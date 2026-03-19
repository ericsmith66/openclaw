# frozen_string_literal: true

class SectorWeightsComponent < ViewComponent::Base
  def initialize(data:)
    @data = data.to_h
  end

  private

  def weights
    @data["sector_weights"].presence
  end

  def rows
    weights.to_h
      .map { |k, v| [ k.to_s, v.to_f ] }
      .sort_by { |(_k, v)| -v }
  end
end
