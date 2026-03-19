# Deferred Features — Ruby Agent Framework Epic

**Created**: 2026-02-26
**Context**: Features explicitly excluded from the current epic scope that may warrant future epics or PRDs.

---

## Summary

The Ruby Agent Framework epic (all 12 PRDs, M0–M6) delivers a **backend-only** gem with **filesystem-based** configuration. The following categories of functionality are **not covered** and are deferred for future consideration.

---

## ~~D1. UI for Agent Profile Management~~

**Status**: ✅ **ADDRESSED by Epic 5 (File Maintenance UI) — PRD-5020, PRD-5025**

**What's missing**: No graphical interface for creating, editing, duplicating, or deleting agent profiles.

**Current state in AiderDesk (Electron)**: The `AgentSettings.tsx` component provides a full UI for:
- Creating new agent profiles (name, model, provider, color)
- Editing all profile fields (temperature, max tokens, tool approvals, invocation mode, etc.)
- Duplicating and deleting profiles
- Drag-and-drop reordering (with `order.json` persistence)
- Toggling tool groups on/off and setting per-tool approval states (always/ask/never)
- Configuring MCP servers per profile
- Pasting JSON profiles from clipboard

**What the Ruby gem provides instead**: Filesystem-only management — profiles are JSON files in `~/.aider-desk/agents/` (global) and `{project}/.aider-desk/agents/` (project-scoped), loaded by `ProfileManager` with hot-reload via `listen` gem.

**Gap**: No equivalent to the AiderDesk UI. Users must hand-edit JSON config files or use the `agent-creator` skill through an LLM conversation.

**Resolution (Epic 5)**: Agent-Forge provides a comprehensive web-based UI for agent profile management with Rails 8 + Turbo Streams + DaisyUI. All profile data is backed by PostgreSQL (not filesystem). Features include:
- Full CRUD operations for profiles
- Drag-and-drop reordering via Stimulus controllers
- Context switcher (global vs project profiles)
- Tool group toggles and per-tool approval selectors
- Color picker, model selector, temperature/max tokens sliders
- MCP server configuration per profile
- Real-time updates via Turbo Streams (multi-user/multi-tab support)
- Import rake task for migrating filesystem configs to PostgreSQL

See: `/Users/ericsmith66/development/agent-forge/knowledge_base/epics/epic-5-file-maintenance-ui/`

---

## ~~D2. UI for Skill Browsing, Creation & Editing~~

**Status**: ✅ **ADDRESSED by Epic 5 (File Maintenance UI) — PRD-5030, PRD-5035**

**What's missing**: No graphical interface for discovering, previewing, creating, or editing skills.

**Current state in AiderDesk (Electron)**: Skills are filesystem-based here too — there is **no dedicated skill management UI** in AiderDesk either. Skills are discovered from `~/.aider-desk/skills/` and `{project}/.aider-desk/skills/` directories. The only UI surface is:
- The `AgentSelector` toggle for enabling/disabling the skills tool group per profile
- Tool call messages in chat showing `skills---activate_skill` invocations
- The `skill-creator` skill itself (an LLM-guided workflow, not a UI)

**What the Ruby gem provides**: Same filesystem discovery from `SkillLoader` — `SKILL.md` files with YAML frontmatter.

**Gap (shared with AiderDesk)**: Neither platform has a UI for:
- Browsing available skills with descriptions/previews
- Creating new skills via a form/wizard
- Editing skill content (SKILL.md) in an integrated editor
- Enabling/disabling specific skills per profile (only the entire skills tool group can be toggled)
- Viewing skill activation history or usage stats

**Resolution (Epic 5)**: Agent-Forge goes beyond AiderDesk by providing a full-featured skills management UI:
- Skill browser with grid/list views, search/filter
- Skill creation wizard (form with frontmatter fields + markdown editor)
- Skill editor with markdown syntax highlighting (Stimulus controller)
- Skill viewer with rendered markdown preview
- Skill activation tracking (database-logged)
- Skill usage analytics dashboard (most-used skills, trends over time)
- PostgreSQL storage (replaces filesystem SKILL.md files)

See: PRD-5030 (Skills Backend), PRD-5035 (Skills UI)

---

## ~~D3. UI for Rule File Management~~

**Status**: ✅ **ADDRESSED by Epic 5 (File Maintenance UI) — PRD-5040, PRD-5045, PRD-5048**

**What's missing**: No graphical interface for viewing, creating, or editing rule files.

**Current state in AiderDesk (Electron)**: The `AgentRules.tsx` component provides:
- A text area for `customInstructions` (inline rules per profile)
- Informational text about rule file locations with a link to examples
- The `ContextFiles` component displays loaded rule files (categorized as `global-rule`, `project-rule`, `agent-rule`) in a read-only tree view

**What's NOT in AiderDesk's UI**:
- Creating new rule files from the UI
- Editing rule file content in-app
- Managing the 3-tier rule hierarchy visually (global → project → agent-specific)
- Previewing which rules will apply to a given agent/project combination

