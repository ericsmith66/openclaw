# frozen_string_literal: true

require "test_helper"
require "json"

class TodoToolsTest < Minitest::Test
  def setup
    @state = AgentDesk::Tools::TodoTools::TodoState.new
    @tool_set = AgentDesk::Tools::TodoTools.create(state: @state)
  end

  def tool(name)
    @tool_set[AgentDesk.tool_id(AgentDesk::TODO_TOOL_GROUP_NAME, name)]
  end

  def parse(raw)
    JSON.parse(raw, symbolize_names: true)
  end

  def test_set_items_and_get_items
    set_tool = tool(AgentDesk::TODO_TOOL_SET_ITEMS)
    get_tool = tool(AgentDesk::TODO_TOOL_GET_ITEMS)

    raw = set_tool.execute({
      "items" => [
        { "name" => "Step 1", "completed" => false },
        { "name" => "Step 2", "completed" => true }
      ],
      "initialUserPrompt" => "Do stuff"
    })
    parsed = parse(raw)
    assert_equal true, parsed[:set]
    assert_equal 2, parsed[:count]

    raw = get_tool.execute({})
    parsed = parse(raw)
    assert_equal 2, parsed.size
    assert_equal "Step 1", parsed[0][:name]
    assert_equal false, parsed[0][:completed]
    assert_equal "Step 2", parsed[1][:name]
    assert_equal true, parsed[1][:completed]
  end

  def test_set_items_overwrites_previous
    set_tool = tool(AgentDesk::TODO_TOOL_SET_ITEMS)
    get_tool = tool(AgentDesk::TODO_TOOL_GET_ITEMS)

    set_tool.execute({ "items" => [ { "name" => "Old", "completed" => false } ] })
    set_tool.execute({ "items" => [ { "name" => "New", "completed" => true } ] })

    raw = get_tool.execute({})
    parsed = parse(raw)
    assert_equal 1, parsed.size
    assert_equal "New", parsed[0][:name]
    assert_equal true, parsed[0][:completed]
  end

  def test_get_items_empty
    get_tool = tool(AgentDesk::TODO_TOOL_GET_ITEMS)
    raw = get_tool.execute({})
    parsed = parse(raw)
    assert_equal "No todo items found.", parsed[:message]
  end

  def test_update_item_completion_marks_done
    set_tool = tool(AgentDesk::TODO_TOOL_SET_ITEMS)
    update_tool = tool(AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION)
    get_tool = tool(AgentDesk::TODO_TOOL_GET_ITEMS)

    set_tool.execute({ "items" => [ { "name" => "Task", "completed" => false } ] })

    raw = update_tool.execute({ "name" => "Task", "completed" => true })
    parsed = parse(raw)
    assert_equal true, parsed[:updated]
    assert_equal "Task", parsed[:item][:name]
    assert_equal true, parsed[:item][:completed]

    raw = get_tool.execute({})
    parsed = parse(raw)
    assert_equal true, parsed[0][:completed]
  end

  def test_update_item_completion_not_found
    update_tool = tool(AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION)
    raw = update_tool.execute({ "name" => "Nonexistent", "completed" => true })
    parsed = parse(raw)
    assert_equal false, parsed[:updated]
    assert_equal "item not found", parsed[:error]
  end

  def test_clear_items
    set_tool = tool(AgentDesk::TODO_TOOL_SET_ITEMS)
    clear_tool = tool(AgentDesk::TODO_TOOL_CLEAR_ITEMS)
    get_tool = tool(AgentDesk::TODO_TOOL_GET_ITEMS)

    set_tool.execute({ "items" => [ { "name" => "Task", "completed" => false } ] })
    raw = clear_tool.execute({})
    parsed = parse(raw)
    assert_equal true, parsed[:cleared]

    raw = get_tool.execute({})
    parsed = parse(raw)
    assert_equal "No todo items found.", parsed[:message]
  end

  def test_clear_items_already_empty
    clear_tool = tool(AgentDesk::TODO_TOOL_CLEAR_ITEMS)
    raw = clear_tool.execute({})
    parsed = parse(raw)
    assert_equal true, parsed[:cleared]
  end

  def test_all_tools_exist
    expected = [
      AgentDesk::TODO_TOOL_SET_ITEMS,
      AgentDesk::TODO_TOOL_GET_ITEMS,
      AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION,
      AgentDesk::TODO_TOOL_CLEAR_ITEMS
    ]
    expected.each do |name|
      t = tool(name)
      refute_nil t, "missing tool #{name}"
      assert_kind_of AgentDesk::Tools::BaseTool, t
    end
  end
end
