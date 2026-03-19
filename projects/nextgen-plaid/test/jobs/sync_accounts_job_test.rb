require "test_helper"
require "ostruct"

class SyncAccountsJobTest < ActiveJob::TestCase
  test "job syncs balances via PlaidAccountsSyncService and marks success" do
    user = User.create!(email: "sync-accounts-job@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_sync_accounts_job", institution_name: "Test Inst", access_token: "tok_job", status: "good")

    balances = OpenStruct.new(current: 10.00, available: 9.00, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(
      account_id: "acc_job",
      persistent_account_id: "pa_job",
      name: "Checking",
      mask: "1111",
      type: "depository",
      subtype: "checking",
      balances: balances
    )
    fake_response = OpenStruct.new(accounts: [ plaid_account ], request_id: "req_job")

    original_plaid_env = ENV["PLAID_ENV"]
    ENV["PLAID_ENV"] = "sandbox"
    with_stubbed_plaid_client(accounts_get: fake_response) do
      SyncAccountsJob.perform_now(item.id)
    end
  ensure
    ENV["PLAID_ENV"] = original_plaid_env

    account = item.accounts.find_by(account_id: "acc_job", source: "plaid")
    refute_nil account
    assert_equal BigDecimal("10.0"), account.current_balance
    assert_equal BigDecimal("9.0"), account.available_balance
    assert_equal "success", account.balances_last_sync_status
    refute_nil account.balances_last_synced_at
  end

  test "job does not skip in non-production Rails env when PLAID_ENV is production" do
    user = User.create!(email: "sync-accounts-job-prod-env@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_sync_accounts_job_prod_env", institution_name: "Test Inst", access_token: "tok_job_prod_env", status: "good")

    balances = OpenStruct.new(current: 12.00, available: 11.00, iso_currency_code: "USD")
    plaid_account = OpenStruct.new(
      account_id: "acc_job_prod_env",
      persistent_account_id: "pa_job_prod_env",
      name: "Checking",
      mask: "3333",
      type: "depository",
      subtype: "checking",
      balances: balances
    )
    fake_response = OpenStruct.new(accounts: [ plaid_account ], request_id: "req_job_prod_env")

    original_plaid_env = ENV["PLAID_ENV"]
    ENV["PLAID_ENV"] = "production"
    with_stubbed_plaid_client(accounts_get: fake_response) do
      SyncAccountsJob.perform_now(item.id)
    end
  ensure
    ENV["PLAID_ENV"] = original_plaid_env

    account = item.accounts.find_by(account_id: "acc_job_prod_env", source: "plaid")
    refute_nil account
    assert_equal BigDecimal("12.0"), account.current_balance
    assert_equal BigDecimal("11.0"), account.available_balance
    assert_equal "success", account.balances_last_sync_status
    refute_nil account.balances_last_synced_at
  end

  test "job records failure on exception (no immediate retry loop)" do
    user = User.create!(email: "sync-accounts-job-fail@example.com", password: "Password!123")
    item = PlaidItem.create!(user: user, item_id: "it_sync_accounts_job_fail", institution_name: "Test Inst", access_token: "tok_job_fail", status: "good")

    account = item.accounts.create!(
      account_id: "acc_existing",
      persistent_account_id: "pa_existing",
      name: "Checking",
      mask: "2222",
      plaid_account_type: "depository",
      subtype: "checking",
      source: "plaid"
    )

    failing_service = Object.new
    def failing_service.sync
      raise StandardError, "boom"
    end

    original_plaid_env = ENV["PLAID_ENV"]
    ENV["PLAID_ENV"] = "sandbox"
    PlaidAccountsSyncService.stub(:new, failing_service) do
      SyncAccountsJob.perform_now(item.id)
    end
  ensure
    ENV["PLAID_ENV"] = original_plaid_env

    account = item.accounts.find_by(account_id: "acc_existing", source: "plaid")
    refute_nil account
    assert_equal "failure", account.reload.balances_last_sync_status
    assert_includes account.balances_last_sync_error.to_s, "boom"
    refute_nil account.balances_last_synced_at
  end
end
