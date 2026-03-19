import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "emptyState"]

  filter() {
    const query = this.inputTarget.value.toLowerCase().trim()
    let visibleCount = 0

    this.itemTargets.forEach(item => {
      const text = item.textContent.toLowerCase()
      if (text.includes(query)) {
        item.classList.remove("hidden")
        visibleCount++
      } else {
        item.classList.add("hidden")
      }
    })

    if (visibleCount === 0 && query !== "") {
      this.emptyStateTarget.classList.remove("hidden")
    } else {
      this.emptyStateTarget.classList.add("hidden")
    }
  }
}
