# frozen_string_literal: true

require "test_helper"

class RunnerTest < Minitest::Test
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def build_runner(responses: [], message_bus: nil, hook_manager: nil, approval_manager: nil)
    mock_mm = AgentDesk::Test::MockModelManager.new(responses: responses)
    runner = AgentDesk::Agent::Runner.new(
      model_manager:    mock_mm,
      message_bus:      message_bus,
      hook_manager:     hook_manager,
      approval_manager: approval_manager
    )
    [ runner, mock_mm ]
  end

  def text_response(content = "Done")
    {
      role: "assistant",
      content: content,
      tool_calls: nil,
      usage: { prompt_tokens: 5, completion_tokens: 10, total_tokens: 15 }
    }
  end

  def tool_call_response(tool_name, arguments = {}, id: "tc-1")
    {
      role: "assistant",
      content: nil,
      tool_calls: [ { id: id, function: { name: tool_name, arguments: arguments } } ],
      usage: { prompt_tokens: 8, completion_tokens: 12, total_tokens: 20 }
    }
  end

  def build_tool_set(*tools)
    ts = AgentDesk::Tools::ToolSet.new
    tools.each { |t| ts.add(t) }
    ts
  end

  def make_tool(name, group: "power", result: "ok")
    AgentDesk::Tools::BaseTool.new(
      name: name,
      group_name: group,
      description: "Test tool #{name}"
    ) { |_args, context:| result }
  end

  # ---------------------------------------------------------------------------
  # Constructor & basic accessors
  # ---------------------------------------------------------------------------

  def test_stores_model_manager
    runner, mock = build_runner
    assert_same mock, runner.model_manager
  end

  def test_stores_message_bus
    bus = AgentDesk::MessageBus::CallbackBus.new
    runner, _ = build_runner(message_bus: bus)
    assert_same bus, runner.message_bus
  end

  def test_stores_hook_manager
    hm = AgentDesk::Hooks::HookManager.new
    runner, _ = build_runner(hook_manager: hm)
    assert_same hm, runner.hook_manager
  end

  def test_stores_approval_manager
    am = AgentDesk::Tools::ApprovalManager.new(tool_approvals: {}, auto_approve: true)
    runner, _ = build_runner(approval_manager: am)
    assert_same am, runner.approval_manager
  end

  # ---------------------------------------------------------------------------
  # Conversation construction
  # ---------------------------------------------------------------------------

  def test_returns_conversation_array
    runner, _ = build_runner(responses: [ text_response ])
    result = runner.run(prompt: "Hello", project_dir: "/tmp")
    assert_kind_of Array, result
  end

  def test_initial_messages_contain_user_prompt
    runner, _ = build_runner(responses: [ text_response ])
    conv = runner.run(prompt: "Hello", project_dir: "/tmp")
    assert_equal "Hello", conv.find { |m| m[:role] == "user" }&.dig(:content)
  end

  def test_accepts_system_prompt
    runner, _ = build_runner(responses: [ text_response ])
    conv = runner.run(prompt: "Hi", project_dir: "/tmp", system_prompt: "You are helpful")
    assert_equal "system", conv.first[:role]
    assert_equal "You are helpful", conv.first[:content]
  end

  def test_system_prompt_precedes_user_message
    runner, _ = build_runner(responses: [ text_response ])
    conv = runner.run(prompt: "Hi", project_dir: "/tmp", system_prompt: "Be concise")
    roles = conv.map { |m| m[:role] }
    assert_equal [ "system", "user", "assistant" ], roles
  end

  def test_accepts_pre_existing_messages
    runner, _ = build_runner(responses: [ text_response ])
    prior = [ { role: "user", content: "Prior msg" }, { role: "assistant", content: "Prior reply" } ]
    conv = runner.run(prompt: "New prompt", project_dir: "/tmp", messages: prior)
    assert_equal "Prior msg", conv[0][:content]
    assert_equal "Prior reply", conv[1][:content]
    assert_equal "New prompt", conv[2][:content]
  end

  def test_final_assistant_message_appended
    runner, _ = build_runner(responses: [ text_response("Final answer") ])
    conv = runner.run(prompt: "Q", project_dir: "/tmp")
    assert_equal "Final answer", conv.last[:content]
    assert_equal "assistant", conv.last[:role]
  end

  # ---------------------------------------------------------------------------
  # Tool call processing
  # ---------------------------------------------------------------------------

  def test_tool_call_executes_and_loops
    tool = make_tool("bash", result: "file_list")
    ts = build_tool_set(tool)
    responses = [
      tool_call_response("power---bash", { "command" => "ls" }),
      text_response("Here are the files")
    ]
    runner, mock = build_runner(responses: responses)
    conv = runner.run(prompt: "List files", project_dir: "/tmp", tool_set: ts)

    # Should have called chat twice
    assert_equal 2, mock.calls.size
    # Final response is the text
    assert_equal "Here are the files", conv.last[:content]
  end

  def test_tool_result_added_to_conversation
    tool = make_tool("bash", result: "some_output")
    ts = build_tool_set(tool)
    responses = [
      tool_call_response("power---bash", {}),
      text_response
    ]
    runner, _ = build_runner(responses: responses)
    conv = runner.run(prompt: "Run it", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    refute_nil tool_msg
    assert_equal "some_output", tool_msg[:content]
    assert_equal "tc-1", tool_msg[:tool_call_id]
  end

  def test_multiple_tool_calls_in_one_response
    tool_a = make_tool("file_read", result: "content_a")
    tool_b = make_tool("file_write", result: "wrote_b")
    ts = build_tool_set(tool_a, tool_b)
    multi_tc_response = {
      role: "assistant",
      content: nil,
      tool_calls: [
        { id: "tc-1", function: { name: "power---file_read",  arguments: {} } },
        { id: "tc-2", function: { name: "power---file_write", arguments: {} } }
      ],
      usage: { prompt_tokens: 5, completion_tokens: 5, total_tokens: 10 }
    }
    runner, mock = build_runner(responses: [ multi_tc_response, text_response ])
    conv = runner.run(prompt: "Do both", project_dir: "/tmp", tool_set: ts)
    tool_msgs = conv.select { |m| m[:role] == "tool" }
    assert_equal 2, tool_msgs.size
    assert_equal "content_a", tool_msgs[0][:content]
    assert_equal "wrote_b",   tool_msgs[1][:content]
    assert_equal 2, mock.calls.size
  end

  def test_tool_call_passes_project_dir_in_context
    received_context = nil
    tool = AgentDesk::Tools::BaseTool.new(
      name: "bash",
      group_name: "power",
      description: "test"
    ) do |_args, context:|
      received_context = context
      "done"
    end
    ts = build_tool_set(tool)
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses)
    runner.run(prompt: "go", project_dir: "/my/project", tool_set: ts)
    assert_equal "/my/project", received_context&.dig(:project_dir)
  end

  # ---------------------------------------------------------------------------
  # Max iterations
  # ---------------------------------------------------------------------------

  def test_max_iterations_stops_loop
    # Always returns tool calls → would be infinite without max_iterations
    ts = build_tool_set(make_tool("bash", result: "loop"))
    # MockModelManager runs out after pre-configured responses; pad with enough
    responses = Array.new(5) { tool_call_response("power---bash") }
    runner, mock = build_runner(responses: responses)
    # Override default by setting max_iterations: 2
    runner.run(prompt: "loop", project_dir: "/tmp", tool_set: ts, max_iterations: 2)
    assert_equal 2, mock.calls.size
  end

  def test_max_iterations_returns_conversation_so_far
    ts = build_tool_set(make_tool("bash"))
    responses = Array.new(5) { tool_call_response("power---bash") }
    runner, _ = build_runner(responses: responses)
    conv = runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts, max_iterations: 2)
    assert_kind_of Array, conv
    assert conv.size > 1
  end

  # ---------------------------------------------------------------------------
  # Missing tool error
  # ---------------------------------------------------------------------------

  def test_missing_tool_returns_error_string
    known_tool = make_tool("glob")
    ts = build_tool_set(known_tool)
    responses = [
      tool_call_response("power---nonexistent"),
      text_response
    ]
    runner, _ = build_runner(responses: responses)
    conv = runner.run(prompt: "use it", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    refute_nil tool_msg
    assert_match(/Tool 'power---nonexistent' not found/, tool_msg[:content])
  end

  def test_missing_tool_error_lists_available_tools
    known_tool = make_tool("glob")
    ts = build_tool_set(known_tool)
    responses = [
      tool_call_response("power---unknown"),
      text_response
    ]
    runner, _ = build_runner(responses: responses)
    conv = runner.run(prompt: "use it", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    assert_match(/power---glob/, tool_msg[:content])
  end

  def test_missing_tool_does_not_crash
    ts = build_tool_set(make_tool("bash"))
    responses = [ tool_call_response("power---does-not-exist"), text_response ]
    runner, _ = build_runner(responses: responses)
    assert_silent { runner.run(prompt: "run", project_dir: "/tmp", tool_set: ts) }
  end

  # ---------------------------------------------------------------------------
  # Tool execution exception handling
  # ---------------------------------------------------------------------------

  def test_tool_execution_exception_caught
    bad_tool = AgentDesk::Tools::BaseTool.new(
      name: "bad",
      group_name: "power",
      description: "always fails"
    ) { |_args, context:| raise RuntimeError, "boom" }
    ts = build_tool_set(bad_tool)
    responses = [ tool_call_response("power---bad"), text_response ]
    runner, _ = build_runner(responses: responses)
    conv = runner.run(prompt: "break", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    refute_nil tool_msg
    assert_match(/Tool error: boom/, tool_msg[:content])
  end

  # ---------------------------------------------------------------------------
  # on_message callback
  # ---------------------------------------------------------------------------

  def test_on_message_fires_for_final_assistant_message
    fired = []
    runner, _ = build_runner(responses: [ text_response("Result") ])
    runner.run(prompt: "Q", project_dir: "/tmp", on_message: ->(msg) { fired << msg })
    assert_equal 1, fired.size
    assert_equal "Result", fired.first[:content]
    assert_equal "assistant", fired.first[:role]
  end

  def test_on_message_fires_for_tool_results
    tool = make_tool("bash", result: "shell_out")
    ts = build_tool_set(tool)
    responses = [ tool_call_response("power---bash"), text_response ]
    fired = []
    runner, _ = build_runner(responses: responses)
    runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts, on_message: ->(msg) { fired << msg })
    roles = fired.map { |m| m[:role] }
    assert_includes roles, "tool"
    assert_includes roles, "assistant"
  end

  def test_on_message_fires_for_assistant_tool_call_message
    tool = make_tool("bash")
    ts = build_tool_set(tool)
    responses = [ tool_call_response("power---bash"), text_response ]
    fired = []
    runner, _ = build_runner(responses: responses)
    runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts, on_message: ->(msg) { fired << msg })
    # First fired message should be the assistant message with tool_calls
    assert_equal "assistant", fired.first[:role]
    refute_nil fired.first[:tool_calls]
  end

  # ---------------------------------------------------------------------------
  # Hook manager integration
  # ---------------------------------------------------------------------------

  def test_on_agent_started_hook_blocks_run
    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_agent_started) do |_event_data, _context|
      AgentDesk::Hooks::HookResult.new(blocked: true)
    end
    runner, mock = build_runner(responses: [ text_response ], hook_manager: hm)
    conv = runner.run(prompt: "go", project_dir: "/tmp")
    # Should return early without calling the LLM
    assert_equal 0, mock.calls.size
    # Conversation only has user message (no assistant reply)
    assert_equal 1, conv.size
    assert_equal "user", conv.last[:role]
  end

  def test_on_tool_called_hook_blocks_tool
    tool = make_tool("bash", result: "should_not_run")
    ts = build_tool_set(tool)
    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_tool_called) do |_event_data, _context|
      AgentDesk::Hooks::HookResult.new(blocked: true)
    end
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses, hook_manager: hm)
    conv = runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    refute_nil tool_msg
    assert_equal "Tool execution blocked", tool_msg[:content]
  end

  def test_on_tool_finished_hook_fires
    tool = make_tool("bash", result: "done")
    ts = build_tool_set(tool)
    finished_events = []
    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_tool_finished) do |event_data, _context|
      finished_events << event_data
      nil
    end
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses, hook_manager: hm)
    runner.run(prompt: "run", project_dir: "/tmp", tool_set: ts)
    assert_equal 1, finished_events.size
    assert_equal "power---bash", finished_events.first[:tool_name]
  end

  def test_works_without_hooks
    runner, _ = build_runner(responses: [ text_response ])
    assert_silent { runner.run(prompt: "hi", project_dir: "/tmp") }
  end

  # ---------------------------------------------------------------------------
  # Approval manager integration
  # ---------------------------------------------------------------------------

  def test_approval_denial_returns_error_result
    tool = make_tool("bash", result: "never_runs")
    ts = build_tool_set(tool)
    am = AgentDesk::Tools::ApprovalManager.new(
      tool_approvals: { "power---bash" => AgentDesk::ToolApprovalState::NEVER }
    )
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses, approval_manager: am)
    conv = runner.run(prompt: "run", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    refute_nil tool_msg
    assert_match(/Tool execution denied/, tool_msg[:content])
  end

  def test_approval_allowed_executes_tool
    tool = make_tool("bash", result: "ran_ok")
    ts = build_tool_set(tool)
    am = AgentDesk::Tools::ApprovalManager.new(
      tool_approvals: { "power---bash" => AgentDesk::ToolApprovalState::ALWAYS }
    )
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses, approval_manager: am)
    conv = runner.run(prompt: "run", project_dir: "/tmp", tool_set: ts)
    tool_msg = conv.find { |m| m[:role] == "tool" }
    assert_equal "ran_ok", tool_msg[:content]
  end

  # ---------------------------------------------------------------------------
  # MessageBus event publishing
  # ---------------------------------------------------------------------------

  def test_publishes_agent_started_event
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    runner, _ = build_runner(responses: [ text_response ], message_bus: bus)
    runner.run(prompt: "start", project_dir: "/tmp", agent_id: "a1", task_id: "t1")
    types = published.map(&:type)
    assert_includes types, "agent.started"
  end

  def test_publishes_response_chunk_events
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    runner, _ = build_runner(responses: [ text_response("Hello world") ], message_bus: bus)
    runner.run(prompt: "hi", project_dir: "/tmp", agent_id: "a1", task_id: "t1")
    chunk_events = published.select { |ev| ev.type == "response.chunk" }
    # MockModelManager yields chunks when content is present
    assert chunk_events.size >= 1
  end

  def test_publishes_response_complete_event
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    runner, _ = build_runner(responses: [ text_response ], message_bus: bus)
    runner.run(prompt: "hi", project_dir: "/tmp", agent_id: "a1", task_id: "t1")
    types = published.map(&:type)
    assert_includes types, "response.complete"
  end

  def test_publishes_tool_called_event
    tool = make_tool("bash")
    ts = build_tool_set(tool)
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses, message_bus: bus)
    runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts, agent_id: "a1", task_id: "t1")
    types = published.map(&:type)
    assert_includes types, "tool.called"
  end

  def test_publishes_tool_result_event
    tool = make_tool("bash", result: "output")
    ts = build_tool_set(tool)
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    responses = [ tool_call_response("power---bash"), text_response ]
    runner, _ = build_runner(responses: responses, message_bus: bus)
    runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts, agent_id: "a1", task_id: "t1")
    types = published.map(&:type)
    assert_includes types, "tool.result"
  end

  def test_publishes_agent_completed_event
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    runner, _ = build_runner(responses: [ text_response ], message_bus: bus)
    runner.run(prompt: "done", project_dir: "/tmp", agent_id: "a1", task_id: "t1")
    completed_events = published.select { |ev| ev.type == "agent.completed" }
    assert_equal 1, completed_events.size
    assert_equal 1, completed_events.first.payload[:iterations]
  end

  def test_publishes_agent_completed_on_max_iterations
    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("*") { |_ch, ev| published << ev }
    ts = build_tool_set(make_tool("bash"))
    responses = Array.new(5) { tool_call_response("power---bash") }
    runner, _ = build_runner(responses: responses, message_bus: bus)
    runner.run(prompt: "loop", project_dir: "/tmp", tool_set: ts,
               max_iterations: 2, agent_id: "a1", task_id: "t1")
    completed_events = published.select { |ev| ev.type == "agent.completed" }
    assert_equal 1, completed_events.size
    assert_equal 2, completed_events.first.payload[:iterations]
  end

  def test_works_without_message_bus
    runner, _ = build_runner(responses: [ text_response ])
    result = nil
    assert_silent { result = runner.run(prompt: "hi", project_dir: "/tmp") }
    assert_kind_of Array, result
  end

  # ---------------------------------------------------------------------------
  # No tool set
  # ---------------------------------------------------------------------------

  def test_works_without_tool_set
    runner, mock = build_runner(responses: [ text_response ])
    runner.run(prompt: "no tools please", project_dir: "/tmp")
    assert_nil mock.calls.first[:tools]
  end

  # ---------------------------------------------------------------------------
  # Tool definitions wrapping (M4)
  # ---------------------------------------------------------------------------

  def test_tool_definitions_wrapped_with_function_type
    tool = make_tool("bash")
    ts = build_tool_set(tool)
    runner, mock = build_runner(responses: [ text_response ])
    runner.run(prompt: "go", project_dir: "/tmp", tool_set: ts)
    sent_tools = mock.calls.first[:tools]
    refute_nil sent_tools
    assert_equal 1, sent_tools.size
    assert_equal "function", sent_tools.first[:type]
    assert_kind_of Hash, sent_tools.first[:function]
    assert_equal "power---bash", sent_tools.first[:function][:name]
  end

  # ---------------------------------------------------------------------------
  # Multi-iteration tool loop (R1 recommendation)
  # ---------------------------------------------------------------------------

  def test_multi_iteration_tool_loop
    tool = make_tool("bash", result: "step_result")
    ts = build_tool_set(tool)
    responses = [
      tool_call_response("power---bash", {}, id: "tc-1"),
      tool_call_response("power---bash", {}, id: "tc-2"),
      text_response("All done")
    ]
    runner, mock = build_runner(responses: responses)
    conv = runner.run(prompt: "chain", project_dir: "/tmp", tool_set: ts)
    assert_equal 3, mock.calls.size
    assert_equal "All done", conv.last[:content]
    tool_msgs = conv.select { |m| m[:role] == "tool" }
    assert_equal 2, tool_msgs.size
  end

  # ---------------------------------------------------------------------------
  # Compaction integration (PRD-0092b)
  # ---------------------------------------------------------------------------

  def build_tracker(threshold: 80, context_window: 200_000, cost_budget: 0)
    AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: context_window,
      threshold: threshold,
      cost_budget: cost_budget
    )
  end

  def test_check_compaction_returns_continue_when_no_tracker
    runner, _ = build_runner(responses: [ text_response ])
    # No tracker → no compaction
    assert_equal :continue, runner.send(
      :check_compaction,
      conversation: [], agent_id: nil, task_id: nil, original_prompt: "Hi", context: {}
    )
  end

  def test_check_compaction_returns_continue_when_no_strategy
    tracker = build_tracker(threshold: 80)
    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker
      # no compaction_strategy
    )
    assert_equal :continue, runner.send(
      :check_compaction,
      conversation: [], agent_id: nil, task_id: nil, original_prompt: "Hi", context: {}
    )
  end

  def test_check_compaction_stops_on_cost_exceeded
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 200_000,
      threshold: 0,
      cost_budget: 0.01
    )
    # Record enough cost to exceed budget
    tracker.record(sent_tokens: 100, received_tokens: 50, message_cost: 0.05)

    # Use a mock strategy that returns :continue so the stop comes from cost check
    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      compaction_strategy:  strategy_obj
    )

    result = runner.send(
      :check_compaction,
      conversation: [], agent_id: nil, task_id: nil, original_prompt: "Hi", context: {}
    )
    assert_equal :stop, result
  end

  def test_check_compaction_fires_token_budget_warning_hook
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 100,
      threshold: 10  # very low threshold so 20 tokens crosses it
    )
    tracker.record(sent_tokens: 15, received_tokens: 5)

    warning_fired = false
    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_token_budget_warning) do |_data, _ctx|
      warning_fired = true
      AgentDesk::Hooks::HookResult.new(blocked: false, event: {}, result: nil)
    end

    # Strategy that returns continue
    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      hook_manager:         hm,
      compaction_strategy:  strategy_obj
    )

    runner.send(
      :check_compaction,
      conversation: [ { role: "user", content: "Hi" } ],
      agent_id: nil, task_id: nil, original_prompt: "Hi", context: {}
    )

    assert warning_fired, "Expected on_token_budget_warning hook to be fired"
  end

  def test_check_compaction_invokes_strategy_and_breaks_on_stop
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 100,
      threshold: 10
    )
    tracker.record(sent_tokens: 15, received_tokens: 5)

    strategy_called = false
    strategy_obj = Object.new
    strategy_obj.define_singleton_method(:execute) do |**_kwargs|
      strategy_called = true
      :stop
    end

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      compaction_strategy:  strategy_obj
    )

    result = runner.send(
      :check_compaction,
      conversation: [ { role: "user", content: "Hi" } ],
      agent_id: nil, task_id: nil, original_prompt: "Hi", context: {}
    )

    assert strategy_called, "Expected strategy to be called"
    assert_equal :stop, result
  end

  def test_check_compaction_rescues_hook_errors_gracefully
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 100,
      threshold: 10
    )
    tracker.record(sent_tokens: 15, received_tokens: 5)

    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_token_budget_warning) do |_data, _ctx|
      raise StandardError, "Broken hook!"
    end

    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      hook_manager:         hm,
      compaction_strategy:  strategy_obj
    )

    # Should not raise despite broken hook — logs warn to stderr and returns :continue
    result = nil
    _out, err = capture_io do
      result = runner.send(
        :check_compaction,
        conversation: [ { role: "user", content: "Hi" } ],
        agent_id: nil, task_id: nil, original_prompt: "Hi", context: {}
      )
    end

    assert_equal :continue, result, "Expected :continue despite broken hook"
    assert_includes err, "Broken hook!", "Expected warn message in stderr"
  end

  def test_compaction_strategy_attr_reader
    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue
    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:       mock_mm,
      compaction_strategy: strategy_obj
    )
    assert_same strategy_obj, runner.compaction_strategy
  end

  def test_tiered_strategy_reset_called_on_run_start
    tiered = AgentDesk::Agent::TieredStrategy.new
    reset_called = false
    tiered.define_singleton_method(:reset) do
      reset_called = true
      self
    end

    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:       mock_mm,
      compaction_strategy: tiered
    )
    runner.run(prompt: "Hi", project_dir: "/tmp")
    assert reset_called, "Expected TieredStrategy#reset to be called at start of run"
  end

  def test_resolve_strategy_symbol_returns_persistent_object
    # When :tiered is passed, resolve_strategy must instantiate TieredStrategy
    # once at construction so @handled_tiers state persists across loop iterations.
    mock_mm = AgentDesk::Test::MockModelManager.new(responses: [ text_response ])
    runner = AgentDesk::Agent::Runner.new(
      model_manager:       mock_mm,
      compaction_strategy: :tiered
    )
    assert_kind_of AgentDesk::Agent::TieredStrategy, runner.compaction_strategy,
                   "Expected :tiered symbol to be resolved to TieredStrategy at construction time"
  end

  def test_resolve_strategy_compact_symbol
    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:       mock_mm,
      compaction_strategy: :compact
    )
    assert_kind_of AgentDesk::Agent::CompactStrategy, runner.compaction_strategy
  end

  def test_resolve_strategy_handoff_symbol
    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:       mock_mm,
      compaction_strategy: :handoff
    )
    assert_kind_of AgentDesk::Agent::HandoffStrategy, runner.compaction_strategy
  end

  def test_resolve_strategy_nil_returns_nil
    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:       mock_mm,
      compaction_strategy: nil
    )
    assert_nil runner.compaction_strategy
  end

  def test_check_compaction_cost_exceeded_fires_hook
    # M1: verify on_cost_budget_exceeded hook actually fires
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 200_000,
      threshold: 0,
      cost_budget: 0.01
    )
    tracker.record(sent_tokens: 100, received_tokens: 50, message_cost: 0.05)

    hook_fired = false
    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_cost_budget_exceeded) do |_data, _ctx|
      hook_fired = true
      AgentDesk::Hooks::HookResult.new(blocked: false, event: {}, result: nil)
    end

    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue

    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      hook_manager:         hm,
      compaction_strategy:  strategy_obj
    )

    runner.send(:check_compaction,
      conversation: [], agent_id: nil, task_id: nil, original_prompt: "Hi", context: {})

    assert hook_fired, "Expected on_cost_budget_exceeded hook to fire"
  end

  def test_check_compaction_cost_exceeded_hook_can_block_halt
    # M2: hook returns blocked: true → runner should NOT return :stop from cost check
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 200_000,
      threshold: 0,
      cost_budget: 0.01
    )
    tracker.record(sent_tokens: 100, received_tokens: 50, message_cost: 0.05)

    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_cost_budget_exceeded) do |_data, _ctx|
      # Block the halt
      AgentDesk::Hooks::HookResult.new(blocked: true, event: {}, result: nil)
    end

    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue

    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      hook_manager:         hm,
      compaction_strategy:  strategy_obj
    )

    result = runner.send(:check_compaction,
      conversation: [], agent_id: nil, task_id: nil, original_prompt: "Hi", context: {})

    refute_equal :stop, result, "When on_cost_budget_exceeded blocks, runner should not return :stop"
  end

  def test_check_compaction_token_warning_hook_blocking_skips_strategy
    # M3: when on_token_budget_warning blocks, strategy should NOT be called
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 100,
      threshold: 10
    )
    tracker.record(sent_tokens: 15, received_tokens: 5)

    hm = AgentDesk::Hooks::HookManager.new
    hm.on(:on_token_budget_warning) do |_data, _ctx|
      AgentDesk::Hooks::HookResult.new(blocked: true, event: {}, result: nil)
    end

    strategy_called = false
    strategy_obj = Object.new
    strategy_obj.define_singleton_method(:execute) do |**_kwargs|
      strategy_called = true
      :stop
    end

    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      hook_manager:         hm,
      compaction_strategy:  strategy_obj
    )

    result = runner.send(:check_compaction,
      conversation: [ { role: "user", content: "Hi" } ],
      agent_id: nil, task_id: nil, original_prompt: "Hi", context: {})

    refute strategy_called, "Strategy should NOT be called when on_token_budget_warning blocks"
    assert_equal :continue, result
  end

  def test_check_compaction_publishes_budget_warning_event
    # M4: verify conversation.budget_warning MessageBus event is published
    tracker = AgentDesk::Agent::TokenBudgetTracker.new(
      context_window: 100,
      threshold: 10
    )
    tracker.record(sent_tokens: 15, received_tokens: 5)

    bus = AgentDesk::MessageBus::CallbackBus.new
    published = []
    bus.subscribe("conversation.budget_warning") { |_ch, event| published << event }

    strategy_obj = Object.new
    def strategy_obj.execute(**_kwargs) = :continue

    mock_mm = AgentDesk::Test::MockModelManager.new
    runner = AgentDesk::Agent::Runner.new(
      model_manager:        mock_mm,
      token_budget_tracker: tracker,
      message_bus:          bus,
      compaction_strategy:  strategy_obj
    )

    runner.send(:check_compaction,
      conversation: [ { role: "user", content: "Hi" } ],
      agent_id: "a1", task_id: "t1", original_prompt: "Hi", context: {})

    assert_equal 1, published.size, "Expected conversation.budget_warning event to be published"
    assert_equal "conversation.budget_warning", published.first.type
  end
end
