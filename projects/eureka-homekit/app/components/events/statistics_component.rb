# frozen_string_literal: true

class Events::StatisticsComponent < ViewComponent::Base
  def initialize(stats:, time_range:)
    @stats = stats
    @time_range = time_range
  end

  def range_label
    case @time_range
    when "hour" then "Last Hour"
    when "24h" then "Last 24 Hours"
    when "7d" then "Last 7 Days"
    else "Selected Period"
    end
  end
end
