import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = {
    accessoryId: String,
    characteristic: String
  }

  connect() {
    this.debounceTimer = null
  }

  toggle(event) {
    const input = event.target
    const newState = input.checked
    
    // Optimistic UI update
    this.updateToggleState(input, newState)
    
    // Debounce API call to prevent rapid-fire requests
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => {
      this.sendControl(newState)
    }, 200)
  }

  updateToggleState(input, newState) {
    // Input state is already updated by browser, this is for visual feedback
    // The toggle class is handled by DaisyUI automatically
  }

  sendControl(newState) {
    fetch('/accessories/control', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        accessory_id: this.accessoryIdValue,
        characteristic: this.characteristicValue,
        value: newState
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showSuccess(newState)
      } else {
        this.showError(data.error)
      }
    })
    .catch(error => {
      this.showError('Network error. Please try again.')
    })
  }

  showSuccess(newState) {
    // Optimistic UI is already correct, just confirm with visual feedback
    this.element.classList.add('animate-pulse')
    setTimeout(() => {
      this.element.classList.remove('animate-pulse')
    }, 300)
    
    // Dispatch success toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: `${newState ? 'Turned on' : 'Turned off'} successfully`,
        type: 'success',
        duration: 3000
      }
    }))
  }

  showError(message) {
    console.error(`Switch control error: ${message}`)
    
    // Rollback optimistic UI
    const input = this.element.querySelector('input[type="checkbox"]')
    if (input) {
      input.checked = !input.checked
    }
    
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
