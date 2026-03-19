# frozen_string_literal: true

require "json"

module AgentDesk
  module Tools
    module TodoTools
      # In-memory todo list state for a single agent run.
      # Not persisted — created fresh per TodoTools.create call.
      class TodoState
        # @return [Array<Hash>] current todo items (each has :name, :completed)
        attr_reader :items

        # @return [String, nil] the original user prompt that started the task
        attr_reader :initial_user_prompt

        def initialize
          @items = []
          @initial_user_prompt = nil
        end

        # Replaces the item list with the provided array.
        # @param items [Array<Hash>] each item must have "name" key; "completed" defaults to false
        # @param initial_user_prompt [String, nil] original user prompt
        # @return [void]
        def set_items(items:, initial_user_prompt: nil)
          @items = items.map { |i| { name: i["name"], completed: i.fetch("completed", false) } }
          @initial_user_prompt = initial_user_prompt
        end

        # @return [Array<Hash>] shallow copy of current items
        def get_items
          @items.dup
        end

        # Finds item by name and updates its completed flag.
        # @param name [String] item name to find
        # @param completed [Boolean] new completion status
        # @return [Hash, nil] updated item, or nil if not found
        def update_item_completion(name:, completed:)
          item = @items.find { |i| i[:name] == name }
          return nil unless item

          item[:completed] = completed
          item
        end

        # Resets all items and initial_user_prompt.
        # @return [void]
        def clear_items
          @items = []
          @initial_user_prompt = nil
        end
      end

      # Factory that creates a ToolSet containing the 4 todo tools.
      #
      # @param state [TodoState] optional pre-built state (defaults to fresh TodoState; for testing)
      # @return [ToolSet] tool set with 4 todo tools
      def self.create(state: TodoState.new)
        Tools.build_group(AgentDesk::TODO_TOOL_GROUP_NAME) do
          tool name: AgentDesk::TODO_TOOL_SET_ITEMS,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TODO_TOOL_SET_ITEMS],
               input_schema: {
                 properties: {
                   items: {
                     type: "array",
                     items: {
                       type: "object",
                       properties: {
                         name: { type: "string" },
                         completed: { type: "boolean" }
                       },
                       required: [ "name" ]
                     }
                   },
                   initialUserPrompt: { type: "string" }
                 },
                 required: [ "items" ]
               } do |args, context:|
            state.set_items(items: args.fetch("items", []), initial_user_prompt: args["initialUserPrompt"])
            JSON.generate({ set: true, count: state.items.size })
          end

          tool name: AgentDesk::TODO_TOOL_GET_ITEMS,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TODO_TOOL_GET_ITEMS],
               input_schema: { properties: {}, required: [] } do |args, context:|
            items = state.get_items
            next JSON.generate({ message: "No todo items found." }) if items.empty?

            JSON.generate(items)
          end

          tool name: AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TODO_TOOL_UPDATE_ITEM_COMPLETION],
               input_schema: {
                 properties: {
                   name: { type: "string" },
                   completed: { type: "boolean" }
                 },
                 required: %w[name completed]
               } do |args, context:|
            updated = state.update_item_completion(name: args["name"], completed: args["completed"])
            if updated
              JSON.generate({ updated: true, item: updated })
            else
              JSON.generate({ updated: false, error: "item not found" })
            end
          end

          tool name: AgentDesk::TODO_TOOL_CLEAR_ITEMS,
               description: AgentDesk::TOOL_DESCRIPTIONS[AgentDesk::TODO_TOOL_CLEAR_ITEMS],
               input_schema: { properties: {}, required: [] } do |args, context:|
            state.clear_items
            JSON.generate({ cleared: true })
          end
        end
      end
    end
  end
end
