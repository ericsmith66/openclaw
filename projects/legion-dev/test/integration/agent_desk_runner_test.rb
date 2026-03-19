# frozen_string_literal: true

require "test_helper"

class AgentDeskRunnerTest < ActionDispatch::IntegrationTest
  # VCR-recorded test: Runner dispatches a prompt to SmartProxy and receives a response.
  # Requires VCR hook_into :webmock to be enabled, or a live SmartProxy instance.
  # Skipped because VCR's webmock hook is disabled to avoid infinite recursion in other tests.
  test "runner dispatches prompt to SmartProxy and receives assistant response" do
    skip "VCR hook_into :webmock disabled — enable RECORD_VCR=1 with live SmartProxy to record or replay"
    VCR.use_cassette("smart_proxy_chat_completion") do
      model_manager = AgentDesk::Models::ModelManager.new(
        provider: :smart_proxy,
        api_key: ENV.fetch("SMART_PROXY_TOKEN", "changeme"),
        base_url: ENV.fetch("SMART_PROXY_URL", "http://192.168.4.253:3001"),
        model: "deepseek-reasoner"
      )

      runner = AgentDesk::Agent::Runner.new(model_manager: model_manager)

      conversation = runner.run(
        prompt: "Say hello in one word.",
        project_dir: Rails.root.to_s
      )

      # The conversation should contain at least the user message and assistant response
      assert conversation.size >= 2, "Expected at least 2 messages in conversation"

      # Find the assistant response
      assistant_msg = conversation.find { |msg| msg[:role] == "assistant" }
      assert assistant_msg, "No assistant message found in conversation"
      assert assistant_msg[:content].present?, "Assistant response content is empty"
    end
  end
end
