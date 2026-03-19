# 📄 PRD: Add DeepSeek Provider to SmartProxy

**Status**: Ready for Implementation
**Created**: 2026-03-02
**Epic**: 3 — DeepSeek Provider Integration

---

## 1. Executive Summary

Add DeepSeek as a new LLM provider in SmartProxy. DeepSeek exposes an OpenAI-compatible REST API, so the integration follows the exact same pattern as `GrokClient` — a thin Faraday wrapper with no request/response transformation required.

---

## 2. Provider Details

| Property        | Value                              |
|-----------------|------------------------------------|
| API Base URL    | `https://api.deepseek.com/v1`      |
| Auth            | Bearer token via `DEEPSEEK_API_KEY` |
| API Format      | OpenAI-compatible                  |
| Tool Calling    | Supported                          |
| Streaming       | Supported (SSE)                    |

### 2.1 Models

| Model ID              | Description                         |
|-----------------------|-------------------------------------|
| `deepseek-chat`       | DeepSeek V3 — general purpose       |
| `deepseek-reasoner`   | DeepSeek R1 — chain-of-thought reasoning |

---

## 3. Implementation Requirements

### 3.1 `lib/deepseek_client.rb`
- Mirror `GrokClient` exactly.
- `BASE_URL = 'https://api.deepseek.com/v1'`
- `chat_completions(payload)` — single public method, POST to `chat/completions`.
- Faraday connection with retry (max 3, statuses: 429, 500–504).
- Timeout via `ENV.fetch('DEEPSEEK_TIMEOUT', '120').to_i`.
- `open_timeout: 10`.
- `handle_error` returning `OpenStruct.new(status:, body:)` on `Faraday::Error`.

### 3.2 `lib/model_router.rb`
- `require_relative 'deepseek_client'` at top.
- Add `use_deepseek?` — true when `@upstream_model.start_with?('deepseek')` and `deepseek_api_key` present.
- Add `:deepseek` to `provider` method — evaluated before `:ollama` fallback.
- Add `DeepSeekClient.new(api_key: deepseek_api_key)` to `client` switch.
- Add `deepseek_api_key` private method: `ENV['DEEPSEEK_API_KEY']`.
- Expose `use_deepseek:` in the `route` hash.

### 3.3 `lib/model_aggregator.rb`
- Add `list_deepseek_models` private method.
- Guard: return `[]` if `ENV['DEEPSEEK_API_KEY'].to_s.empty?`.
- Parse `ENV.fetch('DEEPSEEK_MODELS', 'deepseek-chat,deepseek-reasoner')`.
- Each entry: `{ id:, object: 'model', owned_by: 'deepseek', created: Time.now.to_i, smart_proxy: { provider: 'deepseek' } }`.
- Call `list_deepseek_models` inside `list_models` alongside existing providers.

### 3.4 Environment Variables

| Variable           | Required | Default                              |
|--------------------|----------|--------------------------------------|
| `DEEPSEEK_API_KEY` | Yes      | —                                    |
| `DEEPSEEK_MODELS`  | No       | `deepseek-chat,deepseek-reasoner`    |
| `DEEPSEEK_TIMEOUT` | No       | `120`                                |

- Add all three to `.env.example`.
- Add to `deploy.sh` `.env.production` template.

---

## 4. Testing Requirements

### 4.1 `spec/lib/deepseek_client_spec.rb` (new file)
- Successful `chat_completions` call returns Faraday response.
- `Faraday::Error` is caught and returns `OpenStruct` with status and body.
- Uses VCR cassette for the happy-path call.

### 4.2 `spec/lib/model_router_spec.rb` (update)
- Routes to `:deepseek` when model starts with `deepseek` and `DEEPSEEK_API_KEY` is set.
- Falls through to `:ollama` when `DEEPSEEK_API_KEY` is absent.

### 4.3 `spec/lib/model_aggregator_spec.rb` (update)
- Returns DeepSeek models when `DEEPSEEK_API_KEY` is present.
- Returns empty array when `DEEPSEEK_API_KEY` is absent.

---

## 5. Documentation

- `README.md` — add DeepSeek to the providers table with required env vars.

---

## 6. Success Criteria

- [ ] `GET /v1/models` includes DeepSeek models when `DEEPSEEK_API_KEY` is set.
- [ ] `POST /v1/chat/completions` with `model: deepseek-chat` is proxied to DeepSeek and returns a valid OpenAI-format response.
- [ ] Streaming (`stream: true`) passes through correctly.
- [ ] Tool calls pass through without transformation.
- [ ] `DEEPSEEK_API_KEY` absent → DeepSeek models silently omitted, no errors.
- [ ] All existing tests pass.
- [ ] `bin/model_compatibility_test` passes all 12 tests for `deepseek-chat`.
