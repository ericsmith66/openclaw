# Agent-Forge Storage & Persistence Strategy

**Created:** 2026-03-03  
**Status:** Current Architecture (Post-Epic 5)  
**Context:** Clarifies what data lives where across filesystem, database, and memory

---

## Overview

Agent-Forge uses a **tri-storage architecture** combining filesystem, PostgreSQL database, and in-memory state. The choice of storage depends on data volatility, access patterns, and persistence requirements.

---

## Storage Layers

### 1. Filesystem (Git-Tracked)

**Purpose:** Configuration artifacts that benefit from version control, human editability, and portability.

**Location:** `.aider-desk/` directory structure (per-project or global)

**What's Stored:**

| Data Type | Path | Example | Why Filesystem? |
|-----------|------|---------|-----------------|
| **Agent Profiles (Gem Config)** | `.aider-desk/agents/{domain}/config.json` | `agents/ror/config.json` | Version control, portability, human-readable JSON |
| **Rules (Markdown Files)** | `.aider-desk/rules/*.md`, `.aider-desk/agents/{domain}/rules/*.md` | `rules/rails-best-practices.md` | Human authoring in markdown, 3-tier hierarchy (global/project/agent) |
| **Skills (Markdown + Frontmatter)** | `.aider-desk/skills/{skill-name}/skill.md` | `skills/rails-testing/skill.md` | Knowledge content in markdown, frontmatter metadata |
| **Custom Commands** | `.aider-desk/commands/*.md` | `commands/review-code.md` | Shareable via Git, editable in any text editor |
| **Prompt Templates** | `.aider-desk/prompts/*.liquid` | `prompts/system-prompt.liquid` | Liquid templates for system prompts |
| **Memory (Gem MemoryStore)** | `.aider-desk/memory.json` or `~/.agent_desk/memory.json` | JSON file with memories | Portable JSON, survives gem restarts |

