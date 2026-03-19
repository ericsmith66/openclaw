# PRD: SmartProxy MLX Provider Integration

## Executive Summary

Integrate Apple's MLX framework as a first-class provider in SmartProxy to achieve **6.2x faster local inference** compared to Ollama. Benchmark results show MLX delivers 57.5 tok/s vs Ollama's 14.7 tok/s on the same hardware (M3 Ultra) with identical model quality (Qwen3-Coder-Next 8-bit).

**Business Impact:**
- Agent task execution time reduced by ~83% (49s → 8s per request)
- 265-minute tasks complete in ~43 minutes
- Better developer experience during local testing
- Reduced waiting time in iterative workflows

---

## Problem Statement

Current SmartProxy implementation routes all local LLM requests to Ollama (port 11434), which:
1. Uses GGUF/GGML format (CPU-optimized, limited Metal acceleration)
2. Delivers 14.7 tok/s throughput on M3 Ultra
3. Takes 49s average per coding request
4. Causes significant wait times during multi-task agent workflows

MLX offers superior Metal GPU acceleration specifically designed for Apple Silicon, but requires:
- Different API endpoint (OpenAI-compatible `/v1/chat/completions`)
- Model name passed as-is to the MLX server (server owns path resolution)
- Provider-specific error handling

---

## Goals

### Primary Goals
1. Add MLX as a first-class provider in SmartProxy following existing provider conventions
2. Achieve parity with existing provider integrations (error handling, retries, model listing)
3. Route `mlx/` prefixed model names to the MLX client — consistent with how all other providers work
4. Maintain backward compatibility with existing agent configurations

### Non-Goals
- Replace Ollama entirely (keep as-is)
- Hardware detection or automatic provider preference — callers declare intent via model name
- Explicit router-level fallback from MLX to Ollama — errors surface at runtime like every other provider
- YAML model registry or filesystem path resolution in SmartProxy — the MLX server owns that
- A `BaseClient` shared parent class — separate refactor epic if desired
- Remote/production MLX deployments — Ollama remains primary for servers

---

## Success Metrics

| Metric | Current (Ollama) | Target (MLX) | Measurement |
|--------|------------------|--------------|-------------|
| Tokens/sec (local) | 14.7 tok/s | ≥50 tok/s | Response `usage` metadata |
| Request latency | 49s avg | ≤10s avg | End-to-end timing |
| Time-to-first-token | ~2-3s | <1s | Response streaming |
| Model availability | 1 (Ollama) | 2 (MLX + Ollama) | Provider status |
| Agent task completion | 21-265 min | 3.5-43 min | Workflow logs |

---

## Requirements

### Functional Requirements

#### FR-1: MLX Provider Client
**As a** SmartProxy administrator
**I want** MLX to be available as a provider option
**So that** local requests can use faster inference

**Acceptance Criteria:**
- [ ] `MlxClient` lives in `lib/mlx_client.rb`, following the same flat structure as `GrokClient`, `OllamaClient`, etc.
- [ ] `chat_completions(payload)` returns the raw Faraday response on success; `OpenStruct.new(status:, body:)` on `Faraday::Error` — matching `GrokClient` convention exactly
- [ ] `list_models` returns the standard model hash array consumed by `ModelAggregator`; returns `[]` on any error
- [ ] Model name passed to `MlxClient` is already stripped of `mlx/` prefix by `ModelRouter` — `MlxClient` receives and forwards a clean name
- [ ] MLX speaks native OpenAI `/v1/chat/completions` — payload passes through unchanged
- [ ] Two separate Faraday connections: `chat_connection` (600s timeout, retry middleware) and `models_connection` (10s timeout, no retry) — matching `OllamaClient`'s separate connection pattern
- [ ] `handle_error` always produces a JSON string for `body` — never a raw Hash

**Implementation:**
```ruby
# lib/mlx_client.rb
require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'

class MlxClient
  DEFAULT_BASE_URL = 'http://127.0.0.1:8765'

  def initialize(logger: nil)
    @base_url = ENV.fetch('MLX_BASE_URL', DEFAULT_BASE_URL)
    @logger   = logger
  end

  def list_models
    response = models_connection.get('/v1/models')
    return [] unless response.status == 200

    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    (body['data'] || []).map do |m|
      {
        id:          "mlx/#{m['id']}",
        object:      'model',
        owned_by:    'mlx',
        created:     m['created'] || Time.now.to_i,
        smart_proxy: { provider: 'mlx' }
      }
    end
  rescue StandardError => e
    @logger&.warn({ event: 'mlx_list_models_error', error: e.message })
    []
  end

  def chat_completions(payload)
    # ModelRouter has already stripped the mlx/ prefix into upstream_model.
    # payload['model'] arrives here as a clean name (e.g. "qwen3-coder-next-8bit").
    chat_connection.post('/v1/chat/completions') do |req|
      req.body = payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  # Long-lived connection for inference requests — 600s timeout, retry on transient errors.
  def chat_connection
    @chat_connection ||= Faraday.new(url: @base_url) do |f|
      f.request  :json
      f.options.timeout      = ENV.fetch('MLX_TIMEOUT', '600').to_i
      f.options.open_timeout = 10
      f.request :retry, {
        max:                 3,
        interval:            0.5,
        interval_randomness: 0.5,
        backoff_factor:      2,
        retry_statuses:      [429, 500, 502, 503, 504]
      }
      f.adapter Faraday.default_adapter
    end
  end

  # Short connection for model listing — fast timeout, no retry.
  def models_connection
    @models_connection ||= Faraday.new(url: @base_url) do |f|
      f.request  :json
      f.options.timeout      = 10
      f.options.open_timeout = 5
      f.adapter Faraday.default_adapter
    end
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    # Always produce a JSON string so callers can safely call JSON.parse(response.body)
    body   = error.response ? error.response[:body] : { error: error.message }.to_json
    OpenStruct.new(status: status, body: body)
  end
end
```

