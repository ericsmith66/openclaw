### Spike PRD (Tightened): `agent:test_sdlc` Success Throughput & Observability

#### 1) Background / Context
We cannot reliably reproduce a passing `agent:test_sdlc` end-to-end run. Failures cluster into:
- Provider instability (`RubyLLM::ServerError`)
- Provider rejections (`RubyLLM::BadRequestError`) often correlated with oversized tool outputs / context bloat
- Prompt/contract non-compliance (SAP PRD invalid even after retry)
- Tooling robustness issues (malformed shell commands, optimistic locking, missing sandbox init assumptions)
- Guardrail-induced aborts (per-turn tool limits)

We have made tactical improvements (caps, retries, truncation in `VcTool`, etc.) but success rate remains low and noisy. We need a spike focused on **pipeline reliability + measurement** to drive to ~90% success.

#### 2) Problem Statement
Increase “successful run throughput” of `agent:test_sdlc` by reducing unclassified hard failures and by adding stage-level contracts, recovery strategies, and instrumentation so we can:
- predict failure early,
- automatically recover where safe,
- and generate an evidence-backed plan to reach ~90% success.

#### 3) Success Metric (explicit)
We will track two primary metrics:
- **Metric A (Quality Success):** `% runs with pass=true` (tests green, rubric met)
- **Metric B (Completion Success):** `% runs that complete without crashing`

Provider/infra failures should be **excluded** from the numerator/denominator for “agent quality”, **unless** the failure is attributable to our own request formation (e.g., context bloat, invalid tool schema, oversized payload). In practice we will label each run outcome as:
- `pass` (rubric met)
- `fail` (agent/pipeline failure)
- `inconclusive_provider` (provider/server instability)
- `inconclusive_request_formation` (BadRequest caused by our payload/context/tool output)

The 90% target applies to:
- **Optimize Metric B first** (completion without crashing), then raise quality (Metric A) without significantly regressing completion.

Provider/infra failures should be **excluded** from the success-rate denominator unless the failure is attributable to our request formation.
We will treat `RubyLLM::BadRequestError` as **unknown** by default until we have enough telemetry to label it as `request_formation` vs provider-side validation.

#### 4) Goals
This spike will deliver:
1) **Failure taxonomy + automated classification** for every run.
2) **Stage-level metrics** (drop-off points, duration, tool-call counts, context sizes).
3) **Global tool-output truncation/summarization** to reduce `BadRequest` driven by request formation.
4) **Contract gating + targeted auto-retry** for the highest-impact stage artifacts.
5) A prioritized, evidence-based roadmap to reach ~90% success.

#### 5) Non-goals
- Promotion of sandbox changes into PRs/branches (separate PRD/epic)
- Replacing the LLM provider/models (unless measurements prove it necessary)
- Major autonomy reduction (deterministic planner rewrite) in this spike

#### 6) Scope (What we will implement in the spike)
##### Workstream A — Observability & Failure Taxonomy (Pipeline-first)
Add structured run telemetry (events + summary fields) so every run ends with a machine-readable classification.

**Required classifications (minimum set):**
- `provider_server_error`
- `provider_timeout`
- `provider_bad_request_request_formation` (payload too large, invalid schema)
- `provider_bad_request_other`
- `contract_failure_prd`
- `contract_failure_intent_summary`
- `contract_failure_plan_json`
- `contract_failure_micro_tasks`
- `tool_failure_shell_parse`
- `tool_failure_allowlist`
- `guardrail_abort`
- `db_locking_stale_object`
- `tests_failed`

**Required telemetry fields (per run):**
- stage start/end timestamps
- total tool calls, tool calls by turn
- max tool output bytes by tool (stdout/stderr)
- prompt/context bytes per agent stage
- whether truncation occurred (and where)

Deliverable: `run_summary.json` (or equivalent) next to `run_summary.md`.

