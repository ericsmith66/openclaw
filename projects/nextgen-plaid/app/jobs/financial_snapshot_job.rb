class FinancialSnapshotJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotUnique
  # NOTE: We intentionally avoid `retry_on` here because existing job tests
  # (and error-reporting semantics) expect exceptions to be re-raised.

  DISCLAIMER = "Educational simulation only – not financial advice"

  def perform(user_or_id = nil, force: false)
    if user_or_id.nil?
      User.find_each { |user| snapshot_for_user!(user, force: force) }
      return
    end

    user = resolve_user(user_or_id)
    snapshot = snapshot_for_user!(user, force: force)

    user.broadcast_replace_to(
      "net_worth:sync_status:#{user.id}",
      target: "sync-status",
      partial: "net_worth/sync_status",
      locals: { status: :complete, snapshot: snapshot }
    )
  end

  private

  def snapshot_for_user!(user, force:)
    now_cst = Time.use_zone(APP_TIMEZONE) { Time.zone.now }
    snapshot_at = now_cst.beginning_of_day
    as_of = now_cst.to_date

    snapshot = FinancialSnapshot.find_or_initialize_by(user: user, snapshot_at: snapshot_at)
    return if snapshot.complete? && !force

    provider = Reporting::DataProvider.new(user)
    core = provider.core_aggregates
    asset_allocation = provider.asset_allocation_breakdown
    sector_weights = provider.sector_weights
    top_holdings = provider.top_holdings
    holdings_export = provider.respond_to?(:holdings_export_rows) ? provider.holdings_export_rows : []
    monthly_transaction_summary = provider.monthly_transaction_summary
    historical_net_worth = provider.historical_trends(30)

    warnings = []
    status = :complete

    if core[:total_net_worth].to_f == 0.0
      status = :empty
      warnings << "No holdings/accounts detected; net worth computed as 0"
    end

    if provider.sync_freshness[:stale]
      status = :stale unless status == :empty
      warnings << "Data may be stale; last sync is older than 36 hours" if status == :stale
    end

    validate_snapshot_data!(
      warnings: warnings,
      asset_allocation: asset_allocation,
      total_net_worth: core[:total_net_worth].to_f
    )

    snapshot.schema_version = 1
    snapshot.status = status
    snapshot.data = {
      "total_net_worth" => core[:total_net_worth].to_f,
      "delta_day" => core[:delta_day].to_f,
      "delta_30d" => core[:delta_30d].to_f,
      "asset_allocation" => asset_allocation,
      "sector_weights" => sector_weights,
      "top_holdings" => top_holdings,
      "holdings_export" => holdings_export,
      "monthly_transaction_summary" => monthly_transaction_summary,
      "transactions_summary" => {
        "month" => {
          "income" => monthly_transaction_summary.to_h["income"].to_f,
          "expenses" => monthly_transaction_summary.to_h["expenses"].to_f,
          "net" => (monthly_transaction_summary.to_h["income"].to_f - monthly_transaction_summary.to_h["expenses"].to_f)
        }
      },
      "historical_net_worth" => historical_net_worth,
      "as_of" => as_of.to_s,
      "disclaimer" => DISCLAIMER,
      "data_quality" => {
        "warnings" => warnings
      }
    }

    snapshot.save!
    snapshot
  rescue ActiveRecord::RecordNotUnique
    raise
  rescue StandardError => e
    begin
      error_snapshot = FinancialSnapshot.find_or_initialize_by(user: user, snapshot_at: snapshot_at)
      error_snapshot.schema_version ||= 1
      error_snapshot.status = :error
      error_snapshot.data = (error_snapshot.data || {}).merge(
        "error" => "#{e.class}: #{e.message}",
        "as_of" => as_of.to_s,
        "disclaimer" => DISCLAIMER
      )
      error_snapshot.save!

      user.broadcast_replace_to(
        "net_worth:sync_status:#{user.id}",
        target: "sync-status",
        partial: "net_worth/sync_status",
        locals: { status: :error, snapshot: error_snapshot, error_reason: "#{e.class}: #{e.message}" }
      )
    rescue StandardError
      # best-effort only
    end

    raise
  end

  def resolve_user(user_or_id)
    return user_or_id if user_or_id.is_a?(User)

    User.find(user_or_id)
  end

  def validate_snapshot_data!(warnings:, asset_allocation:, total_net_worth:)
    allocation = asset_allocation.to_h
    if allocation.present?
      sum = allocation.values.sum.to_f
      if (sum - 1.0).abs > 0.01
        warnings << "Asset allocation percentages do not sum to 1.0 (sum=#{sum.round(4)})"
      end
    end

    if total_net_worth.to_f < -10_000_000
      warnings << "Net worth sanity check failed (net_worth=#{total_net_worth.to_f})"
    end
  end
end
