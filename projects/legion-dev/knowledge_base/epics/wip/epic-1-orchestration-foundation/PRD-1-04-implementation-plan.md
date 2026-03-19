# PRD-1-04 CLI Dispatch Implementation Plan

**Created:** 2026-03-06
**Owner:** Rails Lead (DeepSeek Reasoner)
**PRD:** PRD-1-04-cli-dispatch.md
**Branch:** epic-1/prd-04-cli-dispatch

## Overview

Implement the `bin/legion execute` CLI command with full agent assembly pipeline. This creates the primary dispatch mechanism for Epic 1, enabling execution of agents with complete identity from database.

## File-by-File Changes

### New Files

1. **`bin/legion`** (executable Ruby script)
   - Thor-based CLI with `execute` command
   - Argument parsing: --team, --agent, --prompt/--prompt-file, --project, --max-iterations, --interactive, --verbose
   - Exit codes: 0=success, 1=agent failure, 2=argument error, 3=team/agent not found
   - Loads Rails environment for ActiveRecord access

2. **`app/services/legion/agent_assembly_service.rb`**
   - `AgentAssemblyService.call(team_membership:, project_dir:, workflow_run:, interactive: false)`
   - Assembles full pipeline: Profile, Rules, System Prompt, Tools (Power, Skills, Todo, Memory), ModelManager, PostgresBus, HookManager (empty), ApprovalManager, Runner
   - Returns `{ runner:, system_prompt:, tool_set:, profile:, message_bus: }`

3. **`app/services/legion/dispatch_service.rb`**
   - `DispatchService.call(team_name:, agent_identifier:, prompt:, project_path:, max_iterations: nil, interactive: false, verbose: false)`
   - Finds/creates Project, finds AgentTeam, finds TeamMembership by id/name partial match
   - Creates WorkflowRun, calls AgentAssemblyService, executes Runner.run
   - Updates WorkflowRun status/duration/iterations/result on completion
   - Handles verbose event streaming to STDOUT

4. **`test/services/legion/agent_assembly_service_test.rb`**
   - Unit tests for assembly pipeline
   - Mocks filesystem for rules loading
   - Verifies ToolSet composition based on use_* flags
   - Tests ApprovalManager with interactive/non-interactive modes

5. **`test/services/legion/dispatch_service_test.rb`**
   - Unit tests for dispatch logic
   - Mocks AgentAssemblyService and Runner
   - Tests team/agent lookup, WorkflowRun lifecycle
   - Tests error cases: team not found, agent not found

6. **`test/integration/cli_dispatch_integration_test.rb`**
   - Full integration test with VCR-recorded SmartProxy calls
   - Verifies WorkflowRun creation/completion, WorkflowEvent persistence
   - Tests system prompt includes rules content
   - Tests SkillLoader discovers skills

### Modified Files

None — this PRD creates entirely new functionality.

## Numbered Test Checklist (MUST-IMPLEMENT)

### Unit Tests
1. AgentAssemblyService assembles Profile from TeamMembership config
2. AgentAssemblyService loads rules via RulesLoader (stub filesystem)
3. AgentAssemblyService renders system prompt via PromptsManager (stub)
4. AgentAssemblyService creates ToolSet with correct tools based on use_* flags
5. AgentAssemblyService creates ModelManager with correct provider/model
6. AgentAssemblyService creates PostgresBus with workflow_run
7. AgentAssemblyService creates ApprovalManager with tool_approvals from config
8. AgentAssemblyService returns all components needed for Runner
9. DispatchService finds team and agent by name
10. DispatchService creates WorkflowRun with correct initial status
11. DispatchService calls AgentAssemblyService (stub)
12. DispatchService calls Runner.run with correct arguments (stub)
13. DispatchService updates WorkflowRun on success (status, duration, iterations)
14. DispatchService updates WorkflowRun on failure (status, error_message)
15. DispatchService handles agent identifier matching: by id, by name, case-insensitive
16. DispatchService raises on team not found with message
17. DispatchService raises on agent not found with message and available agents list

