# PRD 5.4 — OpenRouter Provider Integration

**Status**: Ready for Implementation  
**Epic**: 5 — Unified Live Model Discovery  
**Depends on**: PRD-5.1 (`ModelFilter`), PRD-5.3 (provider interface pattern)  
**Required by**: PRD-5.2 (`ModelAggregator` registry)  

---

## 1. Summary

Add OpenRouter as a fully functional SmartProxy provider. OpenRouter is an OpenAI-compatible aggregator that proxies requests to 500+ models from dozens of upstream providers (Anthropic, Google, OpenAI, Mistral, DeepSeek, Meta, etc.). The integration requires:

1. `lib/openrouter_client.rb` — thin Faraday wrapper (chat completions + model listing)
2. `lib/model_router.rb` — routing logic for OpenRouter model IDs
3. `ModelAggregator` registry entry (covered by PRD-5.2)
4. ENV variable documentation (covered by PRD-5.5)

---

## 2. Provider Details

| Property | Value |
|----------|-------|
| API Base URL | `https://openrouter.ai/api/v1` |
| Auth | Bearer `OPENROUTER_API_KEY` |
| API Format | OpenAI-compatible |
| Tool Calling | Supported (model-dependent — use `ModelFilter` tools guard) |
| Streaming | Supported (SSE) |
| Models endpoint | `GET /models` |
| Chat endpoint | `POST /chat/completions` |

### 2.1 Model ID Format

OpenRouter uses slash-namespaced IDs: `<provider>/<model-slug>`. Examples:

| Model ID | Upstream Provider |
|----------|-------------------|
| `google/gemini-2.5-pro` | Google |
| `anthropic/claude-opus-4-5` | Anthropic |
| `openai/gpt-4o` | OpenAI |
| `mistralai/mistral-large` | Mistral |
| `deepseek/deepseek-r1` | DeepSeek |
| `meta-llama/llama-4-maverick` | Meta |
| `perplexity/sonar-pro` | Perplexity |
| `moonshotai/kimi-k2` | Moonshot |
| `x-ai/grok-3` | xAI (via OpenRouter) |

### 2.2 Recommended Default Filter

Out of 500+ models, a practical default working set using `ModelFilter`:

- **Blacklist** (`OPENROUTER_MODELS_BLACKLIST`): `free$` — removes free-tier/rate-limited variants
- **Tools requirement**: `MODELS_REQUIRE_TOOLS=true` in OpenRouter-heavy setups narrows to ~80 capable models
- **No global include needed** by default

---

## 3. `lib/openrouter_client.rb`

```ruby
require 'faraday'
require 'faraday/retry'
require 'json'

class OpenRouterClient
  BASE_URL = 'https://openrouter.ai/api/v1'

  def initialize(api_key:, logger: nil, session_id: nil)
    @api_key    = api_key
    @logger     = logger
    @session_id = session_id
    @conn       = build_connection
  end

  # --- Chat Completions (OpenAI-compatible) ---
  def chat_completions(payload)
    @conn.post('/chat/completions') do |req|
      req.headers['Authorization']  = "Bearer #{@api_key}"
      req.headers['Content-Type']   = 'application/json'
      req.headers['HTTP-Referer']   = ENV.fetch('OPENROUTER_REFERER', 'https://smartproxy.local')
      req.headers['X-Title']        = ENV.fetch('OPENROUTER_TITLE', 'SmartProxy')
      req.body = payload.is_a?(String) ? payload : JSON.generate(payload)
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  # --- Model Listing ---
  def list_models
    response = @conn.get('/models') do |req|
      req.headers['Authorization'] = "Bearer #{@api_key}"
    end
    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    (body['data'] || []).map { |m| normalise(m) }
  rescue StandardError => e
    @logger&.warn({ event: 'openrouter_list_models_error', session_id: @session_id, error: e.message })
    models_from_env_fallback
  end

  private

  def normalise(m)
    {
      id:          m['id'],
      object:      'model',
      owned_by:    'openrouter',
      created:     m['created'] || Time.now.to_i,
      smart_proxy: {
        provider:              'openrouter',
        upstream_provider:     m['id'].to_s.split('/').first,
        context_length:        m.dig('context_length'),
        supported_parameters:  m.dig('supported_parameters') || [],
        modalities:            extract_modalities(m)
      }.compact
    }
  end

  def extract_modalities(m)
    # OpenRouter returns architecture.modalities or top-level modalities
    m.dig('architecture', 'modalities') || m['modalities'] || ['text']
  end

  def models_from_env_fallback
    str = ENV.fetch('OPENROUTER_MODELS', '')
    return [] if str.empty?
    str.split(',').map(&:strip).reject(&:empty?).map do |m_id|
      {
        id:          m_id,
        object:      'model',
        owned_by:    'openrouter',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'openrouter' }
      }
    end
  end

  def handle_error(err)
    @logger&.error({ event: 'openrouter_request_error', session_id: @session_id, error: err.message })
    OpenStruct.new(status: 502, body: { error: err.message }.to_json)
  end

  def build_connection
    Faraday.new(url: BASE_URL) do |f|
      f.request  :retry, max: 3, interval: 0.5, backoff_factor: 2,
                         retry_statuses: [429, 500, 502, 503, 504]
      f.options.timeout      = ENV.fetch('OPENROUTER_TIMEOUT', '120').to_i
      f.options.open_timeout = 10
      f.adapter Faraday.default_adapter
    end
  end
end
```

### 3.1 `HTTP-Referer` and `X-Title` Headers

