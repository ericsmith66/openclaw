require 'spec_helper'
require_relative '../../lib/fireworks_client'

RSpec.describe FireworksClient do
  # -----------------------------------------------------------------------
  # Helpers – lightweight ENV isolation without climate_control gem
  # -----------------------------------------------------------------------

  # Temporarily set/clear one ENV key for the duration of a block.
  # Pass value: nil to ensure the key is deleted.
  def with_env(key, value)
    old_value    = ENV[key]
    old_existed  = ENV.key?(key)

    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value
    end

    yield
  ensure
    if old_existed
      ENV[key] = old_value
    else
      ENV.delete(key)
    end
  end

  # -----------------------------------------------------------------------
  # Shared fixtures
  # -----------------------------------------------------------------------

  let(:api_key) { 'test-fireworks-key' }
  let(:client)  { described_class.new(api_key: api_key) }

  # Effective URL: BASE_URL is 'https://api.fireworks.ai/inference/v1', GET path is '/v1/models'
  # Faraday resolves absolute path via URI#merge – 'https://api.fireworks.ai/v1/models'
  let(:models_url) { 'https://api.fireworks.ai/v1/models' }

  # Minimal but realistic Fireworks /v1/models response body
  let(:api_model_payload) do
    {
      'object' => 'list',
      'data'   => [
        { 'id' => 'llama4-maverick', 'object' => 'model', 'owned_by' => 'fireworks', 'created' => 1_700_000_000 },
        { 'id' => 'llama4-scout',    'object' => 'model', 'owned_by' => 'fireworks', 'created' => 1_700_000_001 }
      ]
    }
  end

  # Keys every normalised model hash must carry (T5 contract)
  REQUIRED_FIREWORKS_MODEL_KEYS = %i[id object owned_by created smart_proxy].freeze

  # -----------------------------------------------------------------------
  # T1 – returns normalised hash array on success (200)
  # -----------------------------------------------------------------------

  describe '#list_models (T1: 200 success)' do
    before do
      stub_request(:get, models_url)
        .with(headers: { 'Authorization' => "Bearer #{api_key}" })
        .to_return(
          status:  200,
          body:    api_model_payload.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns an Array' do
      expect(client.list_models).to be_an(Array)
    end

    it 'returns one entry per model in the API response' do
      expect(client.list_models.size).to eq(2)
    end

    it 'maps id from the upstream payload' do
      ids = client.list_models.map { |m| m[:id] }
      expect(ids).to contain_exactly('llama4-maverick', 'llama4-scout')
    end

    it 'forces object to "model"' do
      expect(client.list_models.map { |m| m[:object] }).to all(eq('model'))
    end

    it 'preserves owned_by from upstream when present' do
      expect(client.list_models.map { |m| m[:owned_by] }).to all(eq('fireworks'))
    end

    it 'defaults owned_by to "fireworks" when upstream omits the field' do
      payload_no_owner = {
        'object' => 'list',
        'data'   => [{ 'id' => 'fireworks-unknown', 'object' => 'model', 'created' => 1_700_000_002 }]
      }
      stub_request(:get, models_url)
        .to_return(status: 200, body: payload_no_owner.to_json,
                   headers: { 'Content-Type' => 'application/json' })

      expect(described_class.new(api_key: api_key).list_models.first[:owned_by]).to eq('fireworks')
    end

    it 'carries the created timestamp from upstream' do
      expect(client.list_models.map { |m| m[:created] })
        .to contain_exactly(1_700_000_000, 1_700_000_001)
    end

    it 'sets smart_proxy provider to "fireworks"' do
      expect(client.list_models.map { |m| m.dig(:smart_proxy, :provider) }).to all(eq('fireworks'))
    end

    it 'hits the correct endpoint' do
      client.list_models
      expect(WebMock).to have_requested(:get, models_url)
    end
  end

  # -----------------------------------------------------------------------
  # T2 – returns [] on Faraday::Error
  # -----------------------------------------------------------------------

  describe '#list_models (T2: Faraday::Error)' do
    context 'when Faraday::ConnectionFailed is raised' do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))
      end

      it 'returns an Array' do
        with_env('FIREWORKS_MODELS', nil) { expect(client.list_models).to be_an(Array) }
      end

      it 'returns [] when FIREWORKS_MODELS is not set' do
        with_env('FIREWORKS_MODELS', nil) { expect(client.list_models).to eq([]) }
      end

      it 'does not propagate the exception' do
        with_env('FIREWORKS_MODELS', nil) { expect { client.list_models }.not_to raise_error }
      end
    end

    context 'when Faraday::TimeoutError is raised' do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::TimeoutError.new('execution expired'))
      end

      it 'returns [] when FIREWORKS_MODELS is not set' do
        with_env('FIREWORKS_MODELS', nil) { expect(client.list_models).to eq([]) }
      end

      it 'does not propagate the exception' do
        with_env('FIREWORKS_MODELS', nil) { expect { client.list_models }.not_to raise_error }
      end
    end
  end

  # -----------------------------------------------------------------------
  # T3 – returns [] on non-200 response
  # -----------------------------------------------------------------------

  describe '#list_models (T3: non-200 response)' do
    [401, 403, 429, 500, 503].each do |status_code|
      context "when the server returns HTTP #{status_code}" do
        before do
          stub_request(:get, models_url)
            .to_return(
              status:  status_code,
              body:    { error: 'upstream error' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        it "returns [] for #{status_code} when FIREWORKS_MODELS is not set" do
          with_env('FIREWORKS_MODELS', nil) { expect(client.list_models).to eq([]) }
        end

        it "does not raise for #{status_code}" do
          with_env('FIREWORKS_MODELS', nil) { expect { client.list_models }.not_to raise_error }
        end
      end
    end

    context 'when the response body contains a data array but status is 401' do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  401,
            body:    api_model_payload.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'ignores body data on non-200 and returns [] without a fallback env var' do
        with_env('FIREWORKS_MODELS', nil) { expect(client.list_models).to eq([]) }
      end
    end
  end

  # -----------------------------------------------------------------------
  # T4 – falls back to FIREWORKS_MODELS CSV env var when live returns empty
  # -----------------------------------------------------------------------

  describe '#list_models (T4: FIREWORKS_MODELS env var fallback)' do
    let(:env_models_csv) { 'llama4-maverick,llama4-scout, llama4-maverick-v2 ' }

    shared_examples 'returns env fallback models' do
      it 'returns an Array' do
        with_env('FIREWORKS_MODELS', env_models_csv) { expect(client.list_models).to be_an(Array) }
      end

      it 'returns one entry per non-empty CSV token' do
        with_env('FIREWORKS_MODELS', env_models_csv) { expect(client.list_models.size).to eq(3) }
      end

      it 'uses the CSV values as model ids' do
        with_env('FIREWORKS_MODELS', env_models_csv) do
          expect(client.list_models.map { |m| m[:id] })
            .to contain_exactly('llama4-maverick', 'llama4-scout', 'llama4-maverick-v2')
        end
      end

      it 'strips surrounding whitespace from each CSV token' do
        with_env('FIREWORKS_MODELS', ' llama4-maverick , llama4-maverick-v2 ') do
          expect(client.list_models.map { |m| m[:id] })
            .to contain_exactly('llama4-maverick', 'llama4-maverick-v2')
        end
      end

      it 'sets owned_by to "fireworks" for every fallback entry' do
        with_env('FIREWORKS_MODELS', env_models_csv) do
          expect(client.list_models.map { |m| m[:owned_by] }).to all(eq('fireworks'))
        end
      end

      it 'sets smart_proxy provider to "fireworks" for every fallback entry' do
        with_env('FIREWORKS_MODELS', env_models_csv) do
          expect(client.list_models.map { |m| m.dig(:smart_proxy, :provider) }).to all(eq('fireworks'))
        end
      end
    end

    context 'when the API raises a Faraday::Error' do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))
      end

      include_examples 'returns env fallback models'
    end

    context 'when the API returns 200 with an empty data array' do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  200,
            body:    { 'object' => 'list', 'data' => [] }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      include_examples 'returns env fallback models'
    end

    context 'when the API returns a non-200 response' do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  503,
            body:    { error: 'service unavailable' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      include_examples 'returns env fallback models'
    end

    context 'when FIREWORKS_MODELS is an empty string' do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))
      end

      it 'returns [] (empty CSV treated as no fallback)' do
        with_env('FIREWORKS_MODELS', '') { expect(client.list_models).to eq([]) }
      end
    end
  end

  # -----------------------------------------------------------------------
  # T5 – every returned hash contains the five required normalised keys
  # -----------------------------------------------------------------------

  describe '#list_models (T5: normalised key contract)' do
    context 'when the API returns live models' do
      before do
        stub_request(:get, models_url)
          .to_return(
            status:  200,
            body:    api_model_payload.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'every hash contains all five required keys' do
        client.list_models.each do |model|
          expect(model.keys).to include(*REQUIRED_FIREWORKS_MODEL_KEYS),
            "expected model #{model.inspect} to include #{REQUIRED_FIREWORKS_MODEL_KEYS}"
        end
      end

      it 'id is a non-nil String' do
        client.list_models.each { |m| expect(m[:id]).to be_a(String) }
      end

      it 'object is the String "model"' do
        client.list_models.each { |m| expect(m[:object]).to eq('model') }
      end

      it 'owned_by is a non-nil String' do
        client.list_models.each { |m| expect(m[:owned_by]).to be_a(String) }
      end

      it 'created is an Integer' do
        client.list_models.each { |m| expect(m[:created]).to be_an(Integer) }
      end

      it 'smart_proxy is a Hash with a :provider String' do
        client.list_models.each do |m|
          expect(m[:smart_proxy]).to be_a(Hash)
          expect(m[:smart_proxy][:provider]).to be_a(String)
        end
      end
    end

    context 'when models come from the FIREWORKS_MODELS env var fallback' do
      before do
        stub_request(:get, models_url)
          .to_raise(Faraday::ConnectionFailed.new('connection refused'))
      end

      it 'every fallback hash contains all five required keys' do
        with_env('FIREWORKS_MODELS', 'llama4-maverick,llama4-scout') do
          client.list_models.each do |model|
            expect(model.keys).to include(*REQUIRED_FIREWORKS_MODEL_KEYS),
              "expected fallback model #{model.inspect} to include #{REQUIRED_FIREWORKS_MODEL_KEYS}"
          end
        end
      end

      it 'fallback created is an Integer' do
        with_env('FIREWORKS_MODELS', 'llama4-maverick') do
          client.list_models.each { |m| expect(m[:created]).to be_an(Integer) }
        end
      end

      it 'fallback object is "model"' do
        with_env('FIREWORKS_MODELS', 'llama4-maverick') do
          client.list_models.each { |m| expect(m[:object]).to eq('model') }
        end
      end
    end
  end
end
