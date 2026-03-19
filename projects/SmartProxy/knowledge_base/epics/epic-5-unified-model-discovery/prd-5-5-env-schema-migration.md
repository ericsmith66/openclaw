# PRD 5.5 — ENV Schema & Migration Guide

**Status**: Ready for Implementation  
**Epic**: 5 — Unified Live Model Discovery  
**Depends on**: PRD-5.1, PRD-5.2, PRD-5.3, PRD-5.4 (documents the final ENV surface)  
**Required by**: nothing (documentation artifact)  

---

## 1. Summary

This PRD defines the complete ENV variable schema for Epic 5, documents the migration path from the current static-list approach, and specifies which existing variables are deprecated, preserved, or replaced.

---

## 2. Migration: Old vs New

### 2.1 Static Model List Variables → Live Fetch with ENV Fallback

These variables previously **drove** the model list. They now act as **fallback only** if the live endpoint returns an empty response. No immediate action required — they continue to work.

| Old Variable | Status | New Behaviour |
|---|---|---|
| `GROK_MODELS` | ⚠️ Deprecated (still works) | Fallback if live `/v1/models` returns empty |
| `CLAUDE_MODELS` | ⚠️ Deprecated (still works) | Fallback if live `/v1/models` returns empty |
| `DEEPSEEK_MODELS` | ⚠️ Deprecated (still works) | Fallback if live `/models` returns empty |
| `FIREWORKS_MODELS` | ⚠️ Deprecated (still works) | Fallback if live `/v1/models` returns empty |

**Deprecation timeline**: Remove in Epic 6 or after 60 days, whichever is later. Log a deprecation warning at startup if these are set.

### 2.2 Synthetic Variant Behaviour Change

`list_claude_models` previously hardcoded `-with-live-search` variants per Claude model. This is now controlled by `ModelFilter` via `WITH_LIVE_SEARCH_MODELS`.

| Old Behaviour | New Behaviour |
|---|---|
| Always added `-with-live-search` for every Claude model | `WITH_LIVE_SEARCH_MODELS=^claude-` (default) produces identical output |
| Hardcoded `features: ['live-search', 'tools']` in Claude models only | Any model matching `WITH_LIVE_SEARCH_MODELS` gets a variant |

**Migration action**: No action needed. Default value preserves existing behaviour.

---

## 3. Complete ENV Reference (Post-Epic 5)

### 3.1 Global Filter Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MODELS_BLACKLIST` | _(empty)_ | Comma-separated regex patterns — applied to ALL provider model lists |
| `MODELS_INCLUDE` | _(empty)_ | Comma-separated regex patterns — force-include even if blacklisted |
| `MODELS_REQUIRE_TOOLS` | `false` | If `true`, remove models that don't declare `tools` support |
| `WITH_LIVE_SEARCH_MODELS` | `^claude-` | Regex matching models that get a `-with-live-search` synthetic variant |
| `MODELS_CACHE_TTL` | `60` | Cache TTL in seconds for the aggregated model list |

### 3.2 Grok (xAI)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GROK_API_KEY` | Yes* | — | API key (*or `GROK_API_KEY_SAP`) |
| `GROK_API_KEY_SAP` | Yes* | — | Alternative key (takes precedence) |
| `GROK_TIMEOUT` | No | `120` | Request timeout in seconds |
| `GROK_MODELS` | No | _(see below)_ | ⚠️ Deprecated: fallback CSV only |
| `GROK_MODELS_BLACKLIST` | No | _(empty)_ | Per-provider blacklist (additive to global) |
| `GROK_MODELS_INCLUDE` | No | _(empty)_ | Per-provider include override |

*Default `GROK_MODELS` fallback value: `grok-4-1-fast-reasoning,grok-4-1-fast-non-reasoning,grok-code-fast-1,grok-4,grok-4-latest,grok-3,grok-3-mini`

### 3.3 Claude (Anthropic)

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CLAUDE_API_KEY` | Yes | — | API key |
| `CLAUDE_TIMEOUT` | No | `120` | Request timeout in seconds |
| `CLAUDE_MODELS` | No | _(see below)_ | ⚠️ Deprecated: fallback CSV only |
| `CLAUDE_MODELS_BLACKLIST` | No | _(empty)_ | Per-provider blacklist |
| `CLAUDE_MODELS_INCLUDE` | No | _(empty)_ | Per-provider include override |

*Default `CLAUDE_MODELS` fallback value: `claude-opus-4-6,claude-sonnet-4-6,claude-haiku-4-5-20251001,claude-sonnet-4-5-20250929,claude-sonnet-4-20250514`

### 3.4 DeepSeek

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DEEPSEEK_API_KEY` | Yes | — | API key |
| `DEEPSEEK_TIMEOUT` | No | `120` | Request timeout in seconds |
| `DEEPSEEK_MODELS` | No | _(see below)_ | ⚠️ Deprecated: fallback CSV only |
| `DEEPSEEK_MODELS_BLACKLIST` | No | _(empty)_ | Per-provider blacklist |
| `DEEPSEEK_MODELS_INCLUDE` | No | _(empty)_ | Per-provider include override |

