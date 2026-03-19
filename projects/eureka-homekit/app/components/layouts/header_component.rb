# frozen_string_literal: true

class Layouts::HeaderComponent < ViewComponent::Base
  def initialize(sync_status: :success, last_sync: nil)
    @sync_status = sync_status
    @last_sync = last_sync
  end

  private

  def nav_items
    [
      { label: "Overview", path: helpers.root_path, icon: "layout-dashboard", active: helpers.current_page?(helpers.root_path) },
      { label: "Homes", path: helpers.homes_path, icon: "home", active: helpers.current_page?(helpers.homes_path) || helpers.controller_name == "homes" },
      { label: "Rooms", path: helpers.rooms_path, icon: "door-open", active: helpers.current_page?(helpers.rooms_path) || helpers.controller_name == "rooms" },
      { label: "Sensors", path: helpers.sensors_path, icon: "signal", active: helpers.current_page?(helpers.sensors_path) || helpers.controller_name == "sensors" },
      { label: "Events", path: helpers.events_path, icon: "clipboard-list", active: helpers.current_page?(helpers.events_path) || helpers.controller_name == "events" }
    ]
  end
end
