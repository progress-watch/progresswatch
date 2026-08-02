// Navigates to a space the user pasted. Client-side so the UUID — which is the
// credential — never travels as a query parameter into the server's request log.
export default class extends HTMLElement {
  connectedCallback () {
    this.querySelector('form')?.addEventListener('submit', (e) => {
      e.preventDefault()

      const uuid = this.querySelector('input[name="uuid"]').value.trim()
      if (uuid) window.location.href = `/s/${encodeURIComponent(uuid)}`
    })
  }
}
