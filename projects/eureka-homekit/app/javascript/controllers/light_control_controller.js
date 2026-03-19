import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "toggleButton",
    "brightnessSlider",
    "colorButton",
    "colorModal",
    "hueSlider",
    "saturationSlider",
    "previewSwatch"
  ]
  static values = {
    accessoryId: String,
    offline: Boolean
  }

  connect() {
    this.debounceTimer = null
    this.colorModalVisible = false
  }

  toggle() {
    if (this.offlineValue) return
    
    const newState = !this.isOn()
    this.updateToggleState(newState)
    this.sendControl('On', newState)
  }

  update_brightness(event) {
    if (this.offlineValue) return
    
    const brightness = parseInt(event.target.value)
    
    // Debounce the API call
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.sendControl('Brightness', brightness)
    }, 300)
  }

  open_color_picker() {
    if (this.offlineValue) return
    
    this.colorModalVisible = true
    this.updateColorPreview()
  }

  close_color_picker() {
    this.colorModalVisible = false
  }

  update_hue(event) {
    this.updateColorPreview()
  }

  update_saturation(event) {
    this.updateColorPreview()
  }

  apply_color() {
    if (this.offlineValue) return
    
    const hue = parseInt(this.hueSliderTarget.value)
    const saturation = parseInt(this.saturationSliderTarget.value)
    
    this.sendControl('Hue', hue)
    this.sendControl('Saturation', saturation)
    
    this.close_color_picker()
  }

  isOn() {
    return this.toggleButtonTarget.classList.contains('btn-primary')
  }

  updateToggleState(newState) {
    if (newState) {
      this.toggleButtonTarget.classList.add('btn-primary')
    } else {
      this.toggleButtonTarget.classList.remove('btn-primary')
    }
  }

  sendControl(characteristic, value) {
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
        this.showSuccess(characteristic, value)
      } else {
        this.showError(data.error)
      }
    })
    .catch(error => {
      this.showError('Network error. Please try again.')
    })
  }

  showSuccess(characteristic, value) {
    // Optimistic UI update is already done
    console.log(`Control success: ${characteristic} = ${value}`)
    
    // Dispatch success toast
    let message = 'Light updated'
    if (characteristic === 'On') {
      message = value ? 'Light turned on' : 'Light turned off'
    } else if (characteristic === 'Brightness') {
      message = `Brightness set to ${value}%`
    } else if (characteristic === 'Hue' || characteristic === 'Saturation') {
      message = 'Color updated'
    }
    
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'success',
        duration: 3000
      }
    }))
  }

  showError(message) {
    console.error(`Control error: ${message}`)
    
    // Dispatch error toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }

  updateColorPreview() {
    const hue = this.hueSliderTarget.value
    const saturation = this.saturationSliderTarget.value
    const swatch = this.previewSwatchTarget
    if (swatch) {
      swatch.style.backgroundColor = `hsl(${hue}, ${saturation}%, 50%)`
    }
  }
}
