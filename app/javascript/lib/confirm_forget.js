// Forgetting is effectively destructive: the uuid is the only way back to a space and
// nothing on the server can recover it. Shared so the dashboard button and the grid
// card ask the same question — they do the same thing.
export function confirmForget (title) {
  const what = title ? `"${title}"` : 'this space'

  return window.confirm(
    `Remove ${what} from this browser?\n\n` +
    'The space and its tasks are not deleted, but its UUID is the only way back to it ' +
    'and nothing on the server can recover it.'
  )
}
