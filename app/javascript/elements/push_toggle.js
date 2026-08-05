import { bind } from '@github/catalyst/lib/bind'
import { pushEnabled, setPush } from '../lib/profile'
import { disable, send, subscription, supported } from '../lib/push'

export default class extends HTMLElement {
  async connectedCallback () {
    bind(this)

    if (!supported()) return this.setAttribute('data-state', 'unsupported')

    this.render(pushEnabled(this.dataset.uuid))
  }

  async toggle () {
    if (pushEnabled(this.dataset.uuid)) {
      await disable(this.dataset.uuid)

      return this.render(false)
    }

    return this.subscribe()
  }

  async subscribe () {
    if (await window.Notification.requestPermission() !== 'granted') {
      return this.setAttribute('data-state', 'denied')
    }

    const registration = await window.navigator.serviceWorker.register('/sw.js')
    const existing = await subscription()
    const created = existing ?? await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: this.applicationServerKey
    })

    await send(this.dataset.uuid, 'POST', { subscription: this.serialize(created) })
    setPush(this.dataset.uuid, true)
    this.render(true)
  }

  serialize (created) {
    const json = created.toJSON()

    return { endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth }
  }

  render (on) {
    this.setAttribute('data-state', on ? 'on' : 'off')
  }

  // base64url in the markup, bytes in the API.
  get applicationServerKey () {
    const padded = (this.dataset.key + '='.repeat((4 - this.dataset.key.length % 4) % 4))
      .replace(/-/g, '+').replace(/_/g, '/')
    const binary = window.atob(padded)

    return Uint8Array.from(binary, (character) => character.charCodeAt(0))
  }
}
