<!--
  PRD Template

  Copy this file into your epic directory and rename using the repo convention:
    knowledge_base/epics/wip/<Program>/<Epic-N>/PRD-<N>-<XX>-<slug>.md

  This template is based on the structure used in Epic 4 PRDs, e.g.:
    knowledge_base/epics/wip/NextGen/Epic-4/PRD-4-01-saprun-schema-persona-config.md
-->

#### PRD-0-01: Event Deduplication Improvements

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `{{source-document}}-feedback-V{{N}}.md` in the same directory as the source document.

---
 
### Overview

The Prefab server occasionally sends duplicate events or "noise" where the same value is reported multiple times. The current deduplication logic in `HomekitEventsController#should_store_event?` uses simple string comparison (`to_s`) which fails to catch semantic duplicates (e.g., `1` vs `"1"` vs `true` vs `"true"`). Additionally, there is no time‑based deduplication window, so rapid A→B→A value flips are stored as three separate events, and room/floorplan broadcasts are triggered even when the value hasn’t changed, causing unnecessary front‑end noise.

This PRD defines enhancements to the deduplication system to:
1. **Use typed value comparison** (leveraging `Sensor#type_value`) instead of string comparison.
2. **Introduce a short time‑based deduplication window** (1‑second) to suppress rapid duplicate events.
3. **Improve sensor lookup consistency** to avoid creating duplicate sensor records.
4. **Throttle room/floorplan broadcasts** when the underlying sensor value hasn’t changed.
5. **Activate the already‑defined `DEDUPE_WINDOW` and `HEARTBEAT_INTERVAL` constants** that are currently unused.

These changes will reduce storage clutter, decrease front‑end noise, and improve the perceived reliability of the event stream.

---

### Requirements

#### Functional

- **Typed value comparison**: When deciding whether to store an event, compare the incoming value with the sensor’s current value using `Sensor#type_value` (which handles numeric, boolean, and string coercion) instead of `to_s`.
- **Time‑based deduplication window**: If the same typed value has been recorded for this sensor within the last 1 second (configurable via `RAPID_DEDUPE_WINDOW` constant), skip storing a new event (but still update liveness timestamps).
- **Echo prevention preservation**: Maintain the existing echo‑prevention check that skips events that match a recent successful control command (within 5 seconds).
- **Sensor lookup hardening**: Ensure `find_sensor` reliably matches characteristics across `typeName`, `description`, and `localizedDescription` fields, and does not create duplicate sensor records for the same physical characteristic.
- **Broadcast throttling**: When a duplicate value is received, still update liveness (`last_seen_at`, `last_event_at`) but **do not** broadcast a room/floorplan update unless at least 500 ms have passed since the last broadcast for that room.
- **Constant activation**: Use the existing `DEDUPE_WINDOW` (5 minutes) and `HEARTBEAT_INTERVAL` (15 minutes) constants where appropriate (e.g., for heartbeat‑style updates that should be stored even if the value is unchanged).

#### Non-Functional

- **Performance**: Deduplication checks must not add noticeable latency to webhook processing. All database queries must be indexed (`sensor_id`, `timestamp`, `value`).
- **Maintainability**: Changes must be backward compatible; existing events and sensor data must remain valid.
- **Observability**: Log deduplication decisions at `INFO` level (e.g., “skipping duplicate value 22.5 for sensor 123”) to aid debugging.

#### Rails / Implementation Notes (optional)

- **Primary file**: `app/controllers/api/homekit_events_controller.rb`
  - Add `RAPID_DEDUPE_WINDOW = 1.second` constant.
  - Modify `should_store_event?` to:
    1. Use `Sensor#type_value` for comparison (with fallback to `to_s` on error).
    2. Check for recent duplicate values within `RAPID_DEDUPE_WINDOW` using `HomekitEvent.where(sensor_id: sensor.id, value: new_value).where('timestamp > ?', RAPID_DEDUPE_WINDOW.ago).exists?`
    3. Preserve the existing echo‑prevention check (query to `ControlEvent`).
  - Update `broadcast_room_update` to throttle duplicate broadcasts using `Rails.cache` with a 500 ms expiry keyed by room ID.
  - Refactor `find_sensor` to be more robust and avoid duplicate sensor creation.
- **Supporting models**: `app/models/sensor.rb`
  - Ensure `type_value` handles all HomeKit value formats correctly; add defensive error handling.
- **Database**: Verify indexes exist on `homekit_events` (`sensor_id`, `timestamp`) and `sensors` (`accessory_id`, `characteristic_uuid`). Add composite index on `homekit_events` (`sensor_id`, `value`, `timestamp`) if needed for performance.
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
- Changing the Prefab server’s behavior.
- Introducing a full‑featured event‑stream processing pipeline (e.g., Kafka).
- Modifying the front‑end to handle duplicate events.

---

### Acceptance Criteria

- [ ] **AC1**: Identical values that differ only in type (e.g., `1` vs `"1"`, `true` vs `"true"`) are treated as duplicates and no new `HomekitEvent` is created.
- [ ] **AC2**: When the same typed value arrives within 1 second of a previous event for the same sensor, no new `HomekitEvent` is created (but liveness timestamps are updated).
- [ ] **AC3**: Sensor lookup (`find_sensor`) never creates a duplicate sensor record for the same `characteristic_uuid` within an accessory.
- [ ] **AC4**: Room/floorplan broadcasts are throttled: if the same sensor value is received within 500 ms, no broadcast is sent to the `room_activity` or `floorplan_updates` channels.
- [ ] **AC5**: A new constant `RAPID_DEDUPE_WINDOW` (default 1 second) is defined and used for the rapid duplicate check, while the existing `DEDUPE_WINDOW` (5 minutes) remains available for future use.
- [ ] **AC6**: All deduplication decisions are logged at `INFO` level with enough context to debug (sensor ID, old/new values, reason for skipping).
- [ ] **AC7**: Existing tests pass, and new unit/integration tests cover the enhanced deduplication logic.

---

### Test Cases

#### Unit (RSpec)

- `spec/controllers/api/homekit_events_controller_spec.rb` (new file):
  - `should_store_event?` returns `false` for semantically identical values.
  - `should_store_event?` returns `false` when same value arrives within 1 second.
  - `should_store_event?` returns `true` when value changes.
  - `should_store_event?` returns `true` when sensor is `nil`.
  - `broadcast_room_update` throttles duplicate broadcasts within 500 ms.
- `spec/models/sensor_spec.rb` (extend existing):
  - `type_value` correctly coerces numeric, boolean, and string values.

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
4. **Check Rails logs** for “skipping duplicate value” message.
5. **Verify in the database** that only one `HomekitEvent` was created:
   ```bash
   rails runner "puts HomekitEvent.where(accessory_name: 'Front Door').count"
   ```
6. **Repeat with a different value** (e.g., `23.0`) and confirm a new event is stored.
7. **Open the event log UI** (`/events`) and confirm no duplicate rows appear for the repeated value.
8. **Monitor the floorplan viewer** (if available) and verify room highlights do not flicker on duplicate values.

**Expected**
- Duplicate values (same semantic value) create only one `HomekitEvent`.
- Liveness timestamps (`sensors.last_seen_at`, `rooms.last_event_at`) are updated on every ping.
- Room/floorplan broadcasts are not triggered for duplicates within 500 ms.
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
