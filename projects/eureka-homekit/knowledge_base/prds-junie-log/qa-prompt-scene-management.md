# QA Subagent Prompt: PRD-5-02 Scene Management Compliance Verification

**Date**: 2026-02-14  
**Project**: eureka-homekit  
**PRD**: PRD-5-02: Scene Management UI  
**Task**: Verify Epic 5 compliance and design Minitest suite

---

## Executive Summary

Implement scene management UI per PRD-5-02. All write operations (scene execution) MUST follow Epic 5 architecture rules. This QA task verifies compliance and designs the Minitest suite.

---

## Epic 5 Strict Compliance Requirements (MUST BE MET)

### 1. Open3.capture2e Usage (NO BACKTICKS OR SYSTEM CALLS)

**Rule**: All shell/API calls MUST use `Open3.capture2e` or `Open3.capture3`.

**Verification Checklist**:
- [ ] No backticks (`` `command` ``) anywhere in Ruby code
- [ ] No `Kernel.system` calls for Prefab API interactions
- [ ] No `exec` calls
- [ ] All Open3 calls include configurable timeout (ENV['PREFAB_WRITE_TIMEOUT'])

**Files to Inspect**:
- `app/services/prefab_client.rb` - verify `execute_curl_base` uses Open3
- `app/services/prefab_control_service.rb` - verify all write methods
- `app/controllers/scenes_controller.rb` - verify no shell calls
- `app/components/scenes/card_component.rb` - verify no shell calls

