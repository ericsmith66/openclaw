# frozen_string_literal: true

class Events::RowComponent < ViewComponent::Base
  include EventFormattingHelper

  def initialize(event:)
    @event = event
  end

  def type_class
    case @event.event_type
    when "characteristic_updated"
      "bg-blue-50 text-blue-700 border-blue-100"
    when "homes_updated"
      "bg-purple-50 text-purple-700 border-purple-100"
    else
      "bg-gray-50 text-gray-700 border-gray-100"
    end
  end

  def formatted_value
    formatted_event_value(@event)
  end
end
