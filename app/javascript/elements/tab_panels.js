import { bind } from '@github/catalyst/lib/bind'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  select (event) {
    const name = event.currentTarget.dataset.tab

    this.querySelectorAll('[data-tab]').forEach((tab) => {
      tab.setAttribute('aria-selected', String(tab.dataset.tab === name))
    })

    this.querySelectorAll('[data-panel]').forEach((panel) => {
      panel.hidden = panel.dataset.panel !== name
    })
  }
}
