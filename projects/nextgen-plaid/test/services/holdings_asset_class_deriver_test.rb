# frozen_string_literal: true

require "test_helper"

class HoldingsAssetClassDeriverTest < ActiveSupport::TestCase
  FakeHolding = Struct.new(:type, :subtype, :name, :is_cash_equivalent, keyword_init: true) do
    attr_reader :updated_attrs

    def is_cash_equivalent?
      !!is_cash_equivalent
    end

    def update!(attrs)
      @updated_attrs = attrs
    end
  end

  test "derives etf" do
    holding = FakeHolding.new(type: "etf", subtype: nil, name: "VTI", is_cash_equivalent: false)
    HoldingsAssetClassDeriver.derive!(holding)
    assert_equal "etf", holding.updated_attrs[:asset_class]
  end

  test "derives mutual_fund" do
    holding = FakeHolding.new(type: "mutual fund", subtype: nil, name: "VTSAX", is_cash_equivalent: false)
    HoldingsAssetClassDeriver.derive!(holding)
    assert_equal "mutual_fund", holding.updated_attrs[:asset_class]
  end

  test "derives cd from subtype" do
    holding = FakeHolding.new(type: "fixed income", subtype: "CD", name: "1Y CD", is_cash_equivalent: false)
    HoldingsAssetClassDeriver.derive!(holding)
    assert_equal "cd", holding.updated_attrs[:asset_class]
  end

  test "derives money_market from subtype" do
    holding = FakeHolding.new(type: "cash", subtype: "Money Market", name: "Sweep", is_cash_equivalent: false)
    HoldingsAssetClassDeriver.derive!(holding)
    assert_equal "money_market", holding.updated_attrs[:asset_class]
  end

  test "derives fixed_income" do
    holding = FakeHolding.new(type: "fixed income", subtype: nil, name: "US Treasury Note", is_cash_equivalent: false)
    HoldingsAssetClassDeriver.derive!(holding)
    assert_equal "fixed_income", holding.updated_attrs[:asset_class]
  end
end
