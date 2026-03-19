# frozen_string_literal: true

class Shared::StatCardComponent < ViewComponent::Base
  def initialize(label:, value:, icon: nil, trend: nil, status: nil)
    @label = label
    @value = value
    @icon = icon
    @trend = trend
    @status = status
  end

  private

  def status_color
    case @status&.to_sym
    when :success then "text-success"
    when :warning then "text-warning"
    when :error, :danger then "text-error"
    when :info then "text-info"
    else ""
    end
  end

  def trend_color
    return "" unless @trend
    @trend.start_with?("+") ? "text-success" : "text-error"
  end
end
