# PRD-1.5-05 — Scoring & Comparison Report

**PRD ID:** PRD-1.5-05
**Epic:** Epic 1.5 — LLM Benchmark
**Status:** Draft
**Created:** 2026-03-07
**Depends On:** PRD-1.5-03, PRD-1.5-04
**Blocks:** Phase 2 decision (4C-Features)

---

## User Story

As a benchmark operator, I want a comprehensive scoring report that aggregates all run data, compares against the agent-forge answer key, and produces actionable model tier recommendations, so that I can make informed decisions about which LLMs to use for future Legion work and whether to proceed to Phase 2.

---

## Acceptance Criteria

1. A final report exists at `knowledge_base/epic-4c/benchmark-report.md`
2. Report contains all sections defined below
3. Report includes specific, data-backed recommendations — not opinions
4. Phase 2 go/no-go decision is stated with supporting evidence
5. Report is committed to Legion (not just legion-test)

---

## Report Sections

### Section 1: Executive Summary

One paragraph. Which team configuration(s) succeeded, how far cheap models got, what the cost was, and the headline finding about decomposition quality.

### Section 2: Per-Team Scorecard

| Metric | Team C (Ollama) | Team B (Budget) | Team A (Frontier) |
|--------|----------------|-----------------|-------------------|
| PRDs completed (of 9) | | | |
| Total tests | | | |
| Total assertions | | | |
| Total failures | | | |
| RuboCop offenses | | | |
| Total iterations | | | |
| Total wall-clock time | | | |
| Cloud API cost | $0 + architect | $ | $ |
| Debug cycles needed | | | |
| Escalations from prev tier | N/A | | |

### Section 3: Per-PRD Heat Map

| PRD | Difficulty | Team C | Team B | Team A | Decomp Quality |
|-----|-----------|--------|--------|--------|----------------|
| 0010 | Easy | ✅/❌ | — | — | Good/Fair/Poor |
| 0005 | Easy | | | | |
| 0020 | Medium | | | | |
| 0030 | Medium | | | | |
| 0095 | Medium | | | | |
| 0091 | Hard | | | | |
| 0090 | Very Hard | | | | |
| 0092a | Hard | | | | |
| 0092b | Hard | | | | |

### Section 4: Decomposition Quality Analysis

For each PRD decomposition:
- Task count, average score, max score
- Were all tasks ≤ 6? (atomic)
- Test-first ordering correct?
- Dependencies complete and acyclic?
- **Correlation:** Did good decomposition predict task success? Did poor decomposition predict failure?
- **The hypothesis verdict:** Is the decomposer the deciding factor? Provide correlation coefficient or at minimum a clear pattern statement.

### Section 5: Answer Key Comparison

Compare the best successful run against agent-forge's existing implementation:

| Metric | agent-forge (Answer Key) | Best legion-test Run |
|--------|------------------------|---------------------|
| Test runs | 752 | |
| Assertions | 2022 | |
| Failures | 0 | |
| Source files | (count) | |
| Test files | (count) | |

Architectural comparison (qualitative):
- Do module boundaries align? (agent_desk/tools, agent_desk/hooks, etc.)
- Are class names consistent? (BaseTool, ToolSet, HookManager, etc.)
- Are public API signatures similar?
- Were any acceptance criteria missed?
- Were any extra features added (hallucinated requirements)?

### Section 6: Model Tier Recommendations

Based on the data, produce a decision matrix:

| PRD Difficulty | Minimum Viable Model | Cost Tier | Confidence |
|---------------|---------------------|-----------|------------|
| Easy (scaffold, types) | ? | $ | High/Medium/Low |
| Medium (framework, patterns) | ? | $ | |
| Hard (streaming, integration) | ? | $ | |
| Very Hard (multi-component) | ? | $ | |

### Section 7: Cost Analysis

| Configuration | Cloud Cost | Local Cost | Total | Cost per Passing PRD |
|--------------|-----------|-----------|-------|---------------------|
| Team C | $X (architect only) | $0 | | |
| Team B | $X | $0 | | |
| Team A | $X | $0 | | |
| Cheapest successful | | | | |

### Section 8: Findings & Surprises

Bullet list of unexpected results:
- Models that performed better/worse than predicted
- PRDs that were easier/harder than predicted
- Decomposition patterns that consistently worked or failed
- Failure modes we didn't anticipate

### Section 9: Phase 2 Decision

**Go / No-Go / Conditional** for running 4C-Features (7 PRDs) with rationale:

- If cheapest successful config handles all 9 Core PRDs → **Go** with that config
- If only frontier handles the hard PRDs → **Conditional** — run Features with budget for easy PRDs, frontier for hard ones
- If no config completes all 9 → **No-Go** — decomposition or spec needs improvement first

### Section 10: Recommendations for Legion

Based on findings:
1. Default model configuration for future epics
2. Whether to invest in better decomposition prompts
3. Whether Qwen3 models are viable for QA/coding roles in production
4. SmartProxy routing recommendations (which models for which task types)
5. Whether the team-makeup.md model rankings need updating

---

## Non-Functional Requirements

- Report must be data-driven — every recommendation backed by specific numbers
- No hand-waving ("model X seemed better") — use test counts, pass rates, iteration counts
- Report must be useful to someone who didn't run the benchmark (stand-alone document)
- Include raw data appendix or link to run logs

---

## Deliverables

1. `knowledge_base/epic-4c/benchmark-report.md` — the full report (in Legion repo)
2. `knowledge_base/epic-4c/raw-data/` — directory with all run logs, decomposition outputs, test results
3. Updated `knowledge_base/ignore/team-makeup.md` — if findings change model recommendations
4. Phase 2 decision documented in report and in epic status
