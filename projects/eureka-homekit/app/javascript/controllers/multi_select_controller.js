import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "toolbar", "countBadge", "count"]

  connect() {
    this.updateCount()
  }

  selectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = true)
    this.updateCount()
    this.emitChanged()
  }

  deselectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = false)
    this.updateCount()
    this.emitChanged()
  }

  toggleSelection() {
    this.updateCount()
    this.emitChanged()
  }

  get selectedValues() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }

  updateCount() {
    if (this.hasCountTarget) {
      this.countTarget.textContent = this.selectedValues.length
    }
  }

  emitChanged() {
    this.element.dispatchEvent(new CustomEvent('multi-select:changed', {
      bubbles: true,
      detail: { selected: this.selectedValues }
    }))
  }
}
