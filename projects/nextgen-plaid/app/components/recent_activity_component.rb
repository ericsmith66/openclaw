# frozen_string_literal: true

class RecentActivityComponent < ViewComponent::Base
  def initialize(data:)
    @data = data.to_h
  end

  private

  def summary
    @data["monthly_transaction_summary"].to_h
  end

  def categories
    Array(summary["top_categories"])
  end
end
