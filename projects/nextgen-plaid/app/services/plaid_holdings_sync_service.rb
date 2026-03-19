# app/services/plaid_holdings_sync_service.rb
class PlaidHoldingsSyncService
  def initialize(plaid_item)
    @item = plaid_item
    @client = Rails.application.config.x.plaid_client
  end

  def sync
    token = @item.access_token
    return unless token.present?

    response = @client.investments_holdings_get(
      Plaid::InvestmentsHoldingsGetRequest.new(access_token: token)
    )

    updated_holding_ids = []

    ActiveRecord::Base.transaction do
      sync_accounts(response.accounts)
      updated_holding_ids = sync_holdings(response.holdings, response.securities)

      # Mark last successful holdings sync timestamp (PRD 5.5)
      @item.update!(holdings_synced_at: Time.current, last_holdings_sync_at: Time.current)
    end

    # PRD-1-09: enqueue enrichment for updated equity holdings after sync
    equity_ids = Holding.where(id: updated_holding_ids, type: "equity").pluck(:id)
    HoldingsEnrichmentJob.perform_later(holding_ids: equity_ids) if equity_ids.any?

    # PRD 8.2: Log API cost for holdings
    api_call = PlaidApiCall.log_call(
      product: "investments_holdings",
      endpoint: "/investments/holdings/get",
      request_id: response.request_id,
      count: response.holdings.size
    )

    PlaidApiResponse.create!(
      plaid_api_call: api_call,
      plaid_item: @item,
      product: api_call.product,
      endpoint: api_call.endpoint,
      request_id: api_call.request_id,
      response_json: PlaidApiResponse.serialize_payload(response),
      called_at: api_call.called_at
    )

    { accounts: response.accounts.size, holdings: response.holdings.size }
  rescue Plaid::ApiError => e
    handle_plaid_error(e)
  end

  private

  def sync_accounts(plaid_accounts)
    plaid_accounts.each do |plaid_account|
      persistent_id = plaid_account.persistent_account_id rescue nil

      account = find_account(plaid_account, persistent_id)

      if account
        account.update!(
          account_id: plaid_account.account_id,
          persistent_account_id: persistent_id,
          name: plaid_account.name,
          mask: plaid_account.mask,
          plaid_account_type: plaid_account.type,
          subtype: plaid_account.subtype,
          current_balance: plaid_account.balances.current,
          iso_currency_code: plaid_account.balances.iso_currency_code
        )
      else
        account = @item.accounts.create_or_find_by!(account_id: plaid_account.account_id) do |acc|
          acc.persistent_account_id = persistent_id
          acc.name = plaid_account.name
          acc.mask = plaid_account.mask
          acc.plaid_account_type = plaid_account.type
          acc.subtype = plaid_account.subtype
          acc.current_balance = plaid_account.balances.current
          acc.iso_currency_code = plaid_account.balances.iso_currency_code
        end
        # Ensure it's updated if it was found instead of created
        account.update!(
          persistent_account_id: persistent_id,
          name: plaid_account.name,
          mask: plaid_account.mask,
          plaid_account_type: plaid_account.type,
          subtype: plaid_account.subtype,
          current_balance: plaid_account.balances.current,
          iso_currency_code: plaid_account.balances.iso_currency_code
        )
      end
    end
  end

  def find_account(plaid_account, persistent_id)
    account = nil
    if persistent_id.present?
      account = @item.accounts.find_by(persistent_account_id: persistent_id)
    end

    account ||= @item.accounts.find_by(account_id: plaid_account.account_id)

    account ||= @item.accounts.find_by(
      name: plaid_account.name,
      mask: plaid_account.mask,
      plaid_account_type: plaid_account.type
    )

    account
  end

  def sync_holdings(plaid_holdings, plaid_securities)
    updated_ids = []

    plaid_holdings.each do |holding|
      account = @item.accounts.find_by(account_id: holding.account_id)
      next unless account

      security = plaid_securities.find { |s| s.security_id == holding.security_id }
      next unless security

      pos = account.holdings.find_or_create_by!(security_id: security.security_id, source: :plaid)

      pos.assign_attributes(
        symbol: security.ticker_symbol,
        ticker_symbol: security.ticker_symbol,
        name: security.name,
        quantity: holding.quantity,
        cost_basis: holding.cost_basis,
        market_value: holding.institution_value || holding.market_value,
        unrealized_gl: derive_unrealized_gl(holding),
        vested_value: holding.vested_value,
        institution_price: holding.institution_price,
        institution_price_as_of: holding.institution_price_as_of,
        close_price: (security.respond_to?(:close_price) ? security.close_price : nil),
        close_price_as_of: (security.respond_to?(:close_price_as_of) ? security.close_price_as_of : nil),
        market_identifier_code: (security.respond_to?(:market_identifier_code) ? security.market_identifier_code : nil),
        iso_currency_code: (security.respond_to?(:iso_currency_code) ? security.iso_currency_code : nil),
        proxy_security_id: (security.respond_to?(:proxy_security_id) ? security.proxy_security_id : nil),
        is_cash_equivalent: (security.respond_to?(:is_cash_equivalent) ? (security.is_cash_equivalent || false) : false),
        isin: security.isin,
        cusip: security.cusip,
        sector: security.sector || "Unknown",
        industry: security.industry,
        type: security.type,
        subtype: security.respond_to?(:subtype) ? security.subtype : nil,
        source: "plaid"
      )

      compute_high_cost_flag(pos)
      pos.save!
      updated_ids << pos.id

      sync_fixed_income(pos, security)
      sync_option_contract(pos, security)
    end

    updated_ids
  end

  def compute_high_cost_flag(pos)
    if pos.cost_basis.present? && pos.cost_basis > 0 && pos.market_value.present?
      gain_ratio = (pos.market_value - pos.cost_basis) / pos.cost_basis
      pos.high_cost_flag = (gain_ratio > 0.5)
    else
      pos.high_cost_flag = false
    end
  end

  def derive_unrealized_gl(plaid_holding)
    # Prefer Plaid's explicit field when present.
    if plaid_holding.respond_to?(:unrealized_gain_loss) && !plaid_holding.unrealized_gain_loss.nil?
      return plaid_holding.unrealized_gain_loss
    end

    # Fallback: compute from institution/market value and cost basis.
    return nil unless plaid_holding.respond_to?(:cost_basis)

    cb = plaid_holding.cost_basis
    return nil if cb.nil?

    value = if plaid_holding.respond_to?(:institution_value) && !plaid_holding.institution_value.nil?
      plaid_holding.institution_value
    elsif plaid_holding.respond_to?(:market_value) && !plaid_holding.market_value.nil?
      plaid_holding.market_value
    end
    return nil if value.nil?

    value.to_f - cb.to_f
  end

  def sync_fixed_income(pos, security)
    if security.respond_to?(:fixed_income) && security.fixed_income.present?
      fi = security.fixed_income

      fixed_income_record = pos.fixed_income || pos.create_fixed_income!(yield_type: "unknown") rescue pos.fixed_income
      fixed_income_record.assign_attributes(
        yield_percentage: fi.yield_percentage,
        yield_type: fi.yield_type || "unknown",
        maturity_date: fi.maturity_date,
        issue_date: fi.issue_date,
        face_value: fi.face_value
      )

      fixed_income_record.income_risk_flag = (fi.yield_percentage.present? && fi.yield_percentage.to_f < 2.0)
      fixed_income_record.save!

      if fi.yield_type&.downcase&.include?("tax-exempt")
        Rails.logger.info "PlaidHoldingsSyncService: Tax-exempt bond detected: #{security.security_id}"
      end
    end
  end

  def sync_option_contract(pos, security)
    if security.respond_to?(:option_contract) && security.option_contract.present?
      oc = security.option_contract

      option_record = pos.option_contract || pos.create_option_contract! rescue pos.option_contract
      option_record.assign_attributes(
        contract_type: oc.contract_type,
        expiration_date: oc.expiration_date,
        strike_price: oc.strike_price,
        underlying_ticker: oc.underlying_ticker
      )

      option_record.save!
    end
  end

  def handle_plaid_error(e)
    error_response = JSON.parse(e.response_body) rescue {}
    error_code = error_response["error_code"]

    Rails.logger.error "Plaid Holdings Sync Error for Item #{@item.id}: #{e.message}"

    if %w[ITEM_LOGIN_REQUIRED INVALID_ACCESS_TOKEN].include?(error_code)
      @item.update!(status: :needs_reauth, last_error: e.message)
    end

    raise e
  end
end
