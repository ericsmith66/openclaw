# SmartProxy — TODO / Backlog

**Created:** 2026-03-02
**Source:** Epic 4C model compatibility testing (agent_desk gem)

---

## Priority 1 — Bugs (Claude 400/404 errors)

These were discovered during the Epic 4C model compatibility test suite (`bin/model_compatibility_test`). All Claude non-`-with-live-search` variants return HTTP 400 on simple chat (no tools). The `-with-live-search` variants pass 12/12 because the tool orchestrator path formats requests differently.

### FIXED: BUG-001: Claude models return HTTP 400 on simple chat requests
- **Affected models:** `claude-sonnet-4-5-20250929`, `claude-sonnet-4-20250514`, `claude-3-haiku-20240307`
- **Root cause:** `normalize_content_for_claude()` returned empty arrays `[]` for nil/empty content. Anthropic rejects messages with empty content arrays.
- **Fix applied (2026-03-02):**
  - `normalize_content_for_claude()` now returns `nil` instead of `[]` for empty content
  - `map_to_claude()` now skips messages with nil normalized content
  - Added error response body logging for 400+ status codes
  - Added 2 new RSpec tests covering nil/empty content filtering
- **Needs retest** with `bin/model_compatibility_test` against production

### BUG-002: `claude-3-5-haiku-20241022` returns HTTP 404
- **Affected models:** `claude-3-5-haiku-20241022`, `claude-3-5-haiku-20241022-with-live-search`
- **All LLM tests fail** (T05, T07, T08, T09, T10)
- **Root cause:** Anthropic has retired this model ID. 404 = model not found at Anthropic's API.
- **Fix:** Remove from `CLAUDE_MODELS`. Replaced by `claude-haiku-4-5-20251001` (already added to model list 2026-03-02).

---

## Priority 2 — Model Updates (completed 2026-03-02, needs retest)

Model lists were updated in `model_aggregator.rb`, `deploy.sh`, and remote `.env.production`. New models need testing with the compatibility suite.

### DONE: Add Claude 4.6 models
- [x] `claude-opus-4-6` — new flagship ($5/$25 per MTok, 200K context)
- [x] `claude-sonnet-4-6` — new mid-tier ($3/$15 per MTok, 200K context)
- [x] `claude-haiku-4-5-20251001` — replaces retired claude-3-5-haiku ($1/$5 per MTok)

### DONE: Add Grok 4.1 and Grok 3 models
- [x] `grok-4-1-fast-reasoning` — Grok 4.1, 2M context
- [x] `grok-4-1-fast-non-reasoning` — Grok 4.1 without reasoning
- [x] `grok-code-fast-1` — code-specific, 256K context
- [x] `grok-3` — previous gen, 131K context
- [x] `grok-3-mini` — lightweight, 131K context

### DONE: Remove deprecated models
- [x] Remove `claude-3-5-haiku-20241022` from CLAUDE_MODELS default in `model_aggregator.rb` and `deploy.sh` (returns 404, retired)
- [x] `claude-3-haiku-20240307` was not in code defaults — only exposed if production `CLAUDE_MODELS` env var includes it. Production env should be updated separately.

### TODO: Rerun compatibility test with new models
- [ ] Run `bin/model_compatibility_test` from agent_desk gem against updated SmartProxy
- [ ] Verify new Claude 4.6 models pass all 12 tests
- [ ] Verify new Grok 4.1 models pass all 12 tests

---

## Priority 3 — New Provider: Fireworks AI

### EPIC: Add Fireworks AI Provider
Full PRD: `knowledge_base/epics/epic-4-add-fireworks-provider.md`

Fireworks AI provides an OpenAI-compatible API with fast inference for open-source models.

