# frozen_string_literal: true

class ComparisonSelectorComponent < ViewComponent::Base
  DEFAULT_LIMIT = 50

  def initialize(user:, selected_snapshot_id:, compare_to: nil, base_params:, turbo_frame_id: nil,
                 holdings_path_helper: :portfolio_holdings_path, limit: DEFAULT_LIMIT)
    @user = user
    @selected_snapshot_id = selected_snapshot_id.presence
    @compare_to = compare_to.to_s.presence
    @base_params = base_params.to_h
    @turbo_frame_id = turbo_frame_id
    @holdings_path_helper = holdings_path_helper
    @limit = limit.to_i
    @limit = DEFAULT_LIMIT if @limit <= 0
  end

  private

  attr_reader :user, :selected_snapshot_id, :compare_to, :base_params, :turbo_frame_id, :holdings_path_helper, :limit

  def holdings_path(params)
    public_send(holdings_path_helper, params)
  end

  def snapshot_mode?
    selected_snapshot_id.present? && selected_snapshot_id.to_s != "live"
  end

  def comparison_enabled?
    snapshot_mode?
  end

  def snapshots
    scope = user.holdings_snapshots.user_level.recent_first.limit(limit)
    return scope unless snapshot_mode?

    scope.where.not(id: selected_snapshot_id)
  end

  def option_label(snapshot)
    snapshot.created_at.in_time_zone.strftime("%b %-d, %Y %l:%M%P")
  end

  def form_params_for(value)
    params = base_params.dup
    params.delete(:page)
    params.delete("page")
    params.delete(:compare_to)
    params.delete("compare_to")
    params[:compare_to] = value if value.present?
    params[:page] = 1
    params
  end

  def tooltip_text
    "Select a snapshot first"
  end
end
