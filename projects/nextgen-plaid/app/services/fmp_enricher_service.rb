class FmpEnricherService
  # FMP legacy `/api/v3/...` endpoints were sunset for non-legacy users (403).
  # Use the new stable base.
  BASE_URL = "https://financialmodelingprep.com/stable".freeze

  class Error < StandardError; end

  def initialize(
    api_key: Rails.application.credentials.dig(:fmp, :api_key) || ENV["FMP_API_KEY"],
    client: HttpJsonClient.new
  )
    @api_key = api_key
    @client = client
  end

  def enrich(symbol)
    raise Error, "Missing FMP API key" if @api_key.blank?
    raise Error, "Missing symbol" if symbol.blank?

    profile = get("/profile", symbol: symbol)
    quote = get("/quote", symbol: symbol)
    key_metrics = get("/key-metrics", symbol: symbol)
    ratios = get("/ratios", symbol: symbol)

    extracted = extract(profile: profile, quote: quote, key_metrics: key_metrics, ratios: ratios)

    extracted.merge(
      "raw_response" => {
        "profile" => profile,
        "quote" => quote,
        "key_metrics" => key_metrics,
        "ratios" => ratios
      }
    )
  end

  private

  def normalize_percentage(value)
    return nil if value.nil?

    if value.is_a?(String)
      cleaned = value.strip
      cleaned = cleaned.delete("()%")
      cleaned = cleaned.tr("+", "")
      return nil if cleaned.blank?

      BigDecimal(cleaned)
    else
      BigDecimal(value.to_s)
    end
  rescue ArgumentError
    nil
  end

  def get(path, symbol:)
    @client.get_json(
      "#{BASE_URL}#{path}",
      query: { apikey: @api_key, symbol: symbol },
      retries: 3
    )
  end

  def extract(profile:, quote:, key_metrics:, ratios:)
    profile_row = profile.is_a?(Array) ? profile.first : profile
    quote_row = quote.is_a?(Array) ? quote.first : quote
    km_row = key_metrics.is_a?(Array) ? key_metrics.first : key_metrics
    ratios_row = ratios.is_a?(Array) ? ratios.first : ratios

    {
      "company_name" => profile_row&.[]("companyName") || profile_row&.[]("company_name") || profile_row&.[]("name"),
      "website" => profile_row&.[]("website"),
      "description" => profile_row&.[]("description"),
      "image_url" => profile_row&.[]("image") || profile_row&.[]("logo"),

      "sector" => profile_row&.[]("sector"),
      "industry" => profile_row&.[]("industry"),
      # FMP payloads vary by endpoint/plan and may use different key naming.
      "market_cap" => (
        profile_row&.[]("mktCap") ||
          profile_row&.[]("marketCap") ||
          profile_row&.[]("market_cap") ||
          quote_row&.[]("marketCap") ||
          quote_row&.[]("mktCap")
      ),
      "price" => quote_row&.[]("price"),

      "change_percentage" => normalize_percentage(quote_row&.[]("changesPercentage") || quote_row&.[]("changePercentage")),

      "beta" => km_row&.[]("beta") || quote_row&.[]("beta") || profile_row&.[]("beta"),
      "dividend_yield" => ratios_row&.[]("dividendYield"),
      "pe_ratio" => (
        ratios_row&.[]("priceToEarningsRatio") ||
          ratios_row&.[]("priceEarningsRatio") ||
          ratios_row&.[]("peRatio") ||
          ratios_row&.[]("pe") ||
          quote_row&.[]("pe") ||
          quote_row&.[]("peRatio")
      ),
      "price_to_book" => ratios_row&.[]("priceToBookRatio") || ratios_row&.[]("priceToBook"),
      "net_profit_margin" => ratios_row&.[]("netProfitMargin"),
      "dividend_per_share" => ratios_row&.[]("dividendPerShare"),
      "free_cash_flow_yield" => km_row&.[]("freeCashFlowYield") || ratios_row&.[]("freeCashFlowYield"),
      "roe" => ratios_row&.[]("returnOnEquity") || km_row&.[]("roe") || km_row&.[]("returnOnEquity"),
      "roa" => ratios_row&.[]("returnOnAssets") || km_row&.[]("roa") || km_row&.[]("returnOnAssets"),
      "roic" => ratios_row&.[]("returnOnCapitalEmployed") || km_row&.[]("roic") || km_row&.[]("returnOnCapitalEmployed"),
      "current_ratio" => ratios_row&.[]("currentRatio"),
      "debt_to_equity" => ratios_row&.[]("debtToEquityRatio") || ratios_row&.[]("debtEquityRatio") || ratios_row&.[]("debt_to_equity")
    }.compact
  end
end