**What the Ruby gem provides**: `RulesLoader` with 3-tier discovery, but no UI layer.

**Gap (shared with AiderDesk)**: Both platforms lack a rule file editor. Users must use an external text editor or IDE to create/modify `.md` rule files in the appropriate directories.

**Resolution (Epic 5)**: Agent-Forge provides comprehensive rule management UI:
- Rule browser with tree view showing 3-tier hierarchy (global agent → project → project agent)
- Rule creation form with tier selector and markdown editor
- Rule editor with markdown syntax highlighting
- Rule preview showing final assembled rules for a given profile + project combination
- Rule hierarchy visualizer (interactive diagram)
- Rule templates library (pre-built rule sets for common scenarios: Rails testing, API design, security best practices)
- PostgreSQL storage (replaces filesystem markdown files)
- Background job for rule assembly caching (performance optimization)

See: PRD-5040 (Rules Backend), PRD-5045 (Rules UI), PRD-5048 (Rule Assembly Service)

---

## ~~D4. UI for Custom Command Management~~

**Status**: ✅ **ADDRESSED by Epic 5 (File Maintenance UI) — PRD-5050**

**What's missing**: No interface for creating, editing, or managing custom commands.

**Current state in AiderDesk (Electron)**: Custom commands are markdown files in `.aider-desk/commands/`. They are discovered and executed via `/command-name` syntax in chat. There is no UI to:
- Browse available commands
- Create new commands
- Edit command content
- See command descriptions before execution

**What the Ruby gem provides**: Not yet in scope (no custom command PRD exists in the current epic).

**Gap**: Both platforms rely entirely on filesystem-based command management.

**Resolution (Epic 5)**: Agent-Forge provides custom commands UI:
- Command browser (grid/list view)
- Command creation wizard with description field
- Command editor (markdown editing)
- Command usage history (log all invocations with timestamp and context)
- PostgreSQL storage (replaces filesystem markdown files)

See: PRD-5050 (Custom Commands UI)

---

## D5. UI for Hook Configuration

**What's missing**: No interface for configuring or managing hooks.

**Current state in AiderDesk (Electron)**: Hooks (`on_agent_started`, `on_tool_called`, `on_tool_finished`, `on_handle_approval`) are programmatic only — registered in code, not configurable via UI.

**What the Ruby gem provides**: `HookManager` with programmatic registration (PRD-0030).

**Gap**: No visual hook configuration in either platform. Hooks are developer-facing APIs, not end-user configurable features. This may be intentional rather than a gap.

---

## D6. UI for Prompt Template Management

**What's missing**: No interface for viewing or customizing system prompt templates.

**Current state in AiderDesk (Electron)**: Prompt templates are Handlebars files (`resources/prompts/system-prompt.hbs`, `workflow.hbs`) with a global → project override chain managed by `PromptsManager`. There is no UI to:
- Preview the assembled system prompt for a given profile
- Edit or override templates per project
- See which template variables are available

**What the Ruby gem provides**: `PromptsManager` with template override chain (PRD-0060), but no UI.

**Gap (shared with AiderDesk)**: Template management is developer-only. A "prompt preview" feature would be valuable for debugging agent behavior.

---

## D7. MCP Client Support

**What's missing**: Connecting to external MCP servers from the Ruby gem.

**Current state in AiderDesk (Electron)**: Full MCP client support — agents can connect to external MCP servers, and MCP server configs are part of the agent profile (configurable in the UI).

**What the Ruby gem provides**: Not in scope. Listed explicitly in the epic's Non-Goals: *"No MCP server — MCP client (connecting to external MCP servers) is a future enhancement, not in initial scope."*

**Gap**: Ruby agents cannot leverage external MCP tool servers.

---

## D8. Event System, Streaming & External Consumer Integration

**What's missing**: No event bus, no streaming, no way for chatbots or external apps to receive agent output in real time.

**Current state in AiderDesk (Electron)**: A comprehensive multi-layer messaging architecture:

1. **EventManager** — Central event bus broadcasting 30+ event types (`response-chunk`, `response-completed`, `tool`, `log`, `task-created`, `task-completed`, `context-files-updated`, `ask-question`, `user-message`, `agent-profiles-updated`, etc.) to both IPC (renderer) and Socket.IO (external) consumers.
2. **Socket.IO server** — Runs on port 24337, supports event subscription with filtering by event type, project (`baseDir`), and task (`taskId`). External apps (chatbots, browser UIs, Slack/Discord bots) connect here.
3. **REST API** — Full HTTP endpoints for sending prompts, managing tasks/context/profiles, and getting responses synchronously.
4. **Browser API** — Combined REST + Socket.IO client for web-based integrations.
5. **Response streaming** — `response-chunk` events deliver token-by-token LLM output in real time.
6. **Question/approval flow** — `ask-question` events allow external consumers to answer agent questions (e.g., tool approval prompts).

