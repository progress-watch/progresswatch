import { read, forget } from '../lib/profile'
import { confirmForget } from '../lib/confirm_forget'

// Renders the spaces this browser knows about. Server-side there is no such list —
// without accounts it has no way to know which spaces are yours.
//
// The uuid is deliberately not on the card: it is the credential, it is unreadable at a
// glance, and the share button copies the whole link anyway. What replaces it is the
// only context this element actually has — which server the space lives on, and when it
// was last opened. Watching one hosted space and two self-hosted ones is the normal
// case, so the host is the thing that tells two cards apart.
export default class extends HTMLElement {
  connectedCallback () {
    this.icons = {}
    this.querySelectorAll('template[data-icon]').forEach((template) => {
      this.icons[template.dataset.icon] = template.innerHTML
    })

    this.render()

    this.addEventListener('click', (e) => {
      const button = e.target.closest('[data-forget]')
      if (!button) return

      e.preventDefault()
      if (!confirmForget(button.dataset.forgetTitle)) return

      forget(button.dataset.forget)
      this.render()
    })
  }

  render () {
    const spaces = read()

    this.innerHTML = `
      <h2 class="mb-3 text-sm font-medium text-zinc-500 dark:text-zinc-400">Spaces on this browser</h2>
      <ul class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        ${spaces.map((space) => this.card(space)).join('')}
        ${this.addCard()}
      </ul>
    `
  }

  card (space) {
    const title = escapeHtml(space.title || 'Untitled space')
    const uuid = escapeHtml(space.uuid)
    const icon = space.icon
      ? `<span class="text-xl leading-none" aria-hidden="true">${escapeHtml(space.icon)}</span>`
      : ''

    // The link stretches over the whole card through its ::after, so the card is one
    // target without nesting the share and forget buttons inside an anchor. Those sit
    // above it on z-10 and keep working; the cost is that card text is no longer
    // selectable, which is why the uuid does not live here.
    return `
      <li class="card relative flex min-w-0 flex-col gap-3 p-4 transition hover:border-zinc-300 dark:hover:border-zinc-700">
        <a href="/s/${uuid}" class="flex min-w-0 items-start gap-2.5 after:absolute after:inset-0 after:content-['']">
          ${icon}
          <span class="min-w-0 flex-1">
            <span class="block truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">${title}</span>
            <span class="mt-1 block truncate text-xs text-zinc-500 dark:text-zinc-400">
              ${escapeHtml(hostOf(space.server))} · ${escapeHtml(openedAgo(space.last_opened_at))}
            </span>
          </span>
        </a>

        <div class="relative z-10 flex items-center justify-end gap-1">
          <clipboard-copy class="inline-flex" data-text="${escapeHtml(linkTo(space))}"
                          title="Copy the link to this space. Whoever has it can read and write here.">
            <button type="button" tabindex="-1" aria-label="Copy the link to this space"
                    class="rounded-md p-1.5 text-zinc-400 transition hover:bg-zinc-100 hover:text-zinc-700 dark:hover:bg-zinc-800 dark:hover:text-zinc-200">
              ${this.icons.share || ''}
            </button>
          </clipboard-copy>

          <button type="button" data-forget="${uuid}" data-forget-title="${title}"
                  class="btn-ghost px-2 py-1 text-xs"
                  title="Remove from this browser. The space itself is not deleted.">Forget</button>
        </div>
      </li>
    `
  }

  // Opens the navbar's modal rather than carrying a form of its own — one dialog, one
  // place the field lives.
  addCard () {
    return `
      <li class="min-w-0">
        <modal-button data-target="new-space" class="block h-full">
          <button type="button"
                  class="flex h-full w-full flex-col items-center justify-center gap-2 rounded-xl border-2 border-dashed border-zinc-300 p-4 text-sm text-zinc-500 transition hover:border-brand-500 hover:text-brand-600 dark:border-zinc-700 dark:text-zinc-400 dark:hover:border-brand-500 dark:hover:text-brand-400">
            ${this.icons.plus || ''}
            New space
          </button>
        </modal-button>
      </li>
    `
  }
}

function hostOf (server) {
  try {
    return new URL(server).host
  } catch {
    return server || 'unknown server'
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

function escapeHtml (value) {
  return String(value).replace(/[&<>"']/g, (c) => (
    { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
  ))
}
