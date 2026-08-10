import { bind } from '@github/catalyst/lib/bind'
import { describe, exportBlob, importProfile } from '../lib/profile'

// Local time rather than UTC: whoever reads this filename is the person who pressed the
// button, and they think in their own clock. No colon, because Windows will not have one
// in a filename, and minutes so that a second export the same day is not "(1)".
function stamp () {
  const now = new Date()
  const pad = (value) => String(value).padStart(2, '0')

  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}`
}

// The file carries only uuid and server, so the names come back from the servers. Best
// effort and in parallel: whatever fails leaves its card showing the uuid, which is what it
// showed a moment earlier anyway.
//
// Only same-origin spaces answer. Nothing sends CORS headers, so a space on another
// instance stays a uuid until somebody opens it — the same as before this existed.
function fetchNames (spaces) {
  const unknown = spaces.filter((space) => !space.title)

  return Promise.allSettled(unknown.map((space) => {
    const url = `${String(space.server || '').replace(/\/$/, '')}/spaces/${encodeURIComponent(space.uuid)}`

    return window.fetch(url)
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(String(response.status)))))
      .then(({ title, icon }) => describe(space.uuid, { title, icon }))
  }))
}

// The only backup there is: nothing is recoverable server-side, so losing the browser
// loses every space whose UUID is not written down somewhere else.
export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  // Named after the host rather than the product: somebody watching a hosted space and two
  // self-hosted ones ends up with three of these, and which instance a file came from is
  // the only thing telling them apart. A port's colon is not allowed in a filename.
  export () {
    const url = URL.createObjectURL(exportBlob())
    const link = document.createElement('a')

    link.href = url
    link.download = `${window.location.host.replace(':', '-')}-${stamp()}.json`
    link.click()

    URL.revokeObjectURL(url)
  }

  import (event) {
    const input = event.target
    const file = input.files?.[0]
    if (!file) return

    file.text()
      .then((text) => fetchNames(importProfile(text)))
      .then(() => window.location.reload())
      .catch((error) => this.report(`Could not import: ${error.message}`))
      .finally(() => { input.value = '' })
  }

  report (message) {
    const target = this.querySelector('[data-import-error]')
    if (target) target.textContent = message
  }
}
