# Agentic Coding Benchmark Results & Task Orchestration Strategy

> **Created:** 2026-03-06
> **Source:** Live benchmark testing of `agent_desk` gem Runner + PowerTools pipeline
> **Status:** Idea — informs future Epic design for task decomposition and model routing

---

## 1. Executive Summary

We ran 20 live agentic coding tests (4 prompts × 5 models) through the `agent_desk` gem's
Runner + PowerTools pipeline against a fresh Rails 8 app. Every model completed every prompt
successfully, proving the gem can drive real coding work today. The results reveal clear
model performance tiers, cost tradeoffs, and — critically — predictable failure boundaries
that should inform how Legion decomposes and routes coding tasks.

**Key finding:** The gem works. The bottleneck is not capability — it's task sizing. A well-decomposed
task succeeds reliably on any model. A poorly-scoped task will hit context, iteration, or time
walls depending on the model.

---

## 2. Benchmark Results

### 2.1 Test Prompts (Increasing Complexity)

| Prompt | Name | Description | Complexity |
|--------|------|-------------|------------|
| P1 | Model + Migration | Generate User model, add unique index, run migration, add validations, verify | Single concern |
| P2 | CRUD Controller | Create PostsController with all RESTful JSON actions, routes, strong params | Single concern |
| P3 | Validations + JSON Errors | Add model validations + update controller error responses to JSON | Two concerns |
| P4 | Soft Delete (Hard Mode) | Polymorphic soft-delete with cascading, atomic transactions, auditable restore | Four+ concerns |

### 2.2 Models Tested

| Model | Provider | Type | Context Window |
|-------|----------|------|----------------|
| grok-4-1-fast-non-reasoning | xAI | Cloud API | 2,000,000 |
| claude-sonnet-4-6 | Anthropic | Cloud API | 200,000 |
| qwen3-coder-next:latest (79.7B Q4_K_M) | Ollama (local) | Local | 262,144 |
| deepseek-chat (V3.2) | DeepSeek | Cloud API | 128,000 |
| deepseek-reasoner (V3.2 Thinking) | DeepSeek | Cloud API | 128,000 |

### 2.3 Full Results Matrix

| Model | P1 (time/iters/tools) | P2 | P3 | P4 | Total Time | Avg Iters |
|-------|----------------------|-----|-----|-----|------------|-----------|
| **Grok 4.1 Fast** | 54.9s / 22 / 21 | 22.4s / 7 / 10 | 37.7s / 16 / 22 | 38.6s / 16 / 21 | **153.6s** | **15.2** |
| **Claude Sonnet 4.6** | 43.1s / 14 / 14 | 57.1s / 12 / 16 | 83.9s / 11 / 13 | 64.4s / 11 / 22 | **248.5s** | **12.0** |
| **Qwen3 Coder Next** | 60.1s / 13 / 12 | 218.3s / 30 / 32 | 64.8s / 14 / 14 | 360.1s / 44 / 43 | **703.3s** | **25.2** |
| **DeepSeek Chat** | 146.3s / 25 / 24 | 205.6s / 24 / 23 | 246.9s / 33 / 32 | 471.6s / 49 / 48 | **1,070.4s** | **32.8** |
| **DeepSeek Reasoner** | 153.0s / 21 / 20 | 415.6s / 39 / 38 | 465.3s / 41 / 40 | 623.4s / 49 / 48 | **1,657.3s** | **37.5** |

### 2.4 API Pricing (per 1M tokens)

| Model | Input | Output | Cache Hit | Cost Rating |
|-------|-------|--------|-----------|-------------|
| **Qwen3 Coder Next** | $0 | $0 | $0 | **FREE** (local) |
| **Grok 4.1 Fast** | $0.20 | $0.50 | $0.05 | 💚 Dirt cheap |
| **DeepSeek Chat** | $0.28 | $0.42 | $0.028 | 💚 Dirt cheap |
| **DeepSeek Reasoner** | $0.28 | $0.42 | $0.028 | 💚 Dirt cheap |
| **Claude Sonnet 4.6** | $3.00 | $15.00 | $0.30 | 🔴 30× pricier (output) |

### 2.5 Rankings

| Rank | Model | Why |
|------|-------|-----|
| 🥇 | **Grok 4.1 Fast** | Fastest (2.5 min total), cheapest API, 2M context runway |
| 🥈 | **Claude Sonnet 4.6** | Most efficient (fewest iterations), best reasoning per turn |
| 🥉 | **Qwen3 Coder Next** | Free, solid, no API dependency — best value on local hardware |
| 4th | **DeepSeek Chat** | Cheap but 7× slower than Grok |
| 5th | **DeepSeek Reasoner** | Same cost as Chat, 55% slower — reasoning hurts agentic loops |

