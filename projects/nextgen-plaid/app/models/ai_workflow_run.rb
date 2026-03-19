class AiWorkflowRun < ApplicationRecord
  belongs_to :user
  has_many_attached :attachments

  validates :status, presence: true
  validates :metadata, exclusion: { in: [ nil ] }

  validates :correlation_id, uniqueness: true, allow_nil: true

  STATUSES = %w[draft pending approved failed].freeze
  validates :status, inclusion: { in: STATUSES }

  scope :draft, -> { where(status: "draft") }
  scope :pending, -> { where(status: "pending") }
  scope :approved, -> { where(status: "approved") }
  scope :failed, -> { where(status: "failed") }

  # For RLS-like behavior in Rails
  scope :for_user, ->(user) { where(user: user) }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def transition_to(new_status, log_details = {})
    return false unless can_transition_to?(new_status)

    self.class.transaction do
      old_status = status
      update!(status: new_status)
      log_transition(old_status, new_status, log_details)
    end
    true
  end

  def can_transition_to?(new_status)
    case status
    when "draft"
      %w[pending failed].include?(new_status)
    when "pending"
      %w[approved failed].include?(new_status)
    when "approved"
      %w[failed].include?(new_status)
    when "failed"
      false
    else
      false
    end
  end

  def approve!(approver, details = {})
    transition_to("approved", details.merge(approver_id: approver.id))
  end

  def fail!(details = {})
    transition_to("failed", details)
  end

  def submit_for_approval!(details = {})
    transition_to("pending", details)
  end

  # Helper to access metadata easily
  def model_parameters
    metadata["parameters"] || {}
  end

  def model_parameters=(params)
    self.metadata["parameters"] = params
  end

  after_create_commit :broadcast_to_sidebar, unless: -> { Ai::TestMode.enabled? }
  after_create :auto_title!

  def auto_title!
    self.metadata ||= {}
    return if metadata["title"].present? || name.present?

    # Simple logic for now: use name if present, otherwise status and ID
    title = name.presence || "Run ##{id}: #{status.humanize}"
    self.metadata["title"] = title
    save! if persisted?
  end

  def active_artifact_id
    metadata["active_artifact_id"]
  end

  def active_artifact_id=(id)
    self.metadata["active_artifact_id"] = id
  end

  def active_artifact
    return nil if active_artifact_id.blank?
    Artifact.find_by(id: active_artifact_id)
  end

  def linked_artifact_ids
    metadata["linked_artifact_ids"] || []
  end

  def linked_artifact_ids=(ids)
    self.metadata["linked_artifact_ids"] = ids
  end

  private

  def broadcast_to_sidebar
    ActionCable.server.broadcast(
      "agent_hub_channel_all_agents", # General channel for sidebar updates
      {
        type: "sidebar_update",
        run_id: id,
        user_id: user_id,
        html: ApplicationController.render(
          ConversationSidebarComponent.new(conversations: [ self ]),
          layout: false
        )
      }
    )
  end

  def log_transition(from, to, details)
    self.metadata ||= {}
    self.metadata["audit_log"] ||= []
    self.metadata["audit_log"] << {
      event: "status_transition",
      from: from,
      to: to,
      at: Time.current,
      details: details
    }

    # Also update the top-level transitions for backward compatibility or easier access if needed
    self.metadata["transitions"] ||= []
    self.metadata["transitions"] << {
      from: from,
      to: to,
      at: Time.current,
      details: details
    }
    save!
  end
end
