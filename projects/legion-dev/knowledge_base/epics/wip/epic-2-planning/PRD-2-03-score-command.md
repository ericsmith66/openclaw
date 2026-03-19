# PRD 2-03: `bin/legion score` Command

**Epic:** [Epic 2 — WorkflowEngine & Quality Gates](0000-epic.md)

## Key Decisions

- D-8: Score parsing via QA agent dispatch
- D-12: Configurable gate thresholds (default 90)
- D-21: ConductorDecision includes `duration_ms`, `tokens_used`, `estimated_cost` for performance and cost observability
- D-22: `architect_review` is a distinct `artifact_type` enum value, separate from `score_report`
**Log Requirements**
- Create/update task log under `knowledge_base/task-logs/`

---

### Overview

Legion has no standalone scoring capability. To evaluate the quality of a workflow run's output, a human must manually dispatch a QA agent with the right context. There's no parsed numeric score, no structured feedback storage, and no exit code for CI integration.

PRD 2-03 adds `bin/legion score` — a CLI command that dispatches a QA agent to score a workflow run's output, parses the numeric score from the LLM response, creates an `Artifact` (type: `score_report`) with the score and feedback, and returns exit code 0 (pass) or 3 (below threshold). This is the foundation that QualityGate (2-07) builds on.

---

### Requirements

#### Functional

- FR-1: New CLI command `bin/legion score --workflow-run <id> --team <name>`
- FR-2: Optional flags: `--agent <role>` (default: `qa`), `--threshold <N>` (default: 90), `--prd <path>` (PRD for scoring context)
- FR-3: Load the specified WorkflowRun and its tasks/artifacts
- FR-4: Build a scoring prompt containing: PRD content (if `--prd` provided), acceptance criteria, task results, code diffs (from task outputs)
- FR-5: Dispatch the QA agent via `DispatchService` with the scoring prompt
- FR-6: Parse the numeric score from the QA agent's output using a multi-pattern parser (see Score Parsing Strategy in epic overview)
- FR-7: Create an `Artifact` record: `artifact_type: :score_report`, `score: <parsed_score>`, `content: <full_qa_output>`, associated with the WorkflowRun and (optionally) WorkflowExecution
- FR-8: Print formatted score output to console (score, threshold, verdict, issues, artifact ID)
- FR-9: Exit code 0 if score ≥ threshold, exit code 3 if below threshold
- FR-10: `ScoreParser` service extracts numeric score from LLM output text using priority-ordered regex patterns
- FR-11: If no score can be parsed, return score 0 with feedback "Score parsing failed — manual review required"

#### Non-Functional

- NF-1: Score parsing must handle at least 3 common LLM output formats (header, inline, slash notation)
- NF-2: Command must work standalone (no WorkflowExecution required — can score any WorkflowRun)
- NF-3: Exit code 3 (not 1) for below-threshold to distinguish from command errors (exit 1)

#### Rails / Implementation Notes

- **CLI**: New Thor command in `bin/legion` — `score` subcommand
- **Service**: `app/services/legion/score_service.rb` — orchestrates prompt building, dispatch, parsing, artifact creation
- **Parser**: `app/services/legion/score_parser.rb` — extracts numeric score from text
- **Prompt**: Scoring prompt built inline for now (PromptBuilder integration in 2-05/2-07)

---

### Error Scenarios & Fallbacks

- **WorkflowRun not found** → Exit code 1, message "WorkflowRun #<id> not found"
- **Team not found** → Exit code 1, message "Team '<name>' not found"
- **QA agent not in team** → Exit code 1, message "No agent with role 'qa' in team '<name>'"
- **QA agent dispatch fails** → Exit code 2, message with error details. No Artifact created.
- **Score parsing fails** → Score set to 0, Artifact created with `score: 0`, feedback includes "Score parsing failed". Exit code 3 (below threshold).
- **No tasks in workflow run** → Warning message, proceed with scoring (QA agent evaluates empty output)

---

### Architectural Context

This command reuses the existing `DispatchService` pipeline — the QA agent is assembled and dispatched like any other agent. The scoring prompt is built from the WorkflowRun's context (tasks, their results, referenced PRD). The `ScoreParser` is a standalone service with no LLM dependency — it's pure regex pattern matching on text.

The `score_report` Artifact type is available from PRD 2-02. This PRD creates real Artifacts from day one — no provisional storage (D-28).

The score command is designed to work independently of the WorkflowEngine. It can score any WorkflowRun, whether created by `execute-plan`, `implement`, or manual dispatch. The QualityGate (2-07) will wrap this logic in a reusable gate interface.

---

### Acceptance Criteria

- [ ] AC-1: `bin/legion score --workflow-run <id> --team ROR` dispatches QA agent and prints score to console
- [ ] AC-2: Given QA output "## Score\n87/100\n\n## Issues\n1. Missing test", parser extracts score 87
- [ ] AC-3: Given QA output "SCORE: 92", parser extracts score 92
- [ ] AC-4: Given QA output "The implementation scores 85 / 100 overall", parser extracts score 85
- [ ] AC-5: Given unparseable output (no numeric pattern), parser returns score 0 with "Score parsing failed" message
- [ ] AC-6: Score report stored as Artifact with `artifact_type: :score_report`, `score: 87`, `content: <full output>`
- [ ] AC-7: Given score 87 and threshold 90, exit code is 3
- [ ] AC-8: Given score 94 and threshold 90, exit code is 0
- [ ] AC-9: Console output includes: score value, threshold, verdict (PASSED/BELOW THRESHOLD), issues list, artifact ID
- [ ] AC-10: `--prd <path>` flag includes PRD content in the scoring prompt context
- [ ] AC-11: Command works without a WorkflowExecution (standalone scoring of any WorkflowRun)

---

### Test Cases

#### Unit (Minitest)

- `test/services/legion/score_parser_test.rb`: Test all 4 parsing patterns (header, inline, slash, fallback). Edge cases: score 0, score 100, multiple scores in text (first match wins), no match → 0.
- `test/services/legion/score_service_test.rb`: Test full flow with mocked DispatchService. Verify Artifact creation, score extraction, exit code logic.

#### Integration (Minitest)

- `test/integration/score_command_test.rb`: Full score command with VCR-recorded QA dispatch. Verify Artifact persisted, score correct, exit code correct.

#### System / Smoke

- Manual: Run `bin/legion score --workflow-run <id> --team ROR` against a real workflow run.

---

### Manual Verification

1. Complete a workflow run via `bin/legion execute-plan --workflow-run <id>`
2. Run `bin/legion score --workflow-run <id> --team ROR`
3. Verify console output shows score, threshold, verdict
4. Run `Artifact.last` in console — verify `artifact_type: "score_report"`, `score` is an integer
5. Run with `--threshold 100` — verify exit code 3 (below threshold)
6. Run with `--threshold 50` — verify exit code 0 (passed)

**Expected:** Score displayed, Artifact created, exit codes correct per threshold comparison.

---

### Dependencies

- **Blocked By:** 2-01 (parallel dispatch infrastructure), 2-02 (Artifact model for storing scores)
- **Blocks:** 2-07 (QualityGate wraps score logic)

---

### Rollout / Deployment Notes

- **No migration** — uses Artifact table from 2-02
- **CLI addition** — new `score` subcommand in `bin/legion`

---

