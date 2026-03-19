# ModelFilter applies a pipeline of filters and decorators to a list of model hashes.
# The pipeline consists of:
# 1. Text guard — reject models where `modalities` is present but does not include 'text'
# 2. Tools guard — reject models where `supported_parameters` is present but does not include 'tools',
#    only when env['MODELS_REQUIRE_TOOLS'] == 'true'
# 3. Blacklist — reject models whose `id` matches any pattern from MODELS_BLACKLIST + <PROVIDER>_MODELS_BLACKLIST
# 4. Include override — rescue blacklisted models whose `id` matches any pattern from MODELS_INCLUDE + <PROVIDER>_MODELS_INCLUDE
# 5. Synthetic decoration — append `-with-live-search` variant hashes for models matching WITH_LIVE_SEARCH_MODELS regex
class ModelFilter
  # @param provider [String, nil] Provider name (e.g., 'openrouter'). If nil, extracted from model id prefix.
  # @param env [Hash] Environment variables, defaults to ENV.
  def initialize(provider: nil, env: ENV)
    @provider = provider
    @env = env
  end

  # Filters and decorates the given array of model hashes.
  # @param models [Array<Hash>] Each hash may have string or symbol keys.
  # @return [Array<Hash>] Filtered and decorated models.
  def call(models)
    kept = filter_pipeline(models)
    variants = live_search_variants(kept, live_search_regex)
    kept + variants
  end
  alias apply call

  # Parses a comma-separated string of regex patterns.
  # Returns an empty array for nil or empty string.
  # @param str [String, nil]
  # @return [Array<Regexp>]
  def self.parse_patterns(str)
    return [] if str.nil? || str.empty?
    str.split(',').map(&:strip).reject(&:empty?).map do |p|
      Regexp.new(p, Regexp::IGNORECASE)
    end
  end

  private

  # Returns the provider extracted from the model's id (prefix before first slash).
  # If @provider is given, returns that (upcased) for all models.
  def provider_for(model)
    return @provider.upcase if @provider
    id = string_key(model, :id).to_s
    return nil unless id.include?('/')
    id.split('/').first.upcase
  end

  # Safely reads a value from a hash with either string or symbol keys.
  def string_key(hash, key)
    hash[key] || hash[key.to_s]
  end

  # Returns true if the model is text-capable.
  def text_capable?(model)
    modalities = string_key(model, :modalities)
    return true if modalities.nil?
    Array(modalities).include?('text')
  end

  # Returns true if the model is tools-capable.
  def tools_capable?(model)
    supported = string_key(model, :supported_parameters)
    return true if supported.nil?
    Array(supported).include?('tools')
  end

  # Returns regexp for live-search variants, or nil if disabled.
  def live_search_regex
    pattern = @env['WITH_LIVE_SEARCH_MODELS']
    # Default to '^claude-' if key is absent; empty string disables.
    return Regexp.new('^claude-') if pattern.nil?
    return nil if pattern.empty?
    Regexp.new(pattern)
  end

  # Combines global and per-provider patterns for blacklist.
  def blacklist_patterns(provider)
    global = self.class.parse_patterns(@env['MODELS_BLACKLIST'])
    per_provider = if provider
                     self.class.parse_patterns(@env["#{provider}_MODELS_BLACKLIST"])
                   else
                     []
                   end
    global + per_provider
  end

  # Combines global and per-provider patterns for include override.
  def include_patterns(provider)
    global = self.class.parse_patterns(@env['MODELS_INCLUDE'])
    per_provider = if provider
                     self.class.parse_patterns(@env["#{provider}_MODELS_INCLUDE"])
                   else
                     []
                   end
    global + per_provider
  end

  # Applies the filter pipeline (steps 1-4) and returns kept models.
  def filter_pipeline(models)
    models.select do |model|
      next false unless text_capable?(model)
      next false if tools_guard_active? && !tools_capable?(model)
      next false if blacklisted?(model) && !included?(model)
      true
    end
  end

  def tools_guard_active?
    @env['MODELS_REQUIRE_TOOLS'] == 'true'
  end

  # Determines if a model matches any blacklist pattern.
  def blacklisted?(model)
    provider = provider_for(model)
    patterns = blacklist_patterns(provider)
    id = string_key(model, :id).to_s
    patterns.any? { |regex| regex.match?(id) }
  end

  # Determines if a model matches any include pattern (overrides blacklist).
  def included?(model)
    provider = provider_for(model)
    patterns = include_patterns(provider)
    id = string_key(model, :id).to_s
    patterns.any? { |regex| regex.match?(id) }
  end

  # Generates live-search variants for matching models.
  def live_search_variants(models, regex)
    return [] if regex.nil?
    models.flat_map do |model|
      id = string_key(model, :id).to_s
      next [] unless regex.match?(id)
      variant = model.dup
      variant[:id] = "#{id}-with-live-search"
      variant[:smart_proxy] = (string_key(variant, :smart_proxy) || {}).dup
      variant[:smart_proxy][:features] = Array(variant[:smart_proxy][:features]) | %w[live-search tools]
      variant
    end
  end
end