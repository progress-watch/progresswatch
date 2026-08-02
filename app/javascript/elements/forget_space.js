import { forget } from '../lib/profile'
import { confirmForget } from '../lib/confirm_forget'

// Leaves for the landing page afterwards rather than staying put — <remember-space>
// runs on every dashboard load, so a reload would silently add the space straight back
// and the button would look broken.
export default class extends HTMLElement {
  connectedCallback () {
    this.querySelector('button')?.addEventListener('click', () => {
      if (!confirmForget(this.dataset.title)) return

      forget(this.dataset.uuid)
      window.location.href = '/'
    })
  }
}
