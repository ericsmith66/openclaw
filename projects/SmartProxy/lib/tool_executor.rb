require 'json'
require_relative 'grok_client'
require_relative 'live_search'

class ToolExecutor
  def initialize(session_id:, logger: nil, tools_opt_in: false)
    @session_id = session_id
    @logger = logger
    @tools_opt_in = tools_opt_in
  end

  def execute(name, raw_args)
    tool_name = name.to_s
    args = parse_tool_args(raw_args)

    # Enforce tool opt-in.
    # Currently only live-search models are allowed to trigger web tools.
    unless @tools_opt_in || !web_tool_name?(tool_name)
      return {
        error: 'tool_not_allowed',
        message: "Tool '#{tool_name}' requires a model with '-with-live-search' suffix."
      }.to_json
    end

    case tool_name
    when 'web_search', 'proxy_tools', 'live_search'
      execute_web_search(args)
    when 'x_keyword_search'
      execute_x_keyword_search(args)
    else
      { error: 'unsupported_tool', name: tool_name }.to_json
    end
  rescue StandardError => e
    @logger&.error({ event: 'tool_execution_error', session_id: @session_id, tool: tool_name, error: e.message })
    { error: 'tool_execution_error', message: e.message }.to_json
  end

  def web_tools_enabled?
    ENV['SMART_PROXY_ENABLE_WEB_TOOLS'] == 'true'
  end

  def web_tool_name?(tool_name)
    %w[web_search x_keyword_search proxy_tools live_search].include?(tool_name)
  end

  def parse_tool_args(raw_args)
    if raw_args.is_a?(String)
      JSON.parse(raw_args)
    else
      raw_args
    end
  rescue StandardError
    {}
  end

  def normalize_int(value, default:, min:, max:)
    val = value.to_i rescue default
    val = default if val == 0 && value.to_s != '0'
    [ [ val, min ].max, max ].min
  end

  def validate_query(args)
    (args['query'] || args['q'] || args['keywords'] || "").to_s.strip
  end

  def execute_web_search(args)
    query = validate_query(args)
    num_results = normalize_int(args['num_results'] || 5, default: 5, min: 1, max: 10)

    if query.empty?
      return { error: 'missing_query', message: 'web_search requires a query' }.to_json
    end

    @logger&.info({ event: 'tool_request', session_id: @session_id, tool: 'web_search', args: { query: query, num_results: num_results } })

    grok_client = GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])
    live_search = LiveSearch.new(grok_client: grok_client, session_id: @session_id, logger: @logger)

    live_search.web_search(query, num_results: num_results)
  end

  def execute_x_keyword_search(args)
    query = validate_query(args)
    num_results = normalize_int(args['num_results'] || 5, default: 5, min: 1, max: 10)

    if query.empty?
      return { error: 'missing_query', message: 'x_keyword_search requires a query' }.to_json
    end

    @logger&.info({ event: 'tool_request', session_id: @session_id, tool: 'x_keyword_search', args: { query: query, num_results: num_results } })

    grok_client = GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])
    live_search = LiveSearch.new(grok_client: grok_client, session_id: @session_id, logger: @logger)

    live_search.x_keyword_search(query, limit: num_results)
  end

  def web_tools_definitions
    [
      {
        type: 'function',
        function: {
          name: 'web_search',
          description: 'Search the web for real-time information, news, or general knowledge.',
          parameters: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'The search query.' },
              num_results: { type: 'integer', description: 'Number of results (1-10, default 5).' }
            },
            required: [ 'query' ]
          }
        }
      },
      {
        type: 'function',
        function: {
          name: 'x_keyword_search',
          description: 'Search X (formerly Twitter) for recent posts and trends using keywords.',
          parameters: {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'The search keywords.' },
              num_results: { type: 'integer', description: 'Number of results (1-10, default 5).' }
            },
            required: [ 'query' ]
          }
        }
      }
    ]
  end

  def calculate_confidence(web, x, query)
    # Simple heuristic-based confidence score
    # web and x are raw JSON strings from LiveSearch
    score = 0.5

    web_parsed = JSON.parse(web) rescue nil
    x_parsed = JSON.parse(x) rescue nil

    web_results = web_parsed.is_a?(Array) ? web_parsed.size : 0
    x_results = x_parsed.is_a?(Array) ? x_parsed.size : 0

    score += 0.2 if web_results > 3
    score += 0.2 if x_results > 3
    score += 0.1 if query.length > 10

    [ score, 1.0 ].min
  end
end
