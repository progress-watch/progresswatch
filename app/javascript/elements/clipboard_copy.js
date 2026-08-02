export default class extends HTMLElement {
  connectedCallback () {
    this.addEventListener('click', () => {
      const text = this.dataset.text || this.innerText.trim()

      if (!navigator.clipboard) return

      navigator.clipboard.writeText(text).then(() => this.flash())
    })
  }

  flash () {
    this.dataset.copied = ''

    const label = this.querySelector('[data-copy-label]')
    const original = label && label.textContent

    if (label) label.textContent = label.dataset.copyLabel || 'Copied'

    clearTimeout(this.timer)
    this.timer = setTimeout(() => {
      delete this.dataset.copied
      if (label) label.textContent = original
    }, 1500)
  }
}
