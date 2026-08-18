import { bind } from '@github/catalyst/lib/bind'
import { applyTheme, onThemeChange, readTheme, writeTheme } from '../lib/theme'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    this.render = this.render.bind(this)
    this.stopListening = onThemeChange(this.render)
    applyTheme()
    this.render()
  }

  disconnectedCallback () {
    this.stopListening()
  }

  select (event) {
    writeTheme(event.currentTarget.dataset.choice)
    this.querySelector('details')?.removeAttribute('open')
  }

  render () {
    const theme = readTheme()

    this.querySelectorAll('[data-choice]').forEach((option) => {
      option.setAttribute('aria-selected', String(option.dataset.choice === theme))
    })

  }
}
