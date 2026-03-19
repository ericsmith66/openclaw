# frozen_string_literal: true

require "test_helper"

class ToolSetBuilderTest < Minitest::Test
  # ── Tools.build_group DSL ────────────────────────────────────────────────────

  def test_build_group_returns_tool_set
    ts = AgentDesk::Tools.build_group("my_group") { }
    assert_instance_of AgentDesk::Tools::ToolSet, ts
  end

  def test_build_group_empty_block_returns_empty_tool_set
    ts = AgentDesk::Tools.build_group("my_group") { }
    assert_equal 0, ts.size
  end

  def test_build_group_nil_block_returns_empty_tool_set
    ts = AgentDesk::Tools.build_group("my_group")
    assert_instance_of AgentDesk::Tools::ToolSet, ts
    assert_equal 0, ts.size
  end

  def test_build_group_with_single_tool
    ts = AgentDesk::Tools.build_group("power") do
      tool name: "bash", description: "Runs a shell command" do |args, context:|
        "ok"
      end
    end
    assert_equal 1, ts.size
  end

  def test_build_group_with_multiple_tools
    ts = AgentDesk::Tools.build_group("power") do
      tool name: "bash", description: "Shell command" do |args, context:| "bash" end
      tool name: "glob", description: "Glob files"   do |args, context:| "glob" end
      tool name: "grep", description: "Grep files"   do |args, context:| "grep" end
    end
    assert_equal 3, ts.size
  end

  def test_tool_full_name_uses_build_group_name
    ts = AgentDesk::Tools.build_group("power") do
      tool name: "bash", description: "Shell" do |args, context:| "ok" end
    end
    assert_equal "power---bash", ts["power---bash"].full_name
  end

  def test_tool_description_is_set
    ts = AgentDesk::Tools.build_group("test") do
      tool name: "my_tool", description: "My awesome tool" do |args, context:| "result" end
    end
    assert_equal "My awesome tool", ts["test---my_tool"].description
  end

  def test_tool_input_schema_is_set
    schema = { properties: { path: { type: "string" } }, required: [ "path" ] }
    ts = AgentDesk::Tools.build_group("fs") do
      tool name: "read", description: "Read a file", input_schema: schema do |args, context:|
        File.read(args["path"])
      end
    end
    tool = ts["fs---read"]
    refute_nil tool
    assert_equal schema, tool.input_schema
  end

  def test_tool_can_be_executed
    ts = AgentDesk::Tools.build_group("test") do
      tool name: "echo", description: "Echoes input" do |args, context:|
        args["message"]
      end
    end
    result = ts["test---echo"].execute({ "message" => "hello" })
    assert_equal "hello", result
  end

  def test_tool_input_schema_defaults_to_empty_hash
    ts = AgentDesk::Tools.build_group("test") do
      tool name: "simple", description: "Simple tool" do |args, context:| "ok" end
    end
    assert_equal({}, ts["test---simple"].input_schema)
  end

  # ── ToolSetBuilder directly ─────────────────────────────────────────────────

  def test_builder_build_returns_tool_set
    builder = AgentDesk::Tools::ToolSetBuilder.new("group")
    assert_instance_of AgentDesk::Tools::ToolSet, builder.build
  end

  def test_builder_tool_adds_to_set
    builder = AgentDesk::Tools::ToolSetBuilder.new("group")
    builder.tool(name: "foo", description: "Foo") { |args, context:| "foo" }
    assert_equal 1, builder.build.size
  end
end
