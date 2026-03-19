import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "checkbox",
    "toolbar",
    "count",
    "brightnessSlider",
    "brightnessDisplay",
    "temperatureInput",
    "progressArea",
    "progressText",
    "progressBar",
    "resultsArea"
  ]

  connect() {
    this.updateToolbar()
    if (this.hasBrightnessSliderTarget) {
      this.brightnessSliderTarget.addEventListener('input', () => {
        this.brightnessDisplayTarget.textContent = `${this.brightnessSliderTarget.value}%`
      })
    }
  }

  toggleSelection() {
    this.updateToolbar()
  }

  selectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = true)
    this.updateToolbar()
  }

  deselectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = false)
    this.updateToolbar()
  }

  updateToolbar() {
    const selected = this.selectedAccessories()
    if (selected.length > 0) {
      this.toolbarTarget.classList.remove('hidden')
      this.countTarget.textContent = selected.length
    } else {
      this.toolbarTarget.classList.add('hidden')
    }
  }

  selectedAccessories() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }

  async executeBatchAction(event) {
    const actionType = event.params.action
    const accessoryIds = this.selectedAccessories()

    if (accessoryIds.length === 0) return

    let value = null
    if (actionType === 'set_brightness' && this.hasBrightnessSliderTarget) {
      value = parseInt(this.brightnessSliderTarget.value)
    } else if (actionType === 'set_temperature' && this.hasTemperatureInputTarget) {
      value = parseFloat(this.temperatureInputTarget.value)
    } else if (actionType === 'turn_on') {
      value = true
    } else if (actionType === 'turn_off') {
      value = false
    }

    this.showProgress(0, accessoryIds.length)

    try {
      const response = await fetch('/accessories/batch_control', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          accessory_ids: accessoryIds,
          action_type: actionType,
          value: value
        })
      })

      const data = await response.json()

      if (data.results) {
        this.showResults(data)
      } else {
        this.showError(data.error || 'Batch action failed')
      }
    } catch (error) {
      this.showError('Network error. Please try again.')
    }
  }

  showProgress(current, total) {
    this.progressAreaTarget.classList.remove('hidden')
    this.resultsAreaTarget.classList.add('hidden')
    const pct = total > 0 ? Math.round((current / total) * 100) : 0
    this.progressBarTarget.value = pct
    this.progressTextTarget.textContent = `Controlling ${current} of ${total} accessories...`
  }

  showResults(data) {
    this.progressAreaTarget.classList.add('hidden')
    this.resultsAreaTarget.classList.remove('hidden')

    const succeeded = data.succeeded || 0
    const failed = data.failed || 0

    let html = ''
    if (failed === 0) {
      html = `<div class="alert alert-success py-2 text-sm">
        <span>✅ All ${succeeded} accessories updated successfully.</span>
      </div>`
    } else {
      const failedItems = data.results
        .filter(r => !r.success)
        .map(r => `<li>${r.name}: ${r.error || 'Unknown error'}</li>`)
        .join('')
      html = `<div class="alert alert-warning py-2 text-sm">
        <div>
          <span>⚠️ ${succeeded} succeeded, ${failed} failed:</span>
          <ul class="list-disc list-inside mt-1 text-xs">${failedItems}</ul>
        </div>
      </div>`
    }

    this.resultsAreaTarget.innerHTML = html

    // Auto-hide success after 5s
    if (failed === 0) {
      setTimeout(() => {
        this.resultsAreaTarget.classList.add('hidden')
        this.deselectAll()
      }, 5000)
    }

    // Dispatch toast event for user feedback
    this.dispatch('complete', {
      detail: { succeeded, failed, total: data.total }
    })
    window.dispatchEvent(new CustomEvent('toast:show', {
      bubbles: true,
      detail: {
        message: failed === 0
          ? `Batch action completed: ${succeeded} accessories updated`
          : `Batch action: ${succeeded} succeeded, ${failed} failed`,
        type: failed === 0 ? 'success' : 'warning'
      }
    }))
  }

  showError(message) {
    this.progressAreaTarget.classList.add('hidden')
    this.resultsAreaTarget.classList.remove('hidden')
    this.resultsAreaTarget.innerHTML = `<div class="alert alert-error py-2 text-sm">
      <span>❌ ${message}</span>
    </div>`

    window.dispatchEvent(new CustomEvent('toast:show', {
      bubbles: true,
      detail: { message: message, type: 'error' }
    }))
  }
}
