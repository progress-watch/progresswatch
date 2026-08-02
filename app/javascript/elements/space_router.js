import { read } from '../lib/profile'

// `/` is a dispatcher rather than a landing page: with no spaces it mints one and goes
// there, with exactly one it goes straight to it, and with several it shows the grid.
// The pitch underneath is what is left when creating fails — and, via the noscript
// rule, when there is no JavaScript to run any of this.
//
// replace() rather than href: with a normal navigation, Back from a dashboard lands on
// `/`, which immediately throws the user forward again.
export default class extends HTMLElement {
  connectedCallback () {
    const spaces = read()

    if (spaces.length === 1) return this.open(spaces[0].uuid)
    if (spaces.length === 0) return this.create()

    this.reveal('[data-spaces]')
  }

  create () {
    fetch('/spaces', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{}'
    })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(String(response.status)))))
      .then(({ uuid }) => this.open(uuid))
      .catch(() => this.reveal('[data-landing]'))
  }

  open (uuid) {
    window.location.replace(`/s/${encodeURIComponent(uuid)}`)
  }

  reveal (selector) {
    this.querySelectorAll(selector).forEach((element) => { element.hidden = false })
  }
}