#### FR-2: ModelRouter Extension
**As a** SmartProxy
**I want** `mlx/` prefixed model names routed to `MlxClient`
**So that** callers can select MLX by naming their model explicitly

**Design:** Routing is purely model-name-prefix based — exactly the same mechanism as every other provider (`grok` → GrokClient, `claude` → ClaudeClient, `mlx/` → MlxClient). No hardware detection, no availability probing, no enabled flags.

`ModelRouter` strips the `mlx/` prefix into `upstream_model` — consistent with the existing `LIVE_SEARCH_SUFFIX` stripping pattern. `MlxClient` receives and forwards the clean name without any further transformation.

**Acceptance Criteria:**
- [ ] `ModelRouter` strips `mlx/` from `upstream_model` (e.g. `"mlx/qwen3-coder-next-8bit"` → `upstream_model: "qwen3-coder-next-8bit"`)
- [ ] `use_mlx?` returns true when `requested_model` starts with `mlx/`
- [ ] `provider` returns `:mlx` when `use_mlx?`
- [ ] `client` returns `MlxClient.new` when `:mlx`
- [ ] `route` hash includes `use_mlx:` key (consistent with `use_grok:`, `use_claude:`, etc.)
- [ ] `require_relative 'mlx_client'` added at top of `model_router.rb` (no `lib/` prefix — sibling files)

**`ModelRouter` additions:**
```ruby
# lib/model_router.rb

require_relative 'mlx_client'   # added to existing requires — sibling file, no lib/ prefix

MLX_PREFIX = 'mlx/'

def initialize(requested_model)
  @requested_model = requested_model.to_s
  @tools_opt_in    = @requested_model.end_with?(LIVE_SEARCH_SUFFIX)
  # Strip live-search suffix first, then mlx/ prefix into upstream_model
  base             = @tools_opt_in ? @requested_model.sub(/#{LIVE_SEARCH_SUFFIX}\z/, '') : @requested_model
  @upstream_model  = base.start_with?(MLX_PREFIX) ? base.sub(MLX_PREFIX, '') : base
end

# In route:
use_mlx: use_mlx?,

# In provider (checked before grok/claude/etc — mlx/ is an explicit prefix):
def provider
  if use_mlx?
    :mlx
  elsif use_grok?
    :grok
  # ... rest unchanged
  end
end

# In client:
when :mlx
  MlxClient.new

# New predicate:
def use_mlx?
  @requested_model.start_with?(MLX_PREFIX)
end
```

> **Note:** `use_mlx?` checks `@requested_model` (the original), not `@upstream_model` (already stripped). This mirrors how `tools_opt_in` checks `@requested_model` for the live-search suffix.

#### FR-3: ModelAggregator Registration
**As a** SmartProxy
**I want** MLX models to appear in `GET /v1/models`
**So that** callers can discover available MLX models

**Design:** Add MLX to `ModelAggregator::PROVIDERS` following the same lambda pattern. Since MLX has no API key, the lambda always returns a client (same as `OllamaClient`). `list_models` returns `[]` if the server is down — handled inside `MlxClient`.

**Acceptance Criteria:**
- [ ] `MlxClient` added to `ModelAggregator::PROVIDERS`
- [ ] `require_relative 'mlx_client'` added at top of `model_aggregator.rb` (sibling file, no `lib/` prefix)
- [ ] MLX models appear in `/v1/models` with `mlx/` prefixed ids when server is running
- [ ] MLX models silently absent when server is down — `[]` degrades gracefully
- [ ] No double-prefix: `MlxClient#list_models` adds `mlx/` once; `ModelRouter` never re-adds it

**`ModelAggregator` change:**
```ruby
# lib/model_aggregator.rb

require_relative 'mlx_client'   # added to existing requires

PROVIDERS = {
  grok:       -> { ... },        # unchanged
  claude:     -> { ... },        # unchanged
  deepseek:   -> { ... },        # unchanged
  fireworks:  -> { ... },        # unchanged
  openrouter: -> { ... },        # unchanged
  ollama:     -> { OllamaClient.new },
  mlx:        -> { MlxClient.new },   # NEW — always present, returns [] if server down
}.freeze
```

