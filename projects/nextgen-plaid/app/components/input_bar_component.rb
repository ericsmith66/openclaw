class InputBarComponent < ViewComponent::Base
  def initialize(placeholder: "Message agent...", agent_id:, run_id: nil)
    @placeholder = placeholder
    @agent_id = agent_id
    @run_id = run_id
    @available_models = AgentHub::ModelDiscoveryService.call
    @available_commands = AgentHub::CommandDiscoveryService.call(agent_id)
  end
end
