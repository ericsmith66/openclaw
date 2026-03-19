# frozen_string_literal: true

require "test_helper"
require "tempfile"
require "json"

class MemoryToolsTest < Minitest::Test
  def setup
    @tempfile = Tempfile.new([ "memory", ".json" ])
    File.write(@tempfile.path, "[]")
    @memory_store = AgentDesk::Memory::MemoryStore.new(storage_path: @tempfile.path)
    @tool_set = AgentDesk::Tools::MemoryTools.create(memory_store: @memory_store)
  end

  def teardown
    @tempfile.close
    @tempfile.unlink
  end

  def tool(name)
    @tool_set[AgentDesk.tool_id(AgentDesk::MEMORY_TOOL_GROUP_NAME, name)]
  end

  def parse_result(result)
    JSON.parse(result, symbolize_names: true)
  end

  def test_store_tool
    t = tool(AgentDesk::MEMORY_TOOL_STORE)
    refute_nil t

    raw = t.execute(
      { "type" => "user-preference", "content" => "likes cats" },
      context: {}
    )
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert parsed[:stored]
    assert_match(/\A[0-9a-f\-]{36}\z/, parsed[:id])

    memories = @memory_store.list
    assert_equal 1, memories.size
    assert_equal "likes cats", memories.first.content
  end

  def test_retrieve_tool
    memory = @memory_store.store(type: "task", content: "implement memory tools")
    t = tool(AgentDesk::MEMORY_TOOL_RETRIEVE)
    refute_nil t

    raw = t.execute({ "query" => "memory tools" }, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert_equal 1, parsed.size
    assert_equal memory.id, parsed.first[:id]
    assert_equal "task", parsed.first[:type]
    assert_equal "implement memory tools", parsed.first[:content]

    # with limit
    @memory_store.store(type: "task", content: "another memory tool")
    raw = t.execute({ "query" => "memory", "limit" => 1 }, context: {})
    parsed = parse_result(raw)
    assert_equal 1, parsed.size
  end

  def test_delete_tool
    memory = @memory_store.store(type: "task", content: "delete me")
    t = tool(AgentDesk::MEMORY_TOOL_DELETE)
    refute_nil t

    raw = t.execute({ "id" => memory.id }, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert parsed[:deleted]
    assert_empty @memory_store.list

    # deleting non‑existent ID still returns deleted: true
    raw = t.execute({ "id" => "non-existent" }, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert parsed[:deleted]
  end

  def test_list_tool
    @memory_store.store(type: "task", content: "task 1")
    @memory_store.store(type: "user-preference", content: "pref")
    t = tool(AgentDesk::MEMORY_TOOL_LIST)
    refute_nil t

    raw = t.execute({}, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert_equal 2, parsed.size

    raw = t.execute({ "type" => "task" }, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert_equal 1, parsed.size
    assert_equal "task", parsed.first[:type]
  end

  def test_update_tool
    memory = @memory_store.store(type: "user-preference", content: "old")
    t = tool(AgentDesk::MEMORY_TOOL_UPDATE)
    refute_nil t

    raw = t.execute({ "id" => memory.id, "content" => "new" }, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    assert parsed[:updated]
    assert_equal "new", parsed[:memory][:content]

    memories = @memory_store.list
    assert_equal "new", memories.first.content

    # non‑existent ID
    raw = t.execute({ "id" => "non-existent", "content" => "new" }, context: {})
    assert_kind_of String, raw
    parsed = parse_result(raw)
    refute parsed[:updated]
    assert_equal "Memory not found", parsed[:error]
  end

  def test_tools_integration
    # Ensure all five tools are present in the tool set
    expected = [
      AgentDesk::MEMORY_TOOL_STORE,
      AgentDesk::MEMORY_TOOL_RETRIEVE,
      AgentDesk::MEMORY_TOOL_DELETE,
      AgentDesk::MEMORY_TOOL_LIST,
      AgentDesk::MEMORY_TOOL_UPDATE
    ]
    expected.each do |name|
      t = tool(name)
      refute_nil t, "missing tool #{name}"
      assert_kind_of AgentDesk::Tools::BaseTool, t
    end
  end
end
