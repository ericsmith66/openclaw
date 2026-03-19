module PersonaContextProviders
  class Registry
    UnknownProviderError = Class.new(StandardError)

    PROVIDERS = {
      "financial_snapshot" => "PersonaContextProviders::FinancialSnapshotProvider"
    }.freeze

    def self.build(provider_key)
      key = provider_key.to_s
      klass_name = PROVIDERS[key]
      raise UnknownProviderError, "Unknown provider: #{key}" if klass_name.blank?

      klass_name.constantize
    end
  end
end
