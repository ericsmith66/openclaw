# frozen_string_literal: true

module EventFormattingHelper
  def formatted_event_value(event)
    return "N/A" if event.value.nil?

    # Check for human-readable label in sensor value definitions if sensor is present
    if event.sensor
      definition = event.sensor.sensor_value_definitions.find { |d| d.value == event.value.to_s }
      return definition.label if definition&.label.present?
    end

    if event.characteristic == "Current Temperature" && event.value.to_f != 0
      "#{((event.value.to_f * 9/5) + 32).round(1)}°F"
    elsif event.characteristic == "Current Relative Humidity"
      "#{event.value.to_f.round(0)}%"
    elsif event.value == true || event.value == "true"
      "ON"
    elsif event.value == false || event.value == "false"
      "OFF"
    else
      event.value.to_s
    end
  end

  def event_icon(event)
    case event.characteristic
    when "Current Temperature"
      "thermometer"
    when "Current Relative Humidity"
      "droplets"
    when "Motion Detected"
      "activity"
    when "On"
      "power"
    when "Brightness"
      "sun"
    else
      "bell"
    end
  end

  def event_severity_color(event)
    case event.severity
    when "critical" then "text-error"
    when "warning" then "text-warning"
    else "text-info"
    end
  end

  def event_summary(event)
    case event.characteristic
    when "Current Temperature"
      "Temperature: #{formatted_event_value(event)}"
    when "Current Relative Humidity"
      "Humidity: #{formatted_event_value(event)}"
    when "Motion Detected"
      event.value.to_s == "true" ? "Motion Detected" : "No Motion"
    when "On"
      "Light #{formatted_event_value(event)}"
    else
      "#{event.characteristic}: #{formatted_event_value(event)}"
    end
  end
end
