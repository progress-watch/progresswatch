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

  dismiss (event) {
    if (!this.contains(event.target)) this.close()
  }

  escape (event) {
    if (event.key === 'Escape') this.close()
  }

  close () {
    const details = this.querySelector('details')

    if (details) details.open = false
  }
}
