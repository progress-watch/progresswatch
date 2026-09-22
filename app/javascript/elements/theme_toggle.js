import { bind } from '@github/catalyst/lib/bind'
import { applyTheme, onThemeChange, readTheme, writeTheme } from '../lib/theme'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    this.render = this.render.bind(this)
    this.stopListening = onThemeChange(this.render)
    document.addEventListener('turbo:morph', this.render)
    applyTheme()
    this.render()
  }

  disconnectedCallback () {
    this.stopListening()
    document.removeEventListener('turbo:morph', this.render)
  }

  select (event) {
    writeTheme(event.currentTarget.dataset.choice)
  }

  render () {
    const theme = readTheme()

    this.querySelectorAll('[data-choice]').forEach((option) => {
      const selected = String(option.dataset.choice === theme)

      option.setAttribute('aria-selected', selected)
      option.closest('native-action')?.setAttribute('data-selected', selected)
    })
  }
}
