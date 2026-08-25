import { anyPushEnabled, pushEndpoint, setPush } from './profile'

export function supported () {
  return 'serviceWorker' in window.navigator && 'PushManager' in window && 'Notification' in window
}

export async function subscription () {
  if (!supported()) return null

  const registration = await window.navigator.serviceWorker.getRegistration()

  return registration ? registration.pushManager.getSubscription() : null
}

export async function disable (uuid) {
  const existing = await subscription()

  setPush(uuid, false)
  if (!existing) return

  await send(uuid, 'DELETE', { endpoint: existing.endpoint })
  if (!anyPushEnabled()) await existing.unsubscribe()
}

export async function reassert (uuid, current) {
  const previous = pushEndpoint(uuid)

  if (previous && previous !== current.endpoint) await send(uuid, 'DELETE', { endpoint: previous })

  await register(uuid, current)
}

export async function register (uuid, current) {
  const json = current.toJSON()

  await send(uuid, 'POST', {
    subscription: { endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth }
  })
  setPush(uuid, true, json.endpoint)
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

export async function keepStorage () {
  if (!window.navigator.storage?.persist) return
  if (await window.navigator.storage.persisted()) return

  await window.navigator.storage.persist()
}
