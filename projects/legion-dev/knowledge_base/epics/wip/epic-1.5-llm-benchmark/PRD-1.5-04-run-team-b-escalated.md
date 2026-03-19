# PRD-1.5-04 — Run 4C-Core with Team B (Budget Escalation)

**PRD ID:** PRD-1.5-04
**Epic:** Epic 1.5 — LLM Benchmark
**Status:** Draft
**Created:** 2026-03-07
**Depends On:** PRD-1.5-03
**Blocks:** PRD-1.5-05

---

## User Story

As a benchmark operator, I want to re-run the PRDs that Team C failed on using budget cloud models, so that I can determine the minimum cloud spend needed to complete the full 4C-Core spec and isolate whether failures were model quality or decomposition quality.

---

## Acceptance Criteria

1. Team B agent configs are applied to `legion-test/.aider-desk/agents/`
2. **Only PRDs that Team C failed on** are re-run (not the ones that already passed)
3. For PRDs that Team C passed: the existing code and tests remain in place (Team B builds on Team C's successful work)
4. Each failed PRD goes through the full protocol: decompose → execute-plan → test → optional debug
5. A run log exists at `knowledge_base/epic-4c/team-b-run-log.md` with the same metrics table as Team C
6. If Team B also fails on a PRD, that PRD is attempted with Team A (frontier) as a final escalation
7. After all re-runs, full `rake test` runs with cumulative results (Team C successes + Team B fixes)
8. Side-by-side comparison logged: for each re-run PRD, what changed between Team C and Team B decomposition/execution

---

## Execution Protocol

### Pre-Run: Assess Team C Results

1. Read `team-c-run-log.md`
2. Identify PRDs with status: `failed`, `partial`, or `timeout`
3. Identify PRDs where tests pass but with regressions from earlier PRDs
4. Create ordered list of PRDs to re-run

### Selective Escalation Strategy

Not all roles need escalation. Analyze Team C failures to determine which role failed:

| Failure Pattern | Likely Cause | Escalation |
|----------------|-------------|------------|
| Decomposition produced bad tasks (score > 6, wrong deps) | Architect quality | Switch Architect to Grok-latest (shouldn't happen — DeepSeek is already good) |
| Code compiles but tests fail (logic errors) | Coder quality | Swap Coder to `deepseek-chat` |
| Tests are shallow (pass but miss acceptance criteria) | QA quality | Swap QA to `claude-sonnet-4-6` |
| Debug agent can't fix failures | Debug quality | Swap Debug to `deepseek-chat` |
| Code doesn't compile at all | Coder fundamentally unsuitable | Jump to Team A coder |

**Key insight:** If Team C's decomposition was GOOD but execution was bad → the coder model is the bottleneck. If decomposition was BAD → even Team B won't help until we fix the Architect.

### Per Failed-PRD Protocol

1. **Reset gem state** to the last known-good commit (after the previous successful PRD)
2. **Re-decompose** with Team B's Architect (same DeepSeek, but log if decomposition differs)
3. **Execute plan** with Team B's Coder/QA/Debug
4. **Run full test suite** (including all earlier PRDs' tests)
5. **Log all metrics** in same format as Team C
6. **Compare decompositions** — did Team B get the same task breakdown? (It should — same Architect model)

### Escalation to Team A (If Needed)

If Team B fails on a PRD:

1. Apply Team A config for that role only
2. Re-run the single failed PRD
3. If Team A also fails → the problem is decomposition or PRD spec, not model quality
4. Log this finding explicitly — it's the most valuable data point

---

## Expected Outcomes

| PRD | Team C Result | Team B Prediction | Reasoning |
|-----|-------------|-------------------|-----------|
| 0091 (Model Manager) | ❌ Failed | ⚠️ Maybe | DeepSeek-Chat is good at HTTP/streaming patterns |
| 0090 (Runner) | ❌ Failed | ✅ Likely Pass | DeepSeek-Chat handles complex integration if decomposition is good |
| 0092a (Token Tracking) | ⚠️ Depends | ✅ Likely Pass | Contained scope, DeepSeek handles stateful logic |
| 0092b (Compaction) | ❌ Failed | ⚠️ Maybe | Complex strategy patterns — may need frontier |

**Expected Team B addition: +3-4 PRDs passing, total 7-9 out of 9.**

---

## Decomposition Quality Analysis

This is the critical data this PRD produces. For each re-run PRD, document:

1. **Did Team C's decomposition match Team B's?** (Same Architect, should be identical)
2. **Was the decomposition actually good?** Score each decomposition:
   - All tasks ≤ 6? ✅ / ❌
   - Test-first ordering correct? ✅ / ❌
   - Dependencies complete? ✅ / ❌
   - Tasks actually atomic? (subjective assessment)
3. **If decomposition was good but Team C coder failed → model quality is the issue**
4. **If decomposition was bad → decomposer is the bottleneck regardless of coder**

This directly tests the epic's central hypothesis: **the decomposer is the deciding factor.**

---

## Non-Functional Requirements

- Do NOT restart from scratch — build on Team C's successful PRDs
- Team B configs swap ONLY the failed roles, not all roles
- If a PRD passed with Team C, do NOT re-run it with Team B (wastes resources, adds noise)
- Log cloud API costs separately (DeepSeek API tokens, Anthropic tokens if escalated to Claude)

---

## Error Scenarios

| Scenario | Action |
|----------|--------|
| Team B succeeds on PRD that Team C failed on | Log the delta: what was different? Iterations, approach, code structure. |
| Team B fails on same PRD as Team C | Escalate to Team A for that PRD. Log as "budget insufficient." |
| Team A also fails | Log as "decomposition quality issue" or "PRD spec too complex for agentic coding." This is the most interesting finding. |
| Team C code interferes with Team B re-run | Reset to last good commit before re-running. |
| DeepSeek API goes down during run | Fallback Architect to Grok-latest. Log the switch. |

---

## Deliverables

1. `knowledge_base/epic-4c/team-b-run-log.md` — per-PRD metrics for re-run PRDs only
2. `knowledge_base/epic-4c/team-a-run-log.md` — per-PRD metrics if any PRDs escalated to frontier (may be empty)
3. `knowledge_base/epic-4c/decomposition-analysis.md` — per-PRD decomposition quality assessment
4. `knowledge_base/epic-4c/escalation-log.md` — which roles were swapped, when, and why
5. Updated git history in `legion-test` — commits tagged by team (e.g., `[team-b] PRD-0091 re-run`)
