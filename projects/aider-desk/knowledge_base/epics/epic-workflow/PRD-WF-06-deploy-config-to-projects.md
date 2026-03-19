#### PRD-WF-06: Deploy Agent Config to Target Projects

**Epic**: Epic-WF (Implement the Agent-Forge Workflow Framework)  
**Status**: Not Started  
**Dependencies**: WF-01, WF-02, WF-03, WF-04, WF-05

---

### Overview

After the `ror-agent-config` is fully validated and generalized (WF-01 through WF-05), it must be deployed to all Agent-Forge projects that will use the workflow framework. This includes running the sync script (`/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh`) to deploy the configuration bundle to each target project's `.aider-desk/` directory.

Additionally, critical workflow documentation files (like `RULES.md`) that are referenced by the agent config but live outside the config bundle need to be copied to accessible locations within each project.

This PRD ensures that all target projects have a complete, functional workflow environment after the epic concludes.

---

### Requirements

#### Functional

1. **Deploy `ror-agent-config` to target projects**
   - Run the sync script for each of the following projects:
     - `projects/nextgen-plaid`
     - `projects/eureka`
     - `projects/SmartProxy`
     - `projects/agent-forge`
   - Command format: `/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh <project-path> ror`
   - Example: `/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/eureka ror`

2. **Copy `RULES.md` to each project**
   - Source: `/Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md`
   - Target location in each project: `knowledge_base/epics/instructions/RULES.md`
   - Create the `knowledge_base/epics/instructions/` directory if it doesn't exist
   - The agent config references this path, so it must exist for agents to function properly

3. **Verify deployment for each project**
   - Confirm `.aider-desk/agents/` directory exists and contains agent configs with project-specific IDs
   - Confirm `.aider-desk/commands/` contains all four human commands plus legacy commands
   - Confirm `.aider-desk/rules/` contains generalized `rails-base-rules.md`
   - Confirm `knowledge_base/epics/instructions/RULES.md` exists and is accessible

#### Non-Functional

- **Idempotency**: The sync script is idempotent — running it multiple times should be safe
- **Project-Specific Agent IDs**: The sync script automatically appends project names to agent IDs (e.g., `ror-rails` becomes `ror-rails-eureka`)
- **No Manual Edits**: Do not manually edit `.aider-desk/` files in target projects — always use the sync script

---

### Why This PRD Exists

The workflow framework is designed to be a **deployed artifact**. The `ror-agent-config` in the knowledge base is the source of truth, but it doesn't become operational until it's synced to individual project directories. Without this deployment step, projects won't have access to:
- The four human workflow commands
- Generalized agent rules and prompts
- Correct commit policies
- Agent profiles with proper project context

Additionally, `RULES.md` is the authoritative reference for all workflow phases, templates, rubrics, and anti-patterns. All agent commands reference it. If it's missing from a project, agents will fail at runtime with "file not found" errors when trying to follow workflow instructions.

This PRD is **blocking for workflow adoption**. No project can use the workflow framework until this deployment is complete.

---

### Acceptance Criteria

#### For each target project (nextgen-plaid, eureka, SmartProxy, agent-forge):

- [ ] `.aider-desk/agents/` directory exists
- [ ] `.aider-desk/agents/` contains at least 4 agent subdirectories (ror-rails-{project}, ror-architect-{project}, ror-qa-{project}, ror-debug-{project})
- [ ] Each agent `config.json` has `projectDir` field pointing to the correct absolute path
- [ ] Each agent `config.json` has `id` and `name` fields with project-specific suffixes
- [ ] `.aider-desk/commands/turn-idea-into-epic.md` exists
- [ ] `.aider-desk/commands/get-feedback-on-epic.md` exists
- [ ] `.aider-desk/commands/finalize-epic.md` exists
- [ ] `.aider-desk/commands/implement-prd.md` exists
- [ ] `.aider-desk/rules/rails-base-rules.md` exists
- [ ] `.aider-desk/rules/rails-base-rules.md` contains no HomeKit references
- [ ] `.aider-desk/rules/rails-base-rules.md` commit policy says "commit plans always; commit code when green"
- [ ] `knowledge_base/epics/instructions/RULES.md` exists in project root
- [ ] `knowledge_base/epics/instructions/RULES.md` is identical to source (byte-for-byte match or checksum match)

#### Overall:

- [ ] All four projects pass the per-project acceptance criteria
- [ ] Deployment log (in this PRD or separate file) records which projects were synced and when
- [ ] No errors reported by sync script for any project

---

### Test Cases

#### Pre-Deployment Validation

- Verify source config exists:
  ```bash
  test -d /Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config
  ```
  Expected: Success

- Verify sync script is executable:
  ```bash
  test -x /Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh
  ```
  Expected: Success

