# frozen_string_literal: true

class Sensors::DetailComponent < ViewComponent::Base
  def initialize(sensor:, events:, time_range: "24h")
    @sensor = sensor
    @events = events
    @time_range = time_range
  end

  def type_icon
    case @sensor.characteristic_type
    when "Current Temperature" then "thermometer"
    when "Motion Detected" then "move"
    when "Current Relative Humidity" then "droplets"
    when "Current Ambient Light Level" then "sun"
    when "Battery Level" then "battery"
    when "Contact Sensor State" then "door-closed"
    when "Occupancy Detected" then "user"
    else "activity"
    end
  end
end
