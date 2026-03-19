class BackfillBetaAndDebtToEquityFromRawResponse < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class SecurityEnrichment < ApplicationRecord
    self.table_name = "security_enrichments"
  end

  def up
    SecurityEnrichment.reset_column_information

    SecurityEnrichment
      .where(beta: nil)
      .or(SecurityEnrichment.where(debt_to_equity: nil))
      .in_batches(of: 500) do |relation|
        relation.each do |row|
          updates = build_updates(row)
          next if updates.empty?

          row.update_columns(**updates, updated_at: Time.current)
        end
      end
  end

  def down
    # no-op (data backfill is irreversible)
  end

  private

  def build_updates(row)
    data = row.data || {}
    raw = data["raw_response"] || {}

    profile = (raw["profile"].is_a?(Array) ? raw["profile"].first : raw["profile"]) || {}
    quote = (raw["quote"].is_a?(Array) ? raw["quote"].first : raw["quote"]) || {}
    key_metrics = (raw["key_metrics"].is_a?(Array) ? raw["key_metrics"].first : raw["key_metrics"]) || {}
    ratios = (raw["ratios"].is_a?(Array) ? raw["ratios"].first : raw["ratios"]) || {}

    updates = {}

    if row.beta.nil?
      beta = profile["beta"] || key_metrics["beta"] || quote["beta"]
      beta_decimal = safe_decimal(beta)
      updates[:beta] = beta_decimal if beta_decimal
    end

    if row.debt_to_equity.nil?
      dte = ratios["debtToEquityRatio"] || ratios["debtEquityRatio"] || ratios["debt_to_equity"]
      dte_decimal = safe_decimal(dte)
      updates[:debt_to_equity] = dte_decimal if dte_decimal
    end

    updates
  end

  def safe_decimal(value)
    return nil if value.nil?

    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
