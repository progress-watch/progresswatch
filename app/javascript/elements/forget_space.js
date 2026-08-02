import { bind } from '@github/catalyst/lib/bind'
import { forget } from '../lib/profile'

export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  // Leaves for the landing page afterwards rather than staying put — <remember-space>
  // runs on every dashboard load, so a reload would silently add the space straight back
  // and the button would look broken.
  forgetSpace () {
    if (!this.confirmed(this.dataset.title)) return

    forget(this.dataset.uuid)
    window.location.href = '/'
  }

  confirmed (title) {
    const what = title ? `"${title}"` : 'this space'

    return window.confirm(
      `Remove ${what} from this browser?\n\n` +
      'The space and its tasks are not deleted, but its UUID is the only way back to it ' +
      'and nothing on the server can recover it.'
    )
  }
}
