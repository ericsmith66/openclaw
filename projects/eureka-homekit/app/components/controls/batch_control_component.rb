# frozen_string_literal: true

module Controls
  class BatchControlComponent < ViewComponent::Base
    def initialize(accessories:)
      @accessories = accessories
    end

    private

    attr_reader :accessories

    def controllable_accessories
      @controllable_accessories ||= accessories.select do |acc|
        acc.sensors.any? { |s| s.is_writable }
      end
    end

    def has_brightness_capable?
      controllable_accessories.any? do |acc|
        acc.sensors.any? { |s| s.characteristic_type == "Brightness" && s.is_writable }
      end
    end

    def has_temperature_capable?
      controllable_accessories.any? do |acc|
        acc.sensors.any? { |s| s.characteristic_type == "Target Temperature" && s.is_writable }
      end
    end
  end
end
