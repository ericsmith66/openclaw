import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["positionSlider", "positionDisplay", "tiltSlider", "tiltDisplay"]
  static values = {
    accessoryId: String,
    offline: Boolean
  }

  connect() {
    this.debounceTimer = null
    this.isProcessing = false
  }

  // Quick action: Open fully (100% = fully open)
  openFully() {
    if (this.offlineValue || this.isProcessing) return
    
    this.positionSliderTarget.value = 100
    this.positionDisplayTarget.textContent = '100%'
    this.sendControl('Target Position', 100)
  }

  // Quick action: Set to 50%
  setHalfway() {
    if (this.offlineValue || this.isProcessing) return
    
    this.positionSliderTarget.value = 50
    this.positionDisplayTarget.textContent = '50%'
    this.sendControl('Target Position', 50)
  }

  // Quick action: Close fully (0% = fully closed)
  closeFully() {
    if (this.offlineValue || this.isProcessing) return
    
    this.positionSliderTarget.value = 0
    this.positionDisplayTarget.textContent = '0%'
    this.sendControl('Target Position', 0)
  }

  // Update position display in real-time (no API call)
  updatePositionDisplay(event) {
    const position = parseInt(event.target.value)
    this.positionDisplayTarget.textContent = `${position}%`
  }

  // Update position with debouncing (API call)
  updatePosition(event) {
    if (this.offlineValue || this.isProcessing) return
    
    const position = parseInt(event.target.value)
    
    // Debounce the API call (300ms like light_control_controller.js)
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.sendControl('Target Position', position)
    }, 300)
  }

  // Update tilt display in real-time (no API call)
  updateTiltDisplay(event) {
    const tilt = parseInt(event.target.value)
    this.tiltDisplayTarget.textContent = `${tilt}°`
  }

  // Update tilt with debouncing (API call)
  updateTilt(event) {
    if (this.offlineValue || this.isProcessing) return
    
    const tilt = parseInt(event.target.value)
    
    // Debounce the API call
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.sendControl('Target Horizontal Tilt Angle', tilt)
    }, 300)
  }

  // Send control command to backend
  sendControl(characteristic, value) {
    this.isProcessing = true
    
    fetch('/accessories/control', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        accessory_id: this.accessoryIdValue,
        characteristic: characteristic,
        value: value
      })
    })
    .then(response => response.json())
    .then(data => {
      this.isProcessing = false
      if (data.success) {
        this.showSuccess(characteristic, value)
      } else {
        this.showError(data.error)
      }
    })
    .catch(error => {
      this.isProcessing = false
      this.showError('Network error. Please try again.')
    })
  }

  // Show success message
  showSuccess(characteristic, value) {
    console.log(`Blind control success: ${characteristic} = ${value}`)
    
    let message = 'Blind updated'
    if (characteristic === 'Target Position') {
      if (value === 100) {
        message = 'Blind opened'
      } else if (value === 0) {
        message = 'Blind closed'
      } else {
        message = `Blind position set to ${value}%`
      }
    } else if (characteristic === 'Target Horizontal Tilt Angle') {
      message = `Tilt angle set to ${value}°`
    }
    
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'success',
        duration: 3000
      }
    }))
  }

  // Show error message
  showError(message) {
    console.error(`Blind control error: ${message}`)
    
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }
}
