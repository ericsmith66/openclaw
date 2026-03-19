# Agent-Forge Epic 6 → Legion Epic 2 Reconciliation Analysis

**Created:** 2026-03-08
**Purpose:** Map Agent-Forge Epic 6 (WorkflowEngine) plans against what Legion Epic 1 already delivered, to inform Legion Epic 2 scope.

---

## Executive Summary

Agent-Forge Epic 6 was a 24-PRD, 25-week plan across 4 sub-epics (6A–6D) to build a WorkflowEngine. **Legion Epic 1 already delivered roughly 60-65% of the foundational infrastructure** planned in 6A and significant portions of 6B, but in a CLI-first architecture that skips the web UI entirely. The remaining ~35-40% falls into three categories:

1. **WorkflowEngine state machine & automatic chaining** (core of 6B) — NOT built yet
2. **Quality & human gates** (all of 6C) — NOT built yet  
3. **UI & observability** (all of 6D) — NOT built yet, and not needed yet (CLI-first)

Legion Epic 2 should focus on items #1 and #2 (automation + gates) since we've proven the CLI-first approach works. UI can wait for Epic 4.

---

## Detailed PRD-by-PRD Reconciliation

### Epic 6A: Integration-Gem-UI-Model (4.5 weeks planned)

| 6A PRD | What It Planned | Legion Status | Notes |
|--------|----------------|---------------|-------|
| **6A-00** AgentTeam Data Model | AgentTeam, TeamMembership, TeamProject tables | ✅ **DONE** (PRD 1-01) | Legion has `agent_teams`, `team_memberships` with JSONB config. No `team_projects` join table — team belongs_to project directly. Simpler and sufficient. |
| **6A-01** Team UI Extension | Teams tab in web UI, team browser, CRUD | ❌ **SKIPPED** | Legion is CLI-first. No web UI. Not needed for Epic 2. Deferred to Epic 4. |
| **6A-02** DatabaseProfileLoader | Service to load TeamMembership → Profile objects | ✅ **DONE** (PRD 1-04) | `TeamMembership#to_profile` converts JSONB config → `AgentDesk::Agent::Profile`. `AgentAssemblyService` does the full pipeline. |
| **6A-03** ROR Team Import | Rake task importing `.aider-desk/agents/` | ✅ **DONE** (PRD 1-03) | `rake teams:import[~/.aider-desk]` — `TeamImportService` with dry-run and upsert support. |
| **6A-04** CLI Execution Command | `bin/agent_forge execute --team --prd` | ✅ **DONE** (PRD 1-04) | `bin/legion execute --team ROR --agent rails-lead --prompt "..."` with full assembly pipeline. |
| **6A-05** Blueprint PRD Validation | Execute real PRD using database team | ✅ **DONE** (PRD 1-08) | Validated with SmartProxy PRD 5-1 (ModelFilter) and PRD 5-2 (ModelAggregator). Real-world execution confirmed working. |

**6A Summary: 5/6 PRDs delivered. Only web UI (6A-01) skipped — intentionally.**

---

### Epic 6B: WorkflowEngine Core (6 weeks planned)

| 6B PRD | What It Planned | Legion Status | Notes |
|--------|----------------|---------------|-------|
| **6B-01** WorkflowRun & Artifact Models | workflow_runs table + enhanced artifacts table | ⚠️ **PARTIAL** | `WorkflowRun` exists with full status tracking (queued/running/completed/failed/at_risk/etc), duration, iterations, result, metadata JSONB. **Missing:** Artifact model entirely — results stored as `WorkflowRun.result` text. No `epic_id`, `prd_number`, `phase`, `version`, `parent_artifact_id`. |
| **6B-02** WorkflowEngine State Machine | Φ1-Φ13 phase transitions, automatic chaining | ❌ **NOT BUILT** | This is the core gap. Legion has no state machine. Human manually runs `decompose` then `execute-plan`. No automatic Plan→Approve→Code→QA chaining. |
| **6B-03** PromptBuilder Service | Phase-specific prompts from templates + context | ⚠️ **PARTIAL** | `DecompositionService` has a prompt template (`decomposition_prompt.md.erb`). But there's no generic PromptBuilder for arbitrary phases. Each CLI command constructs its own prompt. |
| **6B-04** TaskRouter & GemDispatchJob | Route to gem vs SmartProxy, async execution | ⚠️ **PARTIAL** | `DispatchService` handles gem Runner dispatch. No TaskRouter abstraction — everything goes through gem Runner (no SmartProxy-only reasoning path). No Solid Queue background jobs — runs synchronously in CLI. |
| **6B-05** SmartProxy Integration | HTTP client for reasoning-only phases | ⚠️ **PARTIAL** | All SmartProxy communication goes through gem's `ModelManager`. No standalone SmartProxy HTTP client for reasoning-only phases (no tool calls). This may be fine — gem's ModelManager already handles it. |
| **6B-06** Workflow Commands | `/draft`, `/implement` in Coordinator | ❌ **NOT BUILT** | No web Coordinator. CLI commands are `bin/legion execute`, `bin/legion decompose`, `bin/legion execute-plan`. No automatic workflow triggers. |

