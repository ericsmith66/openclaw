import { Controller } from "@hotwired/stimulus"
import svgPanZoom from "svg-pan-zoom"
import createFloorplanSubscription from "../channels/floorplan_channel"

export default class extends Controller {
  static targets = ["container", "loading", "info", "roomName", "sensorData"]
  static values = {
    activeId: Number,
    homeId: Number
  }

  connect() {
    this.loadFloorplan()
    this.subscribe()
  }

  disconnect() {
    if (this.panZoom) this.panZoom.destroy()
    if (this.subscription) this.subscription.unsubscribe()
  }

  subscribe() {
    this.subscription = createFloorplanSubscription({
      received: (data) => this.handleRealtimeUpdate(data)
    })
  }

  handleRealtimeUpdate(data) {
    const { room_id, room_name, heatmap_class, sensor_states } = data
    
    const svgElement = this.containerTarget.querySelector("svg")
    if (!svgElement) return

    // Update SVG Heatmap
    const elements = svgElement.querySelectorAll(`[data-room-id="${room_id}"]`)
    elements.forEach(el => el.setAttribute("class", heatmap_class))

    // Update HTML Labels in Overlay
    const overlay = this.element.querySelector('[data-floorplan-viewer-target="overlay"]')
    if (overlay) {
      const labels = overlay.querySelectorAll(`[data-room-id="${room_id}"]`)
      labels.forEach(label => this.updateLabelBadgeContent(label, sensor_states, room_name))
    }

    // Update info panel
    if (!this.infoTarget.classList.contains("hidden") && this.currentRoomId === room_id) {
      if (room_name && this.hasRoomNameTarget) this.roomNameTarget.textContent = room_name
      this.updateInfoPanel(sensor_states)
    }
  }

  async loadFloorplan() {
    this.loadingTarget.classList.remove("opacity-0")
    this.containerTarget.innerHTML = ""
    
    try {
      const response = await fetch(`/api/floorplans/${this.activeIdValue}`)
      const data = await response.json()
      if (data.svg_content) {
        this.renderSVG(data.svg_content, data.mapping)
      }
    } catch (error) {
      console.error("Failed to load floorplan:", error)
    } finally {
      this.loadingTarget.classList.add("opacity-0")
    }
  }

  renderSVG(svgContent, mapping) {
    this.containerTarget.innerHTML = svgContent
    const svgElement = this.containerTarget.querySelector("svg")
    if (!svgElement) return

    svgElement.setAttribute("width", "100%")
    svgElement.setAttribute("height", "100%")
    
    // Ensure the SVG is responsive and visible
    svgElement.style.overflow = "visible"

    this.panZoom = svgPanZoom(svgElement, {
      zoomEnabled: true,
      controlIconsEnabled: false,
      fit: true,
      center: true,
      onUpdatedCTM: () => this.updateLabels()
    })

    this.setupInteractions(svgElement, mapping)
    this.applyInitialHeatmap(svgElement, mapping)
    
    // Use a small delay to ensure SVG is rendered and bounding boxes can be calculated
    setTimeout(() => {
      this.renderLabels(svgElement, mapping)
    }, 500)
  }

  renderLabels(svgElement, mapping) {
    const rooms = Object.entries(mapping)
    
    const overlay = this.element.querySelector('[data-floorplan-viewer-target="overlay"]')
    if (!overlay) return
    
    overlay.innerHTML = ""
    overlay.style.display = "block"

    rooms.forEach(([elementId, data]) => {
      const element = this.findElement(svgElement, elementId)
      if (!element) return

      const label = document.createElement("div")
      label.className = "room-label-badge"
      label.dataset.elementId = elementId
      label.dataset.roomId = data.room_id
      
      label.style.position = "absolute"
      label.style.background = "white"
      label.style.color = "#1e40af"
      label.style.padding = "4px 8px"
      label.style.borderRadius = "6px"
      label.style.fontSize = "11px"
      label.style.fontWeight = "800"
      label.style.border = "2px solid #3b82f6"
      label.style.boxShadow = "0 4px 6px rgba(0,0,0,0.1)"
      label.style.whiteSpace = "nowrap"
      label.style.zIndex = "1001"
      label.style.pointerEvents = "auto"
      label.style.cursor = "pointer"
      label.style.textAlign = "center"
      
      label.onclick = () => window.location.href = `/rooms/${data.room_id}`
      
      overlay.appendChild(label)
      this.updateLabelBadgeContent(label, data.sensor_states, data.room_name)
    })
    
    this.updateLabels()
    // Repeated updates to ensure they find their place as SVG stabilizes
    setTimeout(() => this.updateLabels(), 100)
    setTimeout(() => this.updateLabels(), 500)
    setTimeout(() => this.updateLabels(), 1000)
  }

