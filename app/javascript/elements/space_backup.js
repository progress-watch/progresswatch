import { bind } from '@github/catalyst/lib/bind'
import { exportBlob, importProfile } from '../lib/profile'

// Local time rather than UTC: whoever reads this filename is the person who pressed the
// button, and they think in their own clock. No colon, because Windows will not have one
// in a filename, and minutes so that a second export the same day is not "(1)".
function stamp () {
  const now = new Date()
  const pad = (value) => String(value).padStart(2, '0')

  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}`
}

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
    link.download = `progresswatch-spaces-${stamp()}.json`
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
