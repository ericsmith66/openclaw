# frozen_string_literal: true

require "test_helper"

module Transactions
  class RowComponentTest < ViewComponent::TestCase
    setup do
      @transaction = OpenStruct.new(
        date: Date.new(2026, 1, 15),
        name: "Test Purchase",
        amount: -50.0,
        merchant_name: "Test Merchant",
        personal_finance_category_label: "SHOPPING",
        pending: false,
        payment_channel: "online",
        account: OpenStruct.new(name: "Test Account"),
        account_type: "depository",
        transaction_id: "test_txn_001",
        source: "manual",
        type: "RegularTransaction",
        subtype: nil,
        category: nil,
        is_recurring: false
      )
    end

    test "renders transaction row with correct data" do
      render_inline(RowComponent.new(transaction: @transaction, view_type: "cash"))

      assert_selector "td", text: "Jan 15, 2026"
      assert_selector "td", text: "Test Purchase"
      assert_selector "td", text: "Cash"
      assert_selector "td", text: "Test Account"
      assert_selector "span.badge", text: "Cash"
      assert_no_selector "span.badge-warning", text: "Pending"
    end

    test "pending transaction shows pending badge" do
      @transaction.pending = true
      render_inline(RowComponent.new(transaction: @transaction, view_type: "cash"))
      assert_selector "span.badge-warning", text: "Pending"
    end

    test "recurring transaction shows RR badge" do
      @transaction.is_recurring = true
      render_inline(RowComponent.new(transaction: @transaction, view_type: "cash"))
      assert_selector "span.badge-ghost", text: "RR"
    end

    test "non-recurring transaction does not show RR badge" do
      @transaction.is_recurring = false
      render_inline(RowComponent.new(transaction: @transaction, view_type: "cash"))
      assert_no_selector "span", text: "RR"
    end

    test "amount class for negative amount is text-error" do
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "text-error", component.amount_class
    end

    test "amount class for positive amount is text-success" do
      @transaction.amount = 100.0
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "text-success", component.amount_class
    end

    test "amount class for zero amount is text-base-content" do
      @transaction.amount = 0.0
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "text-base-content", component.amount_class
    end

    test "type_badge returns appropriate badge class" do
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "badge badge-accent badge-sm", component.type_badge

      @transaction.type = "InvestmentTransaction"
      component = RowComponent.new(transaction: @transaction, view_type: "investments")
      assert_equal "badge badge-primary badge-sm", component.type_badge

      @transaction.type = "CreditTransaction"
      component = RowComponent.new(transaction: @transaction, view_type: "credit")
      assert_equal "badge badge-secondary badge-sm", component.type_badge

      @transaction.type = "Unknown"
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "badge badge-outline badge-sm", component.type_badge
    end

    test "formatted_date handles missing date" do
      @transaction.date = nil
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "—", component.formatted_date
    end

    test "formatted_date handles string date" do
      @transaction.date = "2026-01-20"
      component = RowComponent.new(transaction: @transaction, view_type: "cash")
      assert_equal "Jan 20, 2026", component.formatted_date
    end

    test "investment row renders security icon with letter avatar" do
      inv_txn = OpenStruct.new(
        date: Date.new(2026, 1, 10),
        name: "Buy AAPL",
        amount: -5250.0,
        type: "InvestmentTransaction",
        security_name: "Apple Inc.",
        security_id: "sec_aapl",
        quantity: 30.0,
        price: 175.0,
        account: OpenStruct.new(name: "Schwab Brokerage"),
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: inv_txn, show_investment_columns: true, view_type: "investments"))

      # Security icon letter avatar
      assert_selector ".avatar .rounded-full span", text: "A"
      # Clickable security link
      assert_selector "a.link-primary", text: "Apple Inc."
    end

    test "transfer row renders direction arrow and badge" do
      xfr_txn = OpenStruct.new(
        date: Date.new(2026, 1, 20),
        name: "Transfer to Savings",
        amount: -1000.0,
        type: "RegularTransaction",
        account: OpenStruct.new(name: "Chase Checking"),
        target_account_name: "Chase Savings",
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: xfr_txn, view_type: "transfers"))

      # Should show direction arrow (outbound = error colored)
      assert_selector "svg.text-error"
      # Should show Internal badge
      assert_selector "span.badge", text: "Internal"
      # From and To accounts
      assert_selector "td span.font-medium", text: "Chase Checking"
      assert_selector "td span.font-medium", text: "Chase Savings"
    end

    test "transfer row shows External badge for external transfers" do
      xfr_txn = OpenStruct.new(
        date: Date.new(2026, 1, 19),
        name: "External Transfer",
        amount: 500.0,
        type: "RegularTransaction",
        account: OpenStruct.new(name: "Wells Fargo Checking"),
        target_account_name: "External Bank",
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: xfr_txn, view_type: "transfers"))

      # Should show inbound arrow (success colored)
      assert_selector "svg.text-success"
      # Should show External badge
      assert_selector "span.badge", text: "External"
    end

    test "credit view renders merchant icon" do
      credit_txn = OpenStruct.new(
        date: Date.new(2026, 1, 15),
        name: "Amazon.com",
        amount: -129.99,
        merchant_name: "Amazon",
        type: "CreditTransaction",
        account: OpenStruct.new(name: "Chase Sapphire"),
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: credit_txn, view_type: "credit"))

      # Should show merchant letter avatar
      assert_selector ".avatar .rounded-full span", text: "A"
    end

    test "subtype badge renders for investment transactions" do
      inv_txn = OpenStruct.new(
        date: Date.new(2026, 1, 10),
        name: "Buy AAPL",
        amount: -5250.0,
        type: "InvestmentTransaction",
        subtype: "buy",
        account: OpenStruct.new(name: "Schwab Brokerage"),
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: inv_txn, show_investment_columns: true, view_type: "investments"))

      assert_selector "span.badge-success", text: "Buy"
    end

    test "subtype badge renders sell with red color" do
      inv_txn = OpenStruct.new(
        date: Date.new(2026, 1, 10),
        name: "Sell AAPL",
        amount: 5250.0,
        type: "InvestmentTransaction",
        subtype: "sell",
        account: OpenStruct.new(name: "Schwab Brokerage"),
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: inv_txn, show_investment_columns: true, view_type: "investments"))

      assert_selector "span.badge-error", text: "Sell"
    end

    test "subtype badge renders dividend with blue color" do
      inv_txn = OpenStruct.new(
        date: Date.new(2026, 1, 10),
        name: "Dividend AAPL",
        amount: 50.0,
        type: "InvestmentTransaction",
        subtype: "dividend",
        account: OpenStruct.new(name: "Schwab Brokerage"),
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: inv_txn, show_investment_columns: true, view_type: "investments"))

      assert_selector "span.badge-info", text: "Dividend"
    end

    test "category label renders for cash view" do
      cash_txn = OpenStruct.new(
        date: Date.new(2026, 1, 15),
        name: "Grocery Store",
        amount: -125.50,
        type: "RegularTransaction",
        personal_finance_category_label: "FOOD_AND_DRINK→SUPERMARKETS",
        account: OpenStruct.new(name: "Chase Checking"),
        merchant_name: "Grocery Store",
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: cash_txn, view_type: "cash"))

      assert_selector "span.badge-outline", text: "FOOD_AND_DRINK"
    end

    test "category label shows first segment only" do
      cash_txn = OpenStruct.new(
        date: Date.new(2026, 1, 15),
        name: "Gas Station",
        amount: -50.00,
        type: "RegularTransaction",
        personal_finance_category_label: "TRANSPORTATION→GAS_STATIONS",
        account: OpenStruct.new(name: "Chase Checking"),
        merchant_name: "Shell",
        pending: false,
        is_recurring: false
      )

      render_inline(RowComponent.new(transaction: cash_txn, view_type: "regular"))

      assert_selector "span.badge-outline", text: "TRANSPORTATION"
      assert_no_selector "span.badge-outline", text: "GAS_STATIONS"
    end

    test "external? flag set by TransferDeduplicator" do
      out = OpenStruct.new(
        date: Date.new(2026, 1, 15),
        name: "Wire out",
        amount: -500.00,
        type: "RegularTransaction",
        account: OpenStruct.new(name: "Chase Checking"),
        merchant_name: nil,
        pending: false,
        is_recurring: false
      )
      out.instance_variable_set(:@_external, true)

      component = RowComponent.new(transaction: out, view_type: "transfers")

      assert component.external?
    end
  end
end
