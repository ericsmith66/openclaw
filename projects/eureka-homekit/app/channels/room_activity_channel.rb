class RoomActivityChannel < ApplicationCable::Channel
  def subscribed
    stream_from "room_activity"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
