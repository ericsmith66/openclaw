# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "faraday"
require "faraday/adapter/test"

class PowerToolsTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("power_tools")
    @tool_set = AgentDesk::Tools::PowerTools.create(project_dir: @project_dir)
  end

  def teardown
    FileUtils.remove_entry(@project_dir) if File.exist?(@project_dir)
  end

  def tool(name)
    @tool_set[AgentDesk.tool_id("power", name)]
  end

  def stub_faraday_response(url:, body:, status: 200, headers: {})
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(url) { [ status, headers, body ] }
    end
    Faraday.new do |builder|
      builder.adapter :test, stubs
    end
  end

  def stub_faraday_error(url:, error_class:, error_message: nil)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(url) { raise error_class, error_message }
    end
    Faraday.new do |builder|
      builder.adapter :test, stubs
    end
  end

  def test_create_returns_7_tools
    tool_set = AgentDesk::Tools::PowerTools.create(project_dir: @project_dir)
    assert_equal 7, tool_set.count
    expected_names = %w[file_read file_write file_edit glob grep bash fetch]
    expected_names.each do |name|
      assert tool_set[AgentDesk.tool_id("power", name)], "Missing tool: #{name}"
    end
  end

  def test_all_tools_have_schema_and_description
    tool_set = AgentDesk::Tools::PowerTools.create(project_dir: @project_dir)
    tool_set.each do |tool|
      assert tool.input_schema, "Tool #{tool.full_name} missing input_schema"
      assert tool.description, "Tool #{tool.full_name} missing description"
      # input_schema must be a hash with properties
      assert_kind_of Hash, tool.input_schema
      assert_kind_of String, tool.description
    end
  end

  # --- file_read -------------------------------------------------------------
  def test_file_read_happy_path
    file = File.join(@project_dir, "test.txt")
    File.write(file, "line1\nline2\nline3")
    result = tool("file_read").execute({ "file_path" => "test.txt" })
    assert_equal "line1\nline2\nline3", result
  end

  def test_file_read_with_lines
    file = File.join(@project_dir, "test.txt")
    File.write(file, "line1\nline2")
    result = tool("file_read").execute({ "file_path" => "test.txt", "with_lines" => true })
    assert_equal "1|line1\n2|line2", result
  end

  def test_file_read_with_offset_and_limit
    file = File.join(@project_dir, "test.txt")
    File.write(file, "a\nb\nc\nd\ne")
    result = tool("file_read").execute({ "file_path" => "test.txt", "line_offset" => 1, "line_limit" => 2 })
    assert_equal "b\nc", result
  end

  def test_file_read_nonexistent_file_returns_error
    result = tool("file_read").execute({ "file_path" => "nonexistent.txt" })
    assert_kind_of String, result
    assert_match(/No such file|ENOENT/, result)
  end

  def test_file_read_path_traversal_raises_error
    result = tool("file_read").execute({ "file_path" => "../../../etc/passwd" })
    assert_kind_of String, result
    assert_match(/outside project directory/, result)
  end

  # --- file_write ------------------------------------------------------------
  def test_file_write_create_only_success
    result = tool("file_write").execute({
      "file_path" => "new.txt",
      "content" => "hello",
      "mode" => "create_only"
    })
    assert_match(/successfully/i, result.downcase)
    assert File.exist?(File.join(@project_dir, "new.txt"))
    assert_equal "hello", File.read(File.join(@project_dir, "new.txt"))
  end

  def test_file_write_create_only_fails_if_exists
    file = File.join(@project_dir, "exists.txt")
    File.write(file, "original")
    result = tool("file_write").execute({
      "file_path" => "exists.txt",
      "content" => "new",
      "mode" => "create_only"
    })
    assert_match(/already exists/, result)
    assert_equal "original", File.read(file)
  end

  def test_file_write_overwrite
    file = File.join(@project_dir, "overwrite.txt")
    File.write(file, "original")
    result = tool("file_write").execute({
      "file_path" => "overwrite.txt",
      "content" => "new",
      "mode" => "overwrite"
    })
    assert_match(/successfully/i, result.downcase)
    assert_equal "new", File.read(file)
  end

  def test_file_write_append
    file = File.join(@project_dir, "append.txt")
    File.write(file, "original")
    result = tool("file_write").execute({
      "file_path" => "append.txt",
      "content" => " appended",
      "mode" => "append"
    })
    assert_match(/successfully/i, result.downcase)
    assert_equal "original appended", File.read(file)
  end

  def test_file_write_path_traversal_raises_error
    result = tool("file_write").execute({
      "file_path" => "../../../etc/passwd",
      "content" => "evil",
      "mode" => "create_only"
    })
    assert_match(/outside project directory/, result)
  end

  # --- file_edit -------------------------------------------------------------
  def test_file_edit_string_replace
    file = File.join(@project_dir, "edit.txt")
    File.write(file, "hello world")
    result = tool("file_edit").execute({
      "file_path" => "edit.txt",
      "search_term" => "world",
      "replacement_text" => "there"
    })
    assert_match(/Replaced/, result)
    assert_equal "hello there", File.read(file)
  end

  def test_file_edit_regex_replace
    file = File.join(@project_dir, "edit.txt")
    File.write(file, "foo 123 bar")
    result = tool("file_edit").execute({
      "file_path" => "edit.txt",
      "search_term" => '\d+',
      "replacement_text" => "NUM",
      "is_regex" => true
    })
    assert_match(/Replaced/, result)
    assert_equal "foo NUM bar", File.read(file)
  end

  def test_file_edit_replace_all
    file = File.join(@project_dir, "edit.txt")
    File.write(file, "a a a")
    result = tool("file_edit").execute({
      "file_path" => "edit.txt",
      "search_term" => "a",
      "replacement_text" => "b",
      "replace_all" => true
    })
    assert_match(/all occurrences/, result)
    assert_equal "b b b", File.read(file)
  end

  def test_file_edit_search_term_not_found
    file = File.join(@project_dir, "edit.txt")
    File.write(file, "hello")
    result = tool("file_edit").execute({
      "file_path" => "edit.txt",
      "search_term" => "missing",
      "replacement_text" => "x"
    })
    assert_match(/Search term not found/, result)
    assert_equal "hello", File.read(file)
  end

  def test_file_edit_invalid_regex_returns_error
    file = File.join(@project_dir, "edit.txt")
    File.write(file, "hello")
    result = tool("file_edit").execute({
      "file_path" => "edit.txt",
      "search_term" => "[invalid",
      "replacement_text" => "x",
      "is_regex" => true
    })
    assert_match(/Invalid regular expression/, result)
  end

  def test_file_edit_path_traversal_raises_error
    result = tool("file_edit").execute({
      "file_path" => "../../../etc/passwd",
      "search_term" => "root",
      "replacement_text" => "admin"
    })
    assert_match(/outside project directory/, result)
  end

  # --- glob ------------------------------------------------------------------
  def test_glob_finds_files
    File.write(File.join(@project_dir, "a.txt"), "")
    File.write(File.join(@project_dir, "b.rb"), "")
    result = tool("glob").execute({ "pattern" => "*.txt" })
    assert_equal "a.txt", result
  end

  def test_glob_with_cwd
    Dir.mkdir(File.join(@project_dir, "sub"))
    File.write(File.join(@project_dir, "sub", "file.txt"), "")
    result = tool("glob").execute({ "pattern" => "*.txt", "cwd" => "sub" })
    assert_equal "file.txt", result
  end

  def test_glob_with_ignore
    File.write(File.join(@project_dir, "a.txt"), "")
    File.write(File.join(@project_dir, "b.txt"), "")
    result = tool("glob").execute({ "pattern" => "*.txt", "ignore" => [ "b.txt" ] })
    assert_equal "a.txt", result
  end

  def test_glob_returns_empty_string_for_no_matches
    result = tool("glob").execute({ "pattern" => "*.nonexistent" })
    assert_equal "", result
  end

  def test_glob_cwd_path_traversal_raises_error
    result = tool("glob").execute({ "pattern" => "*", "cwd" => "../../.." })
    assert_match(/outside project directory/, result)
  end

  # --- grep ------------------------------------------------------------------
  def test_grep_finds_match
    file = File.join(@project_dir, "test.txt")
    File.write(file, "hello\nworld\ngoodbye")
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "world"
    })
    assert_match(/world/, result)
  end

  def test_grep_case_insensitive_by_default
    file = File.join(@project_dir, "test.txt")
    File.write(file, "HELLO")
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "hello"
    })
    assert_match(/HELLO/, result)
  end

  def test_grep_case_sensitive
    file = File.join(@project_dir, "test.txt")
    File.write(file, "HELLO")
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "hello",
      "case_sensitive" => true
    })
    refute_match(/HELLO/, result)
  end

  def test_grep_with_context_lines
    file = File.join(@project_dir, "test.txt")
    File.write(file, "1\n2\n3\n4\n5")
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "3",
      "context_lines" => 1
    })
    assert_match(/2/, result)
    assert_match(/4/, result)
  end

  def test_grep_max_results
    3.times { |i| File.write(File.join(@project_dir, "f#{i}.txt"), "needle") }
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "needle",
      "max_results" => 2
    })
    # Should only contain 2 matches
    assert_equal 2, result.scan(/needle/).size
  end

  def test_grep_no_matches_returns_message
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "nothing"
    })
    assert_equal "No matches found", result
  end

  def test_grep_invalid_regex_returns_error
    result = tool("grep").execute({
      "file_pattern" => "*.txt",
      "search_term" => "[invalid"
    })
    assert_match(/Invalid regular expression/, result)
  end

  # --- bash ------------------------------------------------------------------
  def test_bash_executes_command
    result = tool("bash").execute({ "command" => "echo hello" })
    assert_match(/STDOUT:\nhello/, result)
    assert_match(/Exit code: 0/, result)
  end

  def test_bash_captures_stderr
    result = tool("bash").execute({ "command" => "echo error >&2" })
    assert_match(/STDERR:\nerror/, result)
  end

  def test_bash_with_cwd
    Dir.mkdir(File.join(@project_dir, "sub"))
    result = tool("bash").execute({ "command" => "pwd", "cwd" => "sub" })
    assert_match(/sub/, result)
  end

  def test_bash_timeout
    # Use a command that sleeps longer than timeout
    result = tool("bash").execute({ "command" => "sleep 2", "timeout" => 10 }) # 10ms timeout
    assert_match(/timed out/, result)
  end

  def test_bash_cwd_path_traversal_raises_error
    result = tool("bash").execute({ "command" => "pwd", "cwd" => "../../.." })
    assert_match(/outside project directory/, result)
  end

  # --- fetch -----------------------------------------------------------------
  def test_fetch_returns_string_on_network_error
    conn = stub_faraday_error(url: "http://example.com", error_class: Faraday::Error, error_message: "Network down")
    result = tool("fetch").execute({ "url" => "http://example.com" }, context: { faraday_connection: conn })
    assert_match(/HTTP error/, result)
  end

  def test_fetch_raw_format
    conn = stub_faraday_response(url: "http://example.com", body: "raw content")
    result = tool("fetch").execute({ "url" => "http://example.com", "format" => "raw" }, context: { faraday_connection: conn })
    assert_match(/Status: 200/, result)
    assert_match(/raw content/, result)
  end

  def test_fetch_html_format
    conn = stub_faraday_response(url: "http://example.com", body: "<h1>Hello</h1>")
    result = tool("fetch").execute({ "url" => "http://example.com", "format" => "html" }, context: { faraday_connection: conn })
    assert_match(/<h1>Hello<\/h1>/, result)
  end

  def test_fetch_markdown_format_strips_tags
    conn = stub_faraday_response(url: "http://example.com", body: "<p>Hello</p>")
    result = tool("fetch").execute({ "url" => "http://example.com", "format" => "markdown" }, context: { faraday_connection: conn })
    assert_match(/Hello/, result)
    refute_match(/<p>/, result)
  end

  def test_fetch_timeout
    conn = stub_faraday_error(url: "http://example.com", error_class: Faraday::TimeoutError)
    result = tool("fetch").execute({ "url" => "http://example.com" }, context: { faraday_connection: conn })
    assert_match(/HTTP error/, result)
  end
end
