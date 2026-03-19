#### PRD-5-02: Scene Management UI

**Log Requirements**
- Junie: Create/update a task log under `knowledge_base/prds-junie-log/PRD-5-02-scene-management-log.md`.
- Include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-5-02-scene-management-feedback-V1.md` in the same directory.

---

### Overview

HomeKit scenes allow users to control multiple accessories with a single action (e.g., "Good Morning" scene turns on lights, adjusts thermostat, opens blinds). This PRD implements the UI for viewing, organizing, and executing scenes through the web interface.

Users will see a list of scenes grouped by home, with visual cards showing scene names, icons, and an "Execute" button. Clicking execute triggers the scene via the Prefab proxy (PRD 5-01) and provides real-time feedback on success/failure.

---

### Requirements

#### Functional

- Display all scenes for a home in a grid layout
- Scene cards show: name, icon/emoji, accessories count, last executed timestamp
- "Execute" button triggers scene via `PrefabControlService.trigger_scene`
- Loading state during execution (button spinner)
- Success feedback (green checkmark, toast notification)
- Error feedback (red X, error message toast)
- Filter scenes by home (dropdown)
- Search scenes by name
- Group scenes by category (if metadata available from Prefab)
- Track scene execution history via `ControlEvent` model

#### Non-Functional

- Scene execution completes in <1 second
- Grid layout responsive (4 cols desktop, 2 cols tablet, 1 col mobile)
- Supports 50+ scenes per home without performance degradation
- Optimistic UI updates (button shows "Executing..." immediately)

#### Rails / Implementation Notes

- **Controller**: `app/controllers/scenes_controller.rb` (new)
  - `index` - list all scenes
  - `show` - scene detail (accessories, history)
  - `execute` - POST endpoint to trigger scene
- **Views**:
  - `app/views/scenes/index.html.erb`
  - `app/views/scenes/show.html.erb`
- **Components**:
  - `app/components/scenes/card_component.rb` (scene card with execute button)
  - `app/components/scenes/list_component.rb` (grid of scene cards)
  - `app/components/shared/control_feedback_component.rb` (loading/success/error states)
- **Routes**:
  ```ruby
  resources :scenes, only: [:index, :show] do
    member do
      post :execute
    end
  end
  ```
- **Stimulus**: `app/javascript/controllers/scene_controller.js` (handle execute button, show feedback)

---

### Error Scenarios & Fallbacks

- **Scene not found** → Show "Scene not found" error toast, log warning
- **Prefab proxy unreachable** → Show "Connection failed" error toast, log error
- **Timeout** → Retry once (via PRD 5-01), then show "Timeout" error toast
- **Scene execution fails** → Show specific error message from Prefab, log error
- **No scenes configured** → Show empty state: "No scenes configured. Use the Apple Home app to create scenes."

---

### Architectural Context

This PRD builds on PRD 5-01 (Prefab Write API) and Epic 2 (UI components). It follows the same component patterns as sensors and rooms, using ViewComponents for cards and Stimulus for interactivity.

Scene execution is a POST request to `ScenesController#execute`, which delegates to `PrefabControlService.trigger_scene`. The response is JSON with success/error status, consumed by Stimulus to update the UI.

**Non-goals**:
- Scene creation/editing (use Apple Home app)
- Scene automation/scheduling (Epic 5)
- Scene analytics dashboard (future enhancement)

---

### Acceptance Criteria

- [ ] Scenes index displays all scenes grouped by home
- [ ] Scene cards show name, icon, accessories count, last executed timestamp
- [ ] Execute button triggers scene via `PrefabControlService.trigger_scene`
- [ ] Loading state appears during execution (spinner on button)
- [ ] Success feedback shown (green checkmark, toast notification)
- [ ] Error feedback shown with specific error message
- [ ] Scene execution logged to `ControlEvent` table
- [ ] Filter by home and search by name functional
- [ ] Grid layout responsive (4/2/1 columns)
- [ ] Empty state shown when no scenes exist
- [ ] Scene detail page shows accessories and execution history
- [ ] Minitest tests for controller, components, and Stimulus controller

---

### Implementation Details

#### Controller: `app/controllers/scenes_controller.rb`

