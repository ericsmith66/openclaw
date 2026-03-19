# PRD-0110: Todo, Task & Helper Tool Groups

**PRD ID**: PRD-0110
**Status**: Draft
**Priority**: Medium
**Created**: 2026-02-26
**Milestone**: M6 (Full Parity)
**Depends On**: PRD-0020

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/tools/todo.ts` — `createTodoToolset` (set_items, get_items, update_item_completion, clear_items)
- `src/main/agent/tools/tasks.ts` — `createTasksToolset` (list_tasks, get_task, create_task, delete_task, etc.)
- `src/main/agent/tools/helpers.ts` — `createHelpersToolset` (no_such_tool, invalid_tool_arguments)
- `src/common/tools.ts` — All `TODO_TOOL_*`, `TASKS_TOOL_*`, `HELPERS_TOOL_*` constants

**Output Files** (Ruby):
- `lib/agent_desk/tools/todo_tools.rb`
- `lib/agent_desk/tools/task_tools.rb`
- `lib/agent_desk/tools/helper_tools.rb`
- `spec/agent_desk/tools/todo_tools_spec.rb`
- `spec/agent_desk/tools/helper_tools_spec.rb`

---

## 1. Problem Statement

Three remaining tool groups needed for full parity:

### Todo Tools
In-memory task tracking within a single agent run. The LLM uses these to manage complex multi-step work:
- **set_items** — Initialize a todo list
- **get_items** — Retrieve current items and completion status
- **update_item_completion** — Mark an item done
- **clear_items** — Reset the list

### Task Tools
Multi-task management (creating/listing/querying tasks). In AiderDesk these interact with the task database. For the Ruby framework, we provide a simpler in-memory or file-based task registry:
- **list_tasks** — List all tasks
- **get_task** — Get task details
- **create_task** — Create a new task
- **delete_task** — Delete a task
- **search_task** — Search within a task

### Helper Tools
Error recovery tools that help the LLM when it calls a non-existent tool or provides invalid arguments:
- **no_such_tool** — Returns available tool names
- **invalid_tool_arguments** — Returns the error and expected schema

---

## 2. Design

### 2.1 Todo Tools

```ruby
# lib/agent_desk/tools/todo_tools.rb
module AgentDesk
  module Tools
    module TodoTools
      def self.create
        items = []        # Mutable state for the run
        initial_prompt = nil

        Tools.build_group(TODO_TOOL_GROUP_NAME) do
          tool TODO_TOOL_SET_ITEMS,
               description: TOOL_DESCRIPTIONS[TODO_TOOL_SET_ITEMS],
               input_schema: {
                 properties: {
                   items: { type: 'array', items: {
                     type: 'object',
                     properties: { name: { type: 'string' }, completed: { type: 'boolean', default: false } },
                     required: ['name']
                   }},
                   initial_user_prompt: { type: 'string' }
                 },
                 required: %w[items initial_user_prompt]
               } do |args, _ctx|
            items.replace(args['items'].map { |i| { name: i['name'], completed: i.fetch('completed', false) } })
            initial_prompt = args['initial_user_prompt']
            "Todo items set successfully."
          end

          tool TODO_TOOL_GET_ITEMS,
               description: TOOL_DESCRIPTIONS[TODO_TOOL_GET_ITEMS],
               input_schema: {} do |_args, _ctx|
            items.empty? ? 'No todo items found.' : items
          end

          tool TODO_TOOL_UPDATE_ITEM_COMPLETION,
               description: TOOL_DESCRIPTIONS[TODO_TOOL_UPDATE_ITEM_COMPLETION],
               input_schema: {
                 properties: {
                   name: { type: 'string' },
                   completed: { type: 'boolean' }
                 },
                 required: %w[name completed]
               } do |args, _ctx|
            item = items.find { |i| i[:name] == args['name'] }
            if item
              item[:completed] = args['completed']
              items
            else
              "Todo item '#{args['name']}' not found."
            end
          end

          tool TODO_TOOL_CLEAR_ITEMS,
               description: TOOL_DESCRIPTIONS[TODO_TOOL_CLEAR_ITEMS],
               input_schema: {} do |_args, _ctx|
            items.clear
            initial_prompt = nil
            'All todo items cleared successfully.'
          end
        end
      end
    end
  end
