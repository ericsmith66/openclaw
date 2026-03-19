# frozen_string_literal: true

module NetWorth
  class HoldingsSummaryComponent < BaseCardComponent
    def initialize(top_holdings:, holdings: nil, expanded: false, sort: nil, dir: nil, error: nil,
                   saved_account_filters: [], saved_account_filter_id: nil)
      @top_holdings = Array(top_holdings)
      @holdings = holdings.nil? ? nil : Array(holdings)
      @expanded = expanded
      @sort = (sort.presence || "value").to_s
      @dir = (dir.presence || "desc").to_s
      @error = error
      @saved_account_filters = Array(saved_account_filters)
      @saved_account_filter_id = saved_account_filter_id
    end

    private

    attr_reader :top_holdings, :holdings, :expanded, :sort, :dir, :error, :saved_account_filters, :saved_account_filter_id

    def base_params
      {
        expanded: expanded?,
        sort: sort,
        dir: dir,
        saved_account_filter_id: saved_account_filter_id
      }.compact
    end

    def rows
      expanded? ? (holdings || []) : top_holdings.first(10)
    end

    def expanded?
      expanded == true
    end

    def empty?
      rows.empty?
    end

    def error?
      error.present?
    end

    def server_sort?
      expanded?
    end

    def sort_dir_for(column)
      return "asc" if sort != column

      dir == "asc" ? "desc" : "asc"
    end

    def sort_link(column)
      { expanded: true, sort: column, dir: sort_dir_for(column), saved_account_filter_id: saved_account_filter_id }.compact
    end

    def aria_sort_for(column)
      return "none" unless sort == column

      dir == "asc" ? "ascending" : "descending"
    end

    def format_pct(pct)
      number_to_percentage(pct.to_f * 100.0, precision: 1)
    end
  end
end
