# PRD-AH-OLLAMA-TOOL-03: Ollama Tool Calls Parsing to OpenAI Format

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: High

---

## Overview

Convert Ollama tool call responses to consistent OpenAI-compatible format for
seamless integration with ToolOrchestrator and Rails SmartProxyClient.

---

## Problem Statement

Ollama returns tool_calls in response, but:
- Format may differ from OpenAI's expected structure
- Missing call IDs (OpenAI requires them)
- Arguments may be strings (need parsing to Hash)
- No finish_reason='tool_calls' signal
- ResponseTransformer doesn't pass through tool_calls

GOAL:
- Parse Ollama tool_calls into OpenAI format
- Generate OpenAI-style call IDs
- Handle malformed JSON gracefully
- Update ResponseTransformer to include tool_calls in choices[0].message
- Set finish_reason='tool_calls' when present

---

## Requirements

### Functional Requirements

#### OllamaClient Parsing
1. Check if response.message.tool_calls exists
2. For each tool_call:
   - Generate OpenAI-style ID: "call_" + SecureRandom.hex(6)
   - Set type: "function"
   - Extract name from function.name
   - Parse arguments:
     - If String: JSON.parse to Hash
     - If parse fails: Create error object {error: 'invalid_json', raw: ..., parse_error: ...}
     - If already Hash: use as-is
3. Log parsed count and details at DEBUG level
4. Log parse errors at WARN level

#### ResponseTransformer Update
1. In ollama_to_openai method:
   - Check if message['tool_calls'] present and non-empty
   - Include tool_calls in choices[0].message hash
   - Set finish_reason to 'tool_calls' if tool_calls present, else 'stop'

### Error Handling

- Lenient: Don't fail on parse errors
- Insert error object in arguments instead
- Log warnings for troubleshooting
- Continue processing other tool_calls

---

## Implementation

### Location

FILE: smart_proxy/lib/ollama_client.rb
METHODS:
- parse_tool_calls_if_present (private)
- parse_tool_call (private)

FILE: smart_proxy/lib/response_transformer.rb
METHOD: ollama_to_openai (existing, update)

### Code Reference

#### OllamaClient Parsing

```ruby
def parse_tool_calls_if_present(body)
  return body unless body.is_a?(Hash)

  tool_calls = body.dig('message', 'tool_calls')
  return body unless tool_calls.is_a?(Array)

  body['message']['tool_calls'] = tool_calls.map do |tc|
    parse_tool_call(tc)
  end

  log_debug(
    event: 'tool_calls_parsed_from_ollama',
    count: body['message']['tool_calls'].length,
    tool_calls: body['message']['tool_calls'].map { |t| {
      id: t['id'],
      function: t.dig('function', 'name'),
      arguments_valid: !t.dig('function', 'arguments', 'error')
    }}
  )

  body
end

def parse_tool_call(ollama_tool_call)
  args = ollama_tool_call.dig('function', 'arguments')

  parsed_args = if args.is_a?(String)
    begin
      JSON.parse(args)
    rescue JSON::ParserError => e
      log_warn(
        event: 'tool_call_argument_parse_error',
        error: e.message,
        raw: args
      )
      {
        error: 'invalid_json',
        raw: args,
        parse_error: e.message
      }
    end
  else
    args
  end

  {
    id: "call_#{SecureRandom.hex(6)}",
    type: "function",
    function: {
      name: ollama_tool_call.dig('function', 'name'),
      arguments: parsed_args
    }
  }
end
```

#### ResponseTransformer Update

```ruby
def ollama_to_openai(parsed)
  msg = parsed['message'] || {}
  created = begin
    Time.parse(parsed['created_at'].to_s).to_i
  rescue StandardError
    Time.now.to_i
  end

  prompt_tokens = parsed['prompt_eval_count'].to_i
  completion_tokens = parsed['eval_count'].to_i
  total_tokens = prompt_tokens + completion_tokens

  # BUILD MESSAGE HASH
  message_hash = {
    role: msg['role'] || 'assistant',
    content: msg['content']
  }

  # ADD: Include tool_calls if present (NEW)
  if msg['tool_calls'].is_a?(Array) && msg['tool_calls'].any?
    message_hash['tool_calls'] = msg['tool_calls']
  end

  {
    id: "chatcmpl-#{SecureRandom.hex(8)}",
    object: 'chat.completion',
    created: created,
    model: @model.to_s.empty? ? parsed['model'] : @model,
    choices: [
      {
        index: 0,
        finish_reason: msg['tool_calls']&.any? ? 'tool_calls' : 'stop',  # UPDATED
        message: message_hash  # UPDATED
      }
    ],
    usage: {
      prompt_tokens: prompt_tokens,
      completion_tokens: completion_tokens,
      total_tokens: total_tokens
    },
    smart_proxy: {
      tool_loop: { loop_count: 0, max_loops: Integer(ENV.fetch('SMART_PROXY_MAX_LOOPS', '3')) },
      tools_used: []
    }
  }
end
```

