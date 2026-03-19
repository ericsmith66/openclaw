require "test_helper"

class AgentHub::MentionParserTest < ActiveSupport::TestCase
  test "extracts SAP mention" do
    result = AgentHub::MentionParser.call("@SAP what is the plan?")
    assert_equal "sap-agent", result[:agent_id]
    assert_equal "sap", result[:mention]
    assert_equal "what is the plan?", result[:clean_content]
  end

  test "extracts Conductor mention" do
    result = AgentHub::MentionParser.call("Hello @Conductor")
    assert_equal "conductor-agent", result[:agent_id]
    assert_equal "conductor", result[:mention]
    assert_equal "Hello", result[:clean_content]
  end

  test "returns nil for invalid mention" do
    assert_nil AgentHub::MentionParser.call("@Unknown person")
  end

  test "returns nil for no mention" do
    assert_nil AgentHub::MentionParser.call("Just a message")
  end
end
