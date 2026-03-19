# frozen_string_literal: true

module Portfolio
  class HoldingsGridComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper

    PER_PAGE_OPTIONS = [ 25, 50, 100, 500, "all" ].freeze

    def initialize(user:, holdings_groups:, summary:, total_count:, page:, per_page:, sort:, dir:, asset_tab: "all", search_term: nil, snapshot_id: nil,
                   compare_to: nil, comparison: nil,
                   saved_account_filters: [], saved_account_filter_id: nil,
                   show_large_all_warning: false)
      @user = user
      @holdings_groups = Array(holdings_groups)
      @summary = summary || {}
      @total_count = total_count.to_i
      @page = page.to_i
      @page = 1 if @page <= 0

      @per_page = per_page.to_s
      @sort = sort.to_s
      @dir = dir.to_s
      @asset_tab = asset_tab.to_s
      @search_term = search_term.to_s
      @snapshot_id = snapshot_id
      @compare_to = compare_to.to_s.presence
      @comparison = comparison

      @saved_account_filters = Array(saved_account_filters)
      @saved_account_filter_id = saved_account_filter_id
      @show_large_all_warning = show_large_all_warning
    end

    private

    attr_reader :user, :holdings_groups, :summary, :total_count, :page, :per_page, :sort, :dir, :asset_tab, :search_term, :snapshot_id,
                :compare_to, :comparison,
                :saved_account_filters, :saved_account_filter_id, :show_large_all_warning

    HOLDINGS_GRID_TURBO_FRAME_ID = "portfolio_holdings_grid".freeze

    TABS = [
      { key: "all", label: "All Positions" },
      { key: "stocks_etfs", label: "Stocks & ETFs" },
      { key: "mutual_funds", label: "Mutual Funds" },
      { key: "bonds_cds_mmfs", label: "Bonds, CDs & MMFs" }
    ].freeze

    def portfolio_value
      summary[:portfolio_value].to_f
    end

    def total_gl_dollars
      summary[:total_gl_dollars].to_f
    end

    def total_gl_pct
      summary[:total_gl_pct].to_f
    end

    def all_view?
      per_page == "all"
    end

    def per_page_value
      return nil if all_view?

      per_page.to_i
    end

    def total_pages
      return 1 if all_view?
      return 1 if total_count <= 0

      (total_count.to_f / per_page_value).ceil
    end

    def showing_from
      return 0 if total_count <= 0
      return 1 if all_view?

      ((page - 1) * per_page_value) + 1
    end

    def showing_to
      return 0 if total_count <= 0
      return total_count if all_view?

      [ page * per_page_value, total_count ].min
    end

    def base_params
      {
        sort: sort.presence,
        dir: dir.presence,
        per_page: per_page.presence,
        asset_tab: asset_tab.presence,
        search_term: search_term.to_s.strip.presence,
        snapshot_id: snapshot_id.presence,
        compare_to: compare_to.presence,
        saved_account_filter_id: saved_account_filter_id.presence
      }.compact
    end

    def comparison_active?
      comparison.present? && compare_to.present? && snapshot_id.present? && snapshot_id.to_s != "live"
    end

    def comparison_overall
      comparison&.dig(:overall) || {}
    end

    def comparison_period_return_pct
      comparison_overall[:period_return_pct]
    end

    def comparison_delta_value
      comparison_overall[:delta_value]
    end

    def comparison_delta_for(parent)
      return nil unless comparison_active?

      key = comparison_key_for(parent)
      comparison&.dig(:securities, key)
    end

    def comparison_key_for(parent)
      security_id = parent_attr(parent, :security_id).to_s.presence
      return "sec:#{security_id}" if security_id.present?

      symbol = parent_symbol(parent)
      name = parent_name(parent)
      "fallback:#{symbol}|#{name}"
    end

    def row_comparison_class(delta)
      return "" unless delta.is_a?(Hash)

      case delta[:status]&.to_sym
      when :added
        "bg-green-50 border-l-4 border-green-500"
      when :removed
        "bg-red-50 border-l-4 border-red-500 opacity-60 line-through"
      else
        ""
      end
    end

    def changed_cell_class(delta, field)
      return "" unless delta.is_a?(Hash)
      return "" unless delta[:status]&.to_sym == :changed

      changed = case field.to_s
      when "quantity"
        delta[:delta_qty].to_f != 0.0
      when "market_value"
        delta[:delta_value].to_f != 0.0
      else
        false
      end

      changed ? "bg-amber-50 font-semibold" : ""
    end

    def period_return_class(return_pct)
      return "" if return_pct.nil?

      return_pct.to_f >= 0 ? "text-green-600 font-bold" : "text-red-600 font-bold"
    end

    def period_delta_class(delta_value)
      return "" if delta_value.nil?

      delta_value.to_f >= 0 ? "text-green-600" : "text-red-600"
    end

    def comparison_column_count
      holdings_grid_column_widths.length
    end

    def expandable_parent_grid_style
      "grid-template-columns: #{holdings_grid_column_widths.join(' ')};"
    end

    def holdings_grid_column_widths
      widths = [
        "6.5rem",  # Symbol
        "20rem",   # Description
        "10rem",   # Asset Class
        "7.5rem",  # Price
        "8.5rem",  # Quantity
        "9.5rem",  # Value
        "9.5rem",  # Cost Basis
        "10.5rem", # Unrealized G/L ($)
        "10rem",   # Unrealized G/L (%)
        "5rem",    # Enrichment
        "9.5rem"   # % of Portfolio
      ]

      if comparison_active?
        widths + [
          "10rem",  # Period Return (%)
          "10.5rem" # Period Delta ($)
        ]
      else
        widths
      end
    end

    def search_params
      base_params.merge(page: 1)
    end

    def sort_active?(column)
      sort.to_s == column.to_s
    end

    def sort_indicator(column)
      return "" unless sort_active?(column)

      dir.to_s == "asc" ? "▲" : "▼"
    end

    def enrichment_badge_class(enriched_at)
      return "badge badge-ghost text-gray-400" if enriched_at.blank?

      age_days = ((Time.current - enriched_at) / 1.day).floor
      case age_days
      when 0
        "badge bg-green-50 text-green-700 border-green-200"
      when 1..3
        "badge bg-amber-50 text-amber-700 border-amber-200"
      else
        "badge bg-red-50 text-red-700 border-red-200"
      end
    end

    def enrichment_label(enriched_at)
      enriched_at.present? ? enriched_at.to_fs(:short) : "N/A"
    end

    def enrichment_dot_class(enriched_at)
      return "bg-gray-300" if enriched_at.blank?

      age_days = ((Time.current - enriched_at) / 1.day).floor
      case age_days
      when 0
        "bg-emerald-500"
      when 1..3
        "bg-amber-500"
      else
        "bg-rose-500"
      end
    end

    def enrichment_tooltip(enriched_at)
      return "Not enriched" if enriched_at.blank?

      "Enriched: #{enriched_at.to_fs(:short)}"
    end

    def tab_link(tab_key)
      base_params.merge(asset_tab: tab_key, page: 1)
    end

    def tab_active?(tab_key)
      asset_tab.to_s == tab_key.to_s || (asset_tab.blank? && tab_key.to_s == "all")
    end

    def pagination_params(new_page)
      base_params.merge(page: new_page)
    end

    def per_page_params(value)
      base_params.merge(per_page: value, page: 1)
    end

    def dismiss_warning_params
      base_params.merge(
        page: page,
        dismiss_large_grid_warning: true
      )
    end

    def sort_link(column)
      next_dir = if sort != column
        "asc"
      else
        dir == "asc" ? "desc" : "asc"
      end

      base_params.merge(sort: column, dir: next_dir, page: 1)
    end

    def loss_or_gain_class(value)
      return "" if value.nil?

      value.to_f >= 0 ? "text-emerald-500" : "text-rose-500"
    end

    def group_parent(group)
      group[:parent]
    end

    def parent_attr(parent, key)
      parent.respond_to?(key) ? parent.public_send(key) : parent[key]
    end

    def parent_symbol(parent)
      parent_attr(parent, :ticker_symbol).presence || parent_attr(parent, :symbol).presence || "—"
    end

    def parent_security_id(parent)
      parent_attr(parent, :security_id).presence
    end

    def security_detail_return_to
      portfolio_holdings_path(base_params.merge(page: page))
    end

    def parent_name(parent)
      parent_attr(parent, :name).to_s
    end

    def parent_asset_class(parent)
      parent_attr(parent, :asset_class).to_s
    end

    def parent_quantity(parent)
      parent_attr(parent, :quantity).to_f
    end

    def parent_value(parent)
      parent_attr(parent, :market_value).to_f
    end

    def parent_cost_basis(parent)
      parent_attr(parent, :cost_basis).to_f
    end

    def parent_unrealized_gl(parent)
      raw = parent_attr(parent, :unrealized_gl)
      return raw.to_f unless raw.nil?

      mv = parent_attr(parent, :market_value)
      cb = parent_attr(parent, :cost_basis)
      return nil if mv.nil? || cb.nil?

      mv.to_f - cb.to_f
    end

    def parent_price(parent)
      qty = parent_quantity(parent)
      return 0.0 if qty <= 0

      parent_value(parent) / qty
    end

    def parent_gl_pct(parent)
      cb = parent_cost_basis(parent)
      gl = parent_unrealized_gl(parent)
      return nil if gl.nil?
      return nil if cb.to_f <= 0

      (gl.to_f / cb.to_f) * 100.0
    end

    def child_account_label(child)
      if child.respond_to?(:account) && child.account.present?
        name = child.account.name.to_s
        mask = child.account.mask.to_s
        mask.present? ? "#{name} • #{mask}" : name
      else
        name = child[:account_name].to_s
        mask = child[:account_mask].to_s
        mask.present? ? "#{name} • #{mask}" : name
      end
    end

    def child_quantity(child)
      (child.respond_to?(:quantity) ? child.quantity : child[:quantity]).to_f
    end

    def child_value(child)
      (child.respond_to?(:market_value) ? child.market_value : child[:market_value]).to_f
    end

    def child_cost_basis(child)
      (child.respond_to?(:cost_basis) ? child.cost_basis : child[:cost_basis]).to_f
    end

    def child_unrealized_gl(child)
      raw = child.respond_to?(:unrealized_gl) ? child.unrealized_gl : child[:unrealized_gl]
      return raw.to_f unless raw.nil?

      mv = child.respond_to?(:market_value) ? child.market_value : child[:market_value]
      cb = child.respond_to?(:cost_basis) ? child.cost_basis : child[:cost_basis]
      return nil if mv.nil? || cb.nil?

      mv.to_f - cb.to_f
    end

    def child_gl_pct(child)
      cb = child_cost_basis(child)
      gl = child_unrealized_gl(child)
      return nil if gl.nil?
      return nil if cb.to_f <= 0

      (gl.to_f / cb.to_f) * 100.0
    end

    def expandable?(group)
      Array(group[:children]).any?
    end

    def parent_pct_of_portfolio(parent)
      pv = portfolio_value
      return 0.0 if pv <= 0

      (parent_value(parent) / pv) * 100.0
    end

    def enrichment_updated_at(parent)
      enrichment = parent_attr(parent, :security_enrichment)
      enrichment&.enriched_at
    end
  end
end
