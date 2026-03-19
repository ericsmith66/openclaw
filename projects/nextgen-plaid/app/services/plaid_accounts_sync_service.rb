# app/services/plaid_accounts_sync_service.rb
class PlaidAccountsSyncService
  def initialize(plaid_item)
    @item = plaid_item
    @client = Rails.application.config.x.plaid_client
  end

  def sync
    token = @item.access_token
    return unless token.present?

    response = @client.accounts_get(
      Plaid::AccountsGetRequest.new(access_token: token)
    )

    now = Time.current

    ActiveRecord::Base.transaction do
      sync_accounts(response.accounts, now)
    end

    api_call = PlaidApiCall.log_call(
      product: "accounts",
      endpoint: "/accounts/get",
      request_id: response.request_id,
      count: response.accounts.size
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

    { accounts: response.accounts.size }
  rescue Plaid::ApiError => e
    handle_plaid_error(e)
  end

  private

  def sync_accounts(plaid_accounts, now)
    plaid_accounts.each do |plaid_account|
      persistent_id = plaid_account.persistent_account_id rescue nil
      account = find_account(plaid_account, persistent_id)

      attrs = {
        account_id: plaid_account.account_id,
        persistent_account_id: persistent_id,
        name: plaid_account.name,
        official_name: plaid_account.official_name,
        mask: plaid_account.mask,
        plaid_account_type: plaid_account.type,
        subtype: plaid_account.subtype,
        current_balance: plaid_account.balances.current,
        available_balance: plaid_account.balances.available,
        credit_limit: plaid_account.balances.limit,
        iso_currency_code: plaid_account.balances.iso_currency_code,
        holder_category: (plaid_account.respond_to?(:holder_category) ? plaid_account.holder_category : nil),
        balances_last_synced_at: now,
        balances_last_sync_status: "success",
        balances_last_sync_error: nil,
        source: "plaid"
      }

      if account
        account.update!(attrs)
      else
        account = @item.accounts.create_or_find_by!(account_id: plaid_account.account_id, source: "plaid") do |acc|
          acc.persistent_account_id = persistent_id
          acc.name = plaid_account.name
          acc.mask = plaid_account.mask
          acc.plaid_account_type = plaid_account.type
          acc.subtype = plaid_account.subtype
          acc.current_balance = plaid_account.balances.current
          acc.available_balance = plaid_account.balances.available
          acc.iso_currency_code = plaid_account.balances.iso_currency_code
          acc.balances_last_synced_at = now
          acc.balances_last_sync_status = "success"
          acc.balances_last_sync_error = nil
          acc.source = "plaid"
        end

        # Ensure it's updated if it was found instead of created
        account.update!(attrs)
      end

      log_missing_balances(account)

      upsert_daily_snapshot(account, now)
    end
  end

  def upsert_daily_snapshot(account, now)
    snapshot = AccountBalanceSnapshot.find_or_initialize_by(account: account, snapshot_date: Date.current)
    snapshot.assign_attributes(
      available_balance: account.available_balance,
      current_balance: account.current_balance,
      limit: account.credit_limit,
      iso_currency_code: account.iso_currency_code,
      synced_at: now,
      source: "plaid"
    )
    snapshot.save!
  rescue ActiveRecord::RecordNotUnique
    # Concurrent syncs can race; retry once.
    retry
  end

  def log_missing_balances(account)
    missing = []
    missing << "current_balance" if account.current_balance.nil?
    missing << "available_balance" if account.available_balance.nil?
    return if missing.empty?

    Rails.logger.warn(
      "PlaidAccountsSyncService: missing #{missing.join(', ')} for Account #{account.id} " \
      "(plaid_account_id=#{account.account_id}) on PlaidItem #{@item.id}"
    )
  end

  def find_account(plaid_account, persistent_id)
    account = nil
    if persistent_id.present?
      account = @item.accounts.find_by(persistent_account_id: persistent_id, source: "plaid")
    end

    account ||= @item.accounts.find_by(account_id: plaid_account.account_id, source: "plaid")

    account ||= @item.accounts.find_by(
      name: plaid_account.name,
      mask: plaid_account.mask,
      plaid_account_type: plaid_account.type,
      source: "plaid"
    )

    account
  end

  def handle_plaid_error(e)
    now = Time.current
    error_response = JSON.parse(e.response_body) rescue {}
    error_code = error_response["error_code"]

    Rails.logger.error "Plaid Accounts Sync Error for Item #{@item.id}: #{e.message}"

    @item.accounts.where(source: "plaid").update_all(
      balances_last_synced_at: now,
      balances_last_sync_status: "failure",
      balances_last_sync_error: e.message,
      updated_at: now
    )

    if %w[ITEM_LOGIN_REQUIRED INVALID_ACCESS_TOKEN].include?(error_code)
      @item.update!(status: :needs_reauth, last_error: e.message)
    end

    raise e
  end
end
