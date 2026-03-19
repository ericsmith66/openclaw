# PRD-AH-OLLAMA-TOOL-04: Streaming Restrictions and Error Handling

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: High

---

## Overview

Prevent tool calls in streaming mode (Ollama limitation) with clear error
handling at SmartProxy boundary.

---

## Problem Statement

Ollama does not support streaming when tools are present:
- Streaming + tools causes undefined behavior
- No clear error message to user
- May partially stream then error
- Wastes compute resources

GOAL:
Fail fast with clear error message before calling Ollama.

---

## Requirements

### Functional Requirements

1. In OllamaClient.chat_completions:
   - Check if stream:true AND tools present
   - If both: Raise ArgumentError before Ollama call
2. Error message: "Ollama does not support streaming with tool calls"
3. In app.rb:
   - Catch ArgumentError during orchestrate call
   - Return HTTP 400 with clear error response
4. Log rejection at WARN level

### Non-Functional Requirements

- Fail immediately (no Ollama call)
- Clear error message for debugging
- Proper HTTP status (400 Bad Request)
- Logged for observability

---

## Implementation

### Location

FILE: smart_proxy/lib/ollama_client.rb
LOCATION: STEP 4 in chat_completions method

FILE: smart_proxy/app.rb
LOCATION: Wrap orchestrate call (around line 170)

### Code Reference

#### OllamaClient Check

```ruby
def chat_completions(payload)
  # ... steps 1-3 ...

  # STEP 4: Enforce non-streaming for tools (PRD-04)
  if normalized_payload['stream'] == true && normalized_payload['tools']&.any?
    raise ArgumentError, "Ollama does not support streaming with tool calls"
  end

  # STEP 5: Ensure stream: false (Ollama API requirement)
  normalized_payload['stream'] = false

  # ... rest of method ...
end
```

#### App.rb Error Handling

```ruby
begin
  response = orchestrator.orchestrate(
    upstream_payload,
    routing: routing,
    max_loops: max_loops_override
  )
rescue ArgumentError => e
  if e.message.include?('streaming with tool calls')
    $logger.warn({
      event: 'streaming_rejected_with_tools',
      session_id: @session_id,
      provider: 'ollama',
      error: e.message
    })
    status 400
    halt {
      error: 'streaming_not_supported_with_tools',
      message: e.message,
      provider: 'ollama'
    }.to_json
  end
  raise
end
```

---

## Acceptance Criteria

- [ ] Streaming + tools -> 400 rejection before Ollama call
- [ ] Streaming no tools -> proceeds normally
- [ ] Non-streaming + tools -> proceeds normally
- [ ] Error message clear and actionable
- [ ] Logged at WARN level with context
- [ ] No Ollama call made when rejected

---

## Test Cases

### Unit Tests (spec/ollama_client_spec.rb)

```ruby
describe '#chat_completions' do
  it 'raises ArgumentError for streaming + tools' do
    payload = {
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
      'stream' => true,
      'tools' => [
        {
          'type' => 'function',
          'function' => { 'name' => 'search', 'parameters' => {} }
        }
      ]
    }

    expect {
      client.chat_completions(payload)
    }.to raise_error(ArgumentError, /streaming with tool calls/)
  end

  it 'allows streaming without tools' do
    stub_request(:post, 'http://localhost:11434/api/chat')
      .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

    payload = {
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
      'stream' => true
    }

    expect {
      client.chat_completions(payload)
    }.not_to raise_error
  end

  it 'allows non-streaming with tools' do
    stub_request(:post, 'http://localhost:11434/api/chat')
      .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

    payload = {
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
      'stream' => false,
      'tools' => [
        {
          'type' => 'function',
          'function' => { 'name' => 'search', 'parameters' => {} }
        }
      ]
    }

    expect {
      client.chat_completions(payload)
    }.not_to raise_error
  end

  it 'forces stream to false' do
    stub_request(:post, 'http://localhost:11434/api/chat')
      .with { |req|
        body = JSON.parse(req.body)
        body['stream'] == false
      }
      .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

    payload = {
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
      'stream' => true  # Will be forced to false
    }

    client.chat_completions(payload)
  end
end
```

### Integration Tests (spec/app_spec.rb)

```ruby
describe 'POST /v1/chat/completions' do
  it 'rejects streaming with tools' do
    post '/v1/chat/completions', {
      model: 'llama3.1:70b',
      messages: [
        { role: 'user', content: 'Hello' }
      ],
      stream: true,
      tools: [
        {
          type: 'function',
          function: {
            name: 'search',
            parameters: { type: 'object', properties: {} }
          }
        }
      ]
    }.to_json, { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(400)
    body = JSON.parse(last_response.body)
    expect(body['error']).to eq('streaming_not_supported_with_tools')
    expect(body['message']).to include('streaming with tool calls')
    expect(body['provider']).to eq('ollama')
  end

  it 'accepts streaming without tools' do
    stub_ollama_streaming_request

    post '/v1/chat/completions', {
      model: 'llama3.1:70b',
      messages: [
        { role: 'user', content: 'Hello' }
      ],
      stream: true
    }.to_json, { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(200)
  end

  it 'accepts non-streaming with tools' do
    stub_ollama_request

    post '/v1/chat/completions', {
      model: 'llama3.1:70b',
      messages: [
        { role: 'user', content: 'Hello' }
      ],
      stream: false,
      tools: [
        {
          type: 'function',
          function: {
            name: 'search',
            parameters: { type: 'object', properties: {} }
          }
        }
      ]
    }.to_json, { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(200)
  end
end
```

### Smoke Tests (test/smoke/smart_proxy_live_test.rb)

```ruby
def test_ollama_rejects_streaming_with_tools
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      { role: "user", content: "Hello" }
    ],
    stream: true,
    tools: [
      {
        type: "function",
        function: {
          name: "noop",
          description: "No-op",
          parameters: { type: "object", properties: {}, required: [] }
        }
      }
    ]
  })

  assert_equal 400, res.code.to_i
  body = JSON.parse(res.body)
  assert_equal 'streaming_not_supported_with_tools', body['error']
  assert body['message'].include?('streaming with tool calls')
end

def test_ollama_accepts_streaming_without_tools
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      { role: "user", content: "Hello" }
    ],
    stream: true
  })

  assert [200, 201].include?(res.code.to_i), "Expected 200/201, got #{res.code}"
end

def test_ollama_accepts_non_streaming_with_tools
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      { role: "user", content: "Hello" }
    ],
    stream: false,
    tools: [
      {
        type: "function",
        function: {
          name: "noop",
          description: "No-op",
          parameters: { type: "object", properties: {}, required: [] }
        }
      }
    ]
  })

  assert_equal 200, res.code.to_i
end
```

---

## Log Requirements

### Log Format

WARN level when streaming rejected:
```json
{
  "timestamp": "2026-01-16T10:30:48Z",
  "severity": "WARN",
  "event": "streaming_rejected_with_tools",
  "session_id": "sess_abc123",
  "provider": "ollama",
  "error": "Ollama does not support streaming with tool calls"
}
```

---

## Error Response Format

HTTP 400 Bad Request:
```json
{
  "error": "streaming_not_supported_with_tools",
  "message": "Ollama does not support streaming with tool calls",
  "provider": "ollama"
}
```

---

## Dependencies

- PRD-02 (tools must be present in payload to trigger check)

---

## Success Metrics

- Zero Ollama calls with streaming + tools combination
- 100% of rejected requests return HTTP 400 with clear message
- All rejections logged at WARN level
- No impact on streaming-only or tools-only requests
