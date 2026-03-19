module Controls
  class SwitchControlComponent < ViewComponent::Base
    def initialize(accessory:, size: "md", compact: false)
      @accessory = accessory
      @size = size
      @compact = compact
      @on_sensor = @accessory.sensors.find_by(characteristic_type: "On")
    end

    def current_state
      return false unless @on_sensor
      @on_sensor.boolean_value?
    end

    def offline?
      @accessory.last_seen_at.nil? || @accessory.last_seen_at < 1.hour.ago
    end

    def size_class
      case @size
      when "lg" then "toggle-lg"
      when "sm" then "toggle-sm"
      else "toggle"
      end
    end
  end
end
