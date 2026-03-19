# frozen_string_literal: true

require "application_system_test_case"

class PortfolioHoldingsGridCapybaraTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(email: "grid-smoke@example.com", password: "password")

    plaid_item = PlaidItem.create!(
      user: @user,
      access_token: "test-access-token",
      item_id: "item_1",
      institution_name: "Test Bank",
      institution_id: "ins_1",
      status: :good
    )

    investment = Account.create!(
      plaid_item: plaid_item,
      account_id: "acc_1",
      name: "Brokerage",
      mask: "1111",
      plaid_account_type: "investment"
    )

    # Create same security in 2 accounts to exercise multi-account expansion
    investment2 = Account.create!(
      plaid_item: plaid_item,
      account_id: "acc_2",
      name: "IRA",
      mask: "2222",
      plaid_account_type: "investment"
    )

    Holding.create!(
      account: investment,
      security_id: "sec_eq",
      ticker_symbol: "EQ1",
      name: "Equity One",
      asset_class: "equity",
      quantity: 1,
      market_value: 100,
      cost_basis: 80,
      unrealized_gl: 20
    )

    Holding.create!(
      account: investment2,
      security_id: "sec_eq",
      ticker_symbol: "EQ1",
      name: "Equity One",
      asset_class: "equity",
      quantity: 2,
      market_value: 250,
      cost_basis: 200,
      unrealized_gl: 50
    )

    SecurityEnrichment.create!(
      security_id: "sec_eq",
      symbol: "EQ1",
      source: "fmp",
      status: "success",
      sector: "Technology",
      enriched_at: Time.current - 2.days,
      data: {}
    )

    Holding.create!(
      account: investment,
      security_id: "sec_mf",
      ticker_symbol: "MF1",
      name: "Mutual Fund One",
      asset_class: "mutual_fund",
      quantity: 1,
      market_value: 200,
      cost_basis: 180,
      unrealized_gl: 20
    )

    Holding.create!(
      account: investment,
      security_id: "sec_bd",
      ticker_symbol: "BD1",
      name: "Bond One",
      asset_class: "bond",
      quantity: 1,
      market_value: 300,
      cost_basis: 290,
      unrealized_gl: 10
    )

    login_as @user, scope: :user
  end

  test "per-page selector updates the footer" do
    visit portfolio_holdings_path
    assert_text "Holdings"

    select "25", from: "per_page"
    click_button "Apply"

    assert_text "Showing 1–3 of 3 holdings"
  end

  test "asset tabs filter rows" do
    visit portfolio_holdings_path
    assert_text "EQ1"
    assert_text "MF1"
    assert_text "BD1"

    click_link "Stocks & ETFs"
    assert_text "EQ1"
    assert_no_text "MF1"
    assert_no_text "BD1"

    click_link "Mutual Funds"
    assert_text "MF1"
    assert_no_text "EQ1"
    assert_no_text "BD1"

    click_link "Bonds, CDs & MMFs"
    assert_text "BD1"
    assert_no_text "EQ1"
    assert_no_text "MF1"
  end

  test "search filters rows and enrichment badge renders" do
    visit portfolio_holdings_path

    fill_in "search_term", with: "tech"
    click_button "Search"

    assert_text "EQ1"
    assert_no_text "MF1"

    # Dot should exist with amber-ish class (2 days old)
    assert_selector "span[aria-label^='Enriched:']"
    assert_selector ".bg-amber-500"
  end

  test "sort toggles by value" do
    visit portfolio_holdings_path

    # Default is value desc; EQ1 is held in 2 accounts (aggregated value 350) so it should be first
    assert_equal "EQ1", first("[data-testid='parent-symbol']").text

    click_link "Value"
    # Ascending: MF1 (200) should be first
    assert_equal "MF1", first("[data-testid='parent-symbol']").text

    click_link "Value"
    assert_equal "EQ1", first("[data-testid='parent-symbol']").text
  end

  test "multi-account row expands to show per-account breakdown" do
    visit portfolio_holdings_path

    assert_selector "details[data-testid='holding-collapse']", count: 1

    # Child table should be hidden until expanded
    assert_no_selector "table[aria-label='Per-account holdings']", visible: true

    find("details[data-testid='holding-collapse'] summary").click

    assert_selector "table[aria-label='Per-account holdings']"
    assert_text "Brokerage • 1111"
    assert_text "IRA • 2222"
  end

  test "navigate to security detail and back preserves holdings url state" do
    visit portfolio_holdings_path(asset_tab: "stocks_etfs", search_term: "eq1")

    # Parent symbol is a link to the security detail page
    click_link "EQ1"
    assert_text "Transactions"
    assert_text "Per-Account Breakdown"

    click_link "← Back to Holdings"
    assert_current_path(/\/portfolio\/holdings\?/) # should include query params from return_to
    assert_text "EQ1"
  end
end
