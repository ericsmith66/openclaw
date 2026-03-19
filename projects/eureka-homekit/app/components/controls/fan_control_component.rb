module Controls
  class FanControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false)
      @accessory = accessory
      @compact = compact
      @sensors = @accessory.sensors.index_by(&:characteristic_type)
    end

    # Fan Active state (HomeKit spec)
    # 0 = inactive, 1 = active
    def active?
      @sensors["Active"]&.boolean_value? || false
    end

    # Rotation Speed (0-100)
    def current_speed
      @sensors["Rotation Speed"]&.current_value&.to_i || 0
    end

    # Rotation Direction (HomeKit spec)
    # 0 = clockwise, 1 = counterclockwise
    def current_direction
      @sensors["Rotation Direction"]&.current_value&.to_i || 0
    end

    def clockwise?
      current_direction == 0
    end

    def counterclockwise?
      current_direction == 1
    end

    # Swing Mode / Oscillation (HomeKit spec)
    # 0 = disabled, 1 = enabled
    def oscillating?
      @sensors["Swing Mode"]&.boolean_value? || false
    end

    # Feature detection
    def has_direction?
      @sensors["Rotation Direction"].present?
    end

    def has_oscillation?
      @sensors["Swing Mode"].present?
    end

    def supports_direction?
      has_direction?
    end

    def supports_oscillation?
      has_oscillation?
    end

    # State icon
    def state_icon
      if active?
        oscillating? ? "🌀" : "💨"
      else
        "⭕"
      end
    end

    # State text
    def state_text
      return "Off" unless active?
      return "On - #{current_speed}%" if current_speed > 0

      "On"
    end

    # Check if accessory is offline
    def offline?
      @accessory.sensors.any? { |sensor| sensor.last_seen_at.present? && sensor.last_seen_at < 1.hour.ago }
    end

    def compact?
      @compact
    end

    private

    attr_reader :accessory, :compact, :sensors
  end
end