**6B Summary: 0/6 fully delivered. WorkflowRun model exists but no state machine, no automatic chaining, no Artifact model. This is the primary scope for Legion Epic 2.**

---

### Epic 6C: Quality & Human Gates (6.5 weeks planned)

| 6C PRD | What It Planned | Legion Status | Notes |
|--------|----------------|---------------|-------|
| **6C-01** QualityGate Base & Score Parsing | Base class, LLM score extraction, thresholds | ❌ **NOT BUILT** | No gate logic. QA agent can score (via manual dispatch), but no automated score parsing or threshold enforcement. |
| **6C-02** ArchitectGate (Φ9) | Plan review scoring ≥90 | ❌ **NOT BUILT** | Architect can review (manual dispatch), but no automated gate. |
| **6C-03** QAGate (Φ11) | Code scoring ≥90, return to debug | ❌ **NOT BUILT** | QA can score (manual dispatch), but no auto-retry loop. |
| **6C-04** Retry Logic & Escalation | Auto-retry (max 3), context accumulation | ❌ **NOT BUILT** | No retry logic. Failed tasks stay `failed`. |
| **6C-05** HumanGate Base & UI | Workflow pausing, approval forms | ❌ **NOT BUILT** | No workflow to pause. CLI-driven = human IS the gate. |
| **6C-06** EpicApprovalGate & FeedbackGate | Φ3, Φ6 gates with UI | ❌ **NOT BUILT** | N/A in CLI-first mode. |

**6C Summary: 0/6 delivered. However, the infrastructure needed (agent dispatch, scoring prompts) exists. The automation layer is what's missing. This is the secondary scope for Legion Epic 2.**

---

### Epic 6D: UI & Observability (8 weeks planned)

| 6D PRD | What It Planned | Legion Status | Notes |
|--------|----------------|---------------|-------|
| **6D-01** Workflow UI Components (PRD 6-11) | Status badges, phase timeline, Turbo Streams | ❌ **NOT BUILT** | Deferred to Epic 4. CLI output has basic progress (task counter, elapsed times, tokens). |
| **6D-02** Custom Command Execution (PRD 6-12) | Slash commands trigger workflows | ❌ **NOT BUILT** | Not needed in CLI-first mode. |
| **6D-03** Epic/PRD Import (PRD 6-13) | Migrate 262 markdown files to DB | ❌ **NOT BUILT** | PRDs stay as filesystem files. `decompose` reads PRD from path. |
| **6D-04** Observability Dashboard | Admin view, filters, drill-down | ❌ **NOT BUILT** | Have `scripts/check_progress.rb` for basic monitoring. |
| **6D-05** Audit Trail & Logging | Structured audit logs | ⚠️ **PARTIAL** | `WorkflowEvent` table captures all gem events. No separate audit_logs table. Event trail is queryable. |
| **6D-06** M1.5 PostgresBus Integration | Replace EventRelay, wire ActionCable | ✅ **DONE** (PRD 1-02) | `Legion::PostgresBus` replaces EventRelay entirely. Persists to WorkflowEvent. CallbackBus for in-process hooks. Solid Cable broadcast stub ready. |

**6D Summary: 1/6 delivered (PostgresBus). Event trail exists. UI deferred intentionally.**

---

## What Agent-Forge Epic 6 Got Wrong (for Legion's Context)

### 1. Over-Invested in UI Before Proving Orchestration
Epic 6 spent 8 weeks (33% of timeline) on UI components before the engine was proven. Legion's CLI-first approach was right — we proved real-world execution against SmartProxy Epic 5 without any UI.

### 2. Many-to-Many Teams Was Over-Engineered
6A planned `TeamProject` join table for teams across multiple projects. Legion's simpler `agent_teams.project_id` FK is sufficient — one team per project. If needed later, it's a trivial migration.

### 3. Artifact Model Was Premature
6B-01 planned a complex Artifact model with 11 types, versioning, parent chains. Legion deferred this correctly — `WorkflowRun.result` text is sufficient until there's a state machine producing structured outputs that need versioning.

### 4. SmartProxy "Reasoning-Only" Client Was Unnecessary
The gem's `ModelManager` already handles SmartProxy. No need for a separate HTTP client — just use the gem without tools for reasoning-only phases.

### 5. Human Gate UI Was Premature
In CLI mode, the human IS the gate. Building approval forms before having automatic chaining is backwards.

---

## What Legion Epic 1 Still Needs (Bugs/Improvements from Real-World Testing)

These emerged from testing against SmartProxy Epic 5 and should be addressed before or alongside Epic 2:

