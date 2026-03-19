# frozen_string_literal: true

class Layouts::LeftSidebarComponent < ViewComponent::Base
  include RoomHelper

  def initialize(homes: [])
    @homes = homes
  end

  private

  def menu_items
    [
      { label: "Dashboard", path: helpers.root_path, icon: "layout-dashboard" },
      { label: "Floorplan", path: helpers.root_path(view: :floorplan), icon: "map" },
      { label: "All Homes", path: helpers.homes_path, icon: "home" },
      { label: "Scenes", path: helpers.scenes_path, icon: "play" },
      { label: "Favorites", path: helpers.favorites_path, icon: "star" },
      { label: "Settings", path: "#", icon: "settings" }
    ]
  end
end
