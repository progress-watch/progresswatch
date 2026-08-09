import { bind } from '@github/catalyst/lib/bind'
import { applyLink, readLanguage, writeLanguage } from '../lib/api_language'

const CHANGED = 'code-samples:changed'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)

    this.render = this.render.bind(this)
    document.addEventListener(CHANGED, this.render)
    applyLink()
    this.render()
  }

  disconnectedCallback () {
    document.removeEventListener(CHANGED, this.render)
  }

  select (event) {
    writeLanguage(event.currentTarget.dataset.language)
    document.dispatchEvent(new CustomEvent(CHANGED))
  }

  render () {
    const language = this.resolve(readLanguage(this.languages[0]))

    this.querySelectorAll('[data-language]').forEach((tab) => {
      tab.setAttribute('aria-selected', String(tab.dataset.language === language))
    })

    this.querySelectorAll('[data-sample]').forEach((panel) => {
      panel.hidden = panel.dataset.sample !== language
    })
  }

  // Not every endpoint has every language — the CLI has no command for a health check.
  // Without this the block would render its tabs above nothing at all.
  resolve (language) {
    return this.languages.includes(language) ? language : this.languages[0]
  }

  get languages () {
    return [...this.querySelectorAll('[data-language]')].map((tab) => tab.dataset.language)
  }
}
