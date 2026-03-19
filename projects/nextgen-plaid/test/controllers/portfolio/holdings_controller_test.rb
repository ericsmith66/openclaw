require "test_helper"

class Portfolio::HoldingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "portfolio-holdings@example.com", password: "password")
    sign_in @user, scope: :user
  end

  test "index renders successfully and assigns expected variables" do
    fake_result = Struct.new(:holdings, :summary, :total_count, keyword_init: true).new(
      holdings: [ { parent: { ticker_symbol: "AAPL", name: "Apple", market_value: 100, quantity: 1, cost_basis: 80, unrealized_gl: 20 }, children: [] } ],
      summary: { portfolio_value: 100, total_gl_dollars: 20, total_gl_pct: 25 },
      total_count: 1
    )

    provider = Struct.new(:call).new(fake_result)
    captured = {}

    HoldingsGridDataProvider.stub(:new, lambda { |_user, provider_params|
      captured[:params] = provider_params
      provider
    }) do
      get portfolio_holdings_path
    end

    assert_response :success
    assert_includes response.body, "Holdings"
    assert_includes response.body, "Showing 1–1 of 1 holdings"
    assert_includes response.body, "AAPL"

    assert_equal "all", captured.dig(:params, :asset_classes).presence || "all"
    assert_nil captured.dig(:params, :snapshot_id)
  end

  test "snapshot_id is passed through to provider when valid" do
    snap = @user.holdings_snapshots.create!(snapshot_data: { "x" => 1 })

    fake_result = Struct.new(:holdings, :summary, :total_count, keyword_init: true).new(
      holdings: [],
      summary: { portfolio_value: 0, total_gl_dollars: 0, total_gl_pct: 0 },
      total_count: 0
    )
    provider = Struct.new(:call).new(fake_result)
    captured = {}

    HoldingsGridDataProvider.stub(:new, lambda { |_user, provider_params|
      captured[:params] = provider_params
      provider
    }) do
      get portfolio_holdings_path(snapshot_id: snap.id)
    end

    assert_response :success
    assert_equal snap.id.to_s, captured.dig(:params, :snapshot_id).to_s
  end

  test "invalid snapshot_id redirects back to live" do
    get portfolio_holdings_path(snapshot_id: "999999999")

    assert_response :redirect
    assert_redirected_to portfolio_holdings_path
    assert_equal "Snapshot not found — showing live holdings instead.", flash[:alert]
  end

  test "asset tab maps to provider asset_classes" do
    fake_result = Struct.new(:holdings, :summary, :total_count, keyword_init: true).new(
      holdings: [ { parent: { ticker_symbol: "BND", name: "Bond", market_value: 100, quantity: 1, cost_basis: 90, unrealized_gl: 10, asset_class: "bond" }, children: [] } ],
      summary: { portfolio_value: 100, total_gl_dollars: 10, total_gl_pct: 11.1 },
      total_count: 1
    )

    provider = Struct.new(:call).new(fake_result)
    captured = {}

    HoldingsGridDataProvider.stub(:new, lambda { |_user, provider_params|
      captured[:params] = provider_params
      provider
    }) do
      get portfolio_holdings_path(asset_tab: "bonds_cds_mmfs")
    end

    assert_response :success
    assert_equal %w[bond fixed_income cd money_market], captured[:params][:asset_classes]
  end

  test "dismiss large grid warning sets session flag and redirects" do
    fake_result = Struct.new(:holdings, :summary, :total_count, keyword_init: true).new(
      holdings: [ { parent: { ticker_symbol: "AAPL", name: "Apple", market_value: 100, quantity: 1, cost_basis: 80, unrealized_gl: 20 }, children: [] } ],
      summary: { portfolio_value: 100, total_gl_dollars: 20, total_gl_pct: 25 },
      total_count: 500
    )

    provider = Struct.new(:call).new(fake_result)

    HoldingsGridDataProvider.stub(:new, ->(*_args) { provider }) do
      get portfolio_holdings_path(per_page: "all", dismiss_large_grid_warning: "true")
    end

    assert_equal true, session[:dismissed_large_grid_warning]
    assert_response :redirect
  end

  test "query signature change resets page to 1 and clears warning dismissal" do
    # Seed prior session state
    get portfolio_holdings_path
    session[:dismissed_large_grid_warning] = true
    session[:holdings_grid_query_signature] = "old"

    get portfolio_holdings_path(page: 3, per_page: 50, sort: "market_value")
    assert_response :redirect
    assert_equal false, session[:dismissed_large_grid_warning]
  end
end
