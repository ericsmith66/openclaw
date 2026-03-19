# frozen_string_literal: true

module Controls
  class GarageDoorControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false)
      @accessory = accessory
      @compact = compact
      @sensors = @accessory.sensors.index_by(&:characteristic_type)

      @current_state_sensor = @sensors["Current Door State"]
      @target_state_sensor = @sensors["Target Door State"]
      @obstruction_sensor = @sensors["Obstruction Detected"]
      @lock_sensor = @sensors["Lock Current State"]
    end

    private

    attr_reader :accessory, :compact, :current_state_sensor, :target_state_sensor, :obstruction_sensor, :lock_sensor

    # Door States (per HAP spec):
    # 0 = Open
    # 1 = Closed
    # 2 = Opening
    # 3 = Closing
    # 4 = Stopped
    def current_state
      return 4 unless @current_state_sensor
      @current_state_sensor.typed_value.to_i
    end

    def target_state
      return 1 unless @target_state_sensor
      @target_state_sensor.typed_value.to_i
    end

    def state_text
      case current_state
      when 0 then "Open"
      when 1 then "Closed"
      when 2 then "Opening"
      when 3 then "Closing"
      when 4 then "Stopped"
      else "Unknown"
      end
    end

    def state_icon
      case current_state
      when 0 then "🔓"  # Open
      when 1 then "🔒"  # Closed
      when 2 then "⬆️"  # Opening
      when 3 then "⬇️"  # Closing
      when 4 then "⏸️"  # Stopped
      else "❓"
      end
    end

    def state_color_class
      case current_state
      when 0 then "text-warning"    # Open (warning - security concern)
      when 1 then "text-success"    # Closed (safe)
      when 2, 3 then "text-info"    # In motion
      when 4 then "text-error"      # Stopped (potential issue)
      else "text-base-content"
      end
    end

    def obstruction_detected?
      return false unless @obstruction_sensor
      @obstruction_sensor.boolean_value? || @obstruction_sensor.current_value.to_s.downcase.in?(%w[true on yes 1])
    end

    def locked?
      return false unless @lock_sensor
      @lock_sensor.typed_value.to_i == 1
    end

    def can_open?
      !locked? && [ 1, 4 ].include?(current_state) # Can open if closed or stopped
    end

    def can_close?
      !locked? && [ 0, 4 ].include?(current_state) # Can close if open or stopped
    end

    def offline?
      @accessory.sensors.any? { |sensor| sensor.last_seen_at.present? && sensor.last_seen_at < 1.hour.ago }
    end
  end
end
