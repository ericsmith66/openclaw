class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_homes, :recent_events
  helper RoomHelper

  def current_homes
    @current_homes ||= Home.includes(rooms: { accessories: { sensors: :sensor_value_definitions } }).all
  end

  def recent_events
    @recent_events ||= HomekitEvent.includes(accessory: :room).order(timestamp: :desc).limit(20)
  end
end
