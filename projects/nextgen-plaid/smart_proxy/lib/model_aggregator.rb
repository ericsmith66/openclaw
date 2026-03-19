require 'json'
require 'time'
require_relative 'ollama_client'

class ModelAggregator
  def initialize(cache_ttl: 60, cache: nil, logger: nil, session_id: nil)
    @cache_ttl = cache_ttl
    @cache = cache || { fetched_at: Time.at(0), data: nil }
    @logger = logger
    @session_id = session_id
  end

  def list_models
    if @cache[:data] && (Time.now - @cache[:fetched_at] < @cache_ttl)
      return { payload: @cache[:data], cache: @cache }
    end

    models = fetch_ollama_models
    models += list_grok_models
    models += list_claude_models

    payload = { object: 'list', data: models }
    new_cache = { fetched_at: Time.now, data: payload }

    { payload: payload, cache: new_cache }
  rescue StandardError => e
    @logger&.error({ event: 'model_aggregation_error', session_id: @session_id, error: e.message })
    { payload: @cache[:data] || { object: 'list', data: [] }, cache: @cache }
  end

  private

  def fetch_ollama_models
    client = OllamaClient.new(logger: @logger)
    resp = client.list_models
    return [] unless resp.status == 200

    body = resp.body.is_a?(String) ? JSON.parse(resp.body) : resp.body
    (body['models'] || []).map do |m|
      {
        id: m['name'],
        object: 'model',
        owned_by: 'ollama',
        created: (Time.parse(m['modified_at']).to_i rescue nil),
        smart_proxy: {
          size: m['size'],
          digest: m['digest'],
          details: m['details']
        }.compact
      }.compact
    end
  rescue StandardError => e
    @logger&.warn({ event: 'ollama_models_fetch_error', session_id: @session_id, error: e.message })
    []
  end

  def list_grok_models
    grok_key = ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY']
    return [] if grok_key.to_s.empty?

    grok_models_str = ENV.fetch('GROK_MODELS', 'grok-4,grok-4-latest,grok-4-with-live-search')
    grok_models_str.split(',').map(&:strip).map do |m_id|
      {
        id: m_id,
        object: 'model',
        owned_by: 'xai',
        created: Time.now.to_i,
        smart_proxy: {
          provider: 'xai'
        }
      }
    end
  end

  def list_claude_models
    claude_key = ENV['CLAUDE_API_KEY']
    return [] if claude_key.to_s.empty?

    claude_models_str = ENV.fetch('CLAUDE_MODELS', 'claude-sonnet-4-5-20250929,claude-sonnet-4-20250514,claude-3-5-haiku-20241022,claude-3-haiku-20240307')
    claude_models = claude_models_str.split(',').map(&:strip)

    models = []
    claude_models.each do |m_id|
      models << {
        id: m_id,
        object: 'model',
        owned_by: 'anthropic',
        created: Time.now.to_i,
        smart_proxy: {
          provider: 'anthropic'
        }
      }

      # Add -with-live-search variants
      models << {
        id: "#{m_id}-with-live-search",
        object: 'model',
        owned_by: 'anthropic',
        created: Time.now.to_i,
        smart_proxy: {
          provider: 'anthropic',
          features: %w[live-search tools]
        }
      }
    end
    models
  end
end
