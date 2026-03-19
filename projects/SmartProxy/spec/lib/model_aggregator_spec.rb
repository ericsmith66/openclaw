require 'spec_helper'
require_relative '../../lib/model_aggregator'
require_relative '../../lib/model_filter'
require_relative '../../lib/mlx_client'
require_relative '../../lib/ollama_client'
require_relative '../../lib/grok_client'
require_relative '../../lib/claude_client'
require_relative '../../lib/deepseek_client'
require_relative '../../lib/fireworks_client'

# ---------------------------------------------------------------------------
# Helpers — build normalised model hashes exactly as provider clients return
# ---------------------------------------------------------------------------
def provider_model(id:, owned_by:)
  {
    id:          id,
    object:      'model',
    owned_by:    owned_by,
    created:     Time.now.to_i,
    smart_proxy: { provider: owned_by }
  }
end

RSpec.describe ModelAggregator do
  # -------------------------------------------------------------------------
  # Shared doubles / ENV setup
  #
  # We require the OpenRouterClient file lazily inside shared contexts because
  # the file does not exist until PRD-5.4 is implemented. All other clients are
  # stubbed at the instance level so no real HTTP connections are made.
  # --------------------------------------------------------------------

  let(:logger) { double('Logger', warn: nil, error: nil, info: nil, debug: nil) }

  # Default: all API keys absent, making every keyed provider return nil from
  # their PROVIDERS factory lambda.
  let(:env_no_keys) do
    {
      'GROK_API_KEY_SAP'    => nil,
      'GROK_API_KEY'        => nil,
      'CLAUDE_API_KEY'      => nil,
      'DEEPSEEK_API_KEY'    => nil,
      'FIREWORKS_API_KEY'   => nil,
      'OPENROUTER_API_KEY'  => nil
    }
  end

  # Freeze time for deterministic TTL assertions
  let(:now) { Time.now }

  before do
    # Silence ENV lookups that are irrelevant to the test under scrutiny.
    # Tests that need specific keys will stub those keys individually.
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original

    env_no_keys.each do |key, _|
      allow(ENV).to receive(:[]).with(key).and_return(nil)
    end
  end

  # -------------------------------------------------------------------------
  # T1 — Merged models from all providers whose API keys are set
  # -------------------------------------------------------------------------
  describe 'T1: merged models from all keyed providers' do
    it 'returns a single flat list combining every provider that has an API key' do
      # Arrange: give every keyed provider a key
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok-key')
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return('claude-key')
      allow(ENV).to receive(:[]).with('DEEPSEEK_API_KEY').and_return('ds-key')
      allow(ENV).to receive(:[]).with('FIREWORKS_API_KEY').and_return('fw-key')

      grok_model      = provider_model(id: 'grok-3',               owned_by: 'xai')
      claude_model    = provider_model(id: 'claude-opus-4-5',      owned_by: 'anthropic')
      deepseek_model  = provider_model(id: 'deepseek-chat',        owned_by: 'deepseek')
      fireworks_model = provider_model(id: 'accounts/fireworks/models/llama4', owned_by: 'fireworks')
      ollama_model    = provider_model(id: 'llama3.1:8b',          owned_by: 'ollama')

      # Stub each client's list_models to return one representative model.
      # ModelFilter is also stubbed to pass through its input unchanged so that
      # the focus of this test remains on aggregation logic, not filtering.
      allow_any_instance_of(GrokClient).to     receive(:list_models).and_return([grok_model])
      allow_any_instance_of(ClaudeClient).to   receive(:list_models).and_return([claude_model])
      allow_any_instance_of(DeepSeekClient).to receive(:list_models).and_return([deepseek_model])
      allow_any_instance_of(FireworksClient).to receive(:list_models).and_return([fireworks_model])
      allow_any_instance_of(OllamaClient).to   receive(:list_models).and_return([ollama_model])

      allow_any_instance_of(ModelFilter).to receive(:apply) { |_filter, models| models }

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('grok-3', 'claude-opus-4-5', 'deepseek-chat',
                             'accounts/fireworks/models/llama4', 'llama3.1:8b')
      expect(result[:payload][:object]).to eq('list')
    end
  end

  # -------------------------------------------------------------------------
  # T2 — Provider with missing API key is silently skipped
  # -------------------------------------------------------------------------
  describe 'T2: missing API key silently skips provider' do
    it 'excludes a keyed provider and does not raise when its API key is absent' do
      # Grok key absent (already defaulted to nil in before block)
      # Ollama always included
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return(
        [provider_model(id: 'llama3.1:8b', owned_by: 'ollama')]
      )
      allow_any_instance_of(ModelFilter).to receive(:apply) { |_filter, models| models }

      # GrokClient must never be instantiated when no key is present
      expect(GrokClient).not_to receive(:new)

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).not_to include('grok-3')
      expect(ids).to include('llama3.1:8b')
    end
  end

  # -------------------------------------------------------------------------
  # T3 — Provider fetch raising StandardError is caught; others still included
  # -------------------------------------------------------------------------
  describe 'T3: provider fetch raising StandardError is caught, others still included' do
    it 'logs a warning and continues when one provider raises, returning remaining models' do
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok-key')

      ollama_model = provider_model(id: 'llama3.1:8b', owned_by: 'ollama')

      # Grok blows up
      allow_any_instance_of(GrokClient).to receive(:list_models).and_raise(StandardError, 'network failure')
      # Ollama succeeds
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([ollama_model])

      allow_any_instance_of(ModelFilter).to receive(:apply) { |_filter, models| models }

      expect(logger).to receive(:warn).with(
        hash_including(event: 'provider_models_fetch_error', provider: :grok)
      )

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('llama3.1:8b')
      expect(ids).not_to include('grok-3')
    end
  end

  # -------------------------------------------------------------------------
  # T4 — Result is cached; second call within TTL does not re-fetch
  # -------------------------------------------------------------------------
  describe 'T4: result is cached within TTL' do
    it 'returns the cached payload without calling any provider client on the second call' do
      cached_data = { object: 'list', data: [{ id: 'cached-model' }] }
      warm_cache  = { fetched_at: Time.now, data: cached_data }

      aggregator = ModelAggregator.new(cache_ttl: 60, cache: warm_cache, logger: logger)

      # Provider clients must not be contacted at all
      expect_any_instance_of(OllamaClient).not_to receive(:list_models)
      expect_any_instance_of(GrokClient).not_to   receive(:list_models)

      result = aggregator.list_models

      expect(result[:payload]).to eq(cached_data)
    end
  end

  # -------------------------------------------------------------------------
  # T5 — Cache invalidated after TTL triggers a fresh fetch
  # -------------------------------------------------------------------------
  describe 'T5: cache invalidated after TTL triggers fresh fetch' do
    it 'fetches from providers again when the cache entry is older than the TTL' do
      stale_data  = { object: 'list', data: [{ id: 'stale-model' }] }
      # fetched_at is 120 s ago; TTL is 60 s → expired
      stale_cache = { fetched_at: Time.now - 120, data: stale_data }

      fresh_model = provider_model(id: 'fresh-model', owned_by: 'ollama')
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([fresh_model])
      allow_any_instance_of(ModelFilter).to  receive(:apply) { |_filter, models| models }

      aggregator = ModelAggregator.new(cache_ttl: 60, cache: stale_cache, logger: logger)
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('fresh-model')
      expect(ids).not_to include('stale-model')
    end
  end

  # -------------------------------------------------------------------------
  # T6 — ModelFilter is called once per active provider with the correct symbol
  # -------------------------------------------------------------------------
  describe 'T6: ModelFilter called once per provider with correct symbol' do
    it 'instantiates ModelFilter with the provider symbol for each active provider' do
      allow(ENV).to receive(:[]).with('GROK_API_KEY_SAP').and_return(nil)
      allow(ENV).to receive(:[]).with('GROK_API_KEY').and_return('grok-key')
      allow(ENV).to receive(:[]).with('CLAUDE_API_KEY').and_return('claude-key')

      allow_any_instance_of(GrokClient).to   receive(:list_models).and_return([])
      allow_any_instance_of(ClaudeClient).to receive(:list_models).and_return([])
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])

      # Capture every ModelFilter instantiation so we can assert on provider:
      captured_providers = []
      allow(ModelFilter).to receive(:new) do |**kwargs|
        captured_providers << kwargs[:provider]
        instance_double(ModelFilter, apply: [])
      end

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      aggregator.list_models

      # Three active providers: grok, claude, ollama
      expect(captured_providers).to include(:grok, :claude, :ollama)

      # Exactly one filter per active provider — no duplicates
      expect(captured_providers.tally.values).to all(eq(1))

      # Inactive providers must not have a filter instantiated
      expect(captured_providers).not_to include(:deepseek, :fireworks, :openrouter)
    end
  end

  # -------------------------------------------------------------------------
  # T7 — OpenRouter models appear when OPENROUTER_API_KEY is set
  # -------------------------------------------------------------------------
  describe 'T7: OpenRouter models appear when OPENROUTER_API_KEY is set' do
    it 'includes OpenRouter models in the payload when the key is present' do
      allow(ENV).to receive(:[]).with('OPENROUTER_API_KEY').and_return('or-key')

      openrouter_model = {
        id:          'google/gemini-2.5-pro',
        object:      'model',
        owned_by:    'openrouter',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'openrouter', upstream_provider: 'google' }
      }

      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
      allow_any_instance_of(ModelFilter).to  receive(:apply) { |_filter, models| models }

      # OpenRouterClient may not exist yet — use a plain double and stub ::new
      openrouter_double = double('OpenRouterClient', list_models: [openrouter_model])
      openrouter_class  = class_double('OpenRouterClient').as_stubbed_const
      allow(openrouter_class).to receive(:new).with(api_key: 'or-key').and_return(openrouter_double)

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('google/gemini-2.5-pro')
    end
  end

  # -------------------------------------------------------------------------
  # T8 — Ollama is always included without a key guard
  # -------------------------------------------------------------------------
  describe 'T8: Ollama always included without a key guard' do
    it 'fetches Ollama models even when all other API keys are absent' do
      # All keyed providers remain absent (set in the before block).
      ollama_model = provider_model(id: 'llama3.1:70b', owned_by: 'ollama')

      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([ollama_model])
      allow_any_instance_of(ModelFilter).to  receive(:apply) { |_filter, models| models }

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('llama3.1:70b')
    end

    it 'does not require any ENV key variable to instantiate OllamaClient' do
      # Verify OllamaClient is constructed with no api_key argument
      expect(OllamaClient).to receive(:new).with(no_args).and_call_original
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
      allow_any_instance_of(ModelFilter).to  receive(:apply) { |_filter, models| models }

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      aggregator.list_models
    end
  end

  # -------------------------------------------------------------------------
  # T9 — MLX models appear when server up, absent when down, with mlx/ prefix
  # -------------------------------------------------------------------------
  describe 'T9: MLX provider integration per FR-3' do
    it 'includes MLX models in the payload when server is running with mlx/ prefix' do
      mlx_model = {
        id:          'mlx/qwen3-coder-next-8bit',
        object:      'model',
        owned_by:    'mlx',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'mlx' }
      }

      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
      allow_any_instance_of(ModelFilter).to  receive(:apply) { |_filter, models| models }

      # MlxClient always returns a client (no API key required)
      allow_any_instance_of(MlxClient).to receive(:list_models).and_return([mlx_model])

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('mlx/qwen3-coder-next-8bit')
      expect(result[:payload][:data].first[:owned_by]).to eq('mlx')
      expect(result[:payload][:data].first.dig(:smart_proxy, :provider)).to eq('mlx')
    end

    it 'silently omits MLX models when server is down (list_models returns [])' do
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return(
        [provider_model(id: 'llama3.1:8b', owned_by: 'ollama')]
      )
      allow_any_instance_of(ModelFilter).to receive(:apply) { |_filter, models| models }

      # MlxClient returns [] when server is down
      allow_any_instance_of(MlxClient).to receive(:list_models).and_return([])

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      ids = result[:payload][:data].map { |m| m[:id] }
      expect(ids).to include('llama3.1:8b')
      expect(ids).not_to include('mlx/')
    end

    it 'MlxClient instantiated without any ENV key requirements (no api_key needed)' do
      # MlxClient requires no API key — lambda calls MlxClient.new with no args,
      # consistent with how OllamaClient is instantiated in PROVIDERS.
      expect(MlxClient).to receive(:new).with(no_args).and_call_original
      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
      allow_any_instance_of(MlxClient).to receive(:list_models).and_return([])
      allow_any_instance_of(ModelFilter).to receive(:apply) { |_filter, models| models }

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      aggregator.list_models
    end

    it 'MLX models include smart_proxy provider: mlx per FR-3' do
      mlx_model = {
        id:          'mlx/qwen2.5-coder-7b',
        object:      'model',
        owned_by:    'mlx',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'mlx' }
      }

      allow_any_instance_of(OllamaClient).to receive(:list_models).and_return([])
      allow_any_instance_of(ModelFilter).to receive(:apply) { |_filter, models| models }
      allow_any_instance_of(MlxClient).to receive(:list_models).and_return([mlx_model])

      aggregator = ModelAggregator.new(logger: logger, session_id: 'test')
      result = aggregator.list_models

      expect(result[:payload][:data].first[:owned_by]).to eq('mlx')
      expect(result[:payload][:data].first.dig(:smart_proxy, :provider)).to eq('mlx')
    end
  end
end
