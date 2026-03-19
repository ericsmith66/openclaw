# frozen_string_literal: true

require "test_helper"

module Transactions
  class MonthlyGroupComponentTest < ViewComponent::TestCase
    setup do
      @transactions = [
        OpenStruct.new(date: Date.new(2026, 1, 15), name: "Jan Transaction", amount: -50.0),
        OpenStruct.new(date: Date.new(2026, 1, 20), name: "Another Jan", amount: -30.0),
        OpenStruct.new(date: Date.new(2026, 2, 10), name: "Feb Transaction", amount: 100.0)
      ]
    end

    test "groups transactions by month" do
      render_inline(MonthlyGroupComponent.new(transactions: @transactions))
      assert_selector ".collapse-title", text: /January 2026/
      assert_selector ".collapse-title", text: /February 2026/
      assert_selector "table", count: 2
    end

    test "calculates monthly totals" do
      render_inline(MonthlyGroupComponent.new(transactions: @transactions))
      assert_text "-$80.00" # January total
      assert_text "$100.00" # February total
    end

    test "handles empty transactions" do
      render_inline(MonthlyGroupComponent.new(transactions: []))
      assert_text "No transactions to group."
    end
  end
end
