#### PRD-5-01: Prefab Write API Integration

**Log Requirements**
- Junie: Create/update a task log under `knowledge_base/prds-junie-log/PRD-5-01-prefab-write-api-log.md`.
- Include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-5-01-prefab-write-api-feedback-V1.md` in the same directory.

---

### Overview

The Prefab proxy currently supports read-only operations via its REST API. To enable interactive controls, we need to extend the `PrefabClient` service to support write operations (PUT/POST) for setting characteristic values and triggering scenes. This PRD establishes the foundational write capability that all subsequent control PRDs depend on.

The service will handle characteristic updates (e.g., turn on light, set temperature, lock door) and scene execution while providing robust error handling, retry logic, and observability for control actions.

---

### Requirements

#### Functional

- Extend `PrefabClient` with method: `update_characteristic(home, room, accessory, characteristic, value)`
- Add method: `execute_scene(home, scene_uuid)`
- Support all writable HomeKit characteristic types (On, Brightness, Target Temperature, Lock Target State, etc.)
- Return structured response with success/failure status and error details
- Retry failed requests once before returning error
- Log all write attempts (success and failure) with full context

#### Non-Functional

- Write operations complete in <500ms (95th percentile)
- Handle concurrent writes gracefully (no race conditions)
- Thread-safe for multi-user scenarios
- Timeout after 5 seconds (configurable via ENV)
- Fail gracefully when Prefab proxy is unreachable

#### Rails / Implementation Notes

- **Service**: `app/services/prefab_control_service.rb` (new)
- **Extended Service**: `app/services/prefab_client.rb` (add write methods)
- **Model**: `app/models/control_event.rb` (new) - log user-initiated control actions
- **Migration**: `db/migrate/YYYYMMDDHHMMSS_create_control_events.rb`
- **Routes**: None (service-only PRD)
- **ENV Vars**:
  - `PREFAB_API_URL` (existing)
  - `PREFAB_WRITE_TIMEOUT` (default: 5000ms)
  - `PREFAB_RETRY_ATTEMPTS` (default: 1)

---

### Error Scenarios & Fallbacks

- **Prefab proxy unreachable** → Return `{ success: false, error: "Connection failed" }`, log error
- **Invalid characteristic value** → Return `{ success: false, error: "Invalid value" }`, log warning
- **Accessory offline** → Return `{ success: false, error: "Device offline" }`, log info
- **Timeout** → Retry once, then return `{ success: false, error: "Timeout" }`, log error
- **Unknown characteristic** → Return `{ success: false, error: "Unknown characteristic" }`, log warning
- **Scene not found** → Return `{ success: false, error: "Scene not found" }`, log warning

---

### Architectural Context

This PRD extends the existing `PrefabClient` service (Epic 1 PRD 1.2) by adding write capabilities. The service maintains the same error handling patterns and logging strategy but introduces a new `ControlEvent` model to track user-initiated actions separately from the sensor-driven `HomekitEvent` records.

The `PrefabControlService` wrapper provides a higher-level interface for controllers and components, handling retries, logging, and response normalization. Direct calls to `PrefabClient` write methods are discouraged—always use `PrefabControlService`.

**Non-goals**:
- No UI components (covered in PRDs 5-02 through 5-08)
- No authentication/authorization (single-user assumption)
- No batch operations (covered in PRD 5-08)

---

### Acceptance Criteria

- [ ] `PrefabClient.update_characteristic` successfully sets writable characteristic values via Prefab API
- [ ] `PrefabClient.execute_scene` triggers scenes via Prefab API
- [ ] All write operations return structured response: `{ success: Boolean, value: Any, error: String }`
- [ ] Failed writes are retried once before returning error
- [ ] All control attempts logged to `ControlEvent` model with full context
- [ ] Errors logged to `Rails.logger` with severity: error (connection), warning (validation), info (offline)
- [ ] Write operations complete in <500ms (95th percentile) under normal conditions
- [ ] Service handles concurrent writes without race conditions
- [ ] Minitest tests cover success and all error scenarios

---

### Implementation Details

#### Database Schema: `control_events`

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_control_events.rb
class CreateControlEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :control_events do |t|
      t.references :accessory, foreign_key: true, null: true
      t.references :scene, foreign_key: true, null: true
      t.string :action_type, null: false # "set_characteristic" | "execute_scene"
      t.string :characteristic_name
      t.string :old_value
      t.string :new_value
      t.boolean :success, null: false, default: true
      t.string :error_message
      t.float :latency_ms
      t.string :user_ip
      t.timestamps
    end

    add_index :control_events, :action_type
    add_index :control_events, :success
    add_index :control_events, :created_at
  end
end
```

