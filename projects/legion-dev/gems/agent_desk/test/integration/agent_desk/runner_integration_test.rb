# frozen_string_literal: true

require "test_helper"

# Integration test for AgentDesk::Agent::Runner with a real LLM provider.
#
# Requires the AGENT_DESK_INTEGRATION environment variable to be set to "true".
# These tests make real HTTP calls and should NOT be run in CI without a
# configured LLM provider.
#
# Usage:
#   AGENT_DESK_INTEGRATION=true bundle exec ruby test/integration/agent_desk/runner_integration_test.rb
class RunnerIntegrationTest < Minitest::Test
  def setup
    skip "Set AGENT_DESK_INTEGRATION=true to run integration tests" \
      unless ENV["AGENT_DESK_INTEGRATION"] == "true"

    api_key = ENV.fetch("OPENAI_API_KEY") { skip "OPENAI_API_KEY not set" }

    @model_manager = AgentDesk::Models::ModelManager.new(
      provider: :openai,
      api_key: api_key,
      model: "gpt-4o-mini"
    )
    @runner = AgentDesk::Agent::Runner.new(model_manager: @model_manager)
  end

  def test_run_returns_conversation_with_real_llm
    conv = @runner.run(
      prompt: "Reply with exactly the word: PONG",
      project_dir: Dir.pwd
    )

    assert_kind_of Array, conv
    assert conv.size >= 2, "Expected at least a user message and an assistant reply"
    last = conv.last
    assert_equal "assistant", last[:role]
    assert_kind_of String, last[:content]
    refute last[:content].to_s.strip.empty?, "Expected non-empty assistant response"
  end
end
