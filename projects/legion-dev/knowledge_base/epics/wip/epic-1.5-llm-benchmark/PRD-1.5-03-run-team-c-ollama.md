# PRD-1.5-03 — Run 4C-Core with Team C (All-Ollama)

**PRD ID:** PRD-1.5-03
**Epic:** Epic 1.5 — LLM Benchmark
**Status:** Draft
**Created:** 2026-03-07
**Depends On:** PRD-1.5-01, PRD-1.5-02
**Blocks:** PRD-1.5-04, PRD-1.5-05

---

## User Story

As a benchmark operator, I want to run all 9 Epic 4C-Core PRDs through Legion's decompose → execute-plan pipeline using the cheapest all-Ollama team, logging every metric, so that I know exactly where local models succeed and fail on real framework construction.

---

## Acceptance Criteria

1. All 9 PRDs are attempted in dependency order (0010 → 0005 → 0020 → 0030 → 0095 → 0091 → 0090 → 0092a → 0092b)
2. Each PRD goes through: `bin/legion decompose` → review decomposition → `bin/legion execute-plan`
3. After each PRD's plan executes, `cd gems/agent_desk && bundle exec rake test` is run and results logged
4. If tests fail after execute-plan, the debug agent gets ONE pass to fix issues, then final state is logged
5. A run log exists at `knowledge_base/epic-4c/team-c-run-log.md` with per-PRD rows:

   | PRD | Decomp Tasks | Avg Score | Flagged >6 | Tests | Assertions | Failures | Iterations | Duration | Debug Cycles | Status |
   |-----|-------------|-----------|------------|-------|------------|----------|------------|----------|-------------|--------|

6. Decomposition output is saved for each PRD (task list, scores, parallel groups)
7. Decision gates are respected:
   - After 0010+0005: if both fail → abort, log "model fundamentally unsuitable"
   - After 0020+0030+0095: if failures → note which PRDs failed, continue to hard PRDs for data
   - After 0091: if fail → note as expected failure point
   - After 0090: if fail → note as expected wall
8. Run continues even if individual PRDs fail (we want data on ALL PRDs, not just until first failure)
9. Full `rake test` run after final PRD with cumulative results logged

---

## Execution Protocol (Per PRD)

### Step 1: Decompose

```bash
bin/legion decompose --team ROR --prd knowledge_base/epic-4c/4C-Core/PRD-4c-XXXX-*.md
```

**Log:**
- Number of tasks generated
- Task score distribution (min, max, avg)
- Count of tasks flagged > 6
- Parallel group count
- Any parse errors

**Review before executing:**
- Are tasks truly atomic? (score ≤ 6 for each)
- Is test-first ordering correct? (test tasks before implementation tasks)
- Do dependencies make sense? (no obvious missing edges)
- If decomposition is clearly broken (parse failure, all tasks score > 6), log and skip to next PRD

### Step 2: Execute Plan

```bash
bin/legion execute-plan --workflow-run <id>
```

**Log per task:**
- Task position, type, agent
- Status (completed/failed)
- Iterations consumed
- Duration

**Log per PRD (after all tasks):**
- `bundle exec rake test` output: runs, assertions, failures, errors, skips
- RuboCop output: offense count
- Whether any earlier PRD's tests regressed

### Step 3: Debug Pass (If Needed)

If tests fail after execute-plan:

```bash
bin/legion execute --team ROR --agent debug --prompt "Fix the following test failures in gems/agent_desk: <paste failures>"
```

**One pass only.** Log:
- What the debug agent changed
- Whether tests pass after debug
- Iterations consumed by debug

### Step 4: Record Final State

Regardless of pass/fail, log:
- Final test count, assertion count, failure count
- Cumulative test count (all PRDs so far)
- Git commit the current state (even if failing) for later analysis

---

## Expected Outcomes (Predictions)

| PRD | Prediction | Confidence | Reasoning |
|-----|-----------|------------|-----------|
| 0010 (Types/Scaffold) | ✅ Pass | High | Simple gem scaffold, constants, Data.define structs |
| 0005 (Test Harness) | ✅ Pass | High | Minitest setup, mock objects, contract stubs |
| 0020 (Tool Framework) | ✅ Pass | Medium | BaseTool DSL is standard Ruby metaprogramming |
| 0030 (Hooks) | ✅ Pass | Medium | Thread-safe callback registration — straightforward |
| 0095 (Message Bus) | ⚠️ Maybe | Medium | Interface module + adapter pattern + wildcard matching |
| 0091 (Model Manager) | ❌ Likely Fail | High | SSE streaming, Faraday middleware, error hierarchy, response normalization |
| 0090 (Runner) | ❌ Likely Fail | High | Integrates 5 prior components, complex control flow |
| 0092a (Token Tracking) | ⚠️ Maybe | Medium | Stateful but contained — depends on 0090 being solid |
| 0092b (Compaction) | ❌ Likely Fail | Medium | Tiered strategies, handoff, state snapshots — complex |

**Expected Team C score: 4-5 out of 9 PRDs passing.**

---

## Non-Functional Requirements

- Do NOT modify PRD content during the run — models work with the spec as-is
- Do NOT provide hints or manual fixes between PRDs — the pipeline must work autonomously
- Operator may review decomposition output before executing (this is normal Legion workflow)
- All Ollama inference runs locally — no cloud tokens consumed (except Architect via DeepSeek)
- Log SmartProxy/Ollama token counts for Architect calls (the only cloud cost)

---

## Error Scenarios

| Scenario | Action |
|----------|--------|
| Decompose produces unparseable output | Log parse error, skip PRD, continue to next |
| Execute-plan hangs (model stuck in loop) | Kill after 30 minutes per task. Log as "timeout". Continue. |
| Ollama OOM on large context | Log error. Try reducing context by clearing earlier conversation. |
| Earlier PRD's tests break after later PRD | Log regression. This is valuable data about architectural coherence. |
| All tasks in a plan fail | Log all failures. Run debug once on the worst failure. Move on. |

---

## Deliverables

1. `knowledge_base/epic-4c/team-c-run-log.md` — complete per-PRD metrics table
2. `knowledge_base/epic-4c/team-c-decompositions/` — saved decomposition output for each PRD
3. Git history in `legion-test` — one commit per PRD attempt (pass or fail)
4. Notes on decomposition quality: which PRDs had good decompositions, which had poor ones
5. Identification of the **failure boundary** — the exact PRD where cheap models stop working
