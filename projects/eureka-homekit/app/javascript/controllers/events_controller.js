import { Controller } from "@hotwired/stimulus"
import { consumer } from "./application"

export default class extends Controller {
  static targets = ["table", "liveToggle"]

  connect() {
    console.log("[Events] Connected to event log")
    this.consumer = consumer
    this.liveMode = true
    this.setupSubscription()
  }

  disconnect() {
    console.log("[Events] Disconnected from event log")
    if (this.channel) {
      this.channel.unsubscribe()
    }
  }

  setupSubscription() {
    this.channel = this.consumer.subscriptions.create("EventsChannel", {
      connected: () => {
        console.log("[Events] Channel connected")
      },
      received: (data) => {
        console.log("[Events] Received data:", data)
        if (this.liveMode) {
          if (data.table_html && this.hasTableTarget) {
            this.prependEventTable(data)
          }
          if (data.sidebar_html) {
            this.updateSidebar(data)
          }
        }
      }
    })
  }

  prependEventTable(data) {
    const table = this.tableTarget
    const div = document.createElement('div')
    div.innerHTML = data.table_html
    const row = div.querySelector('tr')
    
    // Add "NEW" badge animation logic if needed
    row.classList.add('animate-pulse', 'bg-primary/5')
    setTimeout(() => {
      row.classList.remove('animate-pulse', 'bg-primary/5')
    }, 2000)

    table.prepend(row)

    // Remove last row if we want to keep it at 50
    if (table.children.length > 50) {
      table.removeChild(table.lastChild)
    }
  }

  updateSidebar(data) {
    const sidebarList = document.getElementById('recent-events-list')
    if (!sidebarList) return

    // Check if we are in a filtered context
    const sidebarContainer = sidebarList.closest('[data-recent-events-context-type]')
    if (sidebarContainer) {
      const contextType = sidebarContainer.dataset.recentEventsContextType
      const contextId = sidebarContainer.dataset.recentEventsContextId

      if (contextType === 'room' && data.room_id != contextId) return
      if (contextType === 'home' && data.home_id != contextId) return
      if (contextType === 'sensor' && data.sensor_id != contextId) return
    }

    const div = document.createElement('div')
    div.innerHTML = data.sidebar_html
    const item = div.firstElementChild

    sidebarList.prepend(item)

    // Remove last item if too many (keep 15)
    if (sidebarList.children.length > 15) {
      sidebarList.removeChild(sidebarList.lastChild)
    }
  }

  toggleLive(event) {
    this.liveMode = event.target.checked
    if (this.liveMode) {
      console.log("Live mode enabled")
    } else {
      console.log("Live mode disabled")
    }
  }

  openModal(event) {
    const eventId = event.currentTarget.dataset.eventId
    const modal = document.getElementById("event-detail-modal")
    if (!modal) return

    modal.showModal()

    fetch(`/events/${eventId}`, {
      headers: {
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    .then(response => response.text())
    .then(html => {
      // Create a temporary container to extract the modal-box
      const div = document.createElement('div')
      div.innerHTML = html
      const newModalBox = div.querySelector('.modal-box')
      if (newModalBox) {
        const currentModalBox = modal.querySelector('.modal-box')
        if (currentModalBox) {
          currentModalBox.innerHTML = newModalBox.innerHTML
        }
      }
    })
  }
}