### Integration Tests
18. CLI dispatch full assembly pipeline with VCR-recorded SmartProxy call
19. Verify WorkflowRun created and completed
20. Verify WorkflowEvents persisted (at least: agent.started, response.complete, agent.completed)
21. Verify system prompt contains rules content
22. Verify SkillLoader discovered skills

### System/Smoke Tests
23. Manual: `bin/legion execute --team ROR --agent rails-lead --prompt "hello"` dispatches agent and completes
24. Manual: Agent runs with correct model (from TeamMembership config)
25. Manual: Agent runs with rules in system prompt
26. Manual: Agent runs with skills available
27. Manual: Agent runs with correct tool approvals
28. Manual: Agent runs with custom instructions
29. Manual: WorkflowRun record created with status `running`, updated to `completed` on success
30. Manual: WorkflowEvent records created for all events during run
31. Manual: `--prompt-file` reads prompt from file correctly
32. Manual: `--verbose` prints real-time event stream
33. Manual: `--max-iterations 5` overrides agent's default maxIterations
34. Manual: `--interactive` enables terminal-based tool approval for ASK tools
35. Manual: Non-interactive mode auto-approves ASK tools
36. Manual: Team not found → exit 3 with helpful message
37. Manual: Agent not found → exit 3 with list of available agents
38. Manual: SIGINT → WorkflowRun marked failed, graceful exit
39. Manual: AgentAssemblyService is a separate, reusable service
40. Manual: `rails test` — zero failures for dispatch tests

## Error Path Matrix

| Scenario | Input | Expected Behavior | Exit Code | Error Message |
|----------|-------|-------------------|-----------|---------------|
| Team not found | `--team NONEXISTENT --agent foo --prompt "test"` | Exit with available teams list | 3 | "Team 'NONEXISTENT' not found. Available teams: A, B, C" |
| Agent not found | `--team ROR --agent nonexistent --prompt "test"` | Exit with available agents list | 3 | "Agent 'nonexistent' not in team 'ROR'. Available agents: A, B, C" |
| Both --prompt and --prompt-file | `--prompt "test" --prompt-file file.txt` | Exit immediately | 2 | "Provide either --prompt or --prompt-file, not both" |
| Neither --prompt nor --prompt-file | No prompt args | Exit immediately | 2 | "One of --prompt or --prompt-file is required" |
| Prompt file not found | `--prompt-file /nonexistent/file.txt` | Exit immediately | 2 | "File not found: /nonexistent/file.txt" |
| SmartProxy unreachable | Valid args, but proxy down | Agent fails, WorkflowRun marked `failed` | 1 | Runner raises connection error, logged in WorkflowRun.error_message |
| Runner unexpected exception | Valid args, but runtime error | Agent fails, WorkflowRun marked `failed` | 1 | Full backtrace logged, re-raised for visibility |
| SIGINT during run | Ctrl+C during execution | Graceful shutdown, WorkflowRun marked `failed` | 1 | "interrupted by user" |
| Profile missing required config | Imported config missing id/name/provider/model | Assembly fails before Runner | 1 | `to_profile` raises, caught and reported with guidance |

## Migration Steps

No database migrations required for this PRD. All schema changes were completed in PRD-1-01.

## Pre-QA Checklist Acknowledgment

I acknowledge that before requesting QA scoring, I MUST:
- Run `bash scripts/pre-qa-validate.sh` OR manually complete all checks in `knowledge_base/templates/pre-qa-checklist-template.md`
- Fix ALL issues found (rubocop offenses, missing frozen_string_literal, test failures)
- Save completed checklist to `{epic-dir}/feedback/pre-qa-checklist-PRD-{id}.md`
- Ensure ALL mandatory items pass before step 5

## Estimated Effort

1.5 weeks (as per PRD)

## Dependencies

