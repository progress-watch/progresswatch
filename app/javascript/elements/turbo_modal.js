import { bind } from '@github/catalyst/lib/bind'

// Reopening relies on Turbo replacing the frame's children: Chrome 150 never fires close.
export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    const dialog = this.querySelector('dialog')
    if (!dialog) return

    dialog.showModal()
    dialog.querySelector('[data-autofocus]')?.focus()
  }

  dismiss () {
    const frame = this.closest('turbo-frame')

    this.remove()
    frame?.removeAttribute('src')
  }
}
