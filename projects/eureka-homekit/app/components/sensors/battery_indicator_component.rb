# frozen_string_literal: true

class Sensors::BatteryIndicatorComponent < ViewComponent::Base
  def initialize(level:, charging: false, low_threshold: 20)
    @level = level.to_f
    @charging = charging
    @low_threshold = low_threshold
  end

  def color_class
    if @level < @low_threshold
      "text-error"
    elsif @level < 50
      "text-warning"
    else
      "text-success"
    end
  end

  def battery_icon
    if @charging
      "battery-charging"
    elsif @level < 10
      "battery-low"
    elsif @level < 30
      "battery-medium"
    else
      "battery-full"
    end
  end
end
