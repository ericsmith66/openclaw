# frozen_string_literal: true

class Events::FilterComponent < ViewComponent::Base
  def initialize(rooms: [], accessories: [])
    @rooms = rooms
    @accessories = accessories
  end

  def time_ranges
    [
      [ "Last Hour", "hour" ],
      [ "Last 24 Hours", "24h" ],
      [ "Last 7 Days", "7d" ]
    ]
  end

  def event_types
    [
      [ "Sensors", "characteristic_updated" ],
      [ "Homes", "homes_updated" ]
    ]
  end
end
