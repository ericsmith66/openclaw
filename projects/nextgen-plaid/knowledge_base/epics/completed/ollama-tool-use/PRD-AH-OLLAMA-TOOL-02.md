# PRD-AH-OLLAMA-TOOL-02: Gated Tool Forwarding with Model Selector

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: High

---

## Overview

Conditionally forward validated tools to Ollama and select tool-optimized model
based on tool presence and environment configuration.

---

## Problem Statement

Without gating and model selection:
- Tools forwarded even when experimental feature disabled
- Non-tool-optimized models used for tool calls (lower accuracy)
- No way to disable tools for testing/debugging
- Transient errors (5xx, 429) cause workflow failures

GOAL:
- Gate tool forwarding with environment flag
- Use tool-optimized model when tools present
- Retry transient errors automatically
- Log all decisions for observability

---

## Requirements

### Functional Requirements

#### Tool Gating
1. Check ENV['OLLAMA_TOOLS_ENABLED'] (default: 'true')
2. If 'false': Drop tools from payload and log at INFO level
3. If 'true': Forward validated tools to Ollama
4. Always validate first (fail fast) before checking gate

#### Model Selection
1. If tools present and ENV['OLLAMA_TOOL_MODEL'] set:
   - Use tool-optimized model (e.g., llama3-groq-tool-use:70b)
2. Else if ENV['OLLAMA_MODEL'] set:
   - Use configured default model
3. Else:
   - Use hardcoded default: llama3.1:70b
4. If explicit model requested (not 'ollama' or nil):
   - Respect user's choice
5. Log model selection decision at DEBUG level

#### Retry Logic
1. Use Faraday retry middleware
2. Retry on: 429, 500, 502, 503, 504
3. Max retries: 3
4. Backoff: exponential (2s, 5s, 11s)
5. Randomness: 0.5 (jitter)

---

## Implementation

### Location

FILE: smart_proxy/lib/ollama_client.rb
METHODS:
- validate_and_gate_tools (private)
- select_model (private)
- connection (private) - with retry middleware

### Code Reference

#### Tool Gating

```ruby
def validate_and_gate_tools(tools)
  return nil unless tools.is_a?(Array)

  # Validate schema first (PRD-01)
  validate_tools_schema!(tools)

  # Check environment gate (PRD-02)
  unless ENV.fetch('OLLAMA_TOOLS_ENABLED', 'true') == 'true'
    log_info(
      event: 'tools_dropped_disabled',
      count: tools.length,
      reason: 'OLLAMA_TOOLS_ENABLED=false'
    )
    return nil
  end

  log_debug(
    event: 'tools_forwarded',
    count: tools.length,
    names: tools.map { |t| t.dig('function', 'name') }
  )

  tools
end
```

#### Model Selection

```ruby
def select_model(requested_model, has_tools:)
  env_model = ENV['OLLAMA_MODEL']
  env_model = nil if env_model.nil? || env_model.strip.empty?

  # If explicit model requested, use it
  return requested_model unless requested_model == 'ollama' || requested_model.nil?

  # Default: llama3.1:70b for general use
  default_model = env_model || 'llama3.1:70b'

  # If tools present, prefer groq-tool-use model if configured
  if has_tools && ENV['OLLAMA_TOOL_MODEL']
    tool_model = ENV['OLLAMA_TOOL_MODEL']
    log_debug(
      event: 'model_selected_for_tools',
      model: tool_model,
      reason: 'tools_present'
    )
    return tool_model
  end

  default_model
end
```

#### Connection with Retry

```ruby
def connection
  @connection ||= Faraday.new(url: @url) do |f|
    f.request :json
    f.options.timeout = ENV.fetch('OLLAMA_TIMEOUT', '120').to_i
    f.options.open_timeout = 10
    f.request :retry, {
      max: 3,
      interval: 2,
      interval_randomness: 0.5,
      backoff_factor: 2,
      retry_statuses: [429, 500, 502, 503, 504]
    }
    f.adapter Faraday.default_adapter
  end
end
```

#### Integration in chat_completions

```ruby
def chat_completions(payload)
  # STEP 1: Normalize (PRD-00)
  normalized_payload = normalize_tool_arguments_in_payload(payload)

  # STEP 2: Validate and gate tools (PRD-01, PRD-02)
  if normalized_payload['tools']
    validated_tools = validate_and_gate_tools(normalized_payload['tools'])
    normalized_payload['tools'] = validated_tools
    normalized_payload.delete('tools') if validated_tools.nil?
  end

  # STEP 3: Select model (PRD-02)
  normalized_payload['model'] = select_model(
    normalized_payload['model'],
    has_tools: normalized_payload['tools']&.any?
  )

  # ... rest of method ...
end
```

---

## Acceptance Criteria

- [ ] Tools + flag true -> tools in Ollama payload
- [ ] Flag false -> tools dropped, logged, content-only request
- [ ] Model selection: tool-optimized model used when tools present and configured
- [ ] Model selection: default model used when no tools or OLLAMA_TOOL_MODEL not set
- [ ] Model selection: explicit model respected (not overridden)
- [ ] Retries attempted on 5xx/429 errors
- [ ] Max 3 retries with exponential backoff
- [ ] All decisions logged appropriately

---

## Test Cases

### Unit Tests (spec/ollama_client_spec.rb)

