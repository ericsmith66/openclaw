# frozen_string_literal: true

class CreateHoldingsSnapshotService
  Result = Struct.new(:status, :snapshot, :error, :message, :permanent, keyword_init: true) do
    def success?
      status == :success
    end

    def failure?
      status == :failure
    end

    def skipped?
      status == :skipped
    end

    def permanent_failure?
      failure? && permanent
    end
  end

  def initialize(user_id:, account_id: nil, name: nil, force: false)
    @user_id = user_id
    @account_id = account_id
    @name = name
    @force = force
  end

  def call
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    log_event("start")

    unless should_create?
      log_event("skipped", duration_ms: duration_ms(started), reason: "recent_snapshot_exists")
      return Result.new(status: :skipped, message: "Recent snapshot exists")
    end

    user = User.find(@user_id)

    snapshot_data = fetch_holdings_data(user)
    snapshot = create_snapshot(snapshot_data)

    log_event(
      "success",
      duration_ms: duration_ms(started),
      holdings_snapshot_id: snapshot.id,
      holdings_count: Array(snapshot.snapshot_data["holdings"]).size
    )

    Result.new(status: :success, snapshot: snapshot)
  rescue ActiveRecord::RecordNotFound => e
    log_event("failure", duration_ms: duration_ms(started), error_class: e.class.name, error: e.message, permanent: true)
    Result.new(status: :failure, error: e.message, permanent: true)
  rescue StandardError => e
    log_event("failure", duration_ms: duration_ms(started), error_class: e.class.name, error: e.message)
    Result.new(status: :failure, error: e.message, permanent: false)
  end

  private

  def should_create?
    return true if @force

    !recent_snapshot_exists?
  end

  def recent_snapshot_exists?
    scope = HoldingsSnapshot.where(user_id: @user_id)
    scope = @account_id.present? ? scope.where(account_id: @account_id) : scope.user_level
    scope.where("created_at > ?", 24.hours.ago).exists?
  end

  def fetch_holdings_data(user)
    rel = Holding
      .joins(account: :plaid_item)
      .where(plaid_items: { user_id: user.id })
      .where(accounts: { plaid_account_type: "investment" })
      .includes(:account)

    rel = rel.where(account_id: @account_id) if @account_id.present?

    snapshot_holdings = rel.to_a.map { |h| serialize_holding(h) }
    totals = compute_totals(snapshot_holdings)

    {
      holdings: snapshot_holdings,
      totals: totals
    }
  end

  def serialize_holding(holding)
    account = holding.respond_to?(:account) ? holding.account : nil

    unrealized_gl = holding.try(:unrealized_gl)
    if unrealized_gl.nil?
      mv = holding.try(:market_value)
      cb = holding.try(:cost_basis)
      unrealized_gl = (mv.to_f - cb.to_f) if mv.present? && cb.present?
    end

    {
      security_id: holding.try(:security_id),
      ticker_symbol: holding.try(:ticker_symbol),
      symbol: holding.try(:symbol),
      name: holding.try(:name),
      quantity: holding.try(:quantity).to_f,
      market_value: holding.try(:market_value).to_f,
      cost_basis: holding.try(:cost_basis).to_f,
      unrealized_gain_loss: unrealized_gl,
      asset_class: holding.try(:asset_class),
      sector: holding.try(:sector),
      account_id: holding.try(:account_id),
      account_name: account&.name,
      account_mask: account&.mask
    }
  end

  def compute_totals(snapshot_holdings)
    portfolio_value = snapshot_holdings.sum { |h| h[:market_value].to_f }
    total_gl_dollars = snapshot_holdings.sum { |h| h[:unrealized_gain_loss].to_f }
    total_cost_basis = snapshot_holdings.sum { |h| h[:cost_basis].to_f }
    total_gl_pct = total_cost_basis > 0 ? (total_gl_dollars / total_cost_basis) * 100.0 : 0.0

    {
      portfolio_value: portfolio_value,
      total_gl_dollars: total_gl_dollars,
      total_gl_pct: total_gl_pct
    }
  end

  def create_snapshot(data)
    HoldingsSnapshot.create!(
      user_id: @user_id,
      account_id: @account_id,
      name: @name,
      snapshot_data: data
    )
  end

  def duration_ms(started)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0).round(1)
  end

  def log_event(event, extra = {})
    payload = {
      service: self.class.name,
      event: event,
      user_id: @user_id,
      account_id: @account_id,
      force: @force
    }.merge(extra)

    # Keep log as JSON to be machine-friendly.
    Rails.logger.info(payload.to_json)
  end
end
