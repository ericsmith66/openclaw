# PRD 5.2 — `ModelAggregator` Refactor: Live Orchestration

**Status**: Ready for Implementation  
**Epic**: 5 — Unified Live Model Discovery  
**Depends on**: PRD-5.1 (`ModelFilter`), PRD-5.3 (provider `list_models` methods)  
**Required by**: nothing (end of chain)  

---

## 1. Summary

Refactor `lib/model_aggregator.rb` to become a pure **orchestrator**: it calls `#list_models` on each provider client, passes each result through `ModelFilter`, merges everything, and caches. All static ENV CSV parsing is removed from this class.

---

## 2. Current vs. Target State

### Current (static, per-provider logic)
```ruby
def list_grok_models
  grok_models_str = ENV.fetch('GROK_MODELS', 'grok-4-1-fast-reasoning,...')
  grok_models_str.split(',').map(&:strip).map { |m_id| { id: m_id, ... } }
end
# Repeated 4× for grok, claude, deepseek, fireworks
# Ollama: only live provider
```

### Target (thin orchestrator)
```ruby
def list_models
  # cache check unchanged
  
  models = []
  PROVIDERS.each do |provider_sym, client_factory|
    client  = client_factory.call
    next if client.nil?  # key absent
    
    raw     = client.list_models   # live fetch, returns []  on failure
    filter  = ModelFilter.new(provider: provider_sym)
    models += filter.apply(raw)
  end
  
  payload   = { object: 'list', data: models }
  new_cache = { fetched_at: Time.now, data: payload }
  { payload: payload, cache: new_cache }
end
```

---

## 3. Implementation Details

### 3.1 Provider Registry

Define a `PROVIDERS` constant (ordered hash, preserving display order):

```ruby
PROVIDERS = {
  grok:        -> { GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])      if (ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY']).to_s.present? },
  claude:      -> { ClaudeClient.new(api_key: ENV['CLAUDE_API_KEY'])                              if ENV['CLAUDE_API_KEY'].to_s.present? },
  deepseek:    -> { DeepSeekClient.new(api_key: ENV['DEEPSEEK_API_KEY'])                          if ENV['DEEPSEEK_API_KEY'].to_s.present? },
  fireworks:   -> { FireworksClient.new(api_key: ENV['FIREWORKS_API_KEY'])                        if ENV['FIREWORKS_API_KEY'].to_s.present? },
  openrouter:  -> { OpenRouterClient.new(api_key: ENV['OPENROUTER_API_KEY'])                      if ENV['OPENROUTER_API_KEY'].to_s.present? },
  ollama:      -> { OllamaClient.new }  # always available (local, no key)
}.freeze
```

Each lambda returns `nil` if the required API key is absent. `ModelAggregator` skips `nil` clients.

### 3.2 Error Handling per Provider

Wrap each provider fetch in its own rescue block so one failing provider doesn't kill the entire list:

```ruby
PROVIDERS.each do |provider_sym, client_factory|
  begin
    client = client_factory.call
    next if client.nil?
    
    raw    = client.list_models
    filter = ModelFilter.new(provider: provider_sym)
    models += filter.apply(raw)
  rescue StandardError => e
    @logger&.warn({
      event:      'provider_models_fetch_error',
      provider:   provider_sym,
      session_id: @session_id,
      error:      e.message
    })
  end
end
```

### 3.3 Cache Unchanged

The existing cache mechanism (`@cache[:data]`, `@cache_ttl`, `MODELS_CACHE_TTL` ENV) is preserved as-is. No behaviour change.

### 3.4 Requires

```ruby
require_relative 'model_filter'
require_relative 'grok_client'
require_relative 'claude_client'
require_relative 'deepseek_client'
require_relative 'fireworks_client'
require_relative 'openrouter_client'
require_relative 'ollama_client'
```

---

## 4. Removed Code

The following private methods are **deleted** entirely from `model_aggregator.rb`:

- `list_grok_models`
- `list_claude_models` (including the `-with-live-search` decoration loop)
- `list_deepseek_models`
- `list_fireworks_models`
- `fetch_ollama_models` (replaced by `OllamaClient#list_models`)

---

## 5. Testing Requirements

### `spec/lib/model_aggregator_spec.rb` (update)

| Test | Description |
|------|-------------|
| T1 | Returns merged models from all providers whose API keys are set |
| T2 | Provider with missing API key is silently skipped |
| T3 | Provider fetch that raises `StandardError` is caught; other providers still included |
| T4 | Result is cached; second call within TTL does not call provider clients again |
| T5 | Cache is invalidated after TTL; fresh fetch is triggered |
| T6 | `ModelFilter` is called once per provider with correct `provider:` symbol |
| T7 | OpenRouter models appear in list when `OPENROUTER_API_KEY` is set |
| T8 | Ollama models always included (no key guard) |

All provider clients should be stubbed in unit tests (no real HTTP calls); use instance_double or allow/receive.

---

## 6. Acceptance Criteria

- [ ] `GET /v1/models` response includes models from every provider with a valid API key
- [ ] No static CSV model lists remain in `model_aggregator.rb`
- [ ] One failing provider does not affect other providers in the response
- [ ] Cache TTL is configurable via `MODELS_CACHE_TTL` ENV (seconds, default 60)
- [ ] All existing aggregator tests updated and passing
- [ ] All 8 new tests passing
