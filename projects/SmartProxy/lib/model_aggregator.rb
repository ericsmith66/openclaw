require 'json'
require 'time'
require_relative 'model_filter'
require_relative 'grok_client'
require_relative 'claude_client'
require_relative 'deepseek_client'
require_relative 'fireworks_client'
require_relative 'openrouter_client'
require_relative 'ollama_client'
require_relative 'mlx_client'

class ModelAggregator
  # Ordered registry of provider symbols to factory lambdas.
  # Each lambda returns a client instance, or nil when the required API key
  # is absent.  Returning nil causes the provider to be silently skipped.
  # Ollama is always available (local service, no API key required).
  PROVIDERS = {
    grok:        -> { (k = ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY']; k.to_s.empty? ? nil : GrokClient.new(api_key: k)) },
    claude:      -> { (k = ENV['CLAUDE_API_KEY'];      k.to_s.empty? ? nil : ClaudeClient.new(api_key: k)) },
    deepseek:    -> { (k = ENV['DEEPSEEK_API_KEY'];    k.to_s.empty? ? nil : DeepSeekClient.new(api_key: k)) },
    fireworks:   -> { (k = ENV['FIREWORKS_API_KEY'];   k.to_s.empty? ? nil : FireworksClient.new(api_key: k)) },
    openrouter:  -> { (k = ENV['OPENROUTER_API_KEY'];  k.to_s.empty? ? nil : OpenRouterClient.new(api_key: k)) },
    ollama:      -> { OllamaClient.new },
    mlx:        -> { MlxClient.new },
  }.freeze

  def initialize(cache_ttl: 60, cache: nil, logger: nil, session_id: nil)
    @cache_ttl  = cache_ttl
    @cache      = cache || { fetched_at: Time.at(0), data: nil }
    @logger     = logger
    @session_id = session_id
  end

  def list_models
    if @cache[:data] && (Time.now - @cache[:fetched_at] < @cache_ttl)
      return { payload: @cache[:data], cache: @cache }
    end

    models = []

    PROVIDERS.each do |provider_sym, client_factory|
      client = client_factory.call
      next if client.nil?

      begin
        raw      = client.list_models
        filtered = ModelFilter.new(provider: provider_sym).apply(raw)
        models.concat(filtered)
      rescue StandardError => e
        @logger&.warn({ event: 'provider_models_fetch_error', provider: provider_sym, session_id: @session_id, error: e.message })
      end
    end

    payload   = { object: 'list', data: models }
    new_cache = { fetched_at: Time.now, data: payload }

    { payload: payload, cache: new_cache }
  rescue StandardError => e
    @logger&.error({ event: 'model_aggregation_error', session_id: @session_id, error: e.message })
    { payload: @cache[:data] || { object: 'list', data: [] }, cache: @cache }
  end
end
