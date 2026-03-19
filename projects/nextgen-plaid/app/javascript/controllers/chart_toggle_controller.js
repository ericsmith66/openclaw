import { Controller } from "@hotwired/stimulus"

// Simple client-side toggle for showing one of multiple pre-rendered chart panels.
export default class extends Controller {
  static targets = ["panel", "tab"]
  static values = { initial: String }

  connect() {
    this.selectView(this.initialValue || "pie")
  }

  select(event) {
    this.selectView(event.params.view)
  }

  selectView(view) {
    this.panelTargets.forEach((el) => {
      el.classList.toggle("hidden", el.dataset.chartToggleView !== view)
    })

    this.tabTargets.forEach((el) => {
      const active = el.dataset.chartToggleViewParam === view
      el.classList.toggle("btn-primary", active)
      el.classList.toggle("btn-ghost", !active)
      el.setAttribute("aria-selected", active ? "true" : "false")
      el.setAttribute("tabindex", active ? "0" : "-1")
    })
  }
}
