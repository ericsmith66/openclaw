<!--
  PRD Template - REFINED VERSION

  This is the Principal Architect refined version of PRD-0-01.
  Original PRD: PRD-0-01-event-deduplication-improvements.md
  Feedback: PRD-0-01-event-deduplication-improvements-feedback-V1.md
-->

#### PRD-0-01: Event Deduplication Improvements (REFINED)

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---
 
### Overview

The Prefab server occasionally sends duplicate events or "noise" where the same value is reported multiple times. The current deduplication logic in `HomekitEventsController#should_store_event?` uses simple string comparison (`to_s`) which fails to catch semantic duplicates (e.g., `1` vs `"1"` vs `true` vs `"true"`). Additionally, there is no time‑based deduplication window, so rapid A→B→A value flips are stored as three separate events, and room/floorplan broadcasts are triggered even when the value hasn't changed, causing unnecessary front‑end noise.

This PRD defines enhancements to the deduplication system to:
1. **Use typed value comparison** (via new `Sensor#compare_values` method) instead of string comparison.
2. **Introduce a short time‑based deduplication window** (1‑second) to suppress rapid duplicate events.
3. **Improve sensor lookup consistency** to avoid creating duplicate sensor records.
4. **Throttle room/floorplan broadcasts** when the underlying sensor value hasn't changed.
5. **Activate the already‑defined `DEDUPE_WINDOW` and `HEARTBEAT_INTERVAL` constants** that are currently unused.

These changes will reduce storage clutter, decrease front‑end noise, and improve the perceived reliability of the event stream.

---

### Requirements

#### Functional

- **FR1: Typed value comparison**: When deciding whether to store an event, compare the incoming value with the sensor's current value using a NEW method `Sensor#compare_values(stored_value, incoming_value)` which handles numeric, boolean, and string coercion WITHOUT applying unit conversions (e.g., Celsius→Fahrenheit). This avoids the bug where `type_value` converts temperatures for display purposes.
  
  **Type Coercion Rules**:
  | Stored Value | Incoming Value | Match? | Reason |
  |--------------|----------------|--------|--------|
  | `"1"`        | `1`            | YES    | Numeric coercion |
  | `"true"`     | `1`            | YES    | Boolean coercion (1 == true) |
  | `"22.5"`     | `22.5`         | YES    | Float coercion |
  | `22.5`       | `22.50001`     | YES    | Float comparison with epsilon (0.01) |
  | `"ON"`       | `"on"`         | YES    | Case-insensitive string comparison |
  | `[1, 2]`     | `[2, 1]`       | NO     | Array comparison is order-sensitive (future enhancement) |

- **FR2: Time‑based deduplication window**: If the same typed value has been recorded for this sensor within the last 1 second (configurable via `RAPID_DEDUPE_WINDOW` constant), skip storing a new event (but still update liveness timestamps). **Note**: This check is IN ADDITION TO value comparison (not a replacement). Both conditions must be met to skip storage.

- **FR3: Echo prevention preservation**: Maintain the existing echo‑prevention check that skips events that match a recent successful control command (within 5 seconds). This prevents feedback loops when HomeKit echoes back commands we sent.

- **FR4: Sensor lookup hardening**: Update `create_sensor_from_params` to use `find_or_create_by!` with the `characteristic_uuid` to prevent race conditions that could create duplicate sensor records for the same physical characteristic.

- **FR5: Broadcast throttling**: When ANY sensor event for a room occurs within 500 ms of the last broadcast for that room, do NOT broadcast a new room/floorplan update. Use atomic cache operations (fetch with race_condition_ttl) to prevent race conditions where multiple webhooks trigger multiple broadcasts. Throttling is per-room, not per-sensor.

- **FR6: Heartbeat storage**: When `HEARTBEAT_INTERVAL` (15 minutes) has passed since the last stored event for a sensor, store a new event EVEN IF the value is unchanged. This maintains liveness history for sensors that don't frequently change values (e.g., thermostats in stable environments).

#### Non-Functional

- **NFR1: Performance**: Deduplication checks must meet the following SLA:
  - **P50**: < 10ms added latency to webhook processing
  - **P95**: < 50ms added latency to webhook processing
  - **P99**: < 100ms added latency to webhook processing
  
  To achieve this:
  - Add composite index on `homekit_events (sensor_id, timestamp)` for time-window queries
  - Consider storing `last_event_stored_at` on the Sensor model to avoid database queries entirely
  - Use `sensor.with_lock` for concurrent webhook handling (adds 10-20ms but ensures consistency)

