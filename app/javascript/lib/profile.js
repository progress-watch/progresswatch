const KEY = 'progresswatch.profile'

export function read () {
  return readProfile().spaces
}

export function readProfile () {
  return normalise(parse(window.localStorage.getItem(KEY)) ?? {})
}

export function writeProfile (profile) {
  window.localStorage.setItem(KEY, JSON.stringify(normalise(profile)))
}

export function write (spaces) {
  writeProfile({ ...readProfile(), spaces })
}

export function remember ({ uuid, title, icon, server }) {
  const spaces = read().filter((s) => s.uuid !== uuid)

  // Runs on every dashboard load, so rebuilding the entry would drop `push` each time.
  spaces.unshift({
    ...read().find((s) => s.uuid === uuid),
    uuid,
    title: title || null,
    icon: icon || null,
    server,
    last_opened_at: new Date().toISOString()
  })
  write(spaces)

  return spaces
}

export function forget (uuid) {
  const spaces = read().filter((s) => s.uuid !== uuid)
  write(spaces)

  return spaces
}

// A subscription belongs to the origin, so the browser cannot answer this per space.
export function pushEnabled (uuid) {
  return read().some((s) => s.uuid === uuid && s.push === true)
}

export function setPush (uuid, on) {
  write(read().map((s) => (s.uuid === uuid ? { ...s, push: on } : s)))
}

export function anyPushEnabled () {
  return read().some((s) => s.push === true)
}

export function readSetting (name, fallback = null) {
  const value = readProfile().settings[name]

  return value === undefined ? fallback : value
}

export function writeSetting (name, value) {
  const profile = readProfile()

  writeProfile({ ...profile, settings: { ...profile.settings, [name]: value } })
}

export function exportBlob () {
  return new Blob([JSON.stringify(readProfile(), null, 2)], { type: 'application/json' })
}

export function importProfile (json) {
  const incoming = normalise(parse(json) ?? {})
  if (incoming.spaces.length === 0 && Object.keys(incoming.settings).length === 0) {
    throw new Error('expected a { "spaces": [...] } object')
  }

  const current = readProfile()
  const byUuid = new Map(current.spaces.map((s) => [s.uuid, s]))

  incoming.spaces.forEach((entry) => byUuid.set(entry.uuid, entry))

  const merged = {
    spaces: [...byUuid.values()],
    settings: { ...current.settings, ...incoming.settings }
  }
  writeProfile(merged)

  return merged
}

function parse (value) {
  if (typeof value !== 'string') return null

  try {
    return JSON.parse(value)
  } catch {
    return null
  }
}

function normalise (value) {
  const source = value || {}
  const spaces = Array.isArray(source.spaces) ? source.spaces : []

  return {
    spaces: spaces.filter((entry) => entry && typeof entry.uuid === 'string'),
    settings: source.settings && typeof source.settings === 'object' ? source.settings : {}
  }
}
