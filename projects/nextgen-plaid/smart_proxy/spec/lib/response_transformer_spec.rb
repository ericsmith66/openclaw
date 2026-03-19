require 'spec_helper'
require_relative '../../lib/response_transformer'

RSpec.describe ResponseTransformer do
  let(:model) { 'test-model' }

  describe '.to_openai_format' do
    context 'non-streaming' do
      it 'passes through OpenAI-compatible JSON and adds usage' do
        openai_json = {
          id: 'test-id',
          choices: [ { message: { content: 'hello' } } ]
        }.to_json

        result = ResponseTransformer.to_openai_format(openai_json, model: model, streaming: false)

        expect(result[:content_type]).to eq('application/json')
        parsed = JSON.parse(result[:body])
        expect(parsed['choices'][0]['message']['content']).to eq('hello')
        expect(parsed['usage']).to be_a(Hash)
      end

      it 'converts Ollama JSON to OpenAI format' do
        ollama_json = {
          model: 'ollama-model',
          created_at: Time.now.iso8601,
          message: { role: 'assistant', content: 'ollama response' },
          prompt_eval_count: 10,
          eval_count: 5
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: false)

        expect(result[:content_type]).to eq('application/json')
        parsed = JSON.parse(result[:body])
        expect(parsed['object']).to eq('chat.completion')
        expect(parsed['choices'][0]['message']['content']).to eq('ollama response')
        expect(parsed['usage']['total_tokens']).to eq(15)
        expect(parsed['model']).to eq(model)
      end

      it 'includes tool_calls in message when present' do
        ollama_json = {
          model: 'ollama-model',
          created_at: Time.now.iso8601,
          message: {
            role: 'assistant',
            content: nil,
            tool_calls: [
              {
                id: 'call_abc123',
                type: 'function',
                function: {
                  name: 'search',
                  arguments: { query: 'test' }
                }
              }
            ]
          },
          prompt_eval_count: 10,
          eval_count: 5
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: false)

        expect(result[:content_type]).to eq('application/json')
        parsed = JSON.parse(result[:body])
        expect(parsed['choices'][0]['message']['tool_calls']).to be_an(Array)
        expect(parsed['choices'][0]['message']['tool_calls'].length).to eq(1)
        expect(parsed['choices'][0]['message']['tool_calls'][0]['id']).to eq('call_abc123')
        expect(parsed['choices'][0]['message']['tool_calls'][0]['function']['name']).to eq('search')
      end

      it 'sets finish_reason to tool_calls when tool_calls present' do
        ollama_json = {
          model: 'ollama-model',
          created_at: Time.now.iso8601,
          message: {
            role: 'assistant',
            content: nil,
            tool_calls: [
              {
                id: 'call_abc123',
                type: 'function',
                function: {
                  name: 'search',
                  arguments: { query: 'test' }
                }
              }
            ]
          },
          prompt_eval_count: 10,
          eval_count: 5
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: false)

        parsed = JSON.parse(result[:body])
        expect(parsed['choices'][0]['finish_reason']).to eq('tool_calls')
      end

      it 'sets finish_reason to stop when no tool_calls' do
        ollama_json = {
          model: 'ollama-model',
          created_at: Time.now.iso8601,
          message: { role: 'assistant', content: 'response' },
          prompt_eval_count: 10,
          eval_count: 5
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: false)

        parsed = JSON.parse(result[:body])
        expect(parsed['choices'][0]['finish_reason']).to eq('stop')
      end

      it 'handles multiple tool_calls' do
        ollama_json = {
          model: 'ollama-model',
          created_at: Time.now.iso8601,
          message: {
            role: 'assistant',
            content: nil,
            tool_calls: [
              {
                id: 'call_abc123',
                type: 'function',
                function: { name: 'search', arguments: { query: 'test1' } }
              },
              {
                id: 'call_def456',
                type: 'function',
                function: { name: 'calculate', arguments: { expression: '2+2' } }
              }
            ]
          },
          prompt_eval_count: 10,
          eval_count: 5
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: false)

        parsed = JSON.parse(result[:body])
        expect(parsed['choices'][0]['message']['tool_calls'].length).to eq(2)
        expect(parsed['choices'][0]['message']['tool_calls'][0]['function']['name']).to eq('search')
        expect(parsed['choices'][0]['message']['tool_calls'][1]['function']['name']).to eq('calculate')
        expect(parsed['choices'][0]['finish_reason']).to eq('tool_calls')
      end

      it 'does not include tool_calls when empty array' do
        ollama_json = {
          model: 'ollama-model',
          created_at: Time.now.iso8601,
          message: {
            role: 'assistant',
            content: 'response',
            tool_calls: []
          },
          prompt_eval_count: 10,
          eval_count: 5
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: false)

        parsed = JSON.parse(result[:body])
        expect(parsed['choices'][0]['message']['tool_calls']).to be_nil
        expect(parsed['choices'][0]['finish_reason']).to eq('stop')
      end
    end

    context 'streaming' do
      it 'converts OpenAI-compatible JSON to SSE' do
        openai_json = {
          id: 'test-id',
          choices: [ { message: { content: 'hello' } } ]
        }.to_json

        result = ResponseTransformer.to_openai_format(openai_json, model: model, streaming: true)

        expect(result[:content_type]).to eq('text/event-stream')
        expect(result[:body]).to include('data: {"id":"test-id"')
        expect(result[:body]).to include('"delta":{"role":"assistant","content":"hello"}')
        expect(result[:body]).to include('data: [DONE]')
      end

      it 'converts Ollama JSON to SSE' do
        ollama_json = {
          message: { content: 'ollama stream' },
          created_at: Time.now.iso8601
        }.to_json

        result = ResponseTransformer.to_openai_format(ollama_json, model: model, streaming: true)

        expect(result[:content_type]).to eq('text/event-stream')
        expect(result[:body]).to include('"delta":{"role":"assistant","content":"ollama stream"}')
        expect(result[:body]).to include('data: [DONE]')
      end

      it 'passes through existing SSE data' do
        sse_data = "data: {\"choices\":[{\"delta\":{\"content\":\"chunk\"}}]}\n\n"

        result = ResponseTransformer.to_openai_format(sse_data, model: model, streaming: true)

        expect(result[:content_type]).to eq('text/event-stream')
        expect(result[:body]).to eq(sse_data)
      end
    end
  end
end
