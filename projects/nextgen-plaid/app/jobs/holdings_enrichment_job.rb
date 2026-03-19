class HoldingsEnrichmentJob < ApplicationJob
  queue_as :default

  def perform(holding_ids: nil)
    holdings = Holding.where(source: :plaid).where(type: "equity")
    holding_ids = Array(holding_ids).compact
    holdings = holdings.where(id: holding_ids) if holding_ids.any?
    holdings = holdings.where.not(ticker_symbol: [ nil, "" ])

    holdings
      .where.not(security_id: [ nil, "" ])
      .select(:security_id)
      .distinct
      .pluck(:security_id)
      .each do |security_id|
        enrich_security!(security_id)
      end
  end

  private

  def enrich_security!(security_id)
    holding = Holding.where(security_id: security_id).where.not(ticker_symbol: [ nil, "" ]).first
    return unless holding

    symbol = normalize_symbol(holding.ticker_symbol)
    return if symbol.blank?

    now = Time.current
    notes = []

    fmp_data = nil
    begin
      fmp_data = FmpEnricherService.new.enrich(symbol)
    rescue => e
      notes << "fmp: #{safe_error_class_name(e)}: #{safe_error_message(e)}"
    end

    if fmp_data && !fmp_data.empty?
      upsert_enrichment!(security_id, symbol: symbol, enriched_at: now, status: "success", data: merge_target_upside(holding, fmp_data), notes: notes)

      # Apply derived asset_class to all holdings of this security that don't have it yet.
      Holding.where(security_id: security_id).find_each do |h|
        next if h.asset_class.present?
        HoldingsAssetClassDeriver.derive!(h, fmp_sector: fmp_data["sector"])
      end
      return
    end

    upsert_enrichment!(security_id, symbol: symbol, enriched_at: now, status: "error", data: {}, notes: notes)
  end

  def normalize_symbol(symbol)
    symbol.to_s.strip.upcase.tr(".", "-")
  end

  def safe_error_class_name(error)
    error.respond_to?(:class) ? error.class.name : "Error"
  end

  def safe_error_message(error)
    error.respond_to?(:message) ? error.message.to_s : error.to_s
  end

  def upsert_enrichment!(security_id, symbol:, enriched_at:, status:, data:, notes:)
    enrichment = SecurityEnrichment.find_or_initialize_by(security_id: security_id)

    column_attrs = data.present? ? security_enrichment_column_attributes_from_data(data) : {}
    enrichment.assign_attributes(
      source: "fmp",
      symbol: symbol,
      enriched_at: enriched_at,
      status: status,
      data: data,
      notes: notes
    )

    enrichment.assign_attributes(column_attrs) if column_attrs.any?

    enrichment.save!
  rescue ActiveRecord::RecordNotUnique
    # Another worker inserted the same `security_id` concurrently.
    SecurityEnrichment.find_by!(security_id: security_id).tap do |existing|
      existing.update!(
        source: "fmp",
        symbol: symbol,
        enriched_at: enriched_at,
        status: status,
        data: data,
        notes: notes
      )
    end
  end

  def security_enrichment_column_attributes_from_data(data)
    data = data.respond_to?(:with_indifferent_access) ? data.with_indifferent_access : data

    {
      price: data[:price],
      market_cap: data[:market_cap] || data[:marketCap] || data[:mktCap],
      sector: data[:sector],
      industry: data[:industry],
      company_name: data[:company_name] || data[:companyName] || data[:name],
      website: data[:website],
      description: data[:description],
      image_url: data[:image_url] || data[:image] || data[:logo],
      change_percentage: data[:change_percentage] || data[:changePercentage] || data[:changesPercentage],
      dividend_yield: data[:dividend_yield] || data[:dividendYield],
      pe_ratio: data[:pe_ratio] || data[:priceToEarningsRatio] || data[:priceEarningsRatio] || data[:peRatio] || data[:pe],
      price_to_book: data[:price_to_book] || data[:priceToBookRatio] || data[:priceToBook],
      net_profit_margin: data[:net_profit_margin] || data[:netProfitMargin],
      dividend_per_share: data[:dividend_per_share] || data[:dividendPerShare],
      free_cash_flow_yield: data[:free_cash_flow_yield] || data[:freeCashFlowYield],
      roe: data[:roe] || data[:returnOnEquity],
      roa: data[:roa] || data[:returnOnAssets],
      beta: data[:beta],
      roic: data[:roic] || data[:returnOnCapitalEmployed],
      current_ratio: data[:current_ratio] || data[:currentRatio],
      debt_to_equity: data[:debt_to_equity] || data[:debtToEquityRatio] || data[:debtEquityRatio]
    }.compact
  end

  def merge_target_upside(holding, data)
    pt_mean = data["price_target_mean"].to_d
    price = holding.institution_price.presence || holding.close_price
    return data if price.blank? || price.to_d.zero? || pt_mean.zero?

    upside = ((pt_mean - price.to_d) / price.to_d) * 100
    data.merge("target_upside_percent" => upside.round(2))
  end
end
