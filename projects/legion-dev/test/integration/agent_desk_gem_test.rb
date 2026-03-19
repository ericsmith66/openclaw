# frozen_string_literal: true

require "test_helper"

class AgentDeskGemTest < ActionDispatch::IntegrationTest
  test "AgentDesk::VERSION is defined" do
    assert_kind_of String, AgentDesk::VERSION
    refute_empty AgentDesk::VERSION
  end

  test "AgentDesk::Agent::Runner is defined" do
    assert defined?(AgentDesk::Agent::Runner)
  end

  test "AgentDesk::MessageBus::CallbackBus is defined" do
    assert defined?(AgentDesk::MessageBus::CallbackBus)
  end
end
