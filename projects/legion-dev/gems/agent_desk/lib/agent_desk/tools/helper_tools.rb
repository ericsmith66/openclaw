# frozen_string_literal: true

require "json"

module AgentDesk
  module Tools
    module HelperTools
      # Factory that creates a ToolSet containing the 2 helper tools.
      #
      # @param available_tools [Array<String>] list of available tool full_names shown in error messages
      # @return [ToolSet] tool set with 2 helper tools
      def self.create(available_tools: [])
        Tools.build_group(AgentDesk::HELPERS_TOOL_GROUP_NAME) do
          tool name: AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::HELPERS_TOOL_NO_SUCH_TOOL],
               input_schema: {
                 properties: {
                   toolName: { type: "string" },
                   availableTools: { type: "array", items: { type: "string" } }
                 },
                 required: %w[toolName availableTools]
               } do |args, context:|
            tool_name = args["toolName"]
            tools_list = args.fetch("availableTools", available_tools)
            JSON.generate({
              error: "Tool '#{tool_name}' does not exist.",
              availableTools: tools_list
            })
          end

          tool name: AgentDesk::HELPERS_TOOL_INVALID_TOOL_ARGUMENTS,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::HELPERS_TOOL_INVALID_TOOL_ARGUMENTS],
               input_schema: {
                 properties: {
                   toolName: { type: "string" },
                   toolInput: { type: "string" },
                   error: { type: "string" }
                 },
                 required: %w[toolName toolInput error]
               } do |args, context:|
            JSON.generate({
              error: "Invalid arguments for tool '#{args["toolName"]}'.",
              toolInput: args["toolInput"],
              validationError: args["error"]
            })
          end
        end
      end
    end
  end
end
