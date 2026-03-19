class AgentHub::CommandParser
  COMMANDS = {
    "handoff" => :handoff,
    "search" => :search,
    "backlog" => :backlog,
    "approve" => :approve,
    "reject" => :reject,
    "spike" => :spike,
    "plan" => :plan,
    "inspect" => :inspect,
    "save" => :save
  }.freeze

  def self.call(input)
    new(input).parse
  end

  def initialize(input)
    @input = input.to_s.strip
  end

  def parse
    return nil unless @input.start_with?("/")

    match = @input.match(%r{^/(\w+)(?:\s+(.*))?$})
    return nil unless match

    command_name = match[1]
    args = match[2]

    type = COMMANDS[command_name]

    if type
      {
        type: type,
        command: command_name,
        args: args,
        raw: @input
      }
    else
      {
        type: :unknown,
        command: command_name,
        args: args,
        raw: @input
      }
    end
  end
end
