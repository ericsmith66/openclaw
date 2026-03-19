# frozen_string_literal: true

module Portfolio
  class SecurityDetailComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper
    include Rails.application.routes.url_helpers

    PER_PAGE_OPTIONS = SecurityDetailDataProvider::PER_PAGE_OPTIONS

    def initialize(
      security_id:, enrichment:, holdings:, holdings_summary:, holdings_by_account:,
      transactions:, transaction_totals:, transaction_total_count:, page:, per_page:, return_to:
    )
      @security_id = security_id
      @enrichment = enrichment
      @holdings = holdings
      @holdings_summary = holdings_summary
      @holdings_by_account = holdings_by_account
      @transactions = transactions
      @transaction_totals = transaction_totals
      @transaction_total_count = transaction_total_count
      @page = page
      @per_page = per_page
      @return_to = return_to
    end

    private

    attr_reader :security_id, :enrichment, :holdings, :holdings_summary, :holdings_by_account,
                :transactions, :transaction_totals, :transaction_total_count, :page, :per_page, :return_to

    def back_to_holdings_url
      return_to.presence || portfolio_holdings_path
    end

    def ticker
      enrichment&.symbol.presence || holdings.first&.ticker_symbol.presence || holdings.first&.symbol.presence || "—"
    end

    def company_name
      enrichment&.company_name.presence || holdings.first&.name.to_s
    end

    def logo_url
      enrichment&.image_url.to_s.presence
    end

    def current_price
      return enrichment.price.to_f if enrichment&.price.present?

      # If we have live holdings we can infer a per-share price from market_value/quantity.
      holding = holdings.first
      return nil if holding.blank?

      qty = holding.quantity.to_f
      return nil if qty <= 0

      holding.market_value.to_f / qty
    end

    def enriched_at
      enrichment&.enriched_at
    end

    def enrichment_badge_class
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

    def enrichment_label
      enriched_at.present? ? enriched_at.to_fs(:short) : "N/A"
    end

    def na(value)
      value.present? ? value : "N/A"
    end

    def tx_amount_class(amount)
      amount.to_f >= 0 ? "text-emerald-600" : "text-rose-600"
    end

    def per_page_link(value)
      portfolio_security_path(security_id, request_params.merge(per_page: value, page: 1))
    end

    def page_link(value)
      portfolio_security_path(security_id, request_params.merge(page: value))
    end

    def request_params
      { return_to: return_to.presence }.compact
    end

    def total_pages
      return 1 if per_page.to_s == "all"

      (transaction_total_count.to_f / per_page.to_i).ceil.clamp(1, 10_000)
    end
  end
end
