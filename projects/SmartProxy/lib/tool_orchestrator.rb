require 'json'

class ToolOrchestrator
  def initialize(executor:, logger: nil, session_id: nil)
    @executor = executor
    @logger = logger
    @session_id = session_id
  end

  def orchestrate(payload, routing:, max_loops: nil)
    max_loops = Integer(max_loops || ENV.fetch('SMART_PROXY_MAX_LOOPS', '3'))
    loop_count = 0
    tools_used = []
    tool_results = {}
    current_payload = payload.dup

    use_grok = routing[:use_grok]
    use_claude = routing[:use_claude]
    tools_opt_in = routing[:tools_opt_in]
    client = routing[:client]

    if (use_grok || use_claude) && @executor.web_tools_enabled? && tools_opt_in
      current_payload['stream'] = false
      if current_payload['tools'].nil? || Array(current_payload['tools']).empty?
        current_payload['tools'] = @executor.web_tools_definitions
      end
      current_payload['tool_choice'] ||= 'auto'

      # Option C: enforce a response contract for live-search models.
      # Require the final assistant response to cite sources from the tool results and
      # forbid guessing time-sensitive facts without tool evidence.
      current_payload['messages'] ||= []
      current_payload['messages'] = Array(current_payload['messages'])
      current_payload['messages'].unshift({
        role: 'system',
        content: "Live-search is enabled. If you answer time-sensitive questions (prices, breaking news, current events), you MUST call the web tools first. In your final answer you MUST include citations as URLs from the tool results and an 'as of' timestamp if applicable. If the tool results do not contain the needed fact, say you cannot verify and do not guess."
      })

      @logger&.info({
        event: 'live_search_enabled',
        session_id: @session_id,
        requested_model: payload['model'],
        upstream_model: current_payload['model']
      })
    end

    while loop_count <= max_loops
      response = if client.respond_to?(:chat_completions)
                   client.chat_completions(current_payload)
      else
                   client.chat(current_payload)
      end
      parsed = response.body.is_a?(String) ? (JSON.parse(response.body) rescue nil) : response.body

      return response unless parsed.is_a?(Hash) && parsed.key?('choices')

      choice = Array(parsed['choices']).first || {}
      message = choice['message'] || {}
      tool_calls = Array(message['tool_calls']).compact

      if tool_calls.empty?
        attach_tool_loop_metadata!(parsed, loop_count: loop_count, max_loops: max_loops, tools_used: tools_used, tool_results: tool_results)
        return response_with_body(response, parsed)
      end

      if tool_calls.any? { |tc| !@executor.web_tool_name?(tc.dig('function', 'name') || tc['name']) }
        attach_tool_loop_metadata!(parsed, loop_count: loop_count, max_loops: max_loops, tools_used: tools_used, tool_results: tool_results)
        return response_with_body(response, parsed)
      end

      if loop_count >= max_loops
        attach_tool_loop_metadata!(parsed, loop_count: loop_count, max_loops: max_loops, tools_used: tools_used, tool_results: tool_results, stopped: 'max_loops')
        return response_with_body(response, parsed)
      end

      current_payload['messages'] ||= []
      current_payload['messages'] = Array(current_payload['messages'])
      current_payload['messages'] << message

      tool_calls.each do |tool_call|
        tool_name = tool_call.dig('function', 'name') || tool_call['name']
        tool_args = tool_call.dig('function', 'arguments') || tool_call['arguments']
        tool_call_id = tool_call['id'] || tool_call[:id]

        result = @executor.execute(tool_name, tool_args)
        tools_used << { name: tool_name, tool_call_id: tool_call_id }.compact

        tool_results[tool_name] ||= []
        tool_results[tool_name] << begin
          JSON.parse(result)
        rescue StandardError
          { raw: result.to_s }
        end

        current_payload['messages'] << {
          role: 'tool',
          tool_call_id: tool_call_id,
          content: result
        }.compact
      end

      loop_count += 1
    end

    # This part should ideally not be reached if the loop logic is correct,
    # but kept for consistency with original code.
    final_response = if client.respond_to?(:chat_completions)
                       client.chat_completions(current_payload)
    else
                       client.chat(current_payload)
    end
    parsed = final_response.body.is_a?(String) ? (JSON.parse(final_response.body) rescue nil) : final_response.body
    if parsed.is_a?(Hash) && parsed.key?('choices')
      attach_tool_loop_metadata!(parsed, loop_count: loop_count, max_loops: max_loops, tools_used: tools_used, tool_results: tool_results)
      response_with_body(final_response, parsed)
    else
      final_response
    end
  end

  private

  def attach_tool_loop_metadata!(parsed, loop_count:, max_loops:, tools_used:, tool_results: nil, stopped: nil)
    parsed['smart_proxy'] ||= {}
    parsed['smart_proxy']['tool_loop'] = {
      loop_count: loop_count,
      max_loops: max_loops
    }.tap { |h| h['stopped'] = stopped if stopped }
    parsed['smart_proxy']['tools_used'] = tools_used

    # Option A: always return structured tool outputs in the final response.
    if tool_results && !tool_results.empty?
      parsed['smart_proxy']['tool_results'] = tool_results

      # Convenience: include a flattened list of cited source URLs when present.
      urls = tool_results.values.flatten.filter_map do |obj|
        next unless obj.is_a?(Hash)
        results = obj['results'] || obj[:results]
        next unless results.is_a?(Array)
        results.map { |r| r.is_a?(Hash) ? (r['url'] || r[:url]) : nil }
      end.flatten.compact.uniq
      parsed['smart_proxy']['sources'] = urls if urls.any?
    end
  end

  def response_with_body(response, parsed_body)
    # Using a simple struct to mimic Response if needed,
    # but the client response usually has status and body.
    # In SmartProxyApp, Response = Struct.new(:status, :body)
    # We'll return an object that responds to status and body.
    if response.respond_to?(:status)
      Struct.new(:status, :body).new(response.status, parsed_body.to_json)
    else
      parsed_body.to_json
    end
  end
end
