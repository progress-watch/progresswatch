import { bind } from '@github/catalyst/lib/bind'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    this.render = this.render.bind(this)
    document.addEventListener('turbo:morph', this.render)
  }

  disconnectedCallback () {
    document.removeEventListener('turbo:morph', this.render)
  }

  select (event) {
    this.selected = event.currentTarget.dataset.tab

    this.render()
  }

  render () {
    if (!this.selected) return

    this.querySelectorAll('[data-tab]').forEach((tab) => {
      tab.setAttribute('aria-selected', String(tab.dataset.tab === this.selected))
    })

    this.querySelectorAll('[data-panel]').forEach((panel) => {
      panel.hidden = panel.dataset.panel !== this.selected
    })
  }
}
