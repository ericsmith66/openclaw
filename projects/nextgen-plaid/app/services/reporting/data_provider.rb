# frozen_string_literal: true

require "csv"
require "digest"

module Reporting
  class DataProvider
    STALE_AFTER = 36.hours

    def initialize(user)
      @user = user
      @start_date = nil
      @end_date = nil
      @account_filter_criteria = nil
    end

    # Chainable date filtering for methods that use dates (transactions, snapshots).
    def with_date_range(start_date, end_date)
      @start_date = start_date
      @end_date = end_date
      self
    end

    # Chainable account filtering for holdings/accounts-based methods.
    #
    # Expected criteria keys (all optional):
    # - account_ids: array of Account ids (integers) and/or plaid `accounts.account_id` strings
    # - institution_ids: array of Plaid institution ids (plaid_items.institution_id)
    # - ownership_types: array of OwnershipLookup.ownership_type (e.g. "Trust")
    # - asset_strategy: string or array of strings (accounts.asset_strategy)
    # - trust_code: string or array of strings (accounts.trust_code)
    # - holder_category: string or array of strings (accounts.holder_category)
    def with_account_filter(criteria)
      @account_filter_criteria = criteria.presence

      %i[
        @_memoized_accounts_relation
        @_memoized_holdings_relation
        @_memoized_core_aggregates
        @_memoized_asset_allocation_breakdown
        @_memoized_sector_weights
        @_memoized_top_holdings
      ].each do |ivar|
        remove_instance_variable(ivar) if instance_variable_defined?(ivar)
      end

      self
    end

    def core_aggregates
      @_memoized_core_aggregates ||= begin
        total_assets = holdings_relation.sum(:market_value).to_f + cash_account_balance.to_f
        total_liabilities = credit_account_balance.to_f
        total_net_worth = total_assets - total_liabilities

        {
          total_net_worth: total_net_worth,
          delta_day: delta_from_snapshot(total_net_worth, 1.day.ago),
          delta_30d: delta_from_snapshot(total_net_worth, 30.days.ago)
        }
      end
    end

    def asset_allocation_breakdown
      @_memoized_asset_allocation_breakdown ||= begin
        totals = Hash.new(0.0)

        holdings_relation
          .pluck(:asset_class, :market_value)
          .each do |asset_class, market_value|
            key = normalize_asset_class(asset_class)
            totals[key] += market_value.to_f
          end

        totals.delete("")
        normalize_percentages(totals)
      end
    end

    def sector_weights
      @_memoized_sector_weights ||= begin
        totals = Hash.new(0.0)

        holdings_relation
          .where(asset_class: "equity")
          .pluck(:sector, :market_value)
          .each do |sector, market_value|
            key = normalize_sector(sector)
            totals[key] += market_value.to_f
          end

        totals.delete("")
        normalized = normalize_percentages(totals)
        normalized.presence
      end
    end

    def top_holdings(limit = 10)
      @_memoized_top_holdings ||= {}
      @_memoized_top_holdings[limit] ||= begin
        total = holdings_relation.sum(:market_value).to_f

        raw = holdings_relation
          .order(Arel.sql("market_value DESC NULLS LAST"))
          .limit(limit)
          .pluck(:name, :symbol, :ticker_symbol, :market_value)
          .map do |name, symbol, ticker_symbol, market_value|
            ticker = symbol.presence || ticker_symbol.presence || name.to_s
            value = market_value.to_f
            pct = total > 0 ? (value / total) : 0.0

            {
              "ticker" => ticker,
              "name" => name.presence || ticker,
              "value" => value,
              "pct_portfolio" => pct
            }
          end

        raw
      end
    end

    # Full holdings list for the Net Worth UI (expanded holdings summary).
    #
    # Returns an array of hashes compatible with `top_holdings`:
    #   { "ticker" => "AAPL", "name" => "Apple Inc", "value" => 123.45, "pct_portfolio" => 0.12 }
    #
    # Sorting is best-effort server-side (by `market_value` or `name`/ticker proxy).
    def holdings(sort: "value", dir: "desc")
      sort_key = sort.to_s
      dir_key = dir.to_s.downcase == "asc" ? "ASC" : "DESC"

      total = holdings_relation.sum(:market_value).to_f

      order_sql = case sort_key
      when "ticker"
        "COALESCE(NULLIF(symbol, ''), NULLIF(ticker_symbol, ''), NULLIF(name, ''), '') #{dir_key}"
      when "name"
        "COALESCE(NULLIF(name, ''), NULLIF(symbol, ''), NULLIF(ticker_symbol, ''), '') #{dir_key}"
      when "pct", "value"
        "market_value #{dir_key} NULLS LAST"
      else
        "market_value DESC NULLS LAST"
      end

      holdings_relation
        .order(Arel.sql(order_sql))
        .pluck(:name, :symbol, :ticker_symbol, :market_value)
        .map do |name, symbol, ticker_symbol, market_value|
          ticker = symbol.presence || ticker_symbol.presence || name.to_s
          value = market_value.to_f
          pct = total > 0 ? (value / total) : 0.0

          {
            "ticker" => ticker,
            "name" => name.presence || ticker,
            "value" => value,
            "pct_portfolio" => pct
          }
        end
    end

    # Export-friendly holdings rows including account name.
    # Used by snapshot export CSV downloads (PRD-3-16).
    def holdings_export_rows
      total = holdings_relation.sum(:market_value).to_f

      holdings_relation
        .joins(:account)
        .pluck("accounts.name", :name, :symbol, :ticker_symbol, :market_value)
        .map do |account_name, name, symbol, ticker_symbol, market_value|
          resolved_symbol = symbol.presence || ticker_symbol.presence || name.to_s
          value = market_value.to_f
          pct = total > 0 ? (value / total) : 0.0

          {
            "account" => account_name.to_s,
            "symbol" => resolved_symbol,
            "name" => (name.presence || resolved_symbol),
            "value" => value,
            "pct_portfolio" => pct
          }
        end
    end

    def monthly_transaction_summary
      @_memoized_monthly_transaction_summary ||= begin
        range = resolved_date_range(default_days: 30)
        txns = transactions_relation.where(date: range)

        income = txns.where("amount > 0").sum(:amount).to_f
        expenses = txns.where("amount < 0").sum(:amount).to_f.abs

        grouped = txns
          .group(:personal_finance_category_label)
          .sum(:amount)
          .transform_values { |v| v.to_f }

        category_totals = Hash.new(0.0)
        grouped.each do |category, amount|
          key = category.to_s.strip
          key = "uncategorized" if key.blank?
          category_totals[key] += amount.to_f
        end

        top_categories = category_totals
          .map { |category, amount| { "category" => category, "amount" => amount.to_f.abs } }
          .sort_by { |h| -h["amount"].to_f }
          .first(5)

        {
          "start_date" => range.begin.to_s,
          "end_date" => range.end.to_s,
          "income" => income,
          "expenses" => expenses,
          "top_categories" => top_categories
        }
      end
    end

    def historical_trends(days = 30)
      @_memoized_historical_trends ||= {}
      @_memoized_historical_trends[days] ||= begin
        rows = FinancialSnapshot
          .recent_for_user(user, days)
          .complete_only
          .limit(30)
          .pluck(:snapshot_at, Arel.sql("data->>'total_net_worth'"))

        rows
          .reverse
          .map do |snapshot_at, total_net_worth|
            {
              "date" => snapshot_at.to_date.to_s,
              "value" => total_net_worth.to_f
            }
          end
      end
    end

    def sync_freshness
      @_memoized_sync_freshness ||= begin
        last_sync = user
          .plaid_items
          .joins(:sync_logs)
          .merge(SyncLog.where(status: "success"))
          .order("sync_logs.created_at DESC")
          .limit(1)
          .pick("sync_logs.created_at")

        stale = last_sync.nil? || last_sync < STALE_AFTER.ago

        {
          stale: stale,
          last_sync_at: last_sync
        }
      end
    end

    def build_snapshot_hash
      @_memoized_build_snapshot_hash ||= begin
        {
          schema_version: 1,
          generated_at: Time.current,
          core: core_aggregates,
          asset_allocation: asset_allocation_breakdown,
          sector_weights: sector_weights,
          top_holdings: top_holdings,
          monthly_transaction_summary: monthly_transaction_summary,
          historical_trends: historical_trends,
          sync_freshness: sync_freshness
        }
      end
    end

    def to_json(*_args)
      build_snapshot_hash.to_json
    end

    def to_csv
      CSV.generate do |csv|
        csv << %w[key value]
        core_aggregates.each { |k, v| csv << [ k, v ] }
      end
    end

    # Sanitized export intended for RAG ingestion.
    # Pass snapshot-stored data when exporting an existing FinancialSnapshot.
    def to_rag_context(snapshot_data = nil)
      data = (snapshot_data || build_snapshot_hash).deep_dup

      %w[account_numbers institution_ids raw_transaction_data].each do |k|
        data.delete(k)
        data.delete(k.to_sym)
      end

      rag_salt = ENV["RAG_SALT"].to_s

      data.merge(
        "user_id_hash" => Digest::SHA256.hexdigest("#{user.id}#{rag_salt}"),
        "exported_at" => Time.current.iso8601,
        "disclaimer" => "Anonymized data for educational AI context (RAG). Do not attempt to re-identify users."
      )
    end

    def to_tableau_json
      flatten_for_tableau(build_snapshot_hash)
    end

    private

    attr_reader :user

    def account_filter_criteria
      @account_filter_criteria.is_a?(Hash) ? @account_filter_criteria : nil
    end

    def apply_account_filter(scope)
      criteria = account_filter_criteria
      return scope unless criteria.present?

      # account_ids may include internal `accounts.id` integers and/or plaid `accounts.account_id` strings.
      if (account_ids = criteria["account_ids"] || criteria[:account_ids]).present?
        ids = Array(account_ids).compact
        numeric_ids, external_ids = ids.partition { |v| v.is_a?(Numeric) || v.to_s.match?(/\A\d+\z/) }
        numeric_ids = numeric_ids.map { |v| v.to_i }.uniq
        external_ids = external_ids.map(&:to_s).map(&:strip).reject(&:blank?).uniq

        scope = scope.where(id: numeric_ids) if numeric_ids.any?
        scope = scope.where(account_id: external_ids) if external_ids.any?
      end

      if (institution_ids = criteria["institution_ids"] || criteria[:institution_ids]).present?
        scope = scope.joins(:plaid_item).where(plaid_items: { institution_id: Array(institution_ids).compact })
      end

      if (ownership_types = criteria["ownership_types"] || criteria[:ownership_types]).present?
        scope = scope.joins(:ownership_lookup).where(ownership_lookups: { ownership_type: Array(ownership_types).compact })
      end

      if (asset_strategy = criteria["asset_strategy"] || criteria[:asset_strategy]).present?
        scope = scope.where(asset_strategy: Array(asset_strategy).compact)
      end

      if (trust_code = criteria["trust_code"] || criteria[:trust_code]).present?
        scope = scope.where(trust_code: Array(trust_code).compact)
      end

      if (holder_category = criteria["holder_category"] || criteria[:holder_category]).present?
        scope = scope.where(holder_category: Array(holder_category).compact)
      end

      scope
    end

    def holdings_relation
      @_memoized_holdings_relation ||= begin
        base = Holding.joins(account: :plaid_item).where(plaid_items: { user_id: user.id })

        criteria = account_filter_criteria
        if criteria.present?
          filtered_accounts = apply_account_filter(Account.joins(:plaid_item).where(plaid_items: { user_id: user.id }))
          base = base.where(accounts: { id: filtered_accounts.select(:id) })
        end

        base
      end
    end

    def accounts_relation
      @_memoized_accounts_relation ||= begin
        base = Account.joins(:plaid_item).where(plaid_items: { user_id: user.id })
        apply_account_filter(base)
      end
    end

    def transactions_relation
      @_memoized_transactions_relation ||= Transaction.joins(account: :plaid_item).where(plaid_items: { user_id: user.id })
    end

    def cash_account_balance
      accounts_relation.where(plaid_account_type: "depository").sum(:current_balance)
    end

    def credit_account_balance
      accounts_relation.where(plaid_account_type: "credit").sum(:current_balance)
    end

    def delta_from_snapshot(current_net_worth, target_time)
      previous = snapshot_net_worth_value_at_or_before(target_time)
      (current_net_worth.to_f - previous).to_f
    end

    def snapshot_net_worth_value_at_or_before(time)
      snapshot = user
        .financial_snapshots
        .where(status: FinancialSnapshot.statuses[:complete])
        .where("snapshot_at <= ?", time)
        .order(snapshot_at: :desc)
        .limit(1)
        .pick(:data)

      net_worth_from_snapshot_data(snapshot)
    end

    def net_worth_from_snapshot_data(data)
      hash = data.to_h

      value = hash["total_net_worth"] || hash[:total_net_worth]
      return value.to_f if value != nil

      nested = hash["core"] || hash[:core] || {}
      nested_value = nested["total_net_worth"] || nested[:total_net_worth]
      nested_value.to_f
    end

    def flatten_for_tableau(hash, prefix = "")
      flattened = {}

      hash.each do |key, value|
        key_s = key.to_s

        next_prefix =
          if prefix.blank?
            case key_s
            when "core" then ""
            when "asset_allocation" then "allocation"
            else
              key_s
            end
          else
            "#{prefix}_#{key_s}"
          end

        if value.is_a?(Hash)
          flattened.merge!(flatten_for_tableau(value, next_prefix))
          next
        end

        tableau_key = next_prefix.presence || key_s
        flattened[tableau_key] = tableau_scalar(value)
      end

      flattened
    end

    def tableau_scalar(value)
      case value
      when Time, DateTime
        value.iso8601
      when Date
        value.to_s
      when Array
        value.to_json
      else
        value
      end
    end

    def normalize_percentages(raw_totals)
      total = raw_totals.values.sum.to_f
      return {} if total <= 0

      percents = raw_totals.transform_values { |v| (v.to_f / total).round(4) }

      adjust_percentages_to_one!(percents)
      percents.transform_values! { |v| v.to_f.round(4) }
      adjust_percentages_to_one!(percents)

      percents
    end

    def normalize_asset_class(asset_class)
      normalized = asset_class.to_s.strip.downcase
      return "other" if normalized.blank?

      # Keep v1 buckets stable.
      case normalized
      when "equities" then "equity"
      when "fixed income" then "fixed_income"
      when "alternatives" then "alternative"
      else
        # keep as-is
      end

      allowed = %w[equity fixed_income cash alternative other]
      allowed.include?(normalized) ? normalized : "other"
    end

    def normalize_sector(sector)
      normalized = sector.to_s.strip.downcase
      return "unknown" if normalized.blank?

      normalized
    end

    def adjust_percentages_to_one!(percents)
      sum = percents.values.sum.to_f
      delta = 1.0 - sum
      return if delta.abs < 0.0001

      key = percents.max_by { |_k, v| v.to_f }&.first
      percents[key] = (percents[key].to_f + delta) if key
    end

    def resolved_date_range(default_days:)
      start_date = resolved_start_date(default_days: default_days)
      end_date = resolved_end_date
      start_date..end_date
    end

    def resolved_start_date(default_days:)
      (@start_date || default_days.days.ago.to_date)
    end

    def resolved_end_date
      (@end_date || Date.current)
    end
  end
end
