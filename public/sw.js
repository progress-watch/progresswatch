// Served from the root so its scope covers the whole app; webpack output lives under
// /packs, which would scope it to the assets instead.
self.addEventListener('push', (event) => {
  const payload = event.data ? event.data.json() : {}

  event.waitUntil(self.registration.showNotification(payload.title || 'Progress Watch', {
    body: payload.body || '',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    // Two reports of the same task collapse into one notification rather than stacking.
    tag: payload.task_uuid || 'progress-watch',
    data: { url: payload.url || '/' }
  }))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()

  const url = event.notification.data.url

  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
    const open = windows.find((window) => window.url.includes(url))

    return open ? open.focus() : self.clients.openWindow(url)
  }))
})
