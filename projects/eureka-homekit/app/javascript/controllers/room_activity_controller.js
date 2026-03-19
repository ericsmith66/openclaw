import { Controller } from "@hotwired/stimulus"
import { consumer } from "./application"

export default class extends Controller {
  static values = {
    roomId: Number,
    lastEventAt: String
  }

  connect() {
    console.log(`[RoomActivity] Connected to room ${this.roomIdValue}`)
    this.consumer = consumer
    this.setupSubscription()
    this.startFadingTimer()
    this.updateColor()
  }

  disconnect() {
    console.log(`[RoomActivity] Disconnected from room ${this.roomIdValue}`)
    if (this.channel) {
      this.channel.unsubscribe()
    }
    if (this.timer) {
      clearInterval(this.timer)
    }
  }

  setupSubscription() {
    this.channel = this.consumer.subscriptions.create("RoomActivityChannel", {
      connected: () => {
        console.log(`[RoomActivity] Channel connected for room ${this.roomIdValue}`)
      },
      received: (data) => {
        if (data.room_id === this.roomIdValue) {
          console.log(`[RoomActivity] Received data for room ${data.room_id}:`, data)
          this.lastEventAtValue = data.last_event_at
          
          // If the broadcast includes classes from the backend, use them directly
          if (data.color_class || data.text_color_class) {
            this.applyClasses(data.color_class, data.text_color_class)
          } else {
            this.updateColor()
          }
        }
      }
    })
  }

  startFadingTimer() {
    // Check every minute if color needs to fade
    this.timer = setInterval(() => {
      this.updateColor()
    }, 60000)
  }

  updateColor() {
    if (!this.lastEventAtValue) return

    const lastEvent = new Date(this.lastEventAtValue)
    const now = new Date()
    const minutesAgo = (now - lastEvent) / 60000

    let bgColor = "bg-base-100"
    let textColor = "text-base-content"

    if (minutesAgo <= 5) {
      bgColor = "bg-error"
      textColor = "text-green-50"
    } else if (minutesAgo <= 15) {
      bgColor = "bg-warning"
    } else if (minutesAgo <= 60) {
      bgColor = "bg-info"
    }

    this.applyClasses(bgColor, textColor)
  }

  applyClasses(bgColor, textColor) {
    // Standard set of classes used for room activity in the whole app
    const bgClasses = ["bg-error", "bg-warning", "bg-info", "bg-base-100", "bg-green-500", "bg-green-500/50", "bg-green-500/20"]
    const textClasses = ["text-green-50", "text-base-content"]

    // Remove existing activity-related background classes
    this.element.classList.remove(...bgClasses)
    if (bgColor) this.element.classList.add(bgColor)
    
    // Apply text color to the element and known sub-elements
    const textElements = [this.element, ...this.element.querySelectorAll('.room-name, .sensor-badge')]
    textElements.forEach(el => {
      el.classList.remove(...textClasses)
      if (textColor) el.classList.add(textColor)
    })
  }
}
