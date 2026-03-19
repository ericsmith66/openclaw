# frozen_string_literal: true

class TransactionGridDataProvider
  DEFAULT_PER_PAGE = 25
  LARGE_DATASET_THRESHOLD = 500

  Result = Struct.new(:transactions, :summary, :total_count, :warning, keyword_init: true)

  def initialize(user, params = {})
    @user = user
    @params = if params.respond_to?(:to_unsafe_hash)
                params.to_unsafe_hash
    else
                params.to_h
    end
  end

  def call
    if summary_mode?
      compute_summary
    else
      transactions = transaction_rows
      Result.new(
        transactions: transactions,
        summary: totals_summary,
        total_count: total_count,
        warning: @large_dataset_warning
      )
    end
  end

  private

  attr_reader :user, :params

  def transaction_rows
    rel = base_relation
    rel = filter_by_type(rel)
    rel = filter_by_transfer(rel) if transfers_filter?
    rel = apply_account_filter(rel)
    rel = apply_date_range(rel)
    rel = apply_search(rel)
    rel = apply_sort(rel)
    paginate(rel)
  end

  def base_relation
    Transaction.joins(account: :plaid_item)
               .where(plaid_items: { user_id: user.id })
               .includes(:account)
  end

  def filter_by_type(relation)
    return relation unless type_filter.present?

    relation.where(type: type_filter)
  end

  def filter_by_transfer(relation)
    relation.where("personal_finance_category_label ILIKE ?", "TRANSFER%")
            .where.not(accounts: { plaid_account_type: "investment" })
  end

  def transfers_filter?
    params[:transfers].present? || params[:view_type] == "transfers"
  end

  def type_filter
    @type_filter ||= begin
      filter = params[:type_filter].presence
      # Map view_type to STI class if type_filter not explicitly provided
      if filter.blank?
        case params[:view_type]
        when "regular" then "RegularTransaction"
        when "investment" then "InvestmentTransaction"
        when "credit" then "CreditTransaction"
        end
      else
        filter
      end
    end
  end

  def apply_account_filter(relation)
    return relation unless account_filter_id.present?

    saved_filter = user.saved_account_filters.find_by(id: account_filter_id)
    return relation unless saved_filter&.criteria.present?

    account_ids = filtered_account_ids(saved_filter.criteria)
    relation.where(account_id: account_ids) if account_ids.present?
  end

  def filtered_account_ids(criteria)
    base = Account.joins(:plaid_item).where(plaid_items: { user_id: user.id })
    rel = apply_account_filter_logic(base, criteria)
    rel.pluck(:id)
  end

  def apply_account_filter_logic(scope, criteria)
    hash = criteria.respond_to?(:to_h) ? criteria.to_h : {}

    if (account_ids = hash["account_ids"] || hash[:account_ids]).present?
      raw_ids = Array(account_ids).compact
      numeric_ids, external_ids = raw_ids.partition { |id| id.is_a?(Integer) || id.to_s.match?(/\A\d+\z/) }
      numeric_ids = numeric_ids.map(&:to_i)
      external_ids = external_ids.map(&:to_s)

      scope = scope.where(id: numeric_ids) if numeric_ids.any?
      scope = scope.where(account_id: external_ids) if external_ids.any?
    end

    if (institution_ids = hash["institution_ids"] || hash[:institution_ids]).present?
      scope = scope.joins(:plaid_item).where(plaid_items: { institution_id: Array(institution_ids).compact })
    end

    if (ownership_types = hash["ownership_types"] || hash[:ownership_types]).present?
      scope = scope.joins(:ownership_lookup).where(ownership_lookups: { ownership_type: Array(ownership_types).compact })
    end

    if (asset_strategy = hash["asset_strategy"] || hash[:asset_strategy]).present?
      scope = scope.where(asset_strategy: Array(asset_strategy).compact)
    end

    if (trust_code = hash["trust_code"] || hash[:trust_code]).present?
      scope = scope.where(trust_code: Array(trust_code).compact)
    end

    if (holder_category = hash["holder_category"] || hash[:holder_category]).present?
      scope = scope.where(holder_category: Array(holder_category).compact)
    end

    scope
  end

  def apply_date_range(relation)
    if date_from.present?
      relation = relation.where("date >= ?", date_from)
    end
    if date_to.present?
      relation = relation.where("date <= ?", date_to)
    end
    relation
  end

  def apply_search(relation)
    return relation unless search_term.present?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(search_term)}%"
    relation.where("transactions.name ILIKE :term OR transactions.merchant_name ILIKE :term", term: term)
  end

  def apply_sort(relation)
    column = sort_column
    direction = sort_direction

    order_sql = case column
    when "date" then "transactions.date #{direction} NULLS LAST"
    when "name" then "transactions.name #{direction} NULLS LAST"
    when "amount" then "transactions.amount #{direction} NULLS LAST"
    when "merchant_name" then "transactions.merchant_name #{direction} NULLS LAST"
    when "type" then "transactions.type #{direction} NULLS LAST"
    when "subtype" then "transactions.subtype #{direction} NULLS LAST"
    else
                  "transactions.date #{direction} NULLS LAST"
    end

    relation.order(Arel.sql(order_sql))
  end

  def paginate(relation)
    page = params[:page].to_i
    page = 1 if page <= 0
    per_page = params[:per_page].presence || DEFAULT_PER_PAGE
    if per_page.to_s == "all"
      total = filtered_relation.count
      if total > LARGE_DATASET_THRESHOLD
        @large_dataset_warning = "Showing all #{total} transactions. Consider filtering by date or account for better performance."
      end
      relation
    else
      relation.page(page).per(per_page.to_i)
    end
  end

  def filtered_relation
    @filtered_relation ||= begin
      rel = base_relation
      rel = filter_by_type(rel)
      rel = filter_by_transfer(rel) if transfers_filter?
      rel = apply_account_filter(rel)
      rel = apply_date_range(rel)
      rel = apply_search(rel)
      rel
    end
  end

  def total_count
    @total_count ||= filtered_relation.count
  end

  def totals_summary
    rel = filtered_relation

    inflow = rel.where("amount > 0").sum(:amount).to_f
    outflow = rel.where("amount < 0").sum(:amount).to_f
    net = inflow + outflow
    count = rel.count

    {
      inflow: inflow,
      outflow: outflow,
      net: net,
      count: count
    }
  end

  # Helper methods for param extraction
  def account_filter_id
    params[:saved_account_filter_id].presence || params[:account_filter_id].presence
  end

  def date_from
    params[:date_from].presence
  end

  def date_to
    params[:date_to].presence
  end

  def search_term
    params[:search_term].to_s.strip.presence
  end

  def sort_column
    allowed = %w[date name amount merchant_name type subtype]
    column = params[:sort].to_s
    allowed.include?(column) ? column : "date"
  end

  def sort_direction
    %w[asc desc].include?(params[:dir].to_s.downcase) ? params[:dir].to_s.downcase : "desc"
  end

  def summary_mode?
    params[:summary_mode] == true || params[:summary_mode] == "true"
  end

  def compute_summary
    rel = filtered_relation

    Result.new(
      transactions: [],
      summary: {
        total_inflow: total_inflow(rel),
        total_outflow: total_outflow(rel),
        net: net_amount(rel),
        count: rel.count,
        top_categories: top_categories(rel),
        top_merchants: top_merchants(rel),
        monthly_totals: monthly_totals(rel)
      },
      total_count: rel.count,
      warning: nil
    )
  end

  def total_inflow(rel)
    rel.where("amount > 0").sum(:amount).to_f
  end

  def total_outflow(rel)
    rel.where("amount < 0").sum(:amount).to_f
  end

  def net_amount(rel)
    rel.sum(:amount).to_f
  end

  def top_categories(rel)
    # Use pluck to avoid ActiveRecord model instantiation
    rel
      .where.not(personal_finance_category_label: nil)
      .group(:personal_finance_category_label)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(10)
      .pluck(
        Arel.sql("personal_finance_category_label"),
        Arel.sql("COUNT(*)"),
        Arel.sql("SUM(amount)")
      )
      .map { |name, count, total| { name: name, count: count, total: total.to_f } }
  end

  def top_merchants(rel)
    # Use pluck to avoid ActiveRecord model instantiation
    rel
      .where.not(merchant_name: nil)
      .group(:merchant_name)
      .order(Arel.sql("COUNT(*) DESC"))
      .limit(10)
      .pluck(
        Arel.sql("merchant_name"),
        Arel.sql("COUNT(*)"),
        Arel.sql("SUM(amount)")
      )
      .map { |name, count, total| { name: name, count: count, total: total.to_f } }
  end

  def monthly_totals(rel)
    # Use pluck to avoid ActiveRecord model instantiation
    rel
      .group("DATE_TRUNC('month', transactions.date)")
      .order(Arel.sql("DATE_TRUNC('month', transactions.date) DESC"))
      .pluck(
        Arel.sql("DATE_TRUNC('month', transactions.date)"),
        Arel.sql("SUM(amount)")
      )
      .map { |month, total| [ month.strftime("%b %Y"), total.to_f ] }
  end
end
