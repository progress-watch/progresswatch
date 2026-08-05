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
