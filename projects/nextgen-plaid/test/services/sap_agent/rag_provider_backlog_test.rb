require "test_helper"

class SapAgent::RagProviderBacklogTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    Artifact.destroy_all
    @backlog_item = Artifact.create!(
      name: "Backlog Item 1",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP"
    )
  end

  test "includes backlog items for SAP persona" do
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap")

    assert_match /--- BACKLOG \(Total: 1\) ---/, prefix
    assert_match /ID: #{@backlog_item.id} \| Name: Backlog Item 1/, prefix
    assert_match /To move an item forward, you MUST include this tag in your response: \[ACTION: <INTENT>: ID\]/, prefix
    assert_match /Valid intents: MOVE_TO_ANALYSIS, APPROVE_PRD/, prefix
  end

  test "includes ready_for_analysis items for SAP persona" do
    @backlog_item.update!(phase: "ready_for_analysis")
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap")

    assert_match /--- BACKLOG \(Total: 1\) ---/, prefix
    assert_match /ID: #{@backlog_item.id} \| Name: Backlog Item 1/, prefix
    assert_match /Phase: Ready for analysis/, prefix
  end

  test "includes backlog items for sap-agent persona ID" do
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap-agent")

    assert_match /--- BACKLOG \(Total: 1\) ---/, prefix
    assert_match /ID: #{@backlog_item.id} \| Name: Backlog Item 1/, prefix
  end

  test "includes assigned items for Coordinator persona" do
    @backlog_item.update!(owner_persona: "Coordinator", phase: "in_analysis")
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "coordinator")

    assert_match /--- ASSIGNED ARTIFACTS \(Total: 1\) ---/, prefix
    assert_match /ID: #{@backlog_item.id} \| Name: Backlog Item 1/, prefix
    assert_match /Phase: In analysis/, prefix
  end

  test "does not include items for non-authorized personas" do
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "unknown_persona")

    refute_match /--- BACKLOG/, prefix
    refute_match /--- ASSIGNED ARTIFACTS/, prefix
    assert_match /No backlog data available for this persona/, prefix
  end

  test "includes assigned items for CWA persona" do
    @backlog_item.update!(owner_persona: "CWA", phase: "ready_for_development")
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "cwa")

    assert_match /--- ASSIGNED ARTIFACTS \(Total: 1\) ---/, prefix
    assert_match /ID: #{@backlog_item.id} \| Name: Backlog Item 1/, prefix
    assert_match /Phase: Ready for development/, prefix
  end

  test "handles empty backlog" do
    Artifact.destroy_all
    prefix = SapAgent::RagProvider.build_prefix("default", @user.id, "sap")

    assert_match /--- BACKLOG ---\nNo items found./, prefix
  end
end
