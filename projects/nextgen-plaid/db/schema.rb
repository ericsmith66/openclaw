# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_20_213406) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "account_balance_snapshots", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "apr_percentage", precision: 5, scale: 2
    t.decimal "available_balance", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.decimal "current_balance", precision: 15, scale: 2
    t.boolean "is_overdue", default: false
    t.string "iso_currency_code", default: "USD"
    t.decimal "limit", precision: 15, scale: 2
    t.decimal "min_payment_amount", precision: 15, scale: 2
    t.date "next_payment_due_date"
    t.date "snapshot_date", null: false
    t.string "source", default: "plaid"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index [ "account_id", "snapshot_date" ], name: "index_balance_snapshots_unique", unique: true
    t.index [ "account_id", "synced_at" ], name: "index_account_balance_snapshots_on_account_id_and_synced_at"
    t.index [ "account_id" ], name: "index_account_balance_snapshots_on_account_id"
    t.index [ "snapshot_date" ], name: "index_account_balance_snapshots_on_snapshot_date"
  end

  create_table "accounts", force: :cascade do |t|
    t.string "account_id", null: false
    t.decimal "apr_percentage", precision: 15, scale: 8
    t.string "asset_strategy", default: "unknown", null: false
    t.decimal "available_balance"
    t.text "balances_last_sync_error"
    t.string "balances_last_sync_status"
    t.datetime "balances_last_synced_at"
    t.datetime "created_at", null: false
    t.decimal "credit_limit", precision: 15, scale: 2
    t.decimal "current_balance"
    t.boolean "debt_risk_flag"
    t.string "holder_category"
    t.datetime "import_timestamp"
    t.boolean "include_in_net_worth", default: true, null: false
    t.boolean "is_overdue"
    t.string "iso_currency_code"
    t.jsonb "liability_details"
    t.string "mask"
    t.decimal "min_payment_amount", precision: 15, scale: 8
    t.string "name"
    t.date "next_payment_due_date"
    t.string "official_name"
    t.bigint "ownership_lookup_id"
    t.string "persistent_account_id"
    t.string "plaid_account_type"
    t.bigint "plaid_item_id", null: false
    t.integer "source", default: 0
    t.string "source_institution"
    t.string "subtype"
    t.string "trust_code"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index [ "include_in_net_worth" ], name: "index_accounts_on_include_in_net_worth"
    t.index [ "is_overdue" ], name: "index_accounts_on_is_overdue"
    t.index [ "ownership_lookup_id" ], name: "index_accounts_on_ownership_lookup_id"
    t.index [ "plaid_account_type" ], name: "index_accounts_on_plaid_account_type"
    t.index [ "plaid_item_id", "account_id" ], name: "index_accounts_on_item_and_account", unique: true
    t.index [ "plaid_item_id" ], name: "index_accounts_on_plaid_item_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index [ "blob_id" ], name: "index_active_storage_attachments_on_blob_id"
    t.index [ "record_type", "record_id", "name", "blob_id" ], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index [ "key" ], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index [ "blob_id", "variation_digest" ], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agent_logs", force: :cascade do |t|
    t.string "action"
    t.datetime "created_at", null: false
    t.text "details"
    t.string "persona"
    t.string "task_id"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "task_id", "persona", "action" ], name: "index_agent_logs_on_task_id_and_persona_and_action", unique: true
    t.index [ "task_id" ], name: "index_agent_logs_on_task_id"
    t.index [ "user_id" ], name: "index_agent_logs_on_user_id"
  end

  create_table "ai_workflow_runs", force: :cascade do |t|
    t.datetime "archived_at"
    t.string "correlation_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.jsonb "metadata", default: {}, null: false
    t.string "name"
    t.string "status", default: "draft", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "archived_at" ], name: "index_ai_workflow_runs_on_archived_at"
    t.index [ "correlation_id" ], name: "index_ai_workflow_runs_on_correlation_id", unique: true
    t.index [ "metadata" ], name: "index_ai_workflow_runs_on_metadata", using: :gin
    t.index [ "status" ], name: "index_ai_workflow_runs_on_status"
    t.index [ "user_id" ], name: "index_ai_workflow_runs_on_user_id"
  end

  create_table "artifacts", force: :cascade do |t|
    t.string "artifact_type"
    t.datetime "created_at", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "name"
    t.string "owner_persona"
    t.jsonb "payload"
    t.string "phase"
    t.datetime "updated_at", null: false
    t.index [ "artifact_type" ], name: "index_artifacts_on_artifact_type"
    t.index [ "owner_persona" ], name: "index_artifacts_on_owner_persona"
    t.index [ "phase" ], name: "index_artifacts_on_phase"
  end

  create_table "backlog_items", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.jsonb "metadata"
    t.integer "priority"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "user_id" ], name: "index_backlog_items_on_user_id"
  end

  create_table "enriched_transactions", force: :cascade do |t|
    t.string "confidence_level"
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "merchant_name"
    t.string "personal_finance_category"
    t.bigint "transaction_id", null: false
    t.datetime "updated_at", null: false
    t.string "website"
    t.index [ "transaction_id" ], name: "index_enriched_transactions_on_transaction_id", unique: true
  end

  create_table "financial_snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.integer "schema_version", null: false
    t.datetime "snapshot_at", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "data" ], name: "index_financial_snapshots_on_data", using: :gin
    t.index [ "user_id", "snapshot_at" ], name: "index_financial_snapshots_on_user_id_and_snapshot_at", unique: true
    t.index [ "user_id", "snapshot_at" ], name: "index_financial_snapshots_on_user_id_and_snapshot_at_desc", order: { snapshot_at: :desc }
    t.index [ "user_id" ], name: "index_financial_snapshots_on_user_id"
  end

  create_table "fixed_incomes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "face_value", precision: 15, scale: 8
    t.bigint "holding_id", null: false
    t.boolean "income_risk_flag", default: false
    t.date "issue_date"
    t.date "maturity_date"
    t.datetime "updated_at", null: false
    t.decimal "yield_percentage", precision: 15, scale: 8
    t.string "yield_type"
    t.index [ "holding_id" ], name: "index_fixed_incomes_on_holding_id", unique: true
  end

  create_table "holdings", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.date "acquisition_date"
    t.string "asset_class"
    t.datetime "asset_class_derived_at"
    t.string "asset_class_source"
    t.decimal "close_price", precision: 15, scale: 8
    t.date "close_price_as_of"
    t.decimal "cost_basis", precision: 15, scale: 8
    t.datetime "created_at", null: false
    t.string "cusip"
    t.jsonb "disclaimers"
    t.boolean "high_cost_flag", default: false, null: false
    t.datetime "import_timestamp"
    t.string "industry"
    t.decimal "institution_price", precision: 15, scale: 8
    t.datetime "institution_price_as_of"
    t.boolean "is_cash_equivalent", default: false, null: false
    t.string "isin"
    t.string "iso_currency_code"
    t.string "market_identifier_code"
    t.decimal "market_value", precision: 15, scale: 8
    t.date "maturity_date"
    t.string "name"
    t.string "proxy_security_id"
    t.decimal "quantity", precision: 15, scale: 8
    t.string "sector"
    t.string "security_id", null: false
    t.integer "source", default: 0, null: false
    t.string "source_institution"
    t.string "subtype"
    t.string "symbol"
    t.string "ticker_symbol"
    t.string "type"
    t.decimal "unrealized_gl", precision: 15, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "vested_value", precision: 15, scale: 8
    t.decimal "ytm", precision: 15, scale: 2
    t.index [ "account_id", "security_id", "source" ], name: "index_holdings_on_account_security_source", unique: true
    t.index [ "account_id" ], name: "index_holdings_on_account_id"
    t.index [ "asset_class" ], name: "index_holdings_on_asset_class"
    t.index [ "market_identifier_code" ], name: "index_holdings_on_market_identifier_code"
    t.index [ "sector" ], name: "index_holdings_on_sector"
    t.index [ "security_id", "account_id" ], name: "index_holdings_on_security_id_and_account_id"
    t.index [ "security_id", "market_value" ], name: "index_holdings_on_security_id_and_market_value"
    t.index [ "ticker_symbol" ], name: "index_holdings_on_ticker_symbol"
  end

  create_table "holdings_snapshots", force: :cascade do |t|
    t.bigint "account_id"
    t.datetime "created_at", null: false
    t.string "name"
    t.jsonb "snapshot_data", default: {}, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "account_id" ], name: "index_holdings_snapshots_on_account_id"
    t.index [ "user_id", "created_at" ], name: "index_holdings_snapshots_on_user_id_and_created_at"
    t.index [ "user_id" ], name: "index_holdings_snapshots_on_user_id"
  end

  create_table "merchants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.text "long_description"
    t.string "merchant_entity_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index [ "merchant_entity_id" ], name: "index_merchants_on_merchant_entity_id", unique: true
  end

  create_table "option_contracts", force: :cascade do |t|
    t.string "contract_type"
    t.datetime "created_at", null: false
    t.date "expiration_date"
    t.bigint "holding_id", null: false
    t.decimal "strike_price", precision: 15, scale: 8
    t.string "underlying_ticker"
    t.datetime "updated_at", null: false
    t.index [ "holding_id" ], name: "index_option_contracts_on_holding_id", unique: true
  end

  create_table "other_incomes", force: :cascade do |t|
    t.decimal "accrued_amount", precision: 15, scale: 2
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "category"
    t.datetime "created_at", null: false
    t.date "end_date"
    t.string "frequency", default: "annual", null: false
    t.string "name", null: false
    t.text "notes"
    t.date "start_date"
    t.decimal "suggested_tax_rate", precision: 8, scale: 4
    t.boolean "taxable", default: true, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "user_id", "start_date" ], name: "index_other_incomes_on_user_id_and_start_date"
    t.index [ "user_id" ], name: "index_other_incomes_on_user_id"
  end

  create_table "ownership_lookups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "details"
    t.string "name", null: false
    t.string "ownership_type", default: "Other", null: false
    t.datetime "updated_at", null: false
    t.index [ "name" ], name: "index_ownership_lookups_on_name"
    t.index [ "ownership_type" ], name: "index_ownership_lookups_on_ownership_type"
  end

  create_table "persona_conversations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "llm_model", null: false
    t.string "persona_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "user_id", "persona_id" ], name: "index_persona_conversations_on_user_id_and_persona_id"
    t.index [ "user_id" ], name: "index_persona_conversations_on_user_id"
  end

  create_table "persona_messages", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "persona_conversation_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index [ "persona_conversation_id" ], name: "index_persona_messages_on_persona_conversation_id"
  end

  create_table "personal_finance_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "detailed", null: false
    t.text "long_description"
    t.string "primary", null: false
    t.datetime "updated_at", null: false
    t.index [ "primary", "detailed" ], name: "index_pfc_on_primary_and_detailed", unique: true
  end

  create_table "plaid_api_calls", force: :cascade do |t|
    t.datetime "called_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.integer "cost_cents", default: 0
    t.datetime "created_at", null: false
    t.string "endpoint", default: "unknown", null: false
    t.string "product", null: false
    t.string "request_id"
    t.integer "transaction_count", default: 0
    t.datetime "updated_at", null: false
    t.index [ "called_at" ], name: "index_plaid_api_calls_on_called_at"
    t.index [ "created_at" ], name: "index_plaid_api_calls_on_created_at"
    t.index [ "product", "called_at" ], name: "index_plaid_api_calls_on_product_and_called_at"
  end

  create_table "plaid_api_responses", force: :cascade do |t|
    t.datetime "called_at", null: false
    t.datetime "created_at", null: false
    t.string "endpoint", null: false
    t.jsonb "error_json"
    t.bigint "plaid_api_call_id", null: false
    t.bigint "plaid_item_id"
    t.string "product", null: false
    t.string "request_id"
    t.jsonb "response_json"
    t.datetime "updated_at", null: false
    t.index [ "called_at" ], name: "index_plaid_api_responses_on_called_at"
    t.index [ "plaid_api_call_id" ], name: "index_plaid_api_responses_on_plaid_api_call_id"
    t.index [ "plaid_item_id", "called_at" ], name: "index_plaid_api_responses_on_plaid_item_id_and_called_at"
    t.index [ "plaid_item_id" ], name: "index_plaid_api_responses_on_plaid_item_id"
    t.index [ "product", "endpoint", "called_at" ], name: "idx_on_product_endpoint_called_at_35e69a2afc"
    t.index [ "request_id" ], name: "index_plaid_api_responses_on_request_id"
  end

  create_table "plaid_items", force: :cascade do |t|
    t.text "access_token_encrypted"
    t.text "access_token_encrypted_iv"
    t.datetime "created_at", null: false
    t.datetime "holdings_synced_at"
    t.string "institution_id"
    t.string "institution_name", null: false
    t.string "intended_products"
    t.string "item_id", null: false
    t.text "last_error"
    t.datetime "last_force_at"
    t.datetime "last_holdings_sync_at"
    t.datetime "last_retry_at"
    t.datetime "last_webhook_at"
    t.datetime "liabilities_synced_at"
    t.string "plaid_env"
    t.integer "reauth_attempts", default: 0
    t.integer "retry_count", default: 0, null: false
    t.string "status", default: "good", null: false
    t.string "sync_cursor"
    t.datetime "transactions_synced_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "last_retry_at" ], name: "index_plaid_items_on_last_retry_at"
    t.index [ "user_id", "item_id" ], name: "index_plaid_items_on_user_and_item", unique: true
    t.index [ "user_id", "item_id" ], name: "index_plaid_items_on_user_id_and_item_id", unique: true
    t.index [ "user_id" ], name: "index_plaid_items_on_user_id"
  end

  create_table "recurring_transactions", force: :cascade do |t|
    t.decimal "average_amount", precision: 14, scale: 4
    t.string "category"
    t.datetime "created_at", null: false
    t.string "description"
    t.string "frequency"
    t.decimal "last_amount", precision: 14, scale: 4
    t.date "last_date"
    t.string "merchant_name"
    t.bigint "plaid_item_id", null: false
    t.string "status"
    t.string "stream_id", null: false
    t.string "stream_type"
    t.datetime "updated_at", null: false
    t.index [ "plaid_item_id", "stream_id" ], name: "index_recurring_transactions_on_plaid_item_id_and_stream_id", unique: true
    t.index [ "plaid_item_id" ], name: "index_recurring_transactions_on_plaid_item_id"
  end

  create_table "sap_messages", force: :cascade do |t|
    t.text "content", default: "", null: false
    t.datetime "created_at", null: false
    t.string "model"
    t.string "rag_request_id"
    t.string "role", null: false
    t.bigint "sap_run_id", null: false
    t.datetime "updated_at", null: false
    t.index [ "sap_run_id", "created_at" ], name: "index_sap_messages_on_sap_run_id_and_created_at"
    t.index [ "sap_run_id" ], name: "index_sap_messages_on_sap_run_id"
  end

  create_table "sap_runs", force: :cascade do |t|
    t.string "ai_model_name"
    t.integer "artifact_id"
    t.string "artifact_path"
    t.datetime "completed_at"
    t.string "conversation_type", default: "single_persona"
    t.string "correlation_id", null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "idempotency_uuid"
    t.string "model_used"
    t.jsonb "output_json"
    t.string "persona_id"
    t.string "phase"
    t.string "resume_token"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.text "task"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index [ "correlation_id" ], name: "index_sap_runs_on_correlation_id", unique: true
    t.index [ "started_at" ], name: "index_sap_runs_on_started_at"
    t.index [ "user_id", "persona_id" ], name: "index_sap_runs_on_user_id_and_persona_id"
    t.index [ "user_id", "status", "updated_at" ], name: "index_sap_runs_on_user_id_and_status_and_updated_at"
    t.index [ "user_id" ], name: "index_sap_runs_on_user_id"
  end

  create_table "saved_account_filters", force: :cascade do |t|
    t.string "context"
    t.datetime "created_at", null: false
    t.jsonb "criteria", default: {}, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "user_id", "created_at" ], name: "index_saved_account_filters_on_user_id_and_created_at"
    t.index [ "user_id", "name" ], name: "index_saved_account_filters_on_user_id_and_name", unique: true
    t.index [ "user_id" ], name: "index_saved_account_filters_on_user_id"
  end

  create_table "security_enrichments", force: :cascade do |t|
    t.decimal "beta", precision: 10, scale: 6
    t.decimal "change_percentage", precision: 10, scale: 4
    t.string "company_name"
    t.datetime "created_at", null: false
    t.decimal "current_ratio", precision: 10, scale: 4
    t.jsonb "data", default: {}, null: false
    t.decimal "debt_to_equity", precision: 10, scale: 4
    t.text "description"
    t.decimal "dividend_per_share", precision: 10, scale: 4
    t.decimal "dividend_yield", precision: 10, scale: 6
    t.datetime "enriched_at", null: false
    t.decimal "free_cash_flow_yield", precision: 10, scale: 6
    t.string "image_url"
    t.string "industry"
    t.bigint "market_cap"
    t.decimal "net_profit_margin", precision: 10, scale: 6
    t.jsonb "notes", default: [], null: false
    t.decimal "pe_ratio", precision: 12, scale: 4
    t.decimal "price", precision: 18, scale: 6
    t.decimal "price_to_book", precision: 12, scale: 4
    t.decimal "roa", precision: 10, scale: 6
    t.decimal "roe", precision: 10, scale: 6
    t.decimal "roic", precision: 10, scale: 6
    t.string "sector"
    t.string "security_id", null: false
    t.string "source", null: false
    t.string "status", default: "pending", null: false
    t.string "symbol"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index [ "company_name" ], name: "index_security_enrichments_on_company_name", opclass: :gin_trgm_ops, using: :gin
    t.index [ "data" ], name: "index_security_enrichments_on_data", using: :gin
    t.index [ "enriched_at" ], name: "index_security_enrichments_on_enriched_at"
    t.index [ "industry", "status" ], name: "index_security_enrichments_on_industry_and_status"
    t.index [ "industry" ], name: "index_security_enrichments_on_industry"
    t.index [ "market_cap" ], name: "index_security_enrichments_on_market_cap"
    t.index [ "pe_ratio" ], name: "index_security_enrichments_on_pe_ratio"
    t.index [ "price" ], name: "index_security_enrichments_on_price"
    t.index [ "roe" ], name: "index_security_enrichments_on_roe"
    t.index [ "sector", "status" ], name: "index_security_enrichments_on_sector_and_status"
    t.index [ "sector" ], name: "index_security_enrichments_on_sector"
    t.index [ "security_id", "enriched_at" ], name: "index_security_enrichments_on_security_id_and_enriched_at"
    t.index [ "security_id" ], name: "index_security_enrichments_on_security_id", unique: true
    t.index [ "status" ], name: "index_security_enrichments_on_status"
    t.index [ "symbol" ], name: "index_security_enrichments_on_symbol"
  end

  create_table "snapshots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index [ "user_id" ], name: "index_snapshots_on_user_id"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "job_id"
    t.string "job_type", null: false
    t.bigint "plaid_item_id", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index [ "plaid_item_id", "created_at", "job_id" ], name: "index_sync_logs_on_item_created_at_job"
    t.index [ "plaid_item_id", "created_at" ], name: "index_sync_logs_on_plaid_item_id_and_created_at"
    t.index [ "plaid_item_id" ], name: "index_sync_logs_on_plaid_item_id"
  end

  create_table "transaction_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "long_description"
    t.string "name"
    t.datetime "updated_at", null: false
    t.index [ "code" ], name: "index_transaction_codes_on_code", unique: true
  end

  create_table "transaction_corrections", force: :cascade do |t|
    t.datetime "corrected_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.bigint "corrected_transaction_id", null: false
    t.datetime "created_at", null: false
    t.bigint "original_transaction_id", null: false
    t.jsonb "plaid_correction_data"
    t.string "reason", null: false
    t.datetime "updated_at", null: false
    t.index [ "corrected_at" ], name: "index_transaction_corrections_on_corrected_at"
    t.index [ "corrected_transaction_id" ], name: "index_transaction_corrections_on_corrected_transaction_id"
    t.index [ "original_transaction_id", "corrected_transaction_id" ], name: "idx_txn_corrections_unique", unique: true
    t.index [ "original_transaction_id" ], name: "index_transaction_corrections_on_original_transaction_id"
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "account_owner"
    t.decimal "amount", precision: 14, scale: 4
    t.date "authorized_date"
    t.datetime "authorized_datetime"
    t.string "category"
    t.string "check_number"
    t.decimal "cost_usd", precision: 15, scale: 2
    t.jsonb "counterparties"
    t.datetime "created_at", null: false
    t.string "cusip"
    t.date "date"
    t.datetime "datetime"
    t.string "dedupe_fingerprint"
    t.string "dedupe_key"
    t.datetime "deleted_at"
    t.string "dividend_type"
    t.decimal "fees", precision: 15, scale: 2
    t.datetime "import_timestamp"
    t.decimal "income_usd", precision: 15, scale: 2
    t.string "investment_transaction_id"
    t.string "investment_type"
    t.string "iso_currency_code"
    t.jsonb "location"
    t.string "logo_url"
    t.string "merchant_entity_id"
    t.bigint "merchant_id"
    t.string "merchant_name"
    t.string "name"
    t.string "original_description"
    t.string "payment_channel"
    t.jsonb "payment_meta"
    t.boolean "pending", default: false
    t.string "pending_transaction_id"
    t.string "personal_finance_category_confidence_level"
    t.string "personal_finance_category_icon_url"
    t.bigint "personal_finance_category_id"
    t.string "personal_finance_category_label"
    t.string "personal_finance_category_version", default: "v2"
    t.decimal "price", precision: 15, scale: 6
    t.decimal "quantity", precision: 20, scale: 6
    t.string "security_id"
    t.string "source", default: "manual", null: false
    t.string "source_institution"
    t.string "subtype"
    t.string "ticker"
    t.string "tran_code"
    t.string "transaction_code"
    t.bigint "transaction_code_id"
    t.string "transaction_id"
    t.string "transaction_type"
    t.string "type", null: false
    t.string "unofficial_currency_code"
    t.datetime "updated_at", null: false
    t.boolean "wash_sale_risk_flag", default: false
    t.string "website"
    t.index [ "account_id", "dedupe_fingerprint" ], name: "index_txn_on_account_and_fingerprint", unique: true, where: "(dedupe_fingerprint IS NOT NULL)"
    t.index [ "account_id", "dedupe_key" ], name: "index_transactions_on_account_and_dedupe", unique: true
    t.index [ "account_id", "transaction_id" ], name: "index_transactions_on_account_id_and_transaction_id", unique: true
    t.index [ "account_id", "transaction_id" ], name: "index_txn_on_account_and_transaction_id", unique: true, where: "(transaction_id IS NOT NULL)"
    t.index [ "account_id" ], name: "index_transactions_on_account_id"
    t.index [ "counterparties" ], name: "index_transactions_on_counterparties_gin", using: :gin
    t.index [ "deleted_at" ], name: "index_transactions_on_deleted_at"
    t.index [ "investment_transaction_id" ], name: "index_transactions_on_investment_transaction_id"
    t.index [ "investment_type" ], name: "index_transactions_on_investment_type"
    t.index [ "location" ], name: "index_transactions_on_location_gin", opclass: :jsonb_path_ops, using: :gin
    t.index [ "merchant_id" ], name: "index_transactions_on_merchant_id"
    t.index [ "personal_finance_category_id" ], name: "index_transactions_on_personal_finance_category_id"
    t.index [ "personal_finance_category_label" ], name: "index_transactions_on_personal_finance_category_label"
    t.index [ "security_id" ], name: "index_transactions_on_security_id"
    t.index [ "subtype" ], name: "index_transactions_on_subtype"
    t.index [ "transaction_code_id" ], name: "index_transactions_on_transaction_code_id"
    t.index [ "type", "account_id", "date" ], name: "idx_transactions_type_account_date"
    t.index [ "type" ], name: "index_transactions_on_type"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "family_id"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "roles", default: "parent"
    t.datetime "updated_at", null: false
    t.index [ "email" ], name: "index_users_on_email", unique: true
    t.index [ "reset_password_token" ], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type"
    t.jsonb "payload"
    t.bigint "plaid_item_id"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index [ "plaid_item_id" ], name: "index_webhook_logs_on_plaid_item_id"
  end

  add_foreign_key "account_balance_snapshots", "accounts"
  add_foreign_key "accounts", "ownership_lookups", on_delete: :restrict
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_logs", "users"
  add_foreign_key "ai_workflow_runs", "users"
  add_foreign_key "backlog_items", "users"
  add_foreign_key "enriched_transactions", "transactions"
  add_foreign_key "financial_snapshots", "users"
  add_foreign_key "fixed_incomes", "holdings"
  add_foreign_key "holdings", "accounts"
  add_foreign_key "holdings_snapshots", "accounts"
  add_foreign_key "holdings_snapshots", "users"
  add_foreign_key "option_contracts", "holdings"
  add_foreign_key "other_incomes", "users"
  add_foreign_key "persona_conversations", "users"
  add_foreign_key "persona_messages", "persona_conversations"
  add_foreign_key "plaid_api_responses", "plaid_api_calls"
  add_foreign_key "plaid_api_responses", "plaid_items", on_delete: :nullify
  add_foreign_key "plaid_items", "users"
  add_foreign_key "recurring_transactions", "plaid_items"
  add_foreign_key "sap_messages", "sap_runs"
  add_foreign_key "sap_runs", "users"
  add_foreign_key "saved_account_filters", "users"
  add_foreign_key "snapshots", "users"
  add_foreign_key "sync_logs", "plaid_items"
  add_foreign_key "transaction_corrections", "transactions", column: "corrected_transaction_id"
  add_foreign_key "transaction_corrections", "transactions", column: "original_transaction_id"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "merchants"
  add_foreign_key "transactions", "personal_finance_categories"
  add_foreign_key "transactions", "transaction_codes"
  add_foreign_key "webhook_logs", "plaid_items"
end
