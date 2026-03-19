import { Controller } from "@hotwired/stimulus"

// Client-side sorting for small tables (top 10 holdings) to avoid round-trips.
export default class extends Controller {
  static targets = ["row"]
  static values = { enabled: Boolean }

  connect() {
    this.sortColumn = null
    this.sortDir = "desc"
  }

  sort(event) {
    if (!this.enabledValue) return

    const column = event.params.column
    if (!column) return

    if (this.sortColumn === column) {
      this.sortDir = this.sortDir === "asc" ? "desc" : "asc"
    } else {
      this.sortColumn = column
      this.sortDir = column === "ticker" || column === "name" ? "asc" : "desc"
    }

    const dirMultiplier = this.sortDir === "asc" ? 1 : -1
    const rows = [...this.rowTargets]

    rows.sort((a, b) => {
      const av = this.valueFor(a, column)
      const bv = this.valueFor(b, column)
      if (av < bv) return -1 * dirMultiplier
      if (av > bv) return 1 * dirMultiplier
      return 0
    })

    rows.forEach((row) => row.parentElement.appendChild(row))
  }

  valueFor(row, column) {
    if (column === "ticker") return (row.dataset.ticker || "").toLowerCase()
    if (column === "name") return (row.dataset.name || "").toLowerCase()
    if (column === "pct") return parseFloat(row.dataset.pct || "0")
    if (column === "value") return parseFloat(row.dataset.value || "0")
    return ""
  }
}