| Item | Status | Priority |
|------|--------|----------|
| ~~Bundler.with_unbundled_env~~ for target project commands | ✅ Fixed | — |
| ~~Show WorkflowRun ID in decompose output~~ | ✅ Fixed | — |
| ~~bin/legion delete-run command~~ | ✅ Fixed | — |
| ~~DecompositionParser greedy regex for nested code fences~~ | ✅ Fixed | — |
| `bin/legion score` command (QA scoring CLI) | ❌ Not built | High — needed for Epic 2 gates |
| Parallel task execution via Solid Queue | ❌ Not built | High — planned for Epic 2 |
| Auto-approve all tools for non-interactive runs | ❌ Partial | Medium |
| Task re-run (reset single task to pending) | ❌ Not built | Medium |
| Better error recovery (resume from failed task) | ❌ Partial | Medium |

---

## Recommended Legion Epic 2 Scope

Based on this reconciliation, Legion Epic 2 should cover what Agent-Forge 6B (minus UI) + 6C (minus UI) planned, plus the CLI improvements that emerged from real-world testing.

### Epic 2: WorkflowEngine & Quality Gates (CLI-First)

**Estimated: 6-8 weeks, 8-10 PRDs**

#### Phase 1: Parallel Execution & Score Command (2 weeks)
- **PRD 2-01**: Parallel task dispatch via Solid Queue (ready tasks run concurrently)
- **PRD 2-02**: `bin/legion score` command (dispatch QA agent, parse score, store result)
- **PRD 2-03**: Task re-run and error recovery (reset tasks, resume from failure)

#### Phase 2: WorkflowEngine State Machine (2-3 weeks)
- **PRD 2-04**: WorkflowEngine service — state machine encoding phase transitions (Plan→Approve→Code→QA→Log)
- **PRD 2-05**: Artifact model — structured output storage with type, phase, parent chain (only needed once state machine produces typed outputs)
- **PRD 2-06**: PromptBuilder service — phase-specific prompt construction from templates

#### Phase 3: Quality Gates & Auto-Retry (2-3 weeks)
- **PRD 2-07**: QualityGate base class with score parsing, threshold checking
- **PRD 2-08**: ArchitectGate (plan review ≥90) + QAGate (code review ≥90)
- **PRD 2-09**: Retry logic (max 3 attempts, context accumulation, escalation)

#### Phase 4: End-to-End Automation (1 week)
- **PRD 2-10**: `bin/legion implement <prd-path>` — full Blueprint loop (decompose → plan → approve → code → QA) with gates and retry

### What's Explicitly Deferred to Epic 3+
- Human gates (Φ3, Φ6 approval UI) — CLI mode: human is the orchestrator
- Workflow UI components — Epic 4
- Custom command execution — Epic 4
- Epic/PRD import to database — Epic 4
- Observability dashboard — Epic 4
- TaskRouter (gem vs SmartProxy routing) — evaluate if needed; gem handles everything currently

---

## Key Architectural Decisions for Epic 2

| # | Decision | Rationale |
|---|----------|-----------|
| **D-1** | CLI-first, no web UI in Epic 2 | Proven by Epic 1 real-world testing. UI adds weeks without proving orchestration. |
| **D-2** | Solid Queue for parallel dispatch | DAG already designed for it. Same model, new dispatcher. |
| **D-3** | Artifact model only after state machine | No point storing typed artifacts until something produces them automatically. |
| **D-4** | Score parsing via QA agent dispatch | Reuse existing dispatch pipeline. QA agent already has scoring skills/rubric. |
| **D-5** | Per-project mutex for concurrent workflows | Simplest solution for file conflict. Advisory lock in PostgreSQL. |
| **D-6** | No separate SmartProxy client | gem's ModelManager handles it. Use gem without tools for reasoning-only phases. |

---

## Scorecard: Agent-Forge Epic 6 Coverage

| Sub-Epic | PRDs Planned | Legion Delivered | Remaining for Epic 2 | Deferred to Epic 3+ |
|----------|-------------|-----------------|----------------------|---------------------|
| **6A** (Integration) | 6 | 5 (83%) | 0 | 1 (UI) |
| **6B** (Engine Core) | 6 | 0 full, 3 partial | 4-5 | 1 (web commands) |
| **6C** (Gates) | 6 | 0 | 3-4 | 2 (human gate UI) |
| **6D** (UI/Observability) | 6 | 1 (PostgresBus) | 0 | 5 (all UI) |
| **TOTAL** | 24 | 6 full + 4 partial | 8-10 | 9 |

**Bottom line:** Legion Epic 2 needs ~8-10 PRDs to deliver the automation + gates that Agent-Forge Epic 6 planned across 6B+6C. The UI (6D) is deferred to Epic 4. This should take 6-8 weeks instead of Agent-Forge's planned 25 weeks, because:
1. Foundation already exists (schema, dispatch, event pipeline, assembly)
2. No UI overhead (saves 8 weeks)
3. CLI-first means faster iteration
4. Real-world testing already done (SmartProxy PRDs 5-1, 5-2)
