import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  scrollToTable() {
    const table = document.querySelector('table')
    if (table) {
      table.scrollIntoView({ behavior: 'smooth', block: 'start' })
      
      // Highlight the table temporarily
      const container = table.closest('.bg-base-100')
      if (container) {
        container.classList.add('ring-2', 'ring-primary', 'ring-opacity-50')
        setTimeout(() => {
          container.classList.remove('ring-2', 'ring-primary', 'ring-opacity-50')
        }, 2000)
      }
    }
  }
}
