# app/services/plaid_transaction_sync_service.rb
class PlaidTransactionSyncService
  def initialize(plaid_item)
    @item = plaid_item
    @client = Rails.application.config.x.plaid_client
  end

  def sync
    cursor = @item.sync_cursor
    added = []
    modified = []
    removed = []
    has_more = true

    while has_more
      request = Plaid::TransactionsSyncRequest.new(
        access_token: @item.access_token,
        cursor: cursor,
        count: 500
      )

      response = @client.transactions_sync(request)

      added += response.added
      modified += response.modified
      removed += response.removed

      # Log API call
      api_call = PlaidApiCall.log_call(
        product: "transactions",
        endpoint: "/transactions/sync",
        request_id: response.request_id,
        count: response.added.size + response.modified.size + response.removed.size
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

      has_more = response.has_more
      cursor = response.next_cursor
    end

    enriched_transaction_ids = []

    ActiveRecord::Base.transaction do
      process_removed(removed)
      enriched_transaction_ids.concat(process_added(added))
      enriched_transaction_ids.concat(process_modified(modified))

      @item.update!(sync_cursor: cursor)
    end

    {
      added: added.size,
      modified: modified.size,
      removed: removed.size,
      enriched_transaction_ids: enriched_transaction_ids.uniq
    }
  rescue Plaid::ApiError => e
    handle_plaid_error(e)
  end

  private

  def process_added(transactions)
    ids = []
    transactions.each do |txn|
      account = @item.accounts.find_by(account_id: txn.account_id)
      next unless account

      # PRD 0020: Use create_or_find_by to handle race conditions during concurrent syncs.
      # We include source: "plaid" to satisfy the DB default and avoid 'manual' validation triggers.
      transaction = account.transactions.create_or_find_by!(transaction_id: txn.transaction_id, source: "plaid")
      update_transaction_fields(transaction, txn)
      upsert_enrichment_fields(transaction, txn)
      transaction.save!

      # STI reclassification based on account type (PRD-7-01)
      if transaction.type == "RegularTransaction"
        if account.investment?
          transaction.update_column(:type, "InvestmentTransaction")
        elsif account.credit?
          transaction.update_column(:type, "CreditTransaction")
        end
      end

      ids << transaction.id
    end

    ids
  end

  def process_modified(transactions)
    process_added(transactions)
  end

  def process_removed(removed_metadata)
    removed_ids = removed_metadata.map(&:transaction_id)
    # PRD 0020: Soft-deletion
    @item.transactions.where(transaction_id: removed_ids).update_all(deleted_at: Time.current)
  end

  def update_transaction_fields(transaction, txn)
    transaction.assign_attributes(
      name: txn.name,
      amount: txn.amount,
      date: txn.date,
      category: txn.category&.join(", "),
      merchant_name: txn.merchant_name,
      pending: txn.pending,
      payment_channel: txn.payment_channel,
      iso_currency_code: txn.iso_currency_code,
      source: "plaid",
      deleted_at: nil # Restore if it was previously soft-deleted
    )
  end

  def upsert_enrichment_fields(transaction, plaid_txn)
    return unless ENV.fetch("PLAID_ENRICH_ENABLED", "false").to_s == "true"

    counterparties = plaid_txn.respond_to?(:counterparties) ? plaid_txn.counterparties : nil
    counterparty = counterparties&.first
    logo_url = counterparty&.respond_to?(:logo_url) ? counterparty.logo_url : counterparty&.dig(:logo_url)
    website = counterparty&.respond_to?(:website) ? counterparty.website : counterparty&.dig(:website)

    pfc = plaid_txn.respond_to?(:personal_finance_category) ? plaid_txn.personal_finance_category : nil

    raw_confidence = if pfc&.respond_to?(:confidence_level)
      pfc.confidence_level
    elsif counterparty&.respond_to?(:confidence_level)
      counterparty.confidence_level
    end

    transaction.logo_url = logo_url if logo_url.present?
    transaction.website = website if website.present?
    transaction.merchant_name = plaid_txn.merchant_name || plaid_txn.name

    confidence_normalized = case raw_confidence.to_s.upcase
    when "VERY_HIGH" then "very_high"
    when "HIGH" then "high"
    when "MEDIUM" then "medium"
    when "LOW" then "low"
    else
      "unknown"
    end
    transaction.personal_finance_category_confidence_level = confidence_normalized

    # Category mapping is best-effort: do not block persisting logo/website/confidence.
    begin
      primary = pfc&.respond_to?(:primary) ? pfc.primary : pfc&.dig(:primary)
      detailed = pfc&.respond_to?(:detailed) ? pfc.detailed : pfc&.dig(:detailed)

      category_string = nil
      if primary.present? || detailed.present?
        category_string = detailed.present? ? "#{primary} → #{detailed}" : primary
      end

      if primary.present? || detailed.present?
        pfc_record = PersonalFinanceCategory.find_or_create_by!(primary: primary, detailed: detailed)
        transaction.personal_finance_category_id = pfc_record.id
      end

      transaction.personal_finance_category_label = category_string if category_string.present?
    rescue => e
      Rails.logger.error "PlaidTransactionSyncService: failed to upsert category fields for transaction #{transaction.id}: #{e.class.name}: #{e.message}"
    end
  rescue => e
    Rails.logger.error "PlaidTransactionSyncService: failed to upsert enrichment fields for transaction #{transaction.id}: #{e.message}"
  end

  def handle_plaid_error(e)
    error_response = JSON.parse(e.response_body) rescue {}
    error_code = error_response["error_code"]

    Rails.logger.error "Plaid Sync Error for Item #{@item.id}: #{e.message}"

    if %w[ITEM_LOGIN_REQUIRED INVALID_ACCESS_TOKEN].include?(error_code)
      @item.update!(status: :needs_reauth, last_error: e.message)
    end

    raise e
  end
end
