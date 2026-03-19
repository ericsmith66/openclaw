require 'spec_helper'
require_relative '../../lib/ollama_client'

RSpec.describe OllamaClient do
  let(:logger) { instance_double(Logger) }
  let(:client) { OllamaClient.new(logger: logger) }

  describe '#normalize_tool_arguments_in_payload' do
    it 'converts string arguments to hash' do
      allow(logger).to receive(:debug)

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
      allow(logger).to receive(:debug)

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
      expect(logger).to receive(:debug).with(
        { event: 'tool_arguments_normalized', count: 1, provider: 'ollama' }.to_json
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

    it 'does not log when no normalization occurs' do
      expect(logger).not_to receive(:debug)

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

      client.send(:normalize_tool_arguments_in_payload, payload)
    end

    it 'handles multiple tool calls in one message' do
      expect(logger).to receive(:debug).with(
        { event: 'tool_arguments_normalized', count: 2, provider: 'ollama' }.to_json
      )

      payload = {
        'messages' => [
          {
            'role' => 'assistant',
            'tool_calls' => [
              {
                'function' => {
                  'name' => 'search',
                  'arguments' => '{"query": "test1"}'
                }
              },
              {
                'function' => {
                  'name' => 'calculate',
                  'arguments' => '{"expression": "2+2"}'
                }
              }
            ]
          }
        ]
      }

      result = client.send(:normalize_tool_arguments_in_payload, payload)

      args1 = result['messages'][0]['tool_calls'][0]['function']['arguments']
      args2 = result['messages'][0]['tool_calls'][1]['function']['arguments']

      expect(args1).to be_a(Hash)
      expect(args1['query']).to eq('test1')
      expect(args2).to be_a(Hash)
      expect(args2['expression']).to eq('2+2')
    end

    it 'handles multiple messages with tool calls' do
      expect(logger).to receive(:debug).with(
        { event: 'tool_arguments_normalized', count: 2, provider: 'ollama' }.to_json
      )

      payload = {
        'messages' => [
          {
            'role' => 'assistant',
            'tool_calls' => [
              {
                'function' => {
                  'name' => 'search',
                  'arguments' => '{"query": "test1"}'
                }
              }
            ]
          },
          {
            'role' => 'user',
            'content' => 'Continue'
          },
          {
            'role' => 'assistant',
            'tool_calls' => [
              {
                'function' => {
                  'name' => 'calculate',
                  'arguments' => '{"expression": "2+2"}'
                }
              }
            ]
          }
        ]
      }

      result = client.send(:normalize_tool_arguments_in_payload, payload)

      args1 = result['messages'][0]['tool_calls'][0]['function']['arguments']
      args2 = result['messages'][2]['tool_calls'][0]['function']['arguments']

      expect(args1).to be_a(Hash)
      expect(args1['query']).to eq('test1')
      expect(args2).to be_a(Hash)
      expect(args2['expression']).to eq('2+2')
    end

    it 'does not mutate original payload' do
      allow(logger).to receive(:debug)

      original_payload = {
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

      # Store original string reference
      original_args = original_payload['messages'][0]['tool_calls'][0]['function']['arguments']

      result = client.send(:normalize_tool_arguments_in_payload, original_payload)

      # Original should still be a string
      expect(original_payload['messages'][0]['tool_calls'][0]['function']['arguments']).to eq('{"query": "test"}')
      expect(original_payload['messages'][0]['tool_calls'][0]['function']['arguments']).to be_a(String)

      # Result should be a hash
      expect(result['messages'][0]['tool_calls'][0]['function']['arguments']).to be_a(Hash)
    end

    it 'handles empty messages array' do
      payload = { 'messages' => [] }

      result = client.send(:normalize_tool_arguments_in_payload, payload)

      expect(result['messages']).to eq([])
    end

    it 'handles payload without messages key' do
      payload = { 'model' => 'test' }

      result = client.send(:normalize_tool_arguments_in_payload, payload)

      expect(result).to eq({ 'model' => 'test' })
    end

    it 'handles nil messages' do
      payload = { 'messages' => nil }

      result = client.send(:normalize_tool_arguments_in_payload, payload)

      expect(result['messages']).to be_nil
    end
  end

  describe '#validate_tools_schema!' do
    it 'accepts valid tools array' do
      allow(logger).to receive(:debug)

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
              'required' => [ 'query' ]
            }
          }
        }
      ]

      expect {
        client.send(:validate_tools_schema!, tools)
      }.not_to raise_error
    end

    it 'rejects non-array tools' do
      expect {
        client.send(:validate_tools_schema!, 'not an array')
      }.to raise_error(ArgumentError, /tools must be an array/)
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
      }.to raise_error(ArgumentError, /tools\[0\]\.type must be 'function'/)
    end

    it 'rejects tools without function object' do
      tools = [
        {
          'type' => 'function',
          'function' => 'not an object'
        }
      ]

      expect {
        client.send(:validate_tools_schema!, tools)
      }.to raise_error(ArgumentError, /tools\[0\]\.function must be an object/)
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
      }.to raise_error(ArgumentError, /tools\[0\]\.function\.name is required/)
    end

    it 'rejects tools with nil function name' do
      tools = [
        {
          'type' => 'function',
          'function' => {
            'name' => nil,
            'parameters' => {}
          }
        }
      ]

      expect {
        client.send(:validate_tools_schema!, tools)
      }.to raise_error(ArgumentError, /tools\[0\]\.function\.name is required/)
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
      }.to raise_error(ArgumentError, /tools\[0\]\.function\.parameters must be an object/)
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
      }.to raise_error(ArgumentError, /maximum 20 tools allowed/)
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
      }.to raise_error(ArgumentError, /tools\[2\]\.function\.name is required/)
    end

    it 'logs validation success' do
      expect(logger).to receive(:debug).with(
        { event: 'tools_validated', count: 1 }.to_json
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

    it 'accepts exactly 20 tools' do
      allow(logger).to receive(:debug)

      tools = Array.new(20) do |i|
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
      }.not_to raise_error
    end
  end

  describe '#validate_and_gate_tools' do
    it 'validates and forwards tools when enabled' do
      allow(logger).to receive(:debug)
      ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

      tools = [
        {
          'type' => 'function',
          'function' => {
            'name' => 'search',
            'parameters' => {}
          }
        }
      ]

      result = client.send(:validate_and_gate_tools, tools)

      expect(result).to eq(tools)
    end

    it 'drops tools when disabled' do
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
      ENV['OLLAMA_TOOLS_ENABLED'] = 'false'

      tools = [
        {
          'type' => 'function',
          'function' => {
            'name' => 'search',
            'parameters' => {}
          }
        }
      ]

      result = client.send(:validate_and_gate_tools, tools)

      expect(result).to be_nil
    end

    it 'logs when tools are dropped' do
      allow(logger).to receive(:debug)
      expect(logger).to receive(:info).with(
        { event: 'tools_dropped_disabled', count: 1, reason: 'OLLAMA_TOOLS_ENABLED=false' }.to_json
      )
      ENV['OLLAMA_TOOLS_ENABLED'] = 'false'

      tools = [
        {
          'type' => 'function',
          'function' => {
            'name' => 'search',
            'parameters' => {}
          }
        }
      ]

      client.send(:validate_and_gate_tools, tools)
    end

    it 'logs when tools are forwarded' do
      expect(logger).to receive(:debug).with(
        { event: 'tools_validated', count: 1 }.to_json
      )
      expect(logger).to receive(:debug).with(
        { event: 'tools_forwarded', count: 1, names: [ 'search' ] }.to_json
      )
      ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

      tools = [
        {
          'type' => 'function',
          'function' => {
            'name' => 'search',
            'parameters' => {}
          }
        }
      ]

      client.send(:validate_and_gate_tools, tools)
    end

    it 'returns nil for non-array tools' do
      result = client.send(:validate_and_gate_tools, 'not an array')

      expect(result).to be_nil
    end

    it 'validates before checking gate' do
      ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

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
        client.send(:validate_and_gate_tools, tools)
      }.to raise_error(ArgumentError, /tools\[0\]\.type must be 'function'/)
    end

    it 'defaults to enabled when OLLAMA_TOOLS_ENABLED not set' do
      allow(logger).to receive(:debug)
      ENV.delete('OLLAMA_TOOLS_ENABLED')

      tools = [
        {
          'type' => 'function',
          'function' => {
            'name' => 'search',
            'parameters' => {}
          }
        }
      ]

      result = client.send(:validate_and_gate_tools, tools)

      expect(result).to eq(tools)
    end
  end

  describe '#select_model' do
    it 'uses tool model when tools present and configured' do
      ENV['OLLAMA_TOOL_MODEL'] = 'llama3-groq-tool-use:70b'
      allow(logger).to receive(:debug)

      result = client.send(:select_model, 'ollama', has_tools: true)

      expect(result).to eq('llama3-groq-tool-use:70b')
    end

    it 'uses default model when no tools' do
      ENV['OLLAMA_MODEL'] = 'llama3.1:70b'
      ENV.delete('OLLAMA_TOOL_MODEL')

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
      expect(logger).to receive(:debug).with(
        { event: 'model_selected_for_tools', model: 'llama3-groq-tool-use:70b', reason: 'tools_present' }.to_json
      )

      client.send(:select_model, 'ollama', has_tools: true)
    end

    it 'uses default model when tools present but OLLAMA_TOOL_MODEL not set' do
      ENV['OLLAMA_MODEL'] = 'llama3.1:70b'
      ENV.delete('OLLAMA_TOOL_MODEL')

      result = client.send(:select_model, 'ollama', has_tools: true)

      expect(result).to eq('llama3.1:70b')
    end

    it 'handles nil requested_model' do
      ENV['OLLAMA_MODEL'] = 'llama3.1:70b'
      ENV.delete('OLLAMA_TOOL_MODEL')

      result = client.send(:select_model, nil, has_tools: false)

      expect(result).to eq('llama3.1:70b')
    end

    it 'prefers tool model over default when both set and tools present' do
      ENV['OLLAMA_MODEL'] = 'llama3.1:70b'
      ENV['OLLAMA_TOOL_MODEL'] = 'llama3-groq-tool-use:70b'
      allow(logger).to receive(:debug)

      result = client.send(:select_model, 'ollama', has_tools: true)

      expect(result).to eq('llama3-groq-tool-use:70b')
    end
  end

  describe '#parse_tool_calls_if_present' do
    it 'returns body unchanged if no tool_calls present' do
      body = {
        'message' => {
          'role' => 'assistant',
          'content' => 'Hello'
        }
      }

      result = client.send(:parse_tool_calls_if_present, body)

      expect(result).to eq(body)
    end

    it 'returns body unchanged if tool_calls is not an array' do
      body = {
        'message' => {
          'role' => 'assistant',
          'content' => 'Hello',
          'tool_calls' => 'not an array'
        }
      }

      result = client.send(:parse_tool_calls_if_present, body)

      expect(result).to eq(body)
    end

    it 'parses tool_calls and generates OpenAI IDs' do
      allow(logger).to receive(:debug)

      body = {
        'message' => {
          'role' => 'assistant',
          'content' => nil,
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

      expect(result['message']['tool_calls']).to be_an(Array)
      expect(result['message']['tool_calls'].length).to eq(1)

      tool_call = result['message']['tool_calls'][0]
      expect(tool_call['id']).to match(/^call_[a-f0-9]{12}$/)
      expect(tool_call['type']).to eq('function')
      expect(tool_call['function']['name']).to eq('search')
      expect(tool_call['function']['arguments']).to eq({ 'query' => 'test' })
    end

    it 'logs parsed tool_calls' do
      expect(logger).to receive(:debug) do |json_string|
        data = JSON.parse(json_string)
        expect(data['event']).to eq('tool_calls_parsed_from_ollama')
        expect(data['count']).to eq(1)
        expect(data['tool_calls']).to be_an(Array)
        expect(data['tool_calls'].length).to eq(1)
      end

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

    it 'handles multiple tool_calls' do
      allow(logger).to receive(:debug)

      body = {
        'message' => {
          'tool_calls' => [
            {
              'function' => {
                'name' => 'search',
                'arguments' => '{"query": "test1"}'
              }
            },
            {
              'function' => {
                'name' => 'calculate',
                'arguments' => '{"expression": "2+2"}'
              }
            }
          ]
        }
      }

      result = client.send(:parse_tool_calls_if_present, body)

      expect(result['message']['tool_calls'].length).to eq(2)
      expect(result['message']['tool_calls'][0]['function']['name']).to eq('search')
      expect(result['message']['tool_calls'][1]['function']['name']).to eq('calculate')
    end

    it 'returns body unchanged if body is not a hash' do
      result = client.send(:parse_tool_calls_if_present, 'not a hash')

      expect(result).to eq('not a hash')
    end
  end

  describe '#parse_tool_call' do
    it 'generates OpenAI-style ID' do
      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => { 'query' => 'test' }
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['id']).to match(/^call_[a-f0-9]{12}$/)
    end

    it 'sets type to function' do
      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => { 'query' => 'test' }
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['type']).to eq('function')
    end

    it 'extracts function name' do
      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => { 'query' => 'test' }
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['function']['name']).to eq('search')
    end

    it 'parses string arguments to hash' do
      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => '{"query": "test", "limit": 10}'
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['function']['arguments']).to be_a(Hash)
      expect(result['function']['arguments']['query']).to eq('test')
      expect(result['function']['arguments']['limit']).to eq(10)
    end

    it 'preserves hash arguments unchanged' do
      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => { 'query' => 'test', 'limit' => 10 }
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['function']['arguments']).to be_a(Hash)
      expect(result['function']['arguments']['query']).to eq('test')
      expect(result['function']['arguments']['limit']).to eq(10)
    end

    it 'handles malformed JSON gracefully' do
      allow(logger).to receive(:warn)

      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => 'invalid json {'
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['function']['arguments']).to be_a(Hash)
      expect(result['function']['arguments']['error']).to eq('invalid_json')
      expect(result['function']['arguments']['raw']).to eq('invalid json {')
      expect(result['function']['arguments']['parse_error']).to be_a(String)
    end

    it 'logs parse errors at WARN level' do
      expect(logger).to receive(:warn) do |json_string|
        data = JSON.parse(json_string)
        expect(data['event']).to eq('tool_call_argument_parse_error')
        expect(data['error']).to be_a(String)
        expect(data['raw']).to eq('invalid json')
      end

      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => 'invalid json'
        }
      }

      client.send(:parse_tool_call, tool_call)
    end

    it 'handles empty string arguments' do
      allow(logger).to receive(:warn)

      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => ''
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['function']['arguments']).to be_a(Hash)
      expect(result['function']['arguments']['error']).to eq('invalid_json')
    end

    it 'handles nil arguments' do
      tool_call = {
        'function' => {
          'name' => 'search',
          'arguments' => nil
        }
      }

      result = client.send(:parse_tool_call, tool_call)

      expect(result['function']['arguments']).to be_nil
    end
  end

  describe '#chat_completions streaming restrictions' do
    it 'raises ArgumentError when stream:true and tools present' do
      allow(logger).to receive(:debug)
      ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

      payload = {
        'model' => 'llama3.1:70b',
        'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
        'stream' => true,
        'tools' => [
          {
            'type' => 'function',
            'function' => {
              'name' => 'search',
              'parameters' => {}
            }
          }
        ]
      }

      expect {
        client.chat_completions(payload)
      }.to raise_error(ArgumentError, 'Ollama does not support streaming with tool calls')
    end

    it 'allows stream:true when no tools present' do
      stub_request(:post, 'http://localhost:11434/api/chat')
        .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

      payload = {
        'model' => 'llama3.1:70b',
        'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
        'stream' => true
      }

      expect {
        client.chat_completions(payload)
      }.not_to raise_error
    end

    it 'allows stream:false with tools present' do
      allow(logger).to receive(:debug)
      ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

      stub_request(:post, 'http://localhost:11434/api/chat')
        .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

      payload = {
        'model' => 'llama3.1:70b',
        'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
        'stream' => false,
        'tools' => [
          {
            'type' => 'function',
            'function' => {
              'name' => 'search',
              'parameters' => {}
            }
          }
        ]
      }

      expect {
        client.chat_completions(payload)
      }.not_to raise_error
    end

    it 'allows stream:true when tools disabled by gate' do
      allow(logger).to receive(:debug)
      allow(logger).to receive(:info)
      ENV['OLLAMA_TOOLS_ENABLED'] = 'false'

      stub_request(:post, 'http://localhost:11434/api/chat')
        .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

      payload = {
        'model' => 'llama3.1:70b',
        'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
        'stream' => true,
        'tools' => [
          {
            'type' => 'function',
            'function' => {
              'name' => 'search',
              'parameters' => {}
            }
          }
        ]
      }

      expect {
        client.chat_completions(payload)
      }.not_to raise_error
    end

    it 'allows when stream key missing and tools present' do
      allow(logger).to receive(:debug)
      ENV['OLLAMA_TOOLS_ENABLED'] = 'true'

      stub_request(:post, 'http://localhost:11434/api/chat')
        .to_return(status: 200, body: { message: { content: 'ok' } }.to_json)

      payload = {
        'model' => 'llama3.1:70b',
        'messages' => [ { 'role' => 'user', 'content' => 'Hello' } ],
        'tools' => [
          {
            'type' => 'function',
            'function' => {
              'name' => 'search',
              'parameters' => {}
            }
          }
        ]
      }

      expect {
        client.chat_completions(payload)
      }.not_to raise_error
    end
  end

  describe '#list_models' do
    let(:tags_url) { 'http://localhost:11434/api/tags' }

    let(:ollama_model_response) do
      {
        'models' => [
          {
            'name'        => 'llama3.1:70b',
            'modified_at' => '2024-05-01T12:00:00Z',
            'size'        => 123_456_789,
            'digest'      => 'sha256:abc123',
            'details'     => { 'family' => 'llama', 'parameter_size' => '70B' }
          },
          {
            'name'        => 'mistral:7b',
            'modified_at' => '2024-06-15T08:30:00Z',
            'size'        => 4_567_890,
            'digest'      => 'sha256:def456',
            'details'     => { 'family' => 'mistral', 'parameter_size' => '7B' }
          }
        ]
      }
    end

    it 'returns an array of model hashes with all common format keys' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)

      result.each do |model|
        expect(model).to have_key(:id)
        expect(model).to have_key(:object)
        expect(model).to have_key(:owned_by)
        expect(model).to have_key(:created)
        expect(model).to have_key(:smart_proxy)
      end
    end

    it 'sets object to "model" for each entry' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      result.each do |model|
        expect(model[:object]).to eq('model')
      end
    end

    it 'sets owned_by to "ollama" for each entry' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      result.each do |model|
        expect(model[:owned_by]).to eq('ollama')
      end
    end

    it 'maps id from the Ollama model name field' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result[0][:id]).to eq('llama3.1:70b')
      expect(result[1][:id]).to eq('mistral:7b')
    end

    it 'sets created as an integer Unix timestamp parsed from modified_at' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      result.each do |model|
        expect(model[:created]).to be_an(Integer)
        expect(model[:created]).to be > 0
      end

      expect(result[0][:created]).to eq(Time.parse('2024-05-01T12:00:00Z').to_i)
      expect(result[1][:created]).to eq(Time.parse('2024-06-15T08:30:00Z').to_i)
    end

    it 'includes provider key in smart_proxy set to "ollama"' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      result.each do |model|
        expect(model[:smart_proxy]).to be_a(Hash)
        expect(model[:smart_proxy]).to have_key(:provider)
        expect(model[:smart_proxy][:provider]).to eq('ollama')
      end
    end

    it 'includes size and digest in smart_proxy when present' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result[0][:smart_proxy][:size]).to eq(123_456_789)
      expect(result[0][:smart_proxy][:digest]).to eq('sha256:abc123')
    end

    it 'includes details in smart_proxy when present' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result[0][:smart_proxy][:details]).to eq({ 'family' => 'llama', 'parameter_size' => '70B' })
    end

    it 'omits nil optional fields from smart_proxy via compact' do
      sparse_response = {
        'models' => [
          {
            'name'        => 'phi3:mini',
            'modified_at' => '2024-07-01T00:00:00Z',
            'size'        => nil,
            'digest'      => nil,
            'details'     => nil
          }
        ]
      }

      stub_request(:get, tags_url)
        .to_return(status: 200, body: sparse_response.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result[0][:smart_proxy]).to eq({ provider: 'ollama' })
    end

    it 'returns an empty array when the models list is empty' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: { 'models' => [] }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result).to eq([])
    end

    it 'returns an empty array when models key is absent from response' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: {}.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.list_models

      expect(result).to eq([])
    end

    it 'returns [] and logs a warning on HTTP error response' do
      stub_request(:get, tags_url)
        .to_return(status: 500, body: 'Internal Server Error')

      expect(logger).to receive(:warn) do |payload|
        expect(payload[:event]).to eq('ollama_list_models_error')
        expect(payload[:error]).to be_a(String)
      end

      result = client.list_models

      expect(result).to eq([])
    end

    it 'returns [] and logs a warning on connection failure' do
      stub_request(:get, tags_url)
        .to_raise(Faraday::ConnectionFailed.new('Connection refused'))

      expect(logger).to receive(:warn) do |payload|
        expect(payload[:event]).to eq('ollama_list_models_error')
        expect(payload[:error]).to be_a(String)
      end

      result = client.list_models

      expect(result).to eq([])
    end

    it 'returns [] and logs a warning on malformed JSON response body' do
      stub_request(:get, tags_url)
        .to_return(status: 200, body: 'not valid json{{{', headers: { 'Content-Type' => 'application/json' })

      expect(logger).to receive(:warn) do |payload|
        expect(payload[:event]).to eq('ollama_list_models_error')
        expect(payload[:error]).to be_a(String)
      end

      result = client.list_models

      expect(result).to eq([])
    end

    it 'respects OLLAMA_TAGS_URL env var when set' do
      custom_url = 'http://custom-ollama:11434/api/tags'
      ENV['OLLAMA_TAGS_URL'] = custom_url

      stub_request(:get, custom_url)
        .to_return(status: 200, body: ollama_model_response.to_json, headers: { 'Content-Type' => 'application/json' })

      # Instantiate a fresh client so tags_connection picks up the env var
      fresh_client = OllamaClient.new(logger: logger)
      result = fresh_client.list_models

      expect(result.length).to eq(2)
      expect(result[0][:id]).to eq('llama3.1:70b')
    ensure
      ENV.delete('OLLAMA_TAGS_URL')
    end
  end
end