- Verify RULES.md source exists:
  ```bash
  test -f /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md
  ```
  Expected: Success

#### Deployment Execution (per project)

For each project (replace `{project}` with actual project path):

1. **Run sync script**:
   ```bash
   /Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/{project} ror
   ```
   Expected: Exit code 0, message "Done! Configuration synced to projects/{project}."

2. **Verify agent deployment**:
   ```bash
   ls /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/agents/ | wc -l
   ```
   Expected: At least 4 (four agent directories)

3. **Verify command deployment**:
   ```bash
   test -f /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/commands/turn-idea-into-epic.md
   test -f /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/commands/get-feedback-on-epic.md
   test -f /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/commands/finalize-epic.md
   test -f /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/commands/implement-prd.md
   ```
   Expected: All succeed

4. **Verify rules deployment**:
   ```bash
   test -f /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/rules/rails-base-rules.md
   ```
   Expected: Success

5. **Verify project-specific agent IDs**:
   ```bash
   jq -r '.id' /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/agents/ror-rails-{project}/config.json
   ```
   Expected: Output matches `ror-rails-{project}`

6. **Copy RULES.md**:
   ```bash
   mkdir -p /Users/ericsmith66/development/agent-forge/projects/{project}/knowledge_base/epics/instructions
   cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
      /Users/ericsmith66/development/agent-forge/projects/{project}/knowledge_base/epics/instructions/RULES.md
   ```
   Expected: File created successfully

7. **Verify RULES.md deployment**:
   ```bash
   test -f /Users/ericsmith66/development/agent-forge/projects/{project}/knowledge_base/epics/instructions/RULES.md
   ```
   Expected: Success

8. **Verify RULES.md integrity**:
   ```bash
   diff /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
        /Users/ericsmith66/development/agent-forge/projects/{project}/knowledge_base/epics/instructions/RULES.md
   ```
   Expected: No differences (exit code 0)

#### Post-Deployment Smoke Test

For each project:

1. **Verify agent config validity**:
   ```bash
   jq empty /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/agents/*/config.json
   ```
   Expected: No JSON parse errors

2. **Check for HomeKit remnants** (should be zero):
   ```bash
   grep -ri "homekit\|eureka.*homekit\|characteristic_uuid\|LockControlComponent" \
     /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/rules/ || echo "CLEAN"
   ```
   Expected: "CLEAN"

3. **Verify commit policy**:
   ```bash
   grep -i "commit.*plan.*always\|commit.*code.*green" \
     /Users/ericsmith66/development/agent-forge/projects/{project}/.aider-desk/rules/rails-base-rules.md
   ```
   Expected: Matches found

---

### Manual Verification

1. **Pre-Deployment Checklist**:
   - [ ] Source config at `knowledge_base/aider-desk/configs/ror-agent-config/` contains the finalized changes from WF-01 through WF-05
   - [ ] Source config has passed all validation tests (see PRD WF-05)
   - [ ] RULES.md is present at `/Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md`

2. **Deployment Execution**:
   - [ ] Run sync script for `projects/nextgen-plaid`
   - [ ] Run sync script for `projects/eureka`
   - [ ] Run sync script for `projects/SmartProxy`
   - [ ] Run sync script for `projects/agent-forge`
   - [ ] Copy RULES.md to each of the four projects

3. **Post-Deployment Verification** (for each project):
   - [ ] Open `.aider-desk/agents/` and confirm agent directories exist with project suffixes
   - [ ] Open `.aider-desk/commands/turn-idea-into-epic.md` and spot-check that it references RULES.md
   - [ ] Open `.aider-desk/rules/rails-base-rules.md` and confirm title is generic (no "HomeKit")
   - [ ] Search `.aider-desk/rules/rails-base-rules.md` for "commit" and verify policy matches "commit plans always; commit code when green"
   - [ ] Open `knowledge_base/epics/instructions/RULES.md` and confirm it's readable

4. **Final Validation**:
   - [ ] All four projects pass the per-project acceptance criteria
   - [ ] No sync script errors were encountered
   - [ ] Deployment log is complete

---

### Implementation Plan

#### Phase 1: Pre-Deployment Validation (5 min)

**Goal**: Ensure source config and dependencies are ready for deployment.

**Steps**:
1. Verify source config exists and contains finalized changes (WF-01 through WF-05 complete)
2. Verify sync script is executable
3. Verify RULES.md exists at source location
4. Run pre-deployment test cases (source file checks)

**Output**: Confirmation that source artifacts are deployment-ready.

---

#### Phase 2: Deploy to `projects/nextgen-plaid` (10 min)

**Goal**: Execute sync script and copy RULES.md to first target project.

**Steps**:
1. Run sync script:
   ```bash
   /Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/nextgen-plaid ror
   ```
