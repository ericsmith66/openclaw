import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "currentTemp",
    "targetTempSlider",
    "targetTempValue",
    "modeSelect"
  ]
  static values = {
    accessoryId: String,
    unit: String, // 'C' or 'F'
    offline: Boolean
  }

  connect() {
    this.debounceTimer = null
    this.updateDisplay()
  }

  update_target_temp(event) {
    if (this.offlineValue) return
    
    const rawValue = event.target.value
    // Convert from display unit to internal °C
    const targetCelsius = this.toCelsius(rawValue)
    
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.sendControl('Target Temperature', targetCelsius)
    }, 500)
  }

  update_mode() {
    if (this.offlineValue) return
    
    const mode = parseInt(this.modeSelectTarget.value)
    this.sendControl('Target Heating/Cooling State', mode)
  }

  toggle_unit() {
    this.unitValue = this.unitValue === 'C' ? 'F' : 'C'
    this.updateDisplay()
  }

  updateDisplay() {
    // Update current temperature display
    const current = this.unitValue === 'C' 
      ? this.currentTempCelsius 
      : this.currentTempFahrenheit
    
    if (this.currentTempTarget) {
      this.currentTempTarget.textContent = `${current.toFixed(1)}°${this.unitValue}`
    }
    
    // Update slider range
    const min = this.unitValue === 'C' ? 10 : 50
    const max = this.unitValue === 'C' ? 30 : 86
    
    if (this.targetTempSliderTarget) {
      this.targetTempSliderTarget.min = min
      this.targetTempSliderTarget.max = max
    }
    
    // Update value display
    this.updateTargetTempDisplay()
  }

  updateTargetTempDisplay() {
    const current = this.unitValue === 'C'
      ? this.targetTempCelsius
      : this.targetTempFahrenheit
    
    if (this.targetTempValueTarget) {
      this.targetTempValueTarget.textContent = `${current.toFixed(1)}°${this.unitValue}`
    }
    
    if (this.targetTempSliderTarget) {
      this.targetTempSliderTarget.value = current.toFixed(1)
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
    console.log(`Thermostat control success: ${characteristic} = ${value}`)
    
    // Dispatch success toast
    let message = 'Thermostat updated'
    if (characteristic === 'Target Temperature') {
      const displayValue = this.unitValue === 'C' ? value : this.toFahrenheit(value)
      message = `Temperature set to ${displayValue.toFixed(1)}°${this.unitValue}`
    } else if (characteristic === 'Target Heating/Cooling State') {
      const modes = ['Off', 'Heat', 'Cool', 'Auto']
      message = `Mode set to ${modes[value] || 'Unknown'}`
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
    console.error(`Thermostat control error: ${message}`)
    
    // Dispatch error toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }

  currentTempCelsius() {
    // Get current temp from the displayed text (will be converted on toggle)
    const text = this.currentTempTarget ? this.currentTempTarget.textContent : ''
    const match = text.match(/(-?\d+(\.\d+)?)°/)
    return match ? parseFloat(match[1]) : null
  }

  currentTempFahrenheit() {
    const celsius = this.currentTempCelsius()
    if (celsius === null) return null
    return this.toFahrenheit(celsius)
  }

  targetTempCelsius() {
    // Get target temp from slider value (always stored as °C internally)
    const val = this.targetTempSliderTarget ? this.targetTempSliderTarget.value : null
    if (val === null) return null
    
    // Slider value is in display unit, convert to °C if needed
    return this.unitValue === 'C' 
      ? parseFloat(val) 
      : this.toCelsius(parseFloat(val))
  }

  targetTempFahrenheit() {
    const celsius = this.targetTempCelsius()
    if (celsius === null) return null
    return this.toFahrenheit(celsius)
  }

  toCelsius(value) {
    return Math.round((value - 32) * 5 / 9 * 10) / 10
  }

  toFahrenheit(value) {
    return Math.round((value * 9 / 5 + 32) * 10) / 10
  }
}
