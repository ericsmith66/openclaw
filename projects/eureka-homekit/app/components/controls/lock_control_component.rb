module Controls
  class LockControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false)
      @accessory = accessory
      @compact = compact
      @sensors = @accessory.sensors.index_by(&:characteristic_type)
    end

    # Lock Current State mapping (HomeKit spec)
    # 0 = unsecured, 1 = secured, 2 = jammed, 3 = unknown
    def current_state
      @sensors["Lock Current State"]&.current_value&.to_i || 3
    end

    # Lock Target State mapping (HomeKit spec)
    # 0 = unsecured, 1 = secured
    def target_state
      @sensors["Lock Target State"]&.current_value&.to_i || 0
    end

    # Display state
    def locked?
      current_state == 1
    end

    def unlocked?
      current_state == 0
    end

    def jammed?
      current_state == 2
    end

    def unknown?
      current_state == 3
    end

    # State icon
    def state_icon
      case current_state
      when 0 then "🔓"
      when 1 then "🔒"
      when 2 then "⚠️"
      else "❓"
      end
    end

    # State text
    def state_text
      case current_state
      when 0 then "Unlocked"
      when 1 then "Locked"
      when 2 then "Jammed"
      else "Unknown"
      end
    end

    # Check if accessory is offline
    def offline?
      @accessory.last_seen_at.nil? || @accessory.last_seen_at < 1.hour.ago
    end

    private

    attr_reader :accessory, :compact, :sensors
  end
end
