require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'

class OpenRouterClient
  BASE_URL = 'https://openrouter.ai/api/v1'

  def initialize(api_key:, logger: nil, session_id: nil)
    @api_key = api_key
    @logger = logger
    @session_id = session_id
  end

  def chat_completions(payload)
    connection.post('chat/completions') do |req|
      req.headers['HTTP-Referer'] = ENV.fetch('OPENROUTER_REFERER', 'https://smartproxy.local')
      req.headers['X-Title'] = ENV.fetch('OPENROUTER_TITLE', 'SmartProxy')
      req.body = payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  def list_models
    response = connection.get('models') do |req|
      req.headers['Authorization'] = "Bearer #{@api_key}"
    end
    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    (body['data'] || []).map { |m| normalize(m) }
  rescue StandardError => e
    @logger&.warn({ event: 'openrouter_list_models_error', session_id: @session_id, error: e.message })
    models_from_env_fallback
  end

  private

  def normalize(m)
    {
      id:          m['id'],
      object:      'model',
      owned_by:    'openrouter',
      created:     m['created'] || Time.now.to_i,
      smart_proxy: {
        provider:              'openrouter',
        upstream_provider:     m['id'].to_s.split('/').first,
        context_length:        m.dig('context_length'),
        supported_parameters:  m.dig('supported_parameters') || [],
        modalities:            extract_modalities(m)
      }.compact
    }
  end

  def extract_modalities(m)
    m.dig('architecture', 'modalities') || m['modalities'] || ['text']
  end

  def models_from_env_fallback
    str = ENV.fetch('OPENROUTER_MODELS', '')
    return [] if str.empty?
    str.split(',').map(&:strip).reject(&:empty?).map do |m_id|
      {
        id:          m_id,
        object:      'model',
        owned_by:    'openrouter',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'openrouter' }
      }
    end
  end

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('OPENROUTER_TIMEOUT', '120').to_i
      f.options.open_timeout = 10
      f.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [ 429, 500, 502, 503, 504 ]
      }
      f.headers['Authorization'] = "Bearer #{@api_key}"
      f.headers['Content-Type'] = 'application/json'
      f.adapter Faraday.default_adapter
    end
  end

  def handle_error(error)
    @logger&.error({ event: 'openrouter_request_error', session_id: @session_id, error: error.message })
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }
    OpenStruct.new(status: status, body: body)
  end
end