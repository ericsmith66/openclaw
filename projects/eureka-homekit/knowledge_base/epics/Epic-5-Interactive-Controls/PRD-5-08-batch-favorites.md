#### PRD-5-08: Batch Controls & Favorites Dashboard

**Log Requirements**
- Junie: Create/update task log under `knowledge_base/prds-junie-log/PRD-5-08-batch-favorites-log.md`.

---

### Overview

Power user features: batch control multiple accessories simultaneously and quick access dashboard for frequently used controls.

---

### Requirements

#### Functional

**Batch Controls**:
- Multi-select checkboxes on room/accessory lists
- Batch actions: Turn On, Turn Off, Set Brightness, Set Temperature
- Select All / Deselect All buttons
- Confirmation before applying batch actions
- Progress indicator showing N of M completed
- Rollback individual failures (don't fail entire batch)

**Favorites Dashboard**:
- User can "star" accessories for quick access
- Favorites dashboard shows starred accessories with inline controls
- Drag-and-drop to reorder favorites
- Favorites persist in user preferences (localStorage or database)

#### Components

- `Controls::BatchControlComponent` - batch action toolbar
- `Dashboards::FavoritesComponent` - favorites dashboard
- `Shared::MultiSelectComponent` - checkbox selection UI

#### Technical Notes

- Batch actions execute in parallel (Promise.all) with error handling per accessory
- Store favorites in `user_preferences` table or browser localStorage
- Drag-and-drop using SortableJS or Stimulus Sortable
- Show progress: "Controlling 3 of 8 accessories..."

---

### Acceptance Criteria

- [ ] User can select multiple accessories via checkboxes
- [ ] Batch actions (On, Off, Brightness) apply to selected accessories
- [ ] Progress indicator shows completion status
- [ ] Individual failures don't stop batch operation
- [ ] User can star/unstar accessories
- [ ] Favorites dashboard shows starred accessories with controls
- [ ] Drag-and-drop reorders favorites
- [ ] Favorites persist across sessions

---

### Implementation Highlights

```ruby
# app/controllers/accessories_controller.rb
class AccessoriesController < ApplicationController
  def batch_control
    accessory_ids = params[:accessory_ids]
    action = params[:action_type] # 'turn_on', 'turn_off', 'set_brightness'
    value = params[:value]

    results = []

    Accessory.where(id: accessory_ids).each do |accessory|
      characteristic = case action
      when 'turn_on', 'turn_off'
        'On'
      when 'set_brightness'
        'Brightness'
      else
        next
      end

      result = PrefabControlService.set_characteristic(
        accessory: accessory,
        characteristic: characteristic,
        value: value,
        user_ip: request.remote_ip
      )

      results << {
        accessory_id: accessory.id,
        name: accessory.name,
        success: result[:success],
        error: result[:error]
      }
    end

    render json: { results: results }
  end
end

# app/models/user_preference.rb (new)
class UserPreference < ApplicationRecord
  serialize :favorites, Array

  def self.for_session(session_id)
    find_or_create_by(session_id: session_id)
  end

  def add_favorite(accessory_id)
    self.favorites ||= []
    self.favorites << accessory_id unless self.favorites.include?(accessory_id)
    save
  end

  def remove_favorite(accessory_id)
    self.favorites ||= []
    self.favorites.delete(accessory_id)
    save
  end
end
```

**Stimulus Controller** (`app/javascript/controllers/batch_control_controller.js`):
```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "toolbar", "progressBar", "progressText"]
  static values = { action: String }

  connect() {
    this.updateToolbar()
  }

  toggleSelection(event) {
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
      this.toolbarTarget.querySelector('.count').textContent = selected.length
    } else {
      this.toolbarTarget.classList.add('hidden')
    }
  }

  selectedAccessories() {
    return this.checkboxTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  async executeBatchAction(event) {
    const action = event.currentTarget.dataset.action
    const value = event.currentTarget.dataset.value
    const accessoryIds = this.selectedAccessories()

    this.showProgress(0, accessoryIds.length)

    const response = await fetch('/accessories/batch_control', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        accessory_ids: accessoryIds,
        action_type: action,
        value: value
      })
    })

    const data = await response.json()
    this.showResults(data.results)
  }

  showProgress(current, total) {
    this.progressBarTarget.style.width = `${(current / total) * 100}%`
    this.progressTextTarget.textContent = `${current} of ${total} completed`
  }

  showResults(results) {
    const successful = results.filter(r => r.success).length
    const failed = results.filter(r => !r.success).length
    alert(`Batch action complete: ${successful} succeeded, ${failed} failed`)
    this.deselectAll()
  }
}
```

---

### Test Cases

- Multi-select checkboxes work
- Select All / Deselect All buttons
- Batch turn on/off actions
- Progress indicator updates
- Individual failures don't stop batch
- Star/unstar accessories
- Favorites dashboard displays starred items
- Drag-and-drop reordering
- Favorites persist across sessions