**What the Ruby gem provides (PRD-0090)**: A single synchronous `on_message` callback lambda that fires once per complete message (assistant response or tool result). No streaming, no event bus, no external server.

**Critical gaps for chatbot/external integration**:
- **No streaming**: Chatbot users would see nothing until the entire LLM response is complete (could be 30+ seconds for complex responses)
- **No event bus**: No way to subscribe to specific event types or filter by task
- **No server component**: No HTTP or WebSocket endpoint for chatbots to connect to
- **No question/approval routing**: If the agent needs to ask the user a question (e.g., tool approval), there's no mechanism to route it to the chatbot user and get a response back
- **No tool call visibility**: External consumers can't see which tools the agent is calling in real time
- **No task lifecycle events**: No way to know when a task starts, completes, or fails without polling

**What would be needed for chatbot integration**:
1. **EventEmitter / pub-sub** — Ruby-native event bus (e.g., `Wisper` gem or custom) with named events matching AiderDesk's event types
2. **Streaming support** — Yield tokens as they arrive from the LLM (OpenAI streaming API / Anthropic streaming)
3. **Server adapter** — Optional HTTP/WebSocket server (e.g., Rack + Faye/ActionCable) that chatbot frameworks can connect to
4. **Question routing** — Mechanism to pause execution, emit a question event, and wait for an external answer
5. **Structured response format** — Not just raw text, but typed event objects that chatbot adapters can render appropriately (tool calls as cards, code as blocks, etc.)

---

## D9. Subagent/Task Delegation System

**What's missing**: Limited task management in Ruby gem.

**Current state in AiderDesk (Electron)**: Full task system with `create_task` (supports `parentTaskId` for subtasks, `agentProfileId` for profile selection, `execute`/`executeInBackground` flags), `search_task` (semantic search within task history), and subagent delegation via `subagents---run_task`.

**What the Ruby gem provides**: PRD-0110 covers `TaskTools` (list, get, create, delete, search) and `HelperTools`, but the subagent delegation tool (`subagents---run_task`) and background execution are not explicitly addressed.

**Gap**: Multi-agent orchestration (one agent spawning subtasks on different profiles) may need a dedicated PRD.

---

## Prioritization Suggestion

| ID | Feature | Impact | Effort | Recommended Priority |
|----|---------|--------|--------|---------------------|
| ~~D1~~ | ~~Agent Profile UI~~ | ~~High~~ | ~~Medium~~ | **✅ Epic 5 (PRD-5020, PRD-5025)** |
| ~~D2~~ | ~~Skill Management UI~~ | ~~High~~ | ~~Medium~~ | **✅ Epic 5 (PRD-5030, PRD-5035)** |
| ~~D3~~ | ~~Rule File UI~~ | ~~Medium~~ | ~~Low-Medium~~ | **✅ Epic 5 (PRD-5040, PRD-5045, PRD-5048)** |
| D6 | Prompt Preview | Medium — debugging aid | Low | P2 |
| D7 | MCP Client | High — ecosystem integration | High | P1 — Separate PRD |
| ~~D8~~ | ~~Event System / Streaming / Chatbot Integration~~ | ~~Critical~~ | ~~High~~ | **✅ Epic 4 (PRD-0095 - Message Bus)** |
| D9 | Subagent Delegation | High — multi-agent workflows | Medium | P1 — Partially addressed by PRD-0092 (handoff creates continuation tasks); full subagent dispatch still needs dedicated PRD |
| ~~D4~~ | ~~Command Management UI~~ | ~~Low~~ | ~~Low~~ | **✅ Epic 5 (PRD-5050)** |
| D5 | Hook Configuration UI | Low — developer API | Low | P3 |

---

## Notes

- **✅ D1, D2, D3, D4 are addressed by Epic 5 (File Maintenance UI)** — Agent-Forge provides comprehensive web-based UI for agent profiles, skills, rules, and custom commands with PostgreSQL backend. Goes beyond AiderDesk by adding features like analytics, versioning, search, and bulk operations.
- **✅ D8 is addressed by PRD-0095 (Message Bus)** — Added to Epic 4 as PRD-0095 with `CallbackBus` (in-process) and `PostgresBus` (cross-process via PostgreSQL LISTEN/NOTIFY) adapters. Integrates with Agent-Forge's existing Solid Queue + Solid Cable + Turbo Streams infrastructure.
- **D6 (Prompt Preview)** remains deferred — would be valuable for debugging agent behavior, but lower priority than profile/skill/rule management.
- **D7 (MCP Client)** remains deferred — requires significant integration work with external MCP servers.
- **D9 (Subagent Delegation)** remains deferred — multi-agent orchestration needs dedicated design work.
- **D5 (Hook Configuration UI)** may be intentionally out of scope — hooks are a developer API, not an end-user feature.
