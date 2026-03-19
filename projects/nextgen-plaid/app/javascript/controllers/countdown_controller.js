import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["value"]
  static values = { seconds: Number }

  connect() {
    this.remaining = Math.max(0, this.secondsValue || 0)
    this.render()

    if (this.remaining <= 0) return

    this.timer = window.setInterval(() => {
      this.remaining = Math.max(0, this.remaining - 1)
      this.render()
      if (this.remaining === 0) this.stop()
    }, 1000)
  }

  disconnect() {
    this.stop()
  }

  stop() {
    if (this.timer) {
      window.clearInterval(this.timer)
      this.timer = null
    }
  }

  render() {
    if (this.hasValueTarget) this.valueTarget.textContent = String(this.remaining)
  }
}
