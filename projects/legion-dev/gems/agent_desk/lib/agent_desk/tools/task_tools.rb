# frozen_string_literal: true

require "json"
require "securerandom"
require "time"

module AgentDesk
  module Tools
    module TaskTools
      # Lightweight in-memory task registry for a single agent run.
      # Tasks are stored as Hashes with :id, :name, :prompt, :created_at, :updated_at.
      class TaskRegistry
        def initialize
          @tasks = {}
        end

        # @return [Array<Hash>] all tasks sorted by created_at
        def list
          @tasks.values.sort_by { |t| t[:created_at] }
        end

        # @param id [String] task UUID
        # @return [Hash, nil] task hash or nil
        def get(id)
          @tasks[id]
        end

        # @param name [String] task name
        # @param prompt [String] initial user prompt
        # @return [Hash] newly created task
        def create(name:, prompt:)
          id = SecureRandom.uuid
          now = Time.now.iso8601
          task = { id: id, name: name, prompt: prompt, created_at: now, updated_at: now }
          @tasks[id] = task
          task
        end

        # @param id [String] task UUID to remove
        # @return [Boolean] true if deleted, false if not found
        def delete(id)
          !@tasks.delete(id).nil?
        end
      end

      # Factory that creates a ToolSet containing the 7 task tools.
      #
      # @param registry [TaskRegistry] optional pre-built registry (defaults to fresh; for testing)
      # @return [ToolSet] tool set with 7 task tools
      def self.create(registry: TaskRegistry.new)
        Tools.build_group(AgentDesk::TASKS_TOOL_GROUP_NAME) do
          tool name: AgentDesk::TASKS_TOOL_LIST_TASKS,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_LIST_TASKS],
               input_schema: { properties: {}, required: [] } do |args, context:|
            JSON.generate(registry.list)
          end

          tool name: AgentDesk::TASKS_TOOL_GET_TASK,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_GET_TASK],
               input_schema: {
                 properties: { id: { type: "string" } },
                 required: [ "id" ]
               } do |args, context:|
            task = registry.get(args["id"])
            task ? JSON.generate(task) : JSON.generate({ error: "task not found", id: args["id"] })
          end

          tool name: AgentDesk::TASKS_TOOL_CREATE_TASK,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_CREATE_TASK],
               input_schema: {
                 properties: {
                   name: { type: "string" },
                   prompt: { type: "string" }
                 },
                 required: %w[name prompt]
               } do |args, context:|
            task = registry.create(name: args["name"], prompt: args["prompt"])
            JSON.generate(task)
          end

          tool name: AgentDesk::TASKS_TOOL_DELETE_TASK,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_DELETE_TASK],
               input_schema: {
                 properties: { id: { type: "string" } },
                 required: [ "id" ]
               } do |args, context:|
            deleted = registry.delete(args["id"])
            JSON.generate({ deleted: deleted })
          end

          tool name: AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_GET_TASK_MESSAGE],
               input_schema: {
                 properties: {
                   taskId: { type: "string" },
                   messageIndex: { type: "integer" }
                 },
                 required: %w[taskId messageIndex]
               } do |args, context:|
            task = registry.get(args["taskId"])
            unless task
              next JSON.generate({ error: "task not found", taskId: args["taskId"] })
            end

            if args["messageIndex"] == 0
              JSON.generate({ index: 0, role: "user", content: task[:prompt] })
            else
              JSON.generate({ error: "message index out of range" })
            end
          end

          tool name: AgentDesk::TASKS_TOOL_SEARCH_TASK,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_SEARCH_TASK],
               input_schema: {
                 properties: {
                   taskId: { type: "string" },
                   query: { type: "string" }
                 },
                 required: %w[taskId query]
               } do |args, context:|
            # Stub: full semantic search deferred to future PRD (requires vector embeddings)
            JSON.generate([])
          end

          tool name: AgentDesk::TASKS_TOOL_SEARCH_PARENT_TASK,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TASKS_TOOL_SEARCH_PARENT_TASK],
               input_schema: {
                 properties: {
                   taskId: { type: "string" },
                   query: { type: "string" }
                 },
                 required: %w[taskId query]
               } do |args, context:|
            # Stub: full semantic search deferred to future PRD (requires vector embeddings)
            JSON.generate([])
          end
        end
      end
    end
  end
end
