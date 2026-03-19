module NetWorth
  class HoldingsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_new_layout!

    def show
      # Holdings page should default to expanded; collapse is an explicit user action.
      @expanded = if params[:expanded].nil?
        true
      else
        ActiveModel::Type::Boolean.new.cast(params[:expanded])
      end
      @sort = params[:sort].presence
      @dir = params[:dir].presence

      @saved_account_filter_id = params[:saved_account_filter_id].presence
      @saved_account_filters = current_user.saved_account_filters.order(created_at: :desc)
      @selected_saved_account_filter =
        if @saved_account_filter_id.present?
          @saved_account_filters.find_by(id: @saved_account_filter_id)
        end

      @snapshot = FinancialSnapshot.latest_for_user(current_user)
      snapshot_data = @snapshot&.data.to_h
      @top_holdings = snapshot_data["top_holdings"] || snapshot_data[:top_holdings] || []

      provider = nil
      if @top_holdings.blank? || @expanded
        provider = Reporting::DataProvider.new(current_user)
        provider = provider.with_account_filter(@selected_saved_account_filter.criteria) if @selected_saved_account_filter
        @top_holdings = provider.top_holdings if @top_holdings.blank?
      end

      if @expanded
        @holdings = provider.holdings(sort: @sort, dir: @dir)
      else
        @holdings = nil
      end

      render :show
    rescue StandardError => e
      @expanded = true
      @top_holdings = []
      @holdings = []
      @error = e.message

      render :show, status: :ok
    end

    private

    def require_new_layout!
      enabled = if Rails.env.production?
        ENV["ENABLE_NEW_LAYOUT"] == "true"
      else
        ENV.fetch("ENABLE_NEW_LAYOUT", "true") == "true"
      end

      return if enabled

      head :not_found
    end
  end
end