- PRD-1-01 (Schema) — models and database
- PRD-1-02 (PostgresBus) — event persistence
- PRD-1-03 (Team Import) — agents in database

## Acceptance Criteria Alignment

All 18 ACs from PRD will be implemented and tested:
- AC1-AC18 cover CLI execution, agent identity, WorkflowRun lifecycle, verbose output, argument handling, error cases, and service separation.

---

## Architect Review & Amendments

**Reviewer:** Architect Agent
**Date:** 2026-03-07
**Verdict:** APPROVED (with mandatory amendments — all must be resolved before Φ10 begins)

---

### Summary Assessment

The plan covers the right surface area: two well-scoped services, a thin CLI entry point, and a solid test checklist aligned with the 18 ACs. The service separation between `AgentAssemblyService` and `DispatchService` is architecturally sound and correctly anticipates reuse by PRDs 1-06 and 1-07. The Error Path Matrix is complete and the dependency chain is correctly declared.

However, several implementation details are either absent, ambiguous, or incorrect in ways that will cause real failures when the code runs against the actual gem API. These are catalogued below, with mandatory items marked **[BLOCKER]**.

---

### Issues & Amendments

#### 1. [BLOCKER — CHANGED] `AgentAssemblyService` signature mismatch with `Runner.new`

The plan states `AgentAssemblyService` returns `{ runner:, system_prompt:, tool_set:, profile:, message_bus: }` and that `DispatchService` then calls `runner.run(...)`. But the actual `Runner.new` constructor signature (confirmed in `gems/agent_desk/lib/agent_desk/agent/runner.rb`) requires:

```ruby
Runner.new(
  model_manager:,
  message_bus: nil,
  hook_manager: nil,
  approval_manager: nil,
  token_budget_tracker: nil,
  usage_logger: nil,
  compaction_strategy: nil
)
```

The plan does not specify that `AgentAssemblyService` must pass `compaction_strategy:` from the profile. `TeamMembership#to_profile` already maps `config["compactionStrategy"]` → `profile.compaction_strategy` (a Symbol). If this is not forwarded to `Runner.new`, the agent will silently use no compaction strategy regardless of the agent's configured strategy. **The `compaction_strategy:` kwarg must be forwarded from the profile to `Runner.new`.**

Similarly, the plan does not mention `token_budget_tracker`. The `to_profile` method includes `cost_budget:` and `context_window:` fields. If the PRD explicitly defers token/cost budget tracking, that decision must be documented in the plan. Otherwise include a `TokenBudgetTracker` when `profile.cost_budget > 0`.

**Required addition:** Document (and implement) the `compaction_strategy:` passthrough. Explicitly state whether `TokenBudgetTracker` is in or out of scope for this PRD. If out of scope, add a `# TODO: PRD-1-04+` comment at the construction site so it is not silently lost.

---

#### 2. [BLOCKER — CHANGED] `SkillLoader` is instantiated, not called as a class method

The plan states: `AgentDesk::Skills::SkillLoader.activate_skill_tool(project_dir:)`. This is wrong. `activate_skill_tool` is an **instance method** on `SkillLoader`, not a class method. The correct call is:

```ruby
AgentDesk::Skills::SkillLoader.new.activate_skill_tool(project_dir: project_dir)
```

Calling it as a class method will raise `NoMethodError` at runtime. This is confirmed by reading `gems/agent_desk/lib/agent_desk/skills/skill_loader.rb`.

**Required fix:** Update all plan references and the eventual implementation to instantiate `SkillLoader` before calling `activate_skill_tool`.

---

#### 3. [BLOCKER — CHANGED] `ApprovalManager` non-interactive mode uses `auto_approve:` keyword, not a nil block

The plan states: "If `interactive: false` → auto-approve all ASK tools (log the auto-approval)". The actual `ApprovalManager.new` constructor accepts `auto_approve: false` as a keyword argument. The correct non-interactive construction is:

