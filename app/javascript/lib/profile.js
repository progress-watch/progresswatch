// Everything this browser knows, under one key: the list of spaces, and settings as
// they arrive.
//
// There are no accounts, so nothing here is recoverable from the server: a space UUID
// is the credential, and losing it loses the space. That is why export/import exists at
// all, and why it is not a nicety to add later — and it is why export carries the whole
// profile rather than just the list.
//
// Each space entry stores the server it was resolved against, copied at the moment it
// was added rather than referenced. Same rule as the CLI and the mobile app: if it were
// a live reference, changing a default would silently repoint every space at a server
// that has never heard of those UUIDs. There is deliberately **no** top-level server
// setting here for the same reason.
//
// The shape matches the CLI's `~/.progresswatchrc`, so the two stay recognisable as the
// same thing rather than drifting into two formats for one idea.
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

// Merges rather than replaces: importing a backup on a machine that already has spaces
// must not throw the existing ones away. What is being imported wins, because it is the
// more deliberate act.
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
