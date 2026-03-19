require "test_helper"

class SecurityEnrichmentTest < ActiveSupport::TestCase
  test "validates source inclusion (FMP-only)" do
    se = SecurityEnrichment.new(security_id: "sec_1", source: "nope", enriched_at: Time.current, status: "success")
    assert_not se.valid?
    assert_includes se.errors[:source], "is not included in the list"

    se.source = "fmp"
    assert se.valid?
  end

  test "validates security_id uniqueness" do
    SecurityEnrichment.create!(security_id: "sec_dup", source: "fmp", enriched_at: Time.current, status: "success", data: {})

    duplicate = SecurityEnrichment.new(security_id: "sec_dup", source: "fmp", enriched_at: Time.current, status: "success", data: {})
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:security_id], "has already been taken"
  end

  test "has gin index on data" do
    indexes = ActiveRecord::Base.connection.indexes(:security_enrichments)

    gin = indexes.find { |i| i.columns == [ "data" ] && i.using.to_s == "gin" }
    assert gin, "Expected GIN index on security_enrichments.data"
  end

  test "query shape uses @> operator" do
    sql = SecurityEnrichment.where("data @> ?", { asset_class: "equity" }.to_json).to_sql
    assert_includes sql, "data @>"
  end

  test "typed helper methods are aliases to typed columns" do
    enrichment = SecurityEnrichment.create!(
      security_id: "sec_helpers",
      source: "fmp",
      enriched_at: Time.current,
      status: "success",
      data: {},
      price: 246.7,
      market_cap: 1_234,
      roe: 0.25,
      roa: 0.12,
      beta: 1.2,
      roic: 0.15
    )

    assert_kind_of BigDecimal, enrichment.price_d
    assert_equal 246.7.to_d, enrichment.price_d

    assert_kind_of Integer, enrichment.market_cap_i
    assert_equal 1_234, enrichment.market_cap_i

    assert_kind_of BigDecimal, enrichment.roe_d
    assert_kind_of BigDecimal, enrichment.roa_d
    assert_kind_of BigDecimal, enrichment.beta_d
    assert_kind_of BigDecimal, enrichment.roic_d
  end

  test "has indexes for denormalized columns" do
    indexes = ActiveRecord::Base.connection.indexes(:security_enrichments)

    assert indexes.any? { |i| i.columns == [ "price" ] }, "Expected index on security_enrichments.price"
    assert indexes.any? { |i| i.columns == [ "market_cap" ] }, "Expected index on security_enrichments.market_cap"
    assert indexes.any? { |i| i.columns == [ "roe" ] }, "Expected index on security_enrichments.roe"
    assert indexes.any? { |i| i.columns == [ "pe_ratio" ] }, "Expected index on security_enrichments.pe_ratio"
    assert indexes.any? { |i| i.columns == [ "sector" ] }, "Expected index on security_enrichments.sector"
    assert indexes.any? { |i| i.columns == [ "industry" ] }, "Expected index on security_enrichments.industry"
    assert indexes.any? { |i| i.columns == [ "status" ] }, "Expected index on security_enrichments.status"

    assert indexes.any? { |i| i.columns == [ "sector", "status" ] }, "Expected compound index on [:sector, :status]"
    assert indexes.any? { |i| i.columns == [ "industry", "status" ] }, "Expected compound index on [:industry, :status]"

    company_name_gin = indexes.find { |i| i.columns == [ "company_name" ] && i.using.to_s == "gin" }
    assert company_name_gin, "Expected GIN index on security_enrichments.company_name"
  end
end
