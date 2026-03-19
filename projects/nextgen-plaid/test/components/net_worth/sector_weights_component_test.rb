# frozen_string_literal: true

require "test_helper"

class NetWorth::SectorWeightsComponentTest < ViewComponent::TestCase
  def test_renders_empty_state
    rendered = render_inline(NetWorth::SectorWeightsComponent.new(data: { "sector_weights" => [] }))

    assert_includes rendered.text, "No sector data available"
  end

  def test_renders_table_rows
    data = {
      "sector_weights" => [
        { "sector" => "Technology", "pct" => 0.28, "value" => 2_300_000 },
        { "sector" => "Healthcare", "pct" => 0.12, "value" => 990_000 }
      ]
    }

    rendered = render_inline(NetWorth::SectorWeightsComponent.new(data: data))

    assert_includes rendered.text, "Technology"
    assert_includes rendered.text, "Healthcare"
    assert_includes rendered.text, "$2,300,000"
  end
end
