# frozen_string_literal: true

require "test_helper"

class ConversationCompactorContractTest < Minitest::Test
  def build_mock_mm(content = "Summary text")
    AgentDesk::Test::MockModelManager.new(
      responses: [
        { role: "assistant", content: content, tool_calls: nil,
          usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 } }
      ]
    )
  end

  def sample_conversation
    # Use 8 messages so compacted form (4 messages) is smaller
    msgs = [ { role: "user", content: "Original user request" } ]
    7.times { |i| msgs << { role: (i.even? ? "assistant" : "tool"), content: "Step #{i} complete" } }
    msgs
  end

  def sample_snapshot(conversation = [])
    AgentDesk::Agent::StateSnapshot.build(
      original_prompt: "Original user request",
      conversation:    conversation
    )
  end

  def test_compacts_conversation
    strategy = AgentDesk::Agent::CompactStrategy.new
    conv = sample_conversation.dup
    original_size = conv.size

    strategy.execute(
      context: { project_dir: "/tmp" }, conversation: conv,
      state_snapshot: sample_snapshot, model_manager: build_mock_mm("Compact summary")
    )

    # Conversation should be replaced (compacted form is smaller)
    refute_equal original_size, conv.size, "Expected conversation to be compacted"
  end

  def test_preserves_critical_messages
    strategy = AgentDesk::Agent::CompactStrategy.new
    conv = sample_conversation.dup

    strategy.execute(
      context: { project_dir: "/tmp" }, conversation: conv,
      state_snapshot: sample_snapshot, model_manager: build_mock_mm
    )

    # The original user message must be preserved
    user_messages = conv.select { |m| m[:role] == "user" }
    assert user_messages.any?, "Expected at least one user message to be preserved"
    assert user_messages.first[:content].include?("Original user request"),
           "Expected original user request to be preserved"
  end
end
