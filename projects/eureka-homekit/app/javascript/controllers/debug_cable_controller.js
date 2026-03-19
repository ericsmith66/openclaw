import { Controller } from "@hotwired/stimulus"
import { consumer } from "./application"

export default class extends Controller {
  static targets = [
    "container", "statusIndicator", "statusText", 
    "lastPing", "lastData", "toggleLabel", "content",
    "eventsChannelStatus", "roomsChannelStatus"
  ]

  connect() {
    console.log("[DebugCable] Controller connected")
    this.isCollapsed = false
    this.consumer = consumer
    this.updateStatus("connecting", "Connecting...")
    
    this.setupSubscriptions()
  }

  disconnect() {
    if (this.eventsChannel) this.eventsChannel.unsubscribe()
    if (this.roomsChannel) this.roomsChannel.unsubscribe()
  }

  setupSubscriptions() {
    console.log("[DebugCable] Setting up subscriptions")
    // Events Channel
    this.eventsChannel = this.consumer.subscriptions.create("EventsChannel", {
      connected: () => {
        this.updateStatus("connected", "Connected")
        this.eventsChannelStatusTarget.innerText = "Connected"
        this.eventsChannelStatusTarget.classList.add("text-emerald-400")
      },
      disconnected: () => {
        this.updateStatus("disconnected", "Disconnected")
        this.eventsChannelStatusTarget.innerText = "Disconnected"
      },
      received: (data) => {
        this.logReceivedData("Events", data)
      }
    })

    // RoomActivity Channel
    this.roomsChannel = this.consumer.subscriptions.create("RoomActivityChannel", {
      connected: () => {
        this.roomsChannelStatusTarget.innerText = "Connected"
        this.roomsChannelStatusTarget.classList.add("text-emerald-400")
      },
      received: (data) => {
        this.logReceivedData("RoomActivity", data)
      }
    })
  }

  updateStatus(state, text) {
    this.statusTextTarget.innerText = text
    this.statusIndicatorTarget.classList.remove("bg-slate-500", "bg-emerald-500", "bg-red-500")
    
    if (state === "connected") {
      this.statusIndicatorTarget.classList.add("bg-emerald-500")
    } else if (state === "disconnected") {
      this.statusIndicatorTarget.classList.add("bg-red-500")
    } else {
      this.statusIndicatorTarget.classList.add("bg-slate-500")
    }
  }

  logReceivedData(source, data) {
    this.lastPingTarget.innerText = new Date().toLocaleTimeString()
    this.lastDataTarget.innerText = JSON.stringify({ source, ...data }, null, 2)
    
    // Quick flash effect
    this.lastDataTarget.classList.add("text-white")
    setTimeout(() => this.lastDataTarget.classList.remove("text-white"), 500)
  }

  toggle() {
    this.isCollapsed = !this.isCollapsed
    if (this.isCollapsed) {
      this.contentTarget.classList.add("hidden")
      this.toggleLabelTarget.innerText = "Expand"
      this.containerTarget.classList.add("w-32")
      this.containerTarget.classList.remove("w-80")
    } else {
      this.contentTarget.classList.remove("hidden")
      this.toggleLabelTarget.innerText = "Collapse"
      this.containerTarget.classList.add("w-80")
      this.containerTarget.classList.remove("w-32")
    }
  }
}
