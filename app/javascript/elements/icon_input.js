import { bind } from '@github/catalyst/lib/bind'

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
