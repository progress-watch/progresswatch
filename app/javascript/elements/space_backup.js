import { bind } from '@github/catalyst/lib/bind'
import { describe, exportBlob, importProfile } from '../lib/profile'

function stamp () {
  const now = new Date()
  const pad = (value) => String(value).padStart(2, '0')

  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}-${pad(now.getHours())}${pad(now.getMinutes())}`
}

function fetchNames (spaces) {
  const unknown = spaces.filter((space) => !space.title)

  return Promise.allSettled(unknown.map((space) => {
    const url = `${String(space.server || '').replace(/\/$/, '')}/spaces/${encodeURIComponent(space.uuid)}`

    return window.fetch(url)
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(String(response.status)))))
      .then(({ title, icon }) => describe(space.uuid, { title, icon }))
  }))
}

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

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
      .catch((error) => this.report(error.message))
      .finally(() => { input.value = '' })
  }

  report (message) {
    const target = this.querySelector('[data-import-error]')
    const text = JSON.parse(this.dataset.i18n)

    if (target) target.textContent = text.could_not_import_message.replace('%{message}', message)
  }
}
