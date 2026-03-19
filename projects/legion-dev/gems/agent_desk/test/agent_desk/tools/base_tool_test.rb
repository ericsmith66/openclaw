# frozen_string_literal: true

require "test_helper"

class BaseToolTest < Minitest::Test
  def build_tool(name: "bash", group_name: "power", description: "Runs a command",
                 input_schema: {}, &block)
    block ||= ->(args, context:) { "executed" }
    AgentDesk::Tools::BaseTool.new(
      name: name,
      group_name: group_name,
      description: description,
      input_schema: input_schema,
      &block
    )
  end

  # ── full_name ────────────────────────────────────────────────────────────────

  def test_full_name_format
    tool = build_tool(name: "bash", group_name: "power")
    assert_equal "power---bash", tool.full_name
  end

  def test_full_name_uses_separator_constant
    tool = build_tool(name: "read", group_name: "files")
    assert_includes tool.full_name, AgentDesk::TOOL_GROUP_NAME_SEPARATOR
  end

  # ── execute ──────────────────────────────────────────────────────────────────

  def test_execute_invokes_block
    called = false
    tool = build_tool { |args, context:| called = true; "result" }
    tool.execute
    assert called
  end

  def test_execute_returns_block_return_value
    tool = build_tool { |args, context:| 42 }
    assert_equal 42, tool.execute
  end

  def test_execute_passes_args_to_block
    received_args = nil
    tool = build_tool { |args, context:| received_args = args }
    tool.execute({ "cmd" => "ls" })
    assert_equal({ "cmd" => "ls" }, received_args)
  end

  def test_execute_passes_context_to_block
    received_context = nil
    tool = build_tool { |args, context:| received_context = context }
    tool.execute({}, context: { run_id: "abc" })
    assert_equal({ run_id: "abc" }, received_context)
  end

  def test_execute_defaults_args_to_empty_hash
    received_args = :unset
    tool = build_tool { |args, context:| received_args = args }
    tool.execute
    assert_equal({}, received_args)
  end

  def test_execute_defaults_context_to_empty_hash
    received_context = :unset
    tool = build_tool { |args, context:| received_context = context }
    tool.execute
    assert_equal({}, received_context)
  end

  def test_execute_raises_not_implemented_error_without_block
    tool = AgentDesk::Tools::BaseTool.new(
      name: "no_block", group_name: "test", description: "no block tool"
    )
    err = assert_raises(NotImplementedError) { tool.execute }
    assert_includes err.message, "No execute block provided"
  end

  # ── to_function_definition ───────────────────────────────────────────────────

  def test_to_function_definition_has_name
    tool = build_tool(name: "bash", group_name: "power")
    defn = tool.to_function_definition
    assert_equal "power---bash", defn[:name]
  end

  def test_to_function_definition_has_description
    tool = build_tool(description: "Execute a shell command")
    defn = tool.to_function_definition
    assert_equal "Execute a shell command", defn[:description]
  end

  def test_to_function_definition_has_parameters_key
    tool = build_tool
    defn = tool.to_function_definition
    assert defn.key?(:parameters), "Expected :parameters key in function definition"
  end

  def test_to_function_definition_parameters_type_is_object
    tool = build_tool
    assert_equal "object", tool.to_function_definition[:parameters][:type]
  end

  def test_to_function_definition_parameters_additional_properties_false
    tool = build_tool
    assert_equal false, tool.to_function_definition[:parameters][:additionalProperties]
  end

  def test_to_function_definition_uses_schema_properties
    schema = { properties: { command: { type: "string" } }, required: [ "command" ] }
    tool = build_tool(input_schema: schema)
    params = tool.to_function_definition[:parameters]
    assert_equal({ command: { type: "string" } }, params[:properties])
    assert_equal [ "command" ], params[:required]
  end

  def test_to_function_definition_empty_schema_defaults
    tool = build_tool(input_schema: {})
    params = tool.to_function_definition[:parameters]
    assert_equal({}, params[:properties])
    assert_equal [], params[:required]
  end

  # ── attr_readers ─────────────────────────────────────────────────────────────

  def test_name_reader
    tool = build_tool(name: "my_tool")
    assert_equal "my_tool", tool.name
  end

  def test_group_name_reader
    tool = build_tool(group_name: "my_group")
    assert_equal "my_group", tool.group_name
  end

  def test_description_reader
    tool = build_tool(description: "A description")
    assert_equal "A description", tool.description
  end

  def test_input_schema_reader
    schema = { properties: { x: { type: "integer" } } }
    tool = build_tool(input_schema: schema)
    assert_equal schema, tool.input_schema
  end

  # ── frozen attrs ─────────────────────────────────────────────────────────────

  def test_name_is_frozen
    tool = build_tool(name: "bash")
    assert tool.name.frozen?
  end

  def test_group_name_is_frozen
    tool = build_tool(group_name: "power")
    assert tool.group_name.frozen?
  end

  def test_description_is_frozen
    tool = build_tool(description: "desc")
    assert tool.description.frozen?
  end

  def test_input_schema_is_frozen
    tool = build_tool(input_schema: { properties: {} })
    assert tool.input_schema.frozen?
  end

  def test_input_schema_nested_properties_hash_is_frozen
    schema = { properties: { command: { type: "string" } }, required: [ "command" ] }
    tool = build_tool(input_schema: schema)
    assert tool.input_schema[:properties].frozen?,
           "Expected input_schema[:properties] to be frozen"
  end

  def test_input_schema_nested_property_value_hash_is_frozen
    schema = { properties: { command: { type: "string" } } }
    tool = build_tool(input_schema: schema)
    assert tool.input_schema[:properties][:command].frozen?,
           "Expected input_schema[:properties][:command] to be frozen"
  end

  def test_input_schema_required_array_is_frozen
    schema = { properties: {}, required: [ "command", "flags" ] }
    tool = build_tool(input_schema: schema)
    assert tool.input_schema[:required].frozen?,
           "Expected input_schema[:required] to be frozen"
  end

  def test_input_schema_nested_strings_are_frozen
    schema = { properties: { cmd: { type: "string", description: "The command" } } }
    tool = build_tool(input_schema: schema)
    type_value = tool.input_schema[:properties][:cmd][:type]
    assert type_value.frozen?, "Expected nested String values to be frozen"
  end

  def test_input_schema_deep_freeze_prevents_mutation_of_nested_hash
    schema = { properties: { cmd: { type: "string" } }, required: [] }
    tool = build_tool(input_schema: schema)
    assert_raises(FrozenError) do
      tool.input_schema[:properties][:cmd][:injected] = "bad"
    end
  end

  def test_input_schema_deep_freeze_prevents_mutation_of_required_array
    schema = { properties: {}, required: [ "cmd" ] }
    tool = build_tool(input_schema: schema)
    assert_raises(FrozenError) do
      tool.input_schema[:required] << "injected"
    end
  end
end
