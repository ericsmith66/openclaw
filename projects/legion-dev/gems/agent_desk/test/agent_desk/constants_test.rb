# frozen_string_literal: true

require "test_helper"

class ConstantsTest < Minitest::Test
  def test_defines_tool_group_separator
    assert_equal "---", AgentDesk::TOOL_GROUP_NAME_SEPARATOR
  end

  def test_builds_fully_qualified_tool_ids
    assert_equal "power---bash", AgentDesk.tool_id("power", "bash")
  end

  def test_defines_all_power_tool_names
    assert_equal "file_read", AgentDesk::POWER_TOOL_FILE_READ
    assert_equal "bash", AgentDesk::POWER_TOOL_BASH
  end

  def test_defines_all_tool_group_names
    assert_equal "---", AgentDesk::TOOL_GROUP_NAME_SEPARATOR
    assert_equal "aider", AgentDesk::AIDER_TOOL_GROUP_NAME
    assert_equal "helpers", AgentDesk::HELPERS_TOOL_GROUP_NAME
    assert_equal "power", AgentDesk::POWER_TOOL_GROUP_NAME
    assert_equal "subagents", AgentDesk::SUBAGENTS_TOOL_GROUP_NAME
    assert_equal "skills", AgentDesk::SKILLS_TOOL_GROUP_NAME
    assert_equal "todo", AgentDesk::TODO_TOOL_GROUP_NAME
    assert_equal "memory", AgentDesk::MEMORY_TOOL_GROUP_NAME
    assert_equal "tasks", AgentDesk::TASKS_TOOL_GROUP_NAME
  end

  def test_defines_all_tool_names
    # Aider tools
    assert_equal "get_context_files", AgentDesk::AIDER_TOOL_GET_CONTEXT_FILES
    assert_equal "add_context_files", AgentDesk::AIDER_TOOL_ADD_CONTEXT_FILES
    assert_equal "drop_context_files", AgentDesk::AIDER_TOOL_DROP_CONTEXT_FILES
    assert_equal "run_prompt", AgentDesk::AIDER_TOOL_RUN_PROMPT

    # Helpers tools
    assert_equal "no_such_tool", AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL
    assert_equal "invalid_tool_arguments", AgentDesk::HELPERS_TOOL_INVALID_TOOL_ARGUMENTS

    # Power tools
    assert_equal "file_edit", AgentDesk::POWER_TOOL_FILE_EDIT
    assert_equal "file_read", AgentDesk::POWER_TOOL_FILE_READ
    assert_equal "file_write", AgentDesk::POWER_TOOL_FILE_WRITE
    assert_equal "glob", AgentDesk::POWER_TOOL_GLOB
    assert_equal "grep", AgentDesk::POWER_TOOL_GREP
    assert_equal "semantic_search", AgentDesk::POWER_TOOL_SEMANTIC_SEARCH
    assert_equal "bash", AgentDesk::POWER_TOOL_BASH
    assert_equal "fetch", AgentDesk::POWER_TOOL_FETCH

    # Subagents tools
    assert_equal "run_task", AgentDesk::SUBAGENTS_TOOL_RUN_TASK

    # Skills tools
    assert_equal "activate_skill", AgentDesk::SKILLS_TOOL_ACTIVATE_SKILL

    # Todo tools
    assert_equal "set_items", AgentDesk::TODO_TOOL_SET_ITEMS
    assert_equal "get_items", AgentDesk::TODO_TOOL_GET_ITEMS
    assert_equal "update_item_completion", AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION
    assert_equal "clear_items", AgentDesk::TODO_TOOL_CLEAR_ITEMS

    # Memory tools
    assert_equal "store_memory", AgentDesk::MEMORY_TOOL_STORE
    assert_equal "retrieve_memory", AgentDesk::MEMORY_TOOL_RETRIEVE
    assert_equal "delete_memory", AgentDesk::MEMORY_TOOL_DELETE
    assert_equal "list_memories", AgentDesk::MEMORY_TOOL_LIST
    assert_equal "update_memory", AgentDesk::MEMORY_TOOL_UPDATE

    # Tasks tools
    assert_equal "list_tasks", AgentDesk::TASKS_TOOL_LIST_TASKS
    assert_equal "get_task", AgentDesk::TASKS_TOOL_GET_TASK
    assert_equal "get_task_message", AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE
    assert_equal "create_task", AgentDesk::TASKS_TOOL_CREATE_TASK
    assert_equal "delete_task", AgentDesk::TASKS_TOOL_DELETE_TASK
    assert_equal "search_task", AgentDesk::TASKS_TOOL_SEARCH_TASK
    assert_equal "search_parent_task", AgentDesk::TASKS_TOOL_SEARCH_PARENT_TASK
  end

  def test_tool_id_edge_cases
    # nil arguments become empty strings
    assert_equal "---", AgentDesk.tool_id(nil, nil)
    # empty strings
    assert_equal "---", AgentDesk.tool_id("", "")
    # mixed
    assert_equal "group---", AgentDesk.tool_id("group", "")
    assert_equal "---name", AgentDesk.tool_id("", "name")
    # preserves separator
    assert_equal "power---bash", AgentDesk.tool_id("power", "bash")
    # non-string arguments convert to string via to_s
    assert_equal "symbol---123", AgentDesk.tool_id(:symbol, 123)
  end

  def test_tool_descriptions_is_frozen_hash
    assert_instance_of Hash, AgentDesk::TOOL_DESCRIPTIONS
    assert_predicate AgentDesk::TOOL_DESCRIPTIONS, :frozen?
  end

  def test_tool_descriptions_covers_all_aider_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::AIDER_TOOL_GET_CONTEXT_FILES)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::AIDER_TOOL_ADD_CONTEXT_FILES)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::AIDER_TOOL_DROP_CONTEXT_FILES)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::AIDER_TOOL_RUN_PROMPT)
  end

  def test_tool_descriptions_covers_all_power_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_FILE_EDIT)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_FILE_READ)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_FILE_WRITE)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_GLOB)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_GREP)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_SEMANTIC_SEARCH)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_BASH)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::POWER_TOOL_FETCH)
  end

  def test_tool_descriptions_covers_all_todo_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TODO_TOOL_SET_ITEMS)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TODO_TOOL_GET_ITEMS)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TODO_TOOL_CLEAR_ITEMS)
  end

  def test_tool_descriptions_covers_all_memory_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::MEMORY_TOOL_STORE)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::MEMORY_TOOL_RETRIEVE)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::MEMORY_TOOL_DELETE)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::MEMORY_TOOL_LIST)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::MEMORY_TOOL_UPDATE)
  end

  def test_tool_descriptions_covers_all_tasks_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_LIST_TASKS)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_GET_TASK)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_CREATE_TASK)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_DELETE_TASK)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_SEARCH_TASK)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::TASKS_TOOL_SEARCH_PARENT_TASK)
  end

  def test_tool_descriptions_covers_subagents_and_skills_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::SUBAGENTS_TOOL_RUN_TASK)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::SKILLS_TOOL_ACTIVATE_SKILL)
  end

  def test_tool_descriptions_covers_helpers_tools
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL)
    assert AgentDesk::TOOL_DESCRIPTIONS.key?(AgentDesk::HELPERS_TOOL_INVALID_TOOL_ARGUMENTS)
  end

  def test_all_tool_descriptions_are_non_empty_strings
    AgentDesk::TOOL_DESCRIPTIONS.each do |tool_name, description|
      assert_instance_of String, description, "Description for #{tool_name} should be a String"
      refute_empty description, "Description for #{tool_name} should not be empty"
    end
  end

  def test_tool_descriptions_bash_content
    desc = AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::POWER_TOOL_BASH]
    assert_includes desc, "shell command"
  end
end
