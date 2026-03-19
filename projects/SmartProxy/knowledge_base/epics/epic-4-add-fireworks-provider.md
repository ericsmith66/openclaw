# 📄 PRD: Add Fireworks AI Provider to SmartProxy

**Status**: Ready for Implementation
**Created**: 2026-03-02
**Epic**: 4 — Fireworks AI Provider Integration

---

## 1. Executive Summary

Add Fireworks AI as a new LLM provider in SmartProxy. Fireworks AI exposes an OpenAI-compatible REST API, so the integration follows the exact same pattern as `GrokClient` — a thin Faraday wrapper with no request/response transformation required.

Fireworks AI provides fast inference for popular open-source models (Llama 4, Qwen 3, DeepSeek) as an alternative to running them locally via Ollama.

---

## 2. Provider Details

| Property        | Value                                        |
|-----------------|----------------------------------------------|
| API Base URL    | `https://api.fireworks.ai/inference/v1`      |
| Auth            | Bearer token via `FIREWORKS_API_KEY`         |
| API Format      | OpenAI-compatible                            |
| Tool Calling    | Supported                                    |
| Streaming       | Supported (SSE)                              |

### 2.1 Models

Fireworks model IDs use a namespaced path format: `accounts/fireworks/models/<name>`.

| Model ID                                               | Description                    |
|--------------------------------------------------------|--------------------------------|
| `accounts/fireworks/models/llama-v3p3-70b-instruct`   | Llama 3.3 70B                  |
| `accounts/fireworks/models/llama4-maverick-instruct-basic` | Llama 4 Maverick           |
| `accounts/fireworks/models/qwen3-235b-a22b`           | Qwen 3 235B MoE                |
| `accounts/fireworks/models/deepseek-v3-0324`          | DeepSeek V3 (via Fireworks)    |
| `accounts/fireworks/models/deepseek-r1`               | DeepSeek R1 (via Fireworks)    |

---

## 3. Implementation Requirements

### 3.1 `lib/fireworks_client.rb`
- Mirror `GrokClient` exactly.
- `BASE_URL = 'https://api.fireworks.ai/inference/v1'`
- `chat_completions(payload)` — single public method, POST to `chat/completions`.
- Faraday connection with retry (max 3, statuses: 429, 500–504).
- Timeout via `ENV.fetch('FIREWORKS_TIMEOUT', '120').to_i`.
- `open_timeout: 10`.
- `handle_error` returning `OpenStruct.new(status:, body:)` on `Faraday::Error`.

### 3.2 `lib/model_router.rb`
- `require_relative 'fireworks_client'` at top.
- Add `use_fireworks?` — true when `@upstream_model.start_with?('accounts/fireworks/')` and `fireworks_api_key` present.
- Add `:fireworks` to `provider` method — evaluated before `:ollama` fallback.
- Add `FireworksClient.new(api_key: fireworks_api_key)` to `client` switch.
- Add `fireworks_api_key` private method: `ENV['FIREWORKS_API_KEY']`.
- Expose `use_fireworks:` in the `route` hash.

### 3.3 `lib/model_aggregator.rb`
- Add `list_fireworks_models` private method.
- Guard: return `[]` if `ENV['FIREWORKS_API_KEY'].to_s.empty?`.
- Parse `ENV.fetch('FIREWORKS_MODELS', 'accounts/fireworks/models/llama-v3p3-70b-instruct,accounts/fireworks/models/llama4-maverick-instruct-basic,accounts/fireworks/models/qwen3-235b-a22b,accounts/fireworks/models/deepseek-v3-0324,accounts/fireworks/models/deepseek-r1')`.
- Each entry: `{ id:, object: 'model', owned_by: 'fireworks', created: Time.now.to_i, smart_proxy: { provider: 'fireworks' } }`.
- Call `list_fireworks_models` inside `list_models` alongside existing providers.

### 3.4 Environment Variables

| Variable             | Required | Default                                               |
|----------------------|----------|-------------------------------------------------------|
| `FIREWORKS_API_KEY`  | Yes      | —                                                     |
| `FIREWORKS_MODELS`   | No       | comma-separated list of 5 models above                |
| `FIREWORKS_TIMEOUT`  | No       | `120`                                                 |

- Add all three to `.env.example`.
- Add to `deploy.sh` `.env.production` template.

---

## 4. Testing Requirements

### 4.1 `spec/lib/fireworks_client_spec.rb` (new file)
- Successful `chat_completions` call returns Faraday response.
- `Faraday::Error` is caught and returns `OpenStruct` with status and body.
- Uses VCR cassette for the happy-path call.

### 4.2 `spec/lib/model_router_spec.rb` (update)
- Routes to `:fireworks` when model starts with `accounts/fireworks/` and `FIREWORKS_API_KEY` is set.
- Falls through to `:ollama` when `FIREWORKS_API_KEY` is absent.

### 4.3 `spec/lib/model_aggregator_spec.rb` (update)
- Returns Fireworks models when `FIREWORKS_API_KEY` is present.
- Returns empty array when `FIREWORKS_API_KEY` is absent.

---

## 5. Documentation

- `README.md` — add Fireworks AI to the providers table with required env vars and a note about the `accounts/fireworks/models/` model ID prefix.

---

## 6. Success Criteria

- [ ] `GET /v1/models` includes Fireworks models when `FIREWORKS_API_KEY` is set.
- [ ] `POST /v1/chat/completions` with `model: accounts/fireworks/models/llama4-maverick-instruct-basic` is proxied to Fireworks and returns a valid OpenAI-format response.
- [ ] Streaming (`stream: true`) passes through correctly.
- [ ] Tool calls pass through without transformation.
- [ ] `FIREWORKS_API_KEY` absent → Fireworks models silently omitted, no errors.
- [ ] All existing tests pass.
- [ ] `bin/model_compatibility_test` passes all 12 tests for at least one Fireworks model.
