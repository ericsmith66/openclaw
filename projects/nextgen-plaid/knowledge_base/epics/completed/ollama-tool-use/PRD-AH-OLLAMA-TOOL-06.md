# PRD-AH-OLLAMA-TOOL-06: Comprehensive Tests and Acceptance Criteria

Epic: EPIC-AH-OLLAMA-TOOL-USE
Status: Ready for Implementation
Priority: High

---

## Overview

Full regression and coverage suite for the tool refactor.

---

## Problem Statement

Without comprehensive tests:
- Regressions may slip through
- Edge cases remain untested
- Hard to refactor with confidence
- Behavior changes undetected

GOAL:
- 90%+ coverage on new code
- Regression suite passes
- Mixed-provider history test passes
- Edge cases covered (parse errors, network failures, validation failures)

---

## Requirements

### Functional Requirements

#### Test Coverage Targets
- OllamaClient: 95%+ (all methods tested)
- ResponseTransformer updates: 100% (critical path)
- App.rb integration: 90%+ (error handling paths)
- Overall new code: 90%+

#### Test Types
1. Unit tests: Individual method behavior
2. Integration tests: Full round-trip with VCR/WebMock
3. Smoke tests: Real Ollama integration (gated by ENV)
4. Regression tests: Existing functionality unchanged

#### Test Scenarios to Cover
1. String args -> Hash conversion (normalization)
2. Bad JSON -> error object
3. Valid tools validation
4. Invalid tools rejection (all validation rules)
5. Tools gate enabled/disabled
6. Model selection (with/without tools)
7. Retry on 5xx/429
8. Tool calls parsing (valid/invalid)
9. Streaming + tools rejection
10. Mixed-provider histories
11. Response transformation with tool_calls

---

## Implementation

### Location

NEW FILE: smart_proxy/spec/ollama_client_spec.rb
UPDATE: smart_proxy/spec/response_transformer_spec.rb
UPDATE: smart_proxy/spec/app_spec.rb
UPDATE: test/smoke/smart_proxy_live_test.rb

---

## Test Cases

### Unit Tests (spec/ollama_client_spec.rb)

```ruby
require 'spec_helper'
require_relative '../lib/ollama_client'
require 'webmock/rspec'

RSpec.describe OllamaClient do
  let(:client) { described_class.new }

  describe '#normalize_tool_arguments_in_payload' do
    it 'converts string arguments to hash' do
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

      result = client.send(:normalize_tool_arguments_in_payload, payload)
      args = result['messages'][0]['tool_calls'][0]['function']['arguments']

      expect(args).to be_a(Hash)
      expect(args['query']).to eq('test')
    end

    it 'handles bad JSON gracefully' do
      payload = {
        'messages' => [
          {
            'role' => 'assistant',
            'tool_calls' => [
              {
                'function' => {
                  'name' => 'search',
                  'arguments' => 'invalid json'
                }
              }
            ]
          }
        ]
      }

      result = client.send(:normalize_tool_arguments_in_payload, payload)
      args = result['messages'][0]['tool_calls'][0]['function']['arguments']

      expect(args).to eq({})
    end

    it 'preserves hash arguments unchanged' do
      payload = {
        'messages' => [
          {
            'role' => 'assistant',
            'tool_calls' => [
              {
                'function' => {
                  'name' => 'search',
                  'arguments' => { 'query' => 'test' }
                }
              }
            ]
          }
        ]
      }

      result = client.send(:normalize_tool_arguments_in_payload, payload)
      args = result['messages'][0]['tool_calls'][0]['function']['arguments']

      expect(args).to be_a(Hash)
      expect(args['query']).to eq('test')
    end

    it 'handles messages without tool_calls' do
      payload = {
        'messages' => [
          { 'role' => 'user', 'content' => 'Hello' }
        ]
      }

      result = client.send(:normalize_tool_arguments_in_payload, payload)

      expect(result['messages'][0]['role']).to eq('user')
      expect(result['messages'][0]['content']).to eq('Hello')
    end

    it 'logs normalization count' do
      expect(client).to receive(:log_debug).with(
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
  end

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
          'function' => { 'name' => '', 'parameters' => {} }
        }
      ]

      expect {
        client.send(:validate_tools_schema!, tools)
      }.to raise_error(ArgumentError, "tools[2].function.name is required")
    end
  end

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
  end

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

      result = client.send(:parse_tool_calls_if_present, body)
      args = result['message']['tool_calls'][0]['function']['arguments']

      expect(args['error']).to eq('invalid_json')
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
  end

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

    it 'returns OpenStruct with status and body' do
      stub_request(:post, 'http://localhost:11434/api/chat')
        .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

      result = client.chat_completions({
        'model' => 'llama3.1:70b',
        'messages' => [{ 'role' => 'user', 'content' => 'Hello' }]
      })

      expect(result).to respond_to(:status)
      expect(result).to respond_to(:body)
      expect(result.status).to eq(200)
    end
  end
end
```

### Integration Tests (spec/response_transformer_spec.rb)

```ruby
require 'spec_helper'
require_relative '../lib/response_transformer'

RSpec.describe ResponseTransformer do
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

### Smoke Tests (test/smoke/smart_proxy_live_test.rb)

```ruby
def test_ollama_tool_calling_with_normalization
  res = http_post_json("/v1/chat/completions", {
    model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
    messages: [
      {
        role: "assistant",
        content: nil,
        tool_calls: [
          {
            id: "call_abc123",
            type: "function",
            function: {
              name: "search",
              arguments: '{"query": "test"}'  # STRING (Grok style)
            }
          }
        ]
      },
      {
        role: "tool",
        tool_call_id: "call_abc123",
        content: "Search result"
      },
      {
        role: "user",
        content: "Summarize that result"
      }
    ],
    stream: false
  })

  assert_equal 200, res.code.to_i
  body = JSON.parse(res.body)
  assert body.dig("choices", 0, "message", "content").present?
end

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

def test_ollama_invalid_tools_rejected
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
          name: "",  # Invalid: empty name
          parameters: {}
        }
      }
    ]
  })

  assert_equal 400, res.code.to_i
  body = JSON.parse(res.body)
  assert_equal 'invalid_tools_schema', body['error']
end
```

---

## Acceptance Criteria

- [ ] 90%+ coverage on new code (verified by SimpleCov or similar)
- [ ] Regression suite passes (existing tests green)
- [ ] Mixed-provider history test passes
- [ ] All edge cases covered (validation, parsing, retry, errors)
- [ ] VCR cassettes recorded for integration tests
- [ ] Smoke tests pass against real Ollama (when available)
- [ ] No flaky tests

---

## Test Execution

### Unit Tests
```bash
cd smart_proxy
bundle exec rspec spec/ollama_client_spec.rb
bundle exec rspec spec/response_transformer_spec.rb
```

### Integration Tests
```bash
cd smart_proxy
bundle exec rspec spec/app_spec.rb
```

### Smoke Tests (requires Ollama running)
```bash
cd test/smoke
ruby smart_proxy_live_test.rb
```

### Coverage Report
```bash
cd smart_proxy
COVERAGE=true bundle exec rspec
open coverage/index.html
```

---

## Dependencies

- All PRDs 00-05 (complete implementation)
- WebMock or VCR for HTTP mocking
- SimpleCov for coverage reporting
- Running Ollama instance for smoke tests

---

## Success Metrics

- 90%+ test coverage on new code
- Zero regressions in existing tests
- All edge cases covered
- Tests pass consistently (<1% flakiness)
- Coverage report shows critical paths tested
