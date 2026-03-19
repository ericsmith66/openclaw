require 'spec_helper'
require_relative '../../lib/model_aggregator'

RSpec.describe ModelAggregator do
  let(:logger) { double('Logger', error: nil, warn: nil) }
  let(:aggregator) { ModelAggregator.new(logger: logger, session_id: 'test-session') }

  describe '#list_models' do
    it 'returns models from Ollama' do
      ollama_response = double('Response', status: 200, body: {
        'models' => [
          { 'name' => 'llama3', 'modified_at' => Time.now.iso8601, 'size' => 1000, 'digest' => 'sha256:abc' }
        ]
      }.to_json)

      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return(ollama_response)

      # Mock ENV to avoid other providers
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return(nil)

      result = aggregator.list_models

      expect(result[:payload][:object]).to eq('list')
      expect(result[:payload][:data].first[:id]).to eq('llama3')
      expect(result[:payload][:data].first[:owned_by]).to eq('ollama')
    end

    it 'returns models from Grok when API key is present' do
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return(double('Response', status: 500))

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('test-key')
      allow(ENV).to receive(:fetch).with('GROK_MODELS', anything).and_return('grok-1')
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return(nil)

      result = aggregator.list_models

      grok_model = result[:payload][:data].find { |m| m[:id] == 'grok-1' }
      expect(grok_model).not_to be_nil
      expect(grok_model[:owned_by]).to eq('xai')
    end

    it 'uses cache if within TTL' do
      aggregator = ModelAggregator.new(
        cache_ttl: 60,
        cache: { fetched_at: Time.now, data: { object: 'list', data: [ { id: 'cached' } ] } }
      )

      expect_any_instance_of(OllamaClient).not_to receive(:list_models)

      result = aggregator.list_models
      expect(result[:payload][:data].first[:id]).to eq('cached')
    end
  end
end
