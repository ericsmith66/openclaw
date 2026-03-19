// Entry point for application JavaScript.
//
// This project uses Importmap, so this file is loaded as an ES module via
// `javascript_importmap_tags` (i.e., `import "application"`).
//
// NOTE:
// - We intentionally load Hotwire here so Turbo Streams + Stimulus controllers
//   work everywhere (including `/admin/sap_collaborate`).

// Boot marker for debugging importmap/module-load issues.
// If this is not set in the browser console, the `application` module is not executing.
window.__nextgen_application_booted = true

import "@hotwired/turbo-rails"
import "controllers"

// Charts (PRD-3-11 Asset Allocation View)
import Chartkick from "chartkick"
import "chart.js" // UMD build (sets `window.Chart`)

// Chartkick needs to be told which charting adapter to use.
// With the UMD build, Chart.js is available on `window.Chart`.
Chartkick.use(window.Chart)

// Some Chartkick helpers expect globals.
window.Chartkick = Chartkick
window.Chart = window.Chart

// Turbo Frame updates do not always trigger Chartkick to re-draw charts.
// Ensure charts render when inserted via lazy-loaded Turbo Frames.
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
