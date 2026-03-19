require "test_helper"

class AdminSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(email: "admin_snapshots@example.com", password: "password123", roles: "admin")
    @regular = User.create!(email: "regular_snapshots@example.com", password: "password123", roles: "parent")

    @snapshot = FinancialSnapshot.create!(
      user: @regular,
      snapshot_at: Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 00:00:00") },
      schema_version: 1,
      status: :complete,
      data: { "total_net_worth" => 123_456, "data_quality" => { "warnings" => [] } }
    )
  end

  test "admin can view index" do
    sign_in @admin, scope: :user
    get admin_snapshots_url

    assert_response :success
    assert_includes response.body, "Financial Snapshots"
    assert_includes response.body, @regular.email
  end

  test "admin can view show" do
    sign_in @admin, scope: :user
    get admin_snapshot_url(@snapshot)

    assert_response :success
    assert_includes response.body, "&quot;total_net_worth&quot;"
    assert_includes response.body, "123456"
  end

  test "non-admin receives forbidden" do
    sign_in @regular, scope: :user
    get admin_snapshots_url

    assert_response :forbidden
  end
end
