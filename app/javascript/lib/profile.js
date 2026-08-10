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

// Not remember(): that stamps last_opened_at, and a space whose name was fetched has not
// been opened. Merges, so nothing else on the entry is disturbed.
export function describe (uuid, { title, icon }) {
  write(read().map((space) => (space.uuid === uuid ? { ...space, title: title || null, icon: icon || null } : space)))
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

// Only what cannot be recovered. A title and an icon come back from the server the first
// time the space is opened; last_opened_at and push describe this device; settings are a
// preference. What is left is the pair that nothing else in the world can reconstruct.
export function exportBlob () {
  const entries = read().map(({ uuid, server }) => ({ uuid, server }))

  return new Blob([JSON.stringify(entries, null, 2)], { type: 'application/json' })
}

export function importProfile (json) {
  const incoming = parse(json)
  if (!Array.isArray(incoming)) throw new Error('expected a list of { "uuid": ..., "server": ... }')

  const entries = incoming.filter((entry) => typeof entry?.uuid === 'string' && typeof entry?.server === 'string')
  if (entries.length === 0) throw new Error('no spaces in that file')

  const byUuid = new Map(read().map((space) => [space.uuid, space]))

  // Merge rather than replace: a space this browser already knows keeps the title, icon
  // and push flag it has, and the file carries none of those to overwrite them with.
  entries.forEach((entry) => byUuid.set(entry.uuid, { ...byUuid.get(entry.uuid), ...entry }))

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
