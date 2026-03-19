module Controls
  class LightControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false)
      @accessory = accessory
      @compact = compact
      @on_sensor = @accessory.sensors.find_by(characteristic_type: "On")
      @brightness_sensor = @accessory.sensors.find_by(characteristic_type: "Brightness")
      @hue_sensor = @accessory.sensors.find_by(characteristic_type: "Hue")
      @saturation_sensor = @accessory.sensors.find_by(characteristic_type: "Saturation")
    end

    def on?
      @on_sensor&.boolean_value?
    end

    def brightness
      @brightness_sensor&.typed_value&.to_i || 100
    end

    def hue
      @hue_sensor&.typed_value&.to_i || 0
    end

    def saturation
      @saturation_sensor&.typed_value&.to_i || 100
    end

    def offline?
      @accessory.sensors.any? { |s| s.last_seen_at.present? && s.last_seen_at < 1.hour.ago }
    end

    def supports_dimming?
      @brightness_sensor.present?
    end

    def supports_color?
      @hue_sensor.present? && @saturation_sensor.present?
    end

    def has_color?
      supports_color?
    end

    def support_state?
      @on_sensor.present?
    end

    def compact?
      @compact
    end

    private

    def current_on_state
      return false unless @on_sensor
      @on_sensor.current_value == "true"
    end
  end
end
