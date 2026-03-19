class BackfillSecurityEnrichmentColumns < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  class SecurityEnrichment < ApplicationRecord
    self.table_name = "security_enrichments"
  end

  def up
    SecurityEnrichment.reset_column_information

    SecurityEnrichment.in_batches(of: 500) do |relation|
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

    set_if_nil(updates, row, :sector, data["sector"] || profile["sector"])
    set_if_nil(updates, row, :industry, data["industry"] || profile["industry"])
    set_if_nil(updates, row, :company_name, data["company_name"] || profile["companyName"] || profile["company_name"] || profile["name"])
    set_if_nil(updates, row, :website, data["website"] || profile["website"])
    set_if_nil(updates, row, :description, data["description"] || profile["description"])
    set_if_nil(updates, row, :image_url, data["image_url"] || profile["image"] || profile["image_url"] || profile["logo"])

    set_if_nil_decimal(updates, row, :price, data["price"] || quote["price"])
    set_if_nil_bigint(updates, row, :market_cap, data["market_cap"] || profile["mktCap"] || profile["marketCap"] || profile["market_cap"])

    set_if_nil_decimal(updates, row, :change_percentage, data["change_percentage"] || quote["changesPercentage"] || quote["changePercentage"])
    set_if_nil_decimal(updates, row, :dividend_yield, data["dividend_yield"] || ratios["dividendYield"] || ratios["dividend_yield"])
    set_if_nil_decimal(updates, row, :pe_ratio, data["pe_ratio"] || ratios["priceEarningsRatio"] || ratios["peRatio"] || ratios["pe_ratio"])
    set_if_nil_decimal(updates, row, :price_to_book, data["price_to_book"] || ratios["priceToBookRatio"] || ratios["priceToBook"] || ratios["price_to_book"])
    set_if_nil_decimal(updates, row, :net_profit_margin, data["net_profit_margin"] || ratios["netProfitMargin"] || ratios["net_profit_margin"])
    set_if_nil_decimal(updates, row, :dividend_per_share, data["dividend_per_share"] || ratios["dividendPerShare"] || ratios["dividend_per_share"])
    set_if_nil_decimal(updates, row, :free_cash_flow_yield, data["free_cash_flow_yield"] || ratios["freeCashFlowYield"] || ratios["free_cash_flow_yield"])

    set_if_nil_decimal(updates, row, :roe, data["roe"] || ratios["returnOnEquity"] || ratios["roe"])
    set_if_nil_decimal(updates, row, :roa, data["roa"] || ratios["returnOnAssets"] || ratios["roa"])
    set_if_nil_decimal(updates, row, :beta, data["beta"] || key_metrics["beta"] || quote["beta"])
    set_if_nil_decimal(updates, row, :roic, data["roic"] || ratios["returnOnCapitalEmployed"] || ratios["roic"])

    set_if_nil_decimal(updates, row, :current_ratio, data["current_ratio"] || ratios["currentRatio"] || ratios["current_ratio"])
    set_if_nil_decimal(updates, row, :debt_to_equity, data["debt_to_equity"] || ratios["debtEquityRatio"] || ratios["debt_to_equity"])

    updates
  end

  def set_if_nil(updates, row, column, value)
    return if value.nil?
    return if row.public_send(column).present?

    updates[column] = value
  end

  def set_if_nil_decimal(updates, row, column, value)
    return if value.nil?
    return if row.public_send(column).present?

    decimal = safe_decimal(value)
    updates[column] = decimal if decimal
  end

  def set_if_nil_bigint(updates, row, column, value)
    return if value.nil?
    return if row.public_send(column).present?

    int = safe_integer(value)
    updates[column] = int if int
  end

  def safe_decimal(value)
    BigDecimal(value.to_s)
  rescue ArgumentError
    nil
  end

  def safe_integer(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end
end