2. Verify sync output shows success
3. Create `knowledge_base/epics/instructions/` directory in `projects/nextgen-plaid` if it doesn't exist
4. Copy RULES.md:
   ```bash
   cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
      /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/knowledge_base/epics/instructions/RULES.md
   ```
5. Run all deployment test cases for `nextgen-plaid`
6. Run post-deployment smoke tests for `nextgen-plaid`

**Output**: `nextgen-plaid` fully configured with workflow framework.

---

#### Phase 3: Deploy to `projects/eureka` (10 min)

**Goal**: Execute sync script and copy RULES.md to second target project.

**Steps**:
1. Run sync script:
   ```bash
   /Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/eureka ror
   ```
2. Verify sync output shows success
3. Create `knowledge_base/epics/instructions/` directory in `projects/eureka` if it doesn't exist
4. Copy RULES.md:
   ```bash
   cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
      /Users/ericsmith66/development/agent-forge/projects/eureka/knowledge_base/epics/instructions/RULES.md
   ```
5. Run all deployment test cases for `eureka`
6. Run post-deployment smoke tests for `eureka`

**Output**: `eureka` fully configured with workflow framework.

---

#### Phase 4: Deploy to `projects/SmartProxy` (10 min)

**Goal**: Execute sync script and copy RULES.md to third target project.

**Steps**:
1. Run sync script:
   ```bash
   /Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/SmartProxy ror
   ```
2. Verify sync output shows success
3. Create `knowledge_base/epics/instructions/` directory in `projects/SmartProxy` if it doesn't exist
4. Copy RULES.md:
   ```bash
   cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
      /Users/ericsmith66/development/agent-forge/projects/SmartProxy/knowledge_base/epics/instructions/RULES.md
   ```
5. Run all deployment test cases for `SmartProxy`
6. Run post-deployment smoke tests for `SmartProxy`

**Output**: `SmartProxy` fully configured with workflow framework.

---

#### Phase 5: Deploy to `projects/agent-forge` (10 min)

**Goal**: Execute sync script and copy RULES.md to fourth target project.

**Steps**:
1. Run sync script:
   ```bash
   /Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/agent-forge ror
   ```
2. Verify sync output shows success
3. Create `knowledge_base/epics/instructions/` directory in `projects/agent-forge` if it doesn't exist
4. Copy RULES.md:
   ```bash
   cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
      /Users/ericsmith66/development/agent-forge/projects/agent-forge/knowledge_base/epics/instructions/RULES.md
   ```
5. Run all deployment test cases for `agent-forge`
6. Run post-deployment smoke tests for `agent-forge`

**Output**: `agent-forge` fully configured with workflow framework.

---

#### Phase 6: Final Validation and Documentation (10 min)

**Goal**: Confirm all deployments are successful and document results.

**Steps**:
1. Run final validation checklist (all projects pass acceptance criteria)
2. Create deployment log with:
   - Timestamp of each deployment
   - Sync script output for each project
   - Test results summary for each project
   - Any issues encountered and resolutions
3. Update `0001-IMPLEMENTATION-STATUS.md` to mark PRD WF-06 as complete
4. Commit deployment log to epic directory

**Output**: Deployment complete with audit trail.

---

### Files Changed

This PRD does not modify source code. It executes deployment operations:

**Source Files** (read-only during deployment):
- `/Users/ericsmith66/development/agent-forge/knowledge_base/aider-desk/configs/ror-agent-config/` (entire directory)
- `/Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md`
- `/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh`

**Target Files** (created/overwritten by deployment):

For each of the four projects (`nextgen-plaid`, `eureka`, `SmartProxy`, `agent-forge`):
- `.aider-desk/agents/` (entire directory — agent configs with project-specific IDs)
- `.aider-desk/commands/` (entire directory — all command files)
- `.aider-desk/rules/` (entire directory — generalized rules)
- `.aider-desk/prompts/` (entire directory — delegation rules and other prompts)
- `.aider-desk/skills/` (if present in source config)
- `knowledge_base/epics/instructions/RULES.md` (copied from source)

**Documentation Files** (created by this PRD):
- `knowledge_base/epics/epic-workflow/deployment-log-{timestamp}.md` (deployment audit trail)

---

### Dependencies

**Upstream (Blocking)**:
- WF-01: `rails-base-rules.md` must be generalized and commit policy fixed
- WF-02: Three human command files must exist
- WF-03: `implement-prd.md` and legacy commands must be updated
- WF-04: Agent system prompts must be updated
- WF-05: Validation checklist must be 100% complete (source config is deployment-ready)

**Downstream (Blocked by this PRD)**:
- None (this is the final PRD in the epic)
- However, any **workflow adoption** or **epic execution** in target projects is blocked until this deployment is complete

