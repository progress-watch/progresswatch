import { bind } from '@github/catalyst/lib/bind'
import { read, forget } from '../lib/profile'
import { disable } from '../lib/push'

export default class extends HTMLElement {
  connectedCallback () {
    this.text = JSON.parse(this.dataset.i18n)
    this.templates = {}
    this.querySelectorAll('template[data-template]').forEach((template) => {
      this.templates[template.dataset.template] = template
    })

    bind(this)
    this.render({ arriving: true })
  }

  async forgetSpace (event) {
    const button = event.currentTarget

    if (!this.confirmed(button.dataset.forgetTitle)) return

    await disable(button.dataset.forget)
    forget(button.dataset.forget)
    this.render()
  }

  render ({ arriving = false } = {}) {
    const spaces = read()

    this.querySelector('[data-list]')?.remove()
    if (spaces.length === 0 && !this.refused) return this.createFirstSpace()

    if (arriving && spaces.length === 1) return this.open(linkTo(spaces[0]))

    const list = this.clone('list')
    const cards = list.querySelector('[data-cards]')

    spaces.forEach((space) => cards.append(this.card(space)))
    cards.append(this.clone('add'))

    list.firstElementChild.dataset.list = ''
    this.append(list)
  }

  createFirstSpace () {
    if (this.creating) return
    this.creating = true

    fetch('/spaces', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(String(response.status)))))
      .then(({ uuid }) => this.open(`/s/${encodeURIComponent(uuid)}`))
      .catch(() => {
        this.creating = false
        this.refused = true
        this.render()
      })
  }

  // replace, not href: Back from the space lands here and is thrown forward again.
  open (url) {
    window.location.replace(url)
  }

  confirmed (title) {
    const what = title ? `"${title}"` : this.text.this_space

    return window.confirm(this.text.remove_what_from_this_device.replace('%{what}', what))
  }

  card (space) {
    const node = this.clone('card')
    const title = space.title || space.uuid

    node.querySelector('[data-link]').href = linkTo(space)
    node.querySelector('[data-title]').textContent = title
    node.querySelector('[data-meta]').textContent = openedAgo(this.text, space.last_opened_at)
    const share = node.querySelector('[data-share]')

    share.href = `${linkTo(space)}/link`
    if (here(space)) share.dataset.turboFrame = 'modal'

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

function openedAgo (text, iso) {
  const at = Date.parse(iso)
  if (!at) return text.never_opened

  const minutes = Math.round((Date.now() - at) / 60000)
  if (minutes < 1) return text.opened_just_now
  if (minutes < 60) return text.opened_count_m_ago.replace('%{count}', minutes)

  const hours = Math.round(minutes / 60)
  if (hours < 24) return text.opened_count_h_ago.replace('%{count}', hours)

  return text.opened_count_d_ago.replace('%{count}', Math.round(hours / 24))
}

function linkTo (space) {
  return `${String(space.server || '').replace(/\/$/, '')}/s/${space.uuid}`
}

function here (space) {
  return linkTo(space).startsWith(`${window.location.origin}/`)
}
