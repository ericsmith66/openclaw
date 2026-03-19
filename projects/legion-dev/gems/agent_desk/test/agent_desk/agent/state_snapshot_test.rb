# frozen_string_literal: true

require "test_helper"
require "benchmark"

class StateSnapshotTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_snapshot(**opts)
    AgentDesk::Agent::StateSnapshot.build(
      original_prompt: opts.fetch(:original_prompt, "Do the thing"),
      conversation:    opts.fetch(:conversation, []),
      **opts.except(:original_prompt, :conversation)
    )
  end

  # ---------------------------------------------------------------------------
  # Build factory
  # ---------------------------------------------------------------------------

  def test_captures_original_prompt
    snapshot = build_snapshot(original_prompt: "My original request")
    assert_equal "My original request", snapshot.original_prompt
  end

  def test_todo_items_default_to_empty_array
    snapshot = build_snapshot
    assert_equal [], snapshot.todo_items
  end

  def test_files_modified_default_to_empty_array
    snapshot = build_snapshot
    assert_equal [], snapshot.files_modified
  end

  def test_key_decisions_default_to_empty_array
    snapshot = build_snapshot
    assert_equal [], snapshot.key_decisions
  end

  def test_custom_data_defaults_to_empty_hash
    snapshot = build_snapshot
    assert_equal({}, snapshot.custom_data)
  end

  def test_build_factory_with_custom_fields
    snapshot = build_snapshot(
      original_prompt:        "Build it",
      todo_items:             [ { name: "Step 1", completed: false } ],
      files_modified:         [ "app/models/user.rb" ],
      key_decisions:          [ "Use service objects" ],
      tool_approvals_granted: [ "power---bash" ],
      current_step:           "Writing tests",
      remaining_work:         "Finish migrations",
      custom_data:            { run_id: "abc123" }
    )

    assert_equal "Build it",                             snapshot.original_prompt
    assert_equal [ { name: "Step 1", completed: false } ], snapshot.todo_items
    assert_equal [ "app/models/user.rb" ],              snapshot.files_modified
    assert_equal [ "Use service objects" ],             snapshot.key_decisions
    assert_equal [ "power---bash" ],                    snapshot.tool_approvals_granted
    assert_equal "Writing tests",                       snapshot.current_step
    assert_equal "Finish migrations",                   snapshot.remaining_work
    assert_equal({ run_id: "abc123" },                  snapshot.custom_data)
  end

  # ---------------------------------------------------------------------------
  # JSON serialization
  # ---------------------------------------------------------------------------

  def test_serializes_to_json_and_back
    snapshot = build_snapshot(
      original_prompt: "Test prompt",
      todo_items:      [ { name: "Task 1", completed: true } ],
      files_modified:  [ "lib/foo.rb" ],
      custom_data:     { key: "value" }
    )

    json = snapshot.to_json_str
    assert_kind_of String, json
    refute_empty json

    restored = AgentDesk::Agent::StateSnapshot.from_json_str(json)
    assert_equal snapshot.original_prompt, restored.original_prompt
    assert_equal snapshot.files_modified,  restored.files_modified
  end

  def test_json_roundtrip_preserves_custom_data
    snapshot = build_snapshot(custom_data: { "run_id" => "xyz789", "tier" => 2 })
    restored = AgentDesk::Agent::StateSnapshot.from_json_str(snapshot.to_json_str)
    assert_equal "xyz789", restored.custom_data[:run_id]
  end

  def test_empty_state_is_valid
    snapshot = build_snapshot(original_prompt: "")
    json = snapshot.to_json_str
    restored = AgentDesk::Agent::StateSnapshot.from_json_str(json)
    assert_equal [], restored.todo_items
    assert_equal [], restored.files_modified
    assert_equal({}, restored.custom_data)
  end

  def test_serialization_under_10ms_for_100_items
    items = 100.times.map { |i| { name: "Todo item #{i}", completed: i.even? } }
    snapshot = build_snapshot(todo_items: items)

    elapsed = Benchmark.realtime { snapshot.to_json_str }
    assert elapsed < 0.01, "Serialization took #{(elapsed * 1000).round(2)}ms (expected < 10ms)"
  end

  # ---------------------------------------------------------------------------
  # to_context_message
  # ---------------------------------------------------------------------------

  def test_to_context_message_returns_assistant_role
    snapshot = build_snapshot
    msg = snapshot.to_context_message
    assert_equal "assistant", msg[:role]
    assert_kind_of String, msg[:content]
  end

  def test_to_context_message_includes_original_prompt
    snapshot = build_snapshot(original_prompt: "Deploy the app")
    assert_includes snapshot.to_context_message[:content], "Deploy the app"
  end

  def test_to_context_message_includes_todo_items
    items = [ { name: "Write tests", completed: false }, { name: "Review PR", completed: true } ]
    snapshot = build_snapshot(todo_items: items)
    content = snapshot.to_context_message[:content]
    assert_includes content, "Write tests"
    assert_includes content, "Review PR"
  end

  def test_to_context_message_includes_files_modified
    snapshot = build_snapshot(files_modified: [ "app/models/user.rb", "db/schema.rb" ])
    content = snapshot.to_context_message[:content]
    assert_includes content, "app/models/user.rb"
  end

  def test_to_context_message_includes_files_in_context
    snapshot = build_snapshot(files_in_context: [ "app/services/payment.rb", "config/routes.rb" ])
    content = snapshot.to_context_message[:content]
    assert_includes content, "app/services/payment.rb"
    assert_includes content, "Files In Context"
  end

  def test_to_context_message_includes_memory_retrievals
    snapshot = build_snapshot(memory_retrievals: [ "User prefers Tailwind CSS", "Project uses Minitest" ])
    content = snapshot.to_context_message[:content]
    assert_includes content, "User prefers Tailwind CSS"
    assert_includes content, "Memory Retrievals"
  end

  # ---------------------------------------------------------------------------
  # Conversation extraction
  # ---------------------------------------------------------------------------

  def test_extracts_files_modified_from_tool_messages
    conversation = [
      { role: "tool", content: "File 'app/controllers/users_controller.rb' has been written successfully." },
      { role: "assistant", content: "Done" }
    ]
    snapshot = build_snapshot(conversation: conversation)
    assert_includes snapshot.files_modified, "app/controllers/users_controller.rb"
  end

  def test_conversation_extraction_ignores_non_tool_messages
    conversation = [
      { role: "user", content: "Create app/models/post.rb" },
      { role: "assistant", content: "Sure, I'll create that file." }
    ]
    snapshot = build_snapshot(conversation: conversation)
    # Non-tool messages should not produce file modifications
    assert_equal [], snapshot.files_modified
  end
end
