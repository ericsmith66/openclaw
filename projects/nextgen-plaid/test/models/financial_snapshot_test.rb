require "test_helper"

class FinancialSnapshotTest < ActiveSupport::TestCase
  setup do
    @tz = ActiveSupport::TimeZone[APP_TIMEZONE]
    @user = User.first || User.create!(email: "test@example.com", password: "password")
    @other_user = User.where.not(id: @user.id).first || User.create!(email: "other@example.com", password: "password")
  end

  test "creates with required fields and defaults status to pending" do
    snapshot = FinancialSnapshot.create!(user: @user, snapshot_at: Date.current, data: {}, schema_version: 1)
    assert_equal "pending", snapshot.status
    assert snapshot.data.is_a?(Hash)
  end

  test "validates schema_version presence" do
    snapshot = FinancialSnapshot.new(user: @user, snapshot_at: Date.current, data: {}, schema_version: nil)
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:schema_version], "can't be blank"
  end

  test "validates schema_version inclusion" do
    snapshot = FinancialSnapshot.new(user: @user, snapshot_at: Date.current, data: {}, schema_version: 3)
    assert_not snapshot.valid?
    assert snapshot.errors[:schema_version].present?
  end

  test "normalizes snapshot_at to beginning of day in CST" do
    time = @tz.parse("2026-01-24 23:00:00")
    snapshot = FinancialSnapshot.create!(user: @user, snapshot_at: time, data: {}, schema_version: 1)
    assert_equal @tz.parse("2026-01-24 00:00:00"), snapshot.snapshot_at
  end

  test "enforces unique snapshot per user per CST day" do
    time1 = @tz.parse("2026-01-24 01:00:00")
    time2 = @tz.parse("2026-01-24 23:00:00")

    FinancialSnapshot.create!(user: @user, snapshot_at: time1, data: {}, schema_version: 1)
    assert_raises(ActiveRecord::RecordNotUnique) do
      FinancialSnapshot.create!(user: @user, snapshot_at: time2, data: {}, schema_version: 1)
    end
  end

  test "allows same CST day for different users" do
    time = @tz.parse("2026-01-24 12:00:00")

    FinancialSnapshot.create!(user: @user, snapshot_at: time, data: {}, schema_version: 1)
    assert_nothing_raised do
      FinancialSnapshot.create!(user: @other_user, snapshot_at: time, data: {}, schema_version: 1)
    end
  end

  test "latest_for_user returns most recent complete snapshot" do
    older = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-20 10:00:00"), data: {}, schema_version: 1, status: :complete)
    newer = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-21 10:00:00"), data: {}, schema_version: 1, status: :complete)
    FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-22 10:00:00"), data: {}, schema_version: 1, status: :pending)

    assert_equal newer.id, FinancialSnapshot.latest_for_user(@user).id
    assert_not_equal older.id, FinancialSnapshot.latest_for_user(@user).id
  end

  test "latest_for_user returns stale snapshot when it is the most recent exportable snapshot" do
    older_complete = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-20 10:00:00"), data: {}, schema_version: 1, status: :complete)
    newer_stale = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-21 10:00:00"), data: {}, schema_version: 1, status: :stale)

    assert_equal newer_stale.id, FinancialSnapshot.latest_for_user(@user).id
    assert_not_equal older_complete.id, FinancialSnapshot.latest_for_user(@user).id
  end

  test "recent_for_user returns last N days (by cutoff)" do
    FinancialSnapshot.delete_all

    FinancialSnapshot.create!(user: @user, snapshot_at: @tz.now.beginning_of_day - 10.days, data: {}, schema_version: 1, status: :complete)
    included = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.now.beginning_of_day - 3.days, data: {}, schema_version: 1, status: :complete)

    results = FinancialSnapshot.recent_for_user(@user, 7)
    assert_includes results.map(&:id), included.id
  end

  test "rollback_to_date marks snapshots after date as rolled_back" do
    FinancialSnapshot.delete_all

    keep = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-10 12:00:00"), data: {}, schema_version: 1, status: :complete)
    to_rollback = FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-11 12:00:00"), data: {}, schema_version: 1, status: :complete)

    FinancialSnapshot.rollback_to_date(@user, Date.new(2026, 1, 10))

    assert_equal "complete", keep.reload.status
    assert_equal "rolled_back", to_rollback.reload.status
  end

  test "application-level scoping via user association" do
    FinancialSnapshot.delete_all

    FinancialSnapshot.create!(user: @user, snapshot_at: @tz.parse("2026-01-24 12:00:00"), data: {}, schema_version: 1)
    assert_equal 0, @other_user.financial_snapshots.count
  end
end
