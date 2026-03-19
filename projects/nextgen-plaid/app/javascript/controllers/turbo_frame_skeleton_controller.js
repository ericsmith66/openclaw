import { Controller } from "@hotwired/stimulus"

// Replaces a Turbo Frame's content with a skeleton immediately before navigation,
// so users see a loading state while the request is in-flight.
export default class extends Controller {
  static values = { frameId: String }

  showSkeleton() {
    const id = this.frameIdValue
    if (!id) return

    const frame = document.getElementById(id)
    if (!frame) return

    frame.innerHTML = `
      <div class="card bg-base-100 shadow-xl" aria-busy="true" aria-live="polite">
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">Holdings Summary</h2>
          </div>
          <div class="mt-4 space-y-3">
            <div class="skeleton h-4 w-2/3"></div>
            <div class="skeleton h-4 w-1/2"></div>
            <div class="skeleton h-32 w-full"></div>
          </div>
        </div>
      </div>
    `
  }
}
