require "test_helper"
require "ostruct"

class PlaidAccountsSyncServiceTest < ActiveSupport::TestCase
  test "sync upserts balances and balance sync metadata from /accounts/get" do
    user = User.create!(email: "accounts-sync@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_accounts", institution_name: "Test Inst", access_token: "tok_accounts", status: "good")

    balances = OpenStruct.new(current: 100.25, available: 80.10, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(
      account_id: "acc_1",
      persistent_account_id: "pa_1",
      name: "Checking",
      mask: "1234",
      type: "depository",
      subtype: "checking",
      balances: balances
    )
    fake_response = OpenStruct.new(accounts: [ plaid_account ], request_id: "req_accounts")

    assert_difference "PlaidApiCall.where(product: 'accounts', endpoint: '/accounts/get').count", +1 do
      with_stubbed_plaid_client(accounts_get: fake_response) do
        PlaidAccountsSyncService.new(item).sync
      end
    end

    account = item.accounts.find_by(account_id: "acc_1", source: "plaid")
    refute_nil account
    assert_equal BigDecimal("100.25"), account.current_balance
    assert_equal BigDecimal("80.10"), account.available_balance
    assert_equal "USD", account.iso_currency_code
    assert_equal "success", account.balances_last_sync_status
    refute_nil account.balances_last_synced_at
    assert_nil account.balances_last_sync_error
  end

  test "sync logs warning-only when balances are missing" do
    user = User.create!(email: "accounts-sync-missing@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_accounts_missing", institution_name: "Test Inst", access_token: "tok_accounts_missing", status: "good")

    balances = OpenStruct.new(current: nil, available: nil, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(
      account_id: "acc_missing",
      persistent_account_id: nil,
      name: "Checking",
      mask: "9999",
      type: "depository",
      subtype: "checking",
      balances: balances
    )
    fake_response = OpenStruct.new(accounts: [ plaid_account ], request_id: "req_accounts_missing")

    logger = Minitest::Mock.new
    logger.expect(:warn, nil, [ String ])

    with_stubbed_plaid_client(accounts_get: fake_response) do
      Rails.stub(:logger, logger) do
        PlaidAccountsSyncService.new(item).sync
      end
    end

    logger.verify
    account = item.accounts.find_by(account_id: "acc_missing", source: "plaid")
    refute_nil account
    assert_equal "success", account.balances_last_sync_status
  end
end
