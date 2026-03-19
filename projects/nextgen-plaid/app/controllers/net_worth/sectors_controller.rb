module NetWorth
  class SectorsController < ApplicationController
    before_action :authenticate_user!

    def show
      snapshot = FinancialSnapshot.latest_for_user(current_user)
      snapshot_data = if snapshot.present?
        snapshot.data.to_h
      else
        provider = Reporting::DataProvider.new(current_user)
        normalize_provider_hash(provider.build_snapshot_hash)
      end

      @snapshot_data = snapshot_data
    end

    private

    def normalize_provider_hash(hash)
      h = hash.to_h
      core = h["core"] || h[:core] || {}

      {
        "total_net_worth" => (core["total_net_worth"] || core[:total_net_worth]).to_f,
        "delta_day" => (core["delta_day"] || core[:delta_day]).to_f,
        "delta_30d" => (core["delta_30d"] || core[:delta_30d]).to_f,
        "asset_allocation" => h["asset_allocation"] || h[:asset_allocation] || {},
        "sector_weights" => h["sector_weights"] || h[:sector_weights],
        "monthly_transaction_summary" => h["monthly_transaction_summary"] || h[:monthly_transaction_summary] || {},
        "historical_net_worth" => h["historical_trends"] || h[:historical_trends] || [],
        "as_of" => (h["generated_at"] || h[:generated_at] || Time.current).to_date.to_s,
        "disclaimer" => "Educational simulation only – not financial advice",
        "data_quality" => { "warnings" => [] }
      }
    end
  end
end
