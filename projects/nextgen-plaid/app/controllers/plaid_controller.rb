class PlaidController < ApplicationController
  before_action :authenticate_user!

  def link_token
    begin
      # Quick test: filter products based on product_set parameter
      product_set = params[:product_set]
      products = case product_set
      when "investments"
        [ "investments" ]
      when "schwab"
        [ "investments", "transactions" ]
      when "amex"
        [ "transactions", "liabilities" ]
      when "chase"
        [ "investments", "transactions", "liabilities" ]
      when "liabilities"
        [ "liabilities" ]
      when "transactions"
        [ "transactions" ]
      else
        [ "investments", "transactions" ]
      end

      # Build request params
      request_params = {
        user: { client_user_id: current_user.id.to_s },
        client_name: "NextGen Wealth Advisor",
        products: products,
        country_codes: [ "US" ],
        language: "en",
        redirect_uri: ENV["PLAID_REDIRECT_URI"]
      }

      # Only add transactions config if transactions product is included
      if products.include?("transactions")
        request_params[:transactions] = Plaid::LinkTokenTransactions.new(days_requested: 730)
      end

      request = Plaid::LinkTokenCreateRequest.new(**request_params)

      client = Rails.application.config.x.plaid_client
      response = client.link_token_create(request)

      Rails.logger.info "Link token created for user_id: #{current_user.id} with products: #{products.inspect} | request_id: #{response.request_id} | link_token: #{response.link_token[0..20]}..."
      render json: { link_token: response.link_token }
    rescue Plaid::ApiError => e
      Rails.logger.error "Plaid Link Token Error: #{e.message} | Body: #{e.response_body} | Products: #{products.inspect}"
      render json: { error: e.message, code: "PLAID_ERROR", details: e.response_body }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Internal Link Token Error: #{e.message}"
      render json: { error: "Internal Server Error" }, status: :internal_server_error
    end
  end

  def exchange
    public_token = params[:public_token]
    product_set = params[:product_set]

    # Epic-0 PRD-0030: used to show a one-time toast when the first successful link happens.
    first_success = current_user.plaid_items.successfully_linked.none?

    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token)
    client = Rails.application.config.x.plaid_client
    exchange_response = client.item_public_token_exchange(exchange_request)

    # Map product_set to intended_products string
    intended_products = case product_set
    when "schwab"
      "investments,transactions"
    when "amex"
      "transactions,liabilities"
    when "chase"
      "investments,transactions,liabilities"
    else
      "investments,transactions" # default (liabilities requires explicit intent)
    end

    item = PlaidItem.create!(
      user: current_user,
      item_id: exchange_response.item_id,
      institution_name: params[:institution_name] || "Sandbox Institution",
      access_token: exchange_response.access_token,   # ← CORRECT
      status: "good",
      intended_products: intended_products
    )

    # PRD 5.1 + PRD-0-04: Sync only intended products on connect
    intended = intended_products.split(",")
    SyncHoldingsJob.perform_later(item.id) if intended.include?("investments")
    SyncTransactionsJob.perform_later(item.id) if intended.include?("transactions")
    SyncLiabilitiesJob.perform_later(item.id) if intended.include?("liabilities")

    render json: { status: "connected", first_success: first_success }
  end

  def sync_logs
    @sync_logs = SyncLog.includes(:plaid_item).order(created_at: :desc).limit(100)
  end
end
