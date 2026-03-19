# frozen_string_literal: true

class SecurityDetailDataProvider
  DEFAULT_PER_PAGE = 25
  PER_PAGE_OPTIONS = [ 25, 50, 100, "all" ].freeze

  Result = Struct.new(
    :security_id,
    :enrichment,
    :holdings,
    :holdings_summary,
    :holdings_by_account,
    :transactions,
    :transaction_totals,
    :transaction_total_count,
    :page,
    :per_page,
    :return_to,
    keyword_init: true
  )

  def initialize(user, security_id, params = {})
    @user = user
    @security_id = security_id.to_s
    @params = if params.respond_to?(:to_unsafe_h)
      params.to_unsafe_h
    else
      params.to_h
    end
  end

  def call
    return nil if security_id.blank?

    enrichment = SecurityEnrichment.find_by(security_id: security_id)
    holdings = holdings_relation.includes(:account, :security_enrichment).to_a
    tx_rel = transactions_relation.includes(:account)

    exists = enrichment.present? || holdings.any? || tx_rel.exists?
    return nil unless exists

    tx_total_count = tx_rel.count
    paged = paginate(tx_rel)

    Result.new(
      security_id: security_id,
      enrichment: enrichment,
      holdings: holdings,
      holdings_summary: holdings_summary(holdings),
      holdings_by_account: holdings_by_account(holdings),
      transactions: paged,
      transaction_totals: transaction_totals(tx_rel),
      transaction_total_count: tx_total_count,
      page: page,
      per_page: per_page_param,
      return_to: return_to
    )
  end

  private

  attr_reader :user, :security_id, :params

  def return_to
    params[:return_to].to_s.presence
  end

  def holdings_relation
    Holding
      .joins(account: :plaid_item)
      .where(plaid_items: { user_id: user.id })
      .where(accounts: { plaid_account_type: "investment" })
      .where(security_id: security_id)
  end

  def transactions_relation
    Transaction
      .joins(account: :plaid_item)
      .where(plaid_items: { user_id: user.id })
      .where(security_id: security_id)
      .order(date: :desc, id: :desc)
  end

  def page
    value = params[:page].to_i
    value = 1 if value <= 0
    value
  end

  def per_page_param
    raw = params[:per_page].presence
    return "all" if raw.to_s == "all"

    value = raw.to_i
    value = DEFAULT_PER_PAGE if value <= 0
    value
  end

  def paginate(rel)
    return rel.to_a if per_page_param.to_s == "all"

    rel.limit(per_page_param).offset((page - 1) * per_page_param).to_a
  end

  def holdings_summary(holdings)
    qty = holdings.sum { |h| h.quantity.to_f }
    value = holdings.sum { |h| h.market_value.to_f }
    cost = holdings.sum { |h| h.cost_basis.to_f }
    gl = holdings.sum { |h| h.unrealized_gl.to_f }
    gl_pct = cost.to_f > 0 ? (gl / cost.to_f) * 100.0 : 0.0

    {
      total_quantity: qty,
      total_market_value: value,
      total_cost_basis: cost,
      total_unrealized_gl: gl,
      total_unrealized_gl_pct: gl_pct
    }
  end

  def holdings_by_account(holdings)
    holdings
      .group_by(&:account)
      .map do |account, rows|
        qty = rows.sum { |h| h.quantity.to_f }
        value = rows.sum { |h| h.market_value.to_f }
        cost = rows.sum { |h| h.cost_basis.to_f }
        gl = rows.sum { |h| h.unrealized_gl.to_f }
        gl_pct = cost.to_f > 0 ? (gl / cost.to_f) * 100.0 : 0.0

        {
          account: account,
          quantity: qty,
          market_value: value,
          cost_basis: cost,
          unrealized_gl: gl,
          unrealized_gl_pct: gl_pct
        }
      end
      .sort_by { |r| -r[:market_value].to_f }
  end

  def transaction_totals(rel)
    scope = rel.unscope(:order)

    invested = sum_amount_for_kinds(scope, %w[buy contribution])
    proceeds = sum_amount_for_kinds(scope, %w[sell distribution])
    dividends = sum_amount_like(scope, "dividend")

    {
      invested: invested.abs,
      proceeds: proceeds,
      net_cash_flow: proceeds - invested.abs,
      dividends: dividends
    }
  end

  def sum_amount_for_kinds(scope, kinds)
    kinds = Array(kinds).map { |v| v.to_s.downcase }
    scope
      .where("lower(coalesce(transactions.transaction_type, transactions.subtype, '')) IN (?)", kinds)
      .sum(:amount)
      .to_f
  end

  def sum_amount_like(scope, needle)
    pattern = "%#{needle.to_s.downcase}%"
    scope
      .where("lower(coalesce(transactions.transaction_type, transactions.subtype, '')) LIKE ?", pattern)
      .sum(:amount)
      .to_f
  end
end
