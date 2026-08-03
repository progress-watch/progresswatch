import { bind } from '@github/catalyst/lib/bind'
import { read, forget } from '../lib/profile'

// The list lives in localStorage and nowhere else — without accounts the server has no
// idea which spaces are yours, and telling it would put that in its request log. So the
// filling happens here, but the markup is a <template> in the view like everything else.
export default class extends HTMLElement {
  connectedCallback () {
    this.templates = {}
    this.querySelectorAll('template[data-template]').forEach((template) => {
      this.templates[template.dataset.template] = template
    })

    bind(this)
    this.render({ arriving: true })
  }

  forgetSpace (event) {
    const button = event.currentTarget

    if (!this.confirmed(button.dataset.forgetTitle)) return

    forget(button.dataset.forget)
    this.render()
  }

  render ({ arriving = false } = {}) {
    const spaces = read()

    this.querySelector('[data-list]')?.remove()
    if (spaces.length === 0) return this.createFirstSpace()

    // Only on arrival: forgetting one of two spaces re-renders, and being thrown into
    // the survivor is not what that click asked for.
    if (arriving && spaces.length === 1) return this.open(spaces[0].uuid)

    const list = this.clone('list')
    const cards = list.querySelector('[data-cards]')

    spaces.forEach((space) => cards.append(this.card(space)))
    cards.append(this.clone('add'))

    list.firstElementChild.dataset.list = ''
    this.append(list)
  }

  // Spaces made this way and never reported into are swept after a month, which is what
  // makes minting one for every arrival — crawlers included — affordable.
  createFirstSpace () {
    if (this.creating) return
    this.creating = true

    fetch('/spaces', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(String(response.status)))))
      .then(({ uuid }) => this.open(uuid))
      .catch(() => { this.creating = false })
  }

  // replace, not href: with a normal navigation, Back from the space lands here and is
  // thrown straight forward again.
  open (uuid) {
    window.location.replace(`/s/${encodeURIComponent(uuid)}`)
  }

  confirmed (title) {
    const what = title ? `"${title}"` : 'this space'

    return window.confirm(
      `Remove ${what} from this browser?\n\n` +
      'The space and its tasks are not deleted, but its UUID is the only way back to it ' +
      'and nothing on the server can recover it.'
    )
  }

  card (space) {
    const node = this.clone('card')
    const title = space.title || 'Untitled space'

    node.querySelector('[data-link]').href = `/s/${encodeURIComponent(space.uuid)}`
    node.querySelector('[data-title]').textContent = title
    node.querySelector('[data-meta]').textContent = openedAgo(space.last_opened_at)
    node.querySelector('[data-share]').dataset.text = linkTo(space)

    const icon = node.querySelector('[data-icon]')
    if (space.icon) icon.textContent = space.icon
    else icon.remove()

    const button = node.querySelector('[data-forget]')
    button.dataset.forget = space.uuid
    button.dataset.forgetTitle = title

    return node
  }

  clone (name) {
    return this.templates[name].content.cloneNode(true)
  }
}

function openedAgo (iso) {
  const at = Date.parse(iso)
  if (!at) return 'never opened'

  const minutes = Math.round((Date.now() - at) / 60000)
  if (minutes < 1) return 'opened just now'
  if (minutes < 60) return `opened ${minutes}m ago`

  const hours = Math.round(minutes / 60)
  if (hours < 24) return `opened ${hours}h ago`

  return `opened ${Math.round(hours / 24)}d ago`
}

function linkTo (space) {
  return `${String(space.server || '').replace(/\/$/, '')}/s/${space.uuid}`
}
