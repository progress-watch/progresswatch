// Opens the native <dialog> named by data-target. Everything else — Esc, the focus
// trap, the backdrop — the browser already does, and the close buttons are plain
// <form method="dialog">, so this is the only JavaScript a modal needs.
//
// inert is toggled rather than left off: a closed dialog is still in the document, and
// without it a screen reader walks straight into a form nobody opened.
export default class extends HTMLElement {
  connectedCallback () {
    const dialog = document.getElementById(this.dataset.target)
    if (!dialog) return

    this.querySelector('button')?.addEventListener('click', () => {
      // On mobile this button lives inside the navbar's <details> menu, which would
      // otherwise still be hanging open behind the dialog when it closes.
      this.closest('details')?.removeAttribute('open')

      dialog.inert = false
      dialog.showModal()
      dialog.querySelector('[data-autofocus]')?.focus()
    })

    dialog.addEventListener('close', () => { dialog.inert = true })
  }
}
