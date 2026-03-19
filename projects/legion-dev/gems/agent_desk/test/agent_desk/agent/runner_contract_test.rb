# frozen_string_literal: true

require "test_helper"

# Contract tests verifying AgentDesk::Agent::Runner's public interface.
#
# These tests use MockModelManager to avoid real HTTP calls while still
# asserting that the public API contract is satisfied.
class RunnerContractTest < Minitest::Test
  def setup
    @mock_mm = AgentDesk::Test::MockModelManager.new(responses: [
      {
        role: "assistant",
        content: "Contract response",
        tool_calls: nil,
        usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }
      }
    ])
    @runner = AgentDesk::Agent::Runner.new(model_manager: @mock_mm)
  end

  def test_run_returns_conversation_array
    result = @runner.run(prompt: "Hello", project_dir: "/tmp")
    assert_kind_of Array, result
    refute_empty result
    result.each { |msg| assert_kind_of Hash, msg }
  end

  def test_run_executes_tool_calls
    tool = AgentDesk::Tools::BaseTool.new(
      name: "bash",
      group_name: "power",
      description: "run shell"
    ) { |_args, context:| "contract_result" }
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(tool)

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [
      {
        role: "assistant",
        content: nil,
        tool_calls: [ { id: "c-1", function: { name: "power---bash", arguments: {} } } ],
        usage: { prompt_tokens: 5, completion_tokens: 5, total_tokens: 10 }
      },
      {
        role: "assistant",
        content: "Tool executed",
        tool_calls: nil,
        usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
      }
    ])
    runner = AgentDesk::Agent::Runner.new(model_manager: mock_mm)
    conv = runner.run(prompt: "Execute tool", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    refute_nil tool_msg, "Expected a tool result message in the conversation"
    assert_equal "contract_result", tool_msg[:content]
  end

  def test_run_streams_chunks_via_message_bus
    bus = AgentDesk::MessageBus::CallbackBus.new
    chunk_events = []
    bus.subscribe("*") { |_ch, ev| chunk_events << ev if ev.type == "response.chunk" }

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [
      {
        role: "assistant",
        content: "Streaming content here",
        tool_calls: nil,
        usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }
      }
    ])
    runner = AgentDesk::Agent::Runner.new(model_manager: mock_mm, message_bus: bus)
    runner.run(prompt: "Stream this", project_dir: "/tmp", agent_id: "c-agent", task_id: "c-task")

    # MockModelManager yields chunks when content is present
    assert chunk_events.size >= 1, "Expected at least one response.chunk event"
    chunk_events.each do |ev|
      assert_respond_to ev, :type
      assert_equal "response.chunk", ev.type
    end
  end

  def test_run_stops_at_max_iterations
    # Supply a mock that always returns tool_calls (would be infinite without limit)
    always_tool_responses = Array.new(10) do
      {
        role: "assistant",
        content: nil,
        tool_calls: [ { id: "c-2", function: { name: "power---nonexistent", arguments: {} } } ],
        usage: { prompt_tokens: 5, completion_tokens: 5, total_tokens: 10 }
      }
    end
    mock_mm = AgentDesk::Test::MockModelManager.new(responses: always_tool_responses)
    runner = AgentDesk::Agent::Runner.new(model_manager: mock_mm)
    conv = runner.run(prompt: "Loop", project_dir: "/tmp", max_iterations: 3)
    assert_equal 3, mock_mm.calls.size, "Runner should stop after max_iterations"
    assert_kind_of Array, conv
  end
end
