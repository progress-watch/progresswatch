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

export function pushEnabled (uuid) {
  return read().some((s) => s.uuid === uuid && s.push === true)
}

export function describe (uuid, { title, icon }) {
  write(read().map((space) => (space.uuid === uuid ? { ...space, title: title || null, icon: icon || null } : space)))
}

export function setPush (uuid, on, endpoint = null) {
  write(read().map((s) => (s.uuid === uuid ? { ...s, push: on, push_endpoint: on ? endpoint : null } : s)))
}

export function pushEndpoint (uuid) {
  return read().find((s) => s.uuid === uuid)?.push_endpoint ?? null
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
  const entries = read().map(({ uuid, server, title, icon }) => ({ uuid, server, title, icon }))

  return new Blob([JSON.stringify(entries, null, 2)], { type: 'application/json' })
}

export function importProfile (json) {
  const incoming = parse(json)
  if (!Array.isArray(incoming)) throw new Error('expected a list of { "uuid": ..., "server": ... }')

  const entries = incoming.filter((entry) => typeof entry?.uuid === 'string' && typeof entry?.server === 'string')
  if (entries.length === 0) throw new Error('no spaces in that file')

  const byUuid = new Map(read().map((space) => [space.uuid, space]))

  entries.forEach((entry) => {
    const known = byUuid.get(entry.uuid)

    byUuid.set(entry.uuid, { ...entry, ...known, uuid: entry.uuid, server: entry.server })
  })

  const spaces = [...byUuid.values()]
  write(spaces)

  return spaces
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
