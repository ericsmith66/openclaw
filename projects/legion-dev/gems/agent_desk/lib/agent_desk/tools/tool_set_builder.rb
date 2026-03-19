# frozen_string_literal: true

module AgentDesk
  module Tools
    # DSL builder for constructing a {ToolSet} for a named tool group.
    #
    # Typically used via the {Tools.build_group} module method:
    #
    #   my_tools = AgentDesk::Tools.build_group('power') do
    #     tool name: 'bash',
    #          description: 'Executes a shell command',
    #          input_schema: { properties: { command: { type: 'string' } }, required: ['command'] } do |args, context:|
    #       system(args['command'])
    #     end
    #   end
    class ToolSetBuilder
      # @param group_name [String] the tool group name for all tools in this builder
      def initialize(group_name)
        @group_name = group_name
        @tool_set = ToolSet.new
      end

      # Defines a tool within the group and adds it to the set being built.
      #
      # @param name [String] tool short name
      # @param description [String] LLM-facing description
      # @param input_schema [Hash] JSON Schema for input parameters
      # @param block [Proc] execute block for the tool
      # @return [BaseTool] the created tool
      def tool(name:, description:, input_schema: {}, &block)
        t = BaseTool.new(
          name: name,
          group_name: @group_name,
          description: description,
          input_schema: input_schema,
          &block
        )
        @tool_set.add(t)
        t
      end

      # Returns the built {ToolSet}.
      #
      # @return [ToolSet]
      def build
        @tool_set
      end
    end

    # DSL entry point for building a tool group.
    #
    # @param group_name [String] the tool group name
    # @yield block evaluated in the context of a {ToolSetBuilder}
    # @return [ToolSet] the constructed tool set
    def self.build_group(group_name, &block)
      builder = ToolSetBuilder.new(group_name)
      builder.instance_eval(&block) if block
      builder.build
    end
  end
end
