# PRD-AH-OLLAMA-TOOL-05: Enhanced Logging for Tool Flows

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: Medium

---

## Overview

Comprehensive debug logging across tool-related events for observability and
troubleshooting.

---

## Problem Statement

Without detailed logging:
- Hard to debug tool flow issues
- Can't trace tool forwarding decisions
- No visibility into normalization
- Parse errors go unnoticed
- Model selection opaque

GOAL:
Log all key events at appropriate levels following junie-log-requirement.md format.

---

## Requirements

### Functional Requirements

#### Log Events to Capture

1. tool_arguments_normalized (DEBUG)
   - count: number of tool calls normalized
   - provider: 'ollama'

2. tools_validated (DEBUG)
   - count: number of tools validated

3. tools_forwarded (DEBUG)
   - count: number of tools forwarded
   - names: array of tool names

4. tools_dropped_disabled (INFO)
   - count: number of tools dropped
   - reason: 'OLLAMA_TOOLS_ENABLED=false'

5. model_selected_for_tools (DEBUG)
   - model: selected model name
   - reason: 'tools_present'

6. tool_calls_parsed_from_ollama (DEBUG)
   - count: number of tool_calls parsed
   - tool_calls: array of {id, function, arguments_valid}

7. tool_call_argument_parse_error (WARN)
   - error: parse error message
   - raw: raw argument string

8. streaming_rejected_with_tools (WARN)
   - session_id: current session
   - provider: 'ollama'
   - error: error message

9. tools_validation_failed (ERROR)
   - session_id: current session
   - error: validation error message
   - tools_sent: number of tools in payload

### Log Format

- Follow knowledge_base/prds/prds-junie-log/junie-log-requirement.md
- JSON structured logging
- Include timestamp, severity, event
- PII anonymization via lib/anonymizer.rb (already applied in app.rb)

### Log Levels

- DEBUG: Normal operations (validation, forwarding, parsing, model selection)
- INFO: Feature gates applied (tools dropped)
- WARN: Recoverable errors (parse errors, streaming rejection)
- ERROR: Validation failures

---

## Implementation

### Location

FILE: smart_proxy/lib/ollama_client.rb
METHODS: log_debug, log_info, log_warn (private helpers)

### Code Reference

#### Logging Helpers

```ruby
def log_debug(data)
  $logger&.debug(data) if defined?($logger)
end

def log_info(data)
  $logger&.info(data) if defined?($logger)
end

def log_warn(data)
  $logger&.warn(data) if defined?($logger)
end
```

#### Usage Examples

Throughout OllamaClient:

```ruby
# In normalize_tool_arguments_in_payload
if normalized_count > 0
  log_debug(
    event: 'tool_arguments_normalized',
    count: normalized_count,
    provider: 'ollama'
  )
end

# In validate_tools_schema!
log_debug(event: 'tools_validated', count: tools.length)

# In validate_and_gate_tools (gate disabled)
log_info(
  event: 'tools_dropped_disabled',
  count: tools.length,
  reason: 'OLLAMA_TOOLS_ENABLED=false'
)

# In validate_and_gate_tools (gate enabled)
log_debug(
  event: 'tools_forwarded',
  count: tools.length,
  names: tools.map { |t| t.dig('function', 'name') }
)

# In select_model
log_debug(
  event: 'model_selected_for_tools',
  model: tool_model,
  reason: 'tools_present'
)

# In parse_tool_calls_if_present
log_debug(
  event: 'tool_calls_parsed_from_ollama',
  count: body['message']['tool_calls'].length,
  tool_calls: body['message']['tool_calls'].map { |t| {
    id: t['id'],
    function: t.dig('function', 'name'),
    arguments_valid: !t.dig('function', 'arguments', 'error')
  }}
)

# In parse_tool_call (on error)
log_warn(
  event: 'tool_call_argument_parse_error',
  error: e.message,
  raw: args
)
```

#### App.rb Logging (validation failure)

```ruby
$logger.error({
  event: 'tools_validation_failed_early',
  session_id: @session_id,
  error: e.message,
  tools_sent: request_payload['tools'].length
})
```

#### App.rb Logging (streaming rejection)

```ruby
$logger.warn({
  event: 'streaming_rejected_with_tools',
  session_id: @session_id,
  provider: 'ollama',
  error: e.message
})
```

---

## Acceptance Criteria

- [ ] All key events logged at appropriate level
- [ ] PII anonymized (handled by app.rb before logging)
- [ ] Logs include session_id, correlation_id where available
- [ ] JSON structured format
- [ ] Logs queryable for debugging
- [ ] No sensitive data in logs (tool arguments may contain PII)

---

## Test Cases

### Unit Tests (spec/ollama_client_spec.rb)

