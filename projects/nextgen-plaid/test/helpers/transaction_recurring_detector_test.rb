# frozen_string_literal: true

require "test_helper"

class TransactionRecurringDetectorTest < ActiveSupport::TestCase
  test "detect! marks transactions as recurring when same merchant, similar amount, 3+ times" do
    transactions = [
      OpenStruct.new(date: "2025-10-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: nil),
      OpenStruct.new(date: "2025-11-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: nil),
      OpenStruct.new(date: "2025-12-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: nil)
    ]

    TransactionRecurringDetector.detect!(transactions)

    assert transactions.all?(&:is_recurring), "All Netflix transactions should be marked recurring"
  end

  test "detect! does not mark as recurring with fewer than 3 occurrences" do
    transactions = [
      OpenStruct.new(date: "2025-11-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: nil),
      OpenStruct.new(date: "2025-12-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: nil)
    ]

    TransactionRecurringDetector.detect!(transactions)

    assert transactions.none?(&:is_recurring), "Fewer than 3 occurrences should not be recurring"
  end

  test "detect! handles varying amounts within tolerance" do
    transactions = [
      OpenStruct.new(date: "2025-10-01", name: "Spotify", merchant_name: "Spotify", amount: -9.99, is_recurring: nil),
      OpenStruct.new(date: "2025-11-01", name: "Spotify", merchant_name: "Spotify", amount: -10.29, is_recurring: nil),
      OpenStruct.new(date: "2025-12-01", name: "Spotify", merchant_name: "Spotify", amount: -9.99, is_recurring: nil)
    ]

    TransactionRecurringDetector.detect!(transactions)

    assert transactions.all?(&:is_recurring), "Amounts within 5% tolerance should be recurring"
  end

  test "detect! does not mark as recurring with wildly different amounts" do
    transactions = [
      OpenStruct.new(date: "2025-10-01", name: "Amazon", merchant_name: "Amazon", amount: -10.00, is_recurring: nil),
      OpenStruct.new(date: "2025-11-01", name: "Amazon", merchant_name: "Amazon", amount: -500.00, is_recurring: nil),
      OpenStruct.new(date: "2025-12-01", name: "Amazon", merchant_name: "Amazon", amount: -25.00, is_recurring: nil)
    ]

    TransactionRecurringDetector.detect!(transactions)

    assert transactions.none?(&:is_recurring), "Wildly different amounts should not be recurring"
  end

  test "detect! respects Plaid recurring flag" do
    transactions = [
      OpenStruct.new(date: "2025-12-01", name: "Utility", merchant_name: "PG&E", amount: -120.00, recurring: true, is_recurring: nil)
    ]

    TransactionRecurringDetector.detect!(transactions)

    assert transactions.first.is_recurring, "Plaid recurring flag should be respected"
  end

  test "detect! handles empty collection" do
    result = TransactionRecurringDetector.detect!([])
    assert_equal [], result
  end

  test "detect! handles nil collection" do
    result = TransactionRecurringDetector.detect!(nil)
    assert_nil result
  end

  test "top_recurring returns top items sorted by yearly spend" do
    transactions = [
      OpenStruct.new(date: "2025-10-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: true),
      OpenStruct.new(date: "2025-11-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: true),
      OpenStruct.new(date: "2025-12-15", name: "Netflix", merchant_name: "Netflix", amount: -15.99, is_recurring: true),
      OpenStruct.new(date: "2025-10-01", name: "Spotify", merchant_name: "Spotify", amount: -9.99, is_recurring: true),
      OpenStruct.new(date: "2025-11-01", name: "Spotify", merchant_name: "Spotify", amount: -9.99, is_recurring: true),
      OpenStruct.new(date: "2025-12-01", name: "Spotify", merchant_name: "Spotify", amount: -9.99, is_recurring: true)
    ]

    result = TransactionRecurringDetector.top_recurring(transactions, limit: 5)

    assert_equal 2, result.size
    assert_equal "netflix", result.first[:name]
    assert result.first[:yearly_total] > result.last[:yearly_total]
  end

  test "top_recurring returns empty array when no recurring transactions" do
    transactions = [
      OpenStruct.new(date: "2025-12-15", name: "One-off", merchant_name: "Store", amount: -50.00, is_recurring: false)
    ]

    result = TransactionRecurringDetector.top_recurring(transactions)
    assert_equal [], result
  end
end
