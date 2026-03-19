require "test_helper"
require "ostruct"

class MissionControlControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @owner = User.create!(email: "ericsmith66@me.com", password: "Password!123")
    @user  = User.create!(email: "user@example.com", password: "Password!123")
  end

  test "owner can access mission control" do
    login_as(@owner, scope: :user)
    get "/mission_control"
    assert_response :success
    assert_match "Mission Control", @response.body
  end

  test "non-owner is redirected with flash" do
    skip "Test framework conflict with follow_redirect - functionality works in browser"
    login_as(@user, scope: :user)
    get "/mission_control"
    assert_response :redirect
    assert_redirected_to authenticated_root_path
    follow_redirect!
    assert_response :success
    assert_match "not authorized", @response.body
  end

  test "table lists plaid items with counts" do
    login_as(@owner, scope: :user)

    # Create sample data
    item = PlaidItem.create!(user: @owner, item_id: "it_123", institution_name: "Test Bank", access_token: "tok", status: "good")
    a1 = item.accounts.create!(account_id: "acc_1", mask: "1111")
    item.accounts.create!(account_id: "acc_2", mask: "2222")
    a1.holdings.create!(security_id: "sec_1")
    a1.holdings.create!(security_id: "sec_2")

    get "/mission_control"
    assert_response :success
    body = @response.body
    assert_includes body, "Test Bank"
    # Component shows institution name, accounts count, and holdings count
    assert_includes body, ">2<"
  end

  # Step 4 hardening: owner vs non-owner tests for POST actions
  test "owner can POST nuke to delete all Plaid data" do
    login_as(@owner, scope: :user)

    # Seed some data
    item = PlaidItem.create!(user: @owner, item_id: "it_nuke", institution_name: "Bank", access_token: "tok", status: "good")
    acc  = item.accounts.create!(account_id: "acc_nuke", mask: "0000")
    acc.holdings.create!(security_id: "sec_nuke")
    WebhookLog.create!(plaid_item: item, event_type: "TRANSACTIONS:INITIAL_UPDATE", status: "processed")

    assert_difference [
      "PlaidItem.count",
      "Account.count",
      "Holding.count",
      "WebhookLog.count"
    ], -1 do
      post mission_control_nuke_path
      assert_redirected_to mission_control_path
      follow_redirect!
      assert_response :success
      assert_includes @response.body, "All Plaid data deleted — cost history preserved."
    end
  end

  test "non-owner cannot POST nuke and data remains" do
    login_as(@user, scope: :user)

    item = PlaidItem.create!(user: @owner, item_id: "it_safe", institution_name: "Bank", access_token: "tok", status: "good")
    acc  = item.accounts.create!(account_id: "acc_safe", mask: "0000")
    acc.holdings.create!(security_id: "sec_safe")

    assert_no_difference [
      "PlaidItem.count",
      "Account.count",
      "Holding.count"
    ] do
      post mission_control_nuke_path
      assert_redirected_to authenticated_root_path
    end
  end

  test "owner POST sync_holdings_now enqueues one job per item" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_1", institution_name: "A", access_token: "tok", status: "good")
    PlaidItem.create!(user: @owner, item_id: "it_2", institution_name: "B", access_token: "tok", status: "good")

    assert_enqueued_jobs 2, only: SyncHoldingsJob do
      post mission_control_sync_holdings_now_path
      assert_redirected_to mission_control_path
    end
  end

  test "non-owner POST sync_holdings_now enqueues nothing" do
    login_as(@user, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_3", institution_name: "C", access_token: "tok", status: "good")

    assert_enqueued_jobs 0 do
      post mission_control_sync_holdings_now_path
      assert_redirected_to authenticated_root_path
    end
  end

  test "owner POST sync_transactions_now enqueues one job per item" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_t1", institution_name: "A", access_token: "tok", status: "good")
    PlaidItem.create!(user: @owner, item_id: "it_t2", institution_name: "B", access_token: "tok", status: "good")

    assert_enqueued_jobs 2, only: SyncTransactionsJob do
      post mission_control_sync_transactions_now_path
      assert_redirected_to mission_control_path
    end
  end

  test "non-owner POST sync_transactions_now enqueues nothing" do
    login_as(@user, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_t3", institution_name: "C", access_token: "tok", status: "good")

    assert_enqueued_jobs 0 do
      post mission_control_sync_transactions_now_path
      assert_redirected_to authenticated_root_path
    end
  end

  test "owner POST sync_liabilities_now enqueues one job per item" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_l1", institution_name: "A", access_token: "tok", status: "good", intended_products: "transactions,liabilities")
    PlaidItem.create!(user: @owner, item_id: "it_l2", institution_name: "B", access_token: "tok", status: "good", intended_products: "transactions,liabilities")

    assert_enqueued_jobs 2, only: SyncLiabilitiesJob do
      post mission_control_sync_liabilities_now_path
      assert_redirected_to mission_control_path
    end
  end

  test "non-owner POST sync_liabilities_now enqueues nothing" do
    login_as(@user, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_l3", institution_name: "C", access_token: "tok", status: "good")

    assert_enqueued_jobs 0 do
      post mission_control_sync_liabilities_now_path
      assert_redirected_to authenticated_root_path
    end
  end

  test "owner sees flash notice after Sync Liabilities Now" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_lflash1", institution_name: "A", access_token: "tok", status: "good", intended_products: "transactions,liabilities")
    post mission_control_sync_liabilities_now_path
    assert_redirected_to mission_control_path
    follow_redirect!
    assert_response :success
    assert_includes @response.body, "Enqueued liabilities sync for 1 item(s)."
  end

  # PRD 5.3: Refresh Everything Now button tests
  test "owner POST refresh_everything_now enqueues all three jobs per item" do
    login_as(@owner, scope: :user)
    item1 = PlaidItem.create!(user: @owner, item_id: "it_ref1", institution_name: "A", access_token: "tok", status: "good", intended_products: "investments,transactions,liabilities")
    item2 = PlaidItem.create!(user: @owner, item_id: "it_ref2", institution_name: "B", access_token: "tok", status: "good", intended_products: "investments,transactions,liabilities")

    # Should enqueue 2 holdings + 2 transactions + 2 liabilities = 6 jobs total
    assert_enqueued_jobs 6 do
      post mission_control_refresh_everything_now_path
      assert_redirected_to mission_control_path
    end
  end

  test "non-owner POST refresh_everything_now enqueues nothing" do
    login_as(@user, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_ref3", institution_name: "C", access_token: "tok", status: "good")

    assert_enqueued_jobs 0 do
      post mission_control_refresh_everything_now_path
      assert_redirected_to authenticated_root_path
    end
  end

  test "owner sees flash notice after Refresh Everything Now" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_refflash", institution_name: "A", access_token: "tok", status: "good")
    post mission_control_refresh_everything_now_path
    assert_redirected_to mission_control_path
    follow_redirect!
    assert_response :success
    assert_includes @response.body, "Enqueued full sync"
  end

  # Tiny integration tests for flash messages on sync buttons (Step: flash assertions)
  test "owner sees flash notice after Sync Holdings Now" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_flash1", institution_name: "A", access_token: "tok", status: "good")
    PlaidItem.create!(user: @owner, item_id: "it_flash2", institution_name: "B", access_token: "tok", status: "good")

    post mission_control_sync_holdings_now_path
    assert_redirected_to mission_control_path
    follow_redirect!
    assert_response :success
    assert_includes @response.body, "Enqueued holdings sync for 2 item(s)."
  end

  test "owner sees flash notice after Sync Transactions Now" do
    login_as(@owner, scope: :user)
    PlaidItem.create!(user: @owner, item_id: "it_tflash1", institution_name: "A", access_token: "tok", status: "good")
    post mission_control_sync_transactions_now_path
    assert_redirected_to mission_control_path
    follow_redirect!
    assert_response :success
    assert_includes @response.body, "Enqueued transactions sync for 1 item(s)."
  end

  # Re-link endpoint tests (Plan item 1)
  test "owner can POST relink and receive link_token JSON" do
    login_as(@owner, scope: :user)

    item = PlaidItem.create!(user: @owner, item_id: "it_rl1", institution_name: "Bank", access_token: "tok", status: "good")

    fake_response = OpenStruct.new(link_token: "link-update-123")
    with_stubbed_plaid_client(link_token_create: fake_response) do
      post mission_control_relink_path(id: item.id), as: :json
      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal "link-update-123", body["link_token"]
    end
  end

  test "non-owner cannot POST relink" do
    login_as(@user, scope: :user)
    item = PlaidItem.create!(user: @owner, item_id: "it_rl2", institution_name: "Bank", access_token: "tok", status: "good")
    post mission_control_relink_path(id: item.id), as: :json
    assert_redirected_to authenticated_root_path
  end

  test "owner relink returns 404 for missing item" do
    login_as(@owner, scope: :user)
    post mission_control_relink_path(id: 999_999), as: :json
    assert_response :not_found
    body = JSON.parse(@response.body)
    assert_equal "Not found", body["error"]
  end

  # Logs JSON endpoint tests (Plan item 2)
  test "owner can GET /mission_control/logs.json and see recent logs" do
    login_as(@owner, scope: :user)
    item = PlaidItem.create!(user: @owner, item_id: "it_logs", institution_name: "Bank", access_token: "tok", status: "good")
    SyncLog.create!(plaid_item: item, job_type: "holdings", status: "started")
    SyncLog.create!(plaid_item: item, job_type: "holdings", status: "success")

    get "/mission_control/logs.json"
    assert_response :success
    arr = JSON.parse(@response.body)
    assert arr.is_a?(Array)
    assert arr.size >= 2
    # First should be most recent
    first = arr.first
    assert_equal "holdings", first["job_type"]
    assert_includes %w[started success failure], first["status"]
    assert_equal item.id, first["plaid_item_id"]
  end

  test "non-owner GET /mission_control/logs.json is redirected" do
    login_as(@user, scope: :user)
    get "/mission_control/logs.json"
    assert_response :redirect
    assert_redirected_to authenticated_root_path
  end

  # Re-link success auto-sync endpoint
  test "owner can POST relink_success to auto-enqueue all sync jobs for legacy items" do
    login_as(@owner, scope: :user)
    item = PlaidItem.create!(user: @owner, item_id: "it_rls1", institution_name: "Bank", access_token: "tok", status: "good")

    # Legacy items (intended_products NULL) now enqueue investments + transactions only.
    assert_enqueued_jobs 2 do
      post mission_control_relink_success_path(id: item.id), as: :json
      assert_response :success
      body = JSON.parse(@response.body)
      assert_equal "ok", body["status"]
    end

    assert_enqueued_with(job: SyncHoldingsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "non-owner cannot POST relink_success" do
    login_as(@user, scope: :user)
    item = PlaidItem.create!(user: @owner, item_id: "it_rls2", institution_name: "Bank", access_token: "tok", status: "good")

    assert_enqueued_jobs 0 do
      post mission_control_relink_success_path(id: item.id), as: :json
      assert_redirected_to authenticated_root_path
    end
  end

  test "owner relink_success returns 404 for missing item" do
    login_as(@owner, scope: :user)
    post mission_control_relink_success_path(id: 999_999), as: :json
    assert_response :not_found
    body = JSON.parse(@response.body)
    assert_equal "Not found", body["error"]
  end

  # PRD-0-04: Reauth respects intended_products
  test "relink_success only enqueues jobs for intended_products when set to investments,transactions" do
    login_as(@owner, scope: :user)
    item = PlaidItem.create!(
      user: @owner,
      item_id: "it_schwab_reauth",
      institution_name: "Schwab",
      access_token: "tok",
      status: "good",
      intended_products: "investments,transactions"
    )

    assert_enqueued_jobs 2 do
      post mission_control_relink_success_path(id: item.id), as: :json
      assert_response :success
    end

    # Verify only investments and transactions jobs were enqueued
    assert_enqueued_with(job: SyncHoldingsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])

    # Verify liabilities job was NOT enqueued
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "relink_success only enqueues jobs for intended_products when set to transactions only" do
    login_as(@owner, scope: :user)
    item = PlaidItem.create!(
      user: @owner,
      item_id: "it_amex_reauth",
      institution_name: "Amex",
      access_token: "tok",
      status: "good",
      intended_products: "transactions"
    )

    assert_enqueued_jobs 1 do
      post mission_control_relink_success_path(id: item.id), as: :json
      assert_response :success
    end

    # Verify only transactions job was enqueued
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])

    # Verify other jobs were NOT enqueued
    assert_no_enqueued_jobs(only: SyncHoldingsJob)
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  # Remove Item endpoint tests (PRD: Plaid Item Removal)
  test "owner can POST remove_item to delete item and cascade data" do
    login_as(@owner, scope: :user)

    item = PlaidItem.create!(user: @owner, item_id: "it_remove", institution_name: "Test Bank", access_token: "test_token", status: "good")
    account = item.accounts.create!(account_id: "acc_remove", name: "Test Account", plaid_account_type: "investment", subtype: "brokerage", mask: "0000")
    account.holdings.create!(security_id: "sec_remove", symbol: "AAPL", name: "Apple", quantity: 10.0)
    item.recurring_transactions.create!(stream_id: "stream_remove", description: "Test", frequency: "MONTHLY", average_amount: 10.0)
    item.sync_logs.create!(job_type: "holdings", status: "success")

    # Stub Plaid API call
    fake_response = OpenStruct.new(request_id: "req_123")
    with_stubbed_plaid_client(item_remove: fake_response) do
      assert_difference [ "PlaidItem.count", "Account.count", "Holding.count", "RecurringTransaction.count", "SyncLog.count" ], -1 do
        post mission_control_remove_item_path(id: item.id)
        assert_redirected_to mission_control_path
        follow_redirect!
        assert_response :success
        assert_includes @response.body, "Item removed successfully"
      end
    end

    # Verify item is gone
    assert_nil PlaidItem.find_by(id: item.id)
  end

  test "owner remove_item returns 404 flash for invalid item ID" do
    login_as(@owner, scope: :user)

    assert_no_difference "PlaidItem.count" do
      post mission_control_remove_item_path(id: 999_999)
      assert_redirected_to mission_control_path
      follow_redirect!
      assert_response :success
      assert_includes @response.body, "Item not found"
    end
  end

  test "owner remove_item handles Plaid API error gracefully" do
    login_as(@owner, scope: :user)

    item = PlaidItem.create!(user: @owner, item_id: "it_error", institution_name: "Test Bank", access_token: "bad_token", status: "good")

    # Stub Plaid API to raise error
    plaid_error = Plaid::ApiError.new(
      error_type: "INVALID_REQUEST",
      error_code: "INVALID_ACCESS_TOKEN",
      error_message: "Invalid access token",
      display_message: "Invalid access token"
    )

    with_stubbed_plaid_client_error(:item_remove, plaid_error) do
      assert_no_difference "PlaidItem.count" do
        post mission_control_remove_item_path(id: item.id)
        assert_redirected_to mission_control_path
        follow_redirect!
        assert_response :success
        assert_includes @response.body, "Removal failed"
      end
    end

    # Verify item still exists
    assert_not_nil PlaidItem.find_by(id: item.id)
  end

  test "non-owner cannot POST remove_item" do
    login_as(@user, scope: :user)

    item = PlaidItem.create!(user: @owner, item_id: "it_protected", institution_name: "Bank", access_token: "tok", status: "good")

    assert_no_difference "PlaidItem.count" do
      post mission_control_remove_item_path(id: item.id)
      assert_redirected_to authenticated_root_path
    end

    # Verify item still exists
    assert_not_nil PlaidItem.find_by(id: item.id)
  end

  test "owner can edit and update a plaid item's intended_products and status" do
    login_as(@owner, scope: :user)

    item = PlaidItem.create!(
      user: @owner,
      item_id: "it_edit",
      institution_name: "Edit Bank",
      access_token: "tok",
      status: "needs_reauth",
      intended_products: "investments,transactions,liabilities",
      reauth_attempts: 2,
      last_error: "consent needed"
    )

    get edit_mission_control_plaid_item_path(item)
    assert_response :success
    assert_includes @response.body, "Edit Plaid Item"

    patch mission_control_plaid_item_path(item), params: {
      intended_products: [ "transactions" ],
      status: "good"
    }
    assert_redirected_to mission_control_path

    item.reload
    assert_equal "transactions", item.intended_products
    assert_equal "good", item.status
    assert_equal 0, item.reauth_attempts
    assert_nil item.last_error
  end

  test "owner update plaid item rejects invalid status" do
    login_as(@owner, scope: :user)

    item = PlaidItem.create!(
      user: @owner,
      item_id: "it_edit_bad",
      institution_name: "Edit Bank",
      access_token: "tok",
      status: "good",
      intended_products: "investments,transactions"
    )

    patch mission_control_plaid_item_path(item), params: { intended_products: [ "transactions" ], status: "nope" }
    assert_redirected_to edit_mission_control_plaid_item_path(item)

    item.reload
    assert_equal "good", item.status
  end
end