> **Note:** `PROVIDERS` is a frozen constant — no refactor needed. `MlxClient.new` requires no API key so the lambda never returns `nil`. The `@logger` is not passed in the lambda — consistent with how `OllamaClient.new` is instantiated in `PROVIDERS` (no logger). Logging inside `list_models` is silenced in this path; this is an accepted existing pattern.

#### FR-4: Tool Calling Support
**As an** agent
**I want** MLX to support function/tool calling
**So that** I can use the same capabilities as with other providers

**Acceptance Criteria:**
- [ ] `MlxClient` accepts `tools` in payload and passes through unchanged (MLX is OpenAI-compatible)
- [ ] `ToolOrchestrator` requires zero changes — dispatches via `client.respond_to?(:chat_completions)`
- [ ] Tool call responses hit `ResponseTransformer`'s `parsed.key?('choices')` fast path — no conversion needed
- [ ] Verified end-to-end with Legion agent workflows

#### FR-5: Streaming Support
**As an** agent
**I want** MLX streaming responses to work
**So that** I get the same streaming experience as other providers

**Acceptance Criteria:**
- [ ] MLX SSE stream passes through `ResponseTransformer`'s `raw_body.lstrip.start_with?('data:')` path unchanged
- [ ] `ResponseTransformer` requires zero changes
- [ ] Verified end-to-end (see Phase 3)

> **Note:** `app.rb` currently disables streaming for tool-opt-in requests and Claude. MLX streaming should be tested before any similar restriction is applied — the expectation is it works without restriction.

---

### Non-Functional Requirements

#### NFR-1: Performance
- MLX requests must complete in ≤10s average (vs current 49s)
- No performance degradation for non-MLX requests
- Routing decision overhead: negligible (string prefix check only)

#### NFR-2: Reliability
- `chat_connection`: Faraday retry handles transient errors (max 3 attempts, backoff) — same as all other clients
- `models_connection`: fast timeout (10s), no retry — model listing degrades gracefully to `[]`
- `chat_completions` surfaces errors via `OpenStruct` on `Faraday::Error`; `body` always JSON string

#### NFR-3: Observability
- Structured JSON logging via `@logger` — same pattern as `OllamaClient`
- `tokens_per_second` available in MLX response `usage` automatically — `ResponseTransformer` passes `usage` through on the `choices` fast path, no extra work required
- Prometheus metrics (Phase 4):
  - `smartproxy_mlx_requests_total{status}`
  - `smartproxy_mlx_request_duration_seconds`
  - `smartproxy_provider_fallbacks_total{from, to, reason}`

#### NFR-4: Security
- MLX server binds to localhost only (127.0.0.1) — enforced at server config, not SmartProxy
- Timeouts enforced: 600s inference timeout, 10s model listing timeout, 10s open timeout

#### NFR-5: Maintainability
- `MlxClient` structurally identical to `GrokClient` / `DeepSeekClient` — same Faraday setup, same error handling, same `list_models` shape
- `upstream_model` stripping in `ModelRouter` keeps `MlxClient` free of routing concerns
- All routing logic stays in `ModelRouter` — no routing logic in the client

---

## Technical Design

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    SmartProxy (app.rb)                      │
│                                                             │
│  POST /v1/chat/completions                                  │
│         │                                                   │
│  ┌──────▼────────────────────────────────────────────────┐  │
│  │  ModelRouter  (lib/model_router.rb)                   │  │
│  │  "mlx/qwen3-coder-next-8bit"                         │  │
│  │    → upstream_model: "qwen3-coder-next-8bit"         │  │
│  │    → provider: :mlx, client: MlxClient.new           │  │
│  └──────┬────────────────────────────────────────────────┘  │
│         │  routing hash: { provider: :mlx, client: ... }    │
│  ┌──────▼────────────────────────────────────────────────┐  │
│  │  ToolOrchestrator  (lib/tool_orchestrator.rb)         │  │
│  │  client.respond_to?(:chat_completions) → yes          │  │
│  │  No changes required                                  │  │
│  └──────┬────────────────────────────────────────────────┘  │
│         │  payload['model'] = "qwen3-coder-next-8bit"       │
│  ┌──────▼────────────────────────────────────────────────┐  │
│  │  MlxClient  (lib/mlx_client.rb)                       │  │
│  │  Forwards clean model name to MLX server              │  │
│  │  chat_connection: 600s + retry                        │  │
│  │  models_connection: 10s, no retry                     │  │
│  └──────┬────────────────────────────────────────────────┘  │
│         │                                                    │
│  ┌──────▼────────────────────────────────────────────────┐  │
│  │  ResponseTransformer  (lib/response_transformer.rb)   │  │
│  │  MLX returns OpenAI format → choices fast path        │  │
│  │  Streaming → SSE passthrough fast path                │  │
│  │  No changes required                                  │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  GET /v1/models                                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  ModelAggregator  (lib/model_aggregator.rb)          │   │
│  │  PROVIDERS[:mlx] = -> { MlxClient.new }  ← NEW      │   │
│  │  list_models → [] if MLX server down (silent)        │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                        │
                ┌───────▼────────┐
                │   MLX Server   │
                │  :8765 local   │
                │ (owns model    │
                │  path lookup)  │
                └────────────────┘
