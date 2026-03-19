require "test_helper"

class ArtifactPreviewComponentTest < ViewComponent::TestCase
  def test_renders_artifact_details
    artifact = Artifact.new(
      name: "Test Feature",
      phase: "draft",
      owner_persona: "SAP",
      payload: { "content" => "This is a PRD", "micro_tasks" => [ { "id" => "T1", "title" => "Task 1", "estimate" => "1h" } ] },
      updated_at: Time.current
    )

    render_inline(ArtifactPreviewComponent.new(artifact: artifact))

    assert_text "Test Feature"
    assert_text "Draft"
    assert_text "SAP"
    assert_text "This is a PRD"
    assert_text "Task 1"
  end

  def test_does_not_render_if_no_artifact
    render_inline(ArtifactPreviewComponent.new(artifact: nil))
    assert_no_selector "div#artifact-preview-container"
  end
end
