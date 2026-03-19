# frozen_string_literal: true

module Transactions
  # Filter bar component with search, date range, and view-specific placeholders.
  # Supports dynamic search placeholder and sticky positioning.
  # Type filtering is handled by view tabs, not by explicit filter dropdown.
  class FilterBarComponent < ViewComponent::Base
    include ActionView::Helpers::UrlHelper

    PLACEHOLDER_MAP = {
      "investments" => "Search by name, security…",
      "cash" => "Search by name, merchant…",
      "credit" => "Search by name, merchant…",
      "transfers" => "Search by name, merchant…",
      "summary" => "Search by name, merchant…"
    }.freeze

    # @param search_term [String, nil]
    # @param date_from [String, nil]
    # @param date_to [String, nil]
    # @param amount_threshold [Numeric, nil]
    # @param view_type [String] Current view type for dynamic placeholder
    def initialize(search_term: nil, type_filter: nil, date_from: nil, date_to: nil,
                   amount_threshold: nil, view_type: "cash")
      @search_term = search_term.to_s
      @type_filter = type_filter.to_s # Kept for backward compatibility but not used in UI
      @date_from = date_from
      @date_to = date_to
      @amount_threshold = amount_threshold
      @view_type = view_type.to_s
    end

    private

    attr_reader :search_term, :type_filter, :date_from, :date_to, :amount_threshold,
                :view_type

    def search_placeholder
      PLACEHOLDER_MAP[view_type] || "Search by name, merchant…"
    end
  end
end
