class HomesController < ApplicationController
  def index
    @homes = Home.includes(:rooms, :accessories, :sensors).all
  end

  def show
    @home = Home.includes(rooms: [ :accessories, :sensors ]).find(params[:id])
    @recent_events = HomekitEvent.where(
      accessory_name: @home.accessories.pluck(:name)
    ).order(timestamp: :desc).limit(50)
  end
end
