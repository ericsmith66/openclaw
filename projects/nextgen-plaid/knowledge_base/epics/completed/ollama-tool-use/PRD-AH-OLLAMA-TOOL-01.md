# PRD-AH-OLLAMA-TOOL-01: Tool Schema Acceptance and Validation

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: High

---

## Overview

Make /v1/chat/completions accept and strictly validate OpenAI-compatible tools
before forwarding to Ollama.

---

## Problem Statement

Without validation:
- Invalid tools schemas cause cryptic errors from Ollama
- Tools with missing required fields fail silently
- Too many tools (>20) cause performance issues
- Error messages lack specificity (hard to debug)

GOAL:
Fail fast with clear error messages at SmartProxy boundary before calling Ollama.

---

## Requirements

### Functional Requirements

1. Validate tools array structure:
   - Must be an Array
   - Maximum 20 tools allowed
2. For each tool, validate:
   - tool.type must equal "function"
   - tool.function must be an object (Hash)
   - tool.function.name must be present and non-empty string
   - tool.function.parameters must be an object (Hash)
3. Raise ArgumentError with path-specific error on validation failure
4. Log validation success at DEBUG level

### Error Handling

- On validation failure: Raise ArgumentError with detailed message
- Error format: "tools[INDEX].FIELD is PROBLEM"
- Examples:
  - "tools[2].type must be 'function'"
  - "tools[0].function.name is required"
  - "maximum 20 tools allowed"

### Response Format (from app.rb)

HTTP 400 JSON response:
```json
{
  "error": "invalid_tools_schema",
  "message": "tools[2].function.name is required",
  "provider": "ollama"
}
```

---

## Implementation

### Location

FILE: smart_proxy/lib/ollama_client.rb
METHOD: validate_tools_schema! (private)
CALLED FROM: validate_and_gate_tools method

### Code Reference

```ruby
def validate_tools_schema!(tools)
  raise ArgumentError, "tools must be an array" unless tools.is_a?(Array)
  raise ArgumentError, "maximum 20 tools allowed" if tools.length > 20

  tools.each_with_index do |tool, index|
    unless tool.is_a?(Hash) && tool['type'] == 'function'
      raise ArgumentError, "tools[#{index}].type must be 'function'"
    end

    function = tool['function']
    unless function.is_a?(Hash)
      raise ArgumentError, "tools[#{index}].function must be an object"
    end

    if function['name'].to_s.strip.empty?
      raise ArgumentError, "tools[#{index}].function.name is required"
    end

    unless function['parameters'].is_a?(Hash)
      raise ArgumentError, "tools[#{index}].function.parameters must be an object"
    end
  end

  log_debug(event: 'tools_validated', count: tools.length)
end
```

### App.rb Integration (Optional Early Check)

FILE: smart_proxy/app.rb
LOCATION: After line 135 in post '/v1/chat/completions'

```ruby
# Validate tools schema early if present
if request_payload['tools']
  begin
    validate_tools_schema!(request_payload['tools']) if routing[:use_ollama]
  rescue ArgumentError => e
    $logger.error({
      event: 'tools_validation_failed_early',
      session_id: @session_id,
      error: e.message
    })
    status 400
    halt {
      error: 'invalid_tools_schema',
      message: e.message,
      provider: 'ollama'
    }.to_json
  end
end
```

---

## Acceptance Criteria

- [ ] Valid tools -> proceed to client without error
- [ ] Invalid type field -> 400 with "tools[N].type must be 'function'"
- [ ] Missing function name -> 400 with "tools[N].function.name is required"
- [ ] Missing parameters -> 400 with "tools[N].function.parameters must be an object"
- [ ] >20 tools -> 400 with "maximum 20 tools allowed"
- [ ] No tools -> no validation error (skip validation)
- [ ] Validation success logged at DEBUG level

---

## Test Cases

### Unit Tests (spec/ollama_client_spec.rb)

