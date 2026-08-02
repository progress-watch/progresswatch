// Holds the field to one character as a reader would count them: 👍🏽 is two codepoints
// and a family emoji is five, but each is one thing on screen. The server validates the
// same way — this only keeps the web form from ever submitting something it will reject.
export default class extends HTMLElement {
  connectedCallback () {
    const input = this.querySelector('input')
    if (!input) return

    input.addEventListener('input', () => {
      const first = firstGrapheme(input.value)

      if (input.value !== first) input.value = first
    })
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
