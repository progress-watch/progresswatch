import { bind } from '@github/catalyst/lib/bind'
import { pushEnabled, restored, setPush } from '../lib/profile'
import { disable, keepStorage, reassert, register, subscription, supported } from '../lib/push'

export default class extends HTMLElement {
  async connectedCallback () {
    bind(this)

    if (!supported()) return this.setAttribute('data-state', 'unsupported')

    await restored

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
    if (window.webkit?.messageHandlers?.push) return this.subscribeDevice()

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

  async subscribeDevice () {
    const device = await subscription({ prompt: true })

    if (!device) {
      return window.webkit.messageHandlers.flash?.postMessage({ style: 'alert', message: this.dataset.denied })
    }

    await register(this.dataset.uuid, device)

    this.render(true)
  }

  render (on) {
    this.setAttribute('data-state', on ? 'on' : 'off')

    const action = this.closest('native-action')

    if (!action) return

    action.setAttribute('data-icon', on ? 'bell_on' : 'bell')
    action.setAttribute('data-label', on ? this.dataset.on : this.dataset.off)
  }

  get applicationServerKey () {
    const padded = (this.dataset.key + '='.repeat((4 - this.dataset.key.length % 4) % 4))
      .replace(/-/g, '+').replace(/_/g, '/')
    const binary = window.atob(padded)

    return Uint8Array.from(binary, (character) => character.charCodeAt(0))
  }
}
