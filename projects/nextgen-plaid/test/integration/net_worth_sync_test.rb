# frozen_string_literal: true

require "test_helper"

class NetWorthSyncTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.cache.store.clear
  end

  test "POST /net_worth/sync enqueues FinancialSnapshotJob and returns turbo stream pending state" do
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user

      assert_enqueued_with(job: FinancialSnapshotJob, args: [ user.id ]) do
        post "/net_worth/sync", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      end

      assert_response :success
      assert_includes @response.media_type, "turbo-stream"
      assert_includes @response.body, "target=\"sync-status\""
      assert_includes @response.body, "Syncing"
    end
  end

  test "POST /net_worth/sync is rate limited to 1/min per user" do
    user = users(:one)

    ClimateControl.modify ENABLE_NEW_LAYOUT: "true" do
      sign_in user

      post "/net_worth/sync", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success

      post "/net_worth/sync", headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response 429
      assert_includes @response.media_type, "turbo-stream"
      assert_includes @response.body, "Rate limited"
      assert_includes @response.body, "Refresh limit reached"
    end
  end
end
