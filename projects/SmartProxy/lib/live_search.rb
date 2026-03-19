require 'json'

# Agentic live-search execution for SmartProxy.
#
# This executes the `web_search` (and optionally `x_keyword_search`) tool by making an
# inner Grok call to `POST /v1/chat/completions` and asking Grok to return strict JSON.
class LiveSearch
  class Error < StandardError; end

  def initialize(grok_client:, session_id: nil, logger: nil)
    @grok_client = grok_client
    @session_id = session_id
    @logger = logger
  end

  def web_search(query, num_results:)
    sources = sources_from_env
    max_results = normalize_int(num_results, default: default_max_results, min: 1, max: 10)

    log_event('live_search_search_call_made', {
      tool: 'web_search',
      sources: sources,
      max_search_results: max_results
    })

    prompt = build_search_prompt(query: query, num_results: max_results)
    results = inner_search(prompt)

    JSON.dump({ results: results })
  end

  def x_keyword_search(query, limit:, mode: 'top')
    max_results = normalize_int(limit, default: default_max_results, min: 1, max: 10)
    mode = mode.to_s
    mode = 'top' unless %w[top latest].include?(mode)

    log_event('live_search_search_call_made', {
      tool: 'x_keyword_search',
      mode: mode,
      max_search_results: max_results
    })

    prompt = build_x_search_prompt(query: query, limit: max_results, mode: mode)
    results = inner_search(prompt)

    JSON.dump({ results: results })
  end

  private

  def inner_search(user_prompt)
    payload = {
      model: 'grok-4',
      temperature: 0.0,
      stream: false,
      messages: [
        { role: 'user', content: user_prompt }
      ]
    }

    response = @grok_client.chat_completions(payload)
    status = response.respond_to?(:status) ? response.status.to_i : 500
    body = response.respond_to?(:body) ? response.body : response

    raise Error, "inner_grok_call_failed status=#{status}" unless status == 200

    parsed = body.is_a?(String) ? JSON.parse(body) : body
    content = parsed.dig('choices', 0, 'message', 'content').to_s

    json = JSON.parse(content)
    results = json['results']

    unless results.is_a?(Array)
      raise Error, 'inner_search_invalid_json_shape'
    end

    normalize_results(results)
  rescue JSON::ParserError
    raise Error, 'inner_search_non_json_response'
  end

  def normalize_results(results)
    results.map do |r|
      next unless r.is_a?(Hash)

      {
        title: r['title'].to_s,
        url: r['url'].to_s,
        snippet: r['snippet'].to_s
      }
    end.compact
  end

  def build_search_prompt(query:, num_results:)
    clean = query.to_s.strip
    clean = clean[0, 500]

    sources = sources_from_env
    sources_hint = sources.empty? ? '' : " Sources: #{sources.join(', ')}."

    "Perform a real-time web search for '#{clean}'.#{sources_hint} Return exactly the top #{num_results} results as a JSON object: {results: [{title: string, url: string, snippet: string}]}. Do not include any extra text."
  end

  def build_x_search_prompt(query:, limit:, mode:)
    clean = query.to_s.strip
    clean = clean[0, 500]

    "Search X for '#{clean}' (mode: #{mode}) and return exactly the top #{limit} results as a JSON object: {results: [{title: string, url: string, snippet: string}]}. Do not include any extra text."
  end

  def sources_from_env
    raw = ENV.fetch('SMART_PROXY_LIVE_SEARCH_SOURCES', 'web,news').to_s
    raw.split(',').map(&:strip).reject(&:empty?).uniq
  end

  def default_max_results
    Integer(ENV.fetch('SMART_PROXY_LIVE_SEARCH_MAX_RESULTS', '3'))
  rescue StandardError
    3
  end

  def normalize_int(value, default:, min:, max:)
    int = Integer(value)
    [ [ int, min ].max, max ].min
  rescue StandardError
    default
  end

  def log_event(event, data)
    return unless @logger && @logger.respond_to?(:info)

    @logger.info({
      event: event,
      session_id: @session_id,
      data: data
    })
  end
end
