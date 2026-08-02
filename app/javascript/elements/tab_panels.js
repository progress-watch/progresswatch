export default class extends HTMLElement {
  connectedCallback () {
    this.addEventListener('click', (e) => {
      const tab = e.target.closest('[data-tab]')
      if (!tab) return

      this.select(tab.dataset.tab)
    })
  }

  select (name) {
    this.querySelectorAll('[data-tab]').forEach((tab) => {
      tab.setAttribute('aria-selected', String(tab.dataset.tab === name))
    })

    this.querySelectorAll('[data-panel]').forEach((panel) => {
      panel.hidden = panel.dataset.panel !== name
    })
  }
}
