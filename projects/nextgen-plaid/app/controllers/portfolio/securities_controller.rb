module Portfolio
  class SecuritiesController < ApplicationController
    before_action :authenticate_user!

    def show
      security_id = params[:security_id].to_s

      result = SecurityDetailDataProvider.new(current_user, security_id, params).call
      if result.nil?
        render plain: "Security not found or no longer accessible", status: :not_found
        return
      end

      @security_id = result.security_id
      @enrichment = result.enrichment
      @holdings = result.holdings
      @holdings_summary = result.holdings_summary
      @holdings_by_account = result.holdings_by_account

      @transactions = result.transactions
      @transaction_totals = result.transaction_totals
      @transaction_total_count = result.transaction_total_count
      @tx_page = result.page
      @tx_per_page = result.per_page
      @return_to = result.return_to

      render :show
    end
  end
end
