# frozen_string_literal: true

require "test_helper"

module Transactions
  class GridComponentTest < ViewComponent::TestCase
    setup do
      @transactions = [
        OpenStruct.new(
          date: Date.new(2026, 1, 15), name: "Test", amount: -50.0, type: "RegularTransaction",
          merchant_name: "TestMerchant", account_name: "Chase Checking", is_recurring: false,
          pending: false
        ),
        OpenStruct.new(
          date: Date.new(2026, 1, 16), name: "Test2", amount: 100.0, type: "InvestmentTransaction",
          merchant_name: nil, account_name: "Schwab Brokerage", security_name: "AAPL",
          security_id: "sec_aapl", quantity: 10, price: 175.0, is_recurring: false,
          pending: false
        )
      ]
    end

    test "renders grid with transactions" do
      with_request_url "/transactions/regular" do
        render_inline(
          GridComponent.new(
            transactions: @transactions,
            total_count: 2,
            page: 1,
            per_page: "25",
            sort: "date",
            dir: "desc",
            view_type: "cash"
          )
        )

        assert_selector "table"
        assert_selector "tbody tr", count: 2
        assert_selector "th", text: /Date/
        assert_selector "th", text: /Name/
        assert_selector "th", text: /Type/
        assert_selector "th", text: /Amount/
      end
    end

    test "investments view shows Account column and hides Merchant" do
      with_request_url "/transactions/investment" do
        render_inline(
          GridComponent.new(
            transactions: @transactions,
            total_count: 2,
            page: 1,
            per_page: "25",
            sort: "date",
            dir: "desc",
            show_investment_columns: true,
            view_type: "investments"
          )
        )

        # Account column should be present (bold header for investments)
        assert_selector "th.font-bold", text: /Account/
        # Security, Quantity, Price columns should be present
        assert_selector "th", text: /Security/
        assert_selector "th", text: /Quantity/
        assert_selector "th", text: /Price/
        # Merchant column should NOT be present
        assert_no_selector "th", text: "Merchant"
      end
    end

    test "transfers view hides Merchant column and shows Details" do
      with_request_url "/transactions/transfers" do
        render_inline(
          GridComponent.new(
            transactions: @transactions,
            total_count: 2,
            page: 1,
            per_page: "25",
            sort: "date",
            dir: "desc",
            view_type: "transfers"
          )
        )

        assert_no_selector "th", text: "Merchant"
        assert_selector "th", text: "Details"
      end
    end

    test "paginates transactions when per_page is less than total" do
      with_request_url "/transactions/regular" do
        # Data provider handles pagination, component renders what it receives
        # Pass only the transactions for page 2 (2 transactions)
        page_2_transactions = @transactions.take(2)
        component = GridComponent.new(
          transactions: page_2_transactions,
          total_count: 6,
          page: 2,
          per_page: "2",
          sort: "date",
          dir: "desc",
          view_type: "cash"
        )
        render_inline(component)

        assert_selector "tbody tr", count: 2
      end
    end

    test "shows pagination info" do
      with_request_url "/transactions/regular" do
        render_inline(
          GridComponent.new(
            transactions: @transactions,
            total_count: 50,
            page: 2,
            per_page: "25",
            sort: "date",
            dir: "desc",
            view_type: "cash"
          )
        )

        assert_text "Showing 26 – 50 of 50 transactions"
      end
    end

    test "defines TRANSACTIONS_GRID_TURBO_FRAME_ID constant" do
      assert_equal "transactions_grid", GridComponent::TRANSACTIONS_GRID_TURBO_FRAME_ID
    end

    test "does not render its own turbo frame (frame is at view template level)" do
      with_request_url "/transactions/regular" do
        render_inline(
          GridComponent.new(
            transactions: @transactions,
            total_count: 2,
            page: 1,
            per_page: "25",
            sort: "date",
            dir: "desc",
            view_type: "cash"
          )
        )

        assert_no_selector "turbo-frame[id='transactions_grid']"
      end
    end

    test "all columns are sortable in investments view" do
      with_request_url "/transactions/investment" do
        render_inline(
          GridComponent.new(
            transactions: @transactions,
            total_count: 2,
            page: 1,
            per_page: "25",
            sort: "date",
            dir: "desc",
            show_investment_columns: true,
            view_type: "investments"
          )
        )

        # All sortable headers should have links
        assert_selector "th a[href*='sort=date']"
        assert_selector "th a[href*='sort=account']"
        assert_selector "th a[href*='sort=name']"
        assert_selector "th a[href*='sort=security']"
        assert_selector "th a[href*='sort=quantity']"
        assert_selector "th a[href*='sort=price']"
        assert_selector "th a[href*='sort=amount']"
      end
    end
  end
end
