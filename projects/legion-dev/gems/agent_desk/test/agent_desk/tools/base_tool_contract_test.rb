# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::Tools::BaseTool.
# These verify the public API shape that all downstream PRDs depend on.
class BaseToolContractTest < Minitest::Test
  def make_tool
    AgentDesk::Tools::BaseTool.new(
      name: "bash",
      group_name: "power",
      description: "Runs a shell command"
    ) { |args, context:| "executed" }
  end

  def test_responds_to_execute
    assert_respond_to make_tool, :execute
  end

  def test_execute_invokes_block
    tool = make_tool
    result = tool.execute
    assert_equal "executed", result
  end

  def test_responds_to_full_name
    assert_respond_to make_tool, :full_name
  end

  def test_full_name_returns_group_separator_name_format
    assert_equal "power---bash", make_tool.full_name
  end

  def test_responds_to_to_function_definition
    assert_respond_to make_tool, :to_function_definition
  end

  def test_to_function_definition_returns_hash_with_required_keys
    defn = make_tool.to_function_definition
    assert defn.key?(:name),        "Expected :name key"
    assert defn.key?(:description), "Expected :description key"
    assert defn.key?(:parameters),  "Expected :parameters key"
  end

  def test_execute_raises_not_implemented_error_without_block
    tool = AgentDesk::Tools::BaseTool.new(
      name: "no_block", group_name: "test", description: "no block"
    )
    assert_raises(NotImplementedError) { tool.execute }
  end
end