OpenRouter requires or strongly recommends these headers for attribution. Both are configurable via ENV with sensible defaults.

---

## 4. `lib/model_router.rb` Changes

### 4.1 Routing Strategy

OpenRouter model IDs use `provider/model` format. This **overlaps** with existing providers:
- `deepseek/*` — could be DeepSeek direct OR OpenRouter
- `x-ai/*` — could be Grok direct OR OpenRouter

**Resolution**: OpenRouter routing uses **explicit opt-in** via `OPENROUTER_MODELS` ENV (force-route) OR by checking if the model ID contains a `/` and the prefix does not match any direct provider's routing rules.

The recommended approach:

```ruby
def use_openrouter?
  return false if openrouter_api_key.to_s.empty?
  
  # Explicit: model starts with a slash-namespaced prefix not claimed by any direct provider
  return true if @upstream_model.include?('/') && !claimed_by_direct_provider?
  
  # Explicit: model ID matches OPENROUTER_ROUTE_MODELS regex pattern
  route_pattern = ENV['OPENROUTER_ROUTE_MODELS']
  return true if route_pattern && Regexp.new(route_pattern).match?(@upstream_model)
  
  false
end

def claimed_by_direct_provider?
  use_grok? || use_claude? || use_deepseek? || use_fireworks?
end
```

**Routing priority** (ordered):
1. Grok (starts with `grok`)
2. Claude (starts with `claude`)
3. DeepSeek (starts with `deepseek`)
4. Fireworks (starts with `accounts/fireworks/`)
5. **OpenRouter** (contains `/` and not claimed above)
6. Ollama (fallback)

### 4.2 Code Changes

```ruby
# add to requires
require_relative 'openrouter_client'

# add to provider method
def provider
  if use_grok?          then :grok
  elsif use_claude?     then :claude
  elsif use_deepseek?   then :deepseek
  elsif use_fireworks?  then :fireworks
  elsif use_openrouter? then :openrouter
  else                       :ollama
  end
end

# add to client method
when :openrouter
  OpenRouterClient.new(api_key: openrouter_api_key, logger: @logger)

# add private methods
def use_openrouter?
  return false if openrouter_api_key.to_s.empty?
  @upstream_model.include?('/') && !claimed_by_direct_provider?
end

def claimed_by_direct_provider?
  use_grok? || use_claude? || use_deepseek? || use_fireworks?
end

def openrouter_api_key
  ENV['OPENROUTER_API_KEY']
end
```

---

## 5. ENV Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENROUTER_API_KEY` | Yes | — | API key from openrouter.ai |
| `OPENROUTER_TIMEOUT` | No | `120` | Request timeout in seconds |
| `OPENROUTER_MODELS` | No | _(empty)_ | Fallback CSV of model IDs if live fetch fails |
| `OPENROUTER_MODELS_BLACKLIST` | No | `free$` | Regex patterns to exclude (comma-separated) |
| `OPENROUTER_MODELS_INCLUDE` | No | _(empty)_ | Regex patterns to force-include |
| `OPENROUTER_ROUTE_MODELS` | No | _(empty)_ | Regex: force-route matching model IDs to OpenRouter |
| `OPENROUTER_REFERER` | No | `https://smartproxy.local` | HTTP-Referer header for attribution |
| `OPENROUTER_TITLE` | No | `SmartProxy` | X-Title header for attribution |

---

## 6. Testing Requirements

### `spec/lib/openrouter_client_spec.rb` (new file)

| Test | Description |
|------|-------------|
| T1 | `chat_completions` posts to `/chat/completions` with Bearer auth (VCR) |
| T2 | `chat_completions` includes `HTTP-Referer` and `X-Title` headers |
| T3 | `chat_completions` on `Faraday::Error` returns `OpenStruct` with status 502 |
| T4 | `list_models` returns normalised hashes with required keys (VCR) |
| T5 | `list_models` includes `smart_proxy.supported_parameters` from upstream |
| T6 | `list_models` includes `smart_proxy.modalities` from upstream |
| T7 | `list_models` falls back to `OPENROUTER_MODELS` ENV CSV on error |
| T8 | `list_models` returns `[]` when live fails and `OPENROUTER_MODELS` is empty |

### `spec/lib/model_router_spec.rb` (update)

| Test | Description |
|------|-------------|
| T9 | Routes `google/gemini-2.5-pro` to `:openrouter` when key is set |
|T10 | Routes `mistralai/mistral-large` to `:openrouter` when key is set |
|T11 | Routes `deepseek-chat` to `:deepseek` (direct wins over OpenRouter) |
|T12 | Routes `grok-4` to `:grok` (direct wins) |
|T13 | Falls back to `:ollama` for slash-namespaced model when `OPENROUTER_API_KEY` is absent |

---

## 7. Acceptance Criteria

- [ ] `GET /v1/models` includes OpenRouter models (filtered) when `OPENROUTER_API_KEY` is set
- [ ] `POST /v1/chat/completions` with `model: google/gemini-2.5-pro` proxies to OpenRouter
- [ ] `POST /v1/chat/completions` with `model: deepseek-chat` still routes to DeepSeek directly
- [ ] Streaming (`stream: true`) passes through correctly
- [ ] Tool calls pass through without transformation
- [ ] `OPENROUTER_API_KEY` absent → OpenRouter models silently omitted, requests fall through to Ollama
- [ ] `HTTP-Referer` and `X-Title` headers are sent on every OpenRouter request
- [ ] All tests pass
