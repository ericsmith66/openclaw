# frozen_string_literal: true

module Controls
  class BlindControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false)
      @accessory = accessory
      @compact = compact
      @sensors = @accessory.sensors.index_by(&:characteristic_type)

      @position_sensor = @sensors["Target Position"] || @sensors["Current Position"]
      @tilt_sensor = @sensors["Target Horizontal Tilt Angle"] || @sensors["Current Horizontal Tilt Angle"]
      @obstruction_sensor = @sensors["Obstruction Detected"]
    end

    private

    attr_reader :accessory, :compact, :position_sensor, :tilt_sensor, :obstruction_sensor

    def current_position
      return 0 unless @position_sensor
      @position_sensor.typed_value.to_i
    end

    def current_tilt
      return 0 unless @tilt_sensor
      @tilt_sensor.typed_value.to_i
    end

    def has_tilt?
      @tilt_sensor.present?
    end

    def obstruction_detected?
      return false unless @obstruction_sensor
      @obstruction_sensor.boolean_value? || @obstruction_sensor.current_value.to_s.downcase.in?(%w[true on yes 1])
    end

    def offline?
      @accessory.sensors.any? { |sensor| sensor.last_seen_at.present? && sensor.last_seen_at < 1.hour.ago }
    end

    def size_class
      @compact ? "range-sm" : "range-md"
    end
  end
end
