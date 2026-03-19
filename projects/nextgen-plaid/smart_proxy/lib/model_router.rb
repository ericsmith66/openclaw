require_relative 'grok_client'
require_relative 'claude_client'
require_relative 'ollama_client'

class ModelRouter
  LIVE_SEARCH_SUFFIX = '-with-live-search'

  attr_reader :requested_model, :upstream_model, :tools_opt_in

  def initialize(requested_model)
    @requested_model = requested_model.to_s
    @tools_opt_in = @requested_model.end_with?(LIVE_SEARCH_SUFFIX)
    @upstream_model = @tools_opt_in ? @requested_model.sub(/#{LIVE_SEARCH_SUFFIX}\z/, '') : @requested_model
  end

  def route
    {
      provider: provider,
      client: client,
      upstream_model: @upstream_model,
      requested_model: @requested_model,
      tools_opt_in: @tools_opt_in,
      use_grok: use_grok?,
      use_claude: use_claude?
    }
  end

  private

  def provider
    if use_grok?
      :grok
    elsif use_claude?
      :claude
    else
      :ollama
    end
  end

  def client
    case provider
    when :grok
      GrokClient.new(api_key: grok_api_key)
    when :claude
      ClaudeClient.new(api_key: claude_api_key)
    else
      OllamaClient.new
    end
  end

  def use_grok?
    @upstream_model.start_with?('grok') && !grok_api_key.to_s.empty?
  end

  def use_claude?
    @upstream_model.start_with?('claude') && !claude_api_key.to_s.empty?
  end

  def grok_api_key
    ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY']
  end

  def claude_api_key
    ENV['CLAUDE_API_KEY']
  end
end
