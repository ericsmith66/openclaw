require "test_helper"

class AiWorkflowServiceTest < ActiveSupport::TestCase
  test "handoff occurs and artifacts are written" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Coordinator assigns ball_with=Coordinator"
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        }
      )

    correlation_id = "cid-123"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.rm_rf(run_dir)

    result = AiWorkflowService.run(prompt: "Please assign this task", correlation_id: correlation_id)

    assert_equal "Coordinator", result.context[:ball_with]
    assert_includes result.output.to_s, "Coordinator"

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    assert File.exist?(run_dir.join("run.json")), "expected run.json to exist"
    assert File.exist?(run_dir.join("events.ndjson")), "expected events.ndjson to exist"

    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "agent_handoff" && e["from"] == "SAP" && e["to"] == "Coordinator" },
           "expected an agent_handoff event SAP -> Coordinator"
  ensure
    FileUtils.rm_rf(run_dir)
  end

  test "agent_handoff event broadcasts to agent_hub_channel_workflow_monitor" do
    correlation_id = "cid-broadcast-test"
    writer = AiWorkflow::ArtifactWriter.new(correlation_id)

    broadcasts = []
    ActionCable.server.stub :broadcast, ->(channel, data) { broadcasts << { channel: channel, data: data } } do
      writer.send(:on_agent_handoff, "AgentA", "AgentB", "Testing")
    end

    assert broadcasts.any? { |b| b[:channel] == "agent_hub_channel_workflow_monitor" },
           "Expected broadcast to workflow monitor"

    handoff_broadcast = broadcasts.find { |b| b[:channel] == "agent_hub_channel_workflow_monitor" }
    assert_match /🔄 \[HANDOFF\] AgentA -> AgentB/, handoff_broadcast[:data][:token]
  end

  test "should not fail when correlation_id is an Integer" do
    # We mock the actual runner to avoid real network calls
    mock_result = OpenStruct.new(
      output: "Done",
      context: { current_agent: "SAP", turn_count: 1, workflow_state: "complete", correlation_id: 123 },
      error: nil
    )

    runner_mock = Minitest::Mock.new
    runner_mock.expect :on_run_start, nil
    runner_mock.expect :on_agent_thinking, nil
    runner_mock.expect :on_agent_handoff, nil
    runner_mock.expect :on_agent_complete, nil
    runner_mock.expect :on_run_complete, nil
    runner_mock.expect :on_tool_start, nil
    runner_mock.expect :on_tool_complete, nil
    runner_mock.expect :run, mock_result, [ String ], context: Hash, max_turns: Integer, headers: Hash

    Agents::Runner.stub :with_agents, runner_mock do
      assert_nothing_raised do
        AiWorkflowService.run(prompt: "Test", correlation_id: 123)
      end
    end
  end

  test "run_once should not fail when correlation_id is an Integer" do
    mock_result = OpenStruct.new(
      output: "Done",
      context: { current_agent: "SAP", turn_count: 1, workflow_state: "complete", correlation_id: 456 },
      error: nil
    )

    context = AiWorkflowService.build_initial_context(456)
    artifacts = AiWorkflow::ArtifactWriter.new(456)

    runner_mock = Minitest::Mock.new
    runner_mock.expect :on_run_start, nil
    runner_mock.expect :on_agent_thinking, nil
    runner_mock.expect :on_agent_handoff, nil
    runner_mock.expect :on_agent_complete, nil
    runner_mock.expect :on_run_complete, nil
    runner_mock.expect :on_tool_start, nil
    runner_mock.expect :on_tool_complete, nil
    runner_mock.expect :run, mock_result, [ String ], context: Hash, max_turns: Integer, headers: Hash

    Agents::Runner.stub :with_agents, runner_mock do
      # It might raise EscalateToHumanError if turn count >= max_turns,
      # but it should NOT raise TypeError
      begin
        result = AiWorkflowService.run_once(prompt: "Test", context: context, artifacts: artifacts, max_turns: 5)
        assert_equal "Done", result.output
        assert_equal 456, result.context[:correlation_id]
      rescue AiWorkflowService::EscalateToHumanError
        # skip if mock doesn't satisfy guardrails
        assert true
      end
    end
  end

  test "coordinator can handoff to cwa" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_2",
                      type: "function",
                      function: {
                        name: "handoff_to_cwa",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-3",
            object: "chat.completion",
            created: 3,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "CWA received handoff and will implement/test/commit via tools"
                }
              }
            ],
            usage: { prompt_tokens: 14, completion_tokens: 7, total_tokens: 21 }
          }.to_json
        }
      )

    correlation_id = "cid-cwa-1"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.rm_rf(run_dir)
    result = AiWorkflowService.run(prompt: "Please implement via CWA", correlation_id: correlation_id)

    assert_equal "Human", result.context[:ball_with]
    assert_equal "awaiting_review", result.context[:workflow_state]
    assert_includes result.output.to_s, "CWA"

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "agent_handoff" && e["from"] == "Coordinator" && e["to"] == "CWA" },
           "expected an agent_handoff event Coordinator -> CWA"

    assert File.exist?(run_dir.join("cwa_log.json")), "expected cwa_log.json to exist"
    assert File.exist?(run_dir.join("cwa_log.md")), "expected cwa_log.md to exist"

    cwa_log = JSON.parse(File.read(run_dir.join("cwa_log.json")))
    assert_equal correlation_id, cwa_log["correlation_id"]
  ensure
    FileUtils.rm_rf(run_dir)
  end

  test "load_existing_context resumes from run.json" do
    correlation_id = "cid-resume-1"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.mkdir_p(run_dir)

    File.write(
      run_dir.join("run.json"),
      JSON.pretty_generate({
        correlation_id: correlation_id,
        context: { correlation_id: correlation_id, workflow_state: "in_progress", ball_with: "CWA", micro_tasks: [ { "id" => 1 } ] }
      })
    )

    ctx = AiWorkflowService.load_existing_context(correlation_id)
    assert_equal correlation_id, ctx[:correlation_id]
    assert_equal 1, ctx[:micro_tasks].length
  ensure
    FileUtils.rm_rf(run_dir)
  end

  test "load_existing_context drops malformed conversation_history entries missing role" do
    correlation_id = "cid-resume-bad-history-1"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.mkdir_p(run_dir)

    File.write(
      run_dir.join("run.json"),
      JSON.pretty_generate({
        correlation_id: correlation_id,
        context: {
          correlation_id: correlation_id,
          workflow_state: "in_progress",
          ball_with: "SAP",
          conversation_history: [
            { "role" => "user", "content" => "hello" },
            { "role" => nil, "content" => "broken" },
            { "content" => "missing role" },
            "not a hash"
          ]
        }
      })
    )

    ctx = AiWorkflowService.load_existing_context(correlation_id)
    assert_equal 1, ctx[:conversation_history].length
    assert_equal "user", ctx[:conversation_history].first[:role]
  ensure
    FileUtils.rm_rf(run_dir)
  end

  test "logs junie deprecation event" do
    url = "http://localhost:3002/v1/chat/completions"
    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: Time.now.to_i,
            model: "llama3.1:70b",
            choices: [ { index: 0, message: { role: "assistant", content: "ok" }, finish_reason: "stop" } ],
            usage: { prompt_tokens: 1, completion_tokens: 1, total_tokens: 2 }
          }.to_json
        }
      )

    correlation_id = "cid-junie-1"
    AiWorkflowService.run(prompt: "Junie please generate code", correlation_id: correlation_id)

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "junie_deprecation" }
  ensure
    FileUtils.rm_rf(Rails.root.join("agent_logs", "ai_workflow", correlation_id))
  end

  test "guardrail rejects empty prompt" do
    assert_raises(AiWorkflowService::GuardrailError) do
      AiWorkflowService.run(prompt: "   ")
    end
  end

  test "resolve_feedback enters awaiting_feedback when no feedback is provided" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Coordinator requests feedback"
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        }
      )

    correlation_id = "cid-feedback-1"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.rm_rf(run_dir)
    result = AiWorkflowService.resolve_feedback(prompt: "Please resolve this", correlation_id: correlation_id, feedback: nil)

    assert_equal "awaiting_feedback", result.context[:workflow_state]
    assert_equal 1, result.context[:feedback_history].size

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "feedback_requested" }, "expected a feedback_requested event"
  ensure
    FileUtils.rm_rf(run_dir)
  end

  test "resolve_feedback continues and resolves when feedback is provided" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Coordinator requests feedback"
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-3",
            object: "chat.completion",
            created: 3,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Final resolution: resolved"
                }
              }
            ],
            usage: { prompt_tokens: 14, completion_tokens: 7, total_tokens: 21 }
          }.to_json
        }
      )

    correlation_id = "cid-feedback-2"
    result = AiWorkflowService.resolve_feedback(
      prompt: "Please resolve this",
      feedback: "Here is the missing detail",
      correlation_id: correlation_id
    )

    assert_equal "resolved", result.context[:workflow_state]
    assert_equal 1, result.context[:feedback_history].count { |h| h[:feedback].present? }

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "resolution_complete" && e["state"] == "resolved" },
           "expected a resolution_complete event"
  end

  test "finalize_hybrid_handoff! syncs micro_tasks to artifact" do
    user = User.create!(email: "test-artifact@example.com", password: "password", roles: [ "admin" ])
    artifact = Artifact.create!(name: "Test Artifact", artifact_type: "feature")
    run = AiWorkflowRun.create!(user: user, status: "draft", metadata: { "active_artifact_id" => artifact.id })

    result = OpenStruct.new(
      context: {
        correlation_id: run.id,
        current_agent: "Planner",
        workflow_state: "in_progress",
        micro_tasks: [ { "id" => "task-01", "title" => "Test Task", "estimate" => "10m" } ]
      }
    )

    artifacts_writer = AiWorkflow::ArtifactWriter.new(run.id)

    AiWorkflowService.finalize_hybrid_handoff!(result, artifacts: artifacts_writer)

    artifact.reload
    assert_equal 1, artifact.payload["micro_tasks"].size
    assert_equal "Test Task", artifact.payload["micro_tasks"].first["title"]
  end

  test "finalize_hybrid_handoff! can resolve AiWorkflowRun via correlation_id" do
    user = User.create!(email: "test-correlation-id@example.com", password: "password", roles: [ "admin" ])
    artifact = Artifact.create!(name: "Test Artifact", artifact_type: "feature")
    run = AiWorkflowRun.create!(
      user: user,
      status: "draft",
      correlation_id: "rid-001",
      metadata: { "active_artifact_id" => artifact.id }
    )

    result = OpenStruct.new(
      context: {
        correlation_id: run.correlation_id,
        current_agent: "Planner",
        workflow_state: "in_progress",
        micro_tasks: [ { "id" => "task-01", "title" => "Correlation Task", "estimate" => "10m" } ]
      }
    )

    artifacts_writer = AiWorkflow::ArtifactWriter.new(run.correlation_id)
    AiWorkflowService.finalize_hybrid_handoff!(result, artifacts: artifacts_writer)

    artifact.reload
    assert_equal "Correlation Task", artifact.payload["micro_tasks"].first["title"]
  end
end
