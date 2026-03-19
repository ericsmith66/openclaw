class Rooms::DetailComponent < ViewComponent::Base
  def initialize(room:, sensors:, other_accessories:)
    @room = room
    @sensors = sensors
    @other_accessories = other_accessories
  end

  private

  attr_reader :room, :sensors, :other_accessories

  def room_status_items
    is_offline = room.accessories.any?(&:sensors) && room.accessories.all? { |acc| acc.sensors.any? && acc.sensors.all?(&:offline?) }

    [
      { label: "Connectivity", value: is_offline ? "Offline" : "Online", status: is_offline ? :error : :success },
      { label: "Accessories", value: room.accessories.size, status: :info },
      { label: "Sensors", value: room.sensors.size, status: :info }
    ]
  end

  def has_controllable_accessories?
    room.accessories.any? { |acc| acc.sensors.where(is_writable: true).exists? }
  end

  def controllable_accessories
    @controllable_accessories ||= room.accessories.includes(:sensors).select do |acc|
      acc.sensors.where(is_writable: true).exists?
    end
  end
end
