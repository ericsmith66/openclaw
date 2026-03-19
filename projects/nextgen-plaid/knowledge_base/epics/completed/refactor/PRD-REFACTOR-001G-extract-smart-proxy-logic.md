# PRD-REFACTOR-001G: Extract SmartProxy Business Logic

Part of Epic REFACTOR-001: Codebase Architectural Refactoring.

---

## Overview

Extract business logic from the monolithic `SmartProxyApp` Sinatra application (962 lines) into focused service classes, leaving only HTTP routing and request/response handling in the main app file.

This refactoring addresses the "Fat Controller" anti-pattern in the Sinatra app and establishes a pattern for implementing PRD-AH-OLLAMA-TOOL-01 (native tool calling) cleanly.

---

## Problem statement

The current `smart_proxy/app.rb` (962 lines) violates separation of concerns by mixing:

1. **HTTP routing** (Sinatra endpoints: `/health`, `/v1/models`, `/v1/chat/completions`, `/proxy/tools`, `/proxy/generate`)
2. **Response transformation** (lines 224-327: SSE streaming conversion, Ollama→OpenAI mapping)
3. **Tool orchestration** (lines 462-566: tool loop, max_loops enforcement, tool_calls parsing)
4. **Tool execution** (lines 595-846: web_search, x_keyword_search, confidence calculation)
5. **Model routing** (lines 177-204: Grok vs Claude vs Ollama selection)
6. **Authentication** (lines 911-959: Bearer token validation)
7. **Logging** (inline throughout with `$logger.info`)
8. **Configuration** (lines 19-42: cache, logging, ENV var management)
9. **Model listing** (lines 56-144: Ollama + Grok + Claude model aggregation)

This makes the app:
- Hard to test (HTTP layer coupled to business logic)
- Hard to extend (e.g., adding Ollama tool support requires editing 962-line file)
- Difficult to reason about (9 concerns in one file)
- Impossible to reuse logic outside Sinatra context

**Specific issues**:
- 14 methods in single class (8 private, 3 route handlers)
- Tool orchestration logic (105 lines) embedded in route handler
- Response transformation logic (100+ lines) duplicated between streaming/non-streaming paths
- No clear boundary between HTTP concerns and domain logic

---

## Proposed solution

### A) Extract service classes

Create six focused service classes in `smart_proxy/lib/`:

1. **`ResponseTransformer`**
   - Methods: `to_openai_format`, `to_sse_stream`, `ollama_to_openai`, `claude_to_openai`
   - Responsibility: Transform vendor responses to OpenAI-compatible format
   - Location: `smart_proxy/lib/response_transformer.rb`
   - Lines: ~80

2. **`ToolOrchestrator`**
   - Methods: `orchestrate`, `execute_loop`, `should_continue?`, `attach_metadata`
   - Responsibility: Tool calling loop management, max_loops enforcement
   - Location: `smart_proxy/lib/tool_orchestrator.rb`
   - Lines: ~100

3. **`ToolExecutor`**
   - Methods: `execute`, `execute_web_search`, `execute_x_keyword_search`, `validate_args`
   - Responsibility: Individual tool execution and validation
   - Location: `smart_proxy/lib/tool_executor.rb`
   - Lines: ~120

4. **`ModelRouter`**
   - Methods: `route`, `determine_provider`, `select_client`, `resolve_model_alias`
   - Responsibility: Model selection (Ollama/Grok/Claude) and client instantiation
   - Location: `smart_proxy/lib/model_router.rb`
   - Lines: ~60

5. **`ModelAggregator`**
   - Methods: `list_models`, `fetch_ollama_models`, `add_grok_models`, `add_claude_models`
   - Responsibility: Aggregate models from all providers with caching
   - Location: `smart_proxy/lib/model_aggregator.rb`
   - Lines: ~80

6. **`RequestAuthenticator`**
   - Methods: `authenticate!`, `valid_token?`, `extract_bearer_token`
   - Responsibility: Bearer token authentication
   - Location: `smart_proxy/lib/request_authenticator.rb`
   - Lines: ~40

### B) Simplify SmartProxyApp to thin HTTP layer

The main `app.rb` becomes a thin Sinatra router that:
- Handles HTTP routing (endpoints)
- Extracts request parameters
- Delegates to service classes
- Formats HTTP responses (status codes, headers)
- Handles top-level exceptions

Target: Reduce `app.rb` to < 350 lines.

### C) Establish pattern for PRD-AH-OLLAMA-TOOL-01

