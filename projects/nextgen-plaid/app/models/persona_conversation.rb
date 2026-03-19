class PersonaConversation < ApplicationRecord
  belongs_to :user
  has_many :persona_messages, dependent: :destroy

  scope :for_persona, ->(persona_id) { where(persona_id: persona_id) }
  scope :for_user, ->(user) { where(user_id: user.id) }
  scope :recent_first, -> { order(updated_at: :desc) }

  validates :user_id, presence: true
  validates :persona_id, presence: true, inclusion: { in: ->(_) { Personas.ids } }
  validates :llm_model, presence: true
  validates :title, presence: true

  before_validation :set_default_llm_model, on: :create
  before_validation :set_default_title, on: :create

  def self.create_conversation(user_id:, persona_id:)
    last_llm_model = where(user_id: user_id, persona_id: persona_id)
      .order(updated_at: :desc)
      .limit(1)
      .pluck(:llm_model)
      .first

    persona = Personas.find(persona_id)
    default_model = persona&.fetch("default_model", nil) || "llama3.1:70b"

    create!(
      user_id: user_id,
      persona_id: persona_id,
      llm_model: last_llm_model.presence || default_model,
      title: "Chat #{Time.current.strftime('%b %d')}"
    )
  end

  def generate_title_from_first_message
    first_user_message = persona_messages.user_role.order(:created_at).first
    return unless first_user_message

    immediate_title = first_user_message.content.to_s
      .strip
      .truncate(40, separator: " ", omission: "...")
    immediate_title = fallback_title if immediate_title.blank?

    update!(title: immediate_title) if title.blank? || title.start_with?("Chat ")

    if persona_messages.user_role.count == 1
      TitleGenerationJob.perform_later(id)
    end
  end

  def last_message_preview
    content = persona_messages.order(:created_at).last&.content
    (content || "").truncate(60, omission: "...")
  end

  private

  def fallback_title
    ts = created_at || Time.current
    "Chat #{ts.strftime('%b %d')}"
  end

  def set_default_llm_model
    return if llm_model.present?

    persona = Personas.find(persona_id)
    self.llm_model = persona&.fetch("default_model", nil) || "llama3.1:70b"
  end

  def set_default_title
    self.title = fallback_title if title.blank?
  end
end