```

### File Changes

```
SmartProxy/
├── lib/
│   ├── mlx_client.rb          # [NEW]    MLX provider client
│   ├── model_router.rb        # [MODIFY] Strip mlx/ prefix; add use_mlx?, :mlx provider/client
│   └── model_aggregator.rb    # [MODIFY] Add mlx: entry to PROVIDERS; require mlx_client
├── app.rb                     # [MODIFY] require_relative 'lib/mlx_client'
└── spec/
    └── lib/
        ├── mlx_client_spec.rb         # [NEW]    Unit tests
        ├── model_router_spec.rb       # [MODIFY] mlx/ routing + upstream_model strip scenarios
        └── model_aggregator_spec.rb   # [MODIFY] MLX provider listing scenarios
```

No new config files. No changes to `ToolOrchestrator`, `ResponseTransformer`, `ToolExecutor`, or `RequestAuthenticator`.

### Request Flow

```ruby
# 1. Agent sends request with mlx/ prefixed model
POST /v1/chat/completions
{ "model": "mlx/qwen3-coder-next-8bit", "messages": [...], "tools": [...] }

# 2. ModelRouter — strips prefix, pure prefix check for routing
ModelRouter.new("mlx/qwen3-coder-next-8bit").route
# => {
#      provider:        :mlx,
#      client:          MlxClient.new,
#      use_mlx:         true,
#      requested_model: "mlx/qwen3-coder-next-8bit",
#      upstream_model:  "qwen3-coder-next-8bit"   # prefix stripped here
#    }

# 3. app.rb sets upstream payload model to upstream_model
upstream_payload['model'] = "qwen3-coder-next-8bit"

# 4. ToolOrchestrator dispatches — no changes
client.respond_to?(:chat_completions)  # => true
client.chat_completions(upstream_payload)

# 5. MlxClient forwards clean name directly — no stripping needed
# MLX server resolves "qwen3-coder-next-8bit" to its local model path

# 6. MLX returns native OpenAI format
# ResponseTransformer: parsed.key?('choices') → fast path, returned as-is
# usage including tokens_per_second available automatically
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1)
**Goal:** Basic MLX integration working locally

**Tasks:**
1. [ ] Create `lib/mlx_client.rb` — `chat_completions`, `list_models`, two connections
2. [ ] Modify `ModelRouter` — strip `mlx/` into `upstream_model`, add `use_mlx?`, `:mlx` routing
3. [ ] Add `:mlx` to `ModelAggregator::PROVIDERS`, add `require_relative 'mlx_client'`
4. [ ] Add `require_relative 'lib/mlx_client'` to `app.rb`
5. [ ] RSpec unit tests (`spec/lib/mlx_client_spec.rb`)
6. [ ] Manual testing — confirm routing, model listing, and 5-6x speedup

**Deliverables:**
- Working MLX client
- 20+ RSpec examples
- Local testing confirms speedup

### Phase 2: Verification & Integration Tests (Week 1-2)
**Goal:** Confidence in routing and model listing

**Tasks:**
1. [ ] Extend `spec/lib/model_router_spec.rb` with `mlx/` routing and `upstream_model` strip scenarios
2. [ ] Extend `spec/lib/model_aggregator_spec.rb` with MLX provider scenarios
3. [ ] Verify MLX models appear correctly in `GET /v1/models`
4. [ ] Verify MLX absent from listing (silently) when server is down
5. [ ] Integration test with Legion agent workflows

**Deliverables:**
- All routing and listing tests passing
- 15+ additional RSpec examples

### Phase 3: Tool Calling & Streaming (Week 2)
**Goal:** Feature parity confirmed

**Tasks:**
1. [ ] Verify tool calling end-to-end with Legion agent
2. [ ] Verify streaming responses through `ResponseTransformer`
3. [ ] Performance benchmarks documented

**Deliverables:**
- Tool calling confirmed working
- Streaming confirmed working
- Benchmark results updated

### Phase 4: Observability & Docs (Week 2-3)
**Goal:** Production-ready

**Tasks:**
1. [ ] Add Prometheus metrics (`smartproxy_mlx_*`)
2. [ ] Write `docs/mlx_setup.md` (server setup, model naming convention)
3. [ ] Troubleshooting guide

---

## Testing Strategy

> The SmartProxy test suite uses **RSpec** (`spec/`). All examples follow project conventions:
> - ENV isolation uses the `with_env` helper (defined locally in each spec file — see `grok_client_spec.rb`)
> - No `climate_control` gem — use the project's own `with_env` pattern
> - WebMock is configured in `spec_helper.rb`; `stub_request` is available in all specs

### `with_env` Helper (copy into each spec file that needs it)
```ruby
def with_env(key, value)
  old_value   = ENV[key]
  old_existed = ENV.key?(key)
  value.nil? ? ENV.delete(key) : ENV[key] = value
  yield
ensure
  old_existed ? ENV[key] = old_value : ENV.delete(key)
end
```

