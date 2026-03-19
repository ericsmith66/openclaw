# PRD-0092: Token & Cost Tracking, Budget Management & Graceful Handoff

**PRD ID**: PRD-0092
**Status**: Draft
**Priority**: High
**Created**: 2026-02-26
**Milestone**: M1 (Tool Loop)
**Depends On**: PRD-0090, PRD-0030, PRD-0095

---

## 📋 Metadata

**AiderDesk Source Files**:
- `src/main/agent/agent.ts:1620-1688` — `compactMessagesIfNeeded()` (threshold check, dispatch to compact or handoff)
- `src/main/agent/agent.ts:935-953` — Integration point in the runner loop (checks after each iteration)
- `src/main/agent/optimizer.ts` — `optimizeMessages()`, `optimizeAiderMessages()`, `optimizeSubagentMessages()` (pre-send token reduction)
- `src/main/task/task.ts:2352-2475` — `compactConversation()` (summarize and replace messages)
- `src/main/task/task.ts:2477-2572` — `handoffConversation()` (generate continuation prompt, create new task, transfer files)
- `src/common/types.ts:543-548` — `ContextCompactionType` enum (`Compact`, `Handoff`)
- `src/common/agent.ts:519-565` — `COMPACT_CONVERSATION_AGENT_PROFILE`, `HANDOFF_AGENT_PROFILE` (tool-less profiles)
- `resources/prompts/compact-conversation.hbs` — Compaction prompt template
- `resources/prompts/handoff.hbs` — Handoff prompt template
- `src/main/models/providers/default.ts:31-42` — `calculateCost()` (default cost formula: input + output + cache_read per-token costs)
- `src/main/task/task.ts:2205-2218` — `updateTotalCosts()` (accumulates `agentTotalCost` and `aiderTotalCost` from usage reports)
- `src/main/data-manager/data-manager.ts` — SQLite persistence of per-message usage/cost data
- `src/common/types.ts:686-711` — `UsageReportData`, `TokensCost`, `TokensInfoData` interfaces
- `src/common/types.ts:907-940` — `Model` interface with per-token cost fields

**Output Files** (Ruby):
- `lib/agent_desk/agent/token_budget_tracker.rb` — Per-run token accounting
- `lib/agent_desk/agent/state_snapshot.rb` — Structured state serialization
- `lib/agent_desk/agent/compaction_strategy.rb` — Strategy pattern for compact / handoff / tiered
- `lib/agent_desk/agent/conversation_compactor.rb` — Compact conversation via LLM summarization
- `lib/agent_desk/agent/conversation_handoff.rb` — Generate handoff prompt and create continuation task
- `spec/agent_desk/agent/token_budget_tracker_spec.rb`
- `spec/agent_desk/agent/state_snapshot_spec.rb`
- `spec/agent_desk/agent/compaction_strategy_spec.rb`
- `lib/agent_desk/agent/cost_calculator.rb` — Per-provider cost computation
- `lib/agent_desk/agent/usage_logger.rb` — Optional persistence of per-call usage/cost data
- `spec/agent_desk/agent/cost_calculator_spec.rb`
- `spec/agent_desk/agent/usage_logger_spec.rb`

---

## 1. Problem Statement

LLM context windows are finite. Claude 3.5 Sonnet has a 200K token input window; GPT-4o has 128K. When a complex agent task requires many tool calls — reading dozens of files, running commands, creating subtasks — the conversation history grows rapidly. Once the conversation approaches the context limit, the LLM either:

1. **Silently degrades** — drops older context and produces incoherent responses
2. **Hard fails** — the API returns a token limit error, aborting the task mid-execution
3. **Loses critical state** — todo items, partial progress, pending decisions vanish

### 1.1 Current State in AiderDesk

AiderDesk addresses this with two reactive mechanisms triggered when token usage exceeds a user-configured threshold:

**Compaction** (`ContextCompactionType.Compact`):
- Sends the full conversation to the LLM with a "summarize this" prompt using a tool-less agent profile (`COMPACT_CONVERSATION_AGENT_PROFILE`)
- Replaces the entire conversation with: original user message + the LLM-generated summary
- Re-injects the user's original request and resumes

**Handoff** (`ContextCompactionType.Handoff`):
- Uses `agent.generateText()` with a tool-less profile (`HANDOFF_AGENT_PROFILE`) to produce a continuation prompt
- Creates a new task with that prompt, transfers context files, optionally auto-executes

### 1.2 Problems with the Current Approach

