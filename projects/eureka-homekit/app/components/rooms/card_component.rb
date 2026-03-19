class Rooms::CardComponent < ViewComponent::Base
  include RoomHelper

  def initialize(room:, compact: false)
    @room = room
    @compact = compact
  end

  private

  attr_reader :room, :compact

  def accessory_count
    room.accessories.size
  end

  def sensor_count
    room.sensors.size
  end

  def live_sensors
    # Use preloaded association if available
    room.sensors.select { |s| s.accessory_id.present? }.first(3)
  end

  def room_icon
    # Logic to return icon based on room name or metadata
    case room.name.downcase
    when /bedroom/ then "bed"
    when /kitchen/ then "utensils"
    when /living/ then "sofa"
    when /bath/ then "bath"
    when /garage/ then "car"
    when /garden|yard|porch/ then "tree-pine"
    else "door-open"
    end
  end

  def status_color
    room_activity_color(room)
  end

  def activity_text_color
    room_activity_text_color(room)
  end
end