### Unit Tests — `spec/lib/mlx_client_spec.rb`
```ruby
require 'spec_helper'
require_relative '../../lib/mlx_client'

RSpec.describe MlxClient do
  def with_env(key, value)
    old_value   = ENV[key]
    old_existed = ENV.key?(key)
    value.nil? ? ENV.delete(key) : ENV[key] = value
    yield
  ensure
    old_existed ? ENV[key] = old_value : ENV.delete(key)
  end

  let(:client) { described_class.new }

  let(:base_url)        { 'http://127.0.0.1:8765' }
  let(:chat_url)        { "#{base_url}/v1/chat/completions" }
  let(:models_url)      { "#{base_url}/v1/models" }
  let(:base_payload)    { { 'model' => 'qwen3-coder-next-8bit', 'messages' => [{ 'role' => 'user', 'content' => 'hi' }] } }

  let(:openai_response) do
    {
      'id'      => 'chatcmpl-abc123',
      'object'  => 'chat.completion',
      'created' => 1_700_000_000,
      'model'   => 'qwen3-coder-next-8bit',
      'choices' => [{ 'index' => 0, 'message' => { 'role' => 'assistant', 'content' => 'Hello!' }, 'finish_reason' => 'stop' }],
      'usage'   => { 'prompt_tokens' => 5, 'completion_tokens' => 3, 'total_tokens' => 8 }
    }
  end

  # ---------------------------------------------------------------------------
  # #chat_completions
  # ---------------------------------------------------------------------------

  describe '#chat_completions' do
    it 'returns the Faraday response on success (status + body accessible)' do
      stub_request(:post, chat_url)
        .to_return(status: 200, body: openai_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.chat_completions(base_payload)
      expect(result.status).to eq(200)
      expect(JSON.parse(result.body)).to have_key('choices')
    end

    it 'forwards the payload model name unchanged to the server' do
      stub = stub_request(:post, chat_url)
        .with(body: hash_including('model' => 'qwen3-coder-next-8bit'))
        .to_return(status: 200, body: openai_response.to_json)

      client.chat_completions(base_payload)
      expect(stub).to have_been_requested
    end

    it 'passes tools through unchanged to the server' do
      tools = [{ 'type' => 'function', 'function' => { 'name' => 'search', 'parameters' => {} } }]
      stub = stub_request(:post, chat_url)
        .with(body: hash_including('tools' => tools))
        .to_return(status: 200, body: openai_response.to_json)

      client.chat_completions(base_payload.merge('tools' => tools))
      expect(stub).to have_been_requested
    end

    it 'returns OpenStruct with status 500 and JSON body on connection failure' do
      stub_request(:post, chat_url).to_raise(Faraday::ConnectionFailed.new('connection refused'))

      result = client.chat_completions(base_payload)
      expect(result.status).to eq(500)
      expect { JSON.parse(result.body) }.not_to raise_error
      expect(JSON.parse(result.body)).to have_key('error')
    end

    it 'returns OpenStruct with server error status on 5xx response' do
      stub_request(:post, chat_url).to_return(status: 503, body: 'Service Unavailable')

      result = client.chat_completions(base_payload)
      # 5xx without raise_error: Faraday returns the response — status surfaced as-is
      expect(result.status).to eq(503)
    end

    it 'works when called with a non-mlx-prefixed model name (prefix already stripped by ModelRouter)' do
      stub_request(:post, chat_url)
        .with(body: hash_including('model' => 'qwen3-coder-next-8bit'))
        .to_return(status: 200, body: openai_response.to_json)

      # Simulates what ModelRouter delivers: upstream_model with prefix already stripped
      result = client.chat_completions({ 'model' => 'qwen3-coder-next-8bit', 'messages' => [] })
      expect(result.status).to eq(200)
    end

    it 'respects MLX_TIMEOUT env var for the chat connection' do
      with_env('MLX_TIMEOUT', '30') do
        c = described_class.new
        # Force connection build by calling it
        conn = c.send(:chat_connection)
        expect(conn.options.timeout).to eq(30)
      end
    end

    it 'respects MLX_BASE_URL env var' do
      with_env('MLX_BASE_URL', 'http://127.0.0.1:9999') do
        c = described_class.new
        expect(c.instance_variable_get(:@base_url)).to eq('http://127.0.0.1:9999')
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #list_models
  # ---------------------------------------------------------------------------

  describe '#list_models' do
    it 'returns models with mlx/ prefixed ids' do
      stub_request(:get, models_url)
        .to_return(status: 200, body: { 'data' => [{ 'id' => 'qwen3-coder-next-8bit', 'created' => 1_700_000_000 }] }.to_json)

      models = client.list_models
      expect(models.length).to eq(1)
      expect(models.first[:id]).to eq('mlx/qwen3-coder-next-8bit')
      expect(models.first[:owned_by]).to eq('mlx')
      expect(models.first[:smart_proxy]).to eq({ provider: 'mlx' })
    end

    it 'includes all required model hash keys' do
      stub_request(:get, models_url)
        .to_return(status: 200, body: { 'data' => [{ 'id' => 'test-model', 'created' => 0 }] }.to_json)

      model = client.list_models.first
      expect(model.keys).to include(:id, :object, :owned_by, :created, :smart_proxy)
    end

    it 'falls back to Time.now for created when absent from server response' do
      stub_request(:get, models_url)
        .to_return(status: 200, body: { 'data' => [{ 'id' => 'test-model' }] }.to_json)

      model = client.list_models.first
      expect(model[:created]).to be_within(5).of(Time.now.to_i)
    end

    it 'returns empty array when server is down' do
      stub_request(:get, models_url).to_raise(Faraday::ConnectionFailed.new('connection refused'))
      expect(client.list_models).to eq([])
    end

    it 'returns empty array on non-200 response' do
      stub_request(:get, models_url).to_return(status: 503, body: '')
      expect(client.list_models).to eq([])
    end

    it 'returns empty array when data key is missing from response' do
      stub_request(:get, models_url).to_return(status: 200, body: {}.to_json)
      expect(client.list_models).to eq([])
    end

    it 'returns empty array when data is empty array' do
      stub_request(:get, models_url).to_return(status: 200, body: { 'data' => [] }.to_json)
      expect(client.list_models).to eq([])
    end

    it 'returns empty array on malformed JSON response body' do
      stub_request(:get, models_url).to_return(status: 200, body: 'not-json{{{')
      expect(client.list_models).to eq([])
    end

    it 'uses the short-timeout models_connection (not chat_connection)' do
      conn = client.send(:models_connection)
      expect(conn.options.timeout).to eq(10)
    end

    it 'chat_connection has the longer inference timeout' do
      conn = client.send(:chat_connection)
      expect(conn.options.timeout).to eq(600)
    end
  end

  # ---------------------------------------------------------------------------
  # #handle_error (private — tested via chat_completions)
  # ---------------------------------------------------------------------------

  describe '#handle_error (via chat_completions)' do
    it 'body is always a JSON string, never a raw Hash' do
      stub_request(:post, chat_url).to_raise(Faraday::ConnectionFailed.new('refused'))

      result = client.chat_completions(base_payload)
      expect(result.body).to be_a(String)
      expect { JSON.parse(result.body) }.not_to raise_error
    end
  end
end
```

