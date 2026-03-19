import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["confirmDialog"]
  static values = {
    accessoryId: String,
    currentState: Number, // 0=unsecured, 1=secured, 2=jammed, 3=unknown
    offline: Boolean
  }

  connect() {
    this.debounceTimer = null
    this.isProcessing = false
  }

  // Lock the door
  lock(event) {
    if (this.offlineValue || this.isProcessing) return
    
    this.isProcessing = true
    const button = event.currentTarget
    button.disabled = true
    button.innerHTML = '<span class="loading loading-spinner loading-sm"></span> Securing...'
    
    // Optimistic UI update to "locking" state
    this.updateStateDisplay(1, 'Securing...')
    
    // Send lock command
    this.sendControl('Lock Target State', 1)
      .then(() => {
        // Success - state should be 1 (secured) after successful lock
        this.showSuccess('lock')
        setTimeout(() => {
          this.isProcessing = false
          button.disabled = false
          button.textContent = 'Lock'
          // Note: The actual state will be updated via real-time sync
        }, 2000)
      })
      .catch((error) => {
        this.isProcessing = false
        button.disabled = false
        button.innerHTML = 'Lock'
        this.showError(error)
      })
  }

  // Show unlock confirmation modal
  showUnlockConfirmation(event) {
    if (this.offlineValue || this.isProcessing) return
    this.confirmDialogTarget.showModal()
  }

  // Cancel unlock confirmation
  cancelUnlock(event) {
    this.confirmDialogTarget.close()
  }

  // Confirm unlock and send command
  confirmUnlock(event) {
    if (this.offlineValue || this.isProcessing) return
    
    this.confirmDialogTarget.close()
    this.isProcessing = true
    const button = event.currentTarget
    button.disabled = true
    
    // Optimistic UI update to "unlocking" state
    this.updateStateDisplay(0, 'Unsecuring...')
    
    // Send unlock command
    this.sendControl('Lock Target State', 0)
      .then(() => {
        // Success - state should be 0 (unsecured) after successful unlock
        this.showSuccess('unlock')
        setTimeout(() => {
          this.isProcessing = false
          button.disabled = false
          // Note: The actual state will be updated via real-time sync
        }, 2000)
      })
      .catch((error) => {
        this.isProcessing = false
        button.disabled = false
        this.showError(error)
      })
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

  // Update UI state display (optimistic update)
  updateStateDisplay(state, statusText) {
    // This would update the visual display
    // In production, the component would re-render after sync
    console.log(`Lock state optimistic update: ${state} (${statusText})`)
  }

  // Show error message
  showError(message) {
    console.error(`Lock control error: ${message}`)
    
    // Dispatch error toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }
  
  // Show success message
  showSuccess(action) {
    const message = action === 'lock' ? 'Lock secured' : 'Lock unsecured'
    
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'success',
        duration: 3000
      }
    }))
  }


}