- **API Base URL:** `https://api.fireworks.ai/inference/v1`
- **Auth:** Bearer token via `FIREWORKS_API_KEY`
- **API format:** OpenAI-compatible (same as Grok pattern)
- **Key models:**
  - `accounts/fireworks/models/llama-v3p3-70b-instruct` — Llama 3.3 70B
  - `accounts/fireworks/models/llama4-maverick-instruct-basic` — Llama 4 Maverick
  - `accounts/fireworks/models/qwen3-235b-a22b` — Qwen 3 235B MoE
  - `accounts/fireworks/models/deepseek-v3-0324` — DeepSeek V3
  - `accounts/fireworks/models/deepseek-r1` — DeepSeek R1

#### Implementation tasks:
- [ ] Create `lib/fireworks_client.rb` following `GrokClient` pattern
- [ ] Add `use_fireworks?` detection to `ModelRouter` (model starts with `accounts/fireworks/` or `fireworks/`)
- [ ] Add `list_fireworks_models` to `ModelAggregator`
- [ ] Add env vars: `FIREWORKS_API_KEY`, `FIREWORKS_MODELS`, `FIREWORKS_TIMEOUT`
- [ ] Update `deploy.sh` `.env.production` template
- [ ] Add specs: `fireworks_client_spec.rb`, update `model_router_spec.rb`, `model_aggregator_spec.rb`
- [ ] Add to README.md

---

## Priority 4 — New Provider: DeepSeek

### EPIC: Add DeepSeek Provider
Full PRD: `knowledge_base/epics/epic-3-add-deepseek-provider.md`

- **API Base URL:** `https://api.deepseek.com/v1`
- **Auth:** Bearer token via `DEEPSEEK_API_KEY`
- **API format:** OpenAI-compatible
- **Key models:**
  - `deepseek-chat` — DeepSeek V3 (general purpose)
  - `deepseek-reasoner` — DeepSeek R1 (reasoning)

#### Implementation tasks:
- [ ] Create `lib/deepseek_client.rb` following `GrokClient` pattern
- [ ] Add `use_deepseek?` detection to `ModelRouter` (model starts with `deepseek`)
- [ ] Add `list_deepseek_models` to `ModelAggregator`
- [ ] Add env vars: `DEEPSEEK_API_KEY`, `DEEPSEEK_MODELS`, `DEEPSEEK_TIMEOUT`
- [ ] Update `deploy.sh` `.env.production` template
- [ ] Add specs per existing PRD
- [ ] Add to README.md

---

## Priority 5 — 70B Ollama Tool Calling

### Investigation: 70B models fail T05 (Power Tools)
- **Affected:** `llama3-groq-tool-use:70b`, `llama3.1:70b`
- **Symptom:** Models return text responses instead of function calls when tools are provided
- **Notes:** This is a model behavior issue, not a SmartProxy bug. The 8B model (`llama3.1:8b`) and `qwen3-coder-next:latest` handle tool calling correctly.
- [ ] Investigate if Ollama needs specific prompt formatting for 70B tool calling
- [ ] Test with newer Ollama models (e.g., `llama3.3:70b`) that may have better tool support
- [ ] Consider adding tool-calling prompt hints in SmartProxy for Ollama models

---

## Compatibility Test Results (2026-03-02, pre-update baseline)

```
Model                                T01 T02 T03 T04 T05 T06 T07 T08 T09 T10 T11 T12  Score
─────────────────────────────────────────────────────────────────────────────────────────
qwen3-coder-next:latest              ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
llama3.1:8b                          ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
grok-4                               ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
grok-4-latest                        ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
grok-4-with-live-search              ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
claude-sonnet-4-5-*-with-live-search ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
claude-sonnet-4-*-with-live-search   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12
claude-3-haiku-*-with-live-search    ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   ✓   12/12

8/15 models fully compatible
```

**Test legend:**
T01=CoreTypes T02=ToolDSL T03=Hooks T04=Profile T05=PowerTools T06=Templates
T07=Runner T08=ModelMgr T09=MsgBus T10=History T11=ErrorHandling T12=Shutdown