*Default `DEEPSEEK_MODELS` fallback value: `deepseek-chat,deepseek-reasoner`

### 3.5 Fireworks AI

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `FIREWORKS_API_KEY` | Yes | — | API key |
| `FIREWORKS_TIMEOUT` | No | `120` | Request timeout in seconds |
| `FIREWORKS_MODELS` | No | _(see below)_ | ⚠️ Deprecated: fallback CSV only |
| `FIREWORKS_MODELS_BLACKLIST` | No | `\-old$,\-deprecated` | Recommended default to exclude archived models |
| `FIREWORKS_MODELS_INCLUDE` | No | _(empty)_ | Per-provider include override |

*Default `FIREWORKS_MODELS` fallback value: existing 5-model CSV

### 3.6 OpenRouter *(new)*

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENROUTER_API_KEY` | Yes | — | API key from openrouter.ai |
| `OPENROUTER_TIMEOUT` | No | `120` | Request timeout in seconds |
| `OPENROUTER_MODELS` | No | _(empty)_ | Fallback CSV if live fetch fails |
| `OPENROUTER_MODELS_BLACKLIST` | No | `free$` | Exclude free-tier variants by default |
| `OPENROUTER_MODELS_INCLUDE` | No | _(empty)_ | Force-include specific models |
| `OPENROUTER_ROUTE_MODELS` | No | _(empty)_ | Regex to force-route model IDs to OpenRouter |
| `OPENROUTER_REFERER` | No | `https://smartproxy.local` | `HTTP-Referer` header for OpenRouter attribution |
| `OPENROUTER_TITLE` | No | `SmartProxy` | `X-Title` header for OpenRouter attribution |

### 3.7 Ollama

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OLLAMA_HOST` | No | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_TIMEOUT` | No | `600` | Request timeout (long for local generation) |

*No filtering ENV for Ollama — local models are always curated by the user.*

---

## 4. Recommended `.env.example` Additions

```bash
# ───────────────────────────────────────────────
# Global Model Filters (apply to all providers)
# ───────────────────────────────────────────────

# Comma-separated regex patterns to exclude models globally
# MODELS_BLACKLIST=

# Comma-separated regex patterns to force-include (even if blacklisted)
# MODELS_INCLUDE=

# Set to true to only show models that support tool/function calling
# MODELS_REQUIRE_TOOLS=false

# Regex: models matching this pattern get a -with-live-search synthetic variant
WITH_LIVE_SEARCH_MODELS=^claude-

# Cache TTL for aggregated model list (seconds)
MODELS_CACHE_TTL=60

# ───────────────────────────────────────────────
# OpenRouter
# ───────────────────────────────────────────────
# OPENROUTER_API_KEY=
# OPENROUTER_TIMEOUT=120
# OPENROUTER_MODELS_BLACKLIST=free$
# OPENROUTER_MODELS_INCLUDE=
# OPENROUTER_REFERER=https://smartproxy.local
# OPENROUTER_TITLE=SmartProxy

# ───────────────────────────────────────────────
# Per-Provider Filter Overrides
# ───────────────────────────────────────────────
# GROK_MODELS_BLACKLIST=
# CLAUDE_MODELS_BLACKLIST=
# DEEPSEEK_MODELS_BLACKLIST=
# FIREWORKS_MODELS_BLACKLIST=
```

---

## 5. Startup Deprecation Warnings

In `app.rb` or an initializer, add:

```ruby
DEPRECATED_STATIC_MODEL_VARS = %w[
  GROK_MODELS CLAUDE_MODELS DEEPSEEK_MODELS FIREWORKS_MODELS
].freeze

DEPRECATED_STATIC_MODEL_VARS.each do |var|
  if ENV[var].to_s.present?
    Rails.logger.warn({
      event:   'deprecated_env_var',
      var:     var,
      message: "#{var} is deprecated. Models are now fetched live. This variable acts as a fallback only and will be removed in a future version."
    })
  end
end
```

---

## 6. Testing Requirements

### `spec/lib/model_filter_spec.rb` (PRD-5.1 tests also validate ENV resolution)

### `spec/integration/env_compatibility_spec.rb` (new file)

| Test | Description |
|------|-------------|
| T1 | `GROK_MODELS` CSV is used as fallback when live fetch returns `[]` |
| T2 | `MODELS_BLACKLIST` applies to Grok provider response |
| T3 | `MODELS_BLACKLIST` applies to OpenRouter provider response |
| T4 | `OPENROUTER_MODELS_BLACKLIST` applies only to OpenRouter |
| T5 | `MODELS_REQUIRE_TOOLS=true` filters models without tools support |
| T6 | `WITH_LIVE_SEARCH_MODELS` empty string disables synthetic variants |

---

## 7. Acceptance Criteria

- [ ] `.env.example` updated with all new variables, grouped and commented
- [ ] Deprecated variables still work (no 500 errors, no missing models if live fails)
- [ ] Startup deprecation warnings logged when old static-list vars are set
- [ ] All ENV variables documented in `README.md` providers table
- [ ] All integration tests pass
