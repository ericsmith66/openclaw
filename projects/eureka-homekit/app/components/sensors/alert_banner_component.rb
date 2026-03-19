# frozen_string_literal: true

class Sensors::AlertBannerComponent < ViewComponent::Base
  def initialize(alerts:)
    @alerts = alerts
  end

  def render?
    @alerts[:low_battery].any? || @alerts[:offline].any?
  end
end