#### Integration in chat_completions

```ruby
def chat_completions(payload)
  # ... steps 1-6 ...

  # STEP 7: Parse and transform response (PRD-03)
  body = JSON.parse(resp.body)
  body = parse_tool_calls_if_present(body)

  OpenStruct.new(status: resp.status, body: body)
rescue Faraday::Error => e
  handle_error(e)
end
```

---

## Acceptance Criteria

- [ ] Valid args -> Hash in output
- [ ] Invalid JSON -> error object in args + logged at WARN
- [ ] No tool_calls -> nil/empty array (no error)
- [ ] OpenAI-style IDs generated for all tool_calls
- [ ] ResponseTransformer includes tool_calls in message
- [ ] finish_reason='tool_calls' when tool_calls present
- [ ] finish_reason='stop' when no tool_calls
- [ ] Parse errors don't block response

---

## Test Cases

### Unit Tests (spec/ollama_client_spec.rb)

```ruby
describe '#parse_tool_calls_if_present' do
  it 'parses valid tool calls' do
    body = {
      'message' => {
        'tool_calls' => [
          {
            'function' => {
              'name' => 'search',
              'arguments' => '{"query": "test"}'
            }
          }
        ]
      }
    }

    result = client.send(:parse_tool_calls_if_present, body)
    tool_call = result['message']['tool_calls'][0]

    expect(tool_call['id']).to start_with('call_')
    expect(tool_call['type']).to eq('function')
    expect(tool_call['function']['name']).to eq('search')
    expect(tool_call['function']['arguments']).to eq({ 'query' => 'test' })
  end

  it 'handles parse errors gracefully' do
    body = {
      'message' => {
        'tool_calls' => [
          {
            'function' => {
              'name' => 'search',
              'arguments' => 'invalid json'
            }
          }
        ]
      }
    }

    expect(client).to receive(:log_warn)

    result = client.send(:parse_tool_calls_if_present, body)
    args = result['message']['tool_calls'][0]['function']['arguments']

    expect(args['error']).to eq('invalid_json')
    expect(args['raw']).to eq('invalid json')
    expect(args['parse_error']).to be_present
  end

  it 'generates OpenAI-style IDs' do
    body = {
      'message' => {
        'tool_calls' => [
          { 'function' => { 'name' => 'test', 'arguments' => {} } }
        ]
      }
    }

    result = client.send(:parse_tool_calls_if_present, body)
    tool_call = result['message']['tool_calls'][0]

    expect(tool_call['id']).to match(/^call_[0-9a-f]{12}$/)
  end

  it 'logs parsed count and details' do
    expect(client).to receive(:log_debug).with(
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

  it 'handles responses without tool_calls' do
    body = {
      'message' => {
        'content' => 'Hello'
      }
    }

    result = client.send(:parse_tool_calls_if_present, body)

    expect(result['message']['content']).to eq('Hello')
    expect(result['message']['tool_calls']).to be_nil
  end
end

describe '#parse_tool_call' do
  it 'parses string arguments to hash' do
    ollama_tc = {
      'function' => {
        'name' => 'search',
        'arguments' => '{"query": "test"}'
      }
    }

    result = client.send(:parse_tool_call, ollama_tc)

    expect(result['function']['arguments']).to eq({ 'query' => 'test' })
  end

  it 'preserves hash arguments' do
    ollama_tc = {
      'function' => {
        'name' => 'search',
        'arguments' => { 'query' => 'test' }
      }
    }

    result = client.send(:parse_tool_call, ollama_tc)

    expect(result['function']['arguments']).to eq({ 'query' => 'test' })
  end

  it 'creates error object for invalid JSON' do
    ollama_tc = {
      'function' => {
        'name' => 'search',
        'arguments' => 'not json'
      }
    }

    result = client.send(:parse_tool_call, ollama_tc)
    args = result['function']['arguments']

    expect(args['error']).to eq('invalid_json')
    expect(args['raw']).to eq('not json')
  end
end
```

