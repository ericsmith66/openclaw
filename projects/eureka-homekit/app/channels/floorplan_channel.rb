class FloorplanChannel < ApplicationCable::Channel
  def subscribed
    stream_from "floorplan_updates"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