With clean separation, adding Ollama native tool support becomes:
- `OllamaClient`: Parse `tool_calls` from response (already isolated)
- `ToolOrchestrator`: Already handles tool loops (provider-agnostic)
- `ResponseTransformer`: Already normalizes responses (add tool_calls normalization)

**No changes to app.rb required.**

---

## Implementation plan

### Step 1: Extract ResponseTransformer
- Create `smart_proxy/lib/response_transformer.rb`
- Move response transformation logic (lines 224-403)
- Extract methods: `to_openai_format`, `to_sse_stream`, `ollama_to_openai`, `parse_response`
- Update route to use transformer: `ResponseTransformer.to_openai_format(response, streaming: request_payload['stream'])`
- Run existing RSpec tests

### Step 2: Extract ModelAggregator
- Create `smart_proxy/lib/model_aggregator.rb`
- Move model listing logic (lines 56-144)
- Handle caching internally
- Update route: `ModelAggregator.new(cache_ttl: settings.models_cache_ttl).list_models`
- Run existing tests

### Step 3: Extract ModelRouter
- Create `smart_proxy/lib/model_router.rb`
- Move routing logic (lines 165-196)
- Extract client selection (lines 577-593)
- Update route: `ModelRouter.new(requested_model).determine_provider`
- Run existing tests

### Step 4: Extract ToolOrchestrator
- Create `smart_proxy/lib/tool_orchestrator.rb`
- Move orchestration logic (lines 462-566)
- Keep tool execution as injectable dependency
- Update route: `ToolOrchestrator.new(executor: tool_executor).orchestrate(payload, provider: provider)`
- Run existing tests

### Step 5: Extract ToolExecutor
- Create `smart_proxy/lib/tool_executor.rb`
- Move tool execution methods (lines 595-846)
- Extract web_search, x_keyword_search, calculate_confidence
- Update orchestrator to use executor
- Run existing tests

### Step 6: Extract RequestAuthenticator
- Create `smart_proxy/lib/request_authenticator.rb`
- Move authentication logic (lines 911-959)
- Update `before` filter to use authenticator
- Run existing tests

### Step 7: Refactor app.rb
- Simplify routes to delegation pattern
- Remove extracted methods
- Update error handling
- Run existing tests

### Step 8: Final cleanup
- Ensure all tests pass
- Update documentation
- Measure final line count
- Verify no regressions

---

## Service class designs

### ResponseTransformer

```ruby
# smart_proxy/lib/response_transformer.rb
class ResponseTransformer
  def self.to_openai_format(response, model:, streaming: false)
    new(response, model: model, streaming: streaming).transform
  end

  def initialize(response, model:, streaming: false)
    @response = response
    @model = model
    @streaming = streaming
  end

  def transform
    return to_sse_stream if @streaming
    to_json_response
  end

  private

  def to_sse_stream
    # Extract streaming logic (lines 224-327)
    parsed = parse_response_body

    if openai_compatible?(parsed)
      convert_openai_to_sse(parsed)
    elsif ollama_format?(parsed)
      convert_ollama_to_sse(parsed)
    else
      @response.body.to_s
    end
  end

  def to_json_response
    # Extract non-streaming logic (lines 329-403)
    parsed = parse_response_body

    if openai_compatible?(parsed)
      add_usage_metadata(parsed)
    elsif ollama_format?(parsed)
      ollama_to_openai(parsed)
    else
      fallback_response(parsed)
    end
  end

  def ollama_to_openai(parsed)
    # Map Ollama response to OpenAI format (lines 338-375)
    {
      id: "chatcmpl-#{SecureRandom.hex(8)}",
      object: 'chat.completion',
      created: parse_timestamp(parsed['created_at']),
      model: @model,
      choices: [
        {
          index: 0,
          finish_reason: 'stop',
          message: {
            role: parsed.dig('message', 'role') || 'assistant',
            content: parsed.dig('message', 'content')
          }
        }
      ],
      usage: extract_usage(parsed)
    }
  end

  # ... other helper methods
end
```

### ToolOrchestrator

