# PRD 2-09: Retry Logic with Context Accumulation

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-12: Configurable gate thresholds (default 90)
- D-30: Two distinct retry limits: `WorkflowExecution.attempt` (max 3, CODE→QA→RETRY cycles) + `Task.retry_count` (max configurable per-task)
- D-31: Three-layer testing: (1) tool guard unit tests (deterministic), (2) prompt contract tests (live LLM, on prompt changes), (3) integration tests (VCR, assert state changes not reasoning)
- D-32: `retry_with_context` uses Model A (tool-decides task selection). No `task_ids` parameter. Tool reads score_report Artifact for file path matching. Falls back to retry-all.
- D-42: NLP-based retry task selection kept — best-effort file path matching with retry-all fallback. Flagged for structured output mandate in Epic 3+.
- D-43: `retry_with_context` completes reset + dependency re-evaluation synchronously before enqueuing ConductorJob. No async gap.
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

When a QA gate returns a score below threshold, the system needs to retry intelligently — not just re-run the same tasks blindly, but accumulate feedback from each failed attempt so subsequent attempts have more context. PRD 2-04 provided basic task reset capability. PRD 2-09 adds the full retry orchestration: the Conductor's `retry_with_context` tool selects which tasks to retry, accumulates gate feedback across attempts, builds enriched retry prompts, and tracks two distinct retry limits (D-30).

The retry flow is: QA scores < 90 → Conductor calls `retry_with_context` → tool accumulates feedback, resets targeted tasks, increments execution attempt → Conductor calls `dispatch_coding` → tasks re-run with enriched prompts → QA re-scores. This loop runs up to 3 times (execution-level limit).

---

### Requirements

#### Functional

- FR-1: `retry_with_context` orchestration tool full implementation:
  - Extract feedback from QA gate result (issues list, score breakdown)
  - Select tasks to retry: tasks cited in QA feedback (file path matching), or all failed tasks, or all tasks if unclear
  - Call `TaskResetService` on selected tasks (from 2-04)
  - Create `retry_context` Artifact with accumulated feedback
  - Create `review_feedback` Artifact with gate feedback linked to parent score report
  - Increment `WorkflowExecution.attempt`
  - Transition phase to `retrying`
  - Known limitation: file path matching in QA output is best-effort. If QA feedback doesn't contain parseable paths, all non-completed tasks are retried. Future epics may mandate structured QA output (see D-42).
  - `retry_with_context` completes reset + dependency re-evaluation synchronously BEFORE enqueuing ConductorJob. Steps: (1) Reset targeted tasks to `pending` via TaskResetService, (2) Run dependency re-evaluation synchronously, (3) Create `retry_context` Artifact, (4) Create ConductorDecision, (5) THEN enqueue `ConductorJob(trigger: :retry_ready)`. No async gap (D-43).
- FR-2: Context accumulation across attempts. Each retry prompt includes ALL prior feedback:
  - Attempt 1 prompt: original task prompt + file contents
  - Attempt 2 prompt: original + "Attempt 1 feedback: score 87, issues: [...]"
  - Attempt 3 prompt: original + "Attempt 1 feedback: ..." + "Attempt 2 feedback: ..."
