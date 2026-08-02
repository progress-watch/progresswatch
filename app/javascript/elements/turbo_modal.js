import { bind } from '@github/catalyst/lib/bind'

// The dialog gives Esc, the focus trap and focus restoration; nothing here reimplements
// them. Reopening relies on Turbo replacing the frame's children, not on dismiss below:
// Chrome 150 never fires `close`, verified against a hand-built dialog.
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
