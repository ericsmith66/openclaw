class EventsController < ApplicationController
  def index
    @events = HomekitEvent.includes(sensor: [ :sensor_value_definitions, accessory: :room ], accessory: :room)
                          .order(timestamp: :desc)

    # Time filter
    @time_range = params[:time_range] || "hour"
    range_start = case @time_range
    when "hour" then 1.hour.ago
    when "24h" then 24.hours.ago
    when "7d" then 7.days.ago
    else 1.hour.ago
    end
    @events = @events.where("timestamp >= ?", range_start)

    # Type filter
    if params[:types].present?
      @events = @events.where(event_type: params[:types])
    end

    # Room filter
    if params[:room_id].present?
      @events = @events.joins(accessory: :room).where(rooms: { id: params[:room_id] })
    end

    # Search
    if params[:search].present?
      @events = @events.where("accessory_name ILIKE ? OR characteristic ILIKE ?",
                             "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @events_count = @events.count
    @events = @events.limit(50) # Basic limit for now instead of full pagination gem

    # Statistics
    @stats = {
      total: @events_count,
      sensor_events: @events_count > 0 ? HomekitEvent.where("timestamp >= ?", range_start).where(event_type: "characteristic_updated").count : 0,
      events_per_minute: @events_count > 0 ? (@events_count / ((Time.current - range_start) / 60.0)).round(2) : 0
    }

    @recent_grouped_events = HomekitEvent.recent_grouped(limit: 15)
  end

  def show
    @event = HomekitEvent.find(params[:id])
    render layout: false if request.xhr?
  end
end
