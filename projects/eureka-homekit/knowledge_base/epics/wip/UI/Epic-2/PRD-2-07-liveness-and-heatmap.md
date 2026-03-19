#### PRD-2-07: Intelligent Event Deduplication & Room Activity Heatmap

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.

---

### Overview

Optimize database storage by removing redundant events while enhancing room-level visibility with liveness tracking and activity heatmaps. The current system stores ~34% consecutive duplicates, which bloats the database without adding value. This PRD pivots the strategy from "Store Everything" to "Log Changes + Update Metadata."

---

### Requirements

#### Functional

- **Liveness Tracking**:
  - Every incoming HomeKit event must update the `last_seen_at` timestamp on the corresponding `Sensor`, `Accessory`, and `Room`.
  - This update happens even if the event value is a duplicate and is not stored in the `HomekitEvent` table.
- **Strict Deduplication**:
  - Remove the existing 5-minute deduplication window and 15-minute heartbeat logic.
  - A `HomekitEvent` record is created ONLY if `new_value != current_value`.
- **Room Activity Monitoring**:
  - `Room#last_event_at`: Updates on every event received for any accessory in the room.
  - `Room#last_motion_at`: Updates specifically when a 'Motion Detected' sensor in the room reports activity.
- **Room Activity Heatmap (UI)**:
  - Color-coded indicator for rooms based on `last_event_at`.
  - 0-5 mins: Bright Green (Active)
  - 5-15 mins: Pale Green
  - 15-30 mins: Faded Mint
  - > 30 mins: White (Idle)
- **Sensor Value Discovery**:
  - Track all unique values seen per sensor in a `SensorValueDefinitions` table.
  - Auto-populate this table when new values are encountered.
  - Support human-readable labels for values (e.g., "0" -> "No Motion").

#### Non-Functional

- **DB Performance**: Use efficient update methods (e.g., `touch` or direct SQL) for liveness updates to avoid excessive callback overhead.
- **Real-time UI**: Heatmap colors should update dynamically without a full page refresh when new events arrive.

---

### Architectural Context

This PRD modifies the core event ingestion pipeline in `Api::HomekitEventsController`. It shifts the responsibility of "liveness" from the `HomekitEvent` log to dedicated columns on the `Sensor`, `Accessory`, and `Room` models.

---

### Acceptance Criteria

- [ ] `HomekitEvent` table contains zero consecutive duplicates for the same sensor.
- [ ] `Sensor#last_seen_at` updates on every ping, regardless of value change.
- [ ] `Room#last_event_at` updates on every ping from any accessory in that room.
- [ ] Room UI displays the correct color coding based on activity age.
- [ ] `SensorValueDefinitions` table is populated automatically when a sensor reports a value for the first time.

---

### Test Cases

#### Unit (Minitest)
- `test/controllers/api/homekit_events_controller_test.rb`: Verify that duplicate values do not create events but DO update `last_seen_at`.
- `test/models/room_test.rb`: Verify `last_event_at` and `last_motion_at` update logic.

#### System (Capybara)
- `test/system/room_activity_test.rb`: Verify room color changes in the UI when an event is received.

---

### Manual Verification

1. Trigger a sensor event with the SAME value as current.
   - **Expected**: No new `HomekitEvent` in DB; `Sensor#last_seen_at` and `Room#last_event_at` are updated.
2. Trigger a sensor event with a NEW value.
   - **Expected**: New `HomekitEvent` created; Room color turns Bright Green.
3. Wait 30 minutes.
   - **Expected**: Room color fades to White.
