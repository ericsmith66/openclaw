# frozen_string_literal: true

module AgentDesk
  module Tools
    # Represents a single tool that can be called by the LLM.
    #
    # A BaseTool encapsulates a name, group, description, JSON Schema for its
    # input, and an execute block. Tools are passive objects — they do not
    # initiate LLM calls. They get collected into {ToolSet}s and passed to the
    # LLM as function definitions.
    class BaseTool
      # @return [String] the tool's short name (e.g., "bash")
      attr_reader :name

      # @return [String] the tool group name (e.g., "power")
      attr_reader :group_name

      # @return [String] human-readable description shown to the LLM
      attr_reader :description

      # @return [Hash] JSON Schema fragment for the tool's input parameters
      attr_reader :input_schema

      # @param name [String] short tool name
      # @param group_name [String] tool group name
      # @param description [String] LLM-facing description
      # @param input_schema [Hash] JSON Schema for input (optional)
      # @param execute_block [Proc, nil] block to invoke when the tool is called
      def initialize(name:, group_name:, description:, input_schema: {}, &execute_block)
        @name = name.freeze
        @group_name = group_name.freeze
        @description = description.freeze
        @input_schema = deep_freeze(input_schema)
        @execute_block = execute_block
      end

      # Returns the fully-qualified tool identifier in "group---name" format.
      #
      # @return [String] e.g. "power---bash"
      def full_name
        AgentDesk.tool_id(group_name, name)
      end

      # Invokes the tool's execute block with the given arguments and context.
      #
      # @param args [Hash] tool arguments (matching the input_schema)
      # @param context [Hash] contextual data passed by the runner
      # @return [Object] whatever the execute block returns
      # @raise [NotImplementedError] if no execute block was provided
      def execute(args = {}, context: {})
        raise NotImplementedError, "No execute block provided for tool '#{full_name}'" unless @execute_block

        @execute_block.call(args, context: context)
      end

      # Returns an OpenAI-compatible function definition hash for this tool.
      #
      # @return [Hash] function definition with :name, :description, :parameters
      def to_function_definition
        {
          name: full_name,
          description: description,
          parameters: {
            type: "object",
            properties: input_schema.fetch(:properties, {}),
            required: input_schema.fetch(:required, []),
            additionalProperties: false
          }
        }
      end

      private

      # Recursively freezes a Hash or Array and all nested values.
      # Strings, Symbols, Integers, and other immutable types are left as-is.
      #
      # @param obj [Object] the object to deep-freeze
      # @return [Object] the frozen object
      def deep_freeze(obj)
        case obj
        when Hash
          obj.each_value { |v| deep_freeze(v) }
          obj.freeze
        when Array
          obj.each { |v| deep_freeze(v) }
          obj.freeze
        when String
          obj.freeze
        else
          obj
        end
      end
    end
  end
end
