class ChatPaneComponent < ViewComponent::Base
  delegate :markdown, to: :helpers

  def initialize(agent_id: nil, conversation: nil)
    @agent_id = agent_id
    @conversation = conversation
    @messages = conversation&.sap_messages&.order(:created_at) || []
  end
end