```ruby
describe 'logging' do
  let(:mock_logger) { instance_double(Logger) }

  before do
    $logger = mock_logger
  end

  it 'logs normalization at DEBUG' do
    expect(mock_logger).to receive(:debug).with(
      event: 'tool_arguments_normalized',
      count: 1,
      provider: 'ollama'
    )

    payload = {
      'messages' => [
        {
          'role' => 'assistant',
          'tool_calls' => [
            {
              'function' => {
                'name' => 'search',
                'arguments' => '{"query": "test"}'
              }
            }
          ]
        }
      ]
    }

    client.send(:normalize_tool_arguments_in_payload, payload)
  end

  it 'logs validation at DEBUG' do
    expect(mock_logger).to receive(:debug).with(
      event: 'tools_validated',
      count: 1
    )

    tools = [
      {
        'type' => 'function',
        'function' => { 'name' => 'search', 'parameters' => {} }
      }
    ]

    client.send(:validate_tools_schema!, tools)
  end

  it 'logs tools dropped at INFO' do
    ENV['OLLAMA_TOOLS_ENABLED'] = 'false'

    expect(mock_logger).to receive(:info).with(
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

  it 'logs tools forwarded at DEBUG' do
    ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

    expect(mock_logger).to receive(:debug).with(
      event: 'tools_forwarded',
      count: 2,
      names: ['search', 'execute']
    )

    tools = [
      {
        'type' => 'function',
        'function' => { 'name' => 'search', 'parameters' => {} }
      },
      {
        'type' => 'function',
        'function' => { 'name' => 'execute', 'parameters' => {} }
      }
    ]

    client.send(:validate_and_gate_tools, tools)
  end

  it 'logs model selection at DEBUG' do
    ENV['OLLAMA_TOOL_MODEL'] = 'llama3-groq-tool-use:70b'

    expect(mock_logger).to receive(:debug).with(
      event: 'model_selected_for_tools',
      model: 'llama3-groq-tool-use:70b',
      reason: 'tools_present'
    )

    client.send(:select_model, 'ollama', has_tools: true)
  end

  it 'logs parse errors at WARN' do
    expect(mock_logger).to receive(:warn).with(
      event: 'tool_call_argument_parse_error',
      error: kind_of(String),
      raw: 'invalid json'
    )

    ollama_tc = {
      'function' => {
        'name' => 'search',
        'arguments' => 'invalid json'
      }
    }

    client.send(:parse_tool_call, ollama_tc)
  end

  it 'logs tool_calls parsed at DEBUG' do
    expect(mock_logger).to receive(:debug).with(
      event: 'tool_calls_parsed_from_ollama',
      count: 1,
      tool_calls: [{
        id: kind_of(String),
        function: 'search',
        arguments_valid: true
      }]
    )

    body = {
      'message' => {
        'tool_calls' => [
          {
            'function' => {
              'name' => 'search',
              'arguments' => { 'query' => 'test' }
            }
          }
        ]
      }
    }

    client.send(:parse_tool_calls_if_present, body)
  end
end
```

### Integration Tests

```ruby
describe 'log output' do
  it 'logs appear in log/smart_proxy.log' do
    # This test requires real logger setup
    # Verify logs are written to file in correct JSON format
    # Check for presence of all expected events
  end

  it 'includes session_id when available' do
    # Verify session_id propagates through to logs
  end

  it 'handles missing logger gracefully' do
    $logger = nil

    expect {
      client.send(:log_debug, event: 'test')
    }.not_to raise_error
  end
end
```

---

## Log Format Examples

### DEBUG: tool_arguments_normalized
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "DEBUG",
  "event": "tool_arguments_normalized",
  "count": 2,
  "provider": "ollama"
}
```

### DEBUG: tools_validated
```json
{
  "timestamp": "2026-01-16T10:30:45Z",
  "severity": "DEBUG",
  "event": "tools_validated",
  "count": 3
}
```

### DEBUG: tools_forwarded
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "DEBUG",
  "event": "tools_forwarded",
  "count": 3,
  "names": ["search", "execute", "analyze"]
}
```

### INFO: tools_dropped_disabled
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "INFO",
  "event": "tools_dropped_disabled",
  "count": 3,
  "reason": "OLLAMA_TOOLS_ENABLED=false"
}
```

### DEBUG: model_selected_for_tools
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "DEBUG",
  "event": "model_selected_for_tools",
  "model": "llama3-groq-tool-use:70b",
  "reason": "tools_present"
}
```

### DEBUG: tool_calls_parsed_from_ollama
```json
{
  "timestamp": "2026-01-16T10:30:47Z",
  "severity": "DEBUG",
  "event": "tool_calls_parsed_from_ollama",
  "count": 2,
  "tool_calls": [
    {
      "id": "call_abc123def456",
      "function": "search",
      "arguments_valid": true
    },
    {
      "id": "call_789xyz012abc",
      "function": "execute",
      "arguments_valid": false
    }
  ]
}
```

### WARN: tool_call_argument_parse_error
```json
{
  "timestamp": "2026-01-16T10:30:47Z",
  "severity": "WARN",
  "event": "tool_call_argument_parse_error",
  "error": "unexpected token at 'invalid'",
  "raw": "invalid"
}
```

### WARN: streaming_rejected_with_tools
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

### ERROR: tools_validation_failed
```json
{
  "timestamp": "2026-01-16T10:30:46Z",
  "severity": "ERROR",
  "event": "tools_validation_failed_early",
  "session_id": "sess_abc123",
  "error": "tools[2].function.name is required",
  "tools_sent": 3
}
```

---

## Dependencies

- knowledge_base/prds/prds-junie-log/junie-log-requirement.md (log format spec)
- lib/anonymizer.rb (PII anonymization, already integrated in app.rb)

---

## Success Metrics

- All 9 event types logged at appropriate levels
- Logs queryable by event type
- Zero sensitive data leaks in logs
- <1ms overhead for logging operations
- Logs useful for debugging 95%+ of issues
