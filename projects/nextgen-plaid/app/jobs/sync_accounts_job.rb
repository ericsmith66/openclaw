# app/jobs/sync_accounts_job.rb
class SyncAccountsJob < ApplicationJob
  queue_as :default

  def perform(plaid_item_id)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

    if item.status == "failed"
      Rails.logger.warn "SyncAccountsJob: Skipping PlaidItem #{plaid_item_id} with failed status"
      return
    end

    # Guard against accidental production Plaid calls in non-production Rails envs
    if ENV["PLAID_ENV"] == "production" && !Rails.env.production?
      Rails.logger.warn "SECURITY GUARD OVERRIDE: Running production Plaid call in #{Rails.env} environment for accounts job"
    end

    now = Time.current
    item.accounts.where(source: "plaid").update_all(
      balances_last_synced_at: now,
      balances_last_sync_status: "started",
      balances_last_sync_error: nil,
      updated_at: now
    )

    PlaidAccountsSyncService.new(item).sync
  rescue Plaid::ApiError => e
    now = Time.current
    item&.accounts&.where(source: "plaid")&.update_all(
      balances_last_synced_at: now,
      balances_last_sync_status: "failure",
      balances_last_sync_error: e.message,
      updated_at: now
    )
    Rails.logger.error "SyncAccountsJob: Plaid error for PlaidItem #{plaid_item_id}: #{e.message}"
    nil
  rescue => e
    now = Time.current
    item&.accounts&.where(source: "plaid")&.update_all(
      balances_last_synced_at: now,
      balances_last_sync_status: "failure",
      balances_last_sync_error: e.message,
      updated_at: now
    )
    Rails.logger.error "SyncAccountsJob: error for PlaidItem #{plaid_item_id}: #{e.message}"
    nil
  end
end
