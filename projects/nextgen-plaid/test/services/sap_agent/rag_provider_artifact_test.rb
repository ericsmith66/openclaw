require "test_helper"

class SapAgent::RagProviderArtifactTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test_rag@example.com", password: "password")
    @artifact = Artifact.create!(
      name: "Test Artifact",
      artifact_type: "feature",
      payload: {
        "content" => "THIS IS THE PRD CONTENT",
        "micro_tasks" => [
          { "id" => "task-1", "title" => "Implement Login" }
        ]
      }
    )
    @sap_run = SapRun.create_conversation(user_id: @user.id, persona_id: "coordinator")
    @sap_run.update!(artifact_id: @artifact.id)
  end

  test "build_prefix includes PRD for coordinator when sap_run_id is provided" do
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "coordinator", @sap_run.id)

    assert_match /\[ACTIVE_ARTIFACT\]/, prefix
    assert_match /THIS IS THE PRD CONTENT/, prefix
    refute_match /Implement Login/, prefix # Coordinator only gets PRD
  end

  test "build_prefix includes PRD and Technical Plan for CWA when sap_run_id is provided" do
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "cwa", @sap_run.id)

    assert_match /\[ACTIVE_ARTIFACT\]/, prefix
    assert_match /THIS IS THE PRD CONTENT/, prefix
    assert_match /Implement Login/, prefix # CWA gets both
  end

  test "build_prefix does not include artifact context if sap_run_id is missing" do
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "coordinator")

    refute_match /\[ACTIVE_ARTIFACT\]/, prefix
    refute_match /THIS IS THE PRD CONTENT/, prefix
  end

  test "build_prefix does not include artifact context if sap_run has no artifact" do
    @sap_run.update!(artifact_id: nil)
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "coordinator", @sap_run.id)

    refute_match /\[ACTIVE_ARTIFACT\]/, prefix
  end
end
