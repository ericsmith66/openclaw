module NetWorth
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_new_layout!

    def show
      @snapshot = FinancialSnapshot.latest_for_user(current_user)
      @snapshot_data = resolved_snapshot_data
      @stale = @snapshot&.stale?
    end

    private

    def require_new_layout!
      enabled = if Rails.env.production?
        ENV["ENABLE_NEW_LAYOUT"] == "true"
      else
        ENV.fetch("ENABLE_NEW_LAYOUT", "true") == "true"
      end

      return if enabled

      head :not_found
    end

    def resolved_snapshot_data
      if @snapshot.present?
        @snapshot.data.to_h
      else
        provider = Reporting::DataProvider.new(current_user)
        normalize_provider_hash(provider.build_snapshot_hash)
      end
    end

    # `Reporting::DataProvider#build_snapshot_hash` is nested; the stored snapshot JSON is flat.
    # Normalize to the flat keys expected by the UI.
    def normalize_provider_hash(hash)
      h = hash.to_h
      core = h["core"] || h[:core] || {}

      historical = h["historical_totals"] || h[:historical_totals] || h["historical_trends"] || h[:historical_trends] || []

      {
        "total_net_worth" => (core["total_net_worth"] || core[:total_net_worth]).to_f,
        "delta_day" => (core["delta_day"] || core[:delta_day]).to_f,
        "delta_30d" => (core["delta_30d"] || core[:delta_30d]).to_f,
        "asset_allocation" => h["asset_allocation"] || h[:asset_allocation] || {},
        "sector_weights" => h["sector_weights"] || h[:sector_weights],
        "top_holdings" => h["top_holdings"] || h[:top_holdings] || [],
        "monthly_transaction_summary" => h["monthly_transaction_summary"] || h[:monthly_transaction_summary] || {},
        "transactions_summary" => build_transactions_summary(h["monthly_transaction_summary"] || h[:monthly_transaction_summary]),
        "historical_totals" => historical,
        "historical_net_worth" => historical,
        "as_of" => (h["generated_at"] || h[:generated_at] || Time.current).to_date.to_s,
        "disclaimer" => "Educational simulation only – not financial advice",
        "data_quality" => { "warnings" => [] }
      }
    end

    def build_transactions_summary(monthly)
      m = monthly.to_h
      income = (m["income"] || m[:income] || 0).to_f
      expenses = (m["expenses"] || m[:expenses] || 0).to_f

      {
        "month" => {
          "income" => income,
          "expenses" => expenses,
          "net" => (income - expenses)
        }
      }
    end
  end
end
