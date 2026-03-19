class PlaidItemRetriesController < ApplicationController
  before_action :authenticate_user!

  # Epic-0 PRD-0010: Retry button for failed syncs
  def create
    plaid_item = current_user.plaid_items.find_by(id: params[:id])

    unless plaid_item
      flash[:alert] = "Account connection not found."
      return redirect_to accounts_link_path
    end

    unless plaid_item.retry_allowed?
      flash[:alert] = "Retry not available right now."
      return redirect_to accounts_link_path
    end

    plaid_item.with_lock do
      unless plaid_item.retry_allowed?
        flash[:alert] = "Retry not available right now."
        return redirect_to accounts_link_path
      end

      plaid_item.update!(
        retry_count: plaid_item.retry_count.to_i + 1,
        last_retry_at: Time.current
      )
    end

    # Epic-0 PRD-0-04: Only sync products that were originally requested (intended_products)
    # These jobs already handle Plaid errors and will update PlaidItem.status accordingly.
    intended = plaid_item.intended_products_list.presence || PlaidItem::INTENDED_PRODUCT_OPTIONS

    SyncHoldingsJob.perform_later(plaid_item.id) if intended.include?("investments")
    SyncTransactionsJob.perform_later(plaid_item.id) if intended.include?("transactions")
    SyncLiabilitiesJob.perform_later(plaid_item.id) if intended.include?("liabilities")

    flash[:notice] = "Retry enqueued for #{plaid_item.institution_name}."
    redirect_to accounts_link_path
  end
end