---

### Risk Assessment

**Risk 1**: Sync script fails for one or more projects
- **Likelihood**: Low (script is idempotent and well-tested)
- **Impact**: Medium (blocks workflow adoption for affected projects)
- **Mitigation**: Test sync script on a scratch directory first; inspect sync script output for errors

**Risk 2**: RULES.md is out of date or incomplete
- **Likelihood**: Low (assuming WF-01 through WF-05 are complete)
- **Impact**: High (agents will fail at runtime with missing references)
- **Mitigation**: Verify RULES.md content before deployment; cross-check with command file references

**Risk 3**: Project-specific agent IDs conflict with existing agents
- **Likelihood**: Low (sync script uses unique suffixes)
- **Impact**: Low (can be resolved by deleting `.aider-desk/agents/` and re-running sync)
- **Mitigation**: Review existing `.aider-desk/agents/` in target projects before deployment

**Risk 4**: Manual edits to `.aider-desk/` in target projects get overwritten
- **Likelihood**: Medium (team members may have made project-specific customizations)
- **Impact**: Medium (custom agents or commands are lost)
- **Mitigation**: Document that `.aider-desk/` is managed by sync script; advise team to back up custom files before deployment

---

### Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-23 | Deploy to four specific projects | These are the active Agent-Forge projects that will use the workflow framework |
| 2026-02-23 | Copy RULES.md to each project | Agent commands reference this path; must be present for agents to function |
| 2026-02-23 | Use sync script for deployment | Script is idempotent and handles agent ID suffixing automatically |
| 2026-02-23 | Create deployment log | Provides audit trail for compliance and troubleshooting |

---

### Notes

- The sync script (`sync-aider-config.sh`) is located at `/Users/ericsmith66/development/agent-forge/scripts/` and is part of the Agent-Forge infrastructure (not part of this epic).
- This PRD assumes the sync script is working correctly. If the script needs modifications, that is out of scope for this epic.
- After deployment, each project's `.aider-desk/` directory becomes the **runtime configuration**. The source config in `knowledge_base/aider-desk/configs/ror-agent-config/` remains the **source of truth** for future updates.
- To redeploy after source config changes, simply re-run the sync script for affected projects.
- Projects may have **project-local agents** (like `translation-manager`, `test-writer`, etc.) that are not part of the `ror-agent-config` bundle. The sync script does not touch these — they remain in `.aider-desk/agents/` alongside the synced agents.

---

### Success Metrics

- **Deployment Success Rate**: 100% (all four projects deployed without errors)
- **Config Integrity**: 100% (all acceptance criteria pass for all projects)
- **RULES.md Availability**: 100% (RULES.md exists and is identical in all projects)
- **Agent Functionality**: Agents can be loaded and started in each project (manual smoke test)
- **Command Availability**: All four human commands are accessible via AiderDesk UI in each project

---

### Appendix: Project Paths

For reference, the full paths to target projects:

1. **nextgen-plaid**: `/Users/ericsmith66/development/agent-forge/projects/nextgen-plaid`
2. **eureka**: `/Users/ericsmith66/development/agent-forge/projects/eureka`
3. **SmartProxy**: `/Users/ericsmith66/development/agent-forge/projects/SmartProxy`
4. **agent-forge**: `/Users/ericsmith66/development/agent-forge/projects/agent-forge`

Sync script invocations:
```bash
/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/nextgen-plaid ror
/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/eureka ror
/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/SmartProxy ror
/Users/ericsmith66/development/agent-forge/scripts/sync-aider-config.sh projects/agent-forge ror
```

RULES.md copy commands:
```bash
# nextgen-plaid
mkdir -p /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/knowledge_base/epics/instructions
cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
   /Users/ericsmith66/development/agent-forge/projects/nextgen-plaid/knowledge_base/epics/instructions/RULES.md

# eureka
mkdir -p /Users/ericsmith66/development/agent-forge/projects/eureka/knowledge_base/epics/instructions
cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
   /Users/ericsmith66/development/agent-forge/projects/eureka/knowledge_base/epics/instructions/RULES.md

# SmartProxy
mkdir -p /Users/ericsmith66/development/agent-forge/projects/SmartProxy/knowledge_base/epics/instructions
cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
   /Users/ericsmith66/development/agent-forge/projects/SmartProxy/knowledge_base/epics/instructions/RULES.md

# agent-forge
mkdir -p /Users/ericsmith66/development/agent-forge/projects/agent-forge/knowledge_base/epics/instructions
cp /Users/ericsmith66/development/agent-forge/knowledge_base/instructions/RULES.md \
   /Users/ericsmith66/development/agent-forge/projects/agent-forge/knowledge_base/epics/instructions/RULES.md
```
