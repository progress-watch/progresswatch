import { bind } from '@github/catalyst/lib/bind'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  copy () {
    const text = this.dataset.text || this.innerText.trim()
    const app = window.webkit?.messageHandlers?.native

    if (app) {
      app.postMessage({ type: 'copy', text })

      return this.flash()
    }

    if (navigator.clipboard) return navigator.clipboard.writeText(text).then(() => this.flash())

    if (copySelection(text)) this.flash()
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

function copySelection (text) {
  const field = document.createElement('textarea')

  field.value = text
  field.setAttribute('readonly', '')
  field.style.position = 'fixed'
  field.style.opacity = '0'
  document.body.append(field)
  field.select()

  const copied = document.execCommand('copy')

  field.remove()

  return copied
}
