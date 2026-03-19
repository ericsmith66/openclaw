class PersonaMessage < ApplicationRecord
  belongs_to :persona_conversation

  validates :role, presence: true, inclusion: { in: %w[user assistant] }
  validates :content, presence: true, if: -> { role == "user" }

  scope :user_role, -> { where(role: "user") }
  scope :assistant_role, -> { where(role: "assistant") }

  # metadata keys (best-effort):
  # - "sources": ["https://..."]
  # - "model": "grok-4-with-live-search" (requested model)
  # - "provider_model": "grok-4-0709" (actual model/version)

  after_commit :trigger_title_generation, on: :create

  private

  def trigger_title_generation
    return unless role == "user"

    persona_conversation.generate_title_from_first_message
  end
end
