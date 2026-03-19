# frozen_string_literal: true

class AdminAiWorkflowBannerComponent < ViewComponent::Base
  def initialize(snapshot:, active_artifact: nil)
    @snapshot = snapshot
    @active_artifact = active_artifact
  end
end