- **NFR2: Maintainability**: Changes must be backward compatible; existing events and sensor data must remain valid.

- **NFR3: Observability**: Log deduplication decisions at `INFO` level with structured data:
  ```
  [INFO] Event stored: sensor_id=123, old_value=22.5, new_value=23.0, reason=value_changed
  [INFO] Event skipped: sensor_id=123, old_value=22.5, new_value=22.5, reason=value_match
  [INFO] Event skipped: sensor_id=123, old_value=22.5, new_value=22.5, reason=time_window, time_since_last=900ms
  [INFO] Event skipped: sensor_id=123, old_value=1, new_value=1, reason=echo_prevention, control_event_id=456
  ```
  
- **NFR4: Monitoring**: Track the following metrics (via StatsD, Prometheus, or Rails instrumentation):
  - `homekit_events.received_total` (counter)
  - `homekit_events.stored_total` (counter)
  - `homekit_events.deduplicated_total` (counter, with reason label)
  - `homekit_events.deduplication_latency_ms` (histogram)
  - `room_broadcasts.throttled_total` (counter)

#### Rails / Implementation Notes

- **Primary file**: `app/controllers/api/homekit_events_controller.rb`
  - Add `RAPID_DEDUPE_WINDOW = 1.second` constant.
  - Modify `should_store_event?` to:
    1. Call `sensor.compare_values(sensor.current_value, new_value)` for typed comparison (with fallback to string comparison on error).
    2. Check if heartbeat is due: `sensor.last_updated_at < HEARTBEAT_INTERVAL.ago` → store event even if value matches.
    3. Check for recent duplicate values within time window (see alternative approach below).
    4. Preserve the existing echo‑prevention check (query to `ControlEvent`).
  - Update `broadcast_room_update` to use atomic cache throttling:
    ```ruby
    cache_key = "room_broadcast_throttle:#{room.id}"
    return if Rails.cache.fetch(cache_key, expires_in: 500.milliseconds, race_condition_ttl: 100.milliseconds) { true }
    # Proceed with broadcast (cache is automatically set by fetch block)
    ```
  - Update `create_sensor_from_params` to use `find_or_create_by!` to prevent race conditions:
    ```ruby
    Sensor.find_or_create_by!(
      accessory: accessory,
      characteristic_uuid: char['uniqueIdentifier']
    ) do |sensor|
      sensor.service_uuid = svc['uniqueIdentifier']
      sensor.service_type = svc['typeName']
      # ... initialize other attributes
    end
    ```

