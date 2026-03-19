# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class PowerToolsContractTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("power_tools_contract")
    @tool_set = AgentDesk::Tools::PowerTools.create(project_dir: @project_dir)
  end

  def teardown
    FileUtils.remove_entry(@project_dir) if File.exist?(@project_dir)
  end

  def test_file_read_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "file_read")]
    assert tool
    # Safe call with non-existent file returns error string
    result = tool.execute({ "file_path" => "nonexistent.txt" })
    assert_kind_of String, result
  end

  def test_file_write_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "file_write")]
    assert tool
    # Create a file in temp dir
    result = tool.execute({
      "file_path" => "test.txt",
      "content" => "hello",
      "mode" => "create_only"
    })
    assert_kind_of String, result
  end

  def test_file_edit_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "file_edit")]
    assert tool
    # Create a file first
    file = File.join(@project_dir, "edit.txt")
    File.write(file, "foo bar")
    result = tool.execute({
      "file_path" => "edit.txt",
      "search_term" => "foo",
      "replacement_text" => "baz"
    })
    assert_kind_of String, result
  end

  def test_glob_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "glob")]
    assert tool
    result = tool.execute({ "pattern" => "*.txt" })
    assert_kind_of String, result
  end

  def test_grep_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "grep")]
    assert tool
    # Create a file to search
    File.write(File.join(@project_dir, "search.txt"), "needle")
    result = tool.execute({
      "file_pattern" => "*.txt",
      "search_term" => "needle"
    })
    assert_kind_of String, result
  end

  def test_bash_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "bash")]
    assert tool
    result = tool.execute({ "command" => "echo hello" })
    assert_kind_of String, result
  end

  def test_fetch_tool_exists
    tool = @tool_set[AgentDesk.tool_id("power", "fetch")]
    assert tool
    # Use a URL that will fail (invalid host) but still call the tool
    result = tool.execute({ "url" => "http://nonexistent.invalid" })
    assert_kind_of String, result
  end
end
