require "test_helper"

class HoldingsEnrichmentJobTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    @plaid_item = PlaidItem.first || PlaidItem.create!(
      user: @user,
      access_token: "test_access_token",
      item_id: "item_1",
      institution_name: "Test Bank",
      status: :good
    )

    @account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_1",
      name: "Test",
      mask: "0000",
      plaid_account_type: "investment",
      subtype: "brokerage",
      current_balance: 0,
      source: :plaid
    )

    @holding = Holding.create!(
      account: @account,
      security_id: SecureRandom.uuid,
      symbol: "AAPL",
      ticker_symbol: "AAPL",
      name: "Apple",
      quantity: 1,
      market_value: 100,
      institution_price: 100,
      close_price: 99,
      type: "equity",
      source: :plaid
    )
  end

  test "enriches with fmp and computes target_upside_percent" do
    fmp_payload = {
      "company_name" => "Apple Inc.",
      "website" => "https://apple.com",
      "description" => "A" * 200,
      "image_url" => "https://example.com/logo.png",
      "sector" => "Technology",
      "industry" => "Consumer Electronics",
      "price" => 100.0,
      "market_cap" => 123_000_000_000,
      "change_percentage" => 1.2345,
      "dividend_yield" => 0.005,
      "pe_ratio" => 25.12,
      "price_to_book" => 12.34,
      "net_profit_margin" => 0.215,
      "dividend_per_share" => 0.25,
      "free_cash_flow_yield" => 0.045,
      "roe" => 0.25,
      "roa" => 0.12,
      "beta" => 1.2,
      "roic" => 0.15,
      "current_ratio" => 1.5,
      "debt_to_equity" => 0.6,
      "price_target_mean" => "120",
      "analyst_consensus" => "Buy",
      "raw_response" => {}
    }

    fmp = Minitest::Mock.new
    fmp.expect(:enrich, fmp_payload, [ "AAPL" ])

    FmpEnricherService.stub(:new, fmp) do
      HoldingsEnrichmentJob.perform_now(holding_ids: [ @holding.id ])
    end

    fmp.verify

    enrichment = SecurityEnrichment.find_by(security_id: @holding.security_id)
    assert enrichment
    assert_equal "success", enrichment.status
    assert_in_delta 20.0, enrichment.data["target_upside_percent"].to_f, 0.01

    assert_equal "Technology", enrichment.sector
    assert_equal "Consumer Electronics", enrichment.industry
    assert_equal "Apple Inc.", enrichment.company_name
    assert_equal "https://apple.com", enrichment.website
    assert_equal "https://example.com/logo.png", enrichment.image_url
    assert_equal 200, enrichment.description.length

    assert_equal 123_000_000_000, enrichment.market_cap
    assert_in_delta 100.0, enrichment.price.to_d, 0.000001
    assert_in_delta 0.25, enrichment.roe.to_d, 0.000001
    assert_in_delta 1.2, enrichment.beta.to_d, 0.000001
  end

  test "writes an error enrichment when fmp fails" do
    fmp = Minitest::Mock.new
    fmp.expect(:enrich, nil) { raise StandardError, "boom" }

    FmpEnricherService.stub(:new, fmp) do
      HoldingsEnrichmentJob.perform_now(holding_ids: [ @holding.id ])
    end

    enrichment = SecurityEnrichment.find_by(security_id: @holding.security_id)
    assert enrichment
    assert_equal "error", enrichment.status
    assert_includes enrichment.notes.join("\n"), "fmp:"
  end

  test "populates top-level columns when payload keys are camelCase/symbolized" do
    fmp_payload = {
      marketCap: 456_000_000_000,
      returnOnEquity: 0.33,
      returnOnAssets: 0.11,
      beta: 1.05,
      price: 101.25,
      sector: "Technology",
      industry: "Consumer Electronics",
      companyName: "Apple Inc.",
      website: "https://apple.com",
      description: "A" * 50,
      image: "https://example.com/logo.png",
      changesPercentage: "(+1.23%)",
      raw_response: {}
    }

    fmp = Minitest::Mock.new
    fmp.expect(:enrich, fmp_payload, [ "AAPL" ])

    FmpEnricherService.stub(:new, fmp) do
      HoldingsEnrichmentJob.perform_now(holding_ids: [ @holding.id ])
    end

    fmp.verify

    enrichment = SecurityEnrichment.find_by(security_id: @holding.security_id)
    assert enrichment

    assert_equal 456_000_000_000, enrichment.market_cap
    assert_in_delta 0.33, enrichment.roe.to_d, 0.000001
    assert_in_delta 0.11, enrichment.roa.to_d, 0.000001
    assert_in_delta 1.05, enrichment.beta.to_d, 0.000001
  end

  test "re-enriches even when prior success is recent" do
    SecurityEnrichment.create!(
      security_id: @holding.security_id,
      source: "fmp",
      enriched_at: 1.day.ago,
      status: "success",
      data: { "analyst_consensus" => "Buy" }
    )

    fmp_payload = { "market_cap" => 1_000_000, "raw_response" => {} }

    fmp = Minitest::Mock.new
    fmp.expect(:enrich, fmp_payload, [ "AAPL" ])

    FmpEnricherService.stub(:new, fmp) do
      HoldingsEnrichmentJob.perform_now(holding_ids: [ @holding.id ])
    end

    fmp.verify

    enrichment = SecurityEnrichment.find_by(security_id: @holding.security_id)
    assert enrichment
    assert_equal 1_000_000, enrichment.market_cap
  end
end
