# Epic-Workflow: Complete File Modification List

This document lists every file that will be **created**, **modified**, or **deleted** during the implementation of Epic-WF (Implement the Agent-Forge Workflow Framework), organized by PRD.

**Base Path**: `/Users/ericsmith66/development/agent-forge`

---

## PRD WF-01: Generalize Base Rules & Fix Commit Policy

**Status**: Not Started  
**Goal**: Remove HomeKit references and fix commit policy across all config files.

### Files to Modify (3)

1. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/rules/rails-base-rules.md`**
   - Action: MODIFY
   - Changes:
     - Update title from "Rails 8 Base Rules for Eureka HomeKit" to "Rails 8 Base Rules"
     - Remove all HomeKit-specific references (Eureka, characteristic_uuid, LockControlComponent, etc.)
     - Update commit policy to "Commit plans always; commit code when tests pass (green)"
     - Keep destructive git command prohibition

2. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/prompts/delegation-rules.md`**
   - Action: MODIFY
   - Changes:
     - Add explicit green gate for code commits
     - Ensure plan commits are unconditional
     - Align with agreed commit policy

3. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-rails/config.json`**
   - Action: MODIFY
   - Changes:
     - Update COMMIT LOGIC section in systemPrompt field
     - Ensure commit policy matches "commit plans always; commit code when green"

### Verification Files (Read-Only)

- All files in `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/` (grep for HomeKit references)

---

## PRD WF-02: Create Human Command Files

**Status**: Not Started  
**Goal**: Create the three missing human-run workflow command files.

### Files to Create (3)

1. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/turn-idea-into-epic.md`**
   - Action: CREATE
   - Source: `prompt-definitions.md` → `/turn-idea-into-epic` section
   - Content:
     - Reference RULES.md Φ1–Φ2
     - Require PRD summary table output
     - Reference epic template
     - Use `{{1}}` templating for idea input

2. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/get-feedback-on-epic.md`**
   - Action: CREATE
   - Source: `prompt-definitions.md` → `/get-feedback-on-epic` section
   - Content:
     - Reference RULES.md Φ4–Φ6
     - Delegate to `ror-architect` for review
     - Require Questions / Suggestions / Objections format
     - Require solutions for every objection
     - Reference PRD template

3. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/finalize-epic.md`**
   - Action: CREATE
   - Source: `prompt-definitions.md` → `/finalize-epic` section
   - Content:
     - Reference RULES.md Φ7
     - Create individual PRD files following RULES.md Part 3 naming
     - Create `0001-IMPLEMENTATION-STATUS.md`
     - Delegate to `ror-architect` for `/plan-epic`
     - Commit all artifacts per policy

### Reference Files (Read-Only)

- `/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/prompt-definitions.md`

---

## PRD WF-03: Update implement-prd and Legacy Commands

**Status**: Not Started  
**Goal**: Update implement-prd command and clean up legacy commands.

### Files to Modify (4)

1. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/implement-prd.md`**
   - Action: MODIFY (replace content)
   - Source: `prompt-definitions.md` → `/implement-prd` section
   - Changes:
     - Replace with full Blueprint loop (Φ8–Φ12)
     - Require adherence to approved PRD plan
     - Include escalation paths (3 revisions, 3 QA cycles)
     - Include `/log-task` and `/update-implementation-status` as byproducts
     - State commit policy

2. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/review-epic.md`**
   - Action: MODIFY (repurpose)
   - Changes:
     - Add header: "INTERNAL — invoked by `/get-feedback-on-epic`, not by humans directly"
     - Update content to serve as internal architect delegation target
     - Align with architect review prompt from `prompt-definitions.md`

3. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/implement-plan.md`**
   - Action: MODIFY (document as internal)
   - Changes:
     - Add header: "INTERNAL — used after PLAN-APPROVED for re-runs. Not a human command."
     - Keep existing content but ensure it references the approved plan

4. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/roll-call.md`**
   - Action: MODIFY
   - Changes:
     - Replace bare agent IDs with `ror-*` prefixed versions
     - `architect` → `ror-architect`
     - `qa` → `ror-qa`
     - `debug` → `ror-debug`
     - `rails` → `ror-rails`

5. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/validate-installation.md`**
   - Action: MODIFY
   - Changes:
     - Replace bare agent IDs with `ror-*` prefixed versions

### Files to Delete (1)

6. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/commands/audit-homekit.md`**
   - Action: DELETE
   - Reason: HomeKit-specific command, no longer needed

---

## PRD WF-04: Update Agent System Prompts

**Status**: Not Started  
**Goal**: Update agent system prompts to align with workflow requirements.

### Files to Modify (3)

1. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-qa/config.json`**
   - Action: MODIFY (systemPrompt field)
   - Changes:
     - Add explicit Minitest mention
     - Add reference to RULES.md Φ11 QA rubric
     - State ≥ 90 pass threshold
     - Include rubric weights: AC Compliance 30, Test Coverage 30, Code Quality 20, Plan Adherence 20

2. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-debug/config.json`**
   - Action: MODIFY (systemPrompt field)
   - Changes:
     - Strengthen from generic "Troubleshooting Specialist"
     - Require reproduction steps (expected/actual)
     - Require root cause analysis with evidence
     - Require minimal fix plan
     - Require exact verification tests to run

3. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-rails/config.json`**
   - Action: VERIFY (already modified in WF-01, verify here)
   - Verification:
     - Confirm no HomeKit-specific references
     - Confirm commit logic matches agreed policy
     - Confirm Minitest is referenced (not RSpec)

### Files to Verify (1)

4. **`/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/agents/ror-architect/config.json`**
   - Action: VERIFY (no changes expected)
   - Verification:
     - Confirm prompt is generic enough
     - Confirm it references plan review and feedback conventions

---

## PRD WF-05: Validate & Align Documentation

**Status**: Not Started  
**Goal**: Final validation pass to ensure consistency across all config files and documentation.

### Files to Modify (1-3, as needed)

1. **`/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/workflow-table-of-contence.md`**
   - Action: MODIFY
   - Changes:
     - Add three new command files (from WF-02)
     - Mark `audit-homekit.md` as removed
     - Mark `review-epic.md` as repurposed to internal
     - Mark `implement-plan.md` as internal-only
     - Update agent entries to reflect prompt changes (WF-04)
     - Remove asterisks from completed items
     - Add ✅ markers for completed changes

2. **`/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/workflow.md`** (if inconsistencies found)
   - Action: MODIFY (conditional)
   - Changes: Update to resolve any inconsistencies found during validation

3. **`/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/how-to-use-workflow.md`** (if inconsistencies found)
   - Action: MODIFY (conditional)
   - Changes: Update to resolve any inconsistencies found during validation

4. **`/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/prompt-definitions.md`** (if inconsistencies found)
   - Action: MODIFY (conditional)
   - Changes: Update to resolve any inconsistencies found during validation

5. **`/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/workflow-implementaion-plan.md`**
   - Action: MODIFY (mark checklist items as complete)
   - Changes: Mark all Section I validation checklist items as [x] after verification

### Files to Verify (All ror-agent-config files)

- All files in `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/` (grep for RSpec, verify consistency)

### Skills to Verify (10)

All skill files should be checked for RSpec references (replace with Minitest if found):

- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/agent-forge-logging/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-best-practices/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-capybara-system-testing/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-daisyui-components/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-error-handling-logging/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-minitest-vcr/SKILL.md` (verify Minitest is correct)
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-service-patterns/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-tailwind-ui/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-turbo-hotwire/SKILL.md`
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/skills/rails-view-components/SKILL.md`

---

## PRD WF-06: Deploy Agent Config to Target Projects

**Status**: Not Started  
**Goal**: Deploy validated config to all target projects using sync script.

### Files to Deploy (Read-Only Source)

