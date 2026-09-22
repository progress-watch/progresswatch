// Turbo prefetches a link when the cursor enters it, and a touch screen sends that only with the tap
// itself, too late to be worth anything. A finger resting on a link says what a hovering cursor says,
// so it gets the same event; moving the finger is a scroll, and takes it back before the request goes.
const MOVE_TOLERANCE = 10

let held = null
let origin = null

function linkFor (target) {
  const link = target?.closest?.('a[href]')

  if (!link) return null

  // A sheet has its own web view and its own snapshot cache, thrown away when it closes.
  if (window.webkit?.messageHandlers?.native && (link.dataset.turboFrame === 'modal' || document.querySelector('native-modal'))) {
    return null
  }

  return link
}

function release () {
  held?.dispatchEvent(new MouseEvent('mouseleave'))
  held = null
  origin = null
}

document.addEventListener('touchstart', (event) => {
  const touch = event.touches[0]
  const link = linkFor(event.target)

  if (!link || !touch) return

  held = link
  origin = { x: touch.clientX, y: touch.clientY }
  link.dispatchEvent(new MouseEvent('mouseenter'))
}, { passive: true })

document.addEventListener('touchmove', (event) => {
  const touch = event.touches[0]

  if (!held || !touch || !origin) return
  if (Math.hypot(touch.clientX - origin.x, touch.clientY - origin.y) <= MOVE_TOLERANCE) return

  release()
}, { passive: true })

document.addEventListener('touchcancel', release, { passive: true })
