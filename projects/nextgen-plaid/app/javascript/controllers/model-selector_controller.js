import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toast"]

  connect() {
    const message = this.toastTarget?.textContent?.trim()
    if (message) {
      this.showToast(message)
    }
  }

  showToast(message) {
    const wrapper = document.createElement("div")
    wrapper.className = "toast toast-top toast-end z-50"
    wrapper.innerHTML = `<div class="alert alert-info"><span>${message}</span></div>`
    document.body.appendChild(wrapper)
    setTimeout(() => wrapper.remove(), 5000)
  }
}