| Problem | Impact |
|---------|--------|
| **Reactive only** — threshold check happens after each LLM response, not before sending | The final LLM call that exceeds the limit may already fail or degrade |
| **Unstructured state loss** — todo items, partial file edits, tool approval decisions, memory retrievals are discarded | The compacted/handoff task must re-discover context it already had |
| **No tiered degradation** — it's all-or-nothing: either full compaction or full handoff | Aggressive for borderline cases; no intermediate options |
| **Summary quality under pressure** — compaction happens when context is already huge, leaving less room for the summary prompt itself | Summaries can be lossy, missing file paths, code snippets, or decision rationale |
| **No budget visibility** — the runner loop has no concept of remaining capacity | Cannot proactively plan or split work before hitting the wall |
| **No hook integration** — external orchestrators (like Agent-Forge) cannot intercept or customize the compaction/handoff behavior | Tight coupling to the built-in strategies |

### 1.3 What the Ruby Gem Must Solve

The Ruby agent framework should:
1. Track cumulative token usage throughout the runner loop
2. Support configurable thresholds with tiered responses
3. Serialize structured state (not just free-text summaries) before any compaction or handoff
4. Expose hooks so external orchestrators can intercept and customize the behavior
5. Provide both compaction and handoff strategies as composable, swappable components
6. Enable proactive budget-aware decisions (e.g., "I have ~30K tokens left, should I start a new subtask?")

---

## 2. Design

### 2.1 Usage Tracker (Tokens & Cost)

Accumulates token usage and cost data from each LLM response and provides remaining-capacity calculations.

**Responsibilities**:
- Record `sent_tokens`, `received_tokens`, `cache_read_tokens` from each LLM call's usage report
- Record cost data (`message_cost`) from the provider's usage report; when not provided, compute cost from token counts and model cost rates
- Compute cumulative totals and percentage of max capacity consumed
- Determine which tier threshold (if any) has been crossed
- Enforce an optional cost budget cap for the run
- Expose `remaining_tokens` and `remaining_percentage` for proactive decisions

