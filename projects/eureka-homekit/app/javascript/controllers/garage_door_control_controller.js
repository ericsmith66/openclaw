import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["openDialog", "closeDialog"]
  static values = {
    accessoryId: String,
    currentState: Number, // 0=Open, 1=Closed, 2=Opening, 3=Closing, 4=Stopped
    offline: Boolean
  }

  connect() {
    this.isProcessing = false
  }

  // Show open confirmation modal
  showOpenConfirmation() {
    if (this.offlineValue || this.isProcessing) return
    this.openDialogTarget.showModal()
  }

  // Cancel open
  cancelOpen() {
    this.openDialogTarget.close()
  }

  // Confirm and execute open
  confirmOpen() {
    if (this.offlineValue || this.isProcessing) return
    
    this.openDialogTarget.close()
    this.isProcessing = true
    
    // Optimistic UI update
    this.updateStateDisplay(2, 'Opening...')
    
    // Send open command (Target Door State = 0 for Open)
    this.sendControl('Target Door State', 0)
      .then(() => {
        this.isProcessing = false
        this.showSuccess('Garage door opening')
      })
      .catch((error) => {
        this.isProcessing = false
        this.showError(error)
      })
  }

  // Show close confirmation modal
  showCloseConfirmation() {
    if (this.offlineValue || this.isProcessing) return
    this.closeDialogTarget.showModal()
  }

  // Cancel close
  cancelClose() {
    this.closeDialogTarget.close()
  }

  // Confirm and execute close
  confirmClose() {
    if (this.offlineValue || this.isProcessing) return
    
    this.closeDialogTarget.close()
    this.isProcessing = true
    
    // Optimistic UI update
    this.updateStateDisplay(3, 'Closing...')
    
    // Send close command (Target Door State = 1 for Closed)
    this.sendControl('Target Door State', 1)
      .then(() => {
        this.isProcessing = false
        this.showSuccess('Garage door closing')
      })
      .catch((error) => {
        this.isProcessing = false
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
    console.log(`Garage door state optimistic update: ${state} (${statusText})`)
  }

  // Show success message
  showSuccess(message) {
    console.log(`Garage door control success: ${message}`)
    
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
    console.error(`Garage door control error: ${message}`)
    
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }
}
