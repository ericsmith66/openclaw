# PRD-0-01 Event Deduplication Improvements - Principal Architect Feedback V1

**Review Date**: 2026-02-16  
**Reviewer**: Principal Architect  
**PRD Version**: Initial Draft  
**Status**: REQUIRES REFINEMENT

---

## Executive Summary

This PRD addresses a real pain point (duplicate events causing storage clutter and UI noise) with a well-structured approach. The overall architecture is sound, but there are **critical gaps in implementation details**, **performance concerns**, and **missing edge cases** that need to be addressed before implementation.

**Overall Rating**: ⚠️ **CONDITIONAL APPROVAL** - Requires refinements outlined below.

---

## 🎯 Strategic Alignment

### ✅ Strengths

1. **Clear Problem Statement**: The PRD articulates the pain point well with concrete examples (`1` vs `"1"`, A→B→A flips).
2. **Measured Approach**: Introduces time-based deduplication in addition to value comparison, which is pragmatic.
3. **Backward Compatibility**: Explicitly preserves echo-prevention logic and existing behavior.
4. **Observability**: Mandates INFO-level logging for debugging.

### ⚠️ Concerns

1. **Conflicting Goals**: The PRD wants to use `Sensor#type_value` but the current implementation (line 130 in controller) uses string comparison. The PRD doesn't clarify whether `type_value` should be called on both the sensor's stored value AND the incoming value.
2. **Temperature Conversion Issue**: `Sensor#type_value` (lines 83-85) converts Celsius to Fahrenheit for display, but this means a webhook value of `22.5°C` becomes `72.5°F` internally. If the incoming webhook value is already in Fahrenheit (or is numeric without units), this will cause false positives/negatives in deduplication.

---

## 🏗️ Architecture Review

### Critical Issue #1: Type Coercion Strategy is Ambiguous

**Problem**: The PRD states "compare using `Sensor#type_value`" but doesn't specify:
- Should we call `type_value` on the INCOMING webhook value?
- Should we call `type_value` on the STORED sensor value?
- What if the sensor doesn't exist yet (new sensor creation)?

**Current Implementation** (line 130):
```ruby
return false if sensor.current_value.to_s == new_value.to_s
```

**Proposed Implementation** (PRD line 57):
```ruby
# Use Sensor#type_value for comparison (with fallback to to_s on error)
```

**Issue**: `Sensor#type_value` takes a `raw_value` parameter, but the PRD doesn't show HOW to use it for comparison. The method signature is:
```ruby
def type_value(raw_value)
```

This means we need TWO calls:
```ruby
typed_current = sensor.type_value(sensor.current_value)
typed_new = sensor.type_value(new_value)
return false if typed_current == typed_new
```

**Objection**: This approach has a **temperature conversion bug**. If Prefab sends `22.5` (Celsius), `type_value` will convert it to `72.5` (Fahrenheit). But if the sensor's `current_value` is stored as `22.5`, the comparison will fail even though they're semantically identical.

**Recommended Solution**:
1. Store values in their **raw format** (as received from HomeKit) in `current_value`.
2. Add a NEW method `Sensor#compare_values(stored_value, incoming_value)` that:
   - Applies type coercion based on `value_format` (float, int, bool)
   - Does NOT apply unit conversions (Celsius→Fahrenheit)
   - Handles semantic equivalence (`"1"` == `1` == `true` for booleans)
3. Update `type_value` documentation to clarify it's for **display purposes only** (with unit conversions).

---

### Critical Issue #2: Database Query Performance Concerns

**Proposed Query** (PRD line 58):
```ruby
HomekitEvent.where(sensor_id: sensor.id, value: new_value)
  .where('timestamp > ?', RAPID_DEDUPE_WINDOW.ago)
  .exists?
```

**Performance Analysis**:

1. **Index Coverage**: The schema shows:
   - `index_homekit_events_on_sensor_id`
   - `index_homekit_events_on_timestamp`
   - BUT NO composite index on `(sensor_id, timestamp, value)`

2. **Query Plan**: PostgreSQL will likely use the `sensor_id` index, then filter by timestamp and value. For high-traffic sensors (e.g., motion detectors firing every second), this could scan thousands of rows per webhook.

