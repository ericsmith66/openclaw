#### PRD-3-03: Real-time Heatmap & Sensor Injection

**Log Requirements**
- Junie: read the Junie log requirement doc (if present) and create/update a task log under `knowledge_base/prds-junie-log/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-3-03-heatmap-sensor-injection-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

This PRD describes the visualization layer that overlays real-time sensor activity onto the floorplan. It transforms the static map into a "living" dashboard by color-coding rooms based on recent activity (motion/occupancy) and displaying current environmental data (temperature/humidity) through dynamic badges.

---

### Requirements

#### Functional

- **Activity Scoring Logic**:
  - **Active**: Motion detected in the last 5 minutes (Bright Red/Orange + **Glowing Pulse**).
  - **Warm**: Occupancy detected or motion 5-15 mins ago (Yellow/Gold).
  - **Cold**: No activity for > 15 minutes (Blue/Neutral).
- **SVG CSS Injection**: Dynamically apply CSS classes to SVG room elements based on their current activity score to change `fill` colors.
- **Glowing Pulse**: Implement a subtle CSS animation (glowing pulse) for rooms currently detecting active motion.
- **Real-time Updates**: Integrate with ActionCable to update room colors and sensor values instantly as events occur.
- **Room Stat Badges**: Inject small HTML badges over the floorplan regions to display temperature and humidity values.

#### Non-Functional

- **Visual Clarity**: Ensure the heatmap colors are semi-transparent so the underlying blueprint remains legible.
- **Battery/Performance**: Avoid excessive DOM updates; only update elements when state changes.

#### Rails / Implementation Notes (optional)

- **Models**: `Sensor`, `SensorValue`.
- **ActionCable**: Broadcast room state changes to the `FloorplanChannel`.
- **Stimulus**: Controller to receive broadcasts and update the viewer DOM.

---

### Error Scenarios & Fallbacks

- **Stale Data** → If no sensor update has been received for > 1 hour, grey out the sensor badge or show a "stale" indicator.
- **Missing Sensor Type** → If a room lacks a temperature sensor, simply don't show that stat in the badge.

---

### Architectural Context

This PRD builds upon the infrastructure from PRD 3-01 and the viewer from PRD 3-02. It adds the "dynamic" layer of the floorplan.

---

### Acceptance Criteria

- [ ] Rooms change color according to their activity score.
- [ ] Active motion triggers a glowing pulse effect in the corresponding room.
- [ ] Temperature and humidity values are displayed correctly over the rooms.
- [ ] UI updates in real-time when a motion sensor is triggered (verified via logs/simulated events).

---

### Test Cases

#### Unit (Minitest)

- `test/models/room_activity_score_test.rb`: Test the logic that calculates the "heat" level based on sensor timestamps.

#### Integration (Minitest)

- `test/channels/floorplan_channel_test.rb`: Test that room state updates are correctly broadcasted via ActionCable.

---

### Manual Verification

1. Open the Floorplan view.
2. Trigger a motion event for a specific room (e.g., via a script or physical sensor).
3. Observe the room turning Red/Orange and starting to pulse.
4. Verify that the temperature stat badge updates when a new temperature reading is received.

**Expected**
- Immediate visual feedback on sensor events.
- Smooth transitions between activity states.

---

### Rollout / Deployment Notes (optional)

- Ensure the ActionCable server is properly configured to handle the broadcast load of multiple concurrent users viewing the floorplan.
- Start with a simple 3-tier color system (Cold, Warm, Active).
