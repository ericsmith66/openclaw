
require 'net/http'
require 'json'
require 'uri'

# Replace with your actual xAI API key via ENV for security


def send_request(messages, tools = nil, search_params = nil, model = 'grok-4', temperature = 0.5)
  api_key = ENV['XAI_KEY'] || 'xai-changeme'

  uri = URI.parse('https://api.x.ai/v1/chat/completions')
  request = Net::HTTP::Post.new(uri)
  request.content_type = 'application/json'
  request['Authorization'] = "Bearer #{api_key}"

  payload = {
    messages: messages,
    model: model,
    temperature: temperature,
    stream: false
  }
  payload[:tools] = tools if tools
  payload[:search_parameters] = search_params if search_params

  request.body = JSON.dump(payload)

  req_options = { use_ssl: uri.scheme == 'https' }

  response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
    http.request(request)
  end

  if response.code.to_i == 200
    JSON.parse(response.body)
  else
    raise "API Error: #{response.code} - #{response.message}\n#{response.body}"
  end
end

def perform_web_search(query, num_results = 3)
  # Use another x.ai API call to simulate/execute the web search using Grok's internal capabilities
  # This keeps all calls within x.ai, no external sites
  search_messages = [
    { role: 'user', content: "Search the web for '#{query}' and return the top #{num_results} results as a JSON object: {results: [{title: string, url: string, snippet: string}]} without any additional text." }
  ]
  search_params = {
    mode: 'on',
    sources: [ { type: 'web' }, { type: 'news' } ],
    max_search_results: num_results,
    return_citations: true
  }

  response = send_request(search_messages, nil, search_params)
  content = response['choices'][0]['message']['content']

  # Parse the JSON from Grok's response (assuming it follows the format)
  begin
    JSON.parse(content)
  rescue JSON::ParserError
    raise "Failed to parse search results: #{content}"
  end.to_json  # Return as string for tool content
end

begin
  # Initial messages and tools (new agentic format: define web_search tool)
  initial_messages = [
    { role: 'user', content: 'What is the latest stock price of Tesla (TSLA)?' }
  ]
  tools = [
    {
      type: 'function',
      function: {
        name: 'web_search',
        description: 'Search the web for real-time information like stock prices.',
        parameters: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'The search query (e.g., latest Tesla TSLA stock price).'
            },
            num_results: {
              type: 'integer',
              description: 'Number of results to return (default 3).'
            }
          },
          required: [ 'query' ]
        }
      }
    }
  ]

  # Send initial request
  puts "Sending initial request..."
  initial_response = send_request(initial_messages, tools)

  # Handle tool calls (agentic flow)
  choice = initial_response['choices'][0]
  if choice['finish_reason'] == 'tool_calls'
    assistant_message = choice['message']
    tool_call = assistant_message['tool_calls'][0]
    function_name = tool_call['function']['name']
    arguments = JSON.parse(tool_call['function']['arguments'])
    tool_call_id = tool_call['id']

    puts "Tool call: #{function_name} with args #{arguments}"

    # Execute the tool using only x.ai API (inner call for search)
    if function_name == 'web_search'
      tool_result = perform_web_search(arguments['query'], arguments['num_results'] || 3)
      puts "Tool result: #{tool_result}"
    else
      raise "Unexpected tool"
    end

    # Follow-up messages: append assistant's tool call + tool result
    follow_up_messages = initial_messages.dup
    follow_up_messages << assistant_message
    follow_up_messages << {
      role: 'tool',
      tool_call_id: tool_call_id,
      name: function_name,
      content: tool_result
    }

    # Send follow-up request
    puts "Sending follow-up request..."
    final_response = send_request(follow_up_messages)

    # Output final content
    final_content = final_response['choices'][0]['message']['content']
    puts "\nFinal Response:\n#{final_content}"
  else
    # Direct response (no tool needed)
    puts "\nDirect Response:\n#{choice['message']['content']}"
  end
rescue => e
  puts "Error: #{e.message}"
end
# Replace with your actual xAI API key via ENV for security


# uri = URI.parse('https://api.x.ai/v1/chat/completions')
# request = Net::HTTP::Post.new(uri)
# request.content_type = 'application/json'
# request['Authorization'] = "Bearer #{api_key}"

# payload = {
#  messages: [
#    { role: 'user', content: 'What is the latest stock price of Tesla (TSLA)?' }
#  ],
#  model: 'grok-4',
#  temperature: 0.5,
#  search_parameters: {
#    mode: 'on',  # Forces search; use 'auto' for model-decided
#    sources: [
#      { type: 'web' },
#      { type: 'news' }
#    ],  # Corrected: array of objects with 'type'
#    max_search_results: 3,
#    return_citations: true  # Includes source details in response
#  }
# }

# request.body = JSON.dump(payload)

# req_options = { use_ssl: uri.scheme == 'https' }

# response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
#  http.request(request)
# end

# if response.code.to_i == 200
#  data = JSON.parse(response.body)
#  puts "Response ID: #{data['id']}"
#  puts "Model: #{data['model']}"
#  puts "\nAssistant Content:\n#{data['choices'][0]['message']['content']}"
#  puts "\nCitations:" if data['citations']
#  data['citations']&.each { |cit| puts "- #{cit['title']} (#{cit['url']})" } if data['citations']
# else
#  puts "Error: #{response.code} - #{response.message}"
#  puts response.body
# end
