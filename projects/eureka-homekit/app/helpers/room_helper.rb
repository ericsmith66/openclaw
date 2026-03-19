module RoomHelper
  def room_activity_color(room)
    last_event = room.last_event_at
    return "bg-base-100" if last_event.nil?

    minutes_ago = (Time.current - last_event) / 60

    case minutes_ago
    when 0..5
      "bg-error" # Active/Motion (Red-ish in DaisyUI)
    when 5..15
      "bg-warning" # Warm/Occupancy (Yellow-ish)
    when 15..60
      "bg-info" # Recent
    else
      "bg-base-100"     # Idle
    end
  end

  def room_heatmap_class(room)
    last_motion = room.last_motion_at
    last_event = room.last_event_at

    return "heatmap-cold" if last_event.nil?

    motion_mins = last_motion ? (Time.current - last_motion) / 60 : 999
    event_mins = (Time.current - last_event) / 60

    if motion_mins <= 5
      "heatmap-active animate-pulse-slow"
    elsif motion_mins <= 15 || event_mins <= 15
      "heatmap-warm"
    else
      "heatmap-cold"
    end
  end

  def room_activity_text_color(room)
    last_event = room.last_event_at
    return "text-base-content" if last_event.nil?

    minutes_ago = (Time.current - last_event) / 60
    minutes_ago <= 5 ? "text-green-50" : "text-base-content"
  end
end