**Source Configuration** (entire directory synced to each project):
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/` (entire directory tree)

**RULES.md Source**:
- `/Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md`

### Target Projects (4)

For each project below, the sync script will create/overwrite files in `.aider-desk/` and `knowledge_base/`:

#### 1. nextgen-plaid

**Deployment Target**: `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid`

Files created/overwritten:
- `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/.aider-desk/agents/` (all agent configs with project-specific IDs)
- `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/.aider-desk/commands/` (all command files)
- `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/.aider-desk/rules/` (generalized rules)
- `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/.aider-desk/prompts/` (delegation rules)
- `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/.aider-desk/skills/` (all skill files)
- `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/knowledge_base/epics/instructions/RULES.md` (copied from source)

#### 2. eureka

**Deployment Target**: `/Users/ericsmith66/development/agent-forge/projects/eureka`

Files created/overwritten:
- `/Users/ericsmith66/development/agent-forge/projects/eureka/.aider-desk/agents/` (all agent configs with project-specific IDs)
- `/Users/ericsmith66/development/agent-forge/projects/eureka/.aider-desk/commands/` (all command files)
- `/Users/ericsmith66/development/agent-forge/projects/eureka/.aider-desk/rules/` (generalized rules)
- `/Users/ericsmith66/development/agent-forge/projects/eureka/.aider-desk/prompts/` (delegation rules)
- `/Users/ericsmith66/development/agent-forge/projects/eureka/.aider-desk/skills/` (all skill files)
- `/Users/ericsmith66/development/agent-forge/projects/eureka/knowledge_base/epics/instructions/RULES.md` (copied from source)

#### 3. SmartProxy

**Deployment Target**: `/Users/ericsmith66/development/agent-forge/projects/SmartProxy`

Files created/overwritten:
- `/Users/ericsmith66/development/agent-forge/projects/SmartProxy/.aider-desk/agents/` (all agent configs with project-specific IDs)
- `/Users/ericsmith66/development/agent-forge/projects/SmartProxy/.aider-desk/commands/` (all command files)
- `/Users/ericsmith66/development/agent-forge/projects/SmartProxy/.aider-desk/rules/` (generalized rules)
- `/Users/ericsmith66/development/agent-forge/projects/SmartProxy/.aider-desk/prompts/` (delegation rules)
- `/Users/ericsmith66/development/agent-forge/projects/SmartProxy/.aider-desk/skills/` (all skill files)
- `/Users/ericsmith66/development/agent-forge/projects/SmartProxy/knowledge_base/epics/instructions/RULES.md` (copied from source)

#### 4. agent-forge

**Deployment Target**: `/Users/ericsmith66/development/agent-forge/projects/agent-forge`

Files created/overwritten:
- `/Users/ericsmith66/development/agent-forge/projects/agent-forge/.aider-desk/agents/` (all agent configs with project-specific IDs)
- `/Users/ericsmith66/development/agent-forge/projects/agent-forge/.aider-desk/commands/` (all command files)
- `/Users/ericsmith66/development/agent-forge/projects/agent-forge/.aider-desk/rules/` (generalized rules)
- `/Users/ericsmith66/development/agent-forge/projects/agent-forge/.aider-desk/prompts/` (delegation rules)
- `/Users/ericsmith66/development/agent-forge/projects/agent-forge/.aider-desk/skills/` (all skill files)
- `/Users/ericsmith66/development/agent-forge/projects/agent-forge/knowledge_base/epics/instructions/RULES.md` (copied from source)

### Deployment Log (1 file created)

**Documentation File**:
- `/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/deployment-log-{timestamp}.md`
  - Action: CREATE
  - Content: Audit trail of all deployments (timestamps, sync output, test results)

---

## Summary Statistics

### Source Configuration Changes (ror-agent-config)

| Operation | Count | Files |
|-----------|-------|-------|
| **Modify** | 10 | rules (1), prompts (1), agents (4), commands (4) |
| **Create** | 3 | commands (3 new human commands) |
| **Delete** | 1 | commands (audit-homekit.md) |
| **Verify** | 11 | agents (1), skills (10) |
| **Total** | 25 | Unique config files touched |

### Documentation Changes (epic-workflow)

| Operation | Count | Files |
|-----------|-------|-------|
| **Modify** | 1-5 | TOC (1), workflow docs (0-4 conditional) |
| **Create** | 1 | deployment-log (1) |
| **Total** | 2-6 | Documentation files |

### Deployment Targets (WF-06)

| Operation | Count | Details |
|-----------|-------|---------|
| **Projects** | 4 | nextgen-plaid, eureka, SmartProxy, agent-forge |
| **Files per project** | ~30+ | Entire .aider-desk/ tree + RULES.md |
| **Total deployments** | 120+ | All files across all projects |

---

## Complete File List (Alphabetical)

### Source Configuration Files (Modified/Created/Deleted)

```
/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/
├── agents/
│   ├── ror-architect/config.json          [VERIFY - WF-04]
│   ├── ror-debug/config.json              [MODIFY - WF-04]
│   ├── ror-qa/config.json                 [MODIFY - WF-04]
│   └── ror-rails/config.json              [MODIFY - WF-01, VERIFY - WF-04]
├── commands/
│   ├── audit-homekit.md                   [DELETE - WF-03]
│   ├── finalize-epic.md                   [CREATE - WF-02]
│   ├── get-feedback-on-epic.md            [CREATE - WF-02]
│   ├── implement-plan.md                  [MODIFY - WF-03]
│   ├── implement-prd.md                   [MODIFY - WF-03]
│   ├── review-epic.md                     [MODIFY - WF-03]
│   ├── roll-call.md                       [MODIFY - WF-03]
│   ├── turn-idea-into-epic.md             [CREATE - WF-02]
│   └── validate-installation.md           [MODIFY - WF-03]
├── prompts/
│   └── delegation-rules.md                [MODIFY - WF-01]
├── rules/
│   └── rails-base-rules.md                [MODIFY - WF-01]
└── skills/
    ├── agent-forge-logging/SKILL.md       [VERIFY - WF-05]
    ├── rails-best-practices/SKILL.md      [VERIFY - WF-05]
    ├── rails-capybara-system-testing/SKILL.md [VERIFY - WF-05]
    ├── rails-daisyui-components/SKILL.md  [VERIFY - WF-05]
    ├── rails-error-handling-logging/SKILL.md [VERIFY - WF-05]
    ├── rails-minitest-vcr/SKILL.md        [VERIFY - WF-05]
    ├── rails-service-patterns/SKILL.md    [VERIFY - WF-05]
    ├── rails-tailwind-ui/SKILL.md         [VERIFY - WF-05]
    ├── rails-turbo-hotwire/SKILL.md       [VERIFY - WF-05]
    └── rails-view-components/SKILL.md     [VERIFY - WF-05]
