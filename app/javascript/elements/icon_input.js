import { bind } from '@github/catalyst/lib/bind'

// One grapheme, not one codepoint: 👍🏽 is two and a family emoji is five, and each is one
// character on screen. The server validates the same way.
export default class extends HTMLElement {
  connectedCallback () {
    bind(this)
  }

  trim (event) {
    const first = firstGrapheme(event.target.value)

    if (event.target.value !== first) event.target.value = first
  }
}

function firstGrapheme (value) {
  if (!value) return ''

  if (typeof Intl.Segmenter === 'function') {
    const [segment] = new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(value)
    return segment ? segment.segment : ''
  }

  return Array.from(value)[0] || ''
}
