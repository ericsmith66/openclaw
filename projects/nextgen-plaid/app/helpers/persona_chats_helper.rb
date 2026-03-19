module PersonaChatsHelper
  def persona_chat_relative_timestamp(time)
    return "" if time.blank?

    seconds = (Time.current - time).to_i
    return "Just now" if seconds < 60

    minutes = seconds / 60
    return "#{minutes}m ago" if minutes < 60

    hours = minutes / 60
    return "#{hours}h ago" if hours < 24

    days = (time.to_date - Date.current).to_i.abs
    return "Yesterday" if days == 1
    return "#{days} days ago" if days < 7

    time.strftime("%b %-d")
  end
end
