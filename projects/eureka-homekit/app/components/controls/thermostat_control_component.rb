module Controls
  class ThermostatControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false)
      @accessory = accessory
      @compact = compact
      @sensors = @accessory.sensors.index_by(&:characteristic_type)
    end

    # Current temperature (read-only, stored in °C, displayed in user preference)
    # Use current_value directly (raw °C), not typed_value (which auto-converts to °F)
    def current_temp_celsius
      val = @sensors["Current Temperature"]&.current_value
      val.is_a?(Numeric) ? val.to_f : val.to_s.to_f rescue 0.0
    end

    def current_temp_fahrenheit
      TemperatureConverter.to_fahrenheit(current_temp_celsius) if current_temp_celsius
    end

    # Target temperature (writable, stored in °C)
    def target_temp_celsius
      val = @sensors["Target Temperature"]&.current_value
      val.is_a?(Numeric) ? val.to_f : val.to_s.to_f rescue 0.0
    end

    def target_temp_fahrenheit
      TemperatureConverter.to_fahrenheit(target_temp_celsius) if target_temp_celsius
    end

    # Mode state
    def target_mode
      @sensors["Target Heating/Cooling State"]&.current_value&.to_i || 0
    end

    def current_mode
      @sensors["Current Heating/Cooling State"]&.current_value&.to_i || 0
    end

    # Display unit (0=°C, 1=°F)
    def display_unit
      @sensors["Temperature Display Units"]&.current_value&.to_i == 1 ? "F" : "C"
    end

    def heating?
      current_mode == 1
    end

    def cooling?
      current_mode == 2
    end

    # Check if accessory is offline
    def offline?
      @accessory.last_seen_at.nil? || @accessory.last_seen_at < 1.hour.ago
    end

    # Slider range based on unit
    def min_temp
      display_unit == "C" ? 10 : 50
    end

    def max_temp
      display_unit == "C" ? 30 : 86
    end

    # Current displayed temperature value
    def displayed_current_temp
      display_unit == "F" ? current_temp_fahrenheit : current_temp_celsius
    end

    # Target displayed temperature value
    def displayed_target_temp
      display_unit == "F" ? target_temp_fahrenheit : target_temp_celsius
    end
  end
end
