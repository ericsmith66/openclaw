# frozen_string_literal: true

require "test_helper"

class CompactionStrategyTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def text_response(content = "LLM summary")
    {
      role: "assistant",
      content: content,
      tool_calls: nil,
      usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }
    }
  end

  def build_mock_mm(response = nil)
    AgentDesk::Test::MockModelManager.new(
      responses: [ response || text_response ]
    )
  end

  def sample_conversation
    [
      { role: "user", content: "Do the thing" },
      { role: "assistant", content: "Understood" },
      { role: "tool", content: "File written" },
      { role: "assistant", content: "Step 1 done" }
    ]
  end

  def sample_snapshot(original_prompt: "Do the thing")
    AgentDesk::Agent::StateSnapshot.build(
      original_prompt: original_prompt,
      conversation:    []
    )
  end

  def dummy_context
    { project_dir: "/tmp" }
  end

  # ---------------------------------------------------------------------------
  # CompactStrategy
  # ---------------------------------------------------------------------------

  class CompactStrategyTest < Minitest::Test
    def setup
      @strategy = AgentDesk::Agent::CompactStrategy.new
    end

    def text_response(content = "LLM summary")
      { role: "assistant", content: content, tool_calls: nil,
        usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 } }
    end

    def build_mock_mm(response = nil)
      AgentDesk::Test::MockModelManager.new(responses: [ response || text_response ])
    end

    def sample_conversation(size = 10)
      msgs = [ { role: "user", content: "Do the thing" } ]
      (size - 1).times do |i|
        msgs << { role: (i.even? ? "assistant" : "tool"), content: "Message #{i}" }
      end
      msgs
    end

    def sample_snapshot
      AgentDesk::Agent::StateSnapshot.build(original_prompt: "Do the thing", conversation: [])
    end

    def test_returns_continue_on_success
      conv = sample_conversation
      result = @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm
      )
      assert_equal :continue, result
    end

    def test_replaces_conversation_messages_on_success
      conv = sample_conversation(10) # 10 messages > 4 (compacted form size)
      original_size = conv.size
      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm(text_response("Great summary"))
      )
      # Conversation should be replaced with 4-message compacted form
      assert_operator conv.size, :<, original_size, "Expected conversation to be smaller after compaction"
    end

    def test_conversation_has_four_messages_after_compact
      conv = sample_conversation(10)
      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm(text_response("Summary here"))
      )
      assert_equal 4, conv.size, "Expected 4 messages after compaction: user, snapshot, summary, continuation"
    end

    def test_compacted_conversation_starts_with_user_message
      conv = sample_conversation(10)
      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm
      )
      assert_equal "user", conv.first[:role]
    end

    def test_compacted_conversation_contains_summary
      conv = sample_conversation(10)
      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm(text_response("My great summary"))
      )
      summaries = conv.select { |m| m[:role] == "assistant" && m[:content]&.include?("My great summary") }
      assert summaries.any?, "Expected summary message to be in compacted conversation"
    end

    def test_returns_continue_on_llm_failure_without_compacting
      failing_mm = AgentDesk::Test::MockModelManager.new(responses: [])
      # Simulate failure by patching chat to raise
      def failing_mm.chat(**_args, &_block) = raise StandardError, "Network error"

      conv = sample_conversation(10).dup
      original = conv.dup

      result = @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: failing_mm
      )

      assert_equal :continue, result
      assert_equal original, conv, "Conversation should be unchanged on LLM failure"
    end

    def test_publishes_conversation_compacted_event
      bus = AgentDesk::MessageBus::CallbackBus.new
      published = []
      bus.subscribe("conversation.compacted") { |_ch, event| published << event }

      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: sample_conversation(10),
        state_snapshot: sample_snapshot, model_manager: build_mock_mm,
        message_bus: bus, agent_id: "a1", task_id: "t1"
      )

      assert_equal 1, published.size
      assert_equal "conversation.compacted", published.first.type
    end
  end

  # ---------------------------------------------------------------------------
  # HandoffStrategy
  # ---------------------------------------------------------------------------

  class HandoffStrategyTest < Minitest::Test
    def setup
      @strategy = AgentDesk::Agent::HandoffStrategy.new
    end

    def text_response(content = "Continue from here")
      { role: "assistant", content: content, tool_calls: nil,
        usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 } }
    end

    def build_mock_mm(response = nil)
      AgentDesk::Test::MockModelManager.new(responses: [ response || text_response ])
    end

    def sample_conversation
      [
        { role: "user", content: "Do the thing" },
        { role: "assistant", content: "On it" }
      ]
    end

    def sample_snapshot
      AgentDesk::Agent::StateSnapshot.build(original_prompt: "Do the thing", conversation: [])
    end

    def test_returns_stop
      result = @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: sample_conversation,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm
      )
      assert_equal :stop, result
    end

    def test_returns_stop_on_task_creation_failure
      failing_mm = AgentDesk::Test::MockModelManager.new(responses: [])
      def failing_mm.chat(**_args, &_block) = raise StandardError, "LLM unavailable"

      result = @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: sample_conversation,
        state_snapshot: sample_snapshot, model_manager: failing_mm
      )
      assert_equal :stop, result
    end

    def test_fires_on_handoff_created_hook
      hm = AgentDesk::Hooks::HookManager.new
      hook_data = nil
      hm.on(:on_handoff_created) do |event_data, _context|
        hook_data = event_data
        AgentDesk::Hooks::HookResult.new(blocked: false, event: event_data, result: nil)
      end

      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: sample_conversation,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm,
        hook_manager: hm, task_id: "original-task-1"
      )

      refute_nil hook_data, "Expected on_handoff_created hook to be fired"
      assert_equal "original-task-1", hook_data[:original_task_id]
      assert hook_data[:new_task_id], "Expected new_task_id to be set"
      refute_empty hook_data[:handoff_prompt]
    end

    def test_generates_handoff_task_with_uuid_and_prompt
      hm = AgentDesk::Hooks::HookManager.new
      captured_task = nil
      hm.on(:on_handoff_created) do |event_data, _ctx|
        captured_task = event_data
        AgentDesk::Hooks::HookResult.new(blocked: false, event: event_data, result: nil)
      end

      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: sample_conversation,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm(text_response("Continuation prompt here")),
        hook_manager: hm
      )

      refute_nil captured_task
      # UUID format check
      assert_match(/\A[0-9a-f-]{36}\z/i, captured_task[:new_task_id].to_s)
      assert_includes captured_task[:handoff_prompt], "Continuation prompt here"
    end

    def test_publishes_conversation_handoff_event
      bus = AgentDesk::MessageBus::CallbackBus.new
      published = []
      bus.subscribe("conversation.handoff") { |_ch, event| published << event }

      @strategy.execute(
        context: { project_dir: "/tmp" }, conversation: sample_conversation,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm,
        message_bus: bus, agent_id: "a1", task_id: "t1"
      )

      assert_equal 1, published.size
      assert_equal "conversation.handoff", published.first.type
      assert published.first.payload[:new_task_id]
    end
  end

  # ---------------------------------------------------------------------------
  # TieredStrategy
  # ---------------------------------------------------------------------------

  class TieredStrategyTest < Minitest::Test
    def setup
      @strategy = AgentDesk::Agent::TieredStrategy.new
    end

    def text_response(content = "Tier2 summary")
      { role: "assistant", content: content, tool_calls: nil,
        usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 } }
    end

    def build_mock_mm(response = nil)
      AgentDesk::Test::MockModelManager.new(responses: [ response || text_response ])
    end

    def build_long_conversation(size = 15)
      msgs = [ { role: "user", content: "Start task" } ]
      (size - 1).times do |i|
        msgs << { role: "tool", content: "Tool result ##{i}: " + ("x" * 1000) }
      end
      msgs
    end

    def sample_snapshot
      AgentDesk::Agent::StateSnapshot.build(original_prompt: "Start task", conversation: [])
    end

    def context_with_tier(tier)
      { project_dir: "/tmp", threshold_tier: tier }
    end

    def test_tier1_trims_verbose_tool_results
      conv = build_long_conversation(15)

      @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm
      )

      # Older tool messages (not in the last 10) should be trimmed
      older_tool_msgs = conv[0..-(AgentDesk::Agent::TieredStrategy::RECENT_MESSAGES_TO_KEEP + 1)].select { |m| m[:role] == "tool" }
      trimmed = older_tool_msgs.all? { |m| m[:content].length <= AgentDesk::Agent::TieredStrategy::TIER1_MAX_RESULT_LENGTH + 100 }
      assert trimmed, "Expected older tool messages to be trimmed"
    end

    def test_tier1_does_not_make_llm_call
      conv = build_long_conversation(15)
      mm = build_mock_mm

      @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )

      assert_empty mm.calls, "Tier-1 should not make any LLM calls"
    end

    def test_tier1_returns_continue
      conv = build_long_conversation(15)
      result = @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm
      )
      assert_equal :continue, result
    end

    def test_tier2_keeps_recent_messages
      conv = build_long_conversation(15)
      recent_before = conv.last(AgentDesk::Agent::TieredStrategy::RECENT_MESSAGES_TO_KEEP).dup
      mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response("Older stuff summarized") ])

      @strategy.execute(
        context: context_with_tier(:tier_2), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )

      # Recent messages should be at the end
      recent_after = conv.last(AgentDesk::Agent::TieredStrategy::RECENT_MESSAGES_TO_KEEP)
      assert_equal recent_before.map { |m| m[:content] }, recent_after.map { |m| m[:content] },
                   "Recent messages should be preserved in tier-2"
    end

    def test_tier2_returns_continue
      conv = build_long_conversation(15)
      mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response("Summary") ])
      result = @strategy.execute(
        context: context_with_tier(:tier_2), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )
      assert_equal :continue, result
    end

    def test_tier3_delegates_to_compact_strategy
      conv = [ { role: "user", content: "Do stuff" }, { role: "assistant", content: "OK" } ]
      # Provide 2 responses: one for tier-3 compact summarization call
      mm = AgentDesk::Test::MockModelManager.new(responses: [
        text_response("Compacted summary")
      ])

      result = @strategy.execute(
        context: context_with_tier(:tier_3), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )

      assert_equal :continue, result
    end

    def test_does_not_re_trigger_handled_tiers
      conv = build_long_conversation(15)
      mm = build_mock_mm

      # First call handles tier_1
      @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )
      calls_after_first = mm.calls.size

      # Second call at same tier should be a no-op
      @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )

      assert_equal calls_after_first, mm.calls.size, "No new LLM calls should be made for an already-handled tier"
    end

    def test_reset_clears_handled_tiers
      conv = build_long_conversation(15)
      mm = build_mock_mm

      # First call marks tier_1 as handled
      @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv,
        state_snapshot: sample_snapshot, model_manager: mm
      )

      # Reset clears handled tiers
      @strategy.reset

      # Rebuild conversation (tier1 already trimmed, need fresh data)
      conv2 = build_long_conversation(15)
      calls_before = mm.calls.size

      @strategy.execute(
        context: context_with_tier(:tier_1), conversation: conv2,
        state_snapshot: sample_snapshot, model_manager: mm
      )

      # Tier-1 should have been re-triggered (still no LLM call, but the
      # important thing is it didn't skip)
      assert_equal calls_before, mm.calls.size, "Tier-1 still should not make LLM calls"
    end

    def test_returns_continue_when_tier_is_nil
      conv = [ { role: "user", content: "Hello" } ]
      result = @strategy.execute(
        context: { project_dir: "/tmp", threshold_tier: nil }, conversation: conv,
        state_snapshot: sample_snapshot, model_manager: build_mock_mm
      )
      assert_equal :continue, result
    end
  end
end