#### Service: `app/services/prefab_client.rb` (extend existing)

```ruby
# Add to existing PrefabClient class
class PrefabClient
  # Existing read methods...

  # Update a characteristic value
  def self.update_characteristic(home, room, accessory, characteristic, value)
    url = "#{BASE_URL}/accessories/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(room)}/#{ERB::Util.url_encode(accessory)}/#{ERB::Util.url_encode(characteristic)}"

    payload = { value: value }.to_json
    result = execute_curl_put(url, payload)

    if result[:success]
      { success: true, value: value }
    else
      Rails.logger.error("PrefabClient: update_characteristic failed - #{result[:error]}")
      { success: false, error: result[:error] }
    end
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    { success: false, error: e.message }
  end

  # Execute a scene
  def self.execute_scene(home, scene_uuid)
    url = "#{BASE_URL}/scenes/#{ERB::Util.url_encode(home)}/#{ERB::Util.url_encode(scene_uuid)}/execute"

    result = execute_curl_post(url)

    if result[:success]
      { success: true }
    else
      Rails.logger.error("PrefabClient: execute_scene failed - #{result[:error]}")
      { success: false, error: result[:error] }
    end
  rescue StandardError => e
    Rails.logger.error("PrefabClient error: #{e.message}")
    { success: false, error: e.message }
  end

  private

  def self.execute_curl_put(url, payload)
    start_time = Time.now
    result = `curl -s -m 5 -X PUT -H "Content-Type: application/json" -d '#{payload}' "#{url}"`
    success = $?.success?
    latency = ((Time.now - start_time) * 1000).round(2)

    unless success
      Rails.logger.error("PrefabClient: curl PUT failed with exit code #{$?.exitstatus}")
    end

    { success: success, result: result, latency_ms: latency, error: success ? nil : "HTTP #{$?.exitstatus}" }
  end

  def self.execute_curl_post(url)
    start_time = Time.now
    result = `curl -s -m 5 -X POST "#{url}"`
    success = $?.success?
    latency = ((Time.now - start_time) * 1000).round(2)

    unless success
      Rails.logger.error("PrefabClient: curl POST failed with exit code #{$?.exitstatus}")
    end

    { success: success, result: result, latency_ms: latency, error: success ? nil : "HTTP #{$?.exitstatus}" }
  end
end
```

#### Service: `app/services/prefab_control_service.rb` (new)

```ruby
class PrefabControlService
  # Set a characteristic value with retry and logging
  def self.set_characteristic(accessory:, characteristic:, value:, user_ip: nil)
    home = accessory.room.home.name
    room = accessory.room.name
    accessory_name = accessory.name

    old_value = accessory.sensors.find_by(characteristic_type: characteristic)&.current_value
    start_time = Time.now

    # First attempt
    result = PrefabClient.update_characteristic(home, room, accessory_name, characteristic, value)

    # Retry once on failure
    unless result[:success]
      sleep(0.5)
      result = PrefabClient.update_characteristic(home, room, accessory_name, characteristic, value)
    end

    latency = ((Time.now - start_time) * 1000).round(2)

    # Log control event
    ControlEvent.create!(
      accessory: accessory,
      action_type: 'set_characteristic',
      characteristic_name: characteristic,
      old_value: old_value,
      new_value: value,
      success: result[:success],
      error_message: result[:error],
      latency_ms: latency,
      user_ip: user_ip
    )

    result
  end

  # Execute a scene with retry and logging
  def self.trigger_scene(scene:, user_ip: nil)
    home = scene.home.name
    scene_uuid = scene.uuid
    start_time = Time.now

    # First attempt
    result = PrefabClient.execute_scene(home, scene_uuid)

    # Retry once on failure
    unless result[:success]
      sleep(0.5)
      result = PrefabClient.execute_scene(home, scene_uuid)
    end

    latency = ((Time.now - start_time) * 1000).round(2)

    # Log control event
    ControlEvent.create!(
      scene: scene,
      action_type: 'execute_scene',
      success: result[:success],
      error_message: result[:error],
      latency_ms: latency,
      user_ip: user_ip
    )

    result
  end
end
```

