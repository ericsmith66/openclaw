import { Controller } from "@hotwired/stimulus"

// Toast notification system for user feedback
// Listens for 'toast:show' CustomEvents and displays toasts in bottom-right corner
// Usage: window.dispatchEvent(new CustomEvent('toast:show', { 
//   detail: { message: 'Success!', type: 'success', duration: 3000 }
// }))
export default class extends Controller {
  static targets = ["container"]

  connect() {
    // Listen for toast events globally
    this.boundShowToast = this.showToast.bind(this)
    window.addEventListener('toast:show', this.boundShowToast)
  }

  disconnect() {
    window.removeEventListener('toast:show', this.boundShowToast)
  }

  showToast(event) {
    const { message, type = 'info', duration = 3000 } = event.detail || {}
    
    if (!message) {
      console.warn('Toast event missing message')
      return
    }

    // Create toast element
    const toast = document.createElement('div')
    toast.className = this.getToastClasses(type)
    toast.innerHTML = `
      <div class="flex items-center gap-3">
        <span class="text-lg">${this.getIcon(type)}</span>
        <span class="text-sm font-medium">${this.escapeHtml(message)}</span>
        <button class="btn btn-ghost btn-xs btn-circle ml-2" data-action="click->toast#dismiss">
          ✕
        </button>
      </div>
    `
    
    // Add dismiss handler
    const dismissBtn = toast.querySelector('[data-action]')
    dismissBtn.addEventListener('click', () => this.dismiss(toast))
    
    // Add to container
    this.containerTarget.appendChild(toast)
    
    // Trigger animation
    setTimeout(() => toast.classList.add('opacity-100', 'translate-y-0'), 10)
    
    // Auto-dismiss after duration (except for error messages)
    if (type !== 'error' && duration > 0) {
      setTimeout(() => this.dismiss(toast), duration)
    }
  }

  dismiss(toast) {
    if (!toast || !toast.parentNode) return
    
    // Fade out animation
    toast.classList.remove('opacity-100', 'translate-y-0')
    toast.classList.add('opacity-0', 'translate-y-2')
    
    // Remove from DOM after animation
    setTimeout(() => {
      if (toast.parentNode) {
        toast.parentNode.removeChild(toast)
      }
    }, 300)
  }

  getToastClasses(type) {
    const baseClasses = 'alert shadow-lg mb-3 opacity-0 translate-y-2 transition-all duration-300 ease-out max-w-md'
    
    const typeClasses = {
      success: 'alert-success',
      error: 'alert-error',
      warning: 'alert-warning',
      info: 'alert-info'
    }
    
    return `${baseClasses} ${typeClasses[type] || typeClasses.info}`
  }

  getIcon(type) {
    const icons = {
      success: '✓',
      error: '✕',
      warning: '⚠',
      info: 'ℹ'
    }
    
    return icons[type] || icons.info
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
