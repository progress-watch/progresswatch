import { bind } from '@github/catalyst/lib/bind'
import { exportBlob, importProfile } from '../lib/profile'

// The only backup there is: nothing is recoverable server-side, so losing the browser
// loses every space whose UUID is not written down somewhere else.
export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  export () {
    const url = URL.createObjectURL(exportBlob())
    const link = document.createElement('a')

    link.href = url
    link.download = 'progresswatch-profile.json'
    link.click()

    URL.revokeObjectURL(url)
  }

  import (event) {
    const input = event.target
    const file = input.files?.[0]
    if (!file) return

    file.text()
      .then((text) => {
        importProfile(text)
        window.location.reload()
      })
      .catch((error) => this.report(`Could not import: ${error.message}`))
      .finally(() => { input.value = '' })
  }

  report (message) {
    const target = this.querySelector('[data-import-error]')
    if (target) target.textContent = message
  }
}
