module Homes
  class RoomsController < ApplicationController
    def index
      @home = Home.find(params[:home_id])
      @rooms = @home.rooms.includes(:accessories, :sensors)
      @rooms = @rooms.joins(:sensors).distinct if params[:has_sensors]
      @rooms = @rooms.where("name ILIKE ?", "%#{params[:search]}%") if params[:search]
    end
  end
end
