#### PRD-1-04: CLI Dispatch

**Log Requirements**
- Create/update a task log under `knowledge_base/task-logs/`.
- In the log, include detailed manual test steps and expected results.
- If asked to review: create a separate document named `PRD-1-04-cli-dispatch-feedback-V{{N}}.md` in the same directory as the source document.

---

### Overview

Build the `bin/legion execute` CLI command — the primary interface for dispatching a single agent to a single task. This is the most important PRD in Epic 1 because it implements the **full agent assembly pipeline**: loading an agent's identity from the database, assembling all gem components (rules, skills, tools, system prompt, model connection, event bus, hooks, approvals), and running the agent with its complete identity.

After this PRD, you can dispatch any of the 4 ROR agents — Rails Lead, Architect, QA, Debug — each running with its specific model, rules, skills, tool approvals, custom instructions, and system prompt. Every event is persisted to PostgreSQL. This is the foundational dispatch mechanism that PRDs 1-06 (decompose) and 1-07 (execute-plan) build upon.

---

### Requirements

#### Functional

**CLI Command (`bin/legion execute`):**
```bash
bin/legion execute --team ROR --agent rails-lead --prompt "Add a User model with email validation"
bin/legion execute --team ROR --agent qa --prompt "Score this implementation..."
bin/legion execute --team ROR --agent architect --prompt "Review this plan..."
bin/legion execute --team ROR --agent debug --prompt "Fix these test failures..."
bin/legion execute --team ROR --agent rails-lead --prompt-file path/to/prompt.md
```

**Arguments:**
- `--team NAME` (required): AgentTeam name to look up
- `--agent NAME` (required): Agent identifier — matches against `config->>'id'` or `config->>'name'` (case-insensitive partial match)
- `--prompt TEXT` (required, mutually exclusive with --prompt-file): The prompt to send
- `--prompt-file PATH` (required, mutually exclusive with --prompt): Read prompt from file
- `--project PATH` (optional): Project path override (default: current working directory)
- `--max-iterations N` (optional): Override agent's configured maxIterations
- `--interactive` (optional): Enable interactive tool approval (ASK tools prompt on terminal). Default: auto-approve all ASK tools.
- `--verbose` (optional): Print real-time event stream to terminal

**Agent Assembly Service (`app/services/legion/agent_assembly_service.rb`):**

`AgentAssemblyService.call(team_membership:, project_dir:, workflow_run:, interactive: false)`

The assembly pipeline (in order):
1. **Profile**: `team_membership.to_profile` → `AgentDesk::Agent::Profile`
2. **Rules**: `AgentDesk::Rules::RulesLoader.load_rules_content(profile_dir_name: profile.id, project_dir:)` → XML rules string
3. **System Prompt**: `AgentDesk::Prompts::PromptsManager.system_prompt(profile:, project_dir:, rules_content:, custom_instructions: profile.custom_instructions)` → rendered Liquid system prompt
4. **Tools**: Assemble ToolSet:
   - `AgentDesk::Tools::PowerTools.create(project_dir:, profile:)` (if `profile.use_power_tools`)
   - `AgentDesk::Skills::SkillLoader.activate_skill_tool(project_dir:)` (if `profile.use_skills_tools`) — single tool, LLM-driven
   - `AgentDesk::Tools::TodoTools.create` (if `profile.use_todo_tools`) — in-memory scratch pad
   - `AgentDesk::Tools::MemoryTools.create(project_dir:)` (if `profile.use_memory_tools`)
   - Combine all tool arrays into single ToolSet
5. **Model Manager**: `AgentDesk::Agent::ModelManager.new(provider: profile.provider, model: profile.model, api_key: ENV key, base_url: smart_proxy_url)`
6. **Message Bus**: `Legion::PostgresBus.new(workflow_run:)` → event persistence + in-process callbacks
7. **Hook Manager**: `AgentDesk::Hooks::HookManager.new` → orchestrator hooks registered (from PRD-1-05, but create empty HookManager here)
8. **Approval Manager**: `AgentDesk::Tools::ApprovalManager.new(tool_approvals: profile.tool_approvals)` with ask_user_block:
   - If `interactive: true` → block reads from STDIN
   - If `interactive: false` → auto-approve all ASK tools (log the auto-approval)
9. **Runner**: `AgentDesk::Agent::Runner.new(model_manager:, message_bus:, hook_manager:, approval_manager:, ...)`

Returns: `{ runner:, system_prompt:, tool_set:, profile:, message_bus: }`

**Dispatch Service (`app/services/legion/dispatch_service.rb`):**

`DispatchService.call(team_name:, agent_identifier:, prompt:, project_path:, max_iterations: nil, interactive: false, verbose: false)`

