module Portfolio
  class HoldingsController < ApplicationController
    before_action :authenticate_user!
    before_action :normalize_page_for_query_change!
    before_action :validate_snapshot_id!
    before_action :validate_compare_to!

    DEFAULT_PER_PAGE = 50
    LARGE_ALL_THRESHOLD = 400

    def index
      return if handle_dismiss_large_warning!

      asset_tab = params[:asset_tab].presence || "all"
      asset_classes = asset_classes_for_tab(asset_tab)

      @page = params[:page].to_i
      @page = 1 if @page <= 0

      @per_page = (params[:per_page].presence || DEFAULT_PER_PAGE).to_s
      @sort = params[:sort].presence || "market_value"
      @dir = params[:dir].presence || "desc"

      @asset_tab = asset_tab
      @search_term = params[:search_term].to_s
      @snapshot_id = params[:snapshot_id]
      @compare_to = compare_to_param

      @saved_account_filter_id = params[:saved_account_filter_id].presence
      @saved_account_filters = current_user.saved_account_filters.order(created_at: :desc)

      provider_params = {
        page: @page,
        per_page: @per_page,
        sort: @sort,
        dir: @dir,
        search_term: @search_term,
        asset_classes: asset_classes,
        account_filter_id: @saved_account_filter_id,
        snapshot_id: @snapshot_id
      }

      if comparison_active?
        filter_params = {
          search_term: @search_term,
          asset_classes: asset_classes,
          account_filter_id: @saved_account_filter_id
        }.compact

        @comparison = HoldingsSnapshotComparator
          .new(
            start_snapshot_id: @snapshot_id,
            end_snapshot_id: @compare_to == "current" ? :current : @compare_to,
            user_id: current_user.id,
            filter_params: filter_params,
            include_unchanged: true
          )
          .call

        start_all = HoldingsGridDataProvider.new(current_user, provider_params.merge(page: 1, per_page: "all", snapshot_id: @snapshot_id)).call
        end_snapshot_id = @compare_to == "current" ? "live" : @compare_to
        end_all = HoldingsGridDataProvider.new(current_user, provider_params.merge(page: 1, per_page: "all", snapshot_id: end_snapshot_id)).call

        combined = merge_groups(start_all.holdings, end_all.holdings)
        combined = sort_groups(combined, @sort, @dir, comparison: @comparison)

        @total_count = combined.size
        @holdings_groups = paginate_groups(combined, @page, @per_page)
        @summary = start_all.summary
      else
        result = HoldingsGridDataProvider.new(current_user, provider_params).call

        @holdings_groups = result.holdings
        @summary = result.summary
        @total_count = result.total_count
      end

      @show_large_all_warning = show_large_all_warning?(@per_page, @total_count)

      render :index
    end

    private

    def compare_to_param
      raw = params[:compare_to].presence
      return nil if raw.blank? || raw.to_s == "none"

      raw.to_s
    end

    def comparison_active?
      @snapshot_id.present? && @snapshot_id.to_s != "live" && @compare_to.present?
    end

    def validate_snapshot_id!
      raw = params[:snapshot_id].presence
      return if raw.blank? || raw.to_s == "live"

      return if current_user.holdings_snapshots.user_level.exists?(id: raw)

      flash[:alert] = "Snapshot not found — showing live holdings instead."
      redirect_to portfolio_holdings_path(params.except(:snapshot_id, :controller, :action).permit!)
    end

    def validate_compare_to!
      raw = params[:compare_to].presence
      return if raw.blank? || raw.to_s == "none"

      # Comparison only makes sense when a snapshot is selected.
      if params[:snapshot_id].blank? || params[:snapshot_id].to_s == "live"
        redirect_to portfolio_holdings_path(params.except(:compare_to, :controller, :action).permit!)
        return
      end

      return if raw.to_s == "current" || raw.to_s == "live"

      if raw.to_s == params[:snapshot_id].to_s
        redirect_to portfolio_holdings_path(params.except(:compare_to, :controller, :action).permit!)
        return
      end

      return if current_user.holdings_snapshots.user_level.exists?(id: raw)

      flash[:alert] = "Comparison snapshot not found — comparison cleared."
      redirect_to portfolio_holdings_path(params.except(:compare_to, :controller, :action).permit!)
    end

    def merge_groups(start_groups, end_groups)
      start_groups = Array(start_groups)
      end_groups = Array(end_groups)

      map = {}
      start_groups.each { |g| map[group_key(g)] = g }

      end_groups.each do |g|
        key = group_key(g)
        map[key] ||= g
      end

      map.values
    end

    def group_key(group)
      parent = group.is_a?(Hash) ? group[:parent] : nil
      security_id = parent_value(parent, :security_id).to_s.presence
      return "sec:#{security_id}" if security_id.present?

      symbol = parent_value(parent, :ticker_symbol).to_s.presence || parent_value(parent, :symbol).to_s.presence
      name = parent_value(parent, :name).to_s
      "fallback:#{symbol}|#{name}"
    end

    def parent_value(parent, key)
      return nil if parent.nil?

      parent.respond_to?(key) ? parent.public_send(key) : parent[key]
    end

    def sort_groups(groups, sort, dir, comparison: nil)
      sort = sort.to_s
      dir = dir.to_s == "asc" ? "asc" : "desc"

      sorter = lambda do |group|
        parent = group.is_a?(Hash) ? group[:parent] : nil

        case sort
        when "ticker_symbol", "symbol"
          parent_value(parent, :ticker_symbol).to_s.presence || parent_value(parent, :symbol).to_s
        when "name"
          parent_value(parent, :name).to_s
        when "asset_class"
          parent_value(parent, :asset_class).to_s
        when "price"
          parent_value(parent, :institution_price).to_f
        when "quantity"
          parent_value(parent, :quantity).to_f
        when "market_value"
          parent_value(parent, :market_value).to_f
        when "cost_basis"
          parent_value(parent, :cost_basis).to_f
        when "unrealized_gl"
          parent_value(parent, :unrealized_gain_loss).presence || parent_value(parent, :unrealized_gl)
        when "unrealized_gl_pct"
          parent_value(parent, :unrealized_gl_pct).to_f
        when "enriched_at"
          parent_value(parent, :enriched_at) || parent_value(parent, :enriched_on)
        when "period_return_pct"
          key = group_key(group)
          comparison&.dig(:securities, key, :return_pct).to_f
        when "period_delta_value"
          key = group_key(group)
          comparison&.dig(:securities, key, :delta_value).to_f
        else
          parent_value(parent, :market_value).to_f
        end
      end

      sorted = groups.sort_by { |g| sorter.call(g) }
      dir == "asc" ? sorted : sorted.reverse
    end

    def paginate_groups(groups, page, per_page)
      return groups if per_page.to_s == "all"

      per = per_page.to_i
      per = DEFAULT_PER_PAGE if per <= 0
      page = page.to_i
      page = 1 if page <= 0

      offset = (page - 1) * per
      groups.slice(offset, per) || []
    end

    def show_large_all_warning?(per_page, total_count)
      return false unless per_page.to_s == "all"
      return false unless total_count.to_i > LARGE_ALL_THRESHOLD

      dismissed = session[:dismissed_large_grid_warning] == true
      !dismissed
    end

    def handle_dismiss_large_warning!
      return unless params[:dismiss_large_grid_warning].to_s == "true"

      session[:dismissed_large_grid_warning] = true

      redirect_to portfolio_holdings_path(params.except(:dismiss_large_grid_warning).permit!)
      true
    end

    def normalize_page_for_query_change!
      sig = query_signature
      previous = session[:holdings_grid_query_signature]

      if previous.present? && previous != sig
        # Any filter/sort/per-page change invalidates the previous warning dismissal.
        session[:dismissed_large_grid_warning] = false

        # Reset to page 1 if the request tries to keep an old page.
        if params[:page].to_i > 1
          session[:holdings_grid_query_signature] = sig
          redirect_to portfolio_holdings_path(params.merge(page: 1).permit!)
          return
        end
      end

      session[:holdings_grid_query_signature] = sig
    end

    def query_signature
      relevant = {
        per_page: params[:per_page].presence || DEFAULT_PER_PAGE,
        sort: params[:sort].presence,
        dir: params[:dir].presence,
        search_term: params[:search_term].to_s.strip.presence,
        asset_tab: params[:asset_tab].presence,
        saved_account_filter_id: params[:saved_account_filter_id].presence,
        snapshot_id: params[:snapshot_id].presence,
        compare_to: params[:compare_to].presence
      }.compact

      Digest::SHA256.hexdigest(relevant.sort.to_h.to_json)
    end

    def asset_classes_for_tab(tab)
      case tab.to_s
      when "stocks_etfs"
        %w[equity etf]
      when "mutual_funds"
        %w[mutual_fund]
      when "bonds_cds_mmfs"
        %w[bond fixed_income cd money_market]
      else
        nil
      end
    end
  end
end
