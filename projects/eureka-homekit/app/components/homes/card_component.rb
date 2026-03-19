class Homes::CardComponent < ViewComponent::Base
  def initialize(home:)
    @home = home
  end

  private

  attr_reader :home

  def room_count
    home.rooms.size
  end

  def accessory_count
    home.accessories.size
  end

  def sensor_count
    home.sensors.size
  end

  def sync_status
    # Placeholder for actual sync status
    :success
  end

  def last_sync_time
    # Placeholder for last sync timestamp
    "2m ago"
  end
end
