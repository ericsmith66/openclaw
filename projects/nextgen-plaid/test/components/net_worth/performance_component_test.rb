# frozen_string_literal: true

require "test_helper"

class NetWorth::PerformanceComponentTest < ViewComponent::TestCase
  def test_renders_empty_state_when_historical_totals_missing
    rendered = render_inline(NetWorth::PerformanceComponent.new(data: {}))

    assert_includes rendered.text, "No data available"
  end

  def test_renders_insufficient_history_message_when_less_than_two_points
    data = {
      "historical_totals" => [
        { "date" => "2026-01-20", "total" => 1_000, "delta" => 10 }
      ]
    }

    rendered = render_inline(NetWorth::PerformanceComponent.new(data: data))

    assert_includes rendered.text, "Insufficient history for trend"
  end

  def test_renders_chart_and_sr_only_table_when_points_present
    data = {
      "historical_totals" => [
        { "date" => "2026-01-20", "total" => 1_000, "delta" => 10 },
        { "date" => "2026-01-21", "total" => 1_020, "delta" => 20 }
      ]
    }

    rendered = render_inline(NetWorth::PerformanceComponent.new(data: data))

    assert_equal 1, rendered.css("#net-worth-performance-chart").count
    assert_equal 1, rendered.css("table.sr-only").count
    assert_includes rendered.css("table.sr-only").text, "2026-01-20"
    assert_includes rendered.css("table.sr-only").text, "$1,000"
  end

  def test_normalizes_totals_and_deltas_to_numeric_defaults
    data = {
      "historical_totals" => [
        { "date" => "2026-01-01", "total" => "1000", "delta" => "10" },
        { "date" => "2026-01-02", "total" => nil, "delta" => nil },
        { "date" => "2026-01-03", "total" => { "default" => 0.0 }, "delta" => { "default" => nil } }
      ]
    }

    component = NetWorth::PerformanceComponent.new(data: data)
    rows = component.rows

    assert_equal 3, rows.size
    assert_equal 1000.0, rows[0][:total]
    assert_equal 10.0, rows[0][:delta]

    assert_equal 0.0, rows[1][:total]
    assert_nil rows[1][:delta]

    assert_equal 0.0, rows[2][:total]
    assert_nil rows[2][:delta]

    rendered = render_inline(component)
    assert_includes rendered.text, "$1,000"
  end
end
