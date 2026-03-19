# frozen_string_literal: true

class SnapshotSelectorComponent < ViewComponent::Base
  DEFAULT_LIMIT = 50

  def initialize(user:, selected_snapshot_id:, base_params:, turbo_frame_id: nil, holdings_path_helper: :portfolio_holdings_path,
                 limit: DEFAULT_LIMIT)
    @user = user
    @selected_snapshot_id = selected_snapshot_id.presence
    @base_params = base_params.to_h
    @turbo_frame_id = turbo_frame_id
    @holdings_path_helper = holdings_path_helper
    @limit = limit.to_i
    @limit = DEFAULT_LIMIT if @limit <= 0
  end

  private

  attr_reader :user, :selected_snapshot_id, :base_params, :turbo_frame_id, :holdings_path_helper, :limit

  def holdings_path(params)
    public_send(holdings_path_helper, params)
  end

  def snapshots
    user
      .holdings_snapshots
      .user_level
      .recent_first
      .limit(limit)
  end

  def snapshot_mode?
    selected_snapshot_id.present? && selected_snapshot_id.to_s != "live"
  end

  def selected_snapshot
    return nil unless snapshot_mode?

    snapshots.find { |s| s.id.to_s == selected_snapshot_id.to_s }
  end

  def selected_label
    return "Latest (live)" unless snapshot_mode?

    snap = selected_snapshot
    return "Historical snapshot" if snap.nil?

    "Snapshot • #{snap.created_at.in_time_zone.strftime('%b %-d, %Y %l:%M%P')}"
  end

  def option_label(snapshot)
    snapshot.created_at.in_time_zone.strftime("%b %-d, %Y %l:%M%P")
  end

  def form_params_for(snapshot_id)
    params = base_params.dup
    params.delete(:page)
    params.delete("page")
    params.delete(:snapshot_id)
    params.delete("snapshot_id")
    params[:snapshot_id] = snapshot_id if snapshot_id.present?
    params[:page] = 1
    params
  end

  def historical_badge_text
    snap = selected_snapshot
    return "Historical view" if snap.nil?

    "Viewing snapshot from #{snap.created_at.in_time_zone.strftime('%b %-d, %Y %l:%M%P')}"
  end
end