##### Workstream B — Global Context Controls (reduce request formation failures)
Implement **global** output bounding across tools (not only `VcTool`):
- Cap stdout/stderr per tool call (configurable; default 50k–200k bytes)
- Mark tool outputs with `truncated=true` and original size metadata
- Prefer summarized results for known high-volume actions:
    - `vc diff`: default to `--stat`/`--name-only` unless explicitly requesting full diff
    - test output: store full output to file, pass only summary + last N lines to LLM context

Deliverable: policy doc + implementation that prevents multi-MB outputs entering the LLM context.

##### Workstream C — Stage Contracts + Recovery (bounded artifacts)
Add 2 minimal, high-leverage contracts with targeted auto-retry:

1) **Intent Summary Contract** (SAP or Coordinator)
- Output: **small JSON** with keys:
    - `business_requirement`, `user_interaction`, `change_impact`, `constraints`, `success_criteria`
- Validation: required keys present, bounded length, includes key nouns/routes.
- Recovery: up to N targeted reprompts.

2) **Plan JSON Contract** (Planner)
- Output: JSON array of steps with:
    - `files`, `commands`, `tests`
- Validation: non-empty; includes at least one test command; bounded size.
- Recovery: targeted reprompt.

(We can treat `micro_tasks.json` as either part of Plan JSON or a separate contract depending on existing pipeline constraints.)

##### Workstream D — Guardrail Strategy (loosen execution guardrails, keep quality contracts)
- Loosen execution guardrails where they currently cause hard aborts (tool-call caps/timeouts) *after* plan is approved.
- Keep quality contracts strict (PRD validity, plan validity, tests executed).
- Ensure failures become classified outcomes rather than exceptions that terminate without summary.

#### 7) Measurements / Experiments
##### Baseline Experiment
- Run N=50 using the same scenario/prompt set.
- Compute:
    - Metric A (`pass=true`)
    - Metric B (completion without crash)
    - Breakdown by failure taxonomy
    - Stage drop-off rates

##### Post-change Experiment
- Re-run N=50.
- Compare deltas:
    - reduction in `provider_bad_request_request_formation`
    - reduction in hard aborts (`guardrail_abort`, `tool_failure_shell_parse`, `db_locking_stale_object`)
    - changes in pass rate and completion rate

#### 8) Acceptance Criteria
Spike is complete when:
- Every run emits `run_summary.json` with classification and telemetry
- We can answer, with data:
    1) Top 3 failure causes
    2) Which stage is the highest drop-off
    3) Which changes provide the largest improvement to Metric A and Metric B
- We have implemented:
    - global tool output truncation
    - Intent Summary + Plan JSON contract gating with bounded artifacts and targeted retry

#### 9) Risks / Tradeoffs (explicitly accepted)
- Increased runtime and token cost are acceptable.
- More stages can increase exposure to provider flakiness; mitigated by retry + `inconclusive_provider` classification.
- Contracts must be strictly bounded or they will reintroduce context bloat.

#### 10) Epic Consideration: “Context Provider” + “Context Menu”
This likely belongs as an **epic** with this spike as the first PRD.

Proposed epic framing:
- **Context Provider (backend):** pluggable sources (RAG tiers, schema, routes, UI guidelines) producing bounded, structured context objects.
- **Context Menu (agent UX/controls):** explicit selection of context packs per stage (e.g., `VisionSSOT`, `UXDesignStrategy`, `InteractionMap`, `TechnicalDebtScan`) with strict size budgets.

In this spike we only implement the minimal “context bounding + telemetry” necessary to learn which context packs improve success without causing `BadRequest`.

---

#### 11) Default settings for the spike (decisions already made)
- **Optimize Metric B first** (completion without crashing), then raise quality (Metric A).
- **Default truncation budget:** `200_000` bytes per tool stdout/stderr (configurable).
- **BadRequest classification:** default to `provider_bad_request_unknown` until telemetry can distinguish request-formation vs provider-side validation.