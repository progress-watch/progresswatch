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
