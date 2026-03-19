require 'faraday'
require 'faraday/retry'
require 'json'
require 'ostruct'

class MlxClient
  DEFAULT_BASE_URL = 'http://127.0.0.1:8765'.freeze

  def initialize(logger: nil)
    @base_url = ENV.fetch('MLX_BASE_URL', DEFAULT_BASE_URL)
    @logger   = logger
  end

  def list_models
    response = models_connection.get('/v1/models')
    return [] unless response.status == 200

    body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
    (body['data'] || []).map do |m|
      {
        id:          "mlx/#{normalize_model_id(m['id'])}",
        object:      'model',
        owned_by:    'mlx',
        created:     m['created'] || Time.now.to_i,
        smart_proxy: { provider: 'mlx' }
      }
    end
  rescue StandardError => e
    @logger&.warn({ event: 'mlx_list_models_error', error: e.message })
    []
  end

  def chat_completions(payload)
    # Model name arrives pre-stripped of mlx/ prefix by ModelRouter (upstream_model).
    # Resolve friendly name back to server's actual model ID (handles filesystem paths).
    payload = payload.dup
    payload['model'] = resolve_server_model(payload['model']) if payload['model']
    chat_connection.post('/v1/chat/completions') do |req|
      req.body = payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  # Normalize a raw model ID from the MLX server into a friendly name.
  # "/Users/foo/.cache/mlx-models/qwen3-8bit" => "qwen3-8bit"
  # "Qwen/Qwen2.5-Coder-7B-Instruct"          => "Qwen/Qwen2.5-Coder-7B-Instruct" (unchanged)
  def normalize_model_id(raw_id)
    return raw_id unless raw_id.start_with?('/')
    File.basename(raw_id)
  end

  # Build a map of friendly names -> server model IDs.  Cached per instance.
  # Falls back to {} silently on network failure so list_models can still degrade gracefully.
  def model_map
    @model_map ||= begin
      response = models_connection.get('/v1/models')
      return {} unless response.status == 200

      body = response.body.is_a?(String) ? JSON.parse(response.body) : response.body
      (body['data'] || []).each_with_object({}) do |m, map|
        raw      = m['id']
        friendly = normalize_model_id(raw)
        map[friendly] = raw
        map[raw]      = raw  # also accept raw ID directly
      end
    rescue StandardError => e
      @logger&.warn({ event: 'mlx_model_map_error', error: e.message })
      {}
    end
  end

  # Resolve the requested model name to the server's actual ID.
  # Falls back to the first loaded model when name is unknown (MLX typically
  # serves exactly one model at a time), then to the requested name as-is.
  def resolve_server_model(requested_model)
    return model_map[requested_model] if model_map.key?(requested_model)

    first = model_map.values.first
    @logger&.info({ event: 'mlx_model_fallback', requested: requested_model, resolved: first })
    first || requested_model
  end

  # Long-lived connection for inference — 600s timeout, retry on transient errors.
  def chat_connection
    @chat_connection ||= Faraday.new(url: @base_url) do |f|
      f.request  :json
      f.options.timeout      = ENV.fetch('MLX_TIMEOUT', '600').to_i
      f.options.open_timeout = 10
      f.request :retry, {
        max:                 3,
        interval:            0.5,
        interval_randomness: 0.5,
        backoff_factor:      2,
        retry_statuses:      [429, 500, 502, 503, 504]
      }
      f.adapter Faraday.default_adapter
    end
  end

  # Short connection for model listing — fast timeout, no retry.
  def models_connection
    @models_connection ||= Faraday.new(url: @base_url) do |f|
      f.request  :json
      f.options.timeout      = 10
      f.options.open_timeout = 5
      f.adapter Faraday.default_adapter
    end
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    # Always produce a JSON string so callers can safely JSON.parse(response.body)
    body   = error.response ? error.response[:body] : { error: error.message }.to_json
    OpenStruct.new(status: status, body: body)
  end
end