```

### Documentation Files (Modified/Created)

```
/Users/ericsmith66/development/agent-forge/projects/aider-desk/knowledge_base/epics/epic-workflow/
├── deployment-log-{timestamp}.md          [CREATE - WF-06]
├── how-to-use-workflow.md                 [MODIFY CONDITIONAL - WF-05]
├── prompt-definitions.md                  [MODIFY CONDITIONAL - WF-05]
├── workflow-implementaion-plan.md         [MODIFY - WF-05]
├── workflow-table-of-contence.md          [MODIFY - WF-05]
└── workflow.md                            [MODIFY CONDITIONAL - WF-05]
```

### RULES.md (Deployed to All Projects)

```
/Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md      [READ-ONLY SOURCE]

Deployed to:
  /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/knowledge_base/epics/instructions/RULES.md
  /Users/ericsmith66/development/agent-forge/projects/eureka/knowledge_base/epics/instructions/RULES.md
  /Users/ericsmith66/development/agent-forge/projects/SmartProxy/knowledge_base/epics/instructions/RULES.md
  /Users/ericsmith66/development/agent-forge/projects/agent-forge/knowledge_base/epics/instructions/RULES.md
```

---

## Deployment Command Reference

### Sync Script Invocations (WF-06)

```bash
# Base path
BASE=/Users/ericsmith66/development/agent-forge

# Deploy to nextgen-plaid
$BASE/scripts/sync-aider-config.sh projects/nextgen-plaid ror

# Deploy to eureka
$BASE/scripts/sync-aider-config.sh projects/eureka ror

# Deploy to SmartProxy
$BASE/scripts/sync-aider-config.sh projects/SmartProxy ror

# Deploy to agent-forge
$BASE/scripts/sync-aider-config.sh projects/agent-forge ror
```

### RULES.md Copy Commands (WF-06)

```bash
# Copy RULES.md to each project
BASE=/Users/ericsmith66/development/agent-forge

# nextgen-plaid
mkdir -p $BASE/projects/nextgen-plaid/knowledge_base/epics/instructions
cp $BASE/knowledge_base/instructions/RULES.md \
   $BASE/projects/nextgen-plaid/knowledge_base/epics/instructions/RULES.md

# eureka
mkdir -p $BASE/projects/eureka/knowledge_base/epics/instructions
cp $BASE/knowledge_base/instructions/RULES.md \
   $BASE/projects/eureka/knowledge_base/epics/instructions/RULES.md

# SmartProxy
mkdir -p $BASE/projects/SmartProxy/knowledge_base/epics/instructions
cp $BASE/knowledge_base/instructions/RULES.md \
   $BASE/projects/SmartProxy/knowledge_base/epics/instructions/RULES.md

# agent-forge
mkdir -p $BASE/projects/agent-forge/knowledge_base/epics/instructions
cp $BASE/knowledge_base/instructions/RULES.md \
   $BASE/projects/agent-forge/knowledge_base/epics/instructions/RULES.md
```

---

## Implementation Order

1. **WF-01**: Modify 3 files (rules, prompts, agent config)
2. **WF-02**: Create 3 files (human commands)
3. **WF-03**: Modify 5 files + delete 1 file (implement-prd, legacy commands)
4. **WF-04**: Modify 3 files (agent system prompts)
5. **WF-05**: Verify all files, modify 1-5 docs as needed
6. **WF-06**: Deploy to 4 projects (120+ files created/overwritten)

**Total Source Files Modified/Created**: 14 files  
**Total Source Files Deleted**: 1 file  
**Total Files Verified**: 11 files  
**Total Documentation Files**: 2-6 files  
**Total Deployment Artifacts**: 120+ files (across 4 projects)

---

## Notes

- All paths are relative to `/Users/ericsmith66/development/agent-forge` unless otherwise specified
- The sync script is idempotent — running it multiple times is safe
- Project-specific agent IDs are generated automatically by the sync script
- `.aider-desk/` files in target projects should never be edited manually
- Always re-run the sync script after source config changes
- RULES.md must exist in each project for agents to function properly

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-23  
**Epic**: Epic-WF (Implement the Agent-Forge Workflow Framework)
