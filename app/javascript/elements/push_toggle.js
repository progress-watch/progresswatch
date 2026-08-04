import { bind } from '@github/catalyst/lib/bind'

export default class extends HTMLElement {
  async connectedCallback () {
    bind(this)

    if (!this.supported) return this.setAttribute('data-state', 'unsupported')

    // Rendering "Notify me" before the subscription is known makes it flip to "Notifying"
    // a moment later for everyone already subscribed. Permission answers synchronously
    // and rules that out: anything but granted means not subscribed.
    if (Notification.permission !== 'granted') this.setAttribute('data-state', 'off')

    this.registration = await navigator.serviceWorker.register('/sw.js')
    this.render(await this.registration.pushManager.getSubscription())
  }

  get supported () {
    return 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window
  }

  async toggle () {
    const existing = await this.registration.pushManager.getSubscription()

    return existing ? this.unsubscribe(existing) : this.subscribe()
  }

  async subscribe () {
    if (await Notification.requestPermission() !== 'granted') return this.setAttribute('data-state', 'denied')

    const subscription = await this.registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.applicationServerKey
    })

    await this.send('POST', { subscription: this.serialize(subscription) })
    this.render(subscription)
  }

  async unsubscribe (subscription) {
    await this.send('DELETE', { endpoint: subscription.endpoint })
    await subscription.unsubscribe()
    this.render(null)
  }

  serialize (subscription) {
    const json = subscription.toJSON()

    return { endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth }
  }

  send (method, body) {
    return window.fetch(this.dataset.url, {
      method,
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(body)
    })
  }

  render (subscription) {
    this.setAttribute('data-state', subscription ? 'on' : 'off')
  }

  // base64url in the markup, bytes in the API.
  get applicationServerKey () {
    const padded = (this.dataset.key + '='.repeat((4 - this.dataset.key.length % 4) % 4))
      .replace(/-/g, '+').replace(/_/g, '/')
    const binary = window.atob(padded)

    return Uint8Array.from(binary, (character) => character.charCodeAt(0))
  }
}
