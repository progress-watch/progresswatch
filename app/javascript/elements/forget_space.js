import { bind } from '@github/catalyst/lib/bind'
import { forget } from '../lib/profile'
import { disable } from '../lib/push'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  async forgetSpace () {
    if (!this.confirmed(this.dataset.title)) return

    await disable(this.dataset.uuid)
    forget(this.dataset.uuid)
    window.location.href = '/'
  }

  confirmed (title) {
    const text = JSON.parse(this.dataset.i18n)
    const what = title ? `"${title}"` : text.this_space

    return window.confirm(text.remove_what_from_this_device.replace('%{what}', what))
  }
}