### ModelRouter Tests — additions to `spec/lib/model_router_spec.rb`
```ruby
# Additions to existing RSpec.describe ModelRouter block

describe 'MLX routing (FR-2)' do
  it 'routes mlx/ prefixed model to :mlx provider' do
    routing = described_class.new('mlx/qwen3-coder-next-8bit').route
    expect(routing[:provider]).to eq(:mlx)
    expect(routing[:client]).to be_a(MlxClient)
    expect(routing[:use_mlx]).to be true
  end

  it 'strips mlx/ prefix into upstream_model' do
    routing = described_class.new('mlx/qwen3-coder-next-8bit').route
    expect(routing[:upstream_model]).to eq('qwen3-coder-next-8bit')
    expect(routing[:requested_model]).to eq('mlx/qwen3-coder-next-8bit')
  end

  it 'routes mlx/ models to :mlx even when all other API keys are present' do
    allow(ENV).to receive(:[]).and_call_original
    %w[GROK_API_KEY_SAP GROK_API_KEY CLAUDE_API_KEY DEEPSEEK_API_KEY FIREWORKS_API_KEY OPENROUTER_API_KEY].each do |key|
      allow(ENV).to receive(:[]).with(key).and_return('some-key')
    end

    routing = described_class.new('mlx/qwen3-coder-next-8bit').route
    expect(routing[:provider]).to eq(:mlx)
  end

  it 'non-mlx models have use_mlx: false' do
    routing = described_class.new('llama3.1:8b').route
    expect(routing[:use_mlx]).to be false
  end

  it 'non-mlx models upstream_model is unchanged' do
    routing = described_class.new('llama3.1:8b').route
    expect(routing[:upstream_model]).to eq('llama3.1:8b')
  end

  it 'does not strip mlx/ from models that merely contain mlx in the name' do
    routing = described_class.new('some-mlx-variant').route
    expect(routing[:provider]).not_to eq(:mlx)
    expect(routing[:upstream_model]).to eq('some-mlx-variant')
  end
end
```

