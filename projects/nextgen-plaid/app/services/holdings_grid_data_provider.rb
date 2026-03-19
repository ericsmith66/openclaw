# frozen_string_literal: true

require "digest"
require "json"

class HoldingsGridDataProvider
  DEFAULT_PER_PAGE = 25
  CACHE_TTL = 1.hour

  SortSpec = Struct.new(:column, :dir, keyword_init: true)
  Result = Struct.new(:holdings, :summary, :total_count, keyword_init: true)

  def initialize(user, params = {})
    @user = user
    @params = params.to_h
  end

  def call
    holdings = holdings_rows
    Result.new(
      holdings: holdings,
      summary: totals_summary,
      total_count: total_count
    )
  end

  private

  attr_reader :user, :params

  def holdings_rows
    rows = if snapshot_mode?
      snapshot_holdings_rows
    else
      live_holdings_rows
    end

    grouped = group_multi_account(rows)
    grouped = sort_grouped(grouped)
    paginate(grouped)
  end

  def snapshot_mode?
    raw = params[:snapshot_id].presence
    raw.present? && raw.to_s != "live"
  end

  def snapshot_id
    params[:snapshot_id].presence
  end

  def per_page
    raw = params[:per_page].presence
    return :all if raw.to_s == "all"

    value = raw.to_i
    value = DEFAULT_PER_PAGE if value <= 0
    value
  end

  def page
    value = params[:page].to_i
    value = 1 if value <= 0
    value
  end

  def asset_class
    params[:asset_class].presence
  end

  def asset_classes
    raw = params[:asset_classes]
    return nil if raw.nil?

    list = Array(raw).flat_map { |v| v.to_s.split(",") }.map { |v| v.strip.presence }.compact
    list.presence
  end

  def search_term
    params[:search_term].to_s.strip.presence
  end

  def saved_account_filter
    id = params[:account_filter_id].presence || params[:saved_account_filter_id].presence
    return nil unless id.present?

    user.saved_account_filters.find_by(id: id)
  end

  def sort_spec
    column = params[:sort_column].presence || params[:sort].presence
    dir = params[:dir].presence || params[:sort_dir].presence || "desc"
    dir = dir.to_s.downcase == "asc" ? "asc" : "desc"

    SortSpec.new(column: column.to_s, dir: dir)
  end

  def live_base_relation
    Holding
      .joins(account: :plaid_item)
      .left_joins(:security_enrichment)
      .where(plaid_items: { user_id: user.id })
      .where(accounts: { plaid_account_type: "investment" })
  end

  def live_filtered_relation
    rel = live_base_relation

    if saved_account_filter&.criteria.present?
      filtered_accounts = apply_account_filter(
        Account.joins(:plaid_item).where(plaid_items: { user_id: user.id }).where(plaid_account_type: "investment"),
        saved_account_filter.criteria
      )
      rel = rel.where(accounts: { id: filtered_accounts.select(:id) })
    end

    if asset_classes.present?
      rel = apply_live_asset_class_filter(rel, asset_classes)
    elsif asset_class.present?
      rel = apply_live_asset_class_filter(rel, [ asset_class ])
    end
    rel = apply_search(rel)
    apply_sort(rel)
  end

  def apply_live_asset_class_filter(rel, classes)
    list = Array(classes).map { |v| v.to_s.strip }.reject(&:blank?)
    return rel if list.empty?

    # Backward-compatible: allow filtering by Plaid `holdings.type` as well as
    # derived/normalized `holdings.asset_class`.
    types = security_types_for_asset_classes(list)
    if types.present?
      rel.where(asset_class: list).or(rel.where(type: types))
    else
      rel.where(asset_class: list)
    end
  end

  def security_types_for_asset_classes(asset_classes)
    Array(asset_classes).flat_map do |v|
      case v.to_s
      when "equity" then [ "equity" ]
      when "etf" then [ "etf" ]
      when "mutual_fund" then [ "mutual fund", "mutual_fund" ]
      when "fixed_income", "bond" then [ "fixed income", "fixed_income" ]
      when "cd" then [ "cd" ]
      when "money_market" then [ "money market", "money_market" ]
      else
        []
      end
    end.uniq
  end

  def live_holdings_rows
    rel = live_filtered_relation
    rel
      .includes(:account, :security_enrichment)
      .to_a
  end

  def snapshot_holdings_rows
    snap = user.holdings_snapshots.find_by(id: snapshot_id)
    return [] if snap.nil?

    raw = snap.snapshot_data.to_h
    holdings = raw["holdings"] || raw[:holdings] || []

    rows = Array(holdings).map { |h| normalize_snapshot_row(h) }.compact
    rows = apply_snapshot_filters(rows)
    rows = apply_snapshot_search(rows)
    rows = apply_snapshot_sort(rows)

    enrich_snapshot_rows!(rows)
    rows
  end

  def normalize_snapshot_row(h)
    hash = h.respond_to?(:to_h) ? h.to_h : {}

    security_id = (hash["security_id"] || hash[:security_id]).to_s.presence
    ticker_symbol = (hash["ticker_symbol"] || hash[:ticker_symbol]).to_s.presence
    name = (hash["name"] || hash[:name]).to_s.presence

    return nil if security_id.blank? && ticker_symbol.blank? && name.blank?

    {
      security_id: security_id,
      ticker_symbol: ticker_symbol,
      symbol: (hash["symbol"] || hash[:symbol]).to_s.presence,
      name: name,
      asset_class: (hash["asset_class"] || hash[:asset_class]).to_s.presence,
      sector: (hash["sector"] || hash[:sector]).to_s.presence,
      quantity: (hash["quantity"] || hash[:quantity]).to_f,
      market_value: (hash["market_value"] || hash[:market_value]).to_f,
      cost_basis: (hash["cost_basis"] || hash[:cost_basis]).to_f,
      unrealized_gl: (hash["unrealized_gain_loss"] || hash[:unrealized_gain_loss] || hash["unrealized_gl"] || hash[:unrealized_gl]).to_f,
      account_id: hash["account_id"] || hash[:account_id],
      account_name: (hash["account_name"] || hash[:account_name]).to_s.presence,
      account_mask: (hash["account_mask"] || hash[:account_mask]).to_s.presence,
      security_enrichment: nil
    }
  end

  def apply_snapshot_filters(rows)
    filtered = rows
    if asset_classes.present?
      allowed = asset_classes.to_h { |v| [ v.to_s, true ] }
      filtered = filtered.select { |r| allowed[r[:asset_class].to_s] }
    elsif asset_class.present?
      filtered = filtered.select { |r| r[:asset_class].to_s == asset_class }
    end

    if saved_account_filter&.criteria.present?
      allowed_account_ids = resolve_account_ids_from_criteria(saved_account_filter.criteria)
      if allowed_account_ids.present?
        allowed_set = allowed_account_ids.map(&:to_s).to_h { |v| [ v, true ] }
        filtered = filtered.select { |r| allowed_set[r[:account_id].to_s] }
      end
    end

    filtered
  end

  def apply_snapshot_search(rows)
    term = search_term
    return rows if term.blank?

    needle = term.downcase
    rows.select do |r|
      values = [ r[:ticker_symbol], r[:symbol], r[:name], r[:sector] ].compact
      enrichment_sector = r[:security_enrichment]&.sector
      values << enrichment_sector if enrichment_sector.present?
      values.any? { |v| v.to_s.downcase.include?(needle) }
    end
  end

  def apply_snapshot_sort(rows)
    spec = sort_spec
    key = case spec.column
    when "market_value" then :market_value
    when "unrealized_gl", "gl_dollars" then :unrealized_gl
    when "cost_basis" then :cost_basis
    when "quantity" then :quantity
    when "ticker_symbol", "symbol" then :ticker_symbol
    when "name" then :name
    else
      :market_value
    end

    sorted = rows.sort_by { |r| r[key] || 0 }
    spec.dir == "asc" ? sorted : sorted.reverse
  end

  def enrich_snapshot_rows!(rows)
    security_ids = rows.map { |r| r[:security_id] }.compact.uniq
    return if security_ids.empty?

    by_security_id = SecurityEnrichment.where(security_id: security_ids).index_by(&:security_id)
    rows.each do |r|
      next if r[:security_id].blank?

      r[:security_enrichment] = by_security_id[r[:security_id]]
    end
  end

  def apply_search(rel)
    term = search_term
    return rel if term.blank?

    like = "%#{ActiveRecord::Base.sanitize_sql_like(term)}%"
    rel.where(
      "holdings.ticker_symbol ILIKE :q OR holdings.symbol ILIKE :q OR holdings.name ILIKE :q OR holdings.sector ILIKE :q OR security_enrichments.sector ILIKE :q",
      q: like
    )
  end

  def apply_sort(rel)
    spec = sort_spec
    dir = spec.dir

    order_sql = case spec.column
    when "asset_class" then "holdings.asset_class #{dir} NULLS LAST"
    when "market_value" then "holdings.market_value #{dir} NULLS LAST"
    when "unrealized_gl", "gl_dollars" then "holdings.unrealized_gl #{dir} NULLS LAST"
    when "unrealized_gl_pct", "gl_pct" then "(holdings.unrealized_gl / NULLIF(holdings.cost_basis, 0)) #{dir} NULLS LAST"
    when "cost_basis" then "holdings.cost_basis #{dir} NULLS LAST"
    when "quantity" then "holdings.quantity #{dir} NULLS LAST"
    when "price" then "(holdings.market_value / NULLIF(holdings.quantity, 0)) #{dir} NULLS LAST"
    when "ticker_symbol", "symbol" then "holdings.ticker_symbol #{dir} NULLS LAST"
    when "name" then "holdings.name #{dir} NULLS LAST"
    when "enriched_at" then "security_enrichments.enriched_at #{dir} NULLS LAST"
    else
      "holdings.market_value #{dir} NULLS LAST"
    end

    rel.order(Arel.sql(order_sql))
  end

  def sort_grouped(grouped)
    spec = sort_spec
    pv = totals_summary[:portfolio_value].to_f

    sorted = grouped.sort_by do |g|
      parent = g[:parent]

      case spec.column
      when "ticker_symbol", "symbol"
        v = parent.is_a?(Hash) ? parent[:ticker_symbol] : parent.ticker_symbol
        v.to_s
      when "name"
        v = parent.is_a?(Hash) ? parent[:name] : parent.name
        v.to_s
      when "asset_class"
        v = parent.is_a?(Hash) ? parent[:asset_class] : parent.asset_class
        v.to_s
      when "quantity"
        v = parent.is_a?(Hash) ? parent[:quantity] : parent.quantity
        v.to_f
      when "market_value"
        v = parent.is_a?(Hash) ? parent[:market_value] : parent.market_value
        v.to_f
      when "cost_basis"
        v = parent.is_a?(Hash) ? parent[:cost_basis] : parent.cost_basis
        v.to_f
      when "unrealized_gl", "gl_dollars"
        v = parent.is_a?(Hash) ? parent[:unrealized_gl] : parent.unrealized_gl
        v.to_f
      when "price"
        qty = parent.is_a?(Hash) ? parent[:quantity] : parent.quantity
        mv = parent.is_a?(Hash) ? parent[:market_value] : parent.market_value
        qty.to_f > 0 ? (mv.to_f / qty.to_f) : 0.0
      when "unrealized_gl_pct", "gl_pct"
        gl = parent.is_a?(Hash) ? parent[:unrealized_gl] : parent.unrealized_gl
        cb = parent.is_a?(Hash) ? parent[:cost_basis] : parent.cost_basis
        cb.to_f > 0 ? (gl.to_f / cb.to_f) : 0.0
      when "pct_portfolio", "pct_of_portfolio"
        mv = parent.is_a?(Hash) ? parent[:market_value] : parent.market_value
        pv > 0 ? (mv.to_f / pv) : 0.0
      when "enriched_at"
        enrichment = parent.is_a?(Hash) ? parent[:security_enrichment] : parent.security_enrichment
        # nils last
        enrichment&.enriched_at || Time.at(0)
      else
        # default: market_value
        mv = parent.is_a?(Hash) ? parent[:market_value] : parent.market_value
        mv.to_f
      end
    end

    spec.dir == "asc" ? sorted : sorted.reverse
  end

  def group_key_for(row)
    security_id = row_security_id(row)
    return "sec:#{security_id}" if security_id.present?

    ticker = row_ticker(row).to_s
    name = row_name(row).to_s
    "fallback:#{Digest::SHA256.hexdigest("#{ticker}|#{name}")}"
  end

  def row_security_id(row)
    row.respond_to?(:security_id) ? row.security_id : row[:security_id]
  end

  def row_ticker(row)
    row.respond_to?(:ticker_symbol) ? row.ticker_symbol : row[:ticker_symbol]
  end

  def row_name(row)
    row.respond_to?(:name) ? row.name : row[:name]
  end

  def row_account_id(row)
    if row.respond_to?(:account_id)
      row.account_id
    else
      row[:account_id]
    end
  end

  def row_market_value(row)
    value = row.respond_to?(:market_value) ? row.market_value : row[:market_value]
    value.nil? ? nil : value.to_f
  end

  def row_quantity(row)
    (row.respond_to?(:quantity) ? row.quantity : row[:quantity]).to_f
  end

  def row_cost_basis(row)
    value = row.respond_to?(:cost_basis) ? row.cost_basis : row[:cost_basis]
    value.nil? ? nil : value.to_f
  end

  def row_unrealized_gl(row)
    value = row.respond_to?(:unrealized_gl) ? row.unrealized_gl : row[:unrealized_gl]
    return value.to_f unless value.nil?

    mv = row_market_value(row)
    cb = row_cost_basis(row)
    return nil if mv.nil? || cb.nil?

    mv.to_f - cb.to_f
  end

  def group_multi_account(rows)
    groups = {}
    rows.each do |row|
      key = group_key_for(row)
      (groups[key] ||= []) << row
    end

    groups.values.map do |children|
      if children.length == 1
        row = children.first
        { parent: normalize_single_parent(row), children: [] }
      else
        parent = build_aggregated_parent(children)
        { parent: parent, children: children }
      end
    end
  end

  def normalize_single_parent(row)
    return row if row.is_a?(Hash)

    {
      security_id: row_security_id(row),
      ticker_symbol: row_ticker(row),
      symbol: row.respond_to?(:symbol) ? row.symbol : nil,
      name: row_name(row),
      asset_class: row.respond_to?(:asset_class) ? row.asset_class : nil,
      quantity: row_quantity(row),
      market_value: row_market_value(row).to_f,
      cost_basis: row_cost_basis(row).to_f,
      unrealized_gl: row_unrealized_gl(row),
      security_enrichment: row.respond_to?(:security_enrichment) ? row.security_enrichment : nil,
      account_id: row_account_id(row)
    }
  end

  def build_aggregated_parent(children)
    first = children.first

    {
      security_id: row_security_id(first),
      ticker_symbol: row_ticker(first),
      symbol: first.respond_to?(:symbol) ? first.symbol : first[:symbol],
      name: row_name(first),
      asset_class: first.respond_to?(:asset_class) ? first.asset_class : first[:asset_class],
      quantity: children.sum { |c| row_quantity(c) },
      market_value: children.sum { |c| row_market_value(c).to_f },
      cost_basis: children.sum { |c| row_cost_basis(c).to_f },
      unrealized_gl: children.sum { |c| row_unrealized_gl(c).to_f },
      security_enrichment: first.respond_to?(:security_enrichment) ? first.security_enrichment : first[:security_enrichment]
    }
  end

  def paginate(grouped)
    return grouped if per_page == :all

    offset = (page - 1) * per_page
    grouped.slice(offset, per_page) || []
  end

  def total_count
    if snapshot_mode?
      rows = snapshot_holdings_rows
      groups = rows.map { |r| group_key_for(r) }.uniq
      groups.size
    else
      # Counting distinct groups should not depend on ordering; Postgres rejects
      # `SELECT DISTINCT ... ORDER BY ...` when the ORDER BY columns aren't
      # included in the SELECT list.
      rel = live_filtered_relation.except(:order)
      rel.select(:security_id, :ticker_symbol, :name).distinct.count
    end
  end

  def totals_summary
    Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
      compute_totals_summary
    end
  end

  def compute_totals_summary
    if snapshot_mode?
      rows = snapshot_holdings_rows
      portfolio_value = rows.sum { |r| r[:market_value].to_f }
      total_gl_dollars = rows.sum { |r| r[:unrealized_gl].to_f }
      total_cost_basis = rows.sum { |r| r[:cost_basis].to_f }
    else
      # Ensure we don't return stale aggregates from the AR query cache within
      # long-lived requests/tests.
      rel = live_filtered_relation
      portfolio_value = ActiveRecord::Base.uncached { rel.sum(:market_value).to_f }
      total_gl_dollars = ActiveRecord::Base.uncached { rel.sum(:unrealized_gl).to_f }
      total_cost_basis = ActiveRecord::Base.uncached { rel.sum(:cost_basis).to_f }
    end

    total_gl_pct = total_cost_basis > 0 ? (total_gl_dollars / total_cost_basis) * 100.0 : 0.0

    {
      portfolio_value: portfolio_value,
      total_gl_dollars: total_gl_dollars,
      total_gl_pct: total_gl_pct
    }
  end

  def cache_key
    version = Rails.cache.read(version_cache_key).to_i

    filter_json = {
      account_filter_id: params[:account_filter_id] || params[:saved_account_filter_id],
      asset_class: params[:asset_class],
      search_term: params[:search_term],
      sort: params[:sort] || params[:sort_column],
      dir: params[:dir] || params[:sort_dir]
    }.compact

    sorted_filter_json = JSON.dump(filter_json.sort.to_h)

    "holdings_totals:v1:user:#{user.id}:v:#{version}:filters:#{Digest::SHA256.hexdigest(sorted_filter_json)}:snapshot:#{snapshot_mode? ? snapshot_id : 'live'}"
  end

  def version_cache_key
    "holdings_totals:v1:user:#{user.id}:version"
  end

  def apply_account_filter(scope, criteria)
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

  def resolve_account_ids_from_criteria(criteria)
    base = Account.joins(:plaid_item).where(plaid_items: { user_id: user.id }).where(plaid_account_type: "investment")
    rel = apply_account_filter(base, criteria)
    rel.pluck(:id)
  end
end
