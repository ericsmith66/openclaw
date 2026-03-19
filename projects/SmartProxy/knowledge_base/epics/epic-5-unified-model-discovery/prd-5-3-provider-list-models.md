# PRD 5.3 — Provider `list_models` Methods

**Status**: Ready for Implementation  
**Epic**: 5 — Unified Live Model Discovery  
**Depends on**: PRD-5.1 (`ModelFilter` — to understand output shape)  
**Required by**: PRD-5.2 (`ModelAggregator` refactor)  

---

## 1. Summary

Add a `#list_models` instance method to each existing provider client so that `ModelAggregator` can call a uniform interface. Each method hits the provider's live `/models` endpoint, normalises the response to OpenAI model-hash format, and returns `[]` on any failure.

**Note**: `OllamaClient` already supports this via `#list_models`. Its output shape must be verified against the common format but no structural changes are expected.

---

## 2. Common Output Format

Each `list_models` method must return `Array<Hash>` where every hash has **at minimum**:

```ruby
{
  id:         String,          # model ID as used in chat completions
  object:     'model',
  owned_by:   String,          # provider name e.g. 'xai', 'anthropic'
  created:    Integer,         # Unix timestamp (use Time.now.to_i if not provided)
  smart_proxy: {
    provider: String           # same as owned_by
    # optional additional keys per provider
  }
}
```

**Do not** include `modalities` or `supported_parameters` in the base implementation — these are optional fields used by `ModelFilter` steps 1 and 2. They will be naturally present in OpenRouter responses (PRD-5.4) and can be added to other providers in a future pass.

---

## 3. Provider-by-Provider Specification

### 3.1 `GrokClient#list_models`

| Property | Value |
|----------|-------|
| Endpoint | `GET https://api.x.ai/v1/models` |
| Auth | Bearer `GROK_API_KEY_SAP` or `GROK_API_KEY` |
| Response shape | `{ data: [ { id:, object:, created:, owned_by: } ] }` |

**Implementation**:
```ruby
def list_models
  response = @conn.get('/v1/models') do |req|
    req.headers['Authorization'] = "Bearer #{@api_key}"
  end
  body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
  (body['data'] || []).map do |m|
    {
      id:          m['id'],
      object:      'model',
      owned_by:    m['owned_by'] || 'xai',
      created:     m['created'] || Time.now.to_i,
      smart_proxy: { provider: 'xai' }
    }
  end
rescue StandardError => e
  @logger&.warn({ event: 'grok_list_models_error', error: e.message })
  []
end
```

**ENV fallback**: If `GROK_MODELS` is set **and** the live fetch returns an empty list, fall back to parsing the ENV CSV (backward compat). If live fetch succeeds with data, ENV is ignored.

```ruby
def list_models
  live = fetch_live_models
  return live unless live.empty?
  fallback_from_env
end
```

---

### 3.2 `ClaudeClient#list_models`

| Property | Value |
|----------|-------|
| Endpoint | `GET https://api.anthropic.com/v1/models` |
| Auth | Header `x-api-key: CLAUDE_API_KEY` + `anthropic-version: 2023-06-01` |
| Response shape | `{ data: [ { id:, display_name:, created_at: } ] }` |

**Note**: Anthropic's `/v1/models` does exist and returns available models for the account. The `created_at` field is ISO8601; convert with `Time.parse(...).to_i`.

```ruby
def list_models
  response = @conn.get('/v1/models') do |req|
    req.headers['x-api-key']          = @api_key
    req.headers['anthropic-version']  = '2023-06-01'
    req.headers['anthropic-beta']     = 'models-1.0'  # required for model listing
  end
  body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
  (body['data'] || []).map do |m|
    {
      id:          m['id'],
      object:      'model',
      owned_by:    'anthropic',
      created:     (Time.parse(m['created_at']).to_i rescue Time.now.to_i),
      smart_proxy: { provider: 'anthropic' }
    }
  end
rescue StandardError => e
  @logger&.warn({ event: 'claude_list_models_error', error: e.message })
  []
end
```

**Synthetic `-with-live-search` variants**: These are now handled by `ModelFilter` (step 5 — synthetic decoration) using `WITH_LIVE_SEARCH_MODELS=^claude-`. Remove the decoration loop from `ClaudeClient` entirely.

