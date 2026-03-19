# frozen_string_literal: true

require "json"

module AgentDesk
  module Tools
    # Factory for the memory tool group (store, retrieve, delete, list, update).
    module MemoryTools
      # Factory that creates a ToolSet containing the 5 memory tools.
      #
      # @param memory_store [AgentDesk::Memory::MemoryStore] memory store instance
      # @param project_id [String, nil] optional project ID for scoped memories
      # @return [ToolSet] tool set with 5 memory tools
      def self.create(memory_store:, project_id: nil)
        Tools.build_group(AgentDesk::MEMORY_TOOL_GROUP_NAME) do
          tool name: AgentDesk::MEMORY_TOOL_STORE,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::MEMORY_TOOL_STORE],
               input_schema: {
                 properties: {
                   type: { type: "string", enum: %w[task user-preference code-pattern] },
                   content: { type: "string" }
                 },
                 required: %w[type content]
               } do |args, context:|
            memory = memory_store.store(type: args["type"], content: args["content"], project_id: project_id)
            JSON.generate({ id: memory.id, stored: true })
          end

          tool name: AgentDesk::MEMORY_TOOL_RETRIEVE,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::MEMORY_TOOL_RETRIEVE],
               input_schema: {
                 properties: {
                   query: { type: "string" },
                   limit: { type: "integer", default: 3 }
                 },
                 required: [ "query" ]
               } do |args, context:|
            results = memory_store.retrieve(query: args["query"], limit: args.fetch("limit", 3), project_id: project_id)
            JSON.generate(results.map(&:to_h))
          end

          tool name: AgentDesk::MEMORY_TOOL_DELETE,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::MEMORY_TOOL_DELETE],
               input_schema: {
                 properties: { id: { type: "string" } },
                 required: [ "id" ]
               } do |args, context:|
            memory_store.delete(id: args["id"])
            JSON.generate({ deleted: true })
          end

          tool name: AgentDesk::MEMORY_TOOL_LIST,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::MEMORY_TOOL_LIST],
               input_schema: {
                 properties: {
                   type: { type: "string" }
                 },
                 required: []
               } do |args, context:|
            JSON.generate(memory_store.list(type: args["type"], project_id: project_id).map(&:to_h))
          end

          tool name: AgentDesk::MEMORY_TOOL_UPDATE,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::MEMORY_TOOL_UPDATE],
               input_schema: {
                 properties: {
                   id: { type: "string" },
                   content: { type: "string" }
                 },
                 required: %w[id content]
               } do |args, context:|
            updated = memory_store.update(id: args["id"], content: args["content"])
            JSON.generate(updated ? { updated: true, memory: updated.to_h } : { updated: false, error: "Memory not found" })
          end
        end
      end
    end
  end
end
