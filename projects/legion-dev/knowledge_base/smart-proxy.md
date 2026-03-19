# Smart Proxy Overview

> This document describes nextgen-plaid's **smart_proxy** server and its relationship to agent-forge.
> For agent-forge's adapter layer, see `lib/tool_adapter/`.

---

## What is smart_proxy?

**smart_proxy** is a lightweight **Sinatra-based reverse proxy server** (from the nextgen-plaid project) that sits in front of multiple LLM providers. Its primary job is to:

- Accept OpenAI-compatible API requests (same endpoint/format as OpenAI's `/v1/chat/completions`).
- Route them transparently to the configured backend LLM (Claude, Grok, Ollama, etc.).
- Handle model selection, authentication, rate limiting, logging, and fallback logic in one central place.
- Allow the client (AiderDesk, agent-forge, or any OpenAI-compatible tool) to use a **single endpoint** without knowing which LLM is behind it.

**Repo:** https://github.com/ericsmith66/nextgen-plaid/tree/main/smart_proxy

**Port:** `SMART_PROXY_PORT=3002` (default)

---

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/v1/chat/completions` | OpenAI-compatible chat completions |

---

## How it relates to agent-forge

### Naming distinction

- **nextgen-plaid's smart_proxy** — Sinatra server, reverse proxy for LLM routing (port 3002).
- **agent-forge's `ToolAdapter`** — Ruby client-side adapter layer (`lib/tool_adapter/`) that routes coding tasks to AiderDesk. Formerly named `SmartProxy`, renamed to avoid confusion.

### Current Architecture (v0.1)

```
agent-forge → ToolAdapter → AiderDesk REST API (port 24337) → Ollama (port 11434)
```

- `ToolAdapter::AiderDeskAdapter` sends coding prompts to AiderDesk.
- AiderDesk talks directly to Ollama for LLM inference.

### Future Architecture (v0.2+)

```
agent-forge → ToolAdapter → AiderDesk REST API (port 24337)
                                    ↓
                              smart_proxy (port 3002)
                                    ↓
                        Claude / Grok / Ollama
```

- AiderDesk configured to use **smart_proxy** as its LLM backend via OpenAI adapter.
- smart_proxy routes to the desired model (Claude for complex Rails, Ollama for lighter tasks).
- Benefit: Central LLM control — model selection, rate limits, fallbacks all in one place.

### Direct LLM calls (planning/review)

```
agent-forge → smart_proxy (port 3002) → Claude / Grok / Ollama
```

- For non-coding LLM calls (planning, review, summarization), agent-forge can call smart_proxy directly.
- Same OpenAI-compatible format, no AiderDesk involved.

---

## Configuration

Set via environment or config file in nextgen-plaid/smart_proxy:

| Variable | Example | Description |
|----------|---------|-------------|
| `SMART_PROXY_PORT` | `3002` | Server port |
| Model routing | `claude-3-5-sonnet` → Anthropic | Configured per model name |
| Model routing | `grok-beta` → xAI | Configured per model name |
| Model routing | `ollama/*` → localhost:11434 | Local Ollama models |

---

## Recommendation

- Keep nextgen-plaid's smart_proxy as a **standalone server** for LLM proxying.
- agent-forge uses `ToolAdapter` (`lib/tool_adapter/`) to call AiderDesk (REST) for coding tasks.
- Optionally route non-coding LLM calls through smart_proxy for centralized model management.
- Configure AiderDesk to use smart_proxy as its OpenAI backend when ready for centralized model selection.
