# frozen_string_literal: true

class Events::RecentEventsItemComponent < ViewComponent::Base
  include EventFormattingHelper

  def initialize(event:, count: 1)
    @event = event
    @count = count
  end

  def icon_name
    event_icon(@event)
  end

  def summary
    event_summary(@event)
  end

  def accessory_name
    @event.accessory&.name || "Unknown Accessory"
  end

  def room_name
    @event.room&.name || @event.sensor&.room&.name || "N/A"
  end

  def time_ago
    time_ago_in_words(@event.timestamp || @event.created_at)
  end

  def severity_class
    @event.severity == "critical" ? "bg-error animate-pulse" : "bg-info"
  end
end
