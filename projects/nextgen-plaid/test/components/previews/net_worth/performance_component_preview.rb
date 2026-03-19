# frozen_string_literal: true

class NetWorth::PerformanceComponentPreview < ViewComponent::Preview
  def default
    render NetWorth::PerformanceComponent.new(data: sample_data)
  end

  def sparse
    render NetWorth::PerformanceComponent.new(
      data: {
        "historical_totals" => [
          { "date" => "2026-01-26", "total" => 9_950_000, "delta" => nil },
          { "date" => "2026-01-27", "total" => 10_025_000, "delta" => 75_000 }
        ]
      }
    )
  end

  def insufficient_history
    render NetWorth::PerformanceComponent.new(
      data: {
        "historical_totals" => [
          { "date" => "2026-01-27", "total" => 10_025_000, "delta" => 75_000 }
        ]
      }
    )
  end

  def empty
    render NetWorth::PerformanceComponent.new(data: {})
  end

  private

  def sample_data
    totals = []
    start = Date.new(2025, 12, 29)
    30.times do |i|
      date = (start + i).to_s
      total = 10_000_000 + (i * 15_000) - ((i % 6) * 7_500)
      delta = i.zero? ? nil : (total - totals.last[:total])
      totals << { date: date, total: total, delta: delta }
    end

    { "historical_totals" => totals }
  end
end
