class Artifact < ApplicationRecord
  # PHASES defined in PRD-AH-009B
  PHASES = %w[
    backlog
    ready_for_analysis
    in_analysis
    planning
    ready_for_development
    in_development
    ready_for_qa
    complete
  ].freeze

  validates :name, presence: true
  validates :artifact_type, presence: true
  validates :phase, inclusion: { in: PHASES }
  validates :owner_persona, presence: true

  has_many :sap_runs, dependent: :nullify

  # Default phase and owner if not set
  after_initialize :set_defaults, if: :new_record?

  def transition_to(action, actor_persona, rag_request_id: nil)
    next_phase = determine_next_phase(action)
    return false unless next_phase

    old_phase = phase
    self.phase = next_phase
    self.owner_persona = determine_next_owner(next_phase)

    # Audit trail
    self.payload ||= {}
    self.payload["audit_trail"] ||= []
    self.payload["audit_trail"] << {
      "from_phase" => old_phase,
      "to_phase" => next_phase,
      "action" => action,
      "actor_persona" => actor_persona,
      "rag_request_id" => rag_request_id,
      "timestamp" => Time.current
    }.compact

    save!
  end

  private

  def determine_next_phase(action)
    case action
    when "approve"
      case phase
      when "backlog" then "ready_for_analysis"
      when "ready_for_analysis" then "in_analysis"
      when "in_analysis" then "planning"
      when "planning" then "ready_for_development"
      when "ready_for_development" then "in_development"
      when "in_development" then "ready_for_qa"
      when "ready_for_qa" then "complete"
      else phase
      end
    when "finalize_prd"
      "in_analysis"
    when "move_to_analysis"
      "in_analysis"
    when "start_planning"
      "planning"
    when "approve_plan"
      "ready_for_development"
    when "start_implementation"
      "in_development"
    when "reject"
      case phase
      when "ready_for_analysis" then "backlog"
      when "in_analysis" then "ready_for_analysis"
      when "planning" then "in_analysis"
      when "ready_for_development" then "planning"
      when "in_development" then "ready_for_development"
      when "ready_for_qa" then "in_development"
      else phase
      end
    when "backlog"
      "backlog"
    else
      nil
    end
  end

  def determine_next_owner(next_phase)
    case next_phase
    when "backlog", "ready_for_analysis" then "SAP"
    when "in_analysis", "planning" then "Coordinator"
    when "ready_for_development", "in_development" then "CWA"
    when "ready_for_qa" then "Coordinator"
    when "complete" then "Human"
    else owner_persona
    end
  end
  def set_defaults
    self.phase ||= "backlog"
    self.owner_persona ||= determine_next_owner(self.phase)
    self.payload ||= {}
  end
end