end
```

### 2.2 Helper Tools

```ruby
# lib/agent_desk/tools/helper_tools.rb
module AgentDesk
  module Tools
    module HelperTools
      def self.create
        Tools.build_group(HELPERS_TOOL_GROUP_NAME) do
          tool HELPERS_TOOL_NO_SUCH_TOOL,
               description: 'Internal helper tool to inform the LLM that a requested tool does not exist.',
               input_schema: {
                 properties: {
                   tool_name: { type: 'string' },
                   available_tools: { type: 'array', items: { type: 'string' } }
                 },
                 required: %w[tool_name available_tools]
               } do |args, _ctx|
            "Tool '#{args['tool_name']}' does not exist. Available tools: #{args['available_tools'].join(', ')}"
          end

          tool HELPERS_TOOL_INVALID_TOOL_ARGUMENTS,
               description: 'Internal helper tool to inform the LLM of invalid tool arguments.',
               input_schema: {
                 properties: {
                   tool_name: { type: 'string' },
                   tool_input: { type: 'string' },
                   error: { type: 'string' }
                 },
                 required: %w[tool_name tool_input error]
               } do |args, _ctx|
            "Invalid arguments for '#{args['tool_name']}': #{args['error']}. Input was: #{args['tool_input']}"
          end
        end
      end
    end
  end
end
```

### 2.3 Task Tools (simplified)

For the Ruby framework, tasks are in-memory data structures (not a full database):

```ruby
# lib/agent_desk/tools/task_tools.rb
module AgentDesk
  module Tools
    module TaskTools
      def self.create(task_registry: {})
        Tools.build_group(TASKS_TOOL_GROUP_NAME) do
          tool TASKS_TOOL_LIST_TASKS,
               description: TOOL_DESCRIPTIONS[TASKS_TOOL_LIST_TASKS],
               input_schema: {} do |_args, _ctx|
            task_registry.values.map { |t| { id: t[:id], name: t[:name], state: t[:state] } }
          end

          tool TASKS_TOOL_CREATE_TASK,
               description: TOOL_DESCRIPTIONS[TASKS_TOOL_CREATE_TASK],
               input_schema: {
                 properties: {
                   name: { type: 'string' },
                   prompt: { type: 'string' }
                 },
                 required: %w[name prompt]
               } do |args, _ctx|
            id = SecureRandom.uuid
            task_registry[id] = { id: id, name: args['name'], prompt: args['prompt'], state: 'TODO', messages: [] }
            { id: id, created: true }
          end

          tool TASKS_TOOL_GET_TASK,
               description: TOOL_DESCRIPTIONS[TASKS_TOOL_GET_TASK],
               input_schema: {
                 properties: { task_id: { type: 'string' } },
                 required: ['task_id']
               } do |args, _ctx|
            task_registry[args['task_id']] || "Task '#{args['task_id']}' not found."
          end

          tool TASKS_TOOL_DELETE_TASK,
               description: TOOL_DESCRIPTIONS[TASKS_TOOL_DELETE_TASK],
               input_schema: {
                 properties: { task_id: { type: 'string' } },
                 required: ['task_id']
               } do |args, _ctx|
            if task_registry.delete(args['task_id'])
              { deleted: true }
            else
              "Task '#{args['task_id']}' not found."
            end
          end
        end
      end
    end
  end
end
```

---

## 3. Acceptance Criteria

- ✅ Todo tools maintain state within a single agent run
- ✅ `set_items` + `get_items` round-trips correctly
- ✅ `update_item_completion` modifies the right item
- ✅ `clear_items` resets everything
- ✅ Helper tools return formatted error messages for missing/invalid tools
- ✅ Task tools support basic CRUD on an in-memory registry
- ✅ All tools have proper descriptions and input schemas

---

## 4. Test Plan

```ruby
RSpec.describe AgentDesk::Tools::TodoTools do
  let(:tool_set) { described_class.create }

  it 'manages a todo list lifecycle' do
    set_tool = tool_set[AgentDesk.tool_id('todo', 'set_items')]
    get_tool = tool_set[AgentDesk.tool_id('todo', 'get_items')]
    update_tool = tool_set[AgentDesk.tool_id('todo', 'update_item_completion')]

    set_tool.execute({ 'items' => [{ 'name' => 'Step 1' }], 'initial_user_prompt' => 'Do stuff' })
    items = get_tool.execute({})
    expect(items.size).to eq(1)
    expect(items.first[:completed]).to be false

    update_tool.execute({ 'name' => 'Step 1', 'completed' => true })
    items = get_tool.execute({})
    expect(items.first[:completed]).to be true
  end
end

RSpec.describe AgentDesk::Tools::HelperTools do
  let(:tool_set) { described_class.create }

  it 'reports missing tools' do
    tool = tool_set[AgentDesk.tool_id('helpers', 'no_such_tool')]
    result = tool.execute({ 'tool_name' => 'fake_tool', 'available_tools' => ['power---bash'] })
    expect(result).to include('fake_tool')
    expect(result).to include('power---bash')
  end
end
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `TodoTools.create` | `createTodoToolset()` |
| `HelperTools.create` | `createHelpersToolset()` |
| `TaskTools.create` | `createTasksToolset()` |
| Todo state (array) | `task.todoItems` state |
| Task registry (hash) | Full `Task` class + database |
| Helper error formatting | `NoSuchToolError` / `InvalidToolInputError` handling in `repairToolCall` |

---

**This completes the PRD inventory for the Ruby Agent Framework epic.**
