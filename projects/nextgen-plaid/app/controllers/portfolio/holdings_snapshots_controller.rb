# frozen_string_literal: true

module Portfolio
  class HoldingsSnapshotsController < ApplicationController
    before_action :authenticate_user!

    def index
      @snapshots = current_user.holdings_snapshots.user_level.recent_first.limit(50)
    end
  end
end
