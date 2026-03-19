# Manual Testing Guide: PRD-3-03 Heatmap & Sensor Injection

This document provides steps to manually verify the real-time heatmap and sensor injection features on the floorplan.

## Prerequisites

- Ensure the Rails server is running (`bin/dev`).
- Ensure ActionCable is working.
- A Home with a Floorplan and mapped Rooms must exist.

## Test Scenarios

### 1. Initial Heatmap State
1. Open the Dashboard and switch to **Floorplan** view.
2. Observe the room colors:
   - Rooms with no recent activity should be **light blue** (Cold).
   - Rooms with activity > 15 mins ago should also be **light blue**.

### 2. Real-time Motion (Heatmap & Pulse)
1. Keep the Floorplan view open in your browser.
2. In a terminal, open the Rails console: `rails c`.
3. Find a room that is mapped on your floorplan:
   ```ruby
   room = Room.find_by(name: "Kitchen") # Replace with your room name
   ```
4. Simulate a motion event by calling the `broadcast_room_update` logic (or triggering a real webhook event if possible):
   ```ruby
   # Simulate motion detected NOW
   room.update!(last_motion_at: Time.current, last_event_at: Time.current)
   
   # Trigger broadcast (manually using the helper logic)
   helper = Object.new.extend(RoomHelper)
   ActionCable.server.broadcast("floorplan_updates", {
     room_id: room.id,
     heatmap_class: helper.room_heatmap_class(room),
     sensor_states: FloorplanMappingService.new(nil).extract_sensor_states(room)
   })
   ```
5. **Observation**:
   - The room on the floorplan should immediately turn **Red** (Active).
   - The room should start **pulsing** (fade in/out).
   - The room label badge should show a **red dot** pulsing.

### 3. Real-time Temperature/Humidity Updates
1. In the Rails console, simulate a temperature update:
   ```ruby
   sensor = room.sensors.temperature.first
   sensor.update!(current_value: 75.5)
   
   # Broadcast update
   helper = Object.new.extend(RoomHelper)
   ActionCable.server.broadcast("floorplan_updates", {
     room_id: room.id,
     heatmap_class: helper.room_heatmap_class(room),
     sensor_states: FloorplanMappingService.new(nil).extract_sensor_states(room)
   })
   ```
2. **Observation**:
   - The temperature value in the room's label badge should update to **76°** (rounded).
   - If you hover over the room, the info panel should show **Temperature: 75.5°F**.

### 4. Transition to "Warm" State
1. In the Rails console, simulate that motion happened 10 minutes ago:
   ```ruby
   room.update!(last_motion_at: 10.minutes.ago, last_event_at: 10.minutes.ago)
   
   # Broadcast
   helper = Object.new.extend(RoomHelper)
   ActionCable.server.broadcast("floorplan_updates", {
     room_id: room.id,
     heatmap_class: helper.room_heatmap_class(room),
     sensor_states: FloorplanMappingService.new(nil).extract_sensor_states(room)
   })
   ```
2. **Observation**:
   - The room should turn **Orange** (Warm).
   - The pulsing effect should **stop**.
   - The red dot in the badge should **disappear**.

### 5. Transition to "Cold" State
1. In the Rails console, simulate that activity happened 20 minutes ago:
   ```ruby
   room.update!(last_motion_at: 20.minutes.ago, last_event_at: 20.minutes.ago)
   
   # Broadcast
   helper = Object.new.extend(RoomHelper)
   ActionCable.server.broadcast("floorplan_updates", {
     room_id: room.id,
     heatmap_class: helper.room_heatmap_class(room),
     sensor_states: FloorplanMappingService.new(nil).extract_sensor_states(room)
   })
   ```
2. **Observation**:
   - The room should turn back to **light blue** (Cold).

## Troubleshooting
- If no updates appear, check the browser console for ActionCable connection errors.
- Ensure the `room_id` in the broadcast matches the `data-room-id` attribute on the SVG element (you can inspect the DOM to verify).