**Key Characteristics:**
- ✅ **Version controlled** (Git)
- ✅ **Human-editable** (text editors, IDEs)
- ✅ **Portable** (copy .aider-desk/ to new project)
- ✅ **Shareable** (commit to repo)
- ❌ **No real-time sync** (manual file edits don't broadcast to UI)
- ❌ **No ACID transactions** (concurrent edits can conflict)

---

### 2. PostgreSQL Database (Rails ActiveRecord)

**Purpose:** Structured data requiring ACID transactions, real-time updates, complex queries, and multi-user collaboration.

**Location:** Agent-Forge Rails app PostgreSQL database

**What's Stored (Post-Epic 5):**

| Table | Purpose | Real-time Sync? | Why Database? |
|-------|---------|-----------------|---------------|
| `agent_profiles` | Agent profile configuration (model, temperature, tools, custom instructions) | ✅ Turbo Streams | Multi-user editing, validations, Turbo Stream broadcasts |
| `skills` | Skills with markdown content + frontmatter metadata | ✅ Turbo Streams | Search, filtering, activation tracking |
| `rules` | Rules with 3-tier hierarchy (global/project/agent) | ✅ Turbo Streams | Assembly service, hierarchy queries, preview |
| `custom_commands` | User-defined commands (slash commands + execution tracking) | ✅ Turbo Streams | Invocation tracking, workflow integration |
| `skill_activations` | Many-to-many: which skills active in which profiles | ✅ Turbo Streams | Dynamic activation, profile cloning |
| `rule_assignments` | Many-to-many: which rules assigned to which profiles | ✅ Turbo Streams | Dynamic assembly, profile cloning |
| `rule_assembly_caches` | Materialized view of assembled rule hierarchy | ✅ Background job | Performance optimization for complex queries |
| `command_invocations` | Audit log of custom command executions | ✅ Real-time | Debugging, analytics, workflow linking |
| `projects` | Project metadata | ✅ Turbo Streams | Scoping, multi-project support |
| `agent_tasks` | Agent task lifecycle tracking | ✅ ActionCable | Real-time progress, status updates |
| `artifacts` (Epic 6) | Workflow artifacts (PRDs, plans, feedback, logs) | ✅ Turbo Streams | Queryable history, version chains, hierarchy |
| `workflow_runs` (Epic 6) | Workflow execution state machine | ✅ ActionCable | Phase tracking, retry logic, gate enforcement |

**Key Characteristics:**
- ✅ **ACID transactions** (concurrent edits safe)
- ✅ **Real-time updates** (ActionCable + Turbo Streams)
- ✅ **Complex queries** (JOIN, GROUP BY, full-text search)
- ✅ **Validations** (ActiveRecord, uniqueness constraints)
- ✅ **Audit trail** (timestamps, lock_version for optimistic locking)
- ✅ **Multi-user** (scoped by user, project)
- ❌ **Not version controlled** (no Git history for DB changes)
- ❌ **Not portable** (requires DB dump/restore)

---

### 3. In-Memory (Process Lifetime)

**Purpose:** Ephemeral state tied to a specific agent run or task execution.

**What's Stored:**

| Data Type | Scope | Lifecycle | Why In-Memory? |
|-----------|-------|-----------|----------------|
| **Todo List (TodoTools)** | Per agent run | Task start → task complete | Temporary task planning, no persistence needed |
| **Task Registry (TaskTools)** | Per agent run | Task start → task complete | Lightweight CRUD for sub-tasks, no DB overhead |
| **Conversation History** | Per agent run | Task start → task complete (or compaction) | Managed by Runner, compacted when token budget exceeded |
| **Tool Approval State** | Per agent run | Task start → task complete | One-time approvals for current task |
| **LLM Streaming Chunks** | Per request | Request start → request complete | Temporary buffer for SSE streaming |
| **Hook Results** | Per event | Event trigger → event complete | Hook execution results, not persisted |

**Key Characteristics:**
- ✅ **Fast access** (no I/O)
- ✅ **No persistence overhead** (no disk writes)
- ✅ **Isolated** (per-task state doesn't leak)
- ❌ **Lost on crash** (no recovery)
- ❌ **Not queryable** (can't search across tasks)
- ❌ **Not shareable** (single process only)

---

## Data Flow & Sync Strategy

### Epic 5 Architecture: Database as Source of Truth

```
┌─────────────────────────────────────────────────────────────────┐
│                     Agent-Forge Rails App                       │
│                                                                 │
│  ┌───────────────┐    CRUD via UI    ┌──────────────────┐     │
│  │   Web UI      │ ───────────────► │  PostgreSQL DB   │     │
│  │ (Turbo/DaisyUI)│ ◄───────────────  │ (ActiveRecord)   │     │
│  └───────────────┘   Turbo Streams   └──────────────────┘     │
│                                              │                  │
│                                              │ Adapter Layer    │
│                                              ▼                  │
│                                       ┌──────────────────┐     │
│                                       │  agent_desk gem  │     │
│                                       │  (Ruby Structs)  │     │
│                                       └──────────────────┘     │
│                                              │                  │
│                                              │ Read-only        │
│                                              ▼                  │
│                                       ┌──────────────────┐     │
│                                       │  .aider-desk/    │     │
│                                       │  (Filesystem)    │     │
│                                       └──────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

**Key Decision (Epic 4B):**
> "Agent-Forge DB is source of truth for agent profiles/skills/prompts, syncs BACK to .aider-desk/ config files."

**Sync Direction:**
1. **Primary:** User edits in UI → Database → Adapter → Gem (in-process)
2. **Secondary (Optional):** Database → Filesystem export (for portability/backup)
3. **Legacy:** Filesystem → Database import (one-time migration via `rake epic:import`)

### Gem Usage During Task Execution

When `agent_desk` gem runs a task:

1. **Profile loaded from:**
   - **Option A (Epic 5+):** Agent-Forge fetches from DB → passes to gem as Ruby struct
   - **Option B (Standalone gem):** Gem loads from `.aider-desk/agents/{domain}/config.json`

2. **Rules loaded from:**
   - **Always filesystem** (3-tier hierarchy discovery):
     - Global: `~/.aider-desk/agents/{domain}/rules/*.md`
     - Project: `{project_dir}/.aider-desk/rules/*.md`
     - Agent: `{project_dir}/.aider-desk/agents/{domain}/rules/*.md`
   - Epic 5 DB rules → exported to filesystem before gem invocation (if needed)

3. **Skills loaded from:**
   - **Always filesystem**: `{project_dir}/.aider-desk/skills/{skill-name}/skill.md`
   - Epic 5 DB skills → exported to filesystem before gem invocation (if needed)

4. **Memory loaded from:**
   - **Gem's MemoryStore**: JSON file (`~/.agent_desk/memory.json`)
   - Survives gem restarts, but separate from Agent-Forge DB
   - Future: Could integrate with Agent-Forge DB memory tools

---

## Migration Paths

### Epic 5 Import: Filesystem → Database

**One-time migration:**
```bash
rake agent_profiles:import   # Import .aider-desk/agents/* → agent_profiles table
rake skills:import            # Import .aider-desk/skills/* → skills table
rake rules:import             # Import .aider-desk/rules/* → rules table
rake commands:import          # Import .aider-desk/commands/* → custom_commands table
```

**After import:**
- Filesystem files preserved as read-only backup
- All edits happen in UI → Database
- Optional: Periodic export from DB → filesystem for Git commits

### Epic 6 Import: Markdown Epics → Database

**One-time migration:**
```bash
rake epic:import              # Import knowledge_base/epics/* → artifacts table
```

**After import:**
- 262 markdown files → Artifact records
- Hierarchy preserved (PRDs → epics, feedback → epics)
- Filesystem files preserved as historical archive

---

## Storage Decision Matrix

When deciding where to store new data, use this flowchart:

```
Is data temporary (< 1 task)?
├─ YES → In-Memory (TodoTools, TaskTools, conversation buffer)
└─ NO  → Continue

Does data need Git version control?
├─ YES → Filesystem (.aider-desk/ config files)
└─ NO  → Continue

Does data need real-time multi-user sync?
├─ YES → Database (PostgreSQL + Turbo Streams)
└─ NO  → Continue

Does data need complex queries or relationships?
├─ YES → Database (PostgreSQL + ActiveRecord)
└─ NO  → Continue

Is data human-authored markdown/templates?
├─ YES → Filesystem (rules, skills, prompts)
└─ NO  → Database (structured data, logs, audit trails)
```

---

## Specific Examples

### Example 1: Agent Profile

**Before Epic 5:**
- Storage: `.aider-desk/agents/ror/config.json`
- Editing: Text editor, manual JSON edits
- Sync: None (manual Git commit)

**After Epic 5:**
- Storage: `agent_profiles` table in PostgreSQL
- Editing: Web UI with form validation
- Sync: Real-time Turbo Streams to all connected browsers
- Export: Optional periodic export to `.aider-desk/` for backup

### Example 2: Skill

**Before Epic 5:**
- Storage: `.aider-desk/skills/rails-testing/skill.md`
- Editing: Text editor, markdown file
- Discovery: Gem scans filesystem at runtime

**After Epic 5:**
- Storage: `skills` table in PostgreSQL (content + frontmatter)
- Editing: Web UI with markdown editor (SimpleMDE)
- Activation: `skill_activations` join table tracks which profiles use which skills
- Sync: Real-time Turbo Streams
- Export: Optional export to `.aider-desk/skills/` before gem invocation

### Example 3: Memory

**Current (Gem):**
- Storage: `~/.agent_desk/memory.json` (JSON file)
- Scope: Cross-task, cross-run (persistent)
- Access: Gem's MemoryStore class
- Isolation: Optional per-project via `project_id` field

**Future (Epic 6+?):**
- Could migrate to `memories` table in PostgreSQL
- Benefits: Real-time sync, complex queries, UI for memory management
- Trade-off: Gem would need adapter to read from Agent-Forge DB

### Example 4: Workflow Artifacts (Epic 6)

**Storage:** `artifacts` table in PostgreSQL
- epic_draft (Φ2), epic_consolidated (Φ4), PRD (Φ7), implementation_plan (Φ8), etc.
- Hierarchy via `parent_artifact_id` (PRDs → epics, feedback → epics)
- Phase tracking via `phase` field (phi_2, phi_5, phi_8, etc.)
- Versioning via `version` field + parent chains

**Not Filesystem:**
- Artifacts are workflow outputs, not configuration
- Need queryable history (all Φ9 plan reviews that failed)
- Need hierarchy navigation (show all PRDs for Epic 6)
- Real-time updates during workflow execution

---

## Performance Considerations

### Database (Hot Path)
- **Indexes:** All foreign keys, frequently queried fields (`epic_id`, `prd_number`, `phase`)
- **Caching:** `rule_assembly_caches` table materializes expensive queries
- **Pagination:** Large lists use cursor pagination (Pagy gem)
- **N+1 Prevention:** `includes(:skills, :rules)` for eager loading

### Filesystem (Read-Heavy)
- **Lazy Loading:** Rules/skills loaded only when profile activated
- **Caching:** Gem caches loaded rules per task (not re-read on every turn)
- **Glob Optimization:** `Dir.glob` with sort for deterministic ordering

### In-Memory (Fast)
- **No I/O:** Todo/task tools have zero persistence overhead
- **Compaction:** Conversation history compacted when token budget exceeded
- **Ephemeral:** State discarded after task completion

---

## Future Enhancements

### Potential Epic: Unified Storage Layer
1. **Migrate gem MemoryStore to Agent-Forge DB**
   - `memories` table with same schema as JSON file
   - Gem adapter reads from Agent-Forge DB via API
   - Benefits: UI for memory management, real-time sync, complex queries

2. **Hybrid Filesystem + DB for Rules/Skills**
   - DB as primary (editing, activation, search)
   - Filesystem as cache (exported before gem invocation)
   - Benefits: Best of both worlds (version control + real-time UI)

3. **Event Sourcing for Audit Trail**
   - All changes logged as events (created, updated, deleted)
   - Enables rollback, diff view, compliance
   - Table: `audit_events` with JSONB payload

---

## Summary Table

| Data Type | Filesystem | PostgreSQL DB | In-Memory | Notes |
|-----------|------------|---------------|-----------|-------|
| **Agent Profiles** | Legacy (pre-Epic 5) | ✅ Primary (Epic 5+) | ❌ | DB → adapter → gem |
| **Skills** | Legacy (pre-Epic 5) | ✅ Primary (Epic 5+) | ❌ | DB → export → filesystem → gem |
| **Rules** | ✅ Primary (gem loads from disk) | ✅ Primary (Epic 5+) | ❌ | DB → export → filesystem → gem |
| **Custom Commands** | Legacy | ✅ Primary (Epic 5+) | ❌ | Execution via Coordinator |
| **Memory (Gem)** | ✅ JSON file | ❌ Future? | ❌ | Persistent across runs |
| **Todo List** | ❌ | ❌ | ✅ Primary | Per-task only |
| **Task Registry** | ❌ | ❌ | ✅ Primary | Per-task only |
| **Conversation** | ❌ | ❌ | ✅ Primary | Per-task, compacted |
| **Workflow Artifacts** | Legacy (epics) | ✅ Primary (Epic 6+) | ❌ | Queryable history |
| **Workflow State** | ❌ | ✅ Primary (Epic 6+) | ❌ | Phase tracking, gates |

---

## Key Architectural Principles

1. **Database for Collaboration** — Multi-user, real-time, transactional
2. **Filesystem for Portability** — Git-trackable, human-editable, shareable
3. **In-Memory for Ephemerality** — Fast, no overhead, task-scoped
4. **Sync is Explicit** — No magic sync; clear ownership and direction
5. **Adapter for Integration** — Gem remains filesystem-first; Agent-Forge adds DB layer

---

**Last Updated:** 2026-03-03  
**Related Docs:**
- Epic 5: File Maintenance UI (database schema)
- Epic 6: WorkflowEngine (artifact storage)
- agent_desk gem: Memory, Skills, Rules loaders
