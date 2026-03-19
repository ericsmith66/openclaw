import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = 'eureka_homekit_favorites'

export default class extends Controller {
  static targets = ["grid", "emptyState", "star"]

  connect() {
    this.favorites = this.loadFavorites()
    this.updateStarStates()
    this.updateDashboard()
    this.initSortable()
  }

  // Toggle favorite status for an accessory
  async toggleFavorite(event) {
    const uuid = event.currentTarget.dataset.accessoryUuid
    if (!uuid) return

    const index = this.favorites.indexOf(uuid)
    if (index > -1) {
      this.favorites.splice(index, 1)
    } else {
      this.favorites.push(uuid)
    }

    this.saveFavorites()
    this.updateStarStates()
    this.updateDashboard()

    // Persist to server
    try {
      await fetch('/favorites/toggle', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ accessory_uuid: uuid })
      })
    } catch (error) {
      // Server persistence failed silently; localStorage still has the data
      console.warn('Failed to persist favorite to server:', error)
    }

    window.dispatchEvent(new CustomEvent('toast:show', {
      bubbles: true,
      detail: {
        message: index > -1 ? 'Removed from favorites' : 'Added to favorites',
        type: 'success'
      }
    }))
  }

  // Check if an accessory is favorited
  isFavorite(uuid) {
    return this.favorites.includes(uuid)
  }

  // Update all star button states on the page
  updateStarStates() {
    if (!this.hasStarTarget) return

    this.starTargets.forEach(star => {
      const uuid = star.dataset.accessoryUuid
      if (this.isFavorite(uuid)) {
        star.textContent = '★'
        star.classList.add('text-yellow-500')
        star.classList.remove('text-base-content/30')
        star.setAttribute('aria-label', `Remove ${star.dataset.accessoryName || 'accessory'} from favorites`)
      } else {
        star.textContent = '☆'
        star.classList.remove('text-yellow-500')
        star.classList.add('text-base-content/30')
        star.setAttribute('aria-label', `Add ${star.dataset.accessoryName || 'accessory'} to favorites`)
      }
    })
  }

  // Update the favorites dashboard grid visibility
  updateDashboard() {
    if (!this.hasGridTarget) return

    if (this.favorites.length === 0) {
      this.gridTarget.classList.add('hidden')
      if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.remove('hidden')
    } else {
      this.gridTarget.classList.remove('hidden')
      if (this.hasEmptyStateTarget) this.emptyStateTarget.classList.add('hidden')

      // Show/hide individual cards based on favorites list
      const cards = this.gridTarget.querySelectorAll('[data-favorite-uuid]')
      cards.forEach(card => {
        const uuid = card.dataset.favoriteUuid
        const order = this.favorites.indexOf(uuid)
        if (order > -1) {
          card.classList.remove('hidden')
          card.style.order = order
        } else {
          card.classList.add('hidden')
        }
      })
    }
  }

  // Initialize drag-and-drop for reordering
  initSortable() {
    if (!this.hasGridTarget) return

    const cards = this.gridTarget.querySelectorAll('[data-favorite-uuid]')
    cards.forEach(card => {
      card.setAttribute('draggable', 'true')

      card.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', card.dataset.favoriteUuid)
        card.classList.add('opacity-50')
      })

      card.addEventListener('dragend', () => {
        card.classList.remove('opacity-50')
      })

      card.addEventListener('dragover', (e) => {
        e.preventDefault()
        card.classList.add('border-primary')
      })

      card.addEventListener('dragleave', () => {
        card.classList.remove('border-primary')
      })

      card.addEventListener('drop', (e) => {
        e.preventDefault()
        card.classList.remove('border-primary')
        const draggedUuid = e.dataTransfer.getData('text/plain')
        const targetUuid = card.dataset.favoriteUuid
        this.reorderFavorites(draggedUuid, targetUuid)
      })
    })
  }

  // Reorder favorites when drag-and-drop completes
  async reorderFavorites(draggedUuid, targetUuid) {
    if (draggedUuid === targetUuid) return

    const fromIndex = this.favorites.indexOf(draggedUuid)
    const toIndex = this.favorites.indexOf(targetUuid)
    if (fromIndex === -1 || toIndex === -1) return

    this.favorites.splice(fromIndex, 1)
    this.favorites.splice(toIndex, 0, draggedUuid)

    this.saveFavorites()
    this.updateDashboard()

    // Persist reorder to server
    try {
      await fetch('/favorites/reorder', {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ ordered_uuids: this.favorites })
      })
    } catch (error) {
      console.warn('Failed to persist reorder to server:', error)
    }
  }

  // localStorage persistence (fallback + fast reads)
  loadFavorites() {
    try {
      const data = localStorage.getItem(STORAGE_KEY)
      return data ? JSON.parse(data) : []
    } catch {
      return []
    }
  }

  saveFavorites() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.favorites))
    } catch {
      console.error('Failed to save favorites to localStorage')
    }
  }
}
