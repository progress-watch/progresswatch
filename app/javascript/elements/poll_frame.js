// Keeps a turbo-frame current by re-fetching it on an interval. The frame renders
// server-side like every other page, so there is no client-side model of a task to
// drift out of sync with the one in the ERB.
//
// Polling, not SSE: it was evaluated against SSE and won — simpler, cheaper, holds no
// open connections, and the data changes on the order of seconds anyway.
export default class extends HTMLElement {
  connectedCallback () {
    this.interval = parseInt(this.dataset.interval || '2500', 10)

    this.start()

    // Stop entirely when the tab is hidden. Nobody is looking, and a dashboard left
    // open in a background tab should not keep hitting a self-hosted box all day.
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