  updateLabelBadgeContent(label, states, roomName) {
    const sensorStates = states || {}
    const temp = sensorStates.temperature ? `${Math.round(sensorStates.temperature)}°` : ""
    const hum = sensorStates.humidity ? `${Math.round(sensorStates.humidity)}%` : ""
    const hasMotion = sensorStates.motion

    label.innerHTML = `
      <div class="room-label-name" style="margin-bottom: 2px;">${roomName}</div>
      <div style="display: flex; gap: 6px; align-items: center; justify-content: center;">
        ${temp ? `<span style="color: #2563eb; font-family: monospace;">${temp}</span>` : ""}
        ${hum ? `<span style="color: #0891b2; font-family: monospace;">${hum}</span>` : ""}
        ${hasMotion ? `<span style="width: 8px; height: 8px; background: #ef4444; border-radius: 50%; display: inline-block; box-shadow: 0 0 8px #ef4444;"></span>` : ""}
      </div>
    `
    
    if (hasMotion) {
      label.style.borderColor = "#ef4444"
      label.style.background = "#fef2f2"
    } else {
      label.style.borderColor = "#3b82f6"
      label.style.background = "white"
    }
  }

  updateLabels() {
    if (!this.panZoom) return

    const svgElement = this.containerTarget.querySelector("svg")
    const overlay = this.element.querySelector('[data-floorplan-viewer-target="overlay"]')
    if (!svgElement || !overlay) return

    const overlayRect = overlay.getBoundingClientRect()

    overlay.querySelectorAll(".room-label-badge").forEach(label => {
      const elementId = label.dataset.elementId
      const element = this.findElement(svgElement, elementId)
      
      if (element) {
        try {
          const bbox = element.getBBox()
          const centerX = bbox.x + bbox.width / 2
          const centerY = bbox.y + bbox.height / 2
          
          const matrix = element.getScreenCTM() 
          if (!matrix) return

          const point = svgElement.createSVGPoint()
          point.x = centerX
          point.y = centerY
          const screenPoint = point.matrixTransform(matrix)

          const localX = screenPoint.x - overlayRect.left
          const localY = screenPoint.y - overlayRect.top

          label.style.left = `${localX}px`
          label.style.top = `${localY}px`
          label.style.transform = "translate(-50%, -50%)"
        } catch (e) {
          console.error(`Error positioning label for ${elementId}:`, e)
        }
      }
    })
  }

  renderSVGLabels(svgElement, mapping) {
    // Deprecated - using HTML overlay
  }

  updateSVGLabelContent(group, states, name) {
    // Deprecated
  }

  syncLabelScale() {
    // Deprecated
  }

  findElement(svgElement, elementId) {
    let el = svgElement.getElementById(elementId)
    if (el) return el
    el = svgElement.querySelector(`[name="${elementId}"]`)
    if (el) return el
    const titles = Array.from(svgElement.querySelectorAll("title"))
    const title = titles.find(t => t.textContent.trim() === elementId)
    return title ? title.parentElement : null
  }

  applyInitialHeatmap(svgElement, mapping) {
    Object.entries(mapping).forEach(([elementId, data]) => {
      const el = this.findElement(svgElement, elementId)
      if (el) {
        el.setAttribute("data-room-id", data.room_id)
        if (data.heatmap_class) el.setAttribute("class", data.heatmap_class)
      }
    })
  }

  setupInteractions(svgElement, mapping) {
    Object.entries(mapping).forEach(([elementId, data]) => {
      const el = this.findElement(svgElement, elementId)
      if (el) {
        el.style.cursor = "pointer"
        el.addEventListener("mouseenter", () => this.highlightRoom(el, data))
        el.addEventListener("mouseleave", () => this.unhighlightRoom(el))
        el.addEventListener("click", () => window.location.href = `/rooms/${data.room_id}`)
      }
    })
  }

  highlightRoom(el, data) {
    this.currentRoomId = data.room_id
    el.style.filter = "brightness(1.2)"
    
    // Check for debug parameter
    const urlParams = new URLSearchParams(window.location.search)
    if (urlParams.get('debug') === '1') {
      if (this.hasRoomNameTarget) this.roomNameTarget.textContent = data.room_name
      this.updateInfoPanel(data.sensor_states)
      if (this.hasInfoTarget) {
        this.infoTarget.classList.remove("hidden")
        this.infoTarget.style.display = "block"
      }
    }
  }

  unhighlightRoom(el) {
    el.style.filter = ""
    // Check if targets exist before trying to hide them
    if (this.hasInfoTarget) {
      this.infoTarget.classList.add("hidden")
      this.infoTarget.style.display = "none"
    }
  }

  updateInfoPanel(states) {
    if (!states) return
    this.sensorDataTarget.innerHTML = Object.entries(states)
      .filter(([_, v]) => v != null)
      .map(([k, v]) => `<div class="flex justify-between text-sm"><span class="opacity-70 capitalize">${k.replace("_", " ")}:</span><span class="font-mono">${v}</span></div>`)
      .join("")
  }

  zoomIn() { if (this.panZoom) this.panZoom.zoomIn() }
  zoomOut() { if (this.panZoom) this.panZoom.zoomOut() }
  resetZoom() { if (this.panZoom) { this.panZoom.resetZoom(); this.panZoom.center() } }
  switchLevel(e) {
    this.activeIdValue = e.currentTarget.dataset.floorplanId
    this.loadFloorplan()
  }
}
