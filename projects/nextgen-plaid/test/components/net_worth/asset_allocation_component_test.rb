# frozen_string_literal: true

require "test_helper"

class NetWorth::AssetAllocationComponentTest < ViewComponent::TestCase
  def test_renders_empty_state_when_no_data
    html = render_inline(NetWorth::AssetAllocationComponent.new(allocation_data: nil)).to_html

    assert_includes html, "Asset Allocation"
    assert_includes html, "No allocation details available yet"
  end

  def test_renders_chart_container_when_data_present
    allocation = [
      { "class" => "Equities", "pct" => 0.62, "value" => 8_100_000 },
      { "class" => "Cash", "pct" => 0.08, "value" => 1_050_000 }
    ]

    rendered = render_inline(NetWorth::AssetAllocationComponent.new(allocation_data: allocation))

    assert_includes rendered.to_html, "Asset Allocation"
    assert_includes rendered.to_html, "Chartkick"
    assert_includes rendered.to_html, "PieChart"
    assert_includes rendered.to_html, "sr-only"
  end

  def test_normalizes_provider_hash_allocation_without_crashing_on_hash_values
    allocation = {
      "equities" => 0.62,
      "cash" => { "default" => 0.08 },
      "bonds" => "0.15"
    }

    rendered = render_inline(NetWorth::AssetAllocationComponent.new(allocation_data: allocation))

    assert_includes rendered.to_html, "Asset Allocation"
    # Should render without raising and include sr-only fallback table.
    assert_includes rendered.to_html, "sr-only"
  end
end