3. **JSONB Comparison Issue**: The `value` column is **jsonb** (see schema.rb line 110). Comparing jsonb values requires special handling:
   ```ruby
   # This won't work efficiently:
   .where(value: new_value)
   
   # Need this:
   .where("value::text = ?", new_value.to_s)
   # OR better, use jsonb containment:
   .where("value @> ?", new_value.to_json)
   ```

**Objection**: The proposed query will be **slow** without the right index and could add 10-50ms latency per webhook.

**Recommended Solution**:
1. **Add Migration** (missing from PRD):
   ```ruby
   add_index :homekit_events, [:sensor_id, :timestamp], 
     name: 'index_homekit_events_on_sensor_and_time'
   ```
   (Note: Don't include `value` in the index due to jsonb type and cardinality)

2. **Alternative Approach**: Instead of querying `homekit_events`, store the last event timestamp on the **Sensor model**:
   ```ruby
   # Add column: last_event_stored_at
   # Then check:
   return false if sensor.last_event_stored_at && 
                   sensor.last_event_stored_at > RAPID_DEDUPE_WINDOW.ago &&
                   sensor.type_value(sensor.current_value) == sensor.type_value(new_value)
   ```
   This avoids the database query entirely and relies on in-memory comparison.

---

### Critical Issue #3: Race Conditions in Broadcast Throttling

**Proposed Implementation** (PRD line 61):
```ruby
broadcast_room_update to throttle duplicate broadcasts using Rails.cache 
with a 500 ms expiry keyed by room ID
```

**Race Condition Scenario**:
1. Webhook A arrives at `T=0ms`, checks cache (empty), broadcasts, sets cache key `room:123` → `true` with 500ms TTL
2. Webhook B arrives at `T=100ms` for SAME room, checks cache (present), skips broadcast ✅
3. Webhook C arrives at `T=600ms`, cache expired, broadcasts again
4. **BUT**: If Webhook D arrives at `T=550ms` (after cache TTL but before Webhook C processed), it will ALSO broadcast

**Objection**: Using `Rails.cache` with TTL is **not atomic**. Multiple webhooks arriving in the same 500ms window could all broadcast if they check the cache before any of them set it.

**Recommended Solution**:
1. Use **atomic cache operations**:
   ```ruby
   cache_key = "room_broadcast_throttle:#{room.id}"
   if Rails.cache.fetch(cache_key, expires_in: 500.milliseconds, race_condition_ttl: 100.milliseconds) { true }
     # Cache hit, skip broadcast
     return
   end
   # Cache miss, broadcast and cache is automatically set
   broadcast_to_channels(room, timestamp)
   ```

2. OR use **Redis SET NX** (if Redis is available):
   ```ruby
   redis_key = "room_broadcast:#{room.id}"
   if redis.set(redis_key, '1', nx: true, ex: 0.5) # atomic set-if-not-exists
     broadcast_to_channels(room, timestamp)
   end
   ```

3. **Fallback**: If cache fails, the PRD correctly says "allow broadcast" (fail-open), but this should be LOGGED at WARN level.

---

### Critical Issue #4: Sensor Lookup Logic Needs Hardening (But How?)

**PRD Requirement** (line 42):
> Ensure `find_sensor` reliably matches characteristics across `typeName`, `description`, and `localizedDescription` fields, and does not create duplicate sensor records.

**Current Implementation** (lines 57-76):
```ruby
def find_sensor
  accessory = Accessory.find_by(name: params[:accessory])
  return nil unless accessory

  # Try exact match first (characteristic_type)
  sensor = accessory.sensors.find_by(characteristic_type: params[:characteristic])
  return sensor if sensor

  # Fall back to checking if characteristic matches description in raw_data
  accessory.raw_data['services']&.each do |service|
    service['characteristics']&.each do |char|
      if char['description'] == params[:characteristic] || 
         char['localizedDescription'] == params[:characteristic]
        return accessory.sensors.find_by(characteristic_uuid: char['uniqueIdentifier'])
      end
    end
  end

  nil
end
```

**Issues**:
1. **Duplicate Sensor Creation**: `create_sensor_from_params` (lines 98-122) checks `typeName`, `description`, AND `localizedDescription` against `params[:characteristic]`, but it doesn't check if a sensor ALREADY EXISTS with the same `characteristic_uuid`. The uniqueness constraint is on `(accessory_id, characteristic_uuid)` (schema line 193), so a duplicate insert will raise an error, not silently create a duplicate.

2. **Race Condition**: If two webhooks arrive simultaneously for a NEW characteristic, BOTH will call `create_sensor_from_params`, and ONE will fail with a `ActiveRecord::RecordNotUnique` error. This is caught by the `rescue StandardError` at line 23, but the webhook will return 400 Bad Request instead of 200 OK.

**Recommended Solution**:
1. **Wrap sensor creation in `find_or_create_by`**:
   ```ruby
   Sensor.find_or_create_by!(
     accessory: accessory,
     characteristic_uuid: char['uniqueIdentifier']
   ) do |s|
     # Initialize attributes only on create
     s.service_uuid = svc['uniqueIdentifier']
     s.service_type = svc['typeName']
     # ... etc
   end
   ```

2. **Add idempotency to the webhook endpoint**: Even if sensor creation fails, if the event is a duplicate value, we should still return 200 OK (the webhook succeeded semantically).

---

## 📋 Requirements Refinement

### Functional Requirements

#### ✅ Well-Defined
- Echo prevention preservation
- Liveness timestamp updates
- Constant activation (DEDUPE_WINDOW, HEARTBEAT_INTERVAL)

#### ⚠️ Needs Clarification

1. **FR1: Typed Value Comparison** (line 39)
   - **Question**: Should `type_value` be called on BOTH the stored value and incoming value?
   - **Question**: What happens if `value_format` is `nil` (e.g., for a new sensor type)?
   - **Recommendation**: Add a section "Type Coercion Rules" with examples:
     ```
     | Stored Value | Incoming Value | Match? | Reason |
     |--------------|----------------|--------|--------|
     | "1"          | 1              | YES    | Numeric coercion |
     | "true"       | 1              | YES    | Boolean coercion |
     | "22.5"       | 22.5           | YES    | Float coercion |
     | 72.5 (°F)    | 22.5 (°C)      | ???    | Unit conversion ambiguity |
     ```

2. **FR2: Time-Based Deduplication Window** (line 40)
   - **Question**: Does "skip storing a new event" mean we return early from `handle_sensor_event`, or do we still proceed to broadcast/liveness updates?
   - **Current Code** (lines 46-54): Duplicates DO update liveness and broadcast room updates.
   - **Recommendation**: Clarify that the 1-second window is IN ADDITION TO value comparison (not a replacement).

3. **FR5: Broadcast Throttling** (line 43)
   - **Question**: What if the room has multiple sensors firing simultaneously? Should throttling be per-room or per-sensor?
   - **Example**: Motion sensor + temperature sensor both in "Living Room" within 500ms → one broadcast or two?
   - **Recommendation**: Specify that throttling is **per room, per broadcast channel** (i.e., `room_activity` and `floorplan_updates` are throttled independently).

4. **FR6: Constant Activation** (line 44)
   - **Question**: How should `DEDUPE_WINDOW` (5 minutes) and `HEARTBEAT_INTERVAL` (15 minutes) be used?
   - **Current Code**: These constants are defined but NEVER USED.
   - **Recommendation**: Add a new functional requirement:
     > "After `HEARTBEAT_INTERVAL` has passed since the last stored event for a sensor, store a heartbeat event even if the value is unchanged (to maintain liveness history)."

---

### Non-Functional Requirements

#### ✅ Well-Defined
- Performance target: "no noticeable latency"
- Maintainability: backward compatibility
- Observability: INFO-level logging

#### ⚠️ Needs Quantification

1. **NFR1: Performance** (line 48)
   - **Issue**: "No noticeable latency" is subjective. What's the SLA?
   - **Recommendation**: Specify target latencies:
     - P50: < 10ms added to webhook processing
     - P95: < 50ms added to webhook processing
     - P99: < 100ms added to webhook processing
   - **Monitoring**: Add a metric `homekit_events.deduplication_latency_ms` (currently not mentioned).

2. **NFR2: Database Indexes** (line 48)
   - **Issue**: The PRD says "verify indexes exist" but doesn't specify WHICH indexes.
   - **Current Schema**: Missing composite index on `(sensor_id, timestamp)`.
   - **Recommendation**: Add a "Database Changes" section:
     ```ruby
     # Migration: Add composite index for deduplication query
     add_index :homekit_events, [:sensor_id, :timestamp], 
       name: 'index_homekit_events_deduplication'
     ```

---

## 🐛 Edge Cases & Error Scenarios

### ✅ Well-Covered
- `type_value` raises exception → fallback to string comparison
- Database timeout → skip time-window check
- Sensor not found → store event without association
- Cache failure → allow broadcast

### ❌ Missing Edge Cases

1. **EC1: Sensor Value is NULL**
   - **Scenario**: New sensor created but `current_value` is NULL (before first event).
   - **Current Code** (line 127): `return true if sensor.current_value.nil?`
   - **Issue**: If `new_value` is also `nil`, should we store it?
   - **Recommendation**: Add test case and clarify behavior.

2. **EC2: Concurrent Webhooks for Same Sensor**
   - **Scenario**: Two webhooks arrive at T=0ms and T=10ms with different values.
   - **Issue**: Both pass the time-window check, both create events, but the sensor's `current_value` might be updated out of order.
   - **Recommendation**: Add database-level locking:
     ```ruby
     sensor.with_lock do
       should_store = should_store_event?(sensor, new_value, timestamp)
       # ...
     end
     ```
   - **Caveat**: This adds latency (10-20ms) but ensures consistency.

3. **EC3: Webhook Timestamp is in the Future**
   - **Scenario**: Prefab server clock is skewed, sends `timestamp: "2026-02-16T10:00:00Z"` but current time is `2026-02-16T09:59:00Z`.
   - **Current Code** (line 11): `timestamp = params[:timestamp] ? Time.parse(params[:timestamp]) : Time.current`
   - **Issue**: The time-window check will pass, but the event will appear "in the future" in the UI.
   - **Recommendation**: Add timestamp validation:
     ```ruby
     timestamp = params[:timestamp] ? Time.parse(params[:timestamp]) : Time.current
     if timestamp > 1.minute.from_now
       Rails.logger.warn("Webhook timestamp in future: #{timestamp}")
       timestamp = Time.current # Clamp to current time
     end
     ```

4. **EC4: Value is an Array or Complex Object**
   - **Scenario**: Some HomeKit characteristics return JSON arrays (e.g., `"value": [22.5, 50.0]` for thermostats with temperature + humidity).
   - **Current Code**: `value` is stored as JSONB, so arrays are supported.
   - **Issue**: `to_s` comparison for arrays is unreliable: `[22.5, 50.0].to_s == "[22.5, 50.0]"` but order might differ.
   - **Recommendation**: Add array comparison logic in `compare_values`:
     ```ruby
     if typed_current.is_a?(Array) && typed_new.is_a?(Array)
       return typed_current.sort == typed_new.sort # Order-independent comparison
     end
     ```

5. **EC5: Sensor is Deleted While Webhook is in Flight**
   - **Scenario**: User deletes a sensor via the UI, then a webhook arrives for that sensor.
   - **Current Code**: `sensor = find_sensor || create_sensor_from_params(timestamp)` will recreate it.
   - **Issue**: Is this desired behavior?
   - **Recommendation**: Add a `deleted_at` soft-delete column to sensors, and skip recreation for deleted sensors.

---

## 🧪 Testing Strategy Review

### ✅ Good Coverage
- Unit tests for `should_store_event?`
- Integration tests for webhook endpoint
- Typed value comparison tests

### ⚠️ Gaps in Test Cases

1. **Missing: Race Condition Tests**
   - **Test**: Simulate two webhooks arriving simultaneously using threads or `Concurrent::Promise`.
   - **Expected**: One event stored, no duplicate sensors created.

2. **Missing: Performance Tests**
   - **Test**: Benchmark deduplication query with 1M existing events.
   - **Expected**: < 10ms query time with proper indexes.

3. **Missing: Broadcast Throttling Tests**
   - **Test**: Send 5 webhooks within 500ms for the same room.
   - **Expected**: Only 1 broadcast (or 2 if cache operations aren't atomic).

4. **Missing: Temperature Conversion Tests**
   - **Test**: Send `22.5°C` webhook, then send `72.5°F` webhook.
   - **Expected**: Both should be treated as duplicates (if conversion is applied consistently).

5. **Missing: HEARTBEAT_INTERVAL Tests**
   - **Test**: Mock time advancing by 16 minutes, send duplicate value.
   - **Expected**: Event is stored (heartbeat).
   - **Issue**: PRD doesn't implement this feature, so tests would fail.

---

## 📝 Implementation Notes Review

### ✅ Clear Guidance
- Primary file identified (`homekit_events_controller.rb`)
- Specific methods to modify
- Database index verification

### ⚠️ Missing Details

1. **Database Migration** (line 64)
   - **Issue**: PRD says "verify indexes exist" but doesn't provide migration code.
   - **Recommendation**: Add migration to implementation plan:
     ```ruby
     class AddDeduplicationIndexToHomekitEvents < ActiveRecord::Migration[8.1]
       def change
         add_index :homekit_events, [:sensor_id, :timestamp], 
           name: 'index_homekit_events_deduplication',
           algorithm: :concurrently
       end
     end
     ```

2. **Cache Configuration** (line 61)
   - **Issue**: `Rails.cache` behavior depends on cache store (Memory, Redis, Memcached).
   - **Recommendation**: Add configuration guidance:
     ```ruby
     # config/environments/production.rb
     config.cache_store = :redis_cache_store, {
       url: ENV['REDIS_URL'],
       expires_in: 1.hour,
       race_condition_ttl: 100.milliseconds # For atomic operations
     }
     ```

3. **Sensor#compare_values Method** (NEW)
   - **Recommendation**: Add this to implementation notes:
     ```ruby
     # app/models/sensor.rb
     def compare_values(stored_value, incoming_value)
       typed_stored = type_value(stored_value)
       typed_incoming = type_value(incoming_value)
       
       # Handle nil
       return true if typed_stored.nil? && typed_incoming.nil?
       return false if typed_stored.nil? || typed_incoming.nil?
       
       # Numeric comparison with epsilon for floats
       if typed_stored.is_a?(Numeric) && typed_incoming.is_a?(Numeric)
         return (typed_stored - typed_incoming).abs < 0.01
       end
       
       # Boolean comparison
       if [true, false].include?(typed_stored) && [true, false].include?(typed_incoming)
         return typed_stored == typed_incoming
       end
       
       # String comparison (case-insensitive)
       typed_stored.to_s.casecmp?(typed_incoming.to_s)
     end
     ```

---

## 🚀 Rollout / Deployment Concerns

### ⚠️ Missing Considerations

1. **Feature Flag**
   - **Issue**: Rolling out new deduplication logic to production could cause unexpected behavior.
   - **Recommendation**: Add a feature flag:
     ```ruby
     # config/initializers/feature_flags.rb
     ENABLE_TYPED_DEDUPLICATION = ENV.fetch('ENABLE_TYPED_DEDUPLICATION', 'false') == 'true'
     
     # In controller:
     if ENABLE_TYPED_DEDUPLICATION
       return false if sensor.compare_values(sensor.current_value, new_value)
     else
       return false if sensor.current_value.to_s == new_value.to_s # Old behavior
     end
     ```

2. **Gradual Rollout**
   - **Recommendation**: Deploy in phases:
     - Phase 1: Deploy to staging, monitor for 1 week
     - Phase 2: Deploy to production with feature flag OFF, verify no regressions
     - Phase 3: Enable feature flag for 10% of sensors (based on `sensor.id % 10 == 0`)
     - Phase 4: Enable for all sensors after 1 week of monitoring

3. **Rollback Plan**
   - **Issue**: PRD says "revert changes to controller" but doesn't mention data cleanup.
   - **Recommendation**: If the new logic creates MORE events (false negatives), rolling back won't delete those events. Add a cleanup script:
     ```ruby
     # script/cleanup_duplicate_events.rb
     # Find events that would have been deduplicated by the old logic
     # (This is a dry-run script, requires manual review before deletion)
     ```

---

## 🎯 Acceptance Criteria Review

### ✅ Testable Criteria
- AC1, AC2, AC3, AC5, AC7: Clear, testable

### ⚠️ Ambiguous Criteria

1. **AC4: Broadcast Throttling** (line 95)
   - **Issue**: "if the same sensor value is received within 500 ms" → Does this mean:
     - Option A: Any event for the same sensor?
     - Option B: Any event for the same room?
     - Option C: Any event with the same value for the same sensor?
   - **Recommendation**: Clarify wording:
     > "AC4: Room/floorplan broadcasts are throttled: if ANY sensor event for a room occurs within 500 ms of the last broadcast for that room, no new broadcast is sent to the `room_activity` or `floorplan_updates` channels."

2. **AC6: Logging** (line 96)
   - **Issue**: "enough context to debug" is subjective.
   - **Recommendation**: Specify required fields:
     ```
     [INFO] Skipping duplicate event: sensor_id=123, old_value=22.5, new_value=22.5, reason=value_match
     [INFO] Skipping duplicate event: sensor_id=123, old_value=22.5, new_value=22.5, reason=time_window (last_event=900ms ago)
     [INFO] Storing event: sensor_id=123, old_value=22.5, new_value=23.0, reason=value_change
     ```

---

## 🏛️ Architectural Recommendations

### Recommendation #1: Introduce a DeduplicationService

**Rationale**: The `should_store_event?` method is getting complex. Extract it into a service object for better testability and separation of concerns.

**Proposed Structure**:
```ruby
# app/services/event_deduplication_service.rb
class EventDeduplicationService
  def initialize(sensor, new_value, timestamp)
    @sensor = sensor
    @new_value = new_value
    @timestamp = timestamp
  end
  
  def should_store?
    return true if @sensor.nil? # Always store if no sensor yet
    return true if @sensor.current_value.nil? # Always store first value
    
    # Value change check
    return true unless values_match?
    
    # Time window check
    return true if heartbeat_due?
    
    # Echo prevention check
    return true if echo_prevention_passed?
    
    # All checks failed, skip storage
    Rails.logger.info(log_message('duplicate_skipped'))
    false
  end
  
  private
  
  def values_match?
    @sensor.compare_values(@sensor.current_value, @new_value)
  end
  
  def heartbeat_due?
    # Implement HEARTBEAT_INTERVAL logic here
    @sensor.last_updated_at < HEARTBEAT_INTERVAL.ago
  end
  
  def echo_prevention_passed?
    # Move echo prevention logic here
  end
  
  def log_message(reason)
    # Structured logging
  end
end
```

**Benefits**:
- Easier to test in isolation
- Cleaner controller code
- Can add more deduplication strategies without touching controller

---

### Recommendation #2: Add Metrics Dashboard

**Rationale**: The PRD mentions logging but doesn't address how to monitor deduplication effectiveness.

**Proposed Metrics**:
1. `homekit_events.received_total` (counter)
2. `homekit_events.stored_total` (counter)
3. `homekit_events.deduplicated_total` (counter, with reason label: `value_match`, `time_window`, `echo_prevention`)
4. `homekit_events.deduplication_latency_ms` (histogram)
5. `room_broadcasts.throttled_total` (counter)

**Implementation**:
```ruby
# Use StatsD, Prometheus, or built-in Rails instrumentation
ActiveSupport::Notifications.instrument('homekit_events.deduplicated', 
  sensor_id: sensor.id, 
  reason: 'value_match'
)
```

---

### Recommendation #3: Consider Event Sourcing Pattern

**Rationale**: The current approach stores deduplicated events in `homekit_events` but loses information about what was deduplicated. For debugging and auditing, it might be valuable to keep a record of ALL incoming webhooks (even if they don't create events).

**Proposed Addition**:
- Keep `homekit_events` for deduplicated events (as is)
- Add new table `webhook_logs` to store ALL incoming webhooks:
  ```ruby
  create_table :webhook_logs do |t|
    t.bigint :sensor_id
    t.jsonb :raw_payload
    t.datetime :received_at
    t.boolean :stored, default: false # Whether it created a HomekitEvent
    t.string :skip_reason # 'value_match', 'time_window', 'echo_prevention'
    t.index [:sensor_id, :received_at]
  end
  ```

**Benefits**:
- Full audit trail for debugging
- Can retroactively analyze deduplication effectiveness
- Can replay events if deduplication logic changes

**Tradeoffs**:
- Additional storage costs (mitigated by retention policy: keep 7 days)
- Small latency overhead (INSERT is fast)

---

## 🔥 Critical Blockers (Must Fix Before Implementation)

1. **BLOCKER #1**: Clarify `type_value` usage for comparison (see Critical Issue #1)
2. **BLOCKER #2**: Add database migration for composite index (see Critical Issue #2)
3. **BLOCKER #3**: Fix broadcast throttling race condition (see Critical Issue #3)
4. **BLOCKER #4**: Handle temperature unit conversion ambiguity (see Critical Issue #1)
5. **BLOCKER #5**: Add `find_or_create_by` to avoid sensor duplication (see Critical Issue #4)

---

## ✅ Recommendations Summary

### High Priority (P0) - Must Address Before Implementation
1. ✏️ Add migration for `index_homekit_events_deduplication`
2. ✏️ Clarify `type_value` comparison logic with concrete examples
3. ✏️ Fix broadcast throttling to use atomic cache operations
4. ✏️ Add `Sensor#compare_values` method to avoid temperature conversion bugs
5. ✏️ Replace sensor creation with `find_or_create_by!`

### Medium Priority (P1) - Strongly Recommended
6. 📊 Add performance metrics and monitoring
7. 🧪 Add race condition tests (concurrent webhooks)
8. 📝 Specify performance SLA (P50/P95/P99 latencies)
9. 🔄 Implement `HEARTBEAT_INTERVAL` logic (or remove the constant)
10. 🚩 Add feature flag for gradual rollout

### Low Priority (P2) - Nice to Have
11. 🏗️ Extract deduplication logic to `EventDeduplicationService`
12. 📋 Add `webhook_logs` table for full audit trail
13. 🧹 Add cleanup script for rollback scenarios
14. 🔒 Add database locking to prevent race conditions
15. ⏰ Add timestamp validation (reject future timestamps)

---

## 📋 Revised Implementation Checklist

Before coding begins, the PRD should be updated to include:

- [ ] **Section: Type Coercion Rules** (table with examples)
- [ ] **Section: Database Changes** (migration code)
- [ ] **Section: Sensor#compare_values Implementation** (code snippet)
- [ ] **Section: Performance SLA** (P50/P95/P99 targets)
- [ ] **Section: Monitoring & Metrics** (list of metrics to track)
- [ ] **Updated AC4**: Clarify broadcast throttling scope (per-room vs per-sensor)
- [ ] **Updated AC6**: Specify required log fields
- [ ] **New AC8**: Performance - P95 latency < 50ms for deduplication check
- [ ] **New AC9**: No race conditions - concurrent webhooks for same sensor handled gracefully
- [ ] **Test Case**: Add race condition test
- [ ] **Test Case**: Add temperature conversion test
- [ ] **Test Case**: Add broadcast throttling concurrency test
- [ ] **Error Scenario**: Add "concurrent sensor creation" scenario
- [ ] **Error Scenario**: Add "future timestamp" scenario
- [ ] **Error Scenario**: Add "complex value (array)" scenario

---

## 🎓 Lessons for Future PRDs

1. **Specify HOW to use existing methods**: Don't just say "use `Sensor#type_value`" - show the actual code pattern.
2. **Include migration code**: Don't say "verify indexes exist" - provide the migration.
3. **Quantify performance requirements**: Don't say "no noticeable latency" - specify P50/P95/P99.
4. **Consider concurrency**: Always think about race conditions in webhook/API endpoints.
5. **Test the tests**: Ensure test cases cover edge cases, not just happy paths.

---

## ✅ Final Verdict

**CONDITIONAL APPROVAL**: This PRD is **80% ready** for implementation but requires the following refinements:

### Before Implementation Can Start:
1. Address all 5 critical blockers listed above
2. Update PRD with clarifications on type coercion logic
3. Add database migration to PRD or implementation plan
4. Specify performance SLA and monitoring strategy

### Estimated Refinement Time: 4-6 hours
### Estimated Implementation Time (after refinement): 16-24 hours

Once the above refinements are made, this PRD will be architecturally sound and ready for development.

---

**Architect Sign-Off**: Pending revisions  
**Next Review**: After PRD updates addressing blockers 1-5
