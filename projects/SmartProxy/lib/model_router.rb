require_relative 'grok_client'
require_relative 'claude_client'
require_relative 'deepseek_client'
require_relative 'fireworks_client'
require_relative 'openrouter_client'
require_relative 'ollama_client'
require_relative 'mlx_client'

class ModelRouter
  LIVE_SEARCH_SUFFIX = '-with-live-search'
  MLX_PREFIX         = 'mlx/'

  attr_reader :requested_model, :upstream_model, :tools_opt_in

  def initialize(requested_model)
    @requested_model = requested_model.to_s
    @tools_opt_in    = @requested_model.end_with?(LIVE_SEARCH_SUFFIX)
    base             = @tools_opt_in ? @requested_model.sub(/#{LIVE_SEARCH_SUFFIX}\z/, '') : @requested_model
    @upstream_model  = base.start_with?(MLX_PREFIX) ? base.sub(MLX_PREFIX, '') : base
  end

  def route
    {
      provider:       provider,
      client:         client,
      upstream_model: @upstream_model,
      requested_model: @requested_model,
      tools_opt_in:   @tools_opt_in,
      use_grok:       use_grok?,
      use_claude:     use_claude?,
      use_deepseek:   use_deepseek?,
      use_fireworks:  use_fireworks?,
      use_openrouter: use_openrouter?,
      use_mlx:        use_mlx?
    }
  end

  def use_mlx?
    @requested_model.start_with?(MLX_PREFIX)
  end

  private

  def provider
    if use_mlx?
      :mlx
    elsif use_grok?
      :grok
    elsif use_claude?
      :claude
    elsif use_deepseek?
      :deepseek
    elsif use_fireworks?
      :fireworks
    elsif use_openrouter?
      :openrouter
    else
      :ollama
    end
  end

  def client
    case provider
    when :mlx
      MlxClient.new
    when :grok
      GrokClient.new(api_key: grok_api_key)
    when :claude
      ClaudeClient.new(api_key: claude_api_key)
    when :deepseek
      DeepSeekClient.new(api_key: deepseek_api_key)
    when :fireworks
      FireworksClient.new(api_key: fireworks_api_key)
    when :openrouter
      OpenRouterClient.new(api_key: openrouter_api_key)
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

  def use_deepseek?
    @upstream_model.start_with?('deepseek') && !deepseek_api_key.to_s.empty?
  end

  def deepseek_api_key
    ENV['DEEPSEEK_API_KEY']
  end

  def use_fireworks?
    @upstream_model.start_with?('accounts/fireworks/') && !fireworks_api_key.to_s.empty?
  end

  def fireworks_api_key
    ENV['FIREWORKS_API_KEY']
  end

  def use_openrouter?
    @upstream_model.include?('/') && !use_fireworks? && !openrouter_api_key.to_s.empty?
  end

  def openrouter_api_key
    ENV['OPENROUTER_API_KEY']
  end
end
