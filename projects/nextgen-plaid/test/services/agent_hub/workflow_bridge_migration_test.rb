require "test_helper"

class AgentHub::WorkflowBridgeMigrationTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "migration_test_#{rand(1000)}@example.com", password: "password")
    @artifact = Artifact.create!(
      name: "Migration Artifact",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP"
    )
    @sap_run = SapRun.create_conversation(user_id: @user.id, persona_id: "sap")
    @sap_run.update!(artifact_id: @artifact.id)
  end

  test "Happy Path: Transition from Backlog to Ready for Analysis via Bridge" do
    assert_equal "backlog", @artifact.phase

    # Execute transition via Bridge
    AgentHub::WorkflowBridge.execute_transition(
      artifact_id: @artifact.id,
      command: "approve",
      user: @user,
      agent_id: "sap"
    )

    @artifact.reload
    assert_equal "ready_for_analysis", @artifact.phase
    assert_equal "SAP", @artifact.owner_persona

    # Verify side effects: System Message created in SapRun
    assert_equal "[SYSTEM: Phase changed to Ready For Analysis]", @sap_run.sap_messages.last.content
  end

  test "Creates artifact if missing on approve" do
    # Destroy existing artifacts
    Artifact.destroy_all
    @sap_run.update!(artifact_id: nil)
    @sap_run.sap_messages.create!(role: :assistant, content: "Let's build a login page.")

    AgentHub::WorkflowBridge.execute_transition(
      command: "approve",
      user: @user,
      agent_id: "sap"
    )

    artifact = Artifact.last
    assert_not_nil artifact
    assert_equal "ready_for_analysis", artifact.phase
    assert_equal "SAP", artifact.owner_persona
    assert_equal "Let's build a login page.", artifact.payload["content"]

    @sap_run.reload
    assert_equal artifact.id, @sap_run.artifact_id
  end
end
