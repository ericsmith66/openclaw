# frozen_string_literal: true

require "test_helper"

class ToolSetTest < Minitest::Test
  def make_tool(name:, group_name: "test")
    AgentDesk::Tools::BaseTool.new(
      name: name,
      group_name: group_name,
      description: "Tool #{name}"
    ) { |args, context:| "#{group_name}---#{name}" }
  end

  # ── basics ───────────────────────────────────────────────────────────────────

  def test_new_set_is_empty
    ts = AgentDesk::Tools::ToolSet.new
    assert_equal 0, ts.size
  end

  def test_add_increments_size
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "alpha"))
    assert_equal 1, ts.size
  end

  def test_add_multiple_tools
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "alpha"))
    ts.add(make_tool(name: "beta"))
    ts.add(make_tool(name: "gamma"))
    assert_equal 3, ts.size
  end

  def test_add_same_name_overwrites
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "alpha"))
    ts.add(make_tool(name: "alpha"))
    assert_equal 1, ts.size
  end

  # ── bracket access ────────────────────────────────────────────────────────────

  def test_bracket_returns_correct_tool
    ts = AgentDesk::Tools::ToolSet.new
    tool = make_tool(name: "bash", group_name: "power")
    ts.add(tool)
    assert_same tool, ts["power---bash"]
  end

  def test_bracket_returns_nil_for_unknown_name
    ts = AgentDesk::Tools::ToolSet.new
    assert_nil ts["nonexistent---tool"]
  end

  # ── each / Enumerable ────────────────────────────────────────────────────────

  def test_each_enumerates_all_tools
    ts = AgentDesk::Tools::ToolSet.new
    tools = [ make_tool(name: "a"), make_tool(name: "b"), make_tool(name: "c") ]
    tools.each { |t| ts.add(t) }

    visited = []
    ts.each { |t| visited << t }
    assert_equal 3, visited.size
    assert_equal tools.map(&:full_name).sort, visited.map(&:full_name).sort
  end

  def test_map_via_enumerable
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "x"))
    ts.add(make_tool(name: "y"))
    names = ts.map(&:full_name)
    assert_equal 2, names.size
  end

  def test_include_via_enumerable
    ts = AgentDesk::Tools::ToolSet.new
    tool = make_tool(name: "foo")
    ts.add(tool)
    assert ts.include?(tool)
  end

  # ── merge! ───────────────────────────────────────────────────────────────────

  def test_merge_bang_adds_other_tools
    ts1 = AgentDesk::Tools::ToolSet.new
    ts1.add(make_tool(name: "a"))

    ts2 = AgentDesk::Tools::ToolSet.new
    ts2.add(make_tool(name: "b"))
    ts2.add(make_tool(name: "c"))

    ts1.merge!(ts2)
    assert_equal 3, ts1.size
  end

  def test_merge_bang_returns_self
    ts1 = AgentDesk::Tools::ToolSet.new
    ts2 = AgentDesk::Tools::ToolSet.new
    result = ts1.merge!(ts2)
    assert_same ts1, result
  end

  def test_merge_bang_does_not_modify_other
    ts1 = AgentDesk::Tools::ToolSet.new
    ts2 = AgentDesk::Tools::ToolSet.new
    ts2.add(make_tool(name: "a"))
    ts1.merge!(ts2)
    assert_equal 1, ts2.size
  end

  # ── filter_by_approvals ──────────────────────────────────────────────────────

  def test_filter_by_approvals_removes_never_tools
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "allowed", group_name: "power"))
    ts.add(make_tool(name: "banned", group_name: "power"))

    approvals = {
      "power---banned" => AgentDesk::ToolApprovalState::NEVER
    }
    ts.filter_by_approvals(approvals)

    assert_equal 1, ts.size
    assert_nil ts["power---banned"]
    refute_nil ts["power---allowed"]
  end

  def test_filter_by_approvals_keeps_always_tools
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "always_tool", group_name: "power"))

    approvals = {
      "power---always_tool" => AgentDesk::ToolApprovalState::ALWAYS
    }
    ts.filter_by_approvals(approvals)
    assert_equal 1, ts.size
  end

  def test_filter_by_approvals_keeps_ask_tools
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "ask_tool", group_name: "power"))

    approvals = {
      "power---ask_tool" => AgentDesk::ToolApprovalState::ASK
    }
    ts.filter_by_approvals(approvals)
    assert_equal 1, ts.size
  end

  def test_filter_by_approvals_keeps_tools_not_in_approvals_map
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "unlisted", group_name: "power"))

    ts.filter_by_approvals({})
    assert_equal 1, ts.size
  end

  def test_filter_by_approvals_returns_self
    ts = AgentDesk::Tools::ToolSet.new
    result = ts.filter_by_approvals({})
    assert_same ts, result
  end

  def test_filter_by_approvals_mutates_in_place
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "banned", group_name: "x"))
    approvals = { "x---banned" => AgentDesk::ToolApprovalState::NEVER }
    ts.filter_by_approvals(approvals)
    assert_equal 0, ts.size
  end

  # ── to_function_definitions ──────────────────────────────────────────────────

  def test_to_function_definitions_returns_array
    ts = AgentDesk::Tools::ToolSet.new
    assert_instance_of Array, ts.to_function_definitions
  end

  def test_to_function_definitions_has_correct_count
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "a"))
    ts.add(make_tool(name: "b"))
    assert_equal 2, ts.to_function_definitions.size
  end

  def test_to_function_definitions_each_has_name
    ts = AgentDesk::Tools::ToolSet.new
    ts.add(make_tool(name: "my_tool", group_name: "grp"))
    defs = ts.to_function_definitions
    assert_equal "grp---my_tool", defs.first[:name]
  end

  def test_to_function_definitions_empty_set
    ts = AgentDesk::Tools::ToolSet.new
    assert_equal [], ts.to_function_definitions
  end
end
