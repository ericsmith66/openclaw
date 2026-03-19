# frozen_string_literal: true

module Controls
  class AccessoryControlComponent < ViewComponent::Base
    def initialize(accessory:, compact: false, show_favorite: true)
      @accessory = accessory
      @compact = compact
      @show_favorite = show_favorite
      @sensors = @accessory.sensors.index_by(&:characteristic_type)
    end

    private

    attr_reader :accessory, :compact, :sensors

    def accessory_type
      return :outlet if outlet?
      return :garage_door if garage_door?
      return :blind if blind?
      return :fan if fan?
      return :thermostat if thermostat?
      return :lock if lock?
      return :light if light?
      return :switch if switch?
      nil
    end

    def garage_door?
      sensors.key?("Current Door State")
    end

    def blind?
      sensors.key?("Target Position") && !sensors.key?("Active")
    end

    def fan?
      sensors.key?("Rotation Speed") && sensors.key?("Active")
    end

    def thermostat?
      sensors.key?("Target Temperature")
    end

    def lock?
      sensors.key?("Lock Current State")
    end

    def light?
      sensors.key?("On") && (sensors.key?("Brightness") || sensors.key?("Hue"))
    end

    def switch?
      sensors.key?("On") && !sensors.key?("Brightness") && !sensors.key?("Hue") && !outlet?
    end

    def outlet?
      sensors.key?("On") && sensors.key?("Outlet In Use")
    end

    def component_class
      case accessory_type
      when :garage_door then Controls::GarageDoorControlComponent
      when :blind then Controls::BlindControlComponent
      when :fan then Controls::FanControlComponent
      when :thermostat then Controls::ThermostatControlComponent
      when :lock then Controls::LockControlComponent
      when :light then Controls::LightControlComponent
      when :switch then Controls::SwitchControlComponent
      when :outlet then Controls::OutletControlComponent
      end
    end

    def show_favorite?
      @show_favorite
    end

    def renderable?
      accessory_type.present? && component_class.present?
    end
  end
end
