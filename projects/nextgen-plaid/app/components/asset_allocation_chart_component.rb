# frozen_string_literal: true

class AssetAllocationChartComponent < ViewComponent::Base
  def initialize(data:)
    @data = data.to_h
  end

  private

  def allocation
    @data["asset_allocation"].to_h
  end

  def rows
    allocation
      .map { |k, v| [ k.to_s, v.to_f ] }
      .sort_by { |(_k, v)| -v }
  end
end
