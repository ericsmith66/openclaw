module AgentHub
  class CommandDiscoveryService
    # Map personas to their specific commands
    PERSONA_COMMANDS = {
      "sap-agent" => %w[handoff search approve],
      "conductor-agent" => %w[handoff search backlog],
      "cwa-agent" => %w[handoff search build test],
      "ai_financial_advisor-agent" => %w[handoff search],
      "debug-agent" => %w[handoff search clear reset]
    }.freeze

    DEFAULT_COMMANDS = %w[handoff search].freeze

    def self.call(persona_id)
      PERSONA_COMMANDS[persona_id] || DEFAULT_COMMANDS
    end
  end
end
