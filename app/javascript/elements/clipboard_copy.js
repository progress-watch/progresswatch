import { bind } from '@github/catalyst/lib/bind'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  copy () {
    if (!navigator.clipboard) return

    navigator.clipboard.writeText(this.dataset.text || this.innerText.trim()).then(() => this.flash())
  }

  flash () {
    const toast = window.webkit?.messageHandlers?.flash

    if (toast && this.dataset.copiedLabel) return toast.postMessage({ style: 'notice', message: this.dataset.copiedLabel })

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
