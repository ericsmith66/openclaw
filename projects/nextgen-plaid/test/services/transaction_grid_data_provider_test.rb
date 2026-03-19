# frozen_string_literal: true

require "test_helper"

class TransactionGridDataProviderTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @user = User.create!(email: "provider@example.com", password: "password")
    @other_user = User.create!(email: "other@example.com", password: "password")

    @plaid_item = PlaidItem.create!(
      user: @user,
      access_token: "test-access-token",
      item_id: "item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good
    )

    @depository_account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_dep",
      name: "Checking",
      mask: "1111",
      plaid_account_type: "depository"
    )

    @investment_account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_inv",
      name: "Brokerage",
      mask: "2222",
      plaid_account_type: "investment"
    )

    @credit_account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_cred",
      name: "Credit Card",
      mask: "3333",
      plaid_account_type: "credit"
    )

    # Create transactions
    @regular_txn = RegularTransaction.create!(
      account: @depository_account,
      transaction_id: "txn_1",
      name: "Coffee Shop",
      amount: -5.50,
      date: Date.new(2026, 1, 15),
      merchant_name: "Coffee Shop",
      personal_finance_category_label: "FOOD_AND_DRINK"
    )

    @investment_txn = InvestmentTransaction.create!(
      account: @investment_account,
      transaction_id: "txn_2",
      name: "Buy AAPL",
      amount: -1000.00,
      date: Date.new(2026, 1, 10),
      personal_finance_category_label: "INVESTMENT"
    )

    @credit_txn = CreditTransaction.create!(
      account: @credit_account,
      transaction_id: "txn_3",
      name: "Amazon Purchase",
      amount: -50.00,
      date: Date.new(2026, 1, 12),
      merchant_name: "Amazon"
    )

    # Transfer transaction (depository)
    @transfer_txn = RegularTransaction.create!(
      account: @depository_account,
      transaction_id: "txn_4",
      name: "Transfer to Savings",
      amount: -200.00,
      date: Date.new(2026, 1, 20),
      personal_finance_category_label: "TRANSFER_IN"
    )
  end

  test "scopes transactions to current user" do
    result = TransactionGridDataProvider.new(@user).call
    assert_equal 4, result.total_count
    assert_equal 4, result.transactions.size

    result_other = TransactionGridDataProvider.new(@other_user).call
    assert_equal 0, result_other.total_count
  end

  test "filters by type RegularTransaction" do
    result = TransactionGridDataProvider.new(@user, view_type: "regular").call
    assert_equal 2, result.total_count # regular_txn + transfer_txn (both RegularTransaction)
    assert result.transactions.all? { |t| t.type == "RegularTransaction" }
  end

  test "filters by type InvestmentTransaction" do
    result = TransactionGridDataProvider.new(@user, view_type: "investment").call
    assert_equal 1, result.total_count
    assert_equal "InvestmentTransaction", result.transactions.first.type
  end

  test "filters by type CreditTransaction" do
    result = TransactionGridDataProvider.new(@user, view_type: "credit").call
    assert_equal 1, result.total_count
    assert_equal "CreditTransaction", result.transactions.first.type
  end

  test "transfer filtering excludes investment accounts" do
    # Create a transfer transaction in investment account (should be excluded)
    inv_transfer = RegularTransaction.create!(
      account: @investment_account,
      transaction_id: "txn_inv_transfer",
      name: "Transfer within investment",
      amount: -500.00,
      date: Date.new(2026, 1, 25),
      personal_finance_category_label: "TRANSFER_OUT"
    )

    result = TransactionGridDataProvider.new(@user, view_type: "transfers").call
    # Should include only transfer_txn (depository), not inv_transfer
    assert_equal 1, result.total_count
    assert_equal @transfer_txn.id, result.transactions.first.id
  end

  test "summary stats" do
    result = TransactionGridDataProvider.new(@user).call
    summary = result.summary
    assert_equal 4, summary[:count]
    # amounts: -5.5, -1000, -50, -200 = -1255.5 outflow, 0 inflow
    assert_equal 0.0, summary[:inflow]
    assert_equal -1255.5, summary[:outflow]
    assert_equal -1255.5, summary[:net]
  end

  test "pagination" do
    result = TransactionGridDataProvider.new(@user, per_page: 2).call
    assert_equal 4, result.total_count
    assert_equal 2, result.transactions.size
  end

  test "search term filters by name or merchant" do
    result = TransactionGridDataProvider.new(@user, search_term: "Coffee").call
    assert_equal 1, result.total_count
    assert_equal @regular_txn.id, result.transactions.first.id
  end

  test "date range filtering" do
    result = TransactionGridDataProvider.new(@user, date_from: "2026-01-12", date_to: "2026-01-15").call
    # transactions within date range: regular_txn (15), credit_txn (12), investment_txn (10) excluded
    assert_equal 2, result.total_count
    assert_equal [ @regular_txn.id, @credit_txn.id ].sort, result.transactions.map(&:id).sort
  end

  test "sorting by date descending default" do
    result = TransactionGridDataProvider.new(@user, per_page: "all").call
    dates = result.transactions.map(&:date)
    assert_equal dates.sort.reverse, dates
  end

  test "sorting by amount ascending" do
    result = TransactionGridDataProvider.new(@user, sort: "amount", dir: "asc", per_page: "all").call
    amounts = result.transactions.map(&:amount)
    assert_equal amounts.sort, amounts
  end

  test "filters by saved_account_filter_id with account_ids criteria" do
    filter = @user.saved_account_filters.create!(
      name: "Depository Only",
      criteria: { "account_ids" => [ @depository_account.id.to_s ] }
    )
    result = TransactionGridDataProvider.new(@user, saved_account_filter_id: filter.id.to_s).call
    assert result.transactions.all? { |t| t.account_id == @depository_account.id }
    assert_equal 2, result.total_count # regular_txn + transfer_txn
  end

  test "saved_account_filter_id with invalid id returns all transactions" do
    result = TransactionGridDataProvider.new(@user, saved_account_filter_id: "99999").call
    assert_equal 4, result.total_count
  end

  test "saved_account_filter_id combined with search_term" do
    filter = @user.saved_account_filters.create!(
      name: "Depository Only",
      criteria: { "account_ids" => [ @depository_account.id.to_s ] }
    )
    result = TransactionGridDataProvider.new(@user, saved_account_filter_id: filter.id.to_s, search_term: "Coffee").call
    assert_equal 1, result.total_count
    assert_equal @regular_txn.id, result.transactions.first.id
  end

  test "saved_account_filter_id combined with date_range" do
    filter = @user.saved_account_filters.create!(
      name: "Depository Only",
      criteria: { "account_ids" => [ @depository_account.id.to_s ] }
    )
    result = TransactionGridDataProvider.new(
      @user,
      saved_account_filter_id: filter.id.to_s,
      date_from: "2026-01-14",
      date_to: "2026-01-16"
    ).call
    assert_equal 1, result.total_count
    assert_equal @regular_txn.id, result.transactions.first.id
  end

  # Summary Mode Tests
  test "summary_mode returns aggregate hash with stats" do
    result = TransactionGridDataProvider.new(@user, summary_mode: true).call
    summary = result.summary

    assert_equal 0, result.transactions.size, "Should not return transaction rows in summary mode"
    assert_equal 4, summary[:count]
    assert_equal 0.0, summary[:total_inflow]
    assert_equal -1255.5, summary[:total_outflow]
    assert_equal -1255.5, summary[:net]
    assert summary[:top_categories].is_a?(Array)
    assert summary[:top_merchants].is_a?(Array)
    assert summary[:monthly_totals].is_a?(Array)
  end

  test "summary_mode top_categories groups by category label" do
    result = TransactionGridDataProvider.new(@user, summary_mode: true).call
    categories = result.summary[:top_categories]

    assert categories.any? { |c| c[:name] == "FOOD_AND_DRINK" }
    food_cat = categories.find { |c| c[:name] == "FOOD_AND_DRINK" }
    assert_equal 1, food_cat[:count]
    assert_equal -5.50, food_cat[:total]
  end

  test "summary_mode top_merchants excludes nil merchants" do
    # Create a transaction with nil merchant_name
    RegularTransaction.create!(
      account: @depository_account,
      transaction_id: "txn_no_merchant",
      name: "ATM Withdrawal",
      amount: -50.00,
      date: Date.new(2026, 1, 18),
      merchant_name: nil
    )

    result = TransactionGridDataProvider.new(@user, summary_mode: true).call
    merchants = result.summary[:top_merchants]

    assert merchants.all? { |m| m[:name].present? }, "Should exclude nil merchant names"
  end

  test "summary_mode respects saved_account_filter_id" do
    filter = @user.saved_account_filters.create!(
      name: "Depository Only",
      criteria: { "account_ids" => [ @depository_account.id.to_s ] }
    )

    result = TransactionGridDataProvider.new(@user, summary_mode: true, saved_account_filter_id: filter.id.to_s).call
    summary = result.summary

    # Should only include transactions from depository account (regular_txn + transfer_txn)
    assert_equal 2, summary[:count]
    assert_equal -205.5, summary[:total_outflow] # -5.5 + -200
  end

  test "summary_mode with zero transactions" do
    result = TransactionGridDataProvider.new(@other_user, summary_mode: true).call
    summary = result.summary

    assert_equal 0, summary[:count]
    assert_equal 0.0, summary[:total_inflow]
    assert_equal 0.0, summary[:total_outflow]
    assert_equal 0.0, summary[:net]
    assert_equal [], summary[:top_categories]
    assert_equal [], summary[:top_merchants]
    assert_equal [], summary[:monthly_totals]
  end

  test "summary_mode monthly_totals groups by month" do
    result = TransactionGridDataProvider.new(@user, summary_mode: true).call
    monthly = result.summary[:monthly_totals]

    assert monthly.is_a?(Array)
    assert monthly.all? { |m| m.is_a?(Array) && m.size == 2 }
    # All transactions are in Jan 2026
    assert monthly.any? { |m| m[0] == "Jan 2026" }
  end

  test "returns warning when per_page is all and count > 500" do
    # Create 501 transactions to trigger warning
    501.times do |i|
      RegularTransaction.create!(
        account: @depository_account,
        transaction_id: "bulk_txn_#{i}",
        name: "Transaction #{i}",
        amount: -10.00,
        date: Date.today
      )
    end

    result = TransactionGridDataProvider.new(@user, { per_page: "all" }).call

    assert result.warning.present?
    assert_includes result.warning, "505 transactions" # 501 + 4 setup transactions
    assert_includes result.warning, "Consider filtering"
  end

  test "no warning when per_page is all and count <= 500" do
    # Only 4 transactions from setup
    result = TransactionGridDataProvider.new(@user, { per_page: "all" }).call

    assert_nil result.warning
  end

  test "no warning when per_page is numeric" do
    # Create 501 transactions
    501.times do |i|
      RegularTransaction.create!(
        account: @depository_account,
        transaction_id: "bulk_txn_#{i}",
        name: "Transaction #{i}",
        amount: -10.00,
        date: Date.today
      )
    end

    result = TransactionGridDataProvider.new(@user, { per_page: "25" }).call

    assert_nil result.warning
  end

  test "Result struct is backward compatible without warning" do
    # Test that existing code that doesn't pass warning: still works
    result = TransactionGridDataProvider::Result.new(
      transactions: [],
      summary: {},
      total_count: 0
      # warning: not passed
    )

    assert_equal [], result.transactions
    assert_equal({}, result.summary)
    assert_equal 0, result.total_count
    assert_nil result.warning
  end
end
