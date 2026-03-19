class AgentHub::MentionParser
  # Maps common names/aliases to valid agent IDs
  PERSONA_MAP = {
    "sap" => "sap-agent",
    "conductor" => "conductor-agent",
    "cwa" => "cwa-agent",
    "aifinancialadvisor" => "ai_financial_advisor-agent",
    "financialadvisor" => "ai_financial_advisor-agent"
  }.freeze

  def self.call(input)
    new(input).parse
  end

  def initialize(input)
    @input = input.to_s.strip
  end

  def parse
    match = @input.match(/@(\w+)/)
    return nil unless match

    mention = match[1].downcase
    agent_id = PERSONA_MAP[mention]

    return nil unless agent_id

    {
      agent_id: agent_id,
      mention: mention,
      clean_content: @input.gsub(/@#{mention}/i, "").strip
    }
  end
end
