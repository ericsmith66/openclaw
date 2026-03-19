class BackfillPeRatioFromRawResponse < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class SecurityEnrichment < ApplicationRecord
    self.table_name = "security_enrichments"
  end

  def up
    SecurityEnrichment.reset_column_information

    SecurityEnrichment.where(pe_ratio: nil).in_batches(of: 500) do |relation|
      relation.each do |row|
        pe = extract_pe_ratio(row)
        next if pe.nil?

        row.update_columns(pe_ratio: pe, updated_at: Time.current)
      end
    end
  end

  def down
    # no-op (data backfill is irreversible)
  end

  private

  def extract_pe_ratio(row)
    data = row.data || {}
    raw = data["raw_response"] || {}
    ratios = raw["ratios"]
    ratios_row = (ratios.is_a?(Array) ? ratios.first : ratios) || {}
    quote = raw["quote"]
    quote_row = (quote.is_a?(Array) ? quote.first : quote) || {}

    value =
      data["pe_ratio"] ||
        ratios_row["priceToEarningsRatio"] ||
        ratios_row["priceEarningsRatio"] ||
        ratios_row["peRatio"] ||
        ratios_row["pe"] ||
        quote_row["pe"] ||
        quote_row["peRatio"]

    safe_decimal(value)
  end

  def safe_decimal(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end
end
