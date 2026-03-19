# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::Tools::ToolSet.
# These verify the public API shape that all downstream PRDs depend on.
class ToolSetContractTest < Minitest::Test
  def make_tool(name:, group_name: "test")
    AgentDesk::Tools::BaseTool.new(
      name: name, group_name: group_name, description: "Tool #{name}"
    ) { |args, context:| name }
  end

  def test_responds_to_add
    ts = AgentDesk::Tools::ToolSet.new
    assert_respond_to ts, :add
  end

  def test_add_tool_increases_size
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "alpha"))
    assert_equal 1, ts.size
  end

  def test_responds_to_filter_by_approvals
    ts = AgentDesk::Tools::ToolSet.new
    assert_respond_to ts, :filter_by_approvals
  end

  def test_filter_by_approvals_removes_never_tools
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "allowed", group_name: "g"))
    ts.add(make_tool(name: "banned",  group_name: "g"))
    ts.filter_by_approvals({ "g---banned" => AgentDesk::ToolApprovalState::NEVER })
    assert_equal 1, ts.size
    refute_nil ts["g---allowed"]
  end

  def test_responds_to_to_function_definitions
    ts = AgentDesk::Tools::ToolSet.new
    assert_respond_to ts, :to_function_definitions
  end

  def test_to_function_definitions_returns_array
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "x"))
    assert_instance_of Array, ts.to_function_definitions
  end

  def test_is_enumerable
    ts = AgentDesk::Tools::ToolSet.new
    assert_kind_of Enumerable, ts
  end
end