**ENV fallback**: Same pattern as Grok — if live returns empty, fall back to `CLAUDE_MODELS` CSV.

---

### 3.3 `DeepSeekClient#list_models`

| Property | Value |
|----------|-------|
| Endpoint | `GET https://api.deepseek.com/models` |
| Auth | Bearer `DEEPSEEK_API_KEY` |
| Response shape | `{ data: [ { id:, object:, owned_by: } ] }` (OpenAI-compatible) |

```ruby
def list_models
  response = @conn.get('/models') do |req|
    req.headers['Authorization'] = "Bearer #{@api_key}"
  end
  body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
  (body['data'] || []).map do |m|
    {
      id:          m['id'],
      object:      'model',
      owned_by:    m['owned_by'] || 'deepseek',
      created:     m['created'] || Time.now.to_i,
      smart_proxy: { provider: 'deepseek' }
    }
  end
rescue StandardError => e
  @logger&.warn({ event: 'deepseek_list_models_error', error: e.message })
  []
end
```

**ENV fallback**: Same pattern — `DEEPSEEK_MODELS` CSV as fallback.

---

### 3.4 `FireworksClient#list_models`

| Property | Value |
|----------|-------|
| Endpoint | `GET https://api.fireworks.ai/inference/v1/models` |
| Auth | Bearer `FIREWORKS_API_KEY` |
| Response shape | `{ data: [ { id:, object:, owned_by: } ] }` (OpenAI-compatible) |

**Important**: Fireworks returns hundreds of models. The `ModelFilter` blacklist should be used to scope this down. A reasonable default `FIREWORKS_MODELS_BLACKLIST` value is documented in PRD-5.5.

```ruby
def list_models
  response = @conn.get('/v1/models') do |req|
    req.headers['Authorization'] = "Bearer #{@api_key}"
  end
  body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
  (body['data'] || []).map do |m|
    {
      id:          m['id'],
      object:      'model',
      owned_by:    m['owned_by'] || 'fireworks',
      created:     m['created'] || Time.now.to_i,
      smart_proxy: { provider: 'fireworks' }
    }
  end
rescue StandardError => e
  @logger&.warn({ event: 'fireworks_list_models_error', error: e.message })
  []
end
```

**ENV fallback**: `FIREWORKS_MODELS` CSV as fallback.

---

### 3.5 `OllamaClient#list_models` (verify/align only)

Ollama already fetches live. Verify the return shape matches the common format above. If the existing `fetch_ollama_models` helper in `ModelAggregator` has normalisation logic not present in `OllamaClient#list_models`, move it there.

No new Ollama-specific ENV fallback needed (local models are always current).

---

## 4. ENV Fallback Helper (shared pattern)

To avoid duplicating fallback logic, extract a shared private helper into each client (or a shared module):

```ruby
def models_from_env(env_key, default, owned_by:)
  str = ENV.fetch(env_key, default)
  str.split(',').map(&:strip).reject(&:empty?).map do |m_id|
    {
      id:          m_id,
      object:      'model',
      owned_by:    owned_by,
      created:     Time.now.to_i,
      smart_proxy: { provider: owned_by }
    }
  end
end
```

---

## 5. Testing Requirements

For each provider client, add/update tests in `spec/lib/<provider>_client_spec.rb`:

| Test | Description |
|------|-------------|
| T1 | `list_models` returns normalised hash array on successful HTTP response (VCR cassette) |
| T2 | `list_models` returns `[]` on `Faraday::Error` |
| T3 | `list_models` returns `[]` on non-200 response |
| T4 | `list_models` falls back to `ENV` CSV when live returns empty array |
| T5 | Returned hashes contain required keys: `id`, `object`, `owned_by`, `created`, `smart_proxy` |

Claude additionally:

| Test | Description |
|------|-------------|
| T6 | `list_models` does NOT return `-with-live-search` variants (those come from `ModelFilter`) |

---

## 6. Acceptance Criteria

- [ ] All five provider clients implement `#list_models` returning `Array<Hash>`
- [ ] All returned hashes contain `id`, `object`, `owned_by`, `created`, `smart_proxy.provider`
- [ ] ENV CSV fallback works when live endpoint returns empty
- [ ] `-with-live-search` decoration is removed from `ClaudeClient` (moved to `ModelFilter`)
- [ ] All VCR cassettes created/updated
- [ ] All tests pass