```ruby
class ScenesController < ApplicationController
  def index
    @scenes = Scene.includes(:home, :accessories).all

    # Filter by home
    if params[:home_id].present?
      @scenes = @scenes.where(home_id: params[:home_id])
    end

    # Search by name
    if params[:search].present?
      @scenes = @scenes.where('name ILIKE ?', "%#{params[:search]}%")
    end

    @scenes = @scenes.order(name: :asc)
    @homes = Home.all # for filter dropdown
  end

  def show
    @scene = Scene.includes(:home, :accessories).find(params[:id])
    @execution_history = ControlEvent.for_scene(@scene.id).recent.limit(20)
  end

  def execute
    @scene = Scene.find(params[:id])

    result = PrefabControlService.trigger_scene(
      scene: @scene,
      user_ip: request.remote_ip
    )

    if result[:success]
      render json: { success: true, message: "Scene '#{@scene.name}' executed successfully" }
    else
      render json: { success: false, error: result[:error] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("Scene execution error: #{e.message}")
    render json: { success: false, error: "Unexpected error" }, status: :internal_server_error
  end
end
```

#### Component: `app/components/scenes/card_component.rb`

```ruby
class Scenes::CardComponent < ViewComponent::Base
  def initialize(scene:, show_home: false)
    @scene = scene
    @show_home = show_home
  end

  def icon_emoji
    # Map scene names to emojis (basic heuristic)
    case @scene.name.downcase
    when /morning/, /wake/
      "🌅"
    when /night/, /sleep/, /bed/
      "🌙"
    when /movie/, /tv/
      "🎬"
    when /dinner/, /eat/
      "🍽️"
    when /leave/, /away/
      "🚪"
    when /arrive/, /home/
      "🏠"
    else
      "⚡" # default
    end
  end

  def accessories_count
    @scene.accessories.count
  end

  def last_executed
    last_event = ControlEvent.for_scene(@scene.id).successful.order(created_at: :desc).first
    last_event ? time_ago_in_words(last_event.created_at) : "Never"
  end
end
```

#### Component Template: `app/components/scenes/card_component.html.erb`

```erb
<div class="card bg-white border border-gray-200 rounded-lg p-4 hover:shadow-lg transition-shadow"
     data-controller="scene"
     data-scene-id-value="<%= @scene.id %>">
  <div class="flex items-start justify-between mb-3">
    <div class="flex items-center gap-3">
      <div class="text-4xl"><%= icon_emoji %></div>
      <div>
        <h3 class="text-lg font-semibold text-gray-900"><%= @scene.name %></h3>
        <% if @show_home %>
          <p class="text-sm text-gray-500"><%= @scene.home.name %></p>
        <% end %>
      </div>
    </div>
  </div>

  <div class="flex items-center justify-between">
    <div class="text-sm text-gray-600">
      <span class="font-medium"><%= accessories_count %></span> accessories
      <span class="mx-2">•</span>
      Last run: <span class="font-medium"><%= last_executed %></span>
    </div>
  </div>

  <div class="mt-4">
    <button
      type="button"
      class="btn btn-primary w-full"
      data-action="click->scene#execute"
      data-scene-target="executeButton">
      <span data-scene-target="buttonText">Execute</span>
      <span data-scene-target="spinner" class="hidden">
        <svg class="animate-spin h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </span>
    </button>
  </div>

  <!-- Feedback messages -->
  <div data-scene-target="feedback" class="hidden mt-3"></div>
</div>
```

