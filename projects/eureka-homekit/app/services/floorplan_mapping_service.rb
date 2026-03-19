class FloorplanMappingService
  def initialize(floorplan)
    @floorplan = floorplan
  end

  def resolve
    return {} unless @floorplan&.mapping_file&.attached?

    mapping_data = JSON.parse(@floorplan.mapping_file.download)
    resolve_mapping(mapping_data)
  end

  private

  def resolve_mapping(mapping_data)
    # mapping_data format: { "SVG_ID_OR_GROUP": { "room_id": 123, "level": 1 } }
    # We want to return: { "SVG_ID_OR_GROUP": { "room": RoomObject, "sensor_states": {...} } }

    resolved = {}

    # Preload rooms to avoid N+1
    room_ids = mapping_data.values.map { |v| v["room_id"] }.compact.uniq
    rooms = Room.includes(:sensors).where(id: room_ids).index_by(&:id)

    mapping_data.each do |svg_id, metadata|
      room_id = metadata["room_id"]
      room = rooms[room_id]

      if room
        resolved[svg_id] = {
          room: room,
          sensor_states: extract_sensor_states(room)
        }
      else
        Rails.logger.warn "FloorplanMappingService: Room #{room_id} not found for SVG element #{svg_id}"
        resolved[svg_id] = { error: "Room not found", room_id: room_id }
      end
    end

    resolved
  end

  def extract_sensor_states(room)
    # Extract latest values for key sensor types
    {
      temperature: room.sensors.temperature.first&.typed_value,
      humidity: room.sensors.humidity.first&.typed_value,
      motion: room.sensors.motion.first&.typed_value,
      occupancy: room.sensors.occupancy.first&.typed_value,
      last_motion_at: room.last_motion_at,
      last_event_at: room.last_event_at
    }
  end
  public :extract_sensor_states
end
