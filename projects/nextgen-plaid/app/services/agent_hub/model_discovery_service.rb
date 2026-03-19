module AgentHub
  class ModelDiscoveryService
    CACHE_KEY = "agent_hub_discovered_models"
    CACHE_EXPIRY = 1.hour

    def self.call(force_refresh: false)
      new.discover(force_refresh: force_refresh)
    end

    def discover(force_refresh: false)
      if force_refresh
        Rails.cache.delete(CACHE_KEY)
      end

      models = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_EXPIRY) do
        fetch_from_proxy
      end

      models || fallback_models
    end

    private

    def fetch_from_proxy
      base_url = Agents.configuration.openai_api_base if defined?(Agents) && Agents.respond_to?(:configuration)
      base_url ||= ENV.fetch("OPENAI_API_BASE", "http://localhost:11434/v1")
      api_key = Agents.configuration.openai_api_key if defined?(Agents) && Agents.respond_to?(:configuration)
      api_key ||= ENV.fetch("OPENAI_API_KEY", "ollama")

      # Ensure base_url ends with /v1 if we're calling /models and it's missing
      # but Ollama usually expects /v1/models or /api/tags
      # If it's the smart proxy, it depends on its implementation.

      uri = URI.parse("#{base_url}/models")
      Rails.logger.debug("[ModelDiscovery] Fetching from #{uri}")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 5
      http.read_timeout = 5

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{api_key}" if api_key

      res = http.request(req)
      return nil unless res.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(res.body)
      discovered = Array(parsed["data"]).map { |m| m["id"] }.compact

      Rails.logger.info(JSON.generate({ event: "model_discovery_success", count: discovered.size }))
      prioritize_models(discovered)
    rescue StandardError => e
      Rails.logger.warn(JSON.generate({ event: "model_discovery_failed", error: e.message }))
      nil
    end

    def prioritize_models(models)
      # Prioritize llama3.1:70b as the default model
      preferred_model = "llama3.1:70b"

      if models.include?(preferred_model)
        # Move preferred model to the front
        [ preferred_model ] + (models - [ preferred_model ])
      else
        models
      end
    end

    def fallback_models
      [
        ENV.fetch("AI_DEFAULT_MODEL", "llama3.1:70b"),
        ENV.fetch("AI_DEV_MODEL", "llama3.1:8b")
      ].uniq
    end
  end
end
