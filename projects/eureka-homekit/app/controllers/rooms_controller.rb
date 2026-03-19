class RoomsController < ApplicationController
  def index
    @rooms = Room.includes(:home, accessories: { sensors: :sensor_value_definitions }).all
    @rooms = @rooms.joins(:sensors).distinct if params[:has_sensors]
    @rooms = @rooms.where("name ILIKE ?", "%#{params[:search]}%") if params[:search]
    @rooms = @rooms.sort_by { |r| r.name.downcase }
  end

  def show
    @room = Room.includes(:home, accessories: { sensors: :sensor_value_definitions }).find(params[:id])
    @sensors = @room.sensors.includes(:accessory, :sensor_value_definitions)
    @other_accessories = @room.accessories.left_joins(:sensors)
                              .where(sensors: { id: nil })
  end
end