**Key data (tokens)**:
- `max_input_tokens` — from model configuration (e.g., 200_000 for Claude 3.5 Sonnet)
- `cumulative_sent` — total tokens sent to LLM across all iterations
- `cumulative_received` — total tokens received from LLM across all iterations
- `cumulative_cache_read` — total cache-read tokens (for providers that support caching)
- `last_usage` — usage from the most recent LLM call (most relevant for threshold checks, matching AiderDesk's approach)

**Key data (cost)**:
- `cumulative_cost` — total cost (in dollars) across all LLM calls in the run
- `last_message_cost` — cost of the most recent LLM call
- Model cost rates (loaded from model configuration):
  - `input_cost_per_token` — cost per input token
  - `output_cost_per_token` — cost per output token
  - `cache_read_cost_per_token` — cost per cache-read input token
  - `cache_write_cost_per_token` — cost per cache-write input token
- `cost_budget` — optional dollar amount cap for the run (nil/0 = unlimited, default)

**Methods**:
- `record_usage(sent_tokens:, received_tokens:, cache_read_tokens:, message_cost: nil)` — records token counts and cost. When `message_cost` is nil (provider didn't report cost), the tracker computes it using the `CostCalculator` with the model's cost rates and token counts.
- `cost_budget_exceeded?` — returns `true` when `cost_budget > 0` and `cumulative_cost >= cost_budget`. Returns `false` when `cost_budget` is 0 (unlimited).

**Threshold model** (matching AiderDesk's existing approach):
- AiderDesk checks `sentTokens + receivedTokens + cacheReadTokens` from the **last** LLM response against `maxInputTokens * (threshold / 100)`
- The Ruby gem preserves this same check as the primary threshold mechanism
- Additionally exposes cumulative totals for consumers who want trend-based decisions

**Note**: Cost budget enforcement is separate from the token threshold — both can trigger compaction or halt the runner independently.

### 2.2 State Snapshot

A structured representation of the agent's in-flight state at the moment compaction or handoff is triggered. This goes beyond a free-text summary.

**Contents**:
- `original_prompt` — the user's original request (unchanged)
- `todo_items` — current todo list with completion status (from TodoTools state)
- `files_modified` — list of files the agent has created or changed, with brief change descriptions
- `files_in_context` — list of context files currently loaded
- `key_decisions` — architectural or implementation decisions made during the run
- `memory_retrievals` — memories already retrieved (so the continuation doesn't re-fetch)
- `tool_approvals_granted` — per-tool approvals the user granted during this run
- `current_step` — what the agent was working on when the snapshot was taken
- `remaining_work` — what the agent knows it still needs to do (from todo items or conversation context)
- `custom_data` — extensible hash for hook consumers to attach domain-specific state

**Serialization**: The snapshot is a plain Ruby data structure that serializes to JSON. It is passed to the compaction/handoff strategy and can be injected into prompts or persisted to disk.

### 2.2a Cost Calculator

A utility module that computes the cost of a single LLM call from token counts and model cost rates. Mirrors AiderDesk's `calculateCost()` from `src/main/models/providers/default.ts`.

**Cost formula**:
- `input_cost = sent_tokens * input_cost_per_token`
- `output_cost = received_tokens * output_cost_per_token`
- `cache_read_cost = cache_read_tokens * cache_read_cost_per_token` (defaults to `input_cost_per_token` if `cache_read_cost_per_token` is not set)
- `cache_write_cost = cache_write_tokens * cache_write_cost_per_token` (defaults to `input_cost_per_token` if `cache_write_cost_per_token` is not set)
- `total = input_cost + output_cost + cache_read_cost + cache_write_cost`

**Provider-specific overrides**: Some providers (like OpenRouter) return cost directly in API response metadata. The calculator accepts an optional `provider_reported_cost` parameter that, when present, takes precedence over the calculated value. This matches how AiderDesk allows provider-specific implementations to override the default cost formula.

**Error handling**: When cost rates are nil or zero, the calculator returns 0 for those components rather than raising an error.

### 2.2b Usage Logger

An optional component for persisting per-call usage data (tokens, cost, model, timestamp, project) to a durable store.

**Interface**: `UsageLogger` — defines `log(usage_data)` and `query(from:, to:)` methods.

**Implementations**:

| Implementation | Behavior |
|---------------|----------|
| `NullLogger` | No-op (default for lightweight usage). All methods are safe to call but do nothing. |
| `SqliteLogger` | Persists to a SQLite table matching AiderDesk's `messages` schema. Columns: `id`, `timestamp`, `type`, `project`, `model`, `input_tokens`, `output_tokens`, `cache_write_tokens`, `cache_read_tokens`, `cost`, `message_content_json`. |

**Integration**:
- The runner calls `usage_logger.log(usage_data)` after each LLM response, alongside the `UsageTracker` update
- `query(from:, to:)` returns usage data rows within the specified date range, enabling reporting and dashboards
- `SqliteLogger` handles database errors gracefully — logs a warning but does not crash the runner

### 2.3 Compaction Strategies

A strategy pattern where each strategy implements the same interface but handles the token budget crisis differently.

**Strategy interface**:
- `execute(runner_context)` — perform the compaction/handoff, return a result indicating whether the runner should continue or stop
- `runner_context` contains: messages, state snapshot, token tracker, profile, model manager, hook manager, and a task registry (for handoff)

**Built-in strategies**:

#### 2.3.1 Compact Strategy
Mirrors AiderDesk's `ContextCompactionType.Compact`:
1. Build a `StateSnapshot` from current runner state
2. Send conversation + compact prompt to LLM using a tool-less profile (matching `COMPACT_CONVERSATION_AGENT_PROFILE`)
3. Extract the summary from the response
4. Replace conversation with: original user message + state snapshot (as structured context) + summary + continuation instruction
5. Signal runner to continue

**Improvement over AiderDesk**: The state snapshot is included as a structured section in the continuation message, so todo items, file lists, and decisions survive compaction even if the LLM summary omits them.

#### 2.3.2 Handoff Strategy
Mirrors AiderDesk's `ContextCompactionType.Handoff`:
1. Build a `StateSnapshot` from current runner state
2. Send conversation + handoff prompt to LLM using a tool-less profile (matching `HANDOFF_AGENT_PROFILE`)
3. Generate a continuation prompt from the response
4. Prepend the serialized state snapshot to the generated prompt
5. Create a new task in the task registry (or invoke a callback for external task creation)
6. Transfer context files to the new task
7. Optionally auto-execute the new task
8. Signal runner to stop (return `false` to the loop)

#### 2.3.3 Tiered Strategy (New — not in AiderDesk)
Applies progressively more aggressive compaction based on usage tiers:

| Tier | Trigger | Action |
|------|---------|--------|
| **Tier 1: Trim** | Usage crosses `tier_1_threshold` (default: 60%) | Strip verbose tool results from older messages (keep only summaries). Remove image data. Truncate large file reads to first/last N lines. |
| **Tier 2: Selective Compact** | Usage crosses `tier_2_threshold` (default: 75%) | Keep the most recent N messages intact; summarize everything older into a single assistant message with the state snapshot. |
| **Tier 3: Full** | Usage crosses `tier_3_threshold` (default: 85%) | Delegate to either the Compact or Handoff strategy (configurable). |

The tiered approach means the agent only pays the full compaction cost when truly necessary. At lower tiers, it just trims noise.

### 2.4 Hook Integration

Two new hook events integrate with the existing HookManager (PRD-0030):

**`on_token_budget_warning`**
- Fires when any threshold tier is crossed
- Event data: `{ tier:, usage_percentage:, remaining_tokens:, state_snapshot:, strategy:, cumulative_cost:, last_message_cost:, cost_budget:, cost_budget_exceeded: }`
- Handlers can:
  - Modify the strategy (e.g., force handoff instead of compact)
  - Modify the state snapshot (e.g., add domain-specific state)
  - Block the compaction (if the consumer wants to handle it externally)
  - Let it pass through for default behavior

**`on_cost_budget_exceeded`**
- Fires when `cost_budget` is set (> 0) and `cumulative_cost >= cost_budget`
- This is separate from the token threshold — cost budget checks run independently
- Event data: `{ cumulative_cost:, cost_budget:, last_message_cost:, state_snapshot: }`
- Handlers can:
  - Block the halt (to allow override/increase of the cost budget and continue the run)
  - Let it pass through (which halts the runner, similar to handoff)

**`on_handoff_created`**
- Fires after a handoff task has been created (but before optional auto-execution)
- Event data: `{ original_task_id:, new_task_id:, handoff_prompt:, state_snapshot:, context_files: }`
- Handlers can:
  - Modify the handoff prompt
  - Add additional context files
  - Block auto-execution
  - Route the handoff to an external orchestrator (e.g., Agent-Forge's WorkflowEngine)

### 2.5 Runner Loop Integration

The compaction check integrates into `Runner#run` at the same point as AiderDesk — after each LLM response is processed, before the next iteration begins.

**Flow**:
1. LLM responds → process tool calls → add results to conversation
2. Update `UsageTracker` with usage from the response (tokens and cost)
3. Log usage data via `UsageLogger` (if configured)
4. Check if cost budget has been exceeded (`cost_budget_exceeded?`)
5. If cost budget exceeded → fire `on_cost_budget_exceeded` hook
6. If not blocked by hook → halt the runner (set task state to `CostLimitReached`)
7. Check if any token threshold tier has been crossed
8. If crossed → fire `on_token_budget_warning` hook
9. If not blocked by hook → execute the configured compaction strategy
10. Strategy returns `continue` (true) or `stop` (false)
11. If `stop` → break the runner loop, set task state to `Interrupted`
12. If `continue` → the strategy has already modified the messages array in place → proceed to next iteration

**Note**: The cost budget check (steps 4–6) is independent of the token threshold check (steps 7–12) — either can halt the runner. Cost budget is checked first since it represents a hard financial limit.

### 2.6 Configuration

Token and cost budget behavior is configured per profile (extending PRD-0040):

**New profile fields**:
- `context_compacting_threshold` — percentage (0-100, 0 = disabled). Maps to AiderDesk's `contextCompactingThreshold`.
- `compaction_strategy` — one of `:compact`, `:handoff`, `:tiered` (default: `:compact`). Maps to AiderDesk's `ContextCompactionType` with the addition of `:tiered`.
- `tiered_thresholds` — hash `{ tier_1: 60, tier_2: 75, tier_3: 85 }` (only used when strategy is `:tiered`)
- `cost_budget` — optional dollar amount cap per run (0 = unlimited, default). When set, the runner halts if cumulative cost reaches or exceeds this value.

**Model cost rates** (loaded from model configuration, matching AiderDesk's `Model` interface):
- `input_cost_per_token` — maps to `Model.inputCostPerToken`
- `output_cost_per_token` — maps to `Model.outputCostPerToken`
- `cache_read_cost_per_token` — maps to `Model.cacheReadInputTokenCost`
- `cache_write_cost_per_token` — maps to `Model.cacheWriteInputTokenCost`

### 2.7 MessageBus Integration (PRD-0095)

When compaction or handoff occurs, the following events are published to the MessageBus:

- `conversation_compacted` — after successful compaction, includes summary length and tokens saved
- `conversation_handoff` — after handoff task creation, includes new task ID and prompt excerpt
- `token_budget_warning` — when a threshold is crossed, includes tier and usage data
- `usage_recorded` — published after each LLM call with token counts, cost, and cumulative totals
- `cost_budget_exceeded` — published when the cost budget is hit (cumulative_cost >= cost_budget)

This allows Agent-Forge's `EventRelay` to pick up these events via PostgreSQL LISTEN/NOTIFY and route them through Solid Cable to the UI.

---

## 3. Acceptance Criteria

### Usage Tracker (Tokens)
- ✅ Tracks cumulative and per-call token usage (sent, received, cache_read)
- ✅ Computes `remaining_tokens` and `usage_percentage` from `max_input_tokens`
- ✅ Returns the correct threshold tier when thresholds are crossed
- ✅ Returns `nil` tier when usage is below all thresholds
- ✅ Handles missing usage data gracefully (returns no tier crossed)

### State Snapshot
- ✅ Captures todo items, modified files, context files, key decisions, approvals, current step, remaining work
- ✅ Serializes to JSON and deserializes back to the same structure
- ✅ Includes extensible `custom_data` hash
- ✅ Works when some fields are empty/nil (partial snapshot)

### Compact Strategy
- ✅ Sends conversation to LLM with compact prompt and tool-less profile
- ✅ Replaces messages with: original user message + structured state snapshot + summary + continuation
- ✅ Signals runner to continue (returns `true`)
- ✅ Preserves todo items in the continuation via the state snapshot

### Handoff Strategy
- ✅ Sends conversation to LLM with handoff prompt and tool-less profile
- ✅ Creates a new task in the task registry with the generated prompt
- ✅ Prepends serialized state snapshot to the handoff prompt
- ✅ Transfers context files to the new task
- ✅ Signals runner to stop (returns `false`)
- ✅ Optionally auto-executes the new task

### Tiered Strategy
- ✅ At tier 1: trims verbose tool results from older messages without LLM call
- ✅ At tier 2: summarizes older messages while keeping recent N messages intact
- ✅ At tier 3: delegates to Compact or Handoff strategy
- ✅ Does not re-trigger a tier that has already been handled in the current run

### Hook Integration
- ✅ `on_token_budget_warning` fires when any threshold is crossed
- ✅ Hook can block default compaction behavior
- ✅ Hook can modify the strategy before execution
- ✅ Hook can modify the state snapshot
- ✅ `on_handoff_created` fires after handoff task creation
- ✅ Hook can modify the handoff prompt
- ✅ Hook can block auto-execution of the handoff task

### Runner Integration
- ✅ Compaction check runs after each LLM response (same position as AiderDesk)
- ✅ When `context_compacting_threshold` is 0, no checking occurs
- ✅ When compaction signals stop, runner sets task state to `Interrupted` and breaks
- ✅ When compaction signals continue, runner uses the modified messages for the next iteration

### Cost Calculator
- ✅ Computes cost correctly from token counts and per-token rates
- ✅ Uses provider-reported cost when available (takes precedence over calculation)
- ✅ Handles missing cost rates gracefully (returns 0)
- ✅ Handles cache write tokens in addition to cache read tokens

### Usage Tracker (Cost)
- ✅ Tracks cumulative cost across all LLM calls in a run
- ✅ Computes cost from token counts when provider doesn't report `message_cost`
- ✅ `cost_budget_exceeded?` returns true when `cumulative_cost >= cost_budget`
- ✅ `cost_budget_exceeded?` returns false when `cost_budget` is 0 (unlimited)

### Usage Logger
- ✅ `SqliteLogger` persists usage data to SQLite
- ✅ `NullLogger` is a no-op
- ✅ `query(from:, to:)` returns usage rows within the date range
- ✅ Logger handles database errors gracefully (logs warning, does not crash)

### Cost Budget in Runner
- ✅ Runner halts when cost budget exceeded (independent of token threshold)
- ✅ `on_cost_budget_exceeded` hook fires before halting
- ✅ Hook can block the halt (allowing the run to continue)
- ✅ When halted, task state set to indicate cost limit reached

### MessageBus Integration
- ✅ `conversation_compacted` event published after compaction
- ✅ `conversation_handoff` event published after handoff
- ✅ `token_budget_warning` event published when threshold crossed
- ✅ `usage_recorded` event published after each LLM call
- ✅ `cost_budget_exceeded` event published when cost budget is hit

---

## 4. Test Plan

### 4.1 UsageTracker (Tokens)

```
Test: records usage and computes remaining tokens
  Given: tracker initialized with max_input_tokens = 200_000
  When: record_usage called with sent=50_000, received=5_000
  Then: cumulative_sent = 50_000, remaining_tokens = 145_000, usage_percentage ≈ 27.5%

Test: detects threshold crossing
  Given: tracker with max_input_tokens = 200_000, threshold = 80
  When: record_usage with sent=170_000, received=10_000
  Then: threshold_crossed? returns true

Test: handles missing usage data
  Given: tracker with max_input_tokens = 200_000
  When: record_usage called with nil values
  Then: threshold_crossed? returns false, no exception

Test: tiered thresholds report correct tier
  Given: tracker with tiered thresholds { tier_1: 60, tier_2: 75, tier_3: 85 }
  When: usage at 70%
  Then: current_tier returns :tier_1
  When: usage at 80%
  Then: current_tier returns :tier_2
```

### 4.2 StateSnapshot

```
Test: captures todo items from TodoTools
  Given: TodoTools with items [{ name: "Step 1", completed: true }, { name: "Step 2", completed: false }]
  When: StateSnapshot.capture(runner_context) is called
  Then: snapshot.todo_items matches the items

Test: serializes to and from JSON
  Given: a fully populated StateSnapshot
  When: serialized to JSON and deserialized
  Then: all fields match the original

Test: handles empty state
  Given: a runner context with no todo items, no files, no approvals
  When: StateSnapshot.capture(runner_context) is called
  Then: snapshot is valid with empty arrays/hashes, no exceptions
```

### 4.3 Strategies

```
Test: Compact strategy replaces messages and signals continue
  Given: runner context with 20 messages exceeding threshold
  When: CompactStrategy.execute(context) is called
  Then: messages replaced with [original_user_msg, snapshot_msg, summary_msg, continuation_msg]
  And: returns true (continue)

Test: Handoff strategy creates task and signals stop
  Given: runner context with messages exceeding threshold
  When: HandoffStrategy.execute(context) is called
  Then: new task created in task_registry with generated prompt
  And: context files transferred to new task
  And: returns false (stop)

Test: Tiered strategy applies tier 1 trimming
  Given: runner context at 65% usage
  When: TieredStrategy.execute(context) is called
  Then: verbose tool results in older messages are trimmed
  And: no LLM call is made
  And: returns true (continue)

Test: Tiered strategy applies tier 2 selective compaction
  Given: runner context at 78% usage
  When: TieredStrategy.execute(context) is called
  Then: older messages summarized, recent N messages preserved
  And: LLM call made for summarization
  And: returns true (continue)

Test: Tiered strategy does not re-trigger handled tiers
  Given: runner context that already handled tier 1
  When: usage still at tier 1 level
  Then: no action taken, returns true (continue)
```

### 4.4 Hook Integration

```
Test: on_token_budget_warning fires and allows blocking
  Given: hook registered that blocks compaction
  When: threshold crossed
  Then: hook fires with correct event data
  And: default compaction does NOT execute
  And: runner continues (consumer is responsible)

Test: on_token_budget_warning allows strategy override
  Given: hook registered that changes strategy from :compact to :handoff
  When: threshold crossed
  Then: handoff strategy executes instead of compact

Test: on_handoff_created fires with correct data
  Given: handoff strategy executes
  When: new task is created
  Then: hook fires with original_task_id, new_task_id, handoff_prompt, state_snapshot
```

### 4.5 Runner Integration

```
Test: runner checks budget after each iteration
  Given: runner with mock model_manager returning increasing token usage
  When: run executes 5 iterations
  Then: budget check called 5 times

Test: runner stops when compaction signals stop (handoff)
  Given: runner with threshold at 50%, handoff strategy
  When: usage crosses 50% on iteration 3
  Then: handoff executes, runner breaks after iteration 3

Test: runner continues after compaction
  Given: runner with threshold at 50%, compact strategy
  When: usage crosses 50% on iteration 3
  Then: compaction executes, messages replaced, runner continues to iteration 4

Test: runner skips checking when threshold is 0
  Given: runner with context_compacting_threshold = 0
  When: usage reaches 95%
  Then: no compaction triggered, runner continues normally
```

### 4.6 Cost Calculator

```
Test: calculates cost from token counts and rates correctly
  Given: input_cost_per_token = 0.000003, output_cost_per_token = 0.000015
  When: calculate_cost called with sent_tokens=1000, received_tokens=500
  Then: total_cost = (1000 * 0.000003) + (500 * 0.000015) = 0.0105

Test: uses provider-reported cost when provided
  Given: provider_reported_cost = 0.042
  When: calculate_cost called with token counts and rates
  Then: returns 0.042 (ignores calculated value)

Test: handles nil/zero cost rates (returns 0)
  Given: all cost rates are nil
  When: calculate_cost called with token counts
  Then: returns 0.0

Test: handles cache write tokens
  Given: cache_write_cost_per_token = 0.00000375
  When: calculate_cost called with cache_write_tokens=200
  Then: cache_write_cost = 200 * 0.00000375 included in total
```

### 4.7 Usage Tracker (Cost)

```
Test: tracks cumulative cost across multiple calls
  Given: tracker initialized with cost rates
  When: record_usage called 3 times with message_cost = 0.01, 0.02, 0.03
  Then: cumulative_cost = 0.06

Test: auto-calculates cost when message_cost is nil
  Given: tracker with input_cost_per_token = 0.000003, output_cost_per_token = 0.000015
  When: record_usage called with sent=1000, received=500, message_cost=nil
  Then: last_message_cost = 0.0105, cumulative_cost includes this value

Test: cost_budget_exceeded returns true at limit
  Given: tracker with cost_budget = 0.10, cumulative_cost = 0.08
  When: record_usage called with message_cost = 0.03
  Then: cost_budget_exceeded? returns true (0.11 >= 0.10)

Test: cost_budget_exceeded returns false when budget is 0
  Given: tracker with cost_budget = 0
  When: cumulative_cost = 5.00
  Then: cost_budget_exceeded? returns false (unlimited)
```

### 4.8 Usage Logger

```
Test: SqliteLogger persists and queries usage data
  Given: SqliteLogger configured with a test database
  When: log called with usage data (tokens, cost, model, timestamp, project)
  Then: data is persisted to the SQLite table
  And: query(from: start, to: end) returns the logged row

Test: NullLogger does not persist
  Given: NullLogger instance
  When: log called with usage data
  Then: no database interaction occurs
  And: query returns empty results

Test: SqliteLogger handles DB errors gracefully
  Given: SqliteLogger with a read-only or corrupt database
  When: log called with usage data
  Then: logs a warning, does not raise an exception
  And: runner continues normally
```

### 4.9 Runner Cost Budget

```
Test: runner halts when cost budget exceeded
  Given: runner with cost_budget = 0.50
  When: cumulative_cost reaches 0.52 on iteration 4
  Then: runner halts, task state set to CostLimitReached

Test: on_cost_budget_exceeded hook fires
  Given: runner with cost_budget = 0.50, hook registered for on_cost_budget_exceeded
  When: cumulative_cost exceeds budget
  Then: hook fires with cumulative_cost, cost_budget, last_message_cost, state_snapshot

Test: hook can block halt to continue
  Given: hook registered that blocks the cost budget halt
  When: cumulative_cost exceeds budget
  Then: hook fires, runner continues to next iteration

Test: runner continues normally when cost_budget is 0
  Given: runner with cost_budget = 0 (unlimited)
  When: cumulative_cost reaches 100.00
  Then: no cost budget check fires, runner continues normally
```

---

## 5. AiderDesk Mapping

| Ruby | AiderDesk |
|------|-----------|
| `UsageTracker` | Inline calculation in `compactMessagesIfNeeded()` — `usageReport.sentTokens + receivedTokens + cacheReadTokens` |
| `StateSnapshot` | No equivalent — AiderDesk relies entirely on the LLM-generated summary |
| `CompactStrategy` | `compactConversation()` in `task.ts` |
| `HandoffStrategy` | `handoffConversation()` in `task.ts` |
| `TieredStrategy` | No equivalent — new to the Ruby gem |
| `CompactionStrategy` interface | `ContextCompactionType` enum dispatched via `if/else` in `compactMessagesIfNeeded()` |
| `on_token_budget_warning` hook | No equivalent — AiderDesk has no hook before compaction |
| `on_handoff_created` hook | No equivalent — AiderDesk creates the task directly |
| `conversation_compacted` event | No equivalent event — AiderDesk logs only |
| `conversation_handoff` event | `sendTaskCreated` event (partial equivalent) |
| Profile `context_compacting_threshold` | `TaskData.contextCompactingThreshold` |
| Profile `compaction_strategy` | `ContextCompactionType` in settings |
| Tool-less compact profile | `COMPACT_CONVERSATION_AGENT_PROFILE` in `src/common/agent.ts` |
| Tool-less handoff profile | `HANDOFF_AGENT_PROFILE` in `src/common/agent.ts` |
| Compact prompt template | `resources/prompts/compact-conversation.hbs` |
| Handoff prompt template | `resources/prompts/handoff.hbs` |
| `CostCalculator` | `calculateCost()` in `src/main/models/providers/default.ts` |
| `UsageTracker.cumulative_cost` | `task.task.agentTotalCost` (accumulated in `updateTotalCosts`) |
| `UsageTracker.last_message_cost` | `usageReport.messageCost` |
| `UsageLogger (SqliteLogger)` | `DataManager.saveMessage()` + `DataManager.queryUsageData()` |
| `UsageLogger (NullLogger)` | No equivalent (AiderDesk always persists) |
| `on_cost_budget_exceeded` hook | No equivalent (AiderDesk has no cost budget feature) |
| `cost_budget` profile field | No equivalent (new to Ruby gem) |
| Model cost rates | `Model.inputCostPerToken`, `outputCostPerToken`, `cacheWriteInputTokenCost`, `cacheReadInputTokenCost` |

---

## 6. Agent-Forge Integration Notes

This PRD is designed with Agent-Forge's orchestration architecture in mind:

### Handoff via WorkflowEngine
When the `on_handoff_created` hook fires, Agent-Forge can:
1. Receive the event via `MessageBus` → `PostgresBus` → `LISTEN/NOTIFY`
2. Route it through `EventRelay` to `AgentTaskChannel` (ActionCable)
3. `WorkflowEngine` picks up the event and creates a new `AgentTask` record
4. `AgentDispatchJob` (Solid Queue) enqueues the continuation task
5. The UI (Turbo Streams) updates to show the handoff in progress

This is more robust than AiderDesk's approach because the **orchestrator** manages the handoff lifecycle, not the agent itself.

### Token & Cost Budget Events in Turbo Streams
The `token_budget_warning` MessageBus event can be relayed to the browser via:
- `Solid Cable` → `AgentTaskChannel` → Turbo Stream update
- Renders a warning indicator in the task UI showing remaining capacity
- Allows the user to proactively trigger compaction or handoff before the automatic threshold

---

## 7. Dependencies & Ordering

### Depends On
- **PRD-0090** (Agent Runner Loop) — this PRD modifies the runner loop to integrate budget checking
- **PRD-0030** (Hook System) — adds two new hook events (`on_token_budget_warning`, `on_handoff_created`)
- **PRD-0095** (Message Bus) — publishes compaction/handoff events

### Depended On By
- **PRD-0110** (Todo/Task Tools) — the StateSnapshot captures todo state; the Handoff strategy creates tasks via the task registry

### Implementation Order
This PRD should be implemented **after** PRD-0090 and can be done in parallel with PRDs 0040, 0050, 0080, 0100, and 0110 (all Wave 3 per the existing parallelization plan).

### Updated Dependency Graph (additions in bold)
```
0010 (types/constants)
 ├── 0020 (tool framework)
 │    ├── 0050 (power tools)
 │    ├── 0080 (skills tools)
 │    ├── 0100 (memory tools)
 │    └── 0110 (todo/task/helper tools)
 ├── 0030 (hooks)
 ├── 0040 (profiles) ← 0020
 ├── 0060 (prompts) ← 0040
 │    └── 0070 (rules)
 └── 0095 (message bus)

0090 (agent runner) ← 0020, 0030
**0092 (token & cost tracking / handoff) ← 0090, 0030, 0095**
```

### Updated Wave Schedule
| Wave | PRDs | Notes |
|------|------|-------|
| **1** | 0010 | Solo |
| **2** | 0020, 0030, 0095 | Parallel |
| **3** | 0040, 0050, 0080, 0090, 0100, 0110 | Parallel — **0092 can start as soon as 0090 completes** |
| **3b** | **0092** | Immediately after 0090 (0030 and 0095 are already done in Wave 2) |
| **4** | 0060 | Solo |
| **5** | 0070 | Solo |

---

**Next**: Implementation proceeds after PRD-0090 (Agent Runner Loop) is complete. The Compact and Handoff prompt templates from `resources/prompts/` should be ported to the Ruby gem's template directory as part of PRD-0060 (Prompt Templating).