```ruby
# smart_proxy/lib/tool_orchestrator.rb
class ToolOrchestrator
  attr_reader :max_loops, :loop_count, :tools_used

  def initialize(executor:, max_loops: 3, logger: nil, session_id: nil)
    @executor = executor
    @max_loops = max_loops
    @logger = logger || $logger
    @session_id = session_id
    @loop_count = 0
    @tools_used = []
  end

  def orchestrate(payload, provider:, tools_opt_in: false)
    @provider = provider
    @tools_opt_in = tools_opt_in

    current_payload = prepare_payload(payload)

    while should_continue?
      response = execute_turn(current_payload)
      parsed = parse_response(response)

      return finalize_response(parsed) unless has_tool_calls?(parsed)
      return finalize_response(parsed) if unsupported_tools?(parsed)
      return finalize_response(parsed, stopped: 'max_loops') if at_max_loops?

      current_payload = append_tool_results(current_payload, parsed)
      @loop_count += 1
    end

    execute_final_turn(current_payload)
  end

  private

  def prepare_payload(payload)
    return payload unless @tools_opt_in && web_tools_enabled?

    payload.dup.tap do |p|
      p['stream'] = false
      p['tools'] ||= web_tools_definitions
      p['tool_choice'] ||= 'auto'
    end
  end

  def execute_turn(payload)
    # Delegate to provider client
    @provider.chat(payload)
  end

  def append_tool_results(payload, response)
    tool_calls = extract_tool_calls(response)

    payload['messages'] ||= []
    payload['messages'] << response.dig('choices', 0, 'message')

    tool_calls.each do |tool_call|
      result = @executor.execute(
        name: tool_call.dig('function', 'name'),
        args: tool_call.dig('function', 'arguments'),
        call_id: tool_call['id']
      )

      @tools_used << { name: result[:name], tool_call_id: result[:call_id] }

      payload['messages'] << {
        role: 'tool',
        tool_call_id: result[:call_id],
        content: result[:content]
      }.compact
    end

    payload
  end

  def finalize_response(parsed, stopped: nil)
    attach_metadata!(parsed, stopped: stopped)
    Response.new(200, parsed.to_json)
  end

  def attach_metadata!(parsed, stopped: nil)
    parsed['smart_proxy'] ||= {}
    parsed['smart_proxy']['tool_loop'] = {
      loop_count: @loop_count,
      max_loops: @max_loops
    }
    parsed['smart_proxy']['tool_loop'][:stopped] = stopped if stopped
    parsed['smart_proxy']['tools_used'] = @tools_used
  end

  def should_continue?
    @loop_count <= @max_loops
  end

  def at_max_loops?
    @loop_count >= @max_loops
  end

  # ... other helper methods
end
```

### ToolExecutor

```ruby
# smart_proxy/lib/tool_executor.rb
class ToolExecutor
  def initialize(session_id:, logger: nil, tools_opt_in: false)
    @session_id = session_id
    @logger = logger || $logger
    @tools_opt_in = tools_opt_in
  end

  def execute(name:, args:, call_id:)
    tool_name = name.to_s
    parsed_args = parse_args(args)

    unless authorized?(tool_name)
      return unauthorized_result(tool_name, call_id)
    end

    result = case tool_name
    when 'web_search'
      execute_web_search(parsed_args)
    when 'x_keyword_search'
      execute_x_keyword_search(parsed_args)
    when 'proxy_tools', 'live_search'
      execute_web_search(parsed_args)
    else
      { error: 'unsupported_tool', name: tool_name }.to_json
    end

    { name: tool_name, call_id: call_id, content: result }
  rescue StandardError => e
    @logger.error({ event: 'tool_execution_error', session_id: @session_id, tool: tool_name, error: e.message })
    { name: tool_name, call_id: call_id, content: { error: 'tool_execution_error', message: e.message }.to_json }
  end

  private

  def authorized?(tool_name)
    return true unless web_tool_name?(tool_name)
    web_tools_enabled? && @tools_opt_in
  end

  def execute_web_search(args)
    query = validate_query(args)
    num_results = normalize_int(args['num_results'] || 5, default: 5, min: 1, max: 10)

    return error_result('query is required') if query.empty?

    @logger.info({ event: 'tool_request', session_id: @session_id, tool: 'web_search', args: { query: query, num_results: num_results } })

    grok_client = GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])
    live_search = LiveSearch.new(grok_client: grok_client, session_id: @session_id, logger: @logger)

    live_search.web_search(query, num_results: num_results)
  end

  # ... other execute methods
end
```

### ModelRouter

```ruby
# smart_proxy/lib/model_router.rb
class ModelRouter
  GROK_PREFIX = 'grok'
  CLAUDE_PREFIX = 'claude'
  LIVE_SEARCH_SUFFIX = '-with-live-search'

  def initialize(requested_model)
    @requested_model = requested_model.to_s
    @tools_opt_in = @requested_model.end_with?(LIVE_SEARCH_SUFFIX)
    @upstream_model = @tools_opt_in ? @requested_model.sub(/#{LIVE_SEARCH_SUFFIX}\z/, '') : @requested_model
  end

  def determine_provider
    {
      provider: provider_name,
      client: build_client,
      model: @upstream_model,
      requested_model: @requested_model,
      tools_opt_in: @tools_opt_in
    }
  end

  private

  def provider_name
    return :grok if use_grok?
    return :claude if use_claude?
    :ollama
  end

  def use_grok?
    @upstream_model.start_with?(GROK_PREFIX) && grok_api_key.present?
  end

  def use_claude?
    @upstream_model.start_with?(CLAUDE_PREFIX) && claude_api_key.present?
  end

  def build_client
    case provider_name
    when :grok
      GrokClient.new(api_key: grok_api_key)
    when :claude
      ClaudeClient.new(api_key: claude_api_key)
    else
      OllamaClient.new
    end
  end

  def grok_api_key
    ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY']
  end

  def claude_api_key
    ENV['CLAUDE_API_KEY']
  end
end
```