#### Stimulus Controller: `app/javascript/controllers/scene_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["executeButton", "buttonText", "spinner", "feedback"]
  static values = { id: Number }

  async execute() {
    this.showLoading()

    try {
      const response = await fetch(`/scenes/${this.idValue}/execute`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      const data = await response.json()

      if (data.success) {
        this.showSuccess(data.message)
      } else {
        this.showError(data.error)
      }
    } catch (error) {
      this.showError('Network error. Please try again.')
    }
  }

  showLoading() {
    this.executeButtonTarget.disabled = true
    this.buttonTextTarget.classList.add('hidden')
    this.spinnerTarget.classList.remove('hidden')
    this.feedbackTarget.classList.add('hidden')
  }

  showSuccess(message) {
    this.executeButtonTarget.disabled = false
    this.buttonTextTarget.classList.remove('hidden')
    this.spinnerTarget.classList.add('hidden')

    this.feedbackTarget.innerHTML = `
      <div class="alert alert-success bg-green-100 text-green-700 p-2 rounded">
        <svg class="w-5 h-5 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
        ${message}
      </div>
    `
    this.feedbackTarget.classList.remove('hidden')

    // Hide success message after 3 seconds
    setTimeout(() => {
      this.feedbackTarget.classList.add('hidden')
    }, 3000)
  }

  showError(error) {
    this.executeButtonTarget.disabled = false
    this.buttonTextTarget.classList.remove('hidden')
    this.spinnerTarget.classList.add('hidden')

    this.feedbackTarget.innerHTML = `
      <div class="alert alert-error bg-red-100 text-red-700 p-2 rounded">
        <svg class="w-5 h-5 inline mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
        </svg>
        ${error}
      </div>
    `
    this.feedbackTarget.classList.remove('hidden')
  }
}
```

#### View: `app/views/scenes/index.html.erb`

```erb
<div class="max-w-7xl mx-auto px-4 py-8">
  <%= render Shared::BreadcrumbComponent.new(items: [
    { label: 'Dashboard', url: root_path },
    { label: 'Scenes', url: scenes_path }
  ]) %>

  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold text-gray-900">Scenes</h1>
    <div class="flex gap-3">
      <%= form_with url: scenes_path, method: :get, class: "flex gap-3" do |f| %>
        <%= f.select :home_id, options_for_select(@homes.map { |h| [h.name, h.id] }, params[:home_id]),
          { include_blank: 'All Homes' }, class: "select select-bordered" %>
        <%= f.text_field :search, placeholder: "Search scenes...", value: params[:search],
          class: "input input-bordered" %>
        <%= f.submit "Filter", class: "btn btn-primary" %>
      <% end %>
    </div>
  </div>

  <% if @scenes.empty? %>
    <div class="text-center py-12">
      <div class="text-6xl mb-4">⚡</div>
      <h2 class="text-2xl font-semibold text-gray-700 mb-2">No scenes configured</h2>
      <p class="text-gray-500">Use the Apple Home app to create scenes.</p>
    </div>
  <% else %>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <% @scenes.each do |scene| %>
        <%= render Scenes::CardComponent.new(scene: scene, show_home: params[:home_id].blank?) %>
      <% end %>
    </div>
  <% end %>
</div>
```

---

### Test Cases

#### Unit (Minitest)

- **test/controllers/scenes_controller_test.rb**:
  - `index` returns all scenes
  - `index` filters by home_id
  - `index` searches by name
  - `show` displays scene details
  - `execute` success case (returns JSON success)
  - `execute` failure case (returns JSON error)

- **test/components/scenes/card_component_test.rb**:
  - Renders scene name, icon, accessories count
  - Shows "Never" when scene not executed
  - Shows time ago when scene executed previously
  - Renders execute button
  - Shows home name when `show_home: true`

#### Integration (Minitest)

- **test/integration/scene_execution_test.rb**:
  - User can view scenes index
  - User can execute scene via POST
  - Scene execution creates ControlEvent record
  - Failed execution shows error message

#### System (Capybara)

- **test/system/scenes_test.rb**:
  - User navigates to scenes page
  - User filters scenes by home
  - User searches for scene by name
  - User clicks execute button
  - Loading spinner appears
  - Success message appears after execution
  - Error message appears on failure

---

### Manual Verification

1. Start Rails server: `bin/rails server`
2. Navigate to `/scenes`
3. Verify scene cards display with icons, names, accessories count
4. Click "Execute" on a scene
5. Verify loading spinner appears
6. Verify success message appears after execution
7. Check `ControlEvent.last` to confirm logging
8. Filter by home using dropdown
9. Search for a scene by name
10. Navigate to scene detail page (`/scenes/:id`)
11. Verify execution history shows recent executions

**Expected**
- Scenes display in responsive grid (4/2/1 columns)
- Execute button shows loading state, then success/error feedback
- ControlEvent records created for each execution
- Filter and search work correctly
- Empty state shown when no scenes exist

---

### Rollout / Deployment Notes

- **Routes**: Add scenes routes to `config/routes.rb`
- **Assets**: Ensure Stimulus controller bundled via `import_map` or build process
- **Performance**: Eager load scene associations (`includes(:home, :accessories)`) to prevent N+1
- **Caching**: Consider caching scene list (5 minute TTL) if performance becomes an issue
- **Monitoring**: Track scene execution success rate via `ControlEvent.success_rate`
