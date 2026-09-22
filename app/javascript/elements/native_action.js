let counter = 0

export default class extends HTMLElement {
  static observedAttributes = ['data-selected', 'data-label', 'data-icon']

  connectedCallback () {
    this.declare = this.declare.bind(this)
    document.addEventListener('turbo:morph', this.declare)

    this.declare()
  }

  attributeChangedCallback () {
    if (this.nativeId && this.isConnected) this.declare()
  }

  disconnectedCallback () {
    document.removeEventListener('turbo:morph', this.declare)

    if (this.nativeId) {
      window.webkit?.messageHandlers?.native?.postMessage({ type: 'action', op: 'remove', id: this.nativeId })
    }
  }

  declare () {
    const bridge = window.webkit?.messageHandlers?.native

    if (!bridge) return

    const target = this.querySelector('a, button, input, [role="button"]') || this.firstElementChild

    if (!target && !this.dataset.native) return

    this.nativeId ||= `native-action-${++counter}`

    if (target) target.dataset.nativeId = this.nativeId

    bridge.postMessage({
      type: 'action',
      op: 'add',
      id: this.nativeId,
      title: this.dataset.label || target?.textContent.trim(),
      icon: this.dataset.icon,
      placement: this.dataset.placement || 'menu',
      section: this.dataset.section,
      menu: this.dataset.menu,
      menuIcon: this.dataset.menuIcon,
      native: this.dataset.native,
      destructive: this.dataset.destructive === 'true',
      selected: this.dataset.selected === 'true',
      haptic: this.dataset.haptic === 'true'
    })
  }
}
