# Epic 5 — Unified Live Model Discovery + OpenRouter Integration

**Status**: Ready for Implementation  
**Created**: 2026-03-07  
**Owner**: Engineering  

---

## 1. Problem Statement

SmartProxy's `/v1/models` endpoint currently returns a **static, manually-maintained list** of models per provider, driven entirely by `ENV['PROVIDER_MODELS']` CSV strings baked into `ModelAggregator`. This creates three compounding problems:

1. **Stale lists** — When providers release or retire models, SmartProxy is blind until someone manually updates a `.env` file.
2. **Inconsistent filtering** — Each provider list method is its own island; there is no shared, principled way to filter, blacklist, or cap the model space. The `with-live-search` synthetic variant is hardcoded inside `list_claude_models`.
3. **No path to OpenRouter** — OpenRouter exposes 500+ models from dozens of sub-providers. A static whitelist approach simply does not scale; live fetch with intelligent filtering is the only viable option.

---

## 2. Vision

Every provider in SmartProxy fetches its model list **live from the upstream API**, and every list passes through a **single shared `ModelFilter` pipeline** — regex blacklist, regex include override, capability guards (`tools`, text output), and synthetic variant decoration. The result is a model catalogue that is always fresh, easily tunable via ENV, and extensible to any new provider without new bespoke filtering code.

---

## 3. Goals & Success Criteria

| # | Goal | Measurable Condition |
|---|------|----------------------|
| G1 | All providers fetch models live | `GET /v1/models` returns models sourced from upstream APIs, not ENV CSV strings |
| G2 | Shared filter pipeline | A single `ModelFilter` class processes all provider lists; no per-provider filtering logic exists outside it |
| G3 | OpenRouter integrated | Models from OpenRouter appear in `/v1/models`; requests with OpenRouter model IDs are proxied correctly |
| G4 | Graceful degradation | If a live fetch fails, the system falls back to a last-known-good cache (or empty list) without crashing |
| G5 | ENV backward compatibility | Existing `PROVIDER_MODELS` ENV vars continue to work as "static override" mode |
| G6 | Test coverage | All new classes have RSpec unit tests; VCR cassettes cover live fetch paths |

---

## 4. Non-Goals

- Streaming model metadata updates (WebSocket / push)
- Per-user model access control
- Price or latency ranking of models
- Automatic provider health checks (covered in a separate epic)

---

## 5. Architecture Overview

```
GET /v1/models
      │
      ▼
ModelAggregator#list_models
      │
      ├── GrokClient#list_models          ──► xAI  /v1/models
      ├── ClaudeClient#list_models        ──► Anthropic /v1/models
      ├── DeepSeekClient#list_models      ──► DeepSeek /models
      ├── FireworksClient#list_models     ──► Fireworks /v1/models
      ├── OllamaClient#list_models        ──► Ollama /api/tags  (already live)
      └── OpenRouterClient#list_models    ──► OpenRouter /api/v1/models  (NEW)
              │
              ▼ (each provider list)
         ModelFilter#apply(models, provider:)
              │
              ├── 1. Require text output  (discard non-text models)
              ├── 2. Require tools        (optional — MODELS_REQUIRE_TOOLS=true)
              ├── 3. Blacklist regex      (MODELS_BLACKLIST / OPENROUTER_MODELS_BLACKLIST)
              ├── 4. Include override     (MODELS_INCLUDE / OPENROUTER_MODELS_INCLUDE)
              └── 5. Synthetic decoration (-with-live-search variants)
```

**Cache layer**: `ModelAggregator` continues to cache the final merged payload with a configurable TTL (`MODELS_CACHE_TTL`, default 60 s). Per-provider fetches are synchronous within the cache miss path; failures return `[]` and are logged.

---

## 6. Constituent PRDs

| PRD | Title | File |
|-----|-------|------|
| PRD-5.1 | `ModelFilter` — Shared Regex Filter Pipeline | `prd-5-1-model-filter.md` |
| PRD-5.2 | `ModelAggregator` Refactor — Live Orchestration | `prd-5-2-model-aggregator-refactor.md` |
| PRD-5.3 | Provider `list_models` Methods | `prd-5-3-provider-list-models.md` |
| PRD-5.4 | OpenRouter Provider Integration | `prd-5-4-openrouter-provider.md` |
| PRD-5.5 | ENV Schema & Migration Guide | `prd-5-5-env-schema-migration.md` |

---

## 7. Recommended Implementation Order

```
PRD-5.1  →  PRD-5.3  →  PRD-5.2  →  PRD-5.4  →  PRD-5.5
(filter)    (clients)   (aggregator) (openrouter)  (env docs)
```

PRD-5.1 first because every other PRD depends on `ModelFilter` existing. PRD-5.5 last because it documents the final ENV surface.

---

## 8. Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Upstream `/models` endpoint unavailable | Medium | Return cached data; log warning; never return 500 to client |
| OpenRouter 500+ models overwhelms clients | Low | Blacklist by default; require tools flag further narrows list |
| Breaking change to `/v1/models` response shape | Low | Keep existing `id`, `object`, `owned_by`, `created` fields; additions only |
| ENV migration confusion | Medium | PRD-5.5 documents old → new mapping; backward compat maintained for one full version |

---

## 9. Dependencies

- No new gems required (Faraday already in use)
- OpenRouter API key (`OPENROUTER_API_KEY`) required at runtime for OpenRouter models
- All other providers: existing API keys, no new requirements
