export default class extends HTMLElement {
  connectedCallback () {
    this.interval = parseInt(this.dataset.interval || '2500', 10)

    this.start()

    this.onVisibilityChange = () => (
      document.visibilityState === 'visible' ? this.start() : this.stop()
    )

    document.addEventListener('visibilitychange', this.onVisibilityChange)
  }

  disconnectedCallback () {
    this.stop()
    document.removeEventListener('visibilitychange', this.onVisibilityChange)
  }

  start () {
    if (this.timer) return

    this.timer = setInterval(() => this.reload(), this.interval)
  }

  stop () {
    clearInterval(this.timer)
    this.timer = null
  }

  reload () {
    const frame = document.getElementById(this.dataset.frame)
    if (!frame) return this.stop()

    frame.reload()
  }
}
