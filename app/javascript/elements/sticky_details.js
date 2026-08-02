import { bind } from '@github/catalyst/lib/bind'

// The polled frame replaces the list every couple of seconds, which would snap every
// <details> shut again.
export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    const details = this.querySelector('details')
    const stored = sessionStorage.getItem(this.key)

    if (details && stored !== null) details.open = stored === '1'
  }

  remember (event) {
    sessionStorage.setItem(this.key, event.target.open ? '1' : '0')
  }

  get key () {
    return `pw:open:${this.dataset.uuid}`
  }
}
