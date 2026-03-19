# frozen_string_literal: true

class Charts::ActivityChartComponent < ViewComponent::Base
  def initialize(sensor:, events:, time_range: "24h")
    @sensor = sensor
    @events = events.reverse # chronological order for chart
    @time_range = time_range
  end

  def labels
    @events.map { |e| e.timestamp.strftime("%H:%M") }
  end

  def values
    @events.map do |e|
      val = e.value.to_f
      if @sensor.characteristic_type == "Current Temperature"
        ((val * 9.0 / 5.0) + 32.0).round(1)
      else
        val
      end
    end
  end
end
