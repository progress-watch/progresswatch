import { bind } from '@github/catalyst/lib/bind'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    this.addEventListener('turbo:before-morph-attribute', this.keepOpen)

    const details = this.querySelector('details')
    const stored = sessionStorage.getItem(this.key)

    if (details && stored !== null) details.open = stored === '1'
  }

  disconnectedCallback () {
    this.removeEventListener('turbo:before-morph-attribute', this.keepOpen)
  }

  keepOpen = (event) => {
    if (event.detail.attributeName === 'open') event.preventDefault()
  }

  remember (event) {
    sessionStorage.setItem(this.key, event.target.open ? '1' : '0')
  }

  get key () {
    return `pw:open:${this.dataset.uuid}`
  }
}
