require "test_helper"

class ApiSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "api_owner@example.com", password: "password123", roles: "parent")
    @other_user = User.create!(email: "api_other@example.com", password: "password123", roles: "parent")
    @admin = User.create!(email: "api_admin@example.com", password: "password123", roles: "admin")

    @owner_snapshot = FinancialSnapshot.create!(
      user: @owner,
      snapshot_at: Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 00:00:00") },
      schema_version: 1,
      status: :complete,
      data: {
        "total_net_worth" => 123_456,
        "account_numbers" => [ "<REDACTED>" ]
      }
    )

    @other_snapshot = FinancialSnapshot.create!(
      user: @other_user,
      snapshot_at: Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 00:00:00") },
      schema_version: 1,
      status: :complete,
      data: { "total_net_worth" => 999 }
    )
  end

  test "download returns JSON for owner" do
    sign_in @owner, scope: :user
    get download_api_snapshot_url(@owner_snapshot)

    assert_response :success
    assert_includes response.media_type, "application/json"
    assert_includes response.headers["Content-Disposition"], "networth-snapshot-2026-01-24.json"

    json = JSON.parse(response.body)
    assert_equal 123_456, json["total_net_worth"]
    assert_equal [ "<REDACTED>" ], json["account_numbers"]
  end

  test "download JSON (summary) omits holdings_export but includes transactions_summary" do
    @owner_snapshot.update!(data: { "total_net_worth" => 123_456 })

    sign_in @owner, scope: :user
    get download_api_snapshot_url(@owner_snapshot)

    assert_response :success
    json = JSON.parse(response.body)

    assert_equal false, json.key?("holdings_export")
    assert json.key?("transactions_summary")
  end

  test "download JSON (full) includes holdings_export (backfilled when missing)" do
    @owner_snapshot.update!(data: { "total_net_worth" => 123_456 })

    sign_in @owner, scope: :user
    get download_api_snapshot_url(@owner_snapshot, include_holdings_export: "true")

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("holdings_export")
  end

  test "download returns holdings CSV for owner" do
    @owner_snapshot.update!(
      data: @owner_snapshot.data.merge(
        "holdings_export" => [
          {
            "account" => "Brokerage",
            "symbol" => "AAPL",
            "name" => "Apple Inc",
            "value" => 1000,
            "pct_portfolio" => 0.25
          }
        ]
      )
    )

    sign_in @owner, scope: :user
    get download_api_snapshot_url(@owner_snapshot, format: :csv)

    assert_response :success
    assert_includes response.media_type, "text/csv"
    assert_includes response.headers["Content-Disposition"], "networth-snapshot-2026-01-24.csv"
    assert_includes response.body, "Account,Symbol,Name,Value,Percentage"
    assert_includes response.body, "Brokerage,AAPL,Apple Inc,1000.0,25.0"
  end

  test "download denies access to non-owner" do
    sign_in @owner, scope: :user
    get download_api_snapshot_url(@other_snapshot)

    assert_response :forbidden
  end

  test "rag_context returns sanitized JSON for admin" do
    ENV["RAG_SALT"] = "test_salt"

    sign_in @admin, scope: :user
    get rag_context_api_snapshot_url(@owner_snapshot)

    assert_response :success
    json = JSON.parse(response.body)

    assert json.key?("user_id_hash")
    assert json.key?("exported_at")
    assert json.key?("disclaimer")
    assert_equal false, json.key?("account_numbers")
  ensure
    ENV.delete("RAG_SALT")
  end

  test "rag_context includes SHA256 hash of user_id" do
    ENV["RAG_SALT"] = "test_salt"

    sign_in @admin, scope: :user
    get rag_context_api_snapshot_url(@owner_snapshot)

    json = JSON.parse(response.body)
    expected = Digest::SHA256.hexdigest("#{@owner.id}#{ENV["RAG_SALT"]}")
    assert_equal expected, json["user_id_hash"]
  ensure
    ENV.delete("RAG_SALT")
  end

  test "rag_context denies access to non-admin without api key" do
    sign_in @owner, scope: :user
    get rag_context_api_snapshot_url(@owner_snapshot)

    assert_response :forbidden
  end

  test "rag_context allows access with api key when configured" do
    ENV["RAG_SALT"] = "test_salt"
    ENV["RAG_EXPORT_API_KEY"] = "secret_key"

    get rag_context_api_snapshot_url(@owner_snapshot), headers: { "X-Api-Key" => "secret_key" }

    assert_response :success
  ensure
    ENV.delete("RAG_SALT")
    ENV.delete("RAG_EXPORT_API_KEY")
  end
end
