# frozen_string_literal: true

class NetWorth::SectorWeightsComponentPreview < ViewComponent::Preview
  def default
    render NetWorth::SectorWeightsComponent.new(data: sample_data)
  end

  def empty_state
    render NetWorth::SectorWeightsComponent.new(data: { "sector_weights" => [] })
  end

  def single_sector
    render NetWorth::SectorWeightsComponent.new(
      data: { "sector_weights" => [ { "sector" => "Technology", "pct" => 0.55, "value" => 5_500_000 } ] }
    )
  end

  def many_sectors
    render NetWorth::SectorWeightsComponent.new(data: sample_data)
  end

  private

  def sample_data
    {
      "sector_weights" => [
        { "sector" => "Technology", "pct" => 0.28, "value" => 2_300_000 },
        { "sector" => "Healthcare", "pct" => 0.12, "value" => 990_000 },
        { "sector" => "Financials", "pct" => 0.10, "value" => 850_000 },
        { "sector" => "Industrials", "pct" => 0.09, "value" => 770_000 },
        { "sector" => "Consumer Discretionary", "pct" => 0.08, "value" => 690_000 }
      ]
    }
  end
end
