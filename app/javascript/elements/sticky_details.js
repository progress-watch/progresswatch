// The task list is replaced wholesale every couple of seconds by the polled frame, so
// a <details> the user opened would snap shut on the next poll. Keeping the state per
// task uuid and reapplying it on connect survives the replacement; the server's `open`
// attribute stays the default for a task nobody has touched.
export default class extends HTMLElement {
  connectedCallback () {
    const details = this.querySelector('details')
    if (!details) return

    const stored = sessionStorage.getItem(this.key)
    if (stored !== null) details.open = stored === '1'

    details.addEventListener('toggle', () => {
      sessionStorage.setItem(this.key, details.open ? '1' : '0')
    })
  }

  get key () {
    return `pw:open:${this.dataset.uuid}`
  }
}