#### Model: `app/models/control_event.rb` (new)

```ruby
class ControlEvent < ApplicationRecord
  belongs_to :accessory, optional: true
  belongs_to :scene, optional: true

  validates :action_type, presence: true, inclusion: { in: %w[set_characteristic execute_scene] }
  validates :success, inclusion: { in: [true, false] }

  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :recent, -> { order(created_at: :desc).limit(100) }
  scope :for_accessory, ->(accessory_id) { where(accessory_id: accessory_id) }
  scope :for_scene, ->(scene_id) { where(scene_id: scene_id) }

  def self.success_rate(time_range = 24.hours.ago)
    where('created_at >= ?', time_range).group(:success).count
  end

  def self.average_latency(time_range = 24.hours.ago)
    where('created_at >= ?', time_range).average(:latency_ms)
  end
end
```

---

### Test Cases

#### Unit (Minitest)

- **spec/services/prefab_client_spec.rb**:
  - `update_characteristic` success case (returns `{ success: true, value: ... }`)
  - `update_characteristic` failure cases (timeout, invalid value, device offline)
  - `execute_scene` success case
  - `execute_scene` failure cases (scene not found, timeout)
  - URL encoding of parameters
  - Error logging on failures

- **spec/services/prefab_control_service_spec.rb**:
  - `set_characteristic` success with logging
  - `set_characteristic` failure with retry
  - `set_characteristic` logs ControlEvent with correct attributes
  - `trigger_scene` success with logging
  - `trigger_scene` failure with retry
  - Latency tracking is accurate

- **spec/models/control_event_spec.rb**:
  - Validations (action_type, success)
  - Associations (accessory, scene)
  - Scopes (successful, failed, recent, for_accessory, for_scene)
  - `success_rate` calculation
  - `average_latency` calculation

#### Integration (Minitest)

- **test/integration/prefab_control_service_test.rb**:
  - End-to-end control flow (set characteristic → verify log → check response)
  - Scene execution flow (trigger scene → verify log → check response)
  - Concurrent control requests (no race conditions)

---

### Manual Verification

1. Start Prefab proxy: `cd prefab-listener && ruby agent.rb`
2. Start Rails server: `bin/rails server`
3. Open Rails console: `bin/rails console`
4. Find a writable accessory:
   ```ruby
   light = Accessory.joins(:sensors).where(sensors: { characteristic_type: 'On' }).first
   ```
5. Attempt to turn on the light:
   ```ruby
   result = PrefabControlService.set_characteristic(accessory: light, characteristic: 'On', value: true)
   ```
6. Verify result:
   ```ruby
   result[:success] # should be true
   ControlEvent.last # should show the control attempt
   ```
7. Check Prefab proxy logs for PUT request
8. Find a scene:
   ```ruby
   scene = Scene.first
   ```
9. Trigger the scene:
   ```ruby
   result = PrefabControlService.trigger_scene(scene: scene)
   ```
10. Verify scene execution in Prefab proxy logs

**Expected**
- Control operations return structured responses
- ControlEvent records created for all attempts
- Prefab proxy logs show incoming PUT/POST requests
- Retry logic activates on failures
- Latency values are reasonable (<500ms)

---

### Rollout / Deployment Notes

- **Migration**: Run `bin/rails db:migrate` to create `control_events` table
- **Monitoring**: Add dashboard for control success rate and latency (future PRD)
- **Logging**: Ensure `Rails.logger` level is `:info` or lower to capture control logs
- **Performance**: `control_events` table will grow quickly—consider retention policy (30 days)
- **Indexing**: Database indexes on `control_events` (action_type, success, created_at) for fast queries
