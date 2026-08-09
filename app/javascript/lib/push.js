import { anyPushEnabled, setPush } from './profile'

export function supported () {
  return 'serviceWorker' in window.navigator && 'PushManager' in window && 'Notification' in window
}

export async function subscription () {
  if (!supported()) return null

  const registration = await window.navigator.serviceWorker.getRegistration()

  return registration ? registration.pushManager.getSubscription() : null
}

// The endpoint is shared by every space here, so dropping it would switch the others off.
export async function disable (uuid) {
  const existing = await subscription()

  setPush(uuid, false)
  if (!existing) return

  await send(uuid, 'DELETE', { endpoint: existing.endpoint })
  if (!anyPushEnabled()) await existing.unsubscribe()
}

export function send (uuid, method, body) {
  return window.fetch(`/s/${encodeURIComponent(uuid)}/push`, {
    method,
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
    },
    body: JSON.stringify(body)
  })
}

// Chrome grants persistent storage off the back of signals like a granted notification
// permission, so subscribing is the one moment this can succeed without springing a
// prompt on somebody who asked for nothing — Firefox shows one, and `/` mints a space on
// arrival, so calling it on load would meet people before they know what the site is.
// Safari answers no unless the page is a Home Screen web app, which is the same thing
// that already exempts it from the seven-day eviction.
//
// The space list is the only thing here that cannot be recovered from the server.
export async function keepStorage () {
  if (!window.navigator.storage?.persist) return
  if (await window.navigator.storage.persisted()) return

  await window.navigator.storage.persist()
}
