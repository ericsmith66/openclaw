import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleButton", "speedSlider", "speedDisplay"]
  static values = {
    accessoryId: String,
    active: Boolean,
    offline: Boolean
  }

  connect() {
    this.debounceTimer = null
    this.isProcessing = false
  }

  // Toggle fan on/off
  toggle(event) {
    if (this.offlineValue || this.isProcessing) return
    
    const newState = event.target.checked
    this.isProcessing = true
    
    // Optimistic UI update
    this.updateActiveState(newState)
    
    // Send control command
    this.sendControl('Active', newState ? 1 : 0)
      .then(() => {
        this.isProcessing = false
        this.showSuccess('Fan ' + (newState ? 'turned on' : 'turned off'))
      })
      .catch((error) => {
        this.isProcessing = false
        // Rollback optimistic update
        event.target.checked = !newState
        this.updateActiveState(!newState)
        this.showError(error)
      })
  }

  // Update speed display in real-time (no API call)
  updateSpeedDisplay(event) {
    const speed = parseInt(event.target.value)
    this.speedDisplayTarget.textContent = `${speed}%`
  }

  // Update speed with debouncing (API call)
  updateSpeed(event) {
    if (this.offlineValue || this.isProcessing) return
    
    const speed = parseInt(event.target.value)
    
    // Debounce the API call (300ms like light_control_controller.js)
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.sendControl('Rotation Speed', speed)
        .then(() => {
          this.showSuccess(`Speed set to ${speed}%`)
        })
        .catch((error) => {
          this.showError(error)
        })
    }, 300)
  }

  // Set direction to clockwise
  setDirectionClockwise(event) {
    if (this.offlineValue || this.isProcessing) return
    
    this.isProcessing = true
    const button = event.currentTarget
    const originalClass = button.className
    
    // Optimistic UI update
    button.classList.add('btn-active')
    button.parentElement.querySelector('.btn:last-child').classList.remove('btn-active')
    
    this.sendControl('Rotation Direction', 0)
      .then(() => {
        this.isProcessing = false
        this.showSuccess('Direction set to clockwise')
      })
      .catch((error) => {
        this.isProcessing = false
        // Rollback
        button.className = originalClass
        this.showError(error)
      })
  }

  // Set direction to counterclockwise
  setDirectionCounterclockwise(event) {
    if (this.offlineValue || this.isProcessing) return
    
    this.isProcessing = true
    const button = event.currentTarget
    const originalClass = button.className
    
    // Optimistic UI update
    button.classList.add('btn-active')
    button.parentElement.querySelector('.btn:first-child').classList.remove('btn-active')
    
    this.sendControl('Rotation Direction', 1)
      .then(() => {
        this.isProcessing = false
        this.showSuccess('Direction set to counterclockwise')
      })
      .catch((error) => {
        this.isProcessing = false
        // Rollback
        button.className = originalClass
        this.showError(error)
      })
  }

  // Toggle oscillation
  toggleOscillation(event) {
    if (this.offlineValue || this.isProcessing) return
    
    const newState = event.target.checked
    this.isProcessing = true
    
    this.sendControl('Swing Mode', newState ? 1 : 0)
      .then(() => {
        this.isProcessing = false
        this.showSuccess('Oscillation ' + (newState ? 'enabled' : 'disabled'))
      })
      .catch((error) => {
        this.isProcessing = false
        // Rollback
        event.target.checked = !newState
        this.showError(error)
      })
  }

  // Update UI state when fan is turned on/off
  updateActiveState(isActive) {
    const speedSlider = this.speedSliderTarget
    if (isActive) {
      speedSlider.removeAttribute('disabled')
    } else {
      speedSlider.setAttribute('disabled', 'disabled')
    }
    
    // Disable/enable optional controls
    const directionButtons = this.element.querySelectorAll('.btn-group .btn')
    const oscillationToggle = this.element.querySelector('input[type="checkbox"]:not([data-fan-control-target="toggleButton"])')
    
    directionButtons.forEach(btn => {
      if (isActive) {
        btn.removeAttribute('disabled')
      } else {
        btn.setAttribute('disabled', 'disabled')
      }
    })
    
    if (oscillationToggle) {
      if (isActive) {
        oscillationToggle.removeAttribute('disabled')
      } else {
        oscillationToggle.setAttribute('disabled', 'disabled')
      }
    }
  }

  // Send control command to backend
  sendControl(characteristic, value) {
    return new Promise((resolve, reject) => {
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
        if (data.success) {
          resolve(data)
        } else {
          reject(data.error || 'Control failed')
        }
      })
      .catch(error => {
        reject(error.message || 'Network error')
      })
    })
  }

  // Show success message
  showSuccess(message) {
    console.log(`Fan control success: ${message}`)
    
    // Dispatch success toast
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
    console.error(`Fan control error: ${message}`)
    
    // Dispatch error toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }
}
