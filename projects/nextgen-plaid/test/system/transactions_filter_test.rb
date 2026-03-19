# frozen_string_literal: true

require "application_system_test_case"

class TransactionsFilterTest < ApplicationSystemTestCase
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

    @credit_account = Account.find_or_create_by!(
      plaid_item: @plaid_item,
      account_id: "sys_acc_cred_1",
      name: "Credit Card",
      mask: "3333",
      plaid_account_type: "credit"
    )

    RegularTransaction.find_or_create_by!(
      account: @depository_account,
      transaction_id: "sys_txn_reg_1",
      name: "Coffee Shop",
      amount: -5.50,
      date: Date.today,
      merchant_name: "Coffee Shop"
    )

    CreditTransaction.find_or_create_by!(
      account: @credit_account,
      transaction_id: "sys_txn_cred_1",
      name: "Amazon Purchase",
      amount: -50.00,
      date: Date.today,
      merchant_name: "Amazon"
    )

    @filter = @user.saved_account_filters.create!(
      name: "Checking Only",
      criteria: { "account_ids" => [ @depository_account.id.to_s ] }
    )
  end

  test "visiting regular transactions page shows filter selector" do
    visit transactions_regular_path
    assert_selector ".dropdown", text: /Accounts/
    assert_selector ".dropdown-content a", text: "All Accounts"
    assert_selector ".dropdown-content a", text: "Checking Only"
  end

  test "selecting a saved filter reloads with filter applied" do
    visit transactions_regular_path
    assert_text "Coffee Shop"

    # Click the filter link with saved_account_filter_id
    visit transactions_regular_path(saved_account_filter_id: @filter.id)
    assert_text "Coffee Shop"
    # Verify the filter selector shows the selected filter
    assert_selector ".dropdown label", text: /Checking Only/
  end

  test "all accounts resets filter" do
    visit transactions_regular_path(saved_account_filter_id: @filter.id)
    assert_selector ".dropdown label", text: /Checking Only/

    visit transactions_regular_path
    assert_selector ".dropdown label", text: /All Accounts/
  end

  test "filter bar preserves saved_account_filter_id in hidden field" do
    visit transactions_regular_path(saved_account_filter_id: @filter.id)
    assert_selector "input[name='saved_account_filter_id'][value='#{@filter.id}']", visible: :all
  end

  test "summary page shows filter selector" do
    visit transactions_summary_path
    assert_selector ".dropdown", text: /Accounts/
    assert_selector ".dropdown-content a", text: "All Accounts"
  end

  test "investment page shows filter selector" do
    visit transactions_investment_path
    assert_selector ".dropdown", text: /Accounts/
  end

  test "credit page shows filter selector" do
    visit transactions_credit_path
    assert_selector ".dropdown", text: /Accounts/
  end

  test "transfers page shows filter selector" do
    visit transactions_transfers_path
    assert_selector ".dropdown", text: /Accounts/
  end
end
