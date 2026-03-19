# frozen_string_literal: true

module NetWorth
  class SyncsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_new_layout!

    def create
      current_user.broadcast_replace_to(
        "net_worth:sync_status:#{current_user.id}",
        target: "sync-status",
        partial: "net_worth/sync_status",
        locals: { status: :pending, snapshot: FinancialSnapshot.latest_for_user(current_user) }
      )

      FinancialSnapshotJob.perform_later(current_user.id)

      render turbo_stream: turbo_stream.replace(
        "sync-status",
        partial: "net_worth/sync_status",
        locals: { status: :pending, snapshot: FinancialSnapshot.latest_for_user(current_user) }
      )
    end

    private

    def require_new_layout!
      enabled = if Rails.env.production?
        ENV["ENABLE_NEW_LAYOUT"] == "true"
      else
        ENV.fetch("ENABLE_NEW_LAYOUT", "true") == "true"
      end

      return if enabled

      head :not_found
    end
  end
end
