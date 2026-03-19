# Ruby Agent Framework — Architecture

Ported from AiderDesk's agent/skill/rule/command/tool-calling architecture.

## Core Concepts

### 1. Agent Profile
Defines an agent's identity: which LLM provider/model to use, which tool groups are enabled, approval policies per tool, custom instructions, subagent configuration, and rule file paths.

### 2. Tool Groups
Tools are organized into named groups separated by `---`:
- `power---file_read`, `power---bash`, etc.
- `aider---run_prompt`, `aider---add_context_files`, etc.
- `todo---set_items`, `todo---get_items`, etc.
- `memory---store_memory`, `memory---retrieve_memory`, etc.
- `skills---activate_skill`
- `tasks---create_task`, `tasks---list_tasks`, etc.
- `helpers---no_such_tool`, `helpers---invalid_tool_arguments`
- MCP server tools: `server_name---tool_name`

### 3. Tool Approval
Each tool has an approval state per profile: `always`, `ask`, `never`.
- `never` → tool excluded from toolset entirely
- `always` → auto-approved
- `ask` → prompts user (or hook) for approval before execution

### 4. Hooks
Lifecycle hooks that intercept agent/tool events:
- `on_agent_started` — can block or modify prompt
- `on_tool_called` — can block or modify tool args
- `on_tool_finished` — post-execution notification
- `on_handle_approval` — override approval logic

### 5. Rules
Markdown files loaded from:
1. Global agent rules (`~/.aider-desk/agents/{profile}/rules/`)
2. Project rules (`{project}/.aider-desk/rules/`)
3. Project agent rules (`{project}/.aider-desk/agents/{profile}/rules/`)

Injected into system prompt as `<Knowledge><Rules>` XML.

### 6. Skills
Markdown-based capability modules in `.aider-desk/skills/{name}/SKILL.md`.
Discovered at runtime, listed in the `activate_skill` tool description.
When activated, the SKILL.md content is returned to the LLM as a tool result.

### 7. System Prompt (Handlebars Templates)
Templates in `resources/prompts/` compiled with Handlebars.
The system prompt is assembled from:
- Agent persona/directives
- Tool usage guidelines (conditional on enabled tools)
- Subagent protocol (if enabled)
- TODO management (if enabled)
- Memory tools (if enabled)
- Aider/Power tool instructions (if enabled)
- Rules content
- Custom instructions
- Workflow steps

### 8. Agent Runner Loop
Uses Vercel AI SDK's `streamText`/`generateText` with:
- System prompt
- Prepared messages (context + user)
- Full toolset
- `maxSteps` from profile's `maxIterations`
- Tool call repair for missing tools / invalid args
- Abort signal support
- Hook wrapping on every tool execution

## Directory Layout (Ruby)

```
ruby-agent-framework/
├── lib/
│   └── agent_desk/
│       ├── agent/
│       │   ├── agent.rb           # Main agent runner loop
│       │   ├── profile.rb         # AgentProfile struct & defaults
│       │   └── profile_manager.rb # Load/save/watch profiles
│       ├── tools/
│       │   ├── base_tool.rb       # Tool interface
│       │   ├── tool_set.rb        # ToolSet collection
│       │   ├── approval_manager.rb
│       │   ├── power_tools.rb     # file_read, file_write, file_edit, glob, grep, bash, fetch, semantic_search
│       │   ├── todo_tools.rb
│       │   ├── memory_tools.rb
│       │   ├── skills_tools.rb
│       │   ├── task_tools.rb
│       │   ├── helper_tools.rb
│       │   └── aider_tools.rb     # Optional Aider integration
│       ├── prompts/
│       │   ├── prompts_manager.rb # Template compilation & rendering
│       │   └── types.rb           # Template data structures
│       ├── rules/
│       │   └── rules_loader.rb    # Rule file discovery & content loading
│       ├── skills/
│       │   └── skill_loader.rb    # Skill discovery from filesystem
│       ├── hooks/
│       │   └── hook_manager.rb    # Lifecycle hook registry & trigger
│       ├── memory/
│       │   └── memory_manager.rb  # Vector-based memory store
│       ├── models/
│       │   └── model_manager.rb   # LLM provider abstraction
│       ├── utils/
│       │   └── helpers.rb
│       ├── constants.rb
│       └── types.rb               # Core enums and type definitions
├── config/
│   └── defaults.rb                # Default profiles & settings
├── templates/
│   ├── system-prompt.hbs
│   └── workflow.hbs
├── spec/                          # RSpec tests
├── Gemfile
├── agent_desk.gemspec
└── ARCHITECTURE.md
```
