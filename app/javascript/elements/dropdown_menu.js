// A native <details> closes only when its own summary is clicked again, which reads as
// stuck. The listeners are on document because an outside click has no element to hang an
// attribute off — the same exception poll-frame makes.
//
// One instance per dropdown, so opening one closes the others without any of them knowing
// about each other: the click that opens A is outside B.
export default class extends HTMLElement {
  connectedCallback () {
    this.dismiss = this.dismiss.bind(this)
    this.escape = this.escape.bind(this)

    document.addEventListener('click', this.dismiss)
    document.addEventListener('keydown', this.escape)
  }

  disconnectedCallback () {
    document.removeEventListener('click', this.dismiss)
    document.removeEventListener('keydown', this.escape)
  }

  // A link or a button inside is a choice made, so the menu has done its job. Not a label:
  // Import opens a file picker and reports what went wrong back into the panel, which a
  // closed menu would hide. The summary is neither, so opening still works.
  dismiss (event) {
    if (!this.contains(event.target)) return this.close()

    if (event.target.closest('a, button')) this.close()
  }

  escape (event) {
    if (event.key === 'Escape') this.close()
  }

  close () {
    const details = this.querySelector('details')

    if (details) details.open = false
  }
}
