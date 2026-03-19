# frozen_string_literal: true

class Sensors::CardComponent < ViewComponent::Base
  def initialize(sensor:, show_chart: false, compact: false)
    @sensor = sensor
    @show_chart = show_chart
    @compact = compact
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

  def status_color
    if @sensor.offline?
      "error"
    elsif @sensor.characteristic_type == "Battery Level" && @sensor.typed_value.to_f < 20
      "warning"
    else
      "success"
    end
  end
end
