import { anyPushEnabled, pushEndpoint, setPush } from './profile'

function app () {
  return window.webkit?.messageHandlers?.push
}

export function supported () {
  if (app()) return true

  return 'serviceWorker' in window.navigator && 'PushManager' in window && 'Notification' in window
}

export async function subscription ({ prompt = false } = {}) {
  if (app()) return device(prompt)
  if (!supported()) return null

  const registration = await window.navigator.serviceWorker.getRegistration()

  return registration ? registration.pushManager.getSubscription() : null
}

async function device (prompt) {
  const reply = await app().postMessage({ action: 'token', prompt })

  return reply?.token ? { endpoint: reply.token, apns: reply } : null
}

export async function disable (uuid) {
  const existing = await subscription()

  setPush(uuid, false)
  app()?.postMessage({ action: 'unsubscribed', url: spaceUrl(uuid) })

  if (!existing) return

  await send(uuid, 'DELETE', removal(existing, existing.endpoint))

  if (!anyPushEnabled()) await existing.unsubscribe?.()
}

export async function reassert (uuid, current) {
  const previous = pushEndpoint(uuid)

  if (previous && previous !== current.endpoint) await send(uuid, 'DELETE', removal(current, previous))

  await register(uuid, current)
}

export async function register (uuid, current) {
  if (current.apns) {
    const response = await send(uuid, 'POST', { apns: current.apns })
    const { id } = await response.json()

    app().postMessage({ action: 'subscribed', id, url: spaceUrl(uuid) })

    return setPush(uuid, true, current.endpoint)
  }

  const json = current.toJSON()

  await send(uuid, 'POST', {
    subscription: { endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth }
  })
  setPush(uuid, true, json.endpoint)
}

function removal (current, endpoint) {
  return current.apns ? { apns: { ...current.apns, token: endpoint } } : { endpoint }
}

function spaceUrl (uuid) {
  return `${window.location.origin}/s/${encodeURIComponent(uuid)}`
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
