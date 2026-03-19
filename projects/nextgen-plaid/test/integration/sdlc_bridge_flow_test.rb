require "test_helper"

class SdlcBridgeFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "sdlc_test_#{rand(1000)}@example.com", password: "password")
    sign_in @user, scope: :user

    @artifact = Artifact.create!(
      name: "Test SDLC Flow",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP",
      payload: { "content" => "Initial PRD content" }
    )

    # Create a conversation and link it
    @sap_run = SapRun.create_conversation(user_id: @user.id, persona_id: "sap")
    @sap_run.update!(artifact_id: @artifact.id)
  end

  test "Full SDLC RAG Context Flow" do
    # Phase 1: Backlog (SAP)
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap", @sap_run.id)
    @sap_run.reload
    rag_id = @sap_run.output_json["last_rag_request_id"]
    assert rag_id.present?
    assert_match /--- BACKLOG/, prefix
    assert_match /Test SDLC Flow/, prefix
    assert_match /Initial PRD content/, prefix

    # Transition to Ready for Analysis
    @artifact.transition_to("approve", "SAP", rag_request_id: rag_id)
    assert_equal "ready_for_analysis", @artifact.phase
    assert_equal rag_id, @artifact.payload["audit_trail"].last["rag_request_id"]

    # Transition to In Analysis (Coordinator takes over)
    @artifact.transition_to("approve", "SAP")
    assert_equal "in_analysis", @artifact.phase
    assert_equal "Coordinator", @artifact.owner_persona

    # Phase 2: In Analysis (Coordinator)
    # Coordinator should see the PRD in [ACTIVE_ARTIFACT]
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "coordinator", @sap_run.id)
    @sap_run.reload
    new_rag_id = @sap_run.output_json["last_rag_request_id"]
    assert_not_equal rag_id, new_rag_id

    assert_match /\[ACTIVE_ARTIFACT\]/, prefix
    assert_match /Initial PRD content/, prefix
    assert_match /TECHNICAL PLAN/, prefix # Now visible to Coordinator
    assert_match /No structured technical tasks defined/, prefix

    # Transition to Planning
    @artifact.transition_to("approve", "Coordinator", rag_request_id: new_rag_id)
    assert_equal "planning", @artifact.phase
    assert_equal new_rag_id, @artifact.payload["audit_trail"].last["rag_request_id"]

    # Add Technical Plan (simulating agent/human update)
    @artifact.payload["micro_tasks"] = [
      { "id" => "T1", "title" => "Implement Webhook", "estimate" => "2h" }
    ]
    @artifact.save!

    # Transition to Ready for Development (CWA)
    @artifact.transition_to("approve", "SAP")
    assert_equal "ready_for_development", @artifact.phase

    # Transition to In Development (CWA)
    @artifact.transition_to("approve", "CWA")
    assert_equal "in_development", @artifact.phase
    assert_equal "CWA", @artifact.owner_persona

    # Phase 3: In Development (CWA)
    # CWA should see BOTH PRD and Technical Plan
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "cwa", @sap_run.id)
    assert_match /\[ACTIVE_ARTIFACT\]/, prefix
    assert_match /Initial PRD content/, prefix
    assert_match /TECHNICAL PLAN \(Micro-tasks\)/, prefix
    assert_match /Implement Webhook/, prefix
  end

  test "RAG Truncation Warning" do
    # Create a very large PRD
    large_content = "A" * 5000
    @artifact.update!(payload: { "content" => large_content })

    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap", @sap_run.id)

    assert prefix.length <= 4100 # MAX_CONTEXT_CHARS is 4000 + buffer for message
    assert_match /\[TRUNCATED due to length limits\]/, prefix
  end

  test "Anonymization in RAG payload" do
    Snapshot.create!(user: @user, data: {
      accounts: [ { name: "Checking", balance: 9999.99, account_number: "123456789" } ]
    })

    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap", @sap_run.id)

    assert_match /\[REDACTED\]/, prefix
    refute_match /9999.99/, prefix
    refute_match /123456789/, prefix
  end
end