### Integration Tests (spec/response_transformer_spec.rb)

```ruby
describe ResponseTransformer do
  describe '.ollama_to_openai' do
    it 'includes tool_calls in message when present' do
      response_body = {
        'message' => {
          'role' => 'assistant',
          'content' => 'Let me search for that',
          'tool_calls' => [
            {
              'id' => 'call_abc123',
              'type' => 'function',
              'function' => {
                'name' => 'search',
                'arguments' => { 'query' => 'test' }
              }
            }
          ]
        },
        'created_at' => '2026-01-16T10:30:00Z',
        'prompt_eval_count' => 10,
        'eval_count' => 20
      }

      result = ResponseTransformer.to_openai_format(
        response_body.to_json,
        model: 'llama3.1:70b',
        streaming: false
      )

      parsed = JSON.parse(result[:body])
      message = parsed['choices'][0]['message']

      expect(message['tool_calls']).to be_present
      expect(message['tool_calls'][0]['function']['name']).to eq('search')
    end

    it 'sets finish_reason to tool_calls when present' do
      response_body = {
        'message' => {
          'role' => 'assistant',
          'content' => '',
          'tool_calls' => [
            {
              'id' => 'call_abc123',
              'type' => 'function',
              'function' => {
                'name' => 'search',
                'arguments' => {}
              }
            }
          ]
        },
        'created_at' => '2026-01-16T10:30:00Z',
        'prompt_eval_count' => 10,
        'eval_count' => 20
      }

      result = ResponseTransformer.to_openai_format(
        response_body.to_json,
        model: 'llama3.1:70b',
        streaming: false
      )

      parsed = JSON.parse(result[:body])
      finish_reason = parsed['choices'][0]['finish_reason']

      expect(finish_reason).to eq('tool_calls')
    end

    it 'handles responses without tool_calls' do
      response_body = {
        'message' => {
          'role' => 'assistant',
          'content' => 'Hello'
        },
        'created_at' => '2026-01-16T10:30:00Z',
        'prompt_eval_count' => 10,
        'eval_count' => 20
      }

      result = ResponseTransformer.to_openai_format(
        response_body.to_json,
        model: 'llama3.1:70b',
        streaming: false
      )

      parsed = JSON.parse(result[:body])
      message = parsed['choices'][0]['message']
      finish_reason = parsed['choices'][0]['finish_reason']

      expect(message['tool_calls']).to be_nil
      expect(finish_reason).to eq('stop')
    end
  end
end
```

### Full Round-Trip Test

```ruby
describe 'full tool call response handling' do
  it 'parses Ollama response with tool_calls and transforms to OpenAI format' do
    ollama_response = {
      'message' => {
        'role' => 'assistant',
        'content' => '',
        'tool_calls' => [
          {
            'function' => {
              'name' => 'search',
              'arguments' => '{"query": "test"}'
            }
          }
        ]
      },
      'created_at' => '2026-01-16T10:30:00Z',
      'prompt_eval_count' => 10,
      'eval_count' => 20
    }

    stub_request(:post, 'http://localhost:11434/api/chat')
      .to_return(status: 200, body: ollama_response.to_json)

    result = client.chat_completions({
      'model' => 'llama3.1:70b',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }]
    })

    body = JSON.parse(result.body)
    tool_calls = body['message']['tool_calls']

    expect(tool_calls).to be_present
    expect(tool_calls[0]['id']).to start_with('call_')
    expect(tool_calls[0]['function']['arguments']).to eq({ 'query' => 'test' })
  end
end
```

---

## Log Requirements

### Log Format

DEBUG level when tool_calls parsed:
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
      "arguments_valid": true
    }
  ]
}
```

WARN level for parse errors:
```json
{
  "timestamp": "2026-01-16T10:30:47Z",
  "severity": "WARN",
  "event": "tool_call_argument_parse_error",
  "error": "unexpected token at 'invalid'",
  "raw": "invalid"
}
```

---

## Dependencies

- PRD-00 (normalization must happen before parsing)
- PRD-02 (tools must be forwarded to get responses with tool_calls)

---

## Success Metrics

- 100% of tool_calls have OpenAI-style IDs
- Parse errors logged but don't block responses
- ToolOrchestrator receives consistent format from all providers
- finish_reason correctly signals tool_calls presence