1. Find Project by path (or create if not exists)
2. Find AgentTeam by name within project
3. Find TeamMembership by agent identifier (match `config->>'id'` or `config->>'name'`, case-insensitive)
4. Create WorkflowRun (status: `running`, prompt: prompt)
5. Call `AgentAssemblyService.call(team_membership:, project_dir:, workflow_run:, interactive:)`
6. If `verbose:` → subscribe to `*` on PostgresBus, print events to STDOUT
7. Execute: `runner.run(prompt:, system_prompt:, tool_set:, profile:, project_dir:, agent_id: membership.config["id"], task_id: nil, max_iterations: max_iterations || profile.max_iterations)`
8. On success: Update WorkflowRun (status: `completed`, duration_ms:, iterations:, result:)
9. On failure: Update WorkflowRun (status: `failed`, error_message:, duration_ms:)
10. Print summary: agent name, model, iterations, duration, event count, final status

**Verbose output format:**
```
[agent.started] rails-lead (deepseek-reasoner) — starting
[tool.called] power---file_write → app/models/user.rb
[tool.result] power---file_write → success (24 lines)
[tool.called] power---bash → rails test test/models/user_test.rb
[tool.result] power---bash → 3 tests, 3 assertions, 0 failures
[response.complete] 14 iterations, 52.3s
[agent.completed] rails-lead — completed
```

#### Non-Functional

- CLI must use Thor or a custom argument parser (not rake) for proper CLI UX
- Exit codes: 0 = success, 1 = agent failure, 2 = argument error, 3 = team/agent not found
- Signal handling: SIGINT (Ctrl+C) should attempt graceful shutdown — mark WorkflowRun as `failed` with error "interrupted by user"
- Prompt from file: read entire file content as prompt string
- Large prompts (PRD files can be 200+ lines) must work without truncation

#### Rails / Implementation Notes

- CLI entry point: `bin/legion` (executable Ruby script that loads Rails environment)
- Services: `app/services/legion/agent_assembly_service.rb`, `app/services/legion/dispatch_service.rb`
- The `bin/legion` script needs to boot Rails for ActiveRecord access
- Consider using `Thor` gem for CLI argument parsing (already common in Rails ecosystem), or `OptionParser` from stdlib
- SmartProxy URL from `ENV['SMART_PROXY_URL']` (configured in `.env`)
- API key from `ENV['SMART_PROXY_TOKEN']` or model-specific env vars

---

### Error Scenarios & Fallbacks

- Team not found → Exit 3 with message: "Team 'X' not found. Available teams: A, B, C"
- Agent not found within team → Exit 3 with message: "Agent 'X' not in team 'Y'. Available agents: A, B, C"
- Both `--prompt` and `--prompt-file` provided → Exit 2: "Provide either --prompt or --prompt-file, not both"
- Neither `--prompt` nor `--prompt-file` provided → Exit 2: "One of --prompt or --prompt-file is required"
- Prompt file not found → Exit 2: "File not found: #{path}"
- SmartProxy not reachable → Runner raises connection error → WorkflowRun marked `failed` with error message
- Runner raises unexpected exception → Catch, mark WorkflowRun `failed`, log full backtrace, re-raise for visibility
- SIGINT during run → Mark WorkflowRun `failed` with "interrupted by user", exit 1
- Profile missing required config keys → `to_profile` raises → caught before assembly, reported with guidance to re-import

---

### Architectural Context

The CLI Dispatch is the **command center** of Epic 1. It's the entry point for all agent execution, and PRDs 1-06 (decompose) and 1-07 (execute-plan) are thin wrappers around it.

```
bin/legion execute --team ROR --agent rails-lead --prompt "..."
  → DispatchService.call(...)
    → Find TeamMembership in DB
    → AgentAssemblyService.call(...)
      → to_profile → RulesLoader → PromptsManager → SkillLoader → PowerTools
      → TodoTools → MemoryTools → ModelManager → PostgresBus → HookManager
      → ApprovalManager → Runner
    → Runner.run(...)
    → Update WorkflowRun
```

**Why a separate AgentAssemblyService?**
The assembly pipeline is reused by `execute`, `decompose`, and `execute-plan`. Extracting it into a service ensures consistency — every agent dispatch, regardless of entry point, goes through the same assembly.

**This PRD does NOT include orchestrator hooks.** HookManager is created empty here. PRD-1-05 adds the actual hooks. This avoids a dependency cycle: dispatch needs hooks, but hooks need dispatch to test. Solution: dispatch works without hooks (HookManager is nil-safe), hooks are added on top.

