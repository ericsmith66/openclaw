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

  let(:logger) { instance_double(Logger, warn: nil) }
  let(:client) { described_class.new(logger: logger) }

  let(:base_url)   { 'http://127.0.0.1:8765' }
  let(:chat_url)   { "#{base_url}/v1/chat/completions" }
  let(:models_url) { "#{base_url}/v1/models" }

  let(:api_model_payload) do
    {
      'object' => 'list',
      'data'   => [
        { 'id' => 'qwen3-coder-next-8bit', 'object' => 'model', 'created' => 1_720_000_000 },
        { 'id' => 'qwen2.5-coder-7b',      'object' => 'model', 'created' => 1_720_000_001 }
      ]
    }
  end

  # Payload with a filesystem-path model ID (as mlx_lm.server returns for locally cached models)
  let(:api_model_payload_with_path) do
    {
      'object' => 'list',
      'data'   => [
        { 'id' => '/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit', 'object' => 'model', 'created' => 1_720_000_000 },
        { 'id' => 'Qwen/Qwen2.5-Coder-7B-Instruct', 'object' => 'model', 'created' => 1_720_000_001 }
      ]
    }
  end

  let(:success_response) do
    {
      'id'      => 'chatcmpl-123',
      'object'  => 'chat.completion',
      'created' => 1_000,
      'model'   => 'qwen3-coder-next-8bit',
      'choices' => [{ 'index' => 0, 'message' => { 'role' => 'assistant', 'content' => 'Hi there!' }, 'finish_reason' => 'stop' }],
      'usage'   => { 'prompt_tokens' => 10, 'completion_tokens' => 5, 'total_tokens' => 15 }
    }
  end

  let(:base_payload) do
    {
      'model'    => 'qwen3-coder-next-8bit',
      'messages' => [{ 'role' => 'user', 'content' => 'Hello' }],
      'stream'   => false
    }
  end

  REQUIRED_MLX_MODEL_KEYS = %i[id object owned_by created smart_proxy].freeze

  # ---------------------------------------------------------------------------
  # #list_models
  # ---------------------------------------------------------------------------

  describe '#list_models' do
    context 'when API returns 200' do
      before do
        stub_request(:get, models_url)
          .to_return(status: 200, body: api_model_payload.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns an Array' do
        expect(client.list_models).to be_an(Array)
      end

      it 'returns one model per API data entry' do
        expect(client.list_models.size).to eq(2)
      end

      it 'prefixes every id with mlx/' do
        ids = client.list_models.map { |m| m[:id] }
        expect(ids).to contain_exactly('mlx/qwen3-coder-next-8bit', 'mlx/qwen2.5-coder-7b')
      end

      context 'when server returns filesystem-path model IDs' do
        before do
          stub_request(:get, models_url)
            .to_return(status: 200, body: api_model_payload_with_path.to_json, headers: { 'Content-Type' => 'application/json' })
        end

        it 'normalizes absolute paths to basename' do
          ids = client.list_models.map { |m| m[:id] }
          expect(ids).to include('mlx/qwen3-coder-next-8bit')
        end

        it 'does not expose the filesystem path in the id' do
          ids = client.list_models.map { |m| m[:id] }
          expect(ids).not_to include(a_string_matching(%r{/Users/}))
        end

        it 'leaves non-path ids unchanged' do
          ids = client.list_models.map { |m| m[:id] }
          expect(ids).to include('mlx/Qwen/Qwen2.5-Coder-7B-Instruct')
        end

        it 'does not produce a double mlx/ prefix' do
          ids = client.list_models.map { |m| m[:id] }
          expect(ids).not_to include(a_string_matching(/^mlx\/mlx\//))
        end
      end

      it 'sets owned_by to mlx' do
        expect(client.list_models.map { |m| m[:owned_by] }).to all(eq('mlx'))
      end

      it 'sets object to model' do
        expect(client.list_models.map { |m| m[:object] }).to all(eq('model'))
      end

      it 'sets created from API response' do
        expect(client.list_models.map { |m| m[:created] }).to contain_exactly(1_720_000_000, 1_720_000_001)
      end

      it 'sets smart_proxy provider to mlx' do
        expect(client.list_models.map { |m| m.dig(:smart_proxy, :provider) }).to all(eq('mlx'))
      end

      it 'every model has all required keys' do
        client.list_models.each do |model|
          expect(model.keys).to include(*REQUIRED_MLX_MODEL_KEYS)
        end
      end
    end

    context 'when server is unreachable' do
      %i[ConnectionFailed TimeoutError].each do |error_class|
        context "Faraday::#{error_class}" do
          before { stub_request(:get, models_url).to_raise(Faraday.const_get(error_class).new('error')) }

          it 'returns []' do
            expect(client.list_models).to eq([])
          end

          it 'does not propagate the exception' do
            expect { client.list_models }.not_to raise_error
          end

          it 'logs a warn event' do
            expect(logger).to receive(:warn).with(hash_including(event: 'mlx_list_models_error'))
            client.list_models
          end
        end
      end
    end

    context 'with non-200 HTTP status' do
      [401, 403, 404, 429, 500, 503].each do |status|
        it "returns [] for HTTP #{status}" do
          stub_request(:get, models_url).to_return(status: status, body: '')
          expect(client.list_models).to eq([])
        end
      end
    end

    context 'with empty data array' do
      before { stub_request(:get, models_url).to_return(status: 200, body: { 'data' => [] }.to_json) }

      it 'returns []' do
        expect(client.list_models).to eq([])
      end
    end

    context 'with missing data key' do
      before { stub_request(:get, models_url).to_return(status: 200, body: {}.to_json) }

      it 'returns []' do
        expect(client.list_models).to eq([])
      end
    end

    context 'with malformed JSON body' do
      before { stub_request(:get, models_url).to_return(status: 200, body: 'not-json{{{') }

      it 'returns []' do
        expect(client.list_models).to eq([])
      end

      it 'does not propagate the exception' do
        expect { client.list_models }.not_to raise_error
      end
    end

    context 'with missing created field' do
      before do
        stub_request(:get, models_url)
          .to_return(status: 200, body: { 'data' => [{ 'id' => 'test-model' }] }.to_json)
      end

      it 'falls back to Time.now for created' do
        expect(client.list_models.first[:created]).to be_within(5).of(Time.now.to_i)
      end
    end

    it 'uses the short-timeout models_connection (not chat_connection)' do
      expect(client.send(:models_connection).options.timeout).to eq(10)
    end
  end

  # ---------------------------------------------------------------------------
  # #chat_completions
  # ---------------------------------------------------------------------------

  describe '#chat_completions' do
    # Stub models endpoint for resolve_server_model (called on every chat_completions invocation)
    before do
      stub_request(:get, models_url)
        .to_return(status: 200, body: api_model_payload.to_json, headers: { 'Content-Type' => 'application/json' })
    end

    context '200 success' do
      before do
        stub_request(:post, chat_url)
          .to_return(status: 200, body: success_response.to_json, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns a response with status 200' do
        result = client.chat_completions(base_payload)
        expect(result.status).to eq(200)
      end

      it 'returns a parseable JSON body containing choices' do
        result = client.chat_completions(base_payload)
        expect(JSON.parse(result.body)).to have_key('choices')
      end

      it 'resolves the friendly model name to the server model ID' do
        stub = stub_request(:post, chat_url)
          .with(body: hash_including('model' => 'qwen3-coder-next-8bit'))
          .to_return(status: 200, body: success_response.to_json)
        client.chat_completions(base_payload)
        expect(stub).to have_been_requested
      end

      it 'passes tools through to the server unchanged' do
        tools = [{ 'type' => 'function', 'function' => { 'name' => 'search', 'parameters' => {} } }]
        stub = stub_request(:post, chat_url)
          .with(body: hash_including('tools' => tools))
          .to_return(status: 200, body: success_response.to_json)
        client.chat_completions(base_payload.merge('tools' => tools))
        expect(stub).to have_been_requested
      end

      it 'works with a model name that has no mlx/ prefix (already stripped by ModelRouter)' do
        stub = stub_request(:post, chat_url)
          .with(body: hash_including('model' => 'qwen3-coder-next-8bit'))
          .to_return(status: 200, body: success_response.to_json)
        client.chat_completions(base_payload)
        expect(stub).to have_been_requested
      end

      context 'when server uses filesystem-path model IDs' do
        before do
          stub_request(:get, models_url)
            .to_return(status: 200, body: api_model_payload_with_path.to_json,
                       headers: { 'Content-Type' => 'application/json' })
        end

        it 'resolves friendly basename to full filesystem path for chat request' do
          stub = stub_request(:post, chat_url)
            .with(body: hash_including('model' => '/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit'))
            .to_return(status: 200, body: success_response.to_json)
          client.chat_completions(base_payload)
          expect(stub).to have_been_requested
        end

        it 'falls back to first loaded model when requested name is unknown' do
          allow(logger).to receive(:info)
          unknown_payload = base_payload.merge('model' => 'unknown-model')
          stub = stub_request(:post, chat_url)
            .with(body: hash_including('model' => '/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit'))
            .to_return(status: 200, body: success_response.to_json)
          client.chat_completions(unknown_payload)
          expect(stub).to have_been_requested
        end
      end

      it 'does not mutate the original payload hash' do
        original_model = base_payload['model'].dup
        stub_request(:post, chat_url).to_return(status: 200, body: success_response.to_json)
        client.chat_completions(base_payload)
        expect(base_payload['model']).to eq(original_model)
      end
    end

    context 'on Faraday::Error' do
      %i[ConnectionFailed TimeoutError].each do |error_class|
        context "Faraday::#{error_class}" do
          before { stub_request(:post, chat_url).to_raise(Faraday.const_get(error_class).new('refused')) }

          it 'returns an OpenStruct with status 500' do
            result = client.chat_completions(base_payload)
            expect(result.status).to eq(500)
          end

          it 'returns a JSON-parseable body' do
            result = client.chat_completions(base_payload)
            expect { JSON.parse(result.body) }.not_to raise_error
            expect(JSON.parse(result.body)).to have_key('error')
          end

          it 'does not propagate the exception' do
            expect { client.chat_completions(base_payload) }.not_to raise_error
          end
        end
      end
    end

    context 'on non-200 HTTP response' do
      before { stub_request(:post, chat_url).to_return(status: 503, body: 'Service Unavailable') }

      it 'surfaces the upstream status' do
        result = client.chat_completions(base_payload)
        expect(result.status).to eq(503)
      end
    end

    it 'uses the long-timeout chat_connection' do
      expect(client.send(:chat_connection).options.timeout).to eq(600)
    end

    it 'respects MLX_TIMEOUT env var' do
      with_env('MLX_TIMEOUT', '30') do
        c = described_class.new
        expect(c.send(:chat_connection).options.timeout).to eq(30)
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
  # #normalize_model_id (private)
  # ---------------------------------------------------------------------------

  describe '#normalize_model_id (private)' do
    subject(:normalize) { ->(id) { client.send(:normalize_model_id, id) } }

    it 'strips absolute filesystem paths to their basename' do
      expect(normalize.call('/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit')).to eq('qwen3-coder-next-8bit')
    end

    it 'leaves relative/non-path IDs unchanged' do
      expect(normalize.call('Qwen/Qwen2.5-Coder-7B-Instruct')).to eq('Qwen/Qwen2.5-Coder-7B-Instruct')
    end

    it 'leaves simple short names unchanged' do
      expect(normalize.call('qwen3-coder-next-8bit')).to eq('qwen3-coder-next-8bit')
    end

    it 'handles a root-level path correctly' do
      expect(normalize.call('/model-name')).to eq('model-name')
    end
  end

  # ---------------------------------------------------------------------------
  # #model_map (private)
  # ---------------------------------------------------------------------------

  describe '#model_map (private)' do
    context 'when server returns models' do
      before do
        stub_request(:get, models_url)
          .to_return(status: 200, body: api_model_payload_with_path.to_json,
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'maps friendly basename to raw server ID' do
        expect(client.send(:model_map)['qwen3-coder-next-8bit']).to eq('/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit')
      end

      it 'also maps raw server ID to itself' do
        raw = '/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit'
        expect(client.send(:model_map)[raw]).to eq(raw)
      end

      it 'caches the result (makes only one HTTP request)' do
        client.send(:model_map)
        client.send(:model_map)
        expect(WebMock).to have_requested(:get, models_url).once
      end
    end

    context 'when server is unreachable' do
      before { stub_request(:get, models_url).to_raise(Faraday::ConnectionFailed.new('refused')) }

      it 'returns {}' do
        expect(client.send(:model_map)).to eq({})
      end

      it 'does not propagate the exception' do
        expect { client.send(:model_map) }.not_to raise_error
      end
    end

    context 'when server returns non-200' do
      before { stub_request(:get, models_url).to_return(status: 503, body: '') }

      it 'returns {}' do
        expect(client.send(:model_map)).to eq({})
      end
    end
  end

  # ---------------------------------------------------------------------------
  # #resolve_server_model (private)
  # ---------------------------------------------------------------------------

  describe '#resolve_server_model (private)' do
    let(:logger_with_info) { instance_double(Logger, warn: nil, info: nil) }
    let(:client_with_info_logger) { described_class.new(logger: logger_with_info) }

    before do
      stub_request(:get, models_url)
        .to_return(status: 200, body: api_model_payload_with_path.to_json,
                   headers: { 'Content-Type' => 'application/json' })
    end

    it 'resolves a friendly basename to the server path' do
      result = client.send(:resolve_server_model, 'qwen3-coder-next-8bit')
      expect(result).to eq('/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit')
    end

    it 'accepts the raw server ID directly' do
      raw = '/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit'
      expect(client.send(:resolve_server_model, raw)).to eq(raw)
    end

    it 'falls back to first model and logs info when name unknown' do
      expect(logger_with_info).to receive(:info).with(hash_including(event: 'mlx_model_fallback'))
      result = client_with_info_logger.send(:resolve_server_model, 'unknown-model')
      expect(result).to eq('/Users/ericsmith66/.cache/mlx-models/qwen3-coder-next-8bit')
    end

    it 'returns the requested model name unchanged when model_map is empty' do
      stub_request(:get, models_url).to_return(status: 503, body: '')
      allow(logger).to receive(:info)
      fresh_client = described_class.new(logger: logger)
      expect(fresh_client.send(:resolve_server_model, 'unknown-model')).to eq('unknown-model')
    end
  end
end
