class SapRun < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :artifact, optional: true
  has_many :sap_messages, dependent: :destroy

  enum :status, {
    pending: "pending",
    running: "running",
    paused: "paused",
    complete: "complete",
    failed: "failed",
    aborted: "aborted"
  }, suffix: true

  enum :conversation_type, {
    single_persona: "single_persona",
    multi_persona: "multi_persona",
    workflow: "workflow"
  }, suffix: true

  validates :correlation_id, presence: true, uniqueness: true

  scope :recent, -> { order(started_at: :desc).limit(50) }
  scope :for_user_and_persona, ->(user_id, persona_id) {
    base_persona = persona_id.to_s.gsub("-agent", "")
    where(user_id: user_id)
      .where("correlation_id LIKE ?", "agent-hub-#{base_persona}-%")
      .where.not(status: [ :aborted, :failed ])
      .order(updated_at: :desc)
  }
  scope :active, -> { where.not(status: [ :aborted, :failed ]) }

  before_validation :generate_title, on: :create, if: -> { title.blank? }

  def self.create_conversation(user_id:, persona_id:, title: nil)
    conversation_id = SecureRandom.uuid
    correlation_id = "agent-hub-#{persona_id}-#{user_id}-#{conversation_id}"

    create!(
      user_id: user_id,
      correlation_id: correlation_id,
      title: title || "New Conversation",
      status: :pending,
      conversation_type: :single_persona
    )
  end

  def redacted_user_label
    return "User-unknown" unless user_id
    digest = Digest::SHA256.hexdigest(user_id.to_s)[0..7]
    "User-#{digest}"
  end

  def generate_title_from_first_message
    first_user_message = sap_messages.user_role.first
    if first_user_message && title == "New Conversation"
      self.title = first_user_message.content.truncate(50, omission: "...")
      save
    end
  end

  private

  def generate_title
    self.title ||= "New Conversation"
  end
end
