import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "toggleIcon"]
  static values = { open: Boolean }

  connect() {
    this.openValue = true
  }

  toggle() {
    this.openValue = !this.openValue
    this.updateUI()
  }

  updateUI() {
    if (this.openValue) {
      this.sidebarTarget.classList.remove("w-0", "opacity-0", "overflow-hidden")
      this.sidebarTarget.classList.add("w-64", "opacity-100")
      this.toggleIconTarget.classList.remove("rotate-180")
    } else {
      this.sidebarTarget.classList.remove("w-64", "opacity-100")
      this.sidebarTarget.classList.add("w-0", "opacity-0", "overflow-hidden")
      this.toggleIconTarget.classList.add("rotate-180")
    }
  }
}