```ruby
describe '#validate_tools_schema!' do
  it 'accepts valid tools array' do
    tools = [
      {
        'type' => 'function',
        'function' => {
          'name' => 'search',
          'description' => 'Search the web',
          'parameters' => {
            'type' => 'object',
            'properties' => {
              'query' => { 'type' => 'string' }
            },
            'required' => ['query']
          }
        }
      }
    ]

    expect {
      client.send(:validate_tools_schema!, tools)
    }.not_to raise_error
  end

  it 'rejects tools without type function' do
    tools = [
      {
        'type' => 'invalid',
        'function' => {
          'name' => 'search',
          'parameters' => {}
        }
      }
    ]

    expect {
      client.send(:validate_tools_schema!, tools)
    }.to raise_error(ArgumentError, "tools[0].type must be 'function'")
  end

  it 'rejects tools without function name' do
    tools = [
      {
        'type' => 'function',
        'function' => {
          'name' => '',
          'parameters' => {}
        }
      }
    ]

    expect {
      client.send(:validate_tools_schema!, tools)
    }.to raise_error(ArgumentError, "tools[0].function.name is required")
  end

  it 'rejects tools without parameters object' do
    tools = [
      {
        'type' => 'function',
        'function' => {
          'name' => 'search',
          'parameters' => nil
        }
      }
    ]

    expect {
      client.send(:validate_tools_schema!, tools)
    }.to raise_error(ArgumentError, "tools[0].function.parameters must be an object")
  end

  it 'rejects more than 20 tools' do
    tools = Array.new(21) do |i|
      {
        'type' => 'function',
        'function' => {
          'name' => "tool_#{i}",
          'parameters' => {}
        }
      }
    end

    expect {
      client.send(:validate_tools_schema!, tools)
    }.to raise_error(ArgumentError, "maximum 20 tools allowed")
  end

  it 'provides path-specific error messages' do
    tools = [
      {
        'type' => 'function',
        'function' => { 'name' => 'valid', 'parameters' => {} }
      },
      {
        'type' => 'function',
        'function' => { 'name' => 'also_valid', 'parameters' => {} }
      },
      {
        'type' => 'function',
        'function' => { 'name' => '', 'parameters' => {} }  # Invalid at index 2
      }
    ]

    expect {
      client.send(:validate_tools_schema!, tools)
    }.to raise_error(ArgumentError, "tools[2].function.name is required")
  end

  it 'logs validation success' do
    expect(client).to receive(:log_debug).with(
      event: 'tools_validated',
      count: 1
    )

    tools = [
      {
        'type' => 'function',
        'function' => {
          'name' => 'search',
          'parameters' => {}
        }
      }
    ]

    client.send(:validate_tools_schema!, tools)
  end
end
```

### Integration Tests (spec/app_spec.rb)

```ruby
describe 'POST /v1/chat/completions with invalid tools' do
  it 'returns 400 for tools without function name' do
    post '/v1/chat/completions', {
      model: 'llama3.1:70b',
      messages: [
        { role: 'user', content: 'Hello' }
      ],
      tools: [
        {
          type: 'function',
          function: {
            name: '',
            parameters: {}
          }
        }
      ]
    }.to_json, { 'CONTENT_TYPE' => 'application/json' }

    expect(last_response.status).to eq(400)
    body = JSON.parse(last_response.body)
    expect(body['error']).to eq('invalid_tools_schema')
    expect(body['message']).to include('function.name is required')
  end

  it 'returns 200 for valid tools' do
    stub_ollama_request

    post '/v1/chat/completions', {
      model: 'llama3.1:70b',
      messages: [
        { role: 'user', content: 'Hello' }
      ],
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

---

## Log Requirements

### Log Format

DEBUG level when validation succeeds:
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "DEBUG",
  "event": "tools_validated",
  "count": 3
}
```

ERROR level when validation fails:
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "ERROR",
  "event": "tools_validation_failed",
  "error": "tools[2].function.name is required",
  "tools_sent": 3
}
```

---

## Dependencies

- None (can be implemented independently)

---

## Success Metrics

- 100% of invalid tools schemas rejected before Ollama call
- Zero cryptic errors from Ollama due to invalid tools
- All error messages include specific path and problem
- Validation overhead <1ms for typical payloads
