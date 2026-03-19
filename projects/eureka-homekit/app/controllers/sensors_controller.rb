class SensorsController < ApplicationController
  def index
    @sensors = Sensor.includes(:sensor_value_definitions, :accessory, room: :home).all

    # Filters
    if params[:type].present?
      @sensors = @sensors.where(characteristic_type: params[:type])
    end

    if params[:status] == "offline"
      @sensors = @sensors.offline_by_status
    elsif params[:status] == "low_battery"
      @sensors = @sensors.battery_level.where("NULLIF(current_value->>0, '')::float < ?", 20)
    end

    if params[:room_id].present?
      @sensors = @sensors.joins(:room).where(rooms: { id: params[:room_id] })
    end

    if params[:search].present?
      @sensors = @sensors.joins(:accessory).where("accessories.name ILIKE ? OR characteristic_type ILIKE ?", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    if params[:type].present?
      @sensors = @sensors.where(characteristic_type: params[:type])
      @grouped_sensors = @sensors.group_by(&:characteristic_type)
    else
      @grouped_sensors = @sensors.group_by(&:characteristic_type)
    end

    # Alerts
    @alerts = {
      low_battery: Sensor.battery_level.where("NULLIF(current_value->>0, '')::float < ?", 20),
      offline: Sensor.offline_by_status
    }
  end

  def show
    @sensor = Sensor.includes(:sensor_value_definitions, accessory: { room: :home }).find(params[:id])
    @time_range = params[:time_range] || "24h"

    range_start = case @time_range
    when "24h" then 24.hours.ago
    when "7d" then 7.days.ago
    when "30d" then 30.days.ago
    else 24.hours.ago
    end

    @events = @sensor.events.where("timestamp >= ?", range_start)
                    .order(timestamp: :desc)
                    .limit(50) # Basic pagination via limit for now
  end
end