- **Supporting models**: `app/models/sensor.rb`
  - Add NEW method `compare_values(stored_value, incoming_value)` for deduplication (see implementation below).
  - Keep existing `type_value` method unchanged (it's used for display purposes with unit conversions).
  - **Implementation**:
    ```ruby
    def compare_values(stored_value, incoming_value)
      # Coerce both values using value_format, but WITHOUT unit conversions
      typed_stored = coerce_value_without_conversion(stored_value)
      typed_incoming = coerce_value_without_conversion(incoming_value)
      
      return true if typed_stored.nil? && typed_incoming.nil?
      return false if typed_stored.nil? || typed_incoming.nil?
      
      # Numeric comparison with epsilon for floats
      if typed_stored.is_a?(Numeric) && typed_incoming.is_a?(Numeric)
        return (typed_stored - typed_incoming).abs < 0.01
      end
      
      # Boolean comparison (handles "1", 1, true, "true")
      if [true, false].include?(typed_stored) && [true, false].include?(typed_incoming)
        return typed_stored == typed_incoming
      end
      
      # String comparison (case-insensitive)
      typed_stored.to_s.casecmp?(typed_incoming.to_s)
    rescue StandardError => e
      Rails.logger.warn("compare_values failed for sensor #{id}: #{e.message}")
      stored_value.to_s == incoming_value.to_s # Fallback
    end
    
    private
    
    def coerce_value_without_conversion(raw_value)
      return nil if raw_value.nil?
      
      case value_format
      when 'float' then raw_value.to_f
      when 'int', 'uint8' then raw_value.to_i
      when 'bool'
        raw_value.to_s == '1' || raw_value.to_s.downcase == 'true'
      else
        # Try to infer if it's numeric
        if raw_value.is_a?(String) && raw_value.match?(/^-?\d+(\.\d+)?$/)
          raw_value.include?('.') ? raw_value.to_f : raw_value.to_i
        else
          raw_value
        end
      end
    end
    ```

- **Database Migration** (REQUIRED):
  ```ruby
  class AddDeduplicationIndexToHomekitEvents < ActiveRecord::Migration[8.1]
    disable_ddl_transaction! # For concurrent index creation
    
    def change
      add_index :homekit_events, [:sensor_id, :timestamp], 
        name: 'index_homekit_events_deduplication',
        algorithm: :concurrently
    end
  end
  ```

- **Alternative Approach (Recommended)**: Instead of querying `homekit_events` for the time window check, add a column `last_event_stored_at` to the `sensors` table and check it in-memory:
  ```ruby
  # Migration
  add_column :sensors, :last_event_stored_at, :datetime
  add_index :sensors, :last_event_stored_at
  
  # Controller logic
  return false if sensor.last_event_stored_at && 
                  sensor.last_event_stored_at > RAPID_DEDUPE_WINDOW.ago &&
                  sensor.compare_values(sensor.current_value, new_value)
  
  # After storing event
  sensor.update_columns(last_event_stored_at: timestamp)
  ```

- **Cache Configuration**: Ensure Rails cache is configured for production (add to `config/environments/production.rb` if not present):
  ```ruby
  config.cache_store = :redis_cache_store, {
    url: ENV['REDIS_URL'],
    expires_in: 1.hour,
    race_condition_ttl: 100.milliseconds
  }
  ```

- **Front‑end**: No changes required to Stimulus controllers; the reduction in broadcast noise will automatically improve UI responsiveness.

---

### Error Scenarios & Fallbacks

- **`compare_values` raises an exception** → Fall back to string comparison (`to_s`) and log a warning at WARN level.
- **Database query for recent duplicates times out** → Skip the time‑window check (store the event) and log an error at ERROR level.
- **Sensor cannot be found or created** → Store the event without a sensor association (current behavior).
- **Broadcast throttling cache fails** (Redis/Memcached unavailable) → Allow the broadcast to proceed (fail-open) and log a warning at WARN level.
- **Concurrent webhooks for same sensor** → Use `sensor.with_lock` to serialize updates. If lock timeout occurs (rare), store both events (accept the duplicate rather than risk data loss).
- **Webhook timestamp is in the future** (clock skew) → Clamp timestamp to `Time.current` if it's more than 1 minute in the future, and log a warning.
- **Duplicate sensor creation race condition** → Caught by uniqueness constraint on `(accessory_id, characteristic_uuid)`. Retry sensor lookup once, then fail gracefully if it still can't be found.
- **Value is complex type (array/object)** → Compare using string representation (`to_s`). Future enhancement: deep equality for arrays/hashes.

---

### Architectural Context

The deduplication logic sits in the webhook endpoint (`POST /api/homekit/events`) that receives real‑time updates from Prefab. It is the gatekeeper for what enters the `HomekitEvent` table and what triggers real‑time UI updates via ActionCable.

- **Upstream**: Prefab server (HomeKit bridge) sends JSON payloads.
- **Downstream**: `HomekitEvent` records, `Sensor` state updates, ActionCable broadcasts to the event log, room sidebar, and floorplan viewer.
- **Key boundaries**: The deduplication logic must not block the webhook response; long‑running checks should be deferred to background jobs (not required for this PRD).

**Non‑goals**:
- Changing the Prefab server's behavior.
- Introducing a full‑featured event‑stream processing pipeline (e.g., Kafka).
- Modifying the front‑end to handle duplicate events.

---

### Acceptance Criteria

- [ ] **AC1**: Identical values that differ only in type (e.g., `1` vs `"1"`, `true` vs `"true"`) are treated as duplicates and no new `HomekitEvent` is created. Verified by comparing `sensor.compare_values("1", 1)` → true.
- [ ] **AC2**: When the same typed value arrives within 1 second of a previous event for the same sensor, no new `HomekitEvent` is created (but liveness timestamps are updated). Verified by checking `sensor.last_event_stored_at` vs current time.
- [ ] **AC3**: Sensor lookup (`find_sensor`) never creates a duplicate sensor record for the same `characteristic_uuid` within an accessory. Verified by checking database uniqueness constraint is not violated under concurrent webhook load.
- [ ] **AC4**: Room/floorplan broadcasts are throttled: if ANY sensor event for a room occurs within 500 ms of the last broadcast for that room, no new broadcast is sent to the `room_activity` or `floorplan_updates` channels. Verified by monitoring ActionCable broadcast count vs webhook count.
- [ ] **AC5**: A new constant `RAPID_DEDUPE_WINDOW` (default 1 second) is defined and used for the rapid duplicate check. A heartbeat event is stored every `HEARTBEAT_INTERVAL` (15 minutes) even if the value is unchanged.
- [ ] **AC6**: All deduplication decisions are logged at `INFO` level with structured fields: `sensor_id`, `old_value`, `new_value`, `reason` (one of: `value_changed`, `value_match`, `time_window`, `echo_prevention`, `heartbeat_due`).
- [ ] **AC7**: Existing tests pass, and new unit/integration tests cover the enhanced deduplication logic.
- [ ] **AC8**: Performance SLA met - P95 latency for deduplication check is < 50ms. Verified by instrumentation/profiling.
- [ ] **AC9**: No race conditions - concurrent webhooks for the same sensor are handled gracefully without raising errors or creating duplicate sensors. Verified by load testing with parallel requests.

---

### Test Cases

#### Unit (RSpec)

- `spec/controllers/api/homekit_events_controller_spec.rb` (new file):
  - `should_store_event?` returns `false` for semantically identical values (e.g., "1" vs 1, "true" vs 1).
  - `should_store_event?` returns `false` when same value arrives within 1 second.
  - `should_store_event?` returns `true` when value changes.
  - `should_store_event?` returns `true` when sensor is `nil`.
  - `should_store_event?` returns `true` when heartbeat interval has passed (even if value matches).
  - `broadcast_room_update` throttles duplicate broadcasts within 500 ms (atomic cache test).
- `spec/models/sensor_spec.rb` (extend existing):
  - `compare_values` returns `true` for semantically identical values (numeric, boolean, string).
  - `compare_values` returns `false` when values differ.
  - `compare_values` handles float comparison with epsilon tolerance (0.01).
  - `compare_values` is case-insensitive for strings.
  - `compare_values` falls back to string comparison on error.
  - `type_value` correctly coerces values WITH unit conversion (for display purposes).

#### Integration (RSpec)

- `spec/requests/api/homekit_events_deduplication_spec.rb` (extend existing RSpec file):
  - Webhook endpoint stores event when value changes.
  - Webhook endpoint skips event when value is duplicate (typed comparison: "1" vs 1).
  - Webhook endpoint skips event when duplicate arrives within 1 second (time window).
  - Webhook endpoint stores event when heartbeat interval has passed (even if value matches).
  - Liveness timestamps (`last_seen_at`, `last_event_at`) are updated even for duplicates.
  - Room broadcasts are not sent for duplicate values within throttling window (500ms).
  - Concurrent webhooks for the same sensor do not create duplicate sensors (thread safety test).
  - Performance test: 100 webhooks complete within 5 seconds (50ms average per webhook).

#### System / Smoke (Capybara)

- `spec/system/event_deduplication_smoke_spec.rb` (new):
  - Simulate a series of duplicate webhook payloads via `curl` or `Net::HTTP`.
  - Verify event count does not increase.
  - Verify UI (event log) does not show duplicate rows.

---

### Manual Verification

Provide step‑by‑step instructions a human can follow.

1. **Start the Rails server** in development mode: `bin/dev`
2. **Trigger a sensor event** (example using `curl`):
   ```bash
   curl -X POST http://localhost:3000/api/homekit/events \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer sk_live_eureka_abc123xyz789" \
     -d '{"type":"characteristic_updated","accessory":"Front Door","characteristic":"Current Temperature","value":22.5}'
   ```
3. **Immediately send the same event again** (same command).
4. **Check Rails logs** for "Event skipped" message with `reason=value_match`.
5. **Verify in the database** that only one `HomekitEvent` was created:
   ```bash
   rails runner "puts HomekitEvent.where(accessory_name: 'Front Door').count"
   ```
6. **Test type coercion**: Send the same temperature as an integer:
   ```bash
   curl -X POST http://localhost:3000/api/homekit/events \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer sk_live_eureka_abc123xyz789" \
     -d '{"type":"characteristic_updated","accessory":"Front Door","characteristic":"Current Temperature","value":22}'
   ```
   Verify it's treated as a duplicate (22.0 == 22.5 is false, but 22 should not create a new event if it matches stored value).
7. **Test heartbeat**: Wait 16 minutes or mock time travel, send same value, verify new event is stored.
8. **Repeat with a different value** (e.g., `23.0`) and confirm a new event is stored.
9. **Open the event log UI** (`/events`) and confirm no duplicate rows appear for the repeated value.
10. **Monitor the floorplan viewer** (if available) and verify room highlights do not flicker on duplicate values.

**Expected**
- Duplicate values (same semantic value) create only one `HomekitEvent`.
- Liveness timestamps (`sensors.last_seen_at`, `rooms.last_event_at`) are updated on every ping.
- Room/floorplan broadcasts are not triggered for duplicates within 500 ms.
- Heartbeat events are stored every 15 minutes regardless of value changes.
- All existing functionality (value changes, new sensors, error handling) continues to work.

---

### Rollout / Deployment Notes

- **Database Migrations**: 
  1. Add composite index: `add_index :homekit_events, [:sensor_id, :timestamp]` (run with `algorithm: :concurrently` to avoid locking).
  2. (Optional but recommended) Add column: `add_column :sensors, :last_event_stored_at, :datetime`.

- **Monitoring / Alerting**: 
  - Track `homekit_events.deduplicated_total` metric by reason (value_match, time_window, echo_prevention).
  - Alert if deduplication rate > 80% (may indicate Prefab server issues).
  - Alert if P95 latency > 50ms (performance degradation).

- **Feature Flag** (Recommended for gradual rollout):
  ```ruby
  # config/initializers/feature_flags.rb
  ENABLE_TYPED_DEDUPLICATION = ENV.fetch('ENABLE_TYPED_DEDUPLICATION', 'false') == 'true'
  ```
  - Phase 1: Deploy to staging with flag enabled, monitor for 1 week.
  - Phase 2: Deploy to production with flag disabled (no behavior change).
  - Phase 3: Enable flag for 10% of sensors (based on `sensor.id % 10 == 0`).
  - Phase 4: Enable for all sensors after 1 week of monitoring.

- **Rollback Plan**: 
  1. Set `ENABLE_TYPED_DEDUPLICATION=false` (if using feature flag).
  2. Revert code changes to `homekit_events_controller.rb` and `sensor.rb`.
  3. Database indexes can remain (they don't affect old behavior).
  4. If new logic created FEWER events (false positives), rolling back won't recover lost events.
  5. If new logic created MORE events (false negatives), consider running cleanup script:
     ```ruby
     # script/cleanup_duplicate_events.rb (DRY RUN)
     # Identifies events that would have been deduplicated by new logic
     # Requires manual review before deletion
     ```

- **Configuration**: Ensure `config/environments/production.rb` has Redis cache configured for broadcast throttling.

---

### Architectural Recommendations (Optional Enhancements)

#### 1. Extract Deduplication Logic to Service Object

For better testability and separation of concerns, consider extracting `should_store_event?` into:
```ruby
# app/services/event_deduplication_service.rb
class EventDeduplicationService
  def initialize(sensor, new_value, timestamp)
    @sensor = sensor
    @new_value = new_value
    @timestamp = timestamp
  end
  
  def should_store?
    # Deduplication logic here
  end
end
```

#### 2. Add Webhook Audit Trail

Consider adding a `webhook_logs` table to store ALL incoming webhooks (even deduplicated ones) for debugging:
```ruby
create_table :webhook_logs do |t|
  t.bigint :sensor_id
  t.jsonb :raw_payload
  t.datetime :received_at
  t.boolean :stored, default: false
  t.string :skip_reason
  t.index [:sensor_id, :received_at]
end
```

---

### Changes from Original PRD

1. **Added `Sensor#compare_values` method** to avoid temperature conversion bug in `type_value`.
2. **Added database migration** for composite index on `(sensor_id, timestamp)`.
3. **Specified performance SLA** (P50/P95/P99 latencies).
4. **Added structured logging format** with required fields.
5. **Added metrics/monitoring requirements** (counters, histograms).
6. **Clarified broadcast throttling** is per-room, not per-sensor, with atomic cache operations.
7. **Added heartbeat storage logic** using `HEARTBEAT_INTERVAL`.
8. **Updated sensor creation** to use `find_or_create_by!` to prevent race conditions.
9. **Added AC8 and AC9** for performance and race condition testing.
10. **Added feature flag and phased rollout plan** for risk mitigation.
11. **Added error scenarios** for edge cases (future timestamps, concurrent webhooks, etc.).
12. **Added Type Coercion Rules table** with concrete examples.
