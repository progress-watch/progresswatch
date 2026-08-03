import { bind } from '@github/catalyst/lib/bind'

const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i

// Navigation, not a request: opening the page is what records the space.
export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  open (event) {
    event.preventDefault()

    const input = this.querySelector('input')
    const destination = this.destinationFor(input.value.trim())

    if (!destination) return this.reject(input)

    window.location.href = destination
  }

  destinationFor (value) {
    const uuid = value.match(UUID)
    if (!uuid) return null

    // A full URL keeps its own origin, which is the only way to add another server.
    try {
      const url = new URL(value)

      return `${url.origin}/s/${uuid[0]}`
    } catch {
      return `/s/${uuid[0]}`
    }
  }

  reject (input) {
    input.setCustomValidity('Paste a space UUID, or a link to one.')
    input.reportValidity()
    input.addEventListener('input', () => input.setCustomValidity(''), { once: true })
  }
}