**Non-goals:**
- No automatic workflow chaining
- No parallel execution
- No task decomposition (that's PRD-1-06)
- No orchestrator hooks (that's PRD-1-05)

---

### Acceptance Criteria

- [ ] AC1: `bin/legion execute --team ROR --agent rails-lead --prompt "hello"` dispatches agent and completes
- [ ] AC2: Agent runs with correct model (from TeamMembership config, not hardcoded)
- [ ] AC3: Agent runs with rules in system prompt (verified by checking system_prompt content)
- [ ] AC4: Agent runs with skills available (SkillLoader discovers project skills)
- [ ] AC5: Agent runs with correct tool approvals (from TeamMembership config)
- [ ] AC6: Agent runs with custom instructions (from TeamMembership config)
- [ ] AC7: WorkflowRun record created with status `running`, updated to `completed` on success
- [ ] AC8: WorkflowEvent records created for all events during run
- [ ] AC9: `--prompt-file` reads prompt from file correctly
- [ ] AC10: `--verbose` prints real-time event stream
- [ ] AC11: `--max-iterations 5` overrides agent's default maxIterations
- [ ] AC12: `--interactive` enables terminal-based tool approval for ASK tools
- [ ] AC13: Non-interactive mode auto-approves ASK tools
- [ ] AC14: Team not found → exit 3 with helpful message
- [ ] AC15: Agent not found → exit 3 with list of available agents
- [ ] AC16: SIGINT → WorkflowRun marked failed, graceful exit
- [ ] AC17: AgentAssemblyService is a separate, reusable service (not embedded in CLI)
- [ ] AC18: `rails test` — zero failures for dispatch tests

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/agent_assembly_service_test.rb`:
  - Assembles Profile from TeamMembership config
  - Loads rules via RulesLoader (stub filesystem)
  - Renders system prompt via PromptsManager (stub)
  - Creates ToolSet with correct tools based on use_* flags
  - Creates ModelManager with correct provider/model
  - Creates PostgresBus with workflow_run
  - Creates ApprovalManager with tool_approvals from config
  - Returns all components needed for Runner

- `test/services/legion/dispatch_service_test.rb`:
  - Finds team and agent by name
  - Creates WorkflowRun with correct initial status
  - Calls AgentAssemblyService (stub)
  - Calls Runner.run with correct arguments (stub)
  - Updates WorkflowRun on success (status, duration, iterations)
  - Updates WorkflowRun on failure (status, error_message)
  - Agent identifier matching: by id, by name, case-insensitive
  - Team not found → raises with message
  - Agent not found → raises with message and available agents list

#### Integration (Minitest)

- `test/integration/cli_dispatch_integration_test.rb`:
  - Full assembly pipeline with VCR-recorded SmartProxy call
  - Verify WorkflowRun created and completed
  - Verify WorkflowEvents persisted (at least: agent.started, response.complete, agent.completed)
  - Verify system prompt contains rules content
  - Verify SkillLoader discovered skills

#### System / Smoke

- Manual verification with live SmartProxy (see below)

---

### Manual Verification

1. Ensure team is imported: `rake teams:import[~/.aider-desk]`
2. Run `bin/legion execute --team ROR --agent rails-lead --prompt "Say hello and list your available tools" --verbose`
   - Expected: Agent responds, verbose output shows event stream, WorkflowRun created in DB
3. Run `bin/legion execute --team ROR --agent qa --prompt "List your skills"`
   - Expected: QA agent responds with awareness of skills (it sees `skills---activate_skill` tool)
4. Run `rails console`:
   - `WorkflowRun.last.status` → "completed"
   - `WorkflowRun.last.workflow_events.count` → > 0
   - `WorkflowRun.last.workflow_events.pluck(:event_type).uniq` → includes "agent.started", "agent.completed"
5. Run `bin/legion execute --team ROR --agent rails-lead --prompt-file knowledge_base/overview/project-context.md --max-iterations 3`
   - Expected: Reads file as prompt, stops after 3 iterations
6. Run `bin/legion execute --team NONEXISTENT --agent foo --prompt "test"`
   - Expected: Exit 3 with "Team 'NONEXISTENT' not found"
7. Run `bin/legion execute --team ROR --agent nonexistent --prompt "test"`
   - Expected: Exit 3 with "Agent 'nonexistent' not in team 'ROR'. Available agents: ..."

**Expected:** Full agent dispatch working with complete identity — rules, skills, tools, approvals, model, system prompt — all events persisted.

---

### Dependencies

- **Blocked By:** PRD-1-01 (Schema), PRD-1-02 (PostgresBus), PRD-1-03 (Team Import)
- **Blocks:** PRD-1-05 (Hooks extend dispatch), PRD-1-06 (Decompose uses dispatch), PRD-1-07 (Execute-plan uses dispatch)

---

### Estimated Complexity

**High** — This is the integration point where the database layer meets the gem's runtime pipeline. Every component must be wired correctly: Profile, Rules, Prompts, Skills, Tools, ModelManager, MessageBus, HookManager, ApprovalManager, Runner. One misconfiguration and the agent runs with incomplete identity.

**Effort:** 1.5 weeks

### Agent Assignment

**Rails Lead** (DeepSeek Reasoner) — primary implementer for services and CLI
**QA** (Claude Sonnet) — verify full identity assembly via test execution
