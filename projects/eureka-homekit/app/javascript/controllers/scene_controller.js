import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["executeButton", "buttonText", "spinner", "feedback"]
  static values = { id: Number }

  async execute() {
    this.showLoading()

    try {
      const response = await fetch(`/scenes/${this.idValue}/execute`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess(data.message)
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError('Network error. Please try again.')
    }
  }

  showLoading() {
    this.executeButtonTarget.disabled = true
    this.buttonTextTarget.classList.add('hidden')
    this.spinnerTarget.classList.remove('hidden')
    this.feedbackTarget.classList.add('hidden')
  }

  showSuccess(message) {
    this.executeButtonTarget.disabled = false
    this.buttonTextTarget.classList.remove('hidden')
    this.spinnerTarget.classList.add('hidden')

    this.feedbackTarget.innerHTML = `
      <div class="alert alert-success bg-green-100 text-green-700 p-2 rounded">
        <svg class="w-5 h-5 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
        ${message}
      </div>
    `
    this.feedbackTarget.classList.remove('hidden')

    // Hide success message after 3 seconds
    setTimeout(() => {
      this.feedbackTarget.classList.add('hidden')
    }, 3000)
    
    // Also dispatch toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: message,
        type: 'success',
        duration: 3000
      }
    }))
  }

  showError(error) {
    this.executeButtonTarget.disabled = false
    this.buttonTextTarget.classList.remove('hidden')
    this.spinnerTarget.classList.add('hidden')

    this.feedbackTarget.innerHTML = `
      <div class="alert alert-error bg-red-100 text-red-700 p-2 rounded">
        <svg class="w-5 h-5 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        ${error}
      </div>
    `
    this.feedbackTarget.classList.remove('hidden')
    
    // Also dispatch toast
    window.dispatchEvent(new CustomEvent('toast:show', {
      detail: {
        message: error,
        type: 'error',
        duration: 0 // Don't auto-dismiss errors
      }
    }))
  }
}