- FR-3: `retry_prompt.md.liquid` template renders accumulated context with clear structure (each attempt's feedback in a labeled section)
- FR-4: Execution-level retry limit (D-30): `WorkflowExecution.attempt` max 3 (configurable via `--max-retries`). After 3 QA cycles: enter retrospective, then escalate.
- FR-5: Task-level retry limit (D-30): `Task.retry_count` max configurable (`WorkflowExecution.task_retry_limit`, default 3). Task exceeding limit: marked `failed` permanently.
- FR-6: When a task exceeds its retry limit, Conductor receives status "Task #N permanently failed (exceeded retry limit)". Conductor decides: proceed without task (if downstream tasks unblocked) or escalate execution.
- FR-7: `RetryContextBuilder` service: builds the accumulated context hash for a given task, reading all prior `retry_context` and `review_feedback` Artifacts for the execution
- FR-8: Retry context capped at 2000 tokens per attempt (approximately 2000 characters). Prior feedback summarized if exceeding cap.
- FR-9: `dispatch_coding` tool (in retrying phase) uses enriched prompts from `RetryContextBuilder`

#### Non-Functional

- NF-1: Retry context building must complete in < 500ms (DB queries + string manipulation)
- NF-2: Accumulated context must not exceed model context window — cap at 6000 tokens total across all retry feedback
- NF-3: Task selection for retry should be deterministic given the same QA feedback (reproducible)

#### Rails / Implementation Notes

- **Service**: `app/services/legion/retry_context_builder.rb`
- **Tool update**: `app/tools/legion/orchestration/retry_with_context.rb` — full implementation
- **Template**: Update `app/prompts/retry_prompt.md.liquid` with accumulation sections
- **Model**: Use `WorkflowExecution.attempt` and `Task.retry_count` for limit checks

---

### Error Scenarios & Fallbacks

- **QA feedback doesn't cite specific files** → Retry all non-completed tasks (conservative approach). Log: "QA feedback doesn't reference specific files — retrying all incomplete tasks."
- **Retry context exceeds cap** → Summarize oldest feedback (keep issues list, drop verbose explanations). Most recent feedback preserved in full.
- **All tasks in execution permanently failed** → Conductor must escalate (no tasks left to retry).
- **Task retry limit exceeded for one task, others still retryable** → Mark failed task, continue with remaining tasks. Conductor evaluates whether the execution can still pass QA without the failed task's output.
- **Execution attempt limit reached** → `retry_with_context` tool refuses (precondition: `attempt < max_retries`). Conductor must call `run_retrospective` instead.

---

### Architectural Context

This PRD connects the QualityGate evaluation (2-08) with the task re-run capability (2-04) through the Conductor (2-06). The retry logic is the inner loop of the PRD implementation cycle: CODE → QA → RETRY → CODE → QA → ...

The two-tier retry system (D-30) prevents a single persistently-failing task from burning all execution-level retries. Task-level limits allow the system to give up on one task while continuing the execution if possible.

Context accumulation is the key differentiator from simple task re-run. Each attempt gives the agent more specific feedback about what to fix, dramatically increasing the probability of success on subsequent attempts.

---

### Acceptance Criteria

- [ ] AC-1: Given QA score 87 (threshold 90) and attempt 1/3, `retry_with_context` resets targeted tasks, creates retry_context Artifact, increments attempt to 2
- [ ] AC-2: Given QA feedback citing files `app/models/user.rb` and `test/models/user_test.rb`, only tasks referencing those files are reset
- [ ] AC-3: Given QA feedback with no file references, all non-completed tasks are reset
- [ ] AC-4: Attempt 2 retry prompt contains: original task prompt + "Attempt 1 feedback: score 87, issues: [...]"
- [ ] AC-5: Attempt 3 retry prompt contains: original + Attempt 1 feedback + Attempt 2 feedback
- [ ] AC-6: Given attempt 3 and QA score < 90, `retry_with_context` tool refuses (precondition: attempt < max_retries)
- [ ] AC-7: Given task #3 with `retry_count: 3` and `task_retry_limit: 3`, task is marked `failed` permanently on next reset attempt
- [ ] AC-8: Retry context per attempt capped at ~2000 characters. Older feedback summarized if needed.
- [ ] AC-9: `retry_context` Artifact created for each retry with accumulated feedback content
- [ ] AC-10: `review_feedback` Artifact created linking QA feedback to parent score_report
- [ ] AC-11: `RetryContextBuilder.call(task:, execution:)` returns accumulated context hash
- [ ] AC-12: Two distinct counters tracked independently: `WorkflowExecution.attempt` (QA cycles) and `Task.retry_count` (per-task resets)

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/retry_context_builder_test.rb`: Build context for attempt 1 (no prior feedback), attempt 2 (one prior feedback), attempt 3 (two prior feedbacks). Cap enforcement (truncation). File-based task selection.
- `test/tools/legion/orchestration/retry_with_context_test.rb`: Precondition validation (attempt < max, score < threshold). Task selection logic. Artifact creation. Attempt increment. Task retry limit enforcement.

#### Integration (Minitest)

- `test/integration/retry_flow_test.rb`: QA returns score 87 → retry_with_context → tasks reset with context → re-dispatch → QA returns 94 → pass. Verify two Artifacts (retry_context for each attempt). Verify accumulated prompts. (VCR-recorded)
- `test/integration/retry_limit_test.rb`: Three QA cycles, all < 90 → verify execution enters retrospective, not another retry. Verify attempt counter = 3.

---

### Manual Verification

1. Run `bin/legion implement <prd-path> --team ROR` on a PRD expected to need at least one retry
2. Observe: first QA score < 90 → retry with feedback → second attempt
3. Check `WorkflowExecution.last.attempt` — should be 2 after first retry
4. Check `Artifact.where(artifact_type: :retry_context)` — should have 1 record
5. Check retry task prompts contain prior QA feedback
6. If score passes on retry: execution continues to retrospective → completed

**Expected:** Retry happens automatically with accumulated context. Score improves with additional context.

---

### Dependencies

- **Blocked By:** 2-06 (Conductor tools), 2-08 (QualityGate evaluation produces the scores that trigger retry)
- **Blocks:** 2-10 (Implement loop includes retry)

---

