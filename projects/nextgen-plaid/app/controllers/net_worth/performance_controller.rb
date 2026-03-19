module NetWorth
  class PerformanceController < ApplicationController
    before_action :authenticate_user!

    def show
      @snapshot = FinancialSnapshot.latest_for_user(current_user)
      @snapshot_data = @snapshot&.data&.to_h || {}
    end
  end
end