---

## 3. Key Insights

### 3.1 Reasoning Models Hurt Agentic Coding

DeepSeek Reasoner was 55% slower than DeepSeek Chat with more iterations and identical cost.
The extra "thinking" overhead buys nothing when the agent loop already provides iterative
self-correction via tool feedback.

> **Rule: Never use reasoning models for agentic tool-calling tasks.**

### 3.2 All Models Can Code — Task Sizing Is the Variable

Every model passed every prompt (20/20). The quality difference is negligible for well-scoped
tasks. What varies wildly is efficiency:
- Grok: 16 iterations on P4
- DeepSeek: 49 iterations on P4 (3× more work for the same result)

This means the orchestrator's job is not "pick the smart model" — it's "make the task small
enough that any model succeeds quickly."

### 3.3 Iteration Cost Grows Non-Linearly

Each iteration adds to context, making the next iteration slower and more expensive.
Sec/iteration at P4 ranges from 2.4s (Grok) to 12.7s (DeepSeek Reasoner). This
compounds — a 50-iteration task isn't 2× a 25-iteration task, it's closer to 3×.

### 3.4 Optimal Model-to-Role Mapping

| Role | Best Model | Rationale |
|------|-----------|-----------|
| **Coding execution** (migrations, controllers, CRUD) | Grok Fast | Fastest, cheapest, nails routine tasks |
| **Architecture & planning** | Claude Sonnet/Opus | Fewest iterations = best reasoning per turn |
| **Code review / QA** | Claude Sonnet | Read-heavy, efficiency matters more than speed |
| **Bulk/batch coding** | DeepSeek Chat | Nearly free, works if speed isn't critical |
| **Local/offline dev** | Qwen3 | Free, no API dependency |
| **Debugging** | Grok Fast or DeepSeek Chat | Iterative tool-calling, speed > reasoning |

---

## 4. The Atomic Task Scale

### 4.1 Three Dimensions of Task Complexity

Score each task on 3 dimensions (1–4 each):

#### Dimension 1: Files Touched

| Level | Score | Files | Example |
|-------|-------|-------|---------|
| ⚛️ Atomic | 1 | 1–2 | Add a migration, add validations to a model |
| 🔗 Coupled | 2 | 3–4 | Model + controller + routes |
| 🧩 Compound | 3 | 5–7 | Model + concern + migration + controller + tests |
| 💣 Orchestration | 4 | 8+ | Soft delete across models with shared concerns + tests |

#### Dimension 2: Concept Count

| Level | Score | Concepts | Example |
|-------|-------|----------|---------|
| ⚛️ Atomic | 1 | 1 | "Add presence validation to User" |
| 🔗 Coupled | 2 | 2 | "Add validation + update controller error handling" |
| 🧩 Compound | 3 | 3–4 | "Add soft delete columns + default scopes + cascade callbacks" |
| 💣 Orchestration | 4 | 5+ | Migrations + scopes + default_scope + transactions + callbacks + audit |

#### Dimension 3: Cross-Model Dependencies

| Level | Score | Dependencies | Example |
|-------|-------|--------------|---------|
| ⚛️ Atomic | 1 | 0 | Change is self-contained in one model/file |
| 🔗 Coupled | 2 | 1 | Controller depends on model having certain validations |
| 🧩 Compound | 3 | 2–3 | Post.soft_delete must update Comments, Comments track cascade_deleted |
| 💣 Orchestration | 4 | 4+ | Polymorphic + cascading + restore + edge cases across models |

### 4.2 The Decomposition Rule

> **If total score > 6, decompose the task into sub-tasks.**

#### Example: P4 Soft Delete (Score: 4+4+3 = 11 → DECOMPOSE)

Decomposed into 6 atomic tasks:
1. "Add `deleted_at` column to Post" → Score: 2+1+1 = **4** ✅
2. "Add `deleted_at` + `cascade_deleted` to Comment" → Score: 2+1+1 = **4** ✅
3. "Add `default_scope` and `with_deleted` to Post and Comment" → Score: 2+2+2 = **6** ✅
4. "Add `Post#soft_delete` with cascade in transaction" → Score: 2+3+2 = **7** ⚠️ (borderline)
5. "Add `Post#restore` for cascade-deleted comments only" → Score: 2+2+2 = **6** ✅
6. "Verify soft delete/restore edge cases" → Score: 1+1+2 = **4** ✅

Each sub-task completes in ~20–60s on Grok instead of gambling on 48 tool calls.

---

## 5. The Three Failure Walls

