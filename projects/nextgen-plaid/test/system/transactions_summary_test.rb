# frozen_string_literal: true

require "application_system_test_case"

class TransactionsSummaryTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)

    # Create PlaidItem
    @plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "test_item_summary",
      institution_name: "Test Bank",
      institution_id: "ins_summary",
      status: :good,
      access_token: "test_token_summary"
    )

    # Create account
    @account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_summary",
      name: "Test Checking",
      mask: "9999",
      plaid_account_type: "depository"
    )

    # Create transactions
    RegularTransaction.create!(
      account: @account,
      transaction_id: "txn_summary_1",
      name: "Coffee Shop",
      amount: -5.50,
      date: Date.today,
      merchant_name: "Starbucks",
      personal_finance_category_label: "FOOD_AND_DRINK"
    )
    RegularTransaction.create!(
      account: @account,
      transaction_id: "txn_summary_2",
      name: "Salary Deposit",
      amount: 3000.00,
      date: Date.today,
      personal_finance_category_label: "INCOME"
    )

    login_as(@user, scope: :user)
  end

  test "visiting summary page shows stat cards" do
    visit transactions_summary_path

    assert_selector ".card", minimum: 4
    assert_text "Total Transactions"
    assert_text "Total Inflow"
    assert_text "Total Outflow"
    assert_text "Net"
  end

  test "summary page shows transaction count" do
    visit transactions_summary_path

    # Should show count of 2 in the stat card
    assert_selector ".card", text: /Total Transactions.*2/m
  end

  test "summary page shows top categories card if data exists" do
    visit transactions_summary_path

    assert_selector "h2", text: "Top Categories"
    assert_selector "table"
    assert_text "FOOD_AND_DRINK"
  end

  test "summary page shows top merchants card if data exists" do
    visit transactions_summary_path

    assert_selector "h2", text: "Top Merchants"
    assert_selector "table"
    assert_text "Starbucks"
  end

  test "summary page shows monthly totals card" do
    visit transactions_summary_path

    assert_selector "h2", text: "Monthly Totals"
    assert_selector "table"
  end

  test "summary page shows recurring expenses if RecurringTransaction data exists" do
    RecurringTransaction.create!(
      plaid_item: @plaid_item,
      stream_id: "stream_test_1",
      description: "Netflix",
      merchant_name: "Netflix",
      frequency: "monthly",
      stream_type: "outflow",
      average_amount: -15.99,
      last_date: Date.today
    )

    visit transactions_summary_path

    assert_selector "h2", text: "Top Recurring Expenses"
    assert_text "Netflix"
  end

  test "summary page with no transactions shows zero values" do
    # Delete all transactions
    Transaction.where(account: @account).delete_all

    visit transactions_summary_path

    # Should show zero in transaction count
    assert_selector ".card", text: /Total Transactions.*0/m
    assert_text "$0.00"
  end

  test "summary page currency values formatted correctly" do
    visit transactions_summary_path

    # Should show dollar amounts with proper formatting
    assert_text /\$\d+\.\d{2}/
  end

  test "summary page color codes positive and negative amounts" do
    visit transactions_summary_path

    # Check for text-success and text-error classes (can't directly assert CSS, but can check they render)
    assert_selector ".text-success"
    assert_selector ".text-error"
  end
end
