require "test_helper"

class ToolGuardrailsMixinTest < ActiveSupport::TestCase
  class TestTool
    include Agents::ToolGuardrailsMixin

    def perform(tool_context)
      enforce_tool_guardrails!(tool_context)
    end
  end

  class CustomLimitTool
    include Agents::ToolGuardrailsMixin
    MAX_CALLS_PER_TURN = 5
    MAX_RETRIES = 1

    def perform(tool_context)
      enforce_tool_guardrails!(tool_context)
    end
  end

  # Mock objects since we couldn't find the real ones easily
  # and we want to test the mixin in isolation.
  MockRunContext = Struct.new(:context)
  MockToolContext = Struct.new(:run_context, :retry_count) do
    def context
      run_context.context
    end
  end

  setup do
    @tool = TestTool.new
    @run_context = MockRunContext.new({})
    @tool_context = MockToolContext.new(@run_context, 0)
  end

  test "tracks tool calls per turn" do
    @run_context.context[:turn_count] = 1
    @tool.perform(@tool_context)
    @tool.perform(@tool_context)

    assert_equal 2, @run_context.context[:tool_calls_by_turn][1]
    assert_equal 2, @run_context.context[:tool_calls_total]
  end

  test "enforces default max calls per turn" do
    @run_context.context[:turn_count] = 1
    30.times { @tool.perform(@tool_context) }

    assert_raises(AiWorkflowService::GuardrailError) do
      @tool.perform(@tool_context)
    end
  end

  test "enforces custom max calls per turn" do
    tool = CustomLimitTool.new
    @run_context.context[:turn_count] = 1
    5.times { tool.perform(@tool_context) }

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(@tool_context)
    end
  end

  test "enforces total tool calls limit if provided in context" do
    @run_context.context[:max_tool_calls_total] = 10
    9.times { @tool.perform(@tool_context) }
    @tool.perform(@tool_context)

    assert_raises(AiWorkflowService::GuardrailError) do
      @tool.perform(@tool_context)
    end
  end

  test "enforces default max retries" do
    tool_context = MockToolContext.new(@run_context, 3)

    assert_raises(AiWorkflowService::GuardrailError) do
      @tool.perform(tool_context)
    end
  end

  test "enforces custom max retries" do
    tool = CustomLimitTool.new
    tool_context = MockToolContext.new(@run_context, 2)

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(tool_context)
    end
  end

  test "works with string keys in context" do
    @run_context.context["turn_count"] = 5
    @run_context.context["max_tool_calls_total"] = 2

    @tool.perform(@tool_context)
    assert_equal 1, @run_context.context[:tool_calls_by_turn][5]

    @tool.perform(@tool_context)
    assert_raises(AiWorkflowService::GuardrailError) do
      @tool.perform(@tool_context)
    end
  end
end