Every model hits one of three hard limits. **Whichever comes first kills the task.**

| Wall | What | Driver |
|------|------|--------|
| **1. Iteration Cap** | `max_iterations=200` (configurable) | Safety guardrail |
| **2. Context Window** | Conversation grows ~2K tokens/iteration | Model architecture limit |
| **3. Time Budget** | Practical limit ~15 min per task | Operational cost / risk |

### 5.1 Failure Boundary Matrix

| Model | Context Window | P4 Iters Used | Hard Limit (iters) | Limiting Wall | Headroom | Max Task vs P4 |
|-------|---------------|---------------|---------------------|---------------|----------|----------------|
| **Grok Fast** | 2,000,000 | 16 (8%) | 200 | Iteration cap | 92% | **~12.5× P4** |
| **Claude 4.6** | 200,000 | 11 (11%) | ~98 | Context | 89% | **~8.9× P4** |
| **Qwen3** | 262,144 | 44 (40%) | ~110 | Time (15 min) | 60% | **~2.5× P4** |
| **DeepSeek Chat** | 128,000 | 49 (80%) | ~62 | Context | 20% | **~1.3× P4** |
| **DeepSeek Reasoner** | 128,000 | 49 (80%) | ~62 | Context | 20% | **~1.3× P4** |

### 5.2 Interpretation

- **Grok Fast** has massive runway — 92% headroom. Could handle tasks ~12× harder than P4.
- **Claude** is efficient but context-capped at ~98 iterations. Still 89% headroom on P4.
- **Qwen3** is time-limited at 8.2s/iteration. Usable but decomposes earlier.
- **DeepSeek** is already at 80% capacity on P4. Anything harder will likely fail.

### 5.3 The Orchestration Safety Rule

> **Decompose any task where estimated iterations exceed 50% of the model's hard limit.**

| Model | Decompose threshold | Why |
|-------|-------------------|-----|
| **Grok Fast** | > 100 iterations | Generous ceiling |
| **Claude 4.6** | > 50 iterations | Context wall at 98 |
| **Qwen3** | > 55 iterations | Time wall at 110 |
| **DeepSeek** | > 30 iterations | Context wall at 62 — decompose almost everything |

---

## 6. Implications for Legion

### 6.1 The Gem Works Today

The `agent_desk` gem's Runner + PowerTools pipeline reliably drives real agentic coding across
5 different LLM providers. No code changes needed — just smart task scoping.

### 6.2 Agent Config Recommendations

Current vs recommended model assignments based on benchmark data:

| Agent | Current Model | Recommended | Rationale |
|-------|--------------|-------------|-----------|
| **Rails Lead** | deepseek-reasoner | **grok-4-1-fast** | Coding = speed + tools, not reasoning overhead. 10× faster, 30× cheaper vs Claude. |
| **Architect** | claude-opus | claude-opus *(keep)* | Planning/design = few iterations, worth premium. |
| **QA** | claude-sonnet | claude-sonnet *(keep)* | Review = read-heavy, Claude's efficiency shines. |
| **Debug** | claude-sonnet | **grok-4-1-fast** or deepseek-chat | Debug is iterative tool-calling, speed > reasoning. |

### 6.3 Future: TaskDecomposer Service

Build a `TaskDecomposer` that:
1. Receives a feature description from the Architect agent
2. Scores it on the 3-dimension atomic scale (files × concepts × dependencies)
3. If score > 6, decomposes into ordered sub-tasks with dependency graph
4. Estimates iteration count per sub-task
5. Routes each sub-task to the optimal model based on failure wall thresholds
6. Each atomic prompt targets ≤ 2 files, ≤ 2 concepts, ≤ 1 cross-model dependency

### 6.4 Future: Iteration Budget Estimator

Use benchmark data to build a lookup/regression model:
- Input: task complexity score (from atomic scale)
- Output: estimated iterations per model
- Use to pre-check: "Will this task fit within the model's failure wall?"
- If not: auto-decompose or route to a model with more headroom

---

## 7. Test Infrastructure

All tests ran via `projects/legion-test/run_test.rb` — a reusable runner that:
- Creates a fresh Rails 8 app via `rails new`
- Sets up model prerequisites per prompt
- Drives the `agent_desk` Runner + PowerTools pipeline
- Records results to `results.json` with timing, iterations, tool calls
- Supports any model available on SmartProxy

The test infrastructure is ready for expanded benchmarks (more models, harder prompts,
multi-step workflows) as Legion's orchestration capabilities grow.

---

## 8. Raw Data

Full results JSON is stored at `projects/legion-test/results.json` (gitignored).
The test runner script is at `projects/legion-test/run_test.rb`.
