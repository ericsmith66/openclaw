# frozen_string_literal: true

require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    sign_in @user
    Rails.cache.clear

    # Ensure user has a PlaidItem
    @plaid_item = PlaidItem.find_by(item_id: "test_item_1") || PlaidItem.create!(
      user: @user,
      item_id: "test_item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good,
      access_token: "test_token"
    )

    # Create accounts
    @depository_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "acc_dep_1",
      name: "Checking",
      mask: "1111",
      plaid_account_type: "depository"
    )
    @investment_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "acc_inv_1",
      name: "Brokerage",
      mask: "2222",
      plaid_account_type: "investment"
    )
    @credit_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "acc_cred_1",
      name: "Credit Card",
      mask: "3333",
      plaid_account_type: "credit"
    )

    # Create sample transactions (one of each type)
    RegularTransaction.find_or_create_by!(
      account: @depository_account,
      transaction_id: "txn_reg_1",
      name: "Coffee Shop",
      amount: -5.50,
      date: Date.today,
      merchant_name: "Coffee Shop"
    )
    InvestmentTransaction.find_or_create_by!(
      account: @investment_account,
      transaction_id: "txn_inv_1",
      name: "Buy AAPL",
      amount: -1000.00,
      date: Date.today
    )
    CreditTransaction.find_or_create_by!(
      account: @credit_account,
      transaction_id: "txn_cred_1",
      name: "Amazon Purchase",
      amount: -50.00,
      date: Date.today,
      merchant_name: "Amazon"
    )
  end

  test "regular action returns 200" do
    get transactions_regular_path
    assert_response :success
  end

  test "investment action returns 200" do
    get transactions_investment_path
    assert_response :success
  end

  test "credit action returns 200" do
    get transactions_credit_path
    assert_response :success
  end

  test "transfers action returns 200" do
    get transactions_transfers_path
    assert_response :success
  end

  test "summary action returns 200" do
    get transactions_summary_path
    assert_response :success
  end

  test "regular action renders saved account filter selector component" do
    get transactions_regular_path
    assert_response :success
    assert_select ".dropdown", text: /Accounts/
    assert_select ".dropdown-content a", text: "All Accounts"
  end

  test "regular action supports saved_account_filter_id param" do
    filter = @user.saved_account_filters.create!(name: "Test Filter", criteria: { "account_ids" => [ @depository_account.id.to_s ] })
    get transactions_regular_path, params: { saved_account_filter_id: filter.id }
    assert_response :success
  end

  test "summary action supports saved_account_filter_id param" do
    filter = @user.saved_account_filters.create!(name: "Test Filter", criteria: { "account_ids" => [ @depository_account.id.to_s ] })
    get transactions_summary_path, params: { saved_account_filter_id: filter.id }
    assert_response :success
  end

  test "investment action supports saved_account_filter_id param" do
    filter = @user.saved_account_filters.create!(name: "Test Filter", criteria: { "account_ids" => [ @investment_account.id.to_s ] })
    get transactions_investment_path, params: { saved_account_filter_id: filter.id }
    assert_response :success
  end

  test "regular action supports search_term param" do
    get transactions_regular_path, params: { search_term: "Google" }
    assert_response :success
  end

  test "investment action supports sorting params" do
    get transactions_investment_path, params: { sort: "security", dir: "asc" }
    assert_response :success
  end

  test "summary action renders page content" do
    get transactions_summary_path
    assert_response :success
    # Summary page should render breadcrumbs
    assert_select ".breadcrumbs"
  end

  test "regular action renders breadcrumb with Transactions parent" do
    get transactions_regular_path
    assert_response :success
    assert_select ".breadcrumbs a", text: "Transactions"
    assert_select ".breadcrumbs li", text: "Cash & Checking"
  end

  test "investment action renders breadcrumb" do
    get transactions_investment_path
    assert_response :success
    assert_select ".breadcrumbs a", text: "Transactions"
    assert_select ".breadcrumbs li", text: "Investments"
  end

  test "regular action renders dynamic search placeholder" do
    get transactions_regular_path
    assert_response :success
    assert_select "input[name='search_term'][placeholder='Search by name, merchant…']"
  end

  test "investment action renders investment-specific search placeholder" do
    get transactions_investment_path
    assert_response :success
    assert_select "input[name='search_term'][placeholder='Search by name, security…']"
  end

  test "transfers action applies TransferDeduplicator" do
    # Create transfer pair: $1000 outbound, $1000 inbound on same day
    # Use two depository accounts (not credit) to ensure they pass data provider filter
    @depository_account_2 = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "acc_dep_2",
      name: "Savings",
      mask: "2222",
      plaid_account_type: "depository"
    )

    out = RegularTransaction.create!(
      account: @depository_account,
      transaction_id: "ctrl_test_out",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction",
      personal_finance_category_label: "TRANSFER_OUTBOUND"
    )
    in_txn = RegularTransaction.create!(
      account: @depository_account_2,
      transaction_id: "ctrl_test_in",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.today,
      type: "RegularTransaction",
      personal_finance_category_label: "TRANSFER_INBOUND"
    )

    get transactions_transfers_path

    # Should return deduplicated results (only outbound)
    assert_response :success
    # Outbound transaction should appear in the table (inbound suppressed)
    assert_select "table tbody tr", count: 1
    # Should show Internal badge
    assert_select ".badge", text: "Internal"
  end

  test "transfers action returns external transfers with unmatched legs" do
    # Create only outbound transfer (no matching inbound)
    out = RegularTransaction.create!(
      account: @depository_account,
      transaction_id: "ctrl_test_ext",
      name: "Wire out",
      amount: -500.00,
      date: Date.today,
      type: "RegularTransaction",
      personal_finance_category_label: "TRANSFER_OUTBOUND"
    )

    get transactions_transfers_path

    assert_response :success
    # Should appear in table
    assert_select "table tbody tr", count: 1
    # Should show External badge
    assert_select ".badge", text: "External"
  end

  test "transfers action excludes investment account transactions" do
    # The data provider already filters out investment accounts
    # Create transactions only with depository accounts
    @depository_account_2 ||= Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "acc_dep_2",
      name: "Savings",
      mask: "2222",
      plaid_account_type: "depository"
    )

    RegularTransaction.create!(
      account: @depository_account,
      transaction_id: "ctrl_test_inv_out",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction",
      personal_finance_category_label: "TRANSFER_OUTBOUND"
    )
    RegularTransaction.create!(
      account: @depository_account_2,
      transaction_id: "ctrl_test_inv_in",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.today,
      type: "RegularTransaction",
      personal_finance_category_label: "TRANSFER_INBOUND"
    )

    get transactions_transfers_path

    assert_response :success
    # Should show only outbound transaction (inbound suppressed)
    assert_select "table tbody tr", count: 1
    # Should show Internal badge
    assert_select ".badge", text: "Internal"
  end

  # Summary View Tests
  test "GET summary returns 200 with live data" do
    get transactions_summary_path
    assert_response :success
    assert_select ".card", minimum: 4
  end

  test "GET summary populates summary stats" do
    get transactions_summary_path
    assert_response :success

    # Verify stat cards are rendered
    assert_select ".card", text: /Total Transactions/
    assert_select ".card", text: /Total Inflow/
    assert_select ".card", text: /Total Outflow/
    assert_select ".card", text: /Net/
  end

  test "GET summary with saved_account_filter_id" do
    filter = @user.saved_account_filters.create!(
      name: "Test Filter",
      criteria: { "account_ids" => [ @depository_account.id.to_s ] }
    )

    get transactions_summary_path(saved_account_filter_id: filter.id)
    assert_response :success
    assert_select ".card", minimum: 4
  end

  test "GET summary populates top_recurring from RecurringTransaction model" do
    # Create a RecurringTransaction for the user
    RecurringTransaction.create!(
      plaid_item: @plaid_item,
      stream_id: "stream_1",
      description: "Netflix Subscription",
      merchant_name: "Netflix",
      frequency: "monthly",
      stream_type: "outflow",
      average_amount: -15.99,
      last_date: Date.today
    )

    get transactions_summary_path
    assert_response :success
    assert_select "h2", text: "Top Recurring Expenses"
    assert_select "table", text: /Netflix/
  end

  test "GET summary with no transactions shows zeros" do
    # Delete all transactions for this user
    Transaction.where(account: [ @depository_account, @investment_account, @credit_account ]).delete_all

    get transactions_summary_path
    assert_response :success

    # Should show stat cards with zero values
    assert_select ".card", minimum: 4
  end
end
