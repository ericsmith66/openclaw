# frozen_string_literal: true

class PerformancePlaceholderComponent < ViewComponent::Base
  def initialize(data:)
    @data = data.to_h
  end

  private

  def points
    Array(@data["historical_net_worth"])
  end
end
