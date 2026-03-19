# PRD-0010: Core Types, Constants & Project Scaffold

**PRD ID**: PRD-0010
**Status**: Draft
**Priority**: Critical
**Created**: 2026-02-26
**Milestone**: M0 (Scaffold)
**Depends On**: —

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/common/tools.ts` — All tool group names, tool names, separator constant, descriptions
- `src/common/types.ts` — `ToolApprovalState`, `AgentProfile` interface, `ContextMessage`, etc.
- `src/common/agent.ts` — `LlmProviderName`, `DEFAULT_AGENT_PROFILE`, provider type unions

**Output Files** (Ruby):
- `lib/agent_desk.rb` — Main entry point, autoloads
- `lib/agent_desk/version.rb`
- `lib/agent_desk/constants.rb` — Tool group names, tool names, separator
- `lib/agent_desk/types.rb` — Enums, structs, type aliases
- `agent_desk.gemspec`
- `Gemfile`
- `spec/spec_helper.rb`
- `spec/agent_desk/constants_spec.rb`
- `spec/agent_desk/types_spec.rb`

---

## 1. Problem Statement

We need a Ruby gem skeleton that all subsequent PRDs build upon. This includes:
1. A properly structured gem with autoloading
2. All tool constants ported from AiderDesk (group names, tool names, separator)
3. Core type definitions (enums, data classes) matching AiderDesk's type system
4. A test harness ready for RSpec

Without this foundation, no other PRD can proceed.

---

## 2. Design

### 2.1 Directory Layout

```
agent_desk/
├── lib/
│   └── agent_desk/
│       ├── version.rb
│       ├── constants.rb
│       └── types.rb
│   └── agent_desk.rb          # Main require, autoloads
├── spec/
│   ├── spec_helper.rb
│   └── agent_desk/
│       ├── constants_spec.rb
│       └── types_spec.rb
├── Gemfile
├── agent_desk.gemspec
├── .rubocop.yml
├── .rspec
└── README.md
```

### 2.2 Constants (from `src/common/tools.ts`)

```ruby
# lib/agent_desk/constants.rb
module AgentDesk
  TOOL_GROUP_NAME_SEPARATOR = '---'

  # Aider tool group
  AIDER_TOOL_GROUP_NAME = 'aider'
  AIDER_TOOL_GET_CONTEXT_FILES = 'get_context_files'
  AIDER_TOOL_ADD_CONTEXT_FILES = 'add_context_files'
  AIDER_TOOL_DROP_CONTEXT_FILES = 'drop_context_files'
  AIDER_TOOL_RUN_PROMPT = 'run_prompt'

  # Helpers tool group
  HELPERS_TOOL_GROUP_NAME = 'helpers'
  HELPERS_TOOL_NO_SUCH_TOOL = 'no_such_tool'
  HELPERS_TOOL_INVALID_TOOL_ARGUMENTS = 'invalid_tool_arguments'

  # Power tool group
  POWER_TOOL_GROUP_NAME = 'power'
  POWER_TOOL_FILE_EDIT = 'file_edit'
  POWER_TOOL_FILE_READ = 'file_read'
  POWER_TOOL_FILE_WRITE = 'file_write'
  POWER_TOOL_GLOB = 'glob'
  POWER_TOOL_GREP = 'grep'
  POWER_TOOL_SEMANTIC_SEARCH = 'semantic_search'
  POWER_TOOL_BASH = 'bash'
  POWER_TOOL_FETCH = 'fetch'

  # Subagents tool group
  SUBAGENTS_TOOL_GROUP_NAME = 'subagents'
  SUBAGENTS_TOOL_RUN_TASK = 'run_task'

  # Skills tool group
  SKILLS_TOOL_GROUP_NAME = 'skills'
  SKILLS_TOOL_ACTIVATE_SKILL = 'activate_skill'

  # Todo tool group
  TODO_TOOL_GROUP_NAME = 'todo'
  TODO_TOOL_SET_ITEMS = 'set_items'
  TODO_TOOL_GET_ITEMS = 'get_items'
  TODO_TOOL_UPDATE_ITEM_COMPLETION = 'update_item_completion'
  TODO_TOOL_CLEAR_ITEMS = 'clear_items'

  # Memory tool group
  MEMORY_TOOL_GROUP_NAME = 'memory'
  MEMORY_TOOL_STORE = 'store_memory'
  MEMORY_TOOL_RETRIEVE = 'retrieve_memory'
  MEMORY_TOOL_DELETE = 'delete_memory'
  MEMORY_TOOL_LIST = 'list_memories'
  MEMORY_TOOL_UPDATE = 'update_memory'

  # Tasks tool group
  TASKS_TOOL_GROUP_NAME = 'tasks'
  TASKS_TOOL_LIST_TASKS = 'list_tasks'
  TASKS_TOOL_GET_TASK = 'get_task'
  TASKS_TOOL_GET_TASK_MESSAGE = 'get_task_message'
  TASKS_TOOL_CREATE_TASK = 'create_task'
  TASKS_TOOL_DELETE_TASK = 'delete_task'
  TASKS_TOOL_SEARCH_TASK = 'search_task'
  TASKS_TOOL_SEARCH_PARENT_TASK = 'search_parent_task'

  # Helper: build a fully qualified tool ID
  def self.tool_id(group, name)
    "#{group}#{TOOL_GROUP_NAME_SEPARATOR}#{name}"
  end
