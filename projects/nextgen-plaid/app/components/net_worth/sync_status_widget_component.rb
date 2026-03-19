# frozen_string_literal: true

module NetWorth
  class SyncStatusWidgetComponent < ViewComponent::Base
    def initialize(user:, snapshot: nil, status: :complete, error_reason: nil, retry_after: nil)
      @user = user
      @snapshot = snapshot
      @status = status
      @error_reason = error_reason
      @retry_after = retry_after
    end

    private

    attr_reader :user, :snapshot, :status, :error_reason, :retry_after
  end
end
