class ConfirmationBubbleComponent < ViewComponent::Base
  def initialize(message_id:, command:, color_class:, label:, artifact_id: nil)
    @message_id = message_id
    @command = command
    @color_class = color_class
    @label = label
    @artifact_id = artifact_id
  end
end
