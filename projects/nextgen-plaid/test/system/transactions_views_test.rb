# frozen_string_literal: true

require "application_system_test_case"

class TransactionsViewsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    login_as(@user, scope: :user)
    Rails.cache.clear

    @plaid_item = PlaidItem.find_by(item_id: "sys_test_item_1") || PlaidItem.create!(
      user: @user,
      item_id: "sys_test_item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good,
      access_token: "sys_test_token"
    )

    @depository_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "sys_acc_dep_1",
      name: "Checking",
      mask: "1111",
      plaid_account_type: "depository"
    )

    @savings_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "sys_acc_dep_2",
      name: "Savings",
      mask: "2222",
      plaid_account_type: "depository"
    )

    @credit_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "sys_acc_cred_1",
      name: "Credit Card",
      mask: "3333",
      plaid_account_type: "credit"
    )

    @investment_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "sys_acc_inv_1",
      name: "Brokerage",
      mask: "4444",
      plaid_account_type: "investment"
    )

    # Regular transaction
    RegularTransaction.find_or_create_by!(
      account: @depository_account,
      transaction_id: "sys_txn_reg_1",
      name: "Coffee Shop",
      amount: -5.50,
      date: Date.today,
      merchant_name: "Coffee Shop",
      personal_finance_category_label: "Food & Dining → Restaurants"
    )

    # Credit transaction
    CreditTransaction.find_or_create_by!(
      account: @credit_account,
      transaction_id: "sys_txn_cred_1",
      name: "Amazon Purchase",
      amount: -50.00,
      date: Date.today,
      merchant_name: "Amazon"
    )

    # Investment transaction
    InvestmentTransaction.find_or_create_by!(
      account: @investment_account,
      transaction_id: "sys_txn_inv_1",
      name: "Buy AAPL",
      amount: -1000.00,
      date: Date.today,
      subtype: "buy",
      security_id: "sec_aapl",
      quantity: 10,
      price: 100.00
    )

    # Transfer pair (internal) - must have TRANSFER category label
    RegularTransaction.find_or_create_by!(
      account: @depository_account,
      transaction_id: "sys_txn_trans_out",
      name: "Transfer to Savings",
      amount: -200.00,
      date: Date.today,
      personal_finance_category_label: "TRANSFER_INTERNAL"
    )
    RegularTransaction.find_or_create_by!(
      account: @savings_account,
      transaction_id: "sys_txn_trans_in",
      name: "Transfer from Checking",
      amount: 200.00,
      date: Date.today,
      personal_finance_category_label: "TRANSFER_INTERNAL"
    )

    # External transfer (no pair)
    RegularTransaction.find_or_create_by!(
      account: @depository_account,
      transaction_id: "sys_txn_ext",
      name: "External Wire",
      amount: -500.00,
      date: Date.today,
      personal_finance_category_label: "TRANSFER_EXTERNAL"
    )
  end

  test "regular view loads and shows columns" do
    visit transactions_regular_path
    assert_selector "table"
    # Check column headers
    assert_text "Date"
    assert_text "Name"
    assert_text "Type"
    assert_text "Merchant"
    assert_text "Account"
    assert_text "Amount"
    # Check at least one transaction row
    assert_text "Coffee Shop"
    # Check category badge (first segment before →)
    assert_selector ".badge", text: "Food & Dining"
  end

  test "investment view shows security link" do
    visit transactions_investment_path
    assert_selector "table"
    # Check investment columns
    assert_text "Security"
    assert_text "Quantity"
    assert_text "Price"
    # Check security link exists (should be a link to portfolio security page)
    assert_selector "a[href*='/portfolio/securities/sec_aapl']"
  end

  test "transfers view shows internal/external badges" do
    visit transactions_transfers_path
    assert_selector "table"
    # Check transfer columns (header is "Details")
    assert_text "Details"
    # Internal transfer should show Internal badge
    assert_selector ".badge", text: "Internal"
    # External transfer should show External badge
    assert_selector ".badge", text: "External"
  end
end
