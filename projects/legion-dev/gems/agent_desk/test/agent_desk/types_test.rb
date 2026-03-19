# frozen_string_literal: true

require "test_helper"

class ContextFileTest < Minitest::Test
  def test_defaults_read_only_to_false
    file = AgentDesk::ContextFile.new(path: "test.rb")
    assert_equal false, file.read_only
  end
end

class ToolApprovalStateTest < Minitest::Test
  def test_defines_three_approval_states
    assert_equal "always", AgentDesk::ToolApprovalState::ALWAYS
    assert_equal "ask", AgentDesk::ToolApprovalState::ASK
    assert_equal "never", AgentDesk::ToolApprovalState::NEVER
  end
end

class ReasoningEffortTest < Minitest::Test
  def test_defines_four_effort_levels
    assert_equal "none", AgentDesk::ReasoningEffort::NONE
    assert_equal "low", AgentDesk::ReasoningEffort::LOW
    assert_equal "medium", AgentDesk::ReasoningEffort::MEDIUM
    assert_equal "high", AgentDesk::ReasoningEffort::HIGH
  end
end

class ContextMemoryModeTest < Minitest::Test
  def test_defines_three_memory_modes
    assert_equal "off", AgentDesk::ContextMemoryMode::OFF
    assert_equal "relevant", AgentDesk::ContextMemoryMode::RELEVANT
    assert_equal "full", AgentDesk::ContextMemoryMode::FULL
  end
end

class InvocationModeTest < Minitest::Test
  def test_defines_two_invocation_modes
    assert_equal "on_demand", AgentDesk::InvocationMode::ON_DEMAND
    assert_equal "always", AgentDesk::InvocationMode::ALWAYS
  end
end

class ContextMessageTest < Minitest::Test
  def test_creates_context_message_with_attributes
    message = AgentDesk::ContextMessage.new(
      id: "msg1",
      role: "user",
      content: "Hello",
      prompt_context: nil
    )
    assert_equal "msg1", message.id
    assert_equal "user", message.role
    assert_equal "Hello", message.content
    assert_nil message.prompt_context
  end
end

class SubagentConfigTest < Minitest::Test
  def test_default_values
    config = AgentDesk::SubagentConfig.new
    assert_equal false, config.enabled
    assert_equal "", config.system_prompt
    assert_equal AgentDesk::InvocationMode::ON_DEMAND, config.invocation_mode
    assert_equal "#3368a8", config.color
    assert_equal "", config.description
    assert_equal AgentDesk::ContextMemoryMode::OFF, config.context_memory
  end

  def test_custom_values
    config = AgentDesk::SubagentConfig.new(
      enabled: true,
      system_prompt: "Custom prompt",
      invocation_mode: AgentDesk::InvocationMode::ALWAYS,
      color: "#ff0000",
      description: "Test agent",
      context_memory: AgentDesk::ContextMemoryMode::RELEVANT
    )
    assert_equal true, config.enabled
    assert_equal "Custom prompt", config.system_prompt
    assert_equal AgentDesk::InvocationMode::ALWAYS, config.invocation_mode
    assert_equal "#ff0000", config.color
    assert_equal "Test agent", config.description
    assert_equal AgentDesk::ContextMemoryMode::RELEVANT, config.context_memory
  end
end
