require "test_helper"

class AgentHub::WorkflowBridgeTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "bridge_test_#{rand(1000)}@example.com", password: "password")
    @sap_run = SapRun.create_conversation(user_id: @user.id, persona_id: "sap")
    @artifact = Artifact.create!(
      name: "Bridge Artifact",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP"
    )
  end

  test "parses valid intent tags" do
    content = "I have finished the PRD. [ACTION: APPROVE_PRD: #{@artifact.id}]"
    intents = AgentHub::WorkflowBridge.parse(content, role: "assistant", conversation: @sap_run)

    assert_equal 1, intents.size
    assert_equal "APPROVE_PRD", intents.first[:intent]
    assert_equal @artifact.id.to_s, intents.first[:id]
    assert_equal "Finalize PRD", intents.first[:config][:label]
  end

  test "parses new descriptive intents" do
    content = "[ACTION: FINALIZE_PRD: 1], [ACTION: APPROVE_PLAN: 2], [ACTION: START_IMPLEMENTATION: 3], [ACTION: SAVE_TO_BACKLOG: 4]"
    intents = AgentHub::WorkflowBridge.parse(content, role: "assistant")

    assert_equal 4, intents.size
    assert_equal "Finalize PRD", intents.find { |i| i[:intent] == "FINALIZE_PRD" }[:config][:label]
    assert_equal "Approve Plan", intents.find { |i| i[:intent] == "APPROVE_PLAN" }[:config][:label]
    assert_equal "Start Implementation", intents.find { |i| i[:intent] == "START_IMPLEMENTATION" }[:config][:label]
    assert_equal "Save to Backlog", intents.find { |i| i[:intent] == "SAVE_TO_BACKLOG" }[:config][:label]
  end

  test "links conversation to artifact_id" do
    content = "Linking this run to artifact. [ACTION: MOVE_TO_ANALYSIS: #{@artifact.id}]"
    AgentHub::WorkflowBridge.parse(content, role: "assistant", conversation: @sap_run)

    @sap_run.reload
    assert_equal @artifact.id, @sap_run.artifact_id
  end

  test "ignores tags from non-assistant roles" do
    content = "[ACTION: MOVE_TO_ANALYSIS: #{@artifact.id}]"
    intents = AgentHub::WorkflowBridge.parse(content, role: "user")

    assert_empty intents
  end

  test "ignores unknown intents" do
    content = "[ACTION: UNKNOWN_INTENT: 123]"
    intents = AgentHub::WorkflowBridge.parse(content, role: "assistant")

    assert_empty intents
  end

  test "parses multiple intents" do
    content = "[ACTION: APPROVE_PRD: 1] and [ACTION: REJECT: 2]"
    intents = AgentHub::WorkflowBridge.parse(content, role: "assistant")

    assert_equal 2, intents.size
    assert_equal "APPROVE_PRD", intents[0][:intent]
    assert_equal "REJECT", intents[1][:intent]
  end

  test "parses intent tags without brackets (robustness)" do
    content = "ACTION: MOVE_TO_ANALYSIS: #{@artifact.id} --- BACKLOG"
    intents = AgentHub::WorkflowBridge.parse(content, role: "assistant", conversation: @sap_run)

    assert_equal 1, intents.size
    assert_equal "MOVE_TO_ANALYSIS", intents.first[:intent]
    assert_equal @artifact.id.to_s, intents.first[:id]
  end

  test "parses intent tags with leading and trailing noise" do
    content = "OK. ACTION: APPROVE_PRD: #{@artifact.id}. Let me know."
    intents = AgentHub::WorkflowBridge.parse(content, role: "assistant")

    assert_equal 1, intents.size
    assert_equal "APPROVE_PRD", intents.first[:intent]
  end
end
