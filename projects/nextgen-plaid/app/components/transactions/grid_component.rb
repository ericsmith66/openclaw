# frozen_string_literal: true

module Transactions
  # Primary orchestrator component for transaction views.
  # Handles pagination, sorting, and renders the transaction table.
  # Follows pattern of Portfolio::HoldingsGridComponent.
  class GridComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::UrlHelper
    include Turbo::FramesHelper

    PER_PAGE_OPTIONS = [ 10, 25, 50, 100, "all" ].freeze
    SORT_COLUMNS = %w[date name amount type merchant account security quantity price].freeze
    TRANSACTIONS_GRID_TURBO_FRAME_ID = "transactions_grid".freeze

    # @param view_type [String] Current view type (cash, investments, credit, transfers, summary)
    def initialize(transactions:, total_count:, page:, per_page:, sort:, dir:, type_filter: nil,
                   search_term: nil, date_from: nil, date_to: nil, show_investment_columns: false,
                   view_type: "cash")
      @transactions = Array(transactions)
      @total_count = total_count.to_i
      @page = page.to_i
      @page = 1 if @page <= 0
      @per_page = per_page.to_s
      @sort = sort.to_s
      @dir = dir.to_s
      @type_filter = type_filter.to_s.presence
      @search_term = search_term.to_s.presence
      @date_from = date_from
      @date_to = date_to
      @show_investment_columns = show_investment_columns
      @view_type = view_type.to_s
    end

    private

    attr_reader :transactions, :total_count, :page, :per_page, :sort, :dir,
                :type_filter, :search_term, :date_from, :date_to, :show_investment_columns,
                :view_type

    def investments_view?
      view_type == "investments"
    end

    def transfers_view?
      view_type == "transfers"
    end

    def show_merchant_column?
      !investments_view? && !transfers_view?
    end

    def all_view?
      per_page == "all"
    end

    def per_page_value
      return nil if all_view?

      per_page.to_i
    end

    def total_pages
      return 1 if all_view? || total_count <= 0

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
        type_filter: type_filter.presence,
        search_term: search_term.to_s.strip.presence,
        date_from: date_from,
        date_to: date_to
      }.compact
    end

    def next_page_params
      base_params.merge(page: page + 1)
    end

    def prev_page_params
      base_params.merge(page: page - 1)
    end

    def sort_params(column)
      new_dir = (sort == column && dir == "asc") ? "desc" : "asc"
      base_params.merge(sort: column, dir: new_dir, page: 1)
    end

    def sort_icon(column)
      return "" unless sort == column

      dir == "asc" ? "↑" : "↓"
    end
  end
end
