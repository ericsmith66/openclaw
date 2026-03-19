# frozen_string_literal: true

class Events::EventDetailModalComponent < ViewComponent::Base
  include EventFormattingHelper

  def initialize(event: nil)
    @event = event
  end

  def icon_name
    @event ? event_icon(@event) : "bell"
  end

  def summary
    @event ? event_summary(@event) : ""
  end

  def accessory_name
    @event&.accessory&.name || "Unknown Accessory"
  end

  def room_name
    @event&.room&.name || "N/A"
  end

  def timestamp
    @event&.timestamp || @event&.created_at
  end

  def formatted_timestamp
    timestamp&.strftime("%B %d, %Y at %I:%M:%S %p")
  end

  def time_ago
    timestamp ? "#{time_ago_in_words(timestamp)} ago" : ""
  end

  def raw_payload
    return "{}" if @event.nil?

    begin
      JSON.pretty_generate(JSON.parse(@event.raw_payload))
    rescue
      JSON.pretty_generate(JSON.parse(@event.value.to_json)) rescue @event.value.to_s
    end
  end
end
