import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prdView", "planView", "tab"]
  static values = { 
    view: { type: String, default: "prd" },
    artifactId: String
  }

  connect() {
    // Try to restore previous view for this artifact
    const savedView = localStorage.getItem(`artifact-view-${this.artifactIdValue}`)
    if (savedView) {
      this.viewValue = savedView
    }
    this.updateUI()
  }

  viewValueChanged(view) {
    localStorage.setItem(`artifact-view-${this.artifactIdValue}`, view)
    this.updateUI()
  }

  switchView(event) {
    this.viewValue = event.currentTarget.dataset.view
  }

  updateUI() {
    const view = this.viewValue
    
    // Update tabs
    this.tabTargets.forEach(tab => {
      if (tab.dataset.view === view) {
        tab.classList.add("tab-active")
      } else {
        tab.classList.remove("tab-active")
      }
    })

    if (view === "prd") {
      this.showPRD()
    } else {
      this.showPlan()
    }
  }

  showPRD() {
    if (this.hasPrdViewTarget) this.prdViewTarget.classList.remove("hidden")
    if (this.hasPlanViewTarget) this.planViewTarget.classList.add("hidden")
  }

  showPlan() {
    if (this.hasPrdViewTarget) this.prdViewTarget.classList.add("hidden")
    if (this.hasPlanViewTarget) this.planViewTarget.classList.remove("hidden")
  }
}