```ruby
describe '#validate_and_gate_tools' do
  context 'when gate enabled' do
    before { ENV['OLLAMA_TOOLS_ENABLED'] = 'true' }

    it 'forwards tools' do
      tools = [
        {
          'type' => 'function',
          'function' => { 'name' => 'search', 'parameters' => {} }
        }
      ]

      result = client.send(:validate_and_gate_tools, tools)
      expect(result).to eq(tools)
    end

    it 'logs forwarding event' do
      expect(client).to receive(:log_debug).with(
        event: 'tools_forwarded',
        count: 1,
        names: ['search']
      )

      tools = [
        {
          'type' => 'function',
          'function' => { 'name' => 'search', 'parameters' => {} }
        }
      ]

      client.send(:validate_and_gate_tools, tools)
    end
  end

  context 'when gate disabled' do
    before { ENV['OLLAMA_TOOLS_ENABLED'] = 'false' }

    it 'drops tools' do
      tools = [
        {
          'type' => 'function',
          'function' => { 'name' => 'search', 'parameters' => {} }
        }
      ]

      result = client.send(:validate_and_gate_tools, tools)
      expect(result).to be_nil
    end

    it 'logs drop event' do
      expect(client).to receive(:log_info).with(
        event: 'tools_dropped_disabled',
        count: 1,
        reason: 'OLLAMA_TOOLS_ENABLED=false'
      )

      tools = [
        {
          'type' => 'function',
          'function' => { 'name' => 'search', 'parameters' => {} }
        }
      ]

      client.send(:validate_and_gate_tools, tools)
    end
  end
end

describe '#select_model' do
  it 'uses tool model when tools present and configured' do
    ENV['OLLAMA_TOOL_MODEL'] = 'llama3-groq-tool-use:70b'

    result = client.send(:select_model, 'ollama', has_tools: true)
    expect(result).to eq('llama3-groq-tool-use:70b')
  end

  it 'uses default model when no tools' do
    ENV['OLLAMA_MODEL'] = 'llama3.1:70b'

    result = client.send(:select_model, 'ollama', has_tools: false)
    expect(result).to eq('llama3.1:70b')
  end

  it 'respects explicit model requests' do
    ENV['OLLAMA_TOOL_MODEL'] = 'llama3-groq-tool-use:70b'

    result = client.send(:select_model, 'custom-model:latest', has_tools: true)
    expect(result).to eq('custom-model:latest')
  end

  it 'falls back to hardcoded default when no env vars' do
    ENV.delete('OLLAMA_MODEL')
    ENV.delete('OLLAMA_TOOL_MODEL')

    result = client.send(:select_model, 'ollama', has_tools: false)
    expect(result).to eq('llama3.1:70b')
  end

  it 'logs model selection for tools' do
    ENV['OLLAMA_TOOL_MODEL'] = 'llama3-groq-tool-use:70b'

    expect(client).to receive(:log_debug).with(
      event: 'model_selected_for_tools',
      model: 'llama3-groq-tool-use:70b',
      reason: 'tools_present'
    )

    client.send(:select_model, 'ollama', has_tools: true)
  end
end
```

### Integration Tests

```ruby
describe '#chat_completions with retry' do
  it 'retries on 5xx errors' do
    stub_request(:post, 'http://localhost:11434/api/chat')
      .to_return(status: 500)
      .times(2)
      .then
      .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

    result = client.chat_completions({
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }]
    })

    expect(result.status).to eq(200)
  end

  it 'retries on 429 rate limit' do
    stub_request(:post, 'http://localhost:11434/api/chat')
      .to_return(status: 429)
      .times(1)
      .then
      .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

    result = client.chat_completions({
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }]
    })

    expect(result.status).to eq(200)
  end

  it 'gives up after max retries' do
    stub_request(:post, 'http://localhost:11434/api/chat')
      .to_return(status: 500)
      .times(4)

    result = client.chat_completions({
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }]
    })

    expect(result.status).to eq(500)
  end
end
```

### Mock HTTP Tests

```ruby
it 'sends correct payload with tools when gate enabled' do
  ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

  stub_request(:post, 'http://localhost:11434/api/chat')
    .with { |req|
      body = JSON.parse(req.body)
      body['tools'].is_a?(Array) && body['tools'].length == 1
    }
    .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

  client.chat_completions({
    'model' => 'ollama',
    'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
    'tools' => [
      {
        'type' => 'function',
        'function' => { 'name' => 'search', 'parameters' => {} }
      }
    ]
  })
end

it 'omits tools when gate disabled' do
  ENV['OLLAMA_TOOLS_ENABLED'] = 'false'

  stub_request(:post, 'http://localhost:11434/api/chat')
    .with { |req|
      body = JSON.parse(req.body)
      body['tools'].nil?
    }
    .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

  client.chat_completions({
    'model' => 'ollama',
    'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
    'tools' => [
      {
        'type' => 'function',
        'function' => { 'name' => 'search', 'parameters' => {} }
      }
    ]
  })
end
```

---

## Log Requirements

### Log Format

INFO level when tools dropped:
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "INFO",
  "event": "tools_dropped_disabled",
  "count": 3,
  "reason": "OLLAMA_TOOLS_ENABLED=false"
}
```

DEBUG level when tools forwarded:
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "DEBUG",
  "event": "tools_forwarded",
  "count": 3,
  "names": ["search", "execute", "analyze"]
}
```

DEBUG level for model selection:
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "DEBUG",
  "event": "model_selected_for_tools",
  "model": "llama3-groq-tool-use:70b",
  "reason": "tools_present"
}
```

---

## Dependencies

- PRD-01 (validation must happen before gating)

---

## Success Metrics

- 100% compliance with OLLAMA_TOOLS_ENABLED flag
- Tool-optimized model used for 100% of tool requests when configured
- Transient errors recovered via retry >95% of the time
- Zero unintended model selection (explicit models always respected)