```ruby
# Non-interactive: auto-approve all ASK tools
AgentDesk::Tools::ApprovalManager.new(
  tool_approvals: profile.tool_approvals,
  auto_approve: true
)

# Interactive: prompt user via STDIN
AgentDesk::Tools::ApprovalManager.new(
  tool_approvals: profile.tool_approvals
) do |text, subject|
  # read from STDIN
end
```

Passing `auto_approve: false` (the default) with no block will cause ASK tools to be **rejected silently** (the manager returns `[false, nil]` when state is ASK and no block is given). This is a silent failure that would break non-interactive runs for any agent with ASK-configured tools.

**Required fix:** The plan must specify `auto_approve: true` for non-interactive mode. The logging of auto-approvals cannot happen inside `ApprovalManager` (it does not log). Log the auto-approval decision in `AgentAssemblyService` before construction, not inside the manager.

---

#### 4. [BLOCKER — CHANGED] `AgentTeam` lookup must be scoped to `Project`

The plan states: "Find AgentTeam by name within project." The `AgentTeam` model has `validates :name, uniqueness: { scope: :project_id }`, meaning the same team name can exist across different projects. The lookup in `DispatchService` **must** scope by both name and project, or a race condition on the same team name in different projects will return the wrong team.

The correct lookup:
```ruby
project = Project.find_by!(path: project_path)
team = AgentTeam.find_by!(name: team_name, project: project)
```

Do not use `AgentTeam.find_by!(name: team_name)` without project scoping.

---

#### 5. [ADDED] `WorkflowRun` must be linked to `TeamMembership`, not just `Project`

The `workflow_runs` migration requires `t.references :team_membership, null: false`. The `WorkflowRun` model has `belongs_to :team_membership`. The plan mentions `WorkflowRun` creation but does not explicitly say that `team_membership:` is a required field. The implementation must include:

```ruby
WorkflowRun.create!(
  project: project,
  team_membership: team_membership,
  prompt: prompt,
  status: :running
)
```

This is confirmed by the migration (`20260306000400_create_workflow_runs.rb`). Omitting `team_membership:` will raise a `NOT NULL` constraint violation.

---

#### 6. [ADDED] `bin/legion` boot sequence: Rails environment loading order matters

The plan says "`bin/legion` loads Rails environment for ActiveRecord access." This is correct in principle but the implementation must handle the boot path carefully:

- `require_relative "../config/environment"` (or `require File.expand_path("../config/environment", __dir__)`) is the correct way to boot Rails from a `bin/` script.
- Thor must be loaded **after** the Rails environment, since `app/services/` files are autoloaded by Zeitwerk.
- The script must `chmod +x bin/legion` and include a proper shebang: `#!/usr/bin/env ruby`.
- The plan should note that `ENV['RAILS_ENV']` defaults to `"development"` unless overridden, which is correct for CLI dispatch but must be documented.

**Add to plan:** Specify the exact boot sequence and shebang line convention to match `bin/rails` style.

---

#### 7. [ADDED] SIGINT handler must be set up before `Runner.run`, not inside it

The plan describes SIGINT handling but does not specify where the signal trap is registered. `Runner.run` is a blocking loop — a `trap("INT")` registered inside a service will not be respected if the LLM HTTP call is blocking in `Faraday`. The correct pattern:

```ruby
workflow_run = nil
interrupted = false

trap("INT") do
  interrupted = true
  Thread.main.raise(Interrupt)
end

begin
  runner.run(...)
rescue Interrupt
  interrupted = true
ensure
  if interrupted
    workflow_run&.update!(status: :failed, error_message: "interrupted by user")
    exit 1
  end
end
```

The `trap` must be registered in `bin/legion` (the CLI layer), not inside `DispatchService`, to avoid polluting the service's interface. `DispatchService` should rescue `Interrupt` in its error handling and re-raise after updating the `WorkflowRun`.

**Add to plan:** Specify the SIGINT registration site and the rescue/re-raise flow with `WorkflowRun` update.

---

#### 8. [ADDED] `--verbose` subscription must be set up before `runner.run`, not after

