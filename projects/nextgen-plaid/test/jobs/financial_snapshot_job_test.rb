require "test_helper"

class FinancialSnapshotJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = User.create!(email: "snapshot_user@example.com", password: "Password123")
    @plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "item_snapshot_1",
      institution_name: "Test Bank",
      status: PlaidItem.statuses[:good]
    )

    @depository = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_dep",
      mask: "0000",
      plaid_account_type: "depository",
      current_balance: 25_000
    )

    @credit = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_cc",
      mask: "1111",
      plaid_account_type: "credit",
      current_balance: 75_000
    )

    Holding.create!(
      account: @depository,
      security_id: "sec_1",
      market_value: 100_000,
      asset_class: "equity",
      sector: "Technology",
      symbol: "AAA",
      name: "AAA Corp"
    )

    Holding.create!(
      account: @depository,
      security_id: "sec_2",
      market_value: 50_000,
      asset_class: "cash",
      sector: nil,
      symbol: "CASH",
      name: "Cash"
    )
  end

  test "creates snapshot with correct core aggregates and disclaimer" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")

      assert_difference -> { FinancialSnapshot.count }, 1 do
        FinancialSnapshotJob.perform_now(@user)
      end

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      assert_equal "complete", snapshot.status

      # holdings: 100k + 50k = 150k
      # cash accounts: 25k
      # credit accounts: 75k
      # net worth = 150k + 25k - 75k = 100k
      assert_in_delta 100_000, snapshot.data["total_net_worth"], 0.0001
      assert_equal "2026-01-24", snapshot.data["as_of"]
      assert_equal FinancialSnapshotJob::DISCLAIMER, snapshot.data["disclaimer"]
      assert_equal [], snapshot.data.dig("data_quality", "warnings")

      allocation = snapshot.data["asset_allocation"]
      assert allocation.is_a?(Hash)
      assert allocation.key?("equity")
      assert allocation.key?("cash")
      assert_in_delta 1.0, allocation.values.sum, 0.0001

      sector_weights = snapshot.data["sector_weights"]
      assert sector_weights.is_a?(Hash)
      assert_equal [ "technology" ], sector_weights.keys
      assert_in_delta 1.0, sector_weights.values.sum, 0.0001

      top_holdings = snapshot.data["top_holdings"]
      assert top_holdings.is_a?(Array)
      assert_equal 2, top_holdings.size
      assert_equal "AAA", top_holdings.first["ticker"]
      assert_equal "AAA Corp", top_holdings.first["name"]
      assert_in_delta 100_000, top_holdings.first["value"], 0.0001
      assert_in_delta 100_000.0 / 150_000.0, top_holdings.first["pct_portfolio"], 0.0001

      monthly = snapshot.data["monthly_transaction_summary"]
      assert monthly.is_a?(Hash)
      assert_equal 0.0, monthly["income"].to_f
      assert_equal 0.0, monthly["expenses"].to_f
      assert_equal [], monthly["top_categories"]

      historical = snapshot.data["historical_net_worth"]
      assert_equal [], historical
    end
  end

  test "includes historical net worth trends" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")

      5.times do |i|
        FinancialSnapshot.create!(
          user: @user,
          snapshot_at: (i + 1).days.ago,
          schema_version: 1,
          status: :complete,
          data: { "total_net_worth" => 500_000 + ((4 - i) * 10_000) }
        )
      end

      FinancialSnapshotJob.perform_now(@user)

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      history = snapshot.data["historical_net_worth"]
      assert_equal 5, history.size
      assert_operator history.first["date"], :<, history.last["date"]
      assert_equal 540_000, history.last["value"]
    end
  end

  test "computes delta_day using nearest snapshot at or before target" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")

      previous_time = Time.use_zone(APP_TIMEZONE) { 2.days.ago.beginning_of_day }
      FinancialSnapshot.create!(
        user: @user,
        snapshot_at: previous_time,
        schema_version: 1,
        status: :complete,
        data: { "total_net_worth" => 90_000 }
      )

      FinancialSnapshotJob.perform_now(@user)

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      assert_in_delta 10_000, snapshot.data["delta_day"], 0.0001
    end
  end

  test "preserves delta sign correctly" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")

      previous_time = Time.use_zone(APP_TIMEZONE) { 1.day.ago.beginning_of_day }
      FinancialSnapshot.create!(
        user: @user,
        snapshot_at: previous_time,
        schema_version: 1,
        status: :complete,
        data: { "total_net_worth" => 120_000 }
      )

      FinancialSnapshotJob.perform_now(@user)

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      assert_in_delta(-20_000, snapshot.data["delta_day"], 0.0001)
    end
  end

  test "marks snapshot stale when sync is older than 36 hours" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(
        plaid_item: @plaid_item,
        job_type: "holdings",
        status: "success",
        created_at: 40.hours.ago,
        updated_at: 40.hours.ago
      )

      FinancialSnapshotJob.perform_now(@user)

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      assert_equal "stale", snapshot.status
      assert_includes snapshot.data.dig("data_quality", "warnings"), "Data may be stale; last sync is older than 36 hours"
    end
  end

  test "marks snapshot empty when net worth is zero" do
    empty_user = User.create!(email: "snapshot_empty@example.com", password: "Password123")
    PlaidItem.create!(
      user: empty_user,
      item_id: "item_snapshot_empty",
      institution_name: "Empty Bank",
      status: PlaidItem.statuses[:good]
    )

    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      FinancialSnapshotJob.perform_now(empty_user)

      snapshot = empty_user.financial_snapshots.order(snapshot_at: :desc).first
      assert_equal "empty", snapshot.status
      assert_includes snapshot.data.dig("data_quality", "warnings"), "No holdings/accounts detected; net worth computed as 0"

      assert_equal({}, snapshot.data["asset_allocation"])
      assert_nil snapshot.data["sector_weights"]
    end
  end

  test "buckets nil asset_class into other" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")

      Holding.create!(
        account: @depository,
        security_id: "sec_other",
        market_value: 25_000,
        asset_class: nil,
        sector: nil,
        symbol: "OTH",
        name: "Other"
      )

      FinancialSnapshotJob.perform_now(@user)

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      allocation = snapshot.data["asset_allocation"]
      assert allocation.key?("other")
      assert_in_delta 1.0, allocation.values.sum, 0.0001
    end
  end

  test "buckets nil sector into unknown for sector_weights" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      SyncLog.create!(plaid_item: @plaid_item, job_type: "holdings", status: "success")

      Holding.create!(
        account: @depository,
        security_id: "sec_unknown_sector",
        market_value: 25_000,
        asset_class: "equity",
        sector: nil,
        symbol: "UNK",
        name: "Unknown Sector Equity"
      )

      FinancialSnapshotJob.perform_now(@user)

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      sector_weights = snapshot.data["sector_weights"]
      assert sector_weights.key?("technology")
      assert sector_weights.key?("unknown")
      assert_in_delta 1.0, sector_weights.values.sum, 0.0001
    end
  end

  test "does not overwrite complete snapshot unless forced" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      snapshot_at = Time.use_zone(APP_TIMEZONE) { Time.zone.now.beginning_of_day }
      FinancialSnapshot.create!(
        user: @user,
        snapshot_at: snapshot_at,
        schema_version: 1,
        status: :complete,
        data: { "total_net_worth" => 1, "as_of" => "2026-01-24", "disclaimer" => FinancialSnapshotJob::DISCLAIMER }
      )

      assert_no_difference -> { FinancialSnapshot.count } do
        FinancialSnapshotJob.perform_now(@user)
      end

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      assert_equal 1, snapshot.data["total_net_worth"]
    end
  end

  test "stores error snapshot data and re-raises on failure" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      fake_provider = Class.new do
        def core_aggregates
          raise StandardError, "Test error"
        end

        def sync_freshness
          { stale: false, last_sync_at: Time.current }
        end
      end.new

      assert_raises(StandardError) do
        Reporting::DataProvider.stub(:new, fake_provider) do
          FinancialSnapshotJob.perform_now(@user)
        end
      end

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      assert_equal "error", snapshot.status
      assert_includes snapshot.data["error"], "Test error"
    end
  end

  test "adds warning when asset allocation sum is off" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      fake_provider = Class.new do
        def core_aggregates
          { total_net_worth: 100_000, delta_day: 0, delta_30d: 0 }
        end

        def asset_allocation_breakdown
          { "equity" => 0.5 }
        end

        def sector_weights
          nil
        end

        def top_holdings
          []
        end

        def monthly_transaction_summary
          { "income" => 0, "expenses" => 0, "top_categories" => [] }
        end

        def historical_trends(_days)
          []
        end

        def sync_freshness
          { stale: false, last_sync_at: Time.current }
        end
      end.new

      Reporting::DataProvider.stub(:new, fake_provider) do
        FinancialSnapshotJob.perform_now(@user)
      end

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      warnings = snapshot.data.dig("data_quality", "warnings")
      assert warnings.any? { |w| w.include?("Asset allocation percentages do not sum") }
    end
  end

  test "adds warning when net worth sanity check fails" do
    travel_to Time.use_zone(APP_TIMEZONE) { Time.zone.parse("2026-01-24 10:00:00") } do
      fake_provider = Class.new do
        def core_aggregates
          { total_net_worth: -20_000_000, delta_day: 0, delta_30d: 0 }
        end

        def asset_allocation_breakdown
          {}
        end

        def sector_weights
          nil
        end

        def top_holdings
          []
        end

        def monthly_transaction_summary
          { "income" => 0, "expenses" => 0, "top_categories" => [] }
        end

        def historical_trends(_days)
          []
        end

        def sync_freshness
          { stale: false, last_sync_at: Time.current }
        end
      end.new

      Reporting::DataProvider.stub(:new, fake_provider) do
        FinancialSnapshotJob.perform_now(@user)
      end

      snapshot = @user.financial_snapshots.order(snapshot_at: :desc).first
      warnings = snapshot.data.dig("data_quality", "warnings")
      assert warnings.any? { |w| w.include?("Net worth sanity check failed") }
    end
  end
end
