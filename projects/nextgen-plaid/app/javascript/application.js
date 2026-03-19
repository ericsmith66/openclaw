// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Boot marker for debugging importmap/module-load issues.
// If this is not set in the browser console, the `application` module is not executing.
window.__nextgen_application_booted = true

import "@hotwired/turbo-rails"
import "controllers"

// Charts (PRD-3-11 Asset Allocation View)
// Chart.js is loaded via script tag in layout to avoid ESM/UMD import issues
import Chartkick from "chartkick"

// Chartkick (ESM) needs to be told which charting adapter to use.
// window.Chart is set by the script tag in the layout
Chartkick.use(window.Chart)

// Some Chartkick helpers expect globals.
window.Chartkick = Chartkick
window.Chart = window.Chart

// Turbo Frame updates do not always trigger Chartkick to re-draw charts.
// Ensure charts render when inserted via lazy-loaded Turbo Frames (e.g. PRD-3-12).
const redrawChartkickCharts = () => {
  if (!window.Chartkick || typeof window.Chartkick.eachChart !== "function") return

  try {
    window.Chartkick.eachChart((chart) => chart.redraw())
  } catch (e) {
    // Best-effort: chart rendering should never block navigation.
    // eslint-disable-next-line no-console
    console.warn("Chartkick redraw failed", e)
  }
}

document.addEventListener("turbo:load", redrawChartkickCharts)
document.addEventListener("turbo:frame-load", redrawChartkickCharts)
document.addEventListener("turbo:render", redrawChartkickCharts)