### ModelAggregator Tests — additions to `spec/lib/model_aggregator_spec.rb`
```ruby
# Additions to existing RSpec.describe ModelAggregator block

describe 'MLX provider (FR-3)' do
  it 'includes MLX models in the aggregated list when server is running' do
    mlx_model = { id: 'mlx/qwen3-coder-next-8bit', object: 'model', owned_by: 'mlx',
                  created: Time.now.to_i, smart_proxy: { provider: 'mlx' } }

    allow_any_instance_of(MlxClient).to  receive(:list_models).and_return([mlx_model])
    allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
    allow_any_instance_of(ModelFilter).to receive(:apply) { |_f, models| models }

    aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
    result = aggregator.list_models

    ids = result[:payload][:data].map { |m| m[:id] }
    expect(ids).to include('mlx/qwen3-coder-next-8bit')
  end

  it 'silently omits MLX models when server is down (list_models returns [])' do
    allow_any_instance_of(MlxClient).to  receive(:list_models).and_return([])
    allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
    allow_any_instance_of(ModelFilter).to receive(:apply) { |_f, models| models }

    aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
    result = aggregator.list_models

    ids = result[:payload][:data].map { |m| m[:id] }
    expect(ids.none? { |id| id.to_s.start_with?('mlx/') }).to be true
  end

  it 'does not double-prefix MLX model ids' do
    # MlxClient#list_models already adds mlx/ — ModelAggregator must not add it again
    mlx_model = { id: 'mlx/qwen3-coder-next-8bit', object: 'model', owned_by: 'mlx',
                  created: Time.now.to_i, smart_proxy: { provider: 'mlx' } }

    allow_any_instance_of(MlxClient).to  receive(:list_models).and_return([mlx_model])
    allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
    allow_any_instance_of(ModelFilter).to receive(:apply) { |_f, models| models }

    aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
    result = aggregator.list_models

    mlx_ids = result[:payload][:data].map { |m| m[:id] }.select { |id| id.to_s.include?('mlx') }
    expect(mlx_ids).not_to include('mlx/mlx/qwen3-coder-next-8bit')
    expect(mlx_ids).to include('mlx/qwen3-coder-next-8bit')
  end
end
```

### Integration Tests — `spec/lib/mlx_provider_spec.rb`
```ruby
# spec/lib/mlx_provider_spec.rb (requires live MLX server — tagged :integration)
require 'spec_helper'
require_relative '../../lib/mlx_client'

RSpec.describe 'MLX provider integration', :integration do
  let(:client) { MlxClient.new }

  before { skip 'MLX server not running' if client.list_models.empty? }

  it 'completes a chat request end-to-end' do
    result = client.chat_completions({
      'model'    => 'qwen3-coder-next-8bit',
      'messages' => [{ 'role' => 'user', 'content' => 'Write hello world in Ruby. One line only.' }]
    })
    body = JSON.parse(result.body)
    expect(result.status).to eq(200)
    expect(body.dig('choices', 0, 'message', 'content')).not_to be_empty
  end

  it 'handles tool calling end-to-end' do
    tools = [{
      'type'     => 'function',
      'function' => {
        'name'       => 'get_weather',
        'parameters' => { 'type' => 'object', 'properties' => { 'location' => { 'type' => 'string' } }, 'required' => ['location'] }
      }
    }]
    result = client.chat_completions({
      'model'    => 'qwen3-coder-next-8bit',
      'messages' => [{ 'role' => 'user', 'content' => 'What is the weather in London?' }],
      'tools'    => tools
    })
    expect(result.status).to eq(200)
  end
end
```

### Performance Tests — `spec/benchmarks/mlx_vs_ollama_spec.rb`
```ruby
# spec/benchmarks/mlx_vs_ollama_spec.rb
# Run with: RUN_BENCHMARKS=true rspec spec/benchmarks/
require 'spec_helper'
require 'benchmark'
require_relative '../../lib/mlx_client'
require_relative '../../lib/ollama_client'

RSpec.describe 'MLX vs Ollama performance' do
  before(:all) do
    skip 'Set RUN_BENCHMARKS=true to run benchmark tests' unless ENV['RUN_BENCHMARKS'] == 'true'
    skip 'MLX server not running' if MlxClient.new.list_models.empty?
  end

  let(:prompt) { [{ 'role' => 'user', 'content' => 'Write a Ruby method that returns the nth Fibonacci number.' }] }

  it 'MLX is at least 3x faster than Ollama for the same prompt' do
    mlx_time    = Benchmark.realtime { MlxClient.new.chat_completions('model' => 'qwen3-coder-next-8bit', 'messages' => prompt) }
    ollama_time = Benchmark.realtime { OllamaClient.new.chat_completions('model' => 'qwen3-coder-next:q8_0', 'messages' => prompt) }

    speedup = ollama_time / mlx_time
    puts "\nMLX: #{mlx_time.round(2)}s | Ollama: #{ollama_time.round(2)}s | Speedup: #{speedup.round(1)}x"
    expect(speedup).to be > 3.0, "Expected MLX to be at least 3x faster (got #{speedup.round(1)}x)"
  end
end
```

---

## Configuration

### Environment Variables

Two new variables — consistent with the one `BASE_URL` / one `TIMEOUT` pattern per provider:

```bash
MLX_BASE_URL=http://127.0.0.1:8765   # MLX server endpoint (default: http://127.0.0.1:8765)
MLX_TIMEOUT=600                       # Inference request timeout in seconds (default: 600)
```

No `MLX_ENABLED`, no `MLX_FALLBACK_ENABLED`, no `PREFER_MLX_LOCAL`, no `FORCE_PROVIDER` — callers select MLX by using an `mlx/` prefixed model name, same as every other provider.