---

## Refactored app.rb structure

**Before** (962 lines):
```ruby
class SmartProxyApp < Sinatra::Base
  # 42 lines configuration
  # 8 lines before filter
  # 2 lines health endpoint
  # 88 lines model listing endpoint
  # 312 lines chat completions endpoint (inline orchestration, transformation, error handling)
  # 52 lines proxy/tools endpoint
  # 44 lines proxy/generate endpoint
  # 14 private methods (414 lines)
end
```

**After** (< 350 lines):
```ruby
class SmartProxyApp < Sinatra::Base
  # Configuration (minimal)
  configure do
    disable :protection
    set :port, ENV['SMART_PROXY_PORT'] || 4567
    set :bind, '0.0.0.0'
    set :logging, true

    # Setup logger (delegate to Logger service in future)
    log_dir = File.join(settings.root, '..', 'log')
    Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
    $logger = Logger.new(File.join(log_dir, 'smart_proxy.log'), 'daily')
  end

  before do
    content_type :json
    @session_id = request.env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid

    unless request.path_info == '/health'
      RequestAuthenticator.new(
        auth_token: ENV['PROXY_AUTH_TOKEN'],
        request: request,
        logger: $logger
      ).authenticate!
    end
  end

  get '/health' do
    { status: 'ok' }.to_json
  end

  get '/v1/models' do
    aggregator = ModelAggregator.new(
      cache_ttl: settings.models_cache_ttl,
      cache: settings.models_cache,
      logger: $logger,
      session_id: @session_id
    )

    result = aggregator.list_models
    settings.models_cache = result[:cache]
    result[:payload].to_json
  rescue StandardError => e
    $logger.error({ event: 'models_endpoint_error', session_id: @session_id, error: e.message })
    fallback = settings.models_cache[:data] || { object: 'list', data: [] }
    fallback.to_json
  end

  post '/v1/chat/completions' do
    request_payload = parse_request_body

    $logger.info({ event: 'chat_request', session_id: @session_id, payload: Anonymizer.anonymize(request_payload) })

    # Route to provider
    router = ModelRouter.new(request_payload['model'])
    routing = router.determine_provider

    # Orchestrate tool loop if applicable
    orchestrator = ToolOrchestrator.new(
      executor: ToolExecutor.new(session_id: @session_id, logger: $logger, tools_opt_in: routing[:tools_opt_in]),
      max_loops: extract_max_loops_header,
      logger: $logger,
      session_id: @session_id
    )

    response = orchestrator.orchestrate(
      request_payload,
      provider: routing[:client],
      tools_opt_in: routing[:tools_opt_in]
    )

    # Transform response
    transformed = ResponseTransformer.to_openai_format(
      response,
      model: routing[:requested_model],
      streaming: request_payload['stream']
    )

    $logger.info({ event: 'chat_response', session_id: @session_id, status: response.status })

    status response.status
    content_type transformed[:content_type] if transformed[:content_type]
    transformed[:body]
  rescue JSON::ParserError => e
    handle_json_error(e)
  rescue StandardError => e
    handle_internal_error(e)
  end

  # ... other endpoints (simplified similarly)

  private

  def parse_request_body
    request.body.rewind if request.body.respond_to?(:rewind)
    JSON.parse(request.body.read)
  end

  def extract_max_loops_header
    header_val = request.env['HTTP_X_SMART_PROXY_MAX_LOOPS']
    header_val.to_s.strip.empty? ? nil : Integer(header_val)
  end

  def handle_json_error(error)
    # Minimal error formatting
  end

  def handle_internal_error(error)
    # Minimal error formatting
  end

  run! if app_file == $0
end
```

---

## Testing strategy

### Unit tests (new)
Create RSpec tests for each service:

**New test files**:
- `smart_proxy/spec/lib/response_transformer_spec.rb`
- `smart_proxy/spec/lib/tool_orchestrator_spec.rb`
- `smart_proxy/spec/lib/tool_executor_spec.rb`
- `smart_proxy/spec/lib/model_router_spec.rb`
- `smart_proxy/spec/lib/model_aggregator_spec.rb`
- `smart_proxy/spec/lib/request_authenticator_spec.rb`

### Integration tests (existing)
- Existing tests in `smart_proxy/spec/app_spec.rb` continue to work
- Tests verify end-to-end HTTP behavior
- No changes to test assertions (backward compatibility)

### Acceptance criteria for testing
- All existing tests pass without modification
- New service unit tests achieve 100% coverage
- Integration tests verify service delegation

---

## File structure after refactoring

```
smart_proxy/
  app.rb (< 350 lines, HTTP routing only)
  lib/
    response_transformer.rb (~80 lines)
    tool_orchestrator.rb (~100 lines)
    tool_executor.rb (~120 lines)
    model_router.rb (~60 lines)
    model_aggregator.rb (~80 lines)
    request_authenticator.rb (~40 lines)
    ollama_client.rb (existing, 95 lines)
    grok_client.rb (existing, 48 lines)
    claude_client.rb (existing, 167 lines)
    live_search.rb (existing, 138 lines)
    anonymizer.rb (existing, 29 lines)
    tool_client.rb (existing, 55 lines)
  spec/
    app_spec.rb (existing integration tests)
    lib/
      response_transformer_spec.rb (new)
      tool_orchestrator_spec.rb (new)
      tool_executor_spec.rb (new)
      model_router_spec.rb (new)
      model_aggregator_spec.rb (new)
      request_authenticator_spec.rb (new)
```

---

## Acceptance criteria

- AC1: `app.rb` reduced to < 350 lines (64% reduction from 962)
- AC2: Six new service classes created in `lib/` with clear responsibilities
- AC3: All existing integration tests pass without modification
- AC4: New unit tests added for each service (100% coverage)
- AC5: No changes to API contracts (endpoints, request/response formats)
- AC6: Response transformation logic fully testable without HTTP layer
- AC7: Tool orchestration reusable for PRD-AH-OLLAMA-TOOL-01
- AC8: YARD documentation added to all services
- AC9: No performance regression (< 5% latency increase)
- AC10: Code review confirms proper separation of concerns

---

## Benefits for PRD-AH-OLLAMA-TOOL-01

With this refactoring, implementing Ollama native tool calling becomes:

1. **OllamaClient** (already isolated):
   - Add `parse_tool_calls` method
   - Return tool_calls in response body

2. **ToolOrchestrator** (provider-agnostic):
   - No changes required (already handles tool loops)

3. **ResponseTransformer**:
   - Add normalization for Ollama tool_calls format
   - Map to OpenAI-compatible structure

4. **app.rb**:
   - Zero changes required

**Estimated effort**: 2-3 hours (vs 1-2 days without refactoring)

---

## Risks and mitigation

### Risk: Breaking existing API behavior
- **Mitigation**: Comprehensive integration tests; service layer is transparent to HTTP clients
- **Validation**: Run full test suite; test with real Rails caller

### Risk: Performance regression from additional layers
- **Mitigation**: Services are lightweight; benchmark before/after
- **Validation**: Measure P50/P99 latency on `/v1/chat/completions`

### Risk: Increased complexity for simple endpoints
- **Mitigation**: Keep service interfaces simple; only extract when clear benefit
- **Validation**: Code review for unnecessary abstraction

### Risk: Lost Sinatra context in services
- **Mitigation**: Pass necessary context (session_id, logger) explicitly
- **Validation**: Ensure no implicit dependencies on Sinatra globals

---

## Success metrics

- Lines of code: app.rb reduced from 962 to < 350 (64% reduction)
- Method count: Reduced from 14 to ~5 in app.rb
- Test isolation: Services testable in < 0.1s each (vs 1-5s for integration)
- Maintainability: Each service < 120 lines
- PRD-AH-OLLAMA-TOOL-01: Implementation time reduced from 2 days to 3 hours

---

## Out of scope

- Changing API contracts or response formats
- Modifying client behavior (Rails app, Continue, etc.)
- Adding new features (tool calling, etc.)
- Performance optimization (beyond preventing regression)
- Replacing Sinatra with another framework

---

## Rollout plan

1. Create feature branch `refactor/extract-smart-proxy-logic`
2. Implement Steps 1-8 incrementally with tests
3. Run full RSpec suite after each step
4. Code review with 1+ approver
5. Test with Rails app in development environment
6. Merge to main after CI passes
7. Monitor production logs for 24 hours
8. Rollback if any API behavior changes detected
