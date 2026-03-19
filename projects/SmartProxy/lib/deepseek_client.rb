require 'faraday'
require 'faraday/retry'
require 'json'

require 'ostruct'

class DeepSeekClient
  BASE_URL = 'https://api.deepseek.com/v1'

  def initialize(api_key:)
    @api_key = api_key
  end

  def list_models
    response = connection.get('/models')
    return models_from_env_fallback unless response.status == 200

    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    live = (body['data'] || []).map do |m|
      {
        id:          m['id'],
        object:      'model',
        owned_by:    m['owned_by'] || 'deepseek',
        created:     m['created'] || Time.now.to_i,
        smart_proxy: { provider: 'deepseek' }
      }
    end
    live.empty? ? models_from_env_fallback : live
  rescue Faraday::Error
    models_from_env_fallback
  rescue StandardError
    models_from_env_fallback
  end

  def chat_completions(payload)
    connection.post('chat/completions') do |req|
      req.body = payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  def models_from_env_fallback
    str = ENV.fetch('DEEPSEEK_MODELS', '')
    return [] if str.empty?

    str.split(',').map(&:strip).reject(&:empty?).map do |model_id|
      {
        id:          model_id,
        object:      'model',
        owned_by:    'deepseek',
        created:     Time.now.to_i,
        smart_proxy: { provider: 'deepseek' }
      }
    end
  end

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.options.timeout = ENV.fetch('DEEPSEEK_TIMEOUT', '120').to_i
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
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }

    OpenStruct.new(status: status, body: body)
  end
end