The plan describes verbose event streaming but the subscription to `PostgresBus` must happen **before** `runner.run` is called (the bus publishes synchronously during the run). The plan's step 6 ("If verbose: → subscribe to * on PostgresBus") is listed before step 7 ("Execute: runner.run"), which is correct, but this ordering must be explicitly enforced in the code — do not refactor these steps into a sequence that reverses the order.

Also note: subscribing to `"*"` requires checking whether `CallbackBus` supports glob patterns. From the existing `PostgresBus` and `CallbackBus` implementations, the pattern is passed through to `CallbackBus#subscribe`. Confirm that `"*"` is a valid pattern, or use `"agent.*"` / individual event type patterns if glob is not supported. **Add a note to the plan to validate pattern support before implementing.**

---

#### 9. [ADDED] `ModelManager` must receive `provider` as a Symbol, not a String

`TeamMembership#to_profile` maps `config["provider"]` (a String from JSONB) to `profile.provider`. The `ModelManager.new(provider:)` constructor expects a Symbol from `PROVIDERS = %i[openai smart_proxy custom]`. If `profile.provider` is the raw string `"smart_proxy"` rather than the symbol `:smart_proxy`, `ModelManager` will raise `ConfigurationError`. 

The implementation must call `profile.provider.to_sym` (or ensure `to_profile` normalizes it). Check whether `AgentDesk::Agent::Profile` stores provider as Symbol or String — if it stores String (as JSONB is String-keyed), `AgentAssemblyService` must coerce before passing to `ModelManager`.

**Add to plan:** Specify provider Symbol coercion in `AgentAssemblyService` before `ModelManager` construction.

---

#### 10. [ADDED] `SmartProxy` URL and token — use `ENV.fetch` with a clear error message

The plan says "SmartProxy URL from `ENV['SMART_PROXY_URL']`" but does not guard against the env var being absent. An unset `SMART_PROXY_URL` will silently pass `nil` to `ModelManager`, which then defaults to `http://localhost:4567`. This may appear to work locally but fail in CI or on other machines.

**Required:** Use `ENV.fetch("SMART_PROXY_URL", "http://localhost:4567")` for development defaults and document that this must be set in `.env`. For `SMART_PROXY_TOKEN`, use `ENV.fetch("SMART_PROXY_TOKEN")` with no default and rescue the `KeyError` in the CLI with a helpful message: `"SMART_PROXY_TOKEN not set — add it to .env"`.

---

#### 11. [ADDED] Test fixture for `AgentAssemblyService` — `TeamMembership` must have valid `config`

The unit tests for `AgentAssemblyService` must stub `team_membership.to_profile` rather than creating real `TeamMembership` records, because `to_profile` requires a full JSONB config with all required keys. Using `OpenStruct` or a real `TeamMembership` built via fixtures both work, but the plan does not specify which. Given PRD-1-03 fixtures already exist in `test/fixtures/aider_desk/valid_team/`, the assembly service tests should use a `TeamMembership` with a known config derived from those fixtures or from a minimal factory.

**Add to plan:** Specify that `AgentAssemblyService` tests use `TeamMembership.new(config: {...})` (unsaved) with a minimal valid config to keep tests fast and filesystem-independent.

---

#### 12. [ADDED] Missing test: `DispatchService` creates `WorkflowRun` with `team_membership` association

The test checklist item #10 is "DispatchService creates WorkflowRun with correct initial status" but does not check that `team_membership:` is correctly set on the record. This is a NOT NULL column — a missing association causes a DB exception, not a validation failure. Add:

- **Test #18 (MUST-IMPLEMENT):** DispatchService sets `workflow_run.team_membership` to the found `TeamMembership` record (not just correct status).

---

#### 13. [ADDED] Missing test: Non-interactive `ApprovalManager` auto-approves ASK tools without blocking

This maps to AC13 but is not present as a unit-level test. Add:

- **Test #19 (MUST-IMPLEMENT):** `AgentAssemblyService` with `interactive: false` constructs `ApprovalManager` with `auto_approve: true`; calling `check_approval` on an ASK-configured tool returns `[true, nil]`.

---

#### 14. [ADDED] Integration test must use VCR cassette path consistent with existing convention

The existing VCR-recorded test in `test/integration/agent_desk_runner_test.rb` uses `VCR.use_cassette("smart_proxy_chat_completion")`. The new integration test should follow the same naming convention: `"cli_dispatch_integration"`. Confirm that the VCR cassette directory is configured in `test_helper.rb` and add this cassette naming to the plan.

---

#### 15. [ADDED] `bin/legion` review — store at correct location for Architect feedback

Per RULES.md Φ9, the architect review must be stored as `{epic-dir}/feedback/plan-review.md`. The current review is appended to the implementation plan itself (as done for PRD-1-03), which is an acceptable alternate format — but the rules specify `feedback/` subfolder. This is a process note: the implementer should also save a copy of this review section to `knowledge_base/epics/wip/epic-1-orchestration-foundation/feedback/plan-review-PRD-1-04.md` after implementation is complete.

---

### Updated Test Count

| Category | Original | Added | Final Minimum |
|----------|----------|-------|---------------|
| Unit (AgentAssemblyService) | 8 | +1 (#19 auto-approve) | 9 |
| Unit (DispatchService) | 9 | +1 (#18 team_membership association) | 10 |
| Integration | 5 | 0 | 5 |
| System/Manual | 18 | 0 | 18 |
| **Total** | **40** | **+2** | **42 minimum** |

---

### Items the Plan Got Right (No Changes Required)

- **Service separation** — `AgentAssemblyService` + `DispatchService` is the correct decomposition. The assembly pipeline must be independently callable for PRD-1-06/1-07 reuse.
- **HookManager created empty** — correct deferral to PRD-1-05. `HookManager.new` with no handlers registered is nil-safe and won't block runner execution.
- **No migrations required** — confirmed. Schema from PRD-1-01 is sufficient.
- **Thor for CLI** — correct choice. Already in the Rails ecosystem; `OptionParser` is also acceptable but Thor gives better help formatting.
- **Exit code matrix** — complete and aligns with PRD. 0/1/2/3 are correctly assigned.
- **Error Path Matrix** — comprehensive. All 9 scenarios are covered.
- **`AgentTeam` lookup by name** — plan correctly says "within project" (scoping must be implemented per Amendment #4).
- **Pre-QA checklist acknowledged** — present and correct.
- **`bin/legion` as executable Ruby script** — correct. Must be `chmod +x`.
- **Dependency order** — PRD-1-01 → 1-02 → 1-03 → 1-04 is correctly stated.

---

### Architecture Notes for Implementer

1. **Assemble in order, test each step.** The assembly pipeline has 9 steps. A failure at step 3 (PromptsManager) should not produce a cryptic Runner error — add intermediate error handling with step-specific messages.
2. **`DispatchService` should NOT print to STDOUT directly.** The summary line and verbose streaming are CLI concerns. Pass a logger/IO object into `DispatchService` (e.g., `output: $stdout`) so the service can be called from non-CLI contexts in PRD-1-06/1-07 without console noise.
3. **`WorkflowRun#duration_ms`** — compute with `((Time.current - start_time) * 1000).to_i`. Do not use `Process.clock_gettime`; `Time.current` is timezone-aware and consistent with Rails conventions.
4. **Do not rescue `StandardError` at the top level of `DispatchService`.** Rescue specific exceptions where they are expected, and let unexpected exceptions propagate (or re-raise after updating `WorkflowRun`). A silent rescue at the top is an anti-pattern that buries real bugs.
5. **`frozen_string_literal: true`** — required on all three new files: `bin/legion`, `app/services/legion/agent_assembly_service.rb`, `app/services/legion/dispatch_service.rb`, and both test files.

PLAN-APPROVED