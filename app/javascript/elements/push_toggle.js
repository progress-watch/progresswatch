import { bind } from '@github/catalyst/lib/bind'
import { pushEnabled, setPush } from '../lib/profile'
import { disable, keepStorage, reassert, register, subscription, supported } from '../lib/push'

export default class extends HTMLElement {
  async connectedCallback () {
    bind(this)

    if (!supported()) return this.setAttribute('data-state', 'unsupported')

    const on = pushEnabled(this.dataset.uuid)
    this.render(on)

    if (on) await this.repair()
  }

  async repair () {
    const existing = await subscription()

    if (existing) return reassert(this.dataset.uuid, existing)

    this.render(false)
    setPush(this.dataset.uuid, false)
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

    await register(this.dataset.uuid, created)
    await keepStorage()
    this.render(true)
  }

  render (on) {
    this.setAttribute('data-state', on ? 'on' : 'off')
  }

  get applicationServerKey () {
    const padded = (this.dataset.key + '='.repeat((4 - this.dataset.key.length % 4) % 4))
      .replace(/-/g, '+').replace(/_/g, '/')
    const binary = window.atob(padded)

    return Uint8Array.from(binary, (character) => character.charCodeAt(0))
  }
}
