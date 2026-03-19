# frozen_string_literal: true

require "digest"
require "json"

class HoldingsSnapshotComparator
  CACHE_TTL = 30.minutes
  CACHE_VERSION = 1

  def initialize(start_snapshot_id:, end_snapshot_id:, user_id:, filter_params: {}, include_unchanged: false, cache: true)
    @start_snapshot_id = start_snapshot_id
    @end_snapshot_id = end_snapshot_id
    @user_id = user_id
    @filter_params = filter_params.to_h
    @include_unchanged = include_unchanged
    @cache = cache
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    payload = if @cache
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) { compute_payload }
    else
      compute_payload
    end

    payload[:meta][:duration_ms] = duration_ms(started)
    payload
  rescue ActiveRecord::RecordNotFound => e
    log_error("record_not_found", e)
    error_payload("snapshot_not_found", e.message)
  rescue StandardError => e
    log_error("error", e)
    error_payload("error", e.message)
  end

  private

  def compute_payload
    start_rows = fetch_rows(@start_snapshot_id)
    end_rows = fetch_rows(@end_snapshot_id)

    matched = match_rows(start_rows, end_rows)

    securities = compute_security_deltas(matched)
    overall = compute_overall_metrics(start_rows:, end_rows:)

    {
      overall: overall,
      securities: securities,
      meta: {
        start_snapshot_id: @start_snapshot_id,
        end_snapshot_id: @end_snapshot_id,
        user_id: @user_id,
        include_unchanged: @include_unchanged,
        cache_key: cache_key,
        duration_ms: nil
      }
    }
  end

  def error_payload(code, message)
    {
      overall: nil,
      securities: {},
      error: { code: code, message: message },
      meta: {
        start_snapshot_id: @start_snapshot_id,
        end_snapshot_id: @end_snapshot_id,
        user_id: @user_id,
        include_unchanged: @include_unchanged,
        cache_key: cache_key,
        duration_ms: nil
      }
    }
  end

  def cache_key
    filter_json = JSON.dump(@filter_params.sort.to_h)
    filter_hash = Digest::SHA256.hexdigest(filter_json)
    start_part = @start_snapshot_id.to_s
    end_part = @end_snapshot_id.to_s

    "snapshot_comparison:v#{CACHE_VERSION}:#{start_part}:#{end_part}:user:#{@user_id}:filters:#{filter_hash}:include_unchanged:#{@include_unchanged}"
  end

  def fetch_rows(snapshot_id)
    if snapshot_id == :current || snapshot_id.to_s == "current" || snapshot_id.to_s == "live"
      fetch_live_rows
    else
      fetch_snapshot_rows(snapshot_id)
    end
  end

  def fetch_live_rows
    user = User.find(@user_id)
    result = HoldingsGridDataProvider.new(user, @filter_params.merge(snapshot_id: "live", per_page: "all")).call

    grouped = Array(result.holdings)
    grouped.map { |g| g.is_a?(Hash) ? g[:parent] : g }.map { |row| normalize_row(row) }.compact
  end

  def fetch_snapshot_rows(snapshot_id)
    user = User.find(@user_id)
    result = HoldingsGridDataProvider.new(user, @filter_params.merge(snapshot_id: snapshot_id, per_page: "all")).call

    grouped = Array(result.holdings)
    grouped.map { |g| g.is_a?(Hash) ? g[:parent] : g }.map { |row| normalize_row(row) }.compact
  end

  def normalize_row(row)
    hash = row.respond_to?(:to_h) ? row.to_h : {}

    security_id = (hash["security_id"] || hash[:security_id]).to_s.presence
    ticker_symbol = (hash["ticker_symbol"] || hash[:ticker_symbol] || hash["symbol"] || hash[:symbol]).to_s.presence
    name = (hash["name"] || hash[:name]).to_s.presence
    return nil if security_id.blank? && ticker_symbol.blank? && name.blank?

    {
      security_id: security_id,
      ticker_symbol: ticker_symbol,
      name: name,
      quantity: (hash["quantity"] || hash[:quantity]).to_f,
      market_value: (hash["market_value"] || hash[:market_value]).to_f,
      cost_basis: (hash["cost_basis"] || hash[:cost_basis]).to_f,
      account_id: hash["account_id"] || hash[:account_id]
    }
  rescue StandardError => e
    log_warning("invalid_row", error: e.message)
    nil
  end

  def fallback_key(row)
    ticker = row[:ticker_symbol].to_s
    name = row[:name].to_s
    Digest::SHA256.hexdigest("#{ticker}|#{name}")
  end

  def match_rows(start_rows, end_rows)
    start_by_sec_id = {}
    start_by_fallback = {}
    start_rows.each do |r|
      start_by_sec_id[r[:security_id]] = r if r[:security_id].present?
      start_by_fallback[fallback_key(r)] ||= r
    end

    end_by_sec_id = {}
    end_by_fallback = {}
    end_rows.each do |r|
      end_by_sec_id[r[:security_id]] = r if r[:security_id].present?
      end_by_fallback[fallback_key(r)] ||= r
    end

    matched_start = {}
    matched_end = {}
    pairs = {}

    # Prefer `security_id` matches.
    (start_by_sec_id.keys & end_by_sec_id.keys).each do |sec_id|
      s = start_by_sec_id[sec_id]
      e = end_by_sec_id[sec_id]
      key = "sec:#{sec_id}"
      pairs[key] = [ s, e ]
      matched_start[s.object_id] = true
      matched_end[e.object_id] = true
    end

    # Fallback matches for holdings missing `security_id` on either side.
    (start_by_fallback.keys & end_by_fallback.keys).each do |fb|
      s = start_by_fallback[fb]
      e = end_by_fallback[fb]
      next if matched_start[s.object_id] || matched_end[e.object_id]

      key = s[:security_id].presence || e[:security_id].presence
      out_key = key.present? ? "sec:#{key}" : "fallback:#{fb}"
      pairs[out_key] = [ s, e ]
      matched_start[s.object_id] = true
      matched_end[e.object_id] = true

      if s[:security_id].present? ^ e[:security_id].present?
        log_warning(
          "fallback_match",
          start_security_id: s[:security_id],
          end_security_id: e[:security_id],
          ticker_symbol: e[:ticker_symbol].presence || s[:ticker_symbol],
          name: e[:name].presence || s[:name]
        )
      end
    end

    # Added / removed.
    start_rows.each do |s|
      next if matched_start[s.object_id]

      key = s[:security_id].present? ? "sec:#{s[:security_id]}" : "fallback:#{fallback_key(s)}"
      pairs[key] = [ s, nil ]
    end

    end_rows.each do |e|
      next if matched_end[e.object_id]

      key = e[:security_id].present? ? "sec:#{e[:security_id]}" : "fallback:#{fallback_key(e)}"
      pairs[key] = [ nil, e ]
    end

    pairs
  end

  def compute_overall_metrics(start_rows:, end_rows:)
    start_value = start_rows.sum { |r| r[:market_value].to_f }
    end_value = end_rows.sum { |r| r[:market_value].to_f }

    delta_value = end_value - start_value
    delta_pct = safe_return_pct(start_value, end_value)

    {
      start_value: start_value,
      end_value: end_value,
      delta_value: delta_value,
      delta_pct: delta_pct,
      period_return_pct: delta_pct
    }
  end

  def compute_security_deltas(pairs)
    out = {}

    pairs.each do |key, (start_r, end_r)|
      entry = if start_r && end_r
        compute_changed_delta(start_r, end_r)
      elsif end_r
        compute_added_delta(end_r)
      else
        compute_removed_delta(start_r)
      end

      next if !@include_unchanged && entry[:status] == :unchanged
      out[key] = entry
    end

    out
  end

  def compute_changed_delta(start_r, end_r)
    start_val = start_r[:market_value].to_f
    end_val = end_r[:market_value].to_f
    start_qty = start_r[:quantity].to_f
    end_qty = end_r[:quantity].to_f

    delta_qty = end_qty - start_qty
    delta_value = end_val - start_val
    return_pct = safe_return_pct(start_val, end_val)

    status = (delta_qty.zero? && delta_value.zero?) ? :unchanged : :changed

    {
      ticker: end_r[:ticker_symbol].presence || start_r[:ticker_symbol],
      name: end_r[:name].presence || start_r[:name],
      security_id: end_r[:security_id].presence || start_r[:security_id],
      status: status,
      delta_qty: delta_qty,
      delta_value: delta_value,
      return_pct: return_pct,
      start_value: start_val,
      end_value: end_val,
      start_quantity: start_qty,
      end_quantity: end_qty
    }
  end

  def compute_added_delta(end_r)
    end_val = end_r[:market_value].to_f
    end_qty = end_r[:quantity].to_f

    {
      ticker: end_r[:ticker_symbol],
      name: end_r[:name],
      security_id: end_r[:security_id],
      status: :added,
      delta_qty: end_qty,
      delta_value: end_val,
      return_pct: nil,
      start_value: 0.0,
      end_value: end_val,
      start_quantity: 0.0,
      end_quantity: end_qty
    }
  end

  def compute_removed_delta(start_r)
    start_val = start_r[:market_value].to_f
    start_qty = start_r[:quantity].to_f

    {
      ticker: start_r[:ticker_symbol],
      name: start_r[:name],
      security_id: start_r[:security_id],
      status: :removed,
      delta_qty: -start_qty,
      delta_value: -start_val,
      return_pct: nil,
      start_value: start_val,
      end_value: 0.0,
      start_quantity: start_qty,
      end_quantity: 0.0
    }
  end

  def safe_return_pct(start_value, end_value)
    start_value = start_value.to_f
    end_value = end_value.to_f
    return nil if start_value.zero?

    (((end_value - start_value) / start_value) * 100.0).round(2)
  end

  def duration_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0).round(1)
  end

  def log_warning(event, extra = {})
    payload = { service: self.class.name, event: event, user_id: @user_id }.merge(extra)
    Rails.logger.warn(payload.to_json)
  end

  def log_error(event, exception)
    payload = {
      service: self.class.name,
      event: event,
      user_id: @user_id,
      error_class: exception.class.name,
      error: exception.message
    }
    Rails.logger.error(payload.to_json)
  end
end
