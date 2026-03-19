module Admin
  class AiWorkflowController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :require_admin!

    def index
      @tab = params[:tab].to_s.presence_in(%w[artifacts ownership context logs]) || "artifacts"

      @artifacts = Artifact.order(updated_at: :desc)
      @active_artifact = params[:artifact_id].present? ? Artifact.find(params[:artifact_id]) : nil

      correlation_id = params[:correlation_id].presence
      if correlation_id.blank? && @active_artifact
        # Try to find a run associated with this artifact
        run = AiWorkflowRun.where("metadata->>'active_artifact_id' = ?", @active_artifact.id.to_s).order(updated_at: :desc).first
        correlation_id = run.id.to_s if run
      end

      @snapshot = AiWorkflowSnapshot.load_latest(
        correlation_id: correlation_id,
        events_limit: 500,
        fallback: params[:artifact_id].blank?
      )

      @events_page = params[:events_page].to_i
      @events_page = 1 if @events_page < 1
      @events_per_page = 100
    end

    private

    def require_admin!
      head :forbidden unless current_user&.admin?
    end
  end
end
