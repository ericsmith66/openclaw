class ArtifactPreviewComponent < ViewComponent::Base
  include ApplicationHelper
  include Turbo::StreamsHelper
  include Turbo::FramesHelper

  def initialize(artifact:, user_id: nil)
    @artifact = artifact
    @user_id = user_id
  end

  def user_id
    @user_id || @artifact.sap_runs.first&.user_id
  end

  def render?
    @artifact.present?
  end

  def name
    @artifact.name
  end

  def phase
    @artifact.phase
  end

  def owner
    @artifact.owner_persona
  end

  def updated_at
    @artifact.updated_at.strftime("%b %d, %H:%M")
  end

  def prd_content
    @artifact.payload["content"] || "No PRD content available."
  end

  def tasks
    @artifact.payload["micro_tasks"] || []
  end

  def implementation_notes
    @artifact.payload["implementation_notes"]
  end
end
