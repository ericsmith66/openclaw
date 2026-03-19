require 'sinatra/base'
require 'json'
require 'logger'
require 'dotenv'
Dotenv.load(File.expand_path('.env', __dir__))
require_relative 'lib/grok_client'
require_relative 'lib/ollama_client'
require_relative 'lib/claude_client'
require_relative 'lib/tool_client'
require_relative 'lib/live_search'
require_relative 'lib/anonymizer'
require_relative 'lib/response_transformer'
require_relative 'lib/model_aggregator'
require_relative 'lib/model_router'
require_relative 'lib/tool_executor'
require_relative 'lib/tool_orchestrator'
require_relative 'lib/request_authenticator'
require 'securerandom'
require 'time'
require 'digest'

class SmartProxyApp < Sinatra::Base
  Response = Struct.new(:status, :body)

  DEFAULT_LOG_BODY_BYTES = 2_000

  def llm_calls_base_dir(requested_base = nil)
    if requested_base && !requested_base.to_s.strip.empty?
      # Ensure it's within the project for security, or just trust it for this internal tool
      return requested_base.to_s.strip
    end
    # Repo root is one level above smart_proxy/
    File.join(settings.root, '..', 'knowledge_base', 'test_artifacts', 'llm_calls')
  end

  configure do
    disable :protection
    set :port, ENV['SMART_PROXY_PORT'] || 4567
    set :bind, '0.0.0.0'
    set :logging, true
    set :protection, false

    # Setup structured JSON logging
    log_dir = File.join(settings.root, '..', 'log')
    Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
    log_file = File.join(log_dir, 'smart_proxy.log')
    $logger = Logger.new(log_file, 'daily')
    $logger.formatter = proc do |severity, datetime, _progname, msg|
      {
        timestamp: datetime,
        severity: severity,
        message: msg
      }.to_json + "\n"
    end

    # In-memory cache for model listing (best-effort)
    set :models_cache_ttl, Integer(ENV.fetch('SMART_PROXY_MODELS_CACHE_TTL', '60'))
    set :models_cache, { fetched_at: Time.at(0), data: nil }

    # Keep file logs readable by default. Full request/response payloads are already
    # persisted via `dump_llm_call_artifact!`.
    set :log_body_bytes, Integer(ENV.fetch('SMART_PROXY_LOG_BODY_BYTES', DEFAULT_LOG_BODY_BYTES.to_s))
  end

  before do
    content_type :json
    @session_id = request.env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid

    unless request.path_info == '/health'
      auth = RequestAuthenticator.new(
        auth_token: ENV['PROXY_AUTH_TOKEN'],
        request: request,
        logger: $logger,
        session_id: @session_id
      ).authenticate!

      halt auth[:status], auth[:body] if auth
    end
  end

  get '/health' do
    { status: 'ok' }.to_json
  end

  # OpenAI-compatible model listing endpoint.
  # Backed by Ollama's HTTP API (`GET /api/tags`).
  get '/v1/models' do
    aggregator = ModelAggregator.new(
      cache_ttl: settings.models_cache_ttl,
      cache: settings.models_cache,
      logger: $logger,
      session_id: @session_id
    )

    result = aggregator.list_models
    settings.models_cache = result[:cache]
    result[:payload].to_json
  end

  # OpenAI-compatible chat completions endpoint.
  # This is the primary endpoint used by the Rails app (via `ai-agents` / RubyLLM).
  post '/v1/chat/completions' do
    request.body.rewind if request.body.respond_to?(:rewind)
    body_content = request.body.read
    request_payload = JSON.parse(body_content)

    agent_name = request.env['HTTP_X_AGENT_NAME'] || request_payload.dig('smart_proxy', 'agent')
    correlation_id = request.env['HTTP_X_CORRELATION_ID'] || request.env['HTTP_X_RUN_ID'] || request_payload.dig('smart_proxy', 'correlation_id')
    llm_base_dir = request.env['HTTP_X_LLM_BASE_DIR'] || request_payload.dig('smart_proxy', 'llm_base_dir')

    # If correlation_id is still missing, check if it's in the request_id (sometimes misused)
    if correlation_id.to_s.strip.empty? && @session_id.to_s.include?('-') && @session_id.to_s.length > 20
      # This is likely a UUID session_id, not a correlation_id.
    end

    if correlation_id.to_s.strip.empty? && llm_base_dir.to_s.include?('/')
      # If we have a custom base dir, we might not need/want a correlation_id subdirectory
      # depending on how the caller structured the base dir.
      # But for now, we keep the cid logic.
    end

    $logger.info({
      event: 'chat_completions_headers_debug',
      session_id: @session_id,
      agent_name: agent_name,
      correlation_id: correlation_id,
      llm_base_dir: llm_base_dir,
      env_correlation_id: request.env['HTTP_X_CORRELATION_ID'],
      env_run_id: request.env['HTTP_X_RUN_ID'],
      payload_correlation_id: request_payload.dig('smart_proxy', 'correlation_id')
    })

    anonymized_payload = Anonymizer.anonymize(request_payload)

    $logger.info({
      event: 'chat_completions_request_received',
      session_id: @session_id,
      correlation_id: correlation_id,
      agent_name: agent_name,
      payload: anonymized_payload
    })

    # Support an explicit opt-in model alias for web/live search.
    # Continue can request `grok-4-with-live-search` and SmartProxy will:
    # - route upstream as `grok-4`
    # - enable tool injection only when SMART_PROXY_ENABLE_WEB_TOOLS=true
    router = ModelRouter.new(request_payload['model'])
    routing = router.route
    requested_model = routing[:requested_model]
    upstream_model = routing[:upstream_model]
    tools_opt_in = routing[:tools_opt_in]

    # Used by tool execution to enforce the model opt-in requirement.
    @tools_opt_in = tools_opt_in

    # Validate tools schema early if present and routing to Ollama
    if request_payload['tools'] && routing[:provider] == :ollama
      begin
        client = OllamaClient.new(logger: $logger)
        client.send(:validate_tools_schema!, request_payload['tools'])
      rescue ArgumentError => e
        $logger.error({
          event: 'tools_validation_failed_early',
          session_id: @session_id,
          error: e.message
        })
        status 400
        halt({
          error: 'invalid_tools_schema',
          message: e.message,
          provider: 'ollama'
        }.to_json)
      end
    end

    header_max_loops = request.env['HTTP_X_SMART_PROXY_MAX_LOOPS']
    max_loops_override = header_max_loops.to_s.strip.empty? ? nil : Integer(header_max_loops)

    upstream_payload = request_payload.dup
    upstream_payload['model'] = upstream_model

    # Tool/live-search models often stream tool-call chunks first (finish_reason: tool_calls).
    # In streaming mode that can cause downstream clients to show an empty bubble because
    # no `delta.content` is ever produced unless the tool loop is completed.
    #
    # Option A: complete the tool loop in SmartProxy even when the client requested streaming.
    # We do this by disabling upstream streaming for tool-opt-in requests, letting the
    # orchestrator run the tool loop and return a final assistant message, then we convert
    # that final JSON response into a minimal SSE stream below.
    if request_payload['stream'] == true && tools_opt_in
      upstream_payload['stream'] = false
    end

    executor = ToolExecutor.new(session_id: @session_id, logger: $logger, tools_opt_in: tools_opt_in)
    orchestrator = ToolOrchestrator.new(executor: executor, logger: $logger, session_id: @session_id)

    begin
      response = orchestrator.orchestrate(
        upstream_payload,
        routing: routing,
        max_loops: max_loops_override
      )
    rescue ArgumentError => e
      if e.message.include?('streaming with tool calls')
        $logger.warn({
          event: 'streaming_rejected_with_tools',
          session_id: @session_id,
          provider: 'ollama',
          error: e.message
        })
        status 400
        halt({
          error: 'streaming_not_supported_with_tools',
          message: e.message,
          provider: 'ollama'
        }.to_json)
      end
      raise
    end

    # Dump per-call request/response artifact for inspection.
    dump_llm_call_artifact!(
      agent: agent_name,
      request_id: @session_id,
      correlation_id: correlation_id,
      request_payload: request_payload,
      response_status: response.status,
      response_body: response.body,
      base_dir_override: llm_base_dir
    )

    $logger.info({
      event: 'chat_completions_response_received',
      session_id: @session_id,
      status: response.status,
      body: log_body_summary(response.body)
    })

    status response.status

    transformed = ResponseTransformer.to_openai_format(
      response.body,
      model: requested_model,
      streaming: request_payload['stream'] == true
    )

    if transformed[:content_type] == 'text/event-stream'
      content_type 'text/event-stream'
      halt transformed[:body]
    end

    transformed[:body]
  rescue JSON::ParserError => e
    $logger.error({ event: 'chat_completions_json_parse_error', session_id: @session_id, error: e.message })
    status 400
    {
      id: "chatcmpl-#{SecureRandom.hex(8)}",
      object: 'chat.completion',
      created: Time.now.to_i,
      model: 'unknown',
      choices: [
        {
          index: 0,
          finish_reason: 'error',
          message: {
            role: 'assistant',
            content: "SmartProxy error (400): Invalid JSON payload"
          }
        }
      ],
      usage: {
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0
      },
      smart_proxy_error: {
        type: 'invalid_json',
        message: e.message
      }
    }.to_json
  rescue StandardError => e
    $logger.error({ event: 'chat_completions_internal_error', session_id: @session_id, error: e.message, backtrace: (e.backtrace || []).first(5) })
    status 500
    {
      id: "chatcmpl-#{SecureRandom.hex(8)}",
      object: 'chat.completion',
      created: Time.now.to_i,
      model: 'unknown',
      choices: [
        {
          index: 0,
          finish_reason: 'error',
          message: {
            role: 'assistant',
            content: "SmartProxy error (500): #{e.message}"
          }
        }
      ],
      usage: {
        prompt_tokens: 0,
        completion_tokens: 0,
        total_tokens: 0
      },
      smart_proxy_error: {
        type: 'internal_error',
        message: e.message
      }
    }.to_json
  end

  private

  def log_body_summary(body)
    limit = settings.respond_to?(:log_body_bytes) ? settings.log_body_bytes : DEFAULT_LOG_BODY_BYTES

    if body.is_a?(String)
      bytes = body.bytesize
      preview = body.byteslice(0, limit)
      truncated = bytes > preview.bytesize

      # Many upstream responses (e.g., Grok streaming) come back as SSE text which can be huge.
      # Keep a compact preview and a few useful counters.
      is_sse = body.include?("\ndata: ") || body.start_with?("data: ")
      data_lines = is_sse ? body.scan(/^data: /).length : nil

      return {
        type: is_sse ? 'text/event-stream' : 'string',
        bytes: bytes,
        data_lines: data_lines,
        truncated: truncated,
        preview: preview
      }
    end

    if body.respond_to?(:to_json)
      json = body.to_json
      bytes = json.bytesize
      preview = json.byteslice(0, limit)
      truncated = bytes > preview.bytesize

      return {
        type: body.class.name,
        bytes: bytes,
        truncated: truncated,
        preview: preview
      }
    end

    { type: body.class.name, preview: body.to_s.byteslice(0, limit) }
  rescue StandardError => e
    { type: 'log_body_summary_error', error: "#{e.class}: #{e.message}" }
  end

  post '/proxy/tools' do
    request.body.rewind if request.body.respond_to?(:rewind)
    body_content = request.body.read
    request_payload = JSON.parse(body_content)

    executor = ToolExecutor.new(session_id: @session_id, logger: $logger, tools_opt_in: true)

    unless executor.web_tools_enabled?
      halt 403, {
        error: 'tools_disabled',
        message: 'Set SMART_PROXY_ENABLE_WEB_TOOLS=true to enable web tools'
      }.to_json
    end

    query = request_payload['query']
    num_results = request_payload['num_results'] || 5

    $logger.info({
      event: 'tool_request_received',
      session_id: @session_id,
      query: query
    })

    web_results = JSON.parse(executor.execute('web_search', { 'query' => query, 'num_results' => num_results }))
    x_results = JSON.parse(executor.execute('x_keyword_search', { 'query' => query, 'num_results' => num_results, 'mode' => request_payload['mode'] || 'top' }))

    confidence = executor.calculate_confidence(web_results, x_results, query)

    # Re-query if confidence is low
    if confidence < 0.5 && request_payload['retry'] != false
      $logger.info({ event: 'low_confidence_retry', session_id: @session_id, confidence: confidence })
      # Simple refinement: append keywords from query? For now just retry once.
      web_results = JSON.parse(executor.execute('web_search', { 'query' => query, 'num_results' => num_results + 2 }))
      confidence = executor.calculate_confidence(web_results, x_results, query)
    end

    result = {
      confidence: confidence,
      web_results: web_results,
      x_results: x_results,
      session_id: @session_id
    }

    $logger.info({
      event: 'tool_response_sent',
      session_id: @session_id,
      confidence: confidence
    })

    result.to_json
  end

  post '/proxy/generate' do
    request.body.rewind if request.body.respond_to?(:rewind)
    body_content = request.body.read
    request_payload = JSON.parse(body_content)

    # Anonymize request
    anonymized_payload = Anonymizer.anonymize(request_payload)

    $logger.info({
      event: 'request_received',
      session_id: @session_id,
      payload: anonymized_payload
    })

    if anonymized_payload['model'] == 'ollama'
      client = OllamaClient.new(logger: $logger)
      response = client.chat(anonymized_payload)
    else
      client = GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])
      response = client.chat_completions(anonymized_payload)
    end

    $logger.info({
      event: 'response_received',
      session_id: @session_id,
      status: response.status,
      body: response.body
    })

    status response.status
    if response.body.is_a?(String)
      response.body
    else
      response.body.to_json
    end
  rescue JSON::ParserError => e
    $logger.error({ event: 'json_parse_error', session_id: @session_id, error: e.message })
    status 400
    { error: 'Invalid JSON payload' }.to_json
  rescue StandardError => e
    $logger.error({ event: 'internal_error', session_id: @session_id, error: e.message, backtrace: (e.backtrace || []).first(5) })
    status 500
    { error: e.message }.to_json
  end

  private

  def dump_llm_call_artifact!(agent:, request_id:, correlation_id:, request_payload:, response_status:, response_body:, base_dir_override: nil)
    agent = agent.to_s.strip
    agent = 'unknown' if agent.empty?
    request_id = request_id.to_s.strip
    request_id = SecureRandom.uuid if request_id.empty?

    base = llm_calls_base_dir(base_dir_override)
    cid = correlation_id.to_s.strip
    if !cid.empty?
      dir = File.join(base, cid, agent)
    else
      dir = File.join(base, agent)
    end
    FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

    parsed_response = begin
      response_body.is_a?(String) ? JSON.parse(response_body) : response_body
    rescue StandardError
      nil
    end

    usage = if parsed_response.is_a?(Hash)
      parsed_response['usage'] || parsed_response[:usage]
    end

    payload = {
      ts: Time.now.utc.iso8601,
      request_id: request_id,
      correlation_id: correlation_id,
      agent: agent,
      model: (request_payload.is_a?(Hash) ? request_payload['model'] : nil),
      request_bytes: request_payload.to_json.bytesize,
      response_status: response_status,
      response_bytes: response_body.to_s.bytesize,
      usage: usage,
      request: request_payload,
      response: parsed_response || response_body
    }

    path = File.join(dir, "#{request_id}.json")
    File.write(path, JSON.pretty_generate(payload) + "\n")
  rescue StandardError => e
    $logger.error({ event: 'llm_call_artifact_dump_error', session_id: @session_id, error: e.message })
  end

  run! if app_file == $0
end
