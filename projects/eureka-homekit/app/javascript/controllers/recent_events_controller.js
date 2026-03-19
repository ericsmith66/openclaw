import { Controller } from "@hotwired/stimulus"
import { consumer } from "./application"

export default class extends Controller {
  static targets = ["list"]
  static values = {
    contextType: String,
    contextId: Number
  }

  connect() {
    console.log("[RecentEvents] Connected")
    this.consumer = consumer
    this.setupSubscription()
  }

  disconnect() {
    console.log("[RecentEvents] Disconnected")
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  setupSubscription() {
    this.channel = this.consumer.subscriptions.create("EventsChannel", {
      connected: () => {
        console.log("[RecentEvents] Channel connected")
      },
      received: (data) => {
        console.log("[RecentEvents] Received data:", data)
        this.updateSidebar(data)
      }
    })
  }

  updateSidebar(data) {
    if (!data.sidebar_html) return

    // Filter by context if present
    if (this.hasContextTypeValue && this.hasContextIdValue) {
      if (this.contextTypeValue === 'room' && data.room_id != this.contextIdValue) return
      if (this.contextTypeValue === 'home' && data.home_id != this.contextIdValue) return
      if (this.contextTypeValue === 'sensor' && data.sensor_id != this.contextIdValue) return
    }

    const div = document.createElement('div')
    div.innerHTML = data.sidebar_html
    const item = div.firstElementChild

    this.listTarget.prepend(item)

    // Remove last item if too many (keep 15)
    if (this.listTarget.children.length > 15) {
      this.listTarget.removeChild(this.listTarget.lastChild)
    }
  }
}
