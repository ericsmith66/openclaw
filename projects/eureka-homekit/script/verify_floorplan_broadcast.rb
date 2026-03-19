
# Verification script for Floorplan real-time updates
begin
  room = Room.first
  unless room
    puts "No Room found. Please create one first."
    exit
  end

  timestamp = Time.current
  puts "Simulating broadcast for Room: #{room.name} (ID: #{room.id})"

  # Trigger the same logic as HomekitEventsController#broadcast_room_update
  # We need to extend with RoomHelper to use helpers.room_heatmap_class
  # or just call it directly if we have access to helpers in console.

  # In a real controller, 'helpers' is available. In a script, we can do:
  view_context = ApplicationController.new.view_context

  payload = {
    room_id: room.id,
    room_name: room.name,
    heatmap_class: view_context.room_heatmap_class(room),
    sensor_states: FloorplanMappingService.new(nil).extract_sensor_states(room)
  }

  puts "Payload: #{payload.inspect}"

  ActionCable.server.broadcast("floorplan_updates", payload)
  puts "Broadcast sent to 'floorplan_updates' channel."
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