**Grep Command**: `grep -rE '(`|system\(|exec\(' app/ | grep -v test`

---

### 2. SecureRandom.uuid for request_id

**Rule**: Every write attempt MUST generate a unique `SecureRandom.uuid` as `request_id`.

**Verification Checklist**:
- [ ] `ControlEvent` model has `request_id` field (uuid type in PostgreSQL)
- [ ] `PrefabControlService.create_control_event` generates `SecureRandom.uuid`
- [ ] `PrefabClient` write methods include `request_id` in audit log

**Files to Inspect**:
- `app/models/control_event.rb` - verify `request_id` presence
- `app/services/prefab_control_service.rb:85-102` - verify `create_control_event` method

**Expected Code Pattern**:
```ruby
request_id: SecureRandom.uuid
```

---

### 3. Audit Record Fields

**Rule**: Every write attempt MUST log: `source`, latency, success, and error details.

**Verification Checklist**:
- [ ] `ControlEvent` model stores `source` (web, ai-decision, manual)
- [ ] `latency_ms` calculated via `((Time.now - start_time) * 1000).round(2)`
- [ ] `success` boolean stored
- [ ] `error_message` stores stderr from Open3
- [ ] `user_ip` captured via `request.remote_ip`

**Files to Inspect**:
- `app/models/control_event.rb` - verify all fields present
- `app/services/prefab_control_service.rb:59-68` - verify `create_control_event` call in `trigger_scene`

**Expected Fields**:
```ruby
action_type: 'execute_scene',
success: result[:success],
error_message: result[:error],
latency_ms: latency,
user_ip: user_ip,
source: source,
request_id: SecureRandom.uuid
```

---

### 4. Retry Logic: 3 Attempts with 500ms Sleep

**Rule**: API calls MUST retry exactly 3 times with 500ms sleep (configurable via ENV).

**Verification Checklist**:
- [ ] `PrefabControlService.trigger_scene` implements retry logic
- [ ] Uses `ENV.fetch('PREFAB_RETRY_ATTEMPTS', '1').to_i` for retry count
- [ ] Sleep is `RETRY_DELAY = 0.5` (500ms)
- [ ] On final failure, logs error to audit model and sets `success=false`

**Files to Inspect**:
- `app/services/prefab_control_service.rb:42-71` - `trigger_scene` method
- `app/services/prefab_control_service.rb:50-55` - retry loop

**Expected Pattern**:
```ruby
retry_attempts = ENV.fetch('PREFAB_RETRY_ATTEMPTS', '1').to_i
retry_attempts.times do
  break if result[:success]
  sleep(RETRY_DELAY)
  result = attempt_execute_scene(home, scene_uuid)
end
```

---

### 5. Boolean Coercion Helper

**Rule**: Handle HomeKit truthy/falsy values (1, "1", true, "true", "on", "yes" → true; 0, "0", false, "false", "off", "no" → false).

**Verification Checklist**:
- [ ] Boolean coercion helper exists in codebase
- [ ] Applied in write operations before sending to Prefab API

**Current State**: This is for PRD 5-02 scene management (which doesn't require boolean coercion directly), but verify helper exists in case scene execution involves accessories.

---

### 6. Webhook Deduplication (Echo Prevention)

**Rule**: Check for recent control events (same accessory + characteristic, within 2–5 seconds) before processing incoming webhook events.

**Verification Checklist**:
- [ ] Webhook controller checks for recent outbound controls
- [ ] Dedupe window is 2–5 seconds
- [ ] Skips creation if matching recent control exists

**Current State**: Not directly applicable to scene execution (webhook is for incoming events, scene execution is outbound).

---

## Implementation Files Review

### 1. ScenesController (`app/controllers/scenes_controller.rb`)

**Required Methods**:
- [ ] `index` - lists all scenes, filters by home, searches by name
- [ ] `show` - scene details with execution history
- [ ] `execute` - POST endpoint calling `PrefabControlService.trigger_scene`

**Compliance Checks**:
- [ ] Uses `PrefabControlService.trigger_scene` (not direct `PrefabClient` calls)
- [ ] Returns JSON with `success` and `error`/`message` keys
- [ ] Captures `user_ip` from `request.remote_ip`
- [ ] Rescue block logs errors and returns generic error message

**Test Prompt**: Verify controller tests cover:
- `index` with/without filters
- `show` with execution history
- `execute` success case
- `execute` failure case
- `execute` error handling

---

### 2. Scenes::CardComponent (`app/components/scenes/card_component.rb`)

**Required Methods**:
- [ ] `initialize(scene:, show_home: false)`
- [ ] `icon_emoji` - maps scene names to emojis
- [ ] `accessories_count` - returns `@scene.accessories.count`
- [ ] `last_executed` - returns time ago or "Never"

**Compliance Checks**:
- [ ] Uses `ControlEvent.for_scene(@scene.id).successful.order(created_at: :desc).first`
- [ ] No shell calls or API interactions

**Template Requirements**:
- [ ] `data-controller="scene"` on card container
- [ ] `data-scene-id-value="<%= @scene.id %>"` for Stimulus
- [ ] Execute button with `data-action="click->scene#execute"`
- [ ] Spinner in hidden `data-scene-target="spinner"`
- [ ] Feedback area in `data-scene-target="feedback"`

---

### 3. Stimulus Controller (`app/javascript/controllers/scene_controller.js`)

**Required Features**:
- [ ] `static targets = ["executeButton", "buttonText", "spinner", "feedback"]`
- [ ] `static values = { id: Number }`
- [ ] `execute()` async function with POST to `/scenes/:id/execute`
- [ ] `showLoading()` - disables button, shows spinner
- [ ] `showSuccess(message)` - shows green success alert, auto-hides after 3s
- [ ] `showError(error)` - shows red error alert with error message

**Compliance Checks**:
- [ ] Fetch includes `X-CSRF-Token` header
- [ ] Handles both success and error responses from JSON
- [ ] Network errors handled with user-friendly message

---

### 4. Views (`app/views/scenes/index.html.erb`, `app/views/scenes/show.html.erb`)

**Index View Requirements**:
- [ ] Breadcrumb with Dashboard/Scenes
- [ ] Filter form with home dropdown and search
- [ ] Responsive grid (4/2/1 columns)
- [ ] Empty state when no scenes
- [ ] Renders `Scenes::CardComponent` for each scene

**Show View Requirements**:
- [ ] Breadcrumb with Dashboard/Scenes/[Scene Name]
- [ ] Scene details (home, accessories count, UUID)
- [ ] Scene accessories list
- [ ] Execution history table with status, latency, source, error
- [ ] Execute button that triggers `scene#execute`

---

## Minitest Suite Design

### Unit Tests

#### test/controllers/scenes_controller_test.rb

```ruby
# Test Cases
test "index returns all scenes" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one))
  get scenes_path
  assert_response :success
  assert_includes assigns(:scenes), scene
end

test "index filters by home_id" do
  scene1 = Scene.create!(name: "Scene 1", home: homes(:one))
  scene2 = Scene.create!(name: "Scene 2", home: homes(:two))
  get scenes_path, params: { home_id: homes(:one).id }
  assert_includes assigns(:scenes), scene1
  refute_includes assigns(:scenes), scene2
end

test "index searches by name" do
  scene1 = Scene.create!(name: "Morning Scene", home: homes(:one))
  scene2 = Scene.create!(name: "Evening Scene", home: homes(:one))
  get scenes_path, params: { search: "Morning" }
  assert_includes assigns(:scenes), scene1
  refute_includes assigns(:scenes), scene2
end

test "show displays scene details" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one))
  get scene_path(scene)
  assert_response :success
  assert_equal scene, assigns(:scene)
end

test "execute success" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  stub_prefab_execute_scene(scene.uuid, success: true)
  
  post execute_scene_path(scene), headers: { "X-CSRF-Token" => form_authenticity_token }
  
  assert_response :success
  json = JSON.parse(response.body)
  assert json["success"]
end

test "execute failure" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  stub_prefab_execute_scene(scene.uuid, success: false, error: "Connection failed")
  
  post execute_scene_path(scene), headers: { "X-CSRF-Token" => form_authenticity_token }
  
  assert_response :unprocessable_entity
  json = JSON.parse(response.body)
  refute json["success"]
  assert json["error"].present?
end

test "execute handles exceptions" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  allow(PrefabControlService).to receive(:trigger_scene).and_raise(StandardError.new("Test error"))
  
  post execute_scene_path(scene), headers: { "X-CSRF-Token" => form_authenticity_token }
  
  assert_response :internal_server_error
  json = JSON.parse(response.body)
  refute json["success"]
  assert_equal "Unexpected error", json["error"]
end
```

#### test/components/scenes/card_component_test.rb

```ruby
# Test Cases
test "renders scene name" do
  scene = Scene.new(name: "Morning Scene")
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "h3", "Morning Scene"
end

test "renders emoji icon for morning scene" do
  scene = Scene.new(name: "Good Morning")
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "div.text-4xl", "🌅"
end

test "renders emoji icon for night scene" do
  scene = Scene.new(name: "Good Night")
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "div.text-4xl", "🌙"
end

test "renders emoji icon for default scene" do
  scene = Scene.new(name: "Random Scene")
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "div.text-4xl", "⚡"
end

test "renders accessories count" do
  scene = Scene.new
  allow(scene).to receive(:accessories).and_return(double(count: 3))
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "span.font-medium", "3"
end

test "shows Never when scene not executed" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one))
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "span.font-medium", "Never"
end

test "shows time ago when scene executed" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one))
  ControlEvent.create!(
    scene: scene,
    action_type: "execute_scene",
    success: true,
    created_at: 5.minutes.ago
  )
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "span.font-medium", /5 minutes/
end

test "shows home name when show_home is true" do
  home = Home.create!(name: "My Home")
  scene = Scene.create!(name: "Test Scene", home: home)
  component = Scenes::CardComponent.new(scene: scene, show_home: true)
  render_component(component)
  
  assert_select "p.text-gray-500", "My Home"
end

test "executes scene on button click" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  component = Scenes::CardComponent.new(scene: scene)
  render_component(component)
  
  assert_select "button[data-action='click->scene#execute']"
  assert_select "button[data-scene-target='executeButton']"
end
```

### Integration Tests

#### test/integration/scene_execution_test.rb

```ruby
# Test Cases
test "scene execution creates ControlEvent" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  stub_prefab_execute_scene(scene.uuid, success: true)
  
  assert_difference "ControlEvent.count", 1 do
    post execute_scene_path(scene), headers: { "X-CSRF-Token" => form_authenticity_token }
  end
  
  event = ControlEvent.order(:created_at).last
  assert_equal scene, event.scene
  assert_equal "execute_scene", event.action_type
  assert event.success
  assert event.request_id.present?
  assert event.latency_ms.present?
  assert_equal "web", event.source
end

test "scene execution failure logs error" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  stub_prefab_execute_scene(scene.uuid, success: false, error: "Prefab API timeout")
  
  post execute_scene_path(scene), headers: { "X-CSRF-Token" => form_authenticity_token }
  
  event = ControlEvent.order(:created_at).last
  refute event.success
  assert event.error_message.include?("Prefab API timeout")
end

test "scene execution respects retry config" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  
  # Mock PrefabClient to fail then succeed
  call_count = 0
  allow(PrefabClient).to receive(:execute_scene) do
    call_count += 1
    if call_count < 3
      { success: false, error: "Temporary error", latency_ms: 10 }
    else
      { success: true, latency_ms: 500 }
    end
  end
  
  post execute_scene_path(scene), headers: { "X-CSRF-Token" => form_authenticity_token }
  
  assert_equal 3, call_count # 3 attempts total
  event = ControlEvent.order(:created_at).last
  assert event.success
end
```

### System Tests

#### test/system/scenes_test.rb

```ruby
# Test Cases
test "user navigates to scenes page" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one))
  
  visit scenes_path
  assert_selector "h1", text: "Scenes"
  assert_selector "h3", text: scene.name
end

test "user filters scenes by home" do
  home1 = homes(:one)
  home2 = homes(:two)
  scene1 = Scene.create!(name: "Scene 1", home: home1)
  scene2 = Scene.create!(name: "Scene 2", home: home2)
  
  visit scenes_path
  select home2.name, from: "home_id"
  click_button "Filter"
  
  assert_selector "h3", text: scene2.name
  assert_no_selector "h3", text: scene1.name
end

test "user searches scenes by name" do
  scene1 = Scene.create!(name: "Morning Scene", home: homes(:one))
  scene2 = Scene.create!(name: "Evening Scene", home: homes(:one))
  
  visit scenes_path
  fill_in "search", with: "Morning"
  click_button "Filter"
  
  assert_selector "h3", text: scene1.name
  assert_no_selector "h3", text: scene2.name
end

test "user executes scene successfully" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  stub_prefab_execute_scene(scene.uuid, success: true)
  
  visit scenes_path
  click_button "Execute", match: :first
  
  assert_selector ".alert-success", text: "executed successfully"
  assert_no_selector ".spinner"
end

test "user executes scene with failure" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one), uuid: SecureRandom.uuid)
  stub_prefab_execute_scene(scene.uuid, success: false, error: "Device offline")
  
  visit scenes_path
  click_button "Execute", match: :first
  
  assert_selector ".alert-error", text: "Device offline"
end

test "scene detail page shows execution history" do
  scene = Scene.create!(name: "Test Scene", home: homes(:one))
  ControlEvent.create!(
    scene: scene,
    action_type: "execute_scene",
    success: true,
    latency_ms: 250,
    source: "web",
    created_at: 10.minutes.ago
  )
  
  visit scene_path(scene)
  assert_selector "h1", text: scene.name
  assert_selector "td", text: "Success"
  assert_selector "td", text: "250ms"
end

test "empty state shown when no scenes exist" do
  visit scenes_path
  assert_selector "h2", text: "No scenes configured"
end
```

---

## QA Verification Steps

### 1. Code Review Checklist

- [ ] Review `app/services/prefab_client.rb` for Open3 compliance
- [ ] Review `app/services/prefab_control_service.rb` for retry logic
- [ ] Review `app/controllers/scenes_controller.rb` for JSON responses
- [ ] Review `app/components/scenes/card_component.rb` for helper methods
- [ ] Review `app/javascript/controllers/scene_controller.js` for Stimulus patterns

### 2. Test Execution

```bash
# Run all tests
bundle exec rails test:all

# Run specific test files
bundle exec rails test:controllers scenes_controller_test
bundle exec rails test:components scenes/card_component_test
bundle exec rails test:integration scene_execution_test
bundle exec rails test:system scenes_test
```

### 3. Manual Verification

1. Start Rails server: `bin/rails server`
2. Navigate to `/scenes`
3. Verify scene cards display with icons, names, accessories count
4. Click "Execute" on a scene
5. Verify loading spinner appears
6. Verify success/error message appears
7. Check `ControlEvent.last` to confirm logging
8. Filter by home using dropdown
9. Search for a scene by name
10. Navigate to scene detail page (`/scenes/:id`)
11. Verify execution history shows recent executions

---

## Success Criteria

- [ ] All Epic 5 compliance checks pass
- [ ] Minitest suite covers 100% of scenarios
- [ ] All tests pass in CI environment
- [ ] No linting errors (rubocop, eslint)
- [ ] No security vulnerabilities (brakeman)
- [ ] Performance acceptable (<1s scene execution)

---

## Rollback Plan

If any compliance check fails:

1. Revert changes to non-compliant files
2. Fix implementation per Epic 5 strict rules
3. Re-run tests
4. If issue persists >2 iterations, escalate to architect

---

## Notes

- Scene execution uses `PrefabClient.execute_scene` which is already Open3-compliant
- `PrefabControlService.trigger_scene` handles retry, latency, and audit logging
- No additional boolean coercion needed for scene execution (UUID-based)
- Webhook deduplication not applicable to scene execution (outbound action)