end
```

### 2.3 Types (from `src/common/types.ts`)

Port key enums and data structures as Ruby modules/classes:

```ruby
# lib/agent_desk/types.rb
module AgentDesk
  module ToolApprovalState
    ALWAYS = 'always'
    ASK    = 'ask'
    NEVER  = 'never'
  end

  module ReasoningEffort
    NONE   = 'none'
    LOW    = 'low'
    MEDIUM = 'medium'
    HIGH   = 'high'
  end

  module ContextMemoryMode
    OFF       = 'off'
    RELEVANT  = 'relevant'
    FULL      = 'full'
  end

  module InvocationMode
    ON_DEMAND = 'on_demand'
    ALWAYS    = 'always'
  end

  # Lightweight data class for context messages
  ContextMessage = Data.define(:id, :role, :content, :prompt_context)

  # Lightweight data class for context files
  ContextFile = Data.define(:path, :read_only) do
    def initialize(path:, read_only: false)
      super
    end
  end

  # Subagent configuration (nested in profile)
  SubagentConfig = Data.define(
    :enabled, :system_prompt, :invocation_mode, :color, :description, :context_memory
  ) do
    def initialize(
      enabled: false,
      system_prompt: '',
      invocation_mode: InvocationMode::ON_DEMAND,
      color: '#3368a8',
      description: '',
      context_memory: ContextMemoryMode::OFF
    )
      super
    end
  end
end
```

### 2.4 Tool Descriptions

A frozen hash mapping tool names to their description strings (ported from `tools.ts`). These are used later by the prompt system and tool registration.

```ruby
module AgentDesk
  TOOL_DESCRIPTIONS = {
    AIDER_TOOL_GET_CONTEXT_FILES => 'Get all files currently in the context...',
    AIDER_TOOL_RUN_PROMPT => 'Delegates a natural language coding task...',
    # ... all descriptions from tools.ts
  }.freeze
end
```

---

## 3. Acceptance Criteria

- ✅ `require 'agent_desk'` loads without error
- ✅ All constants from `src/common/tools.ts` are accessible as `AgentDesk::*`
- ✅ `AgentDesk.tool_id('power', 'bash')` returns `'power---bash'`
- ✅ `AgentDesk::ToolApprovalState::ALWAYS` returns `'always'`
- ✅ `AgentDesk::ContextFile.new(path: 'foo.rb')` works with `read_only` defaulting to `false`
- ✅ RSpec test suite passes with `bundle exec rspec`
- ✅ Gem builds with `gem build agent_desk.gemspec`

---

## 4. Test Plan

```ruby
# spec/agent_desk/constants_spec.rb
RSpec.describe AgentDesk do
  it 'defines the tool group separator' do
    expect(AgentDesk::TOOL_GROUP_NAME_SEPARATOR).to eq('---')
  end

  it 'builds fully qualified tool IDs' do
    expect(AgentDesk.tool_id('power', 'bash')).to eq('power---bash')
  end

  it 'defines all power tool names' do
    expect(AgentDesk::POWER_TOOL_FILE_READ).to eq('file_read')
    expect(AgentDesk::POWER_TOOL_BASH).to eq('bash')
  end
end

# spec/agent_desk/types_spec.rb
RSpec.describe AgentDesk::ContextFile do
  it 'defaults read_only to false' do
    file = AgentDesk::ContextFile.new(path: 'test.rb')
    expect(file.read_only).to be false
  end
end

RSpec.describe AgentDesk::ToolApprovalState do
  it 'defines the three approval states' do
    expect(AgentDesk::ToolApprovalState::ALWAYS).to eq('always')
    expect(AgentDesk::ToolApprovalState::ASK).to eq('ask')
    expect(AgentDesk::ToolApprovalState::NEVER).to eq('never')
  end
end
```

---

## 5. Implementation Notes

- Use Ruby 3.2+ `Data.define` for immutable value objects (replaces TypeScript interfaces)
- Constants are frozen strings by default with `# frozen_string_literal: true`
- No runtime dependencies needed for this PRD (test deps only: rspec, rubocop)
- The gemspec should declare `required_ruby_version >= 3.2`

---

**Next**: PRD-0020 (Tool Framework) builds on these types to create the tool registration and execution system.