---

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| MLX server crashes during request | High | Medium | Faraday retry (3 attempts, backoff) on `chat_connection` |
| Model not found on MLX server | High | Low | MLX server returns 404; `handle_error` surfaces it as JSON body |
| MLX server down at startup | Low | Low | `list_models` uses `models_connection` (10s timeout), returns `[]` silently |
| Breaking changes in MLX OpenAI-compatible API | Medium | Low | Integration tests catch API changes |
| Performance regression vs benchmark | High | Low | Continuous benchmarking; rollback by switching model name prefix |
| `upstream_model` strip regression | Medium | Low | `model_router_spec.rb` explicitly asserts both `upstream_model` and `requested_model` values |

---

## Rollout Plan

### Phase 1: Local Development (Week 1)
- Deploy to M3 Ultra developer machine
- Test with sample workflows using `mlx/` prefixed model names
- Gather performance metrics

### Phase 2: Opt-In (Week 2)
- Share with 2-3 beta testers
- Agents opt in by using `mlx/` prefixed model names
- Monitor for issues

### Phase 3: Default Local Model (Week 3)
- Update agent configurations to use `mlx/` prefixed models by default
- Ollama remains available via unprefixed model names
- Monitor metrics

### Phase 4: Documentation (Week 4)
- Publish `docs/mlx_setup.md`
- Update team documentation with model naming convention

---

## Success Criteria

### Must Have (P0)
- [ ] `MlxClient` integrated following existing provider conventions
- [ ] `mlx/` prefix stripped by `ModelRouter` into `upstream_model`; routing to `:mlx` working
- [ ] MLX models appear in `GET /v1/models` when server is running
- [ ] 5x+ speedup demonstrated in benchmarks
- [ ] Tool calling working
- [ ] Zero regressions in existing provider routing

### Should Have (P1)
- [ ] Streaming responses verified
- [ ] Prometheus metrics
- [ ] Complete documentation
- [ ] 90%+ RSpec test coverage on `MlxClient`

### Nice to Have (P2)
- [ ] Performance comparison dashboard
- [ ] `BaseClient` shared parent (separate epic)

---

## Future Enhancements

1. **Adaptive Model Selection** — Route to faster 4-bit MLX models for simple queries, 8-bit for complex reasoning
2. **Model Preloading** — Keep frequently-used models warm to eliminate cold-start delays
3. **Remote MLX Support** — Deploy MLX on a dedicated Mac Studio server; expose via `MLX_BASE_URL`
4. **`BaseClient` Shared Parent** — Extract common Faraday wiring into a base class; requires refactoring all existing clients

---

## Appendix

### Benchmark Results (Raw Data)
```
Test 1: Fibonacci function
  Ollama: 37.78s | 411 tokens | 10.9 tok/s
  MLX:     6.52s | 360 tokens | 55.2 tok/s
  Speedup: 5.8x

Test 2: Sync vs Async explanation
  Ollama: 49.02s | 709 tokens | 14.5 tok/s
  MLX:     8.72s | 512 tokens | 58.7 tok/s
  Speedup: 5.6x

Test 3: Rails service generation
  Ollama: 60.75s | 1143 tokens | 18.8 tok/s
  MLX:     8.72s | 512 tokens | 58.7 tok/s
  Speedup: 7.0x

Average Speedup: 6.2x
Recommendation: YES — integrate MLX
```

### Model Naming Convention

Callers select MLX by prefixing the model name with `mlx/`. `ModelRouter` strips the prefix before forwarding:

| Agent request | Routes to | `upstream_model` | Server receives |
|---------------|-----------|-----------------|-----------------|
| `mlx/qwen3-coder-next-8bit` | MlxClient | `qwen3-coder-next-8bit` | `qwen3-coder-next-8bit` |
| `mlx/qwen2.5-coder-7b` | MlxClient | `qwen2.5-coder-7b` | `qwen2.5-coder-7b` |
| `qwen3-coder-next:q8_0` | OllamaClient | `qwen3-coder-next:q8_0` | `qwen3-coder-next:q8_0` |
| `grok-4` | GrokClient | `grok-4` | `grok-4` |

The MLX server is responsible for resolving model names to local filesystem paths.

### References
- [MLX GitHub](https://github.com/ml-explore/mlx)
- [MLX-LM Documentation](https://github.com/ml-explore/mlx-examples/tree/main/llms)
- [OpenAI API Specification](https://platform.openai.com/docs/api-reference)

### Glossary
- **MLX**: Apple's machine learning framework optimized for Apple Silicon
- **GGUF**: GPT-Generated Unified Format (Ollama's model format)
- **Metal**: Apple's GPU acceleration framework
- **M3 Ultra**: Apple Silicon chip with unified memory architecture
- **`upstream_model`**: The model name forwarded to the upstream provider after any prefix/suffix stripping by `ModelRouter`

---

## Approval

**Product Owner:** _________________  Date: __________

**Tech Lead:** _________________  Date: __________

**QA Lead:** _________________  Date: __________
