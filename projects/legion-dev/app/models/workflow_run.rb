# frozen_string_literal: true

class WorkflowRun < ApplicationRecord
  belongs_to :project
  belongs_to :team_membership
  belongs_to :task, optional: true
  belongs_to :workflow_execution, optional: true
  has_many :workflow_events, dependent: :destroy
  has_many :tasks, foreign_key: :workflow_run_id, dependent: :nullify
  has_many :artifacts, dependent: :destroy

  enum :status, {
    queued: "queued",
    running: "running",
    completed: "completed",
    failed: "failed",
    at_risk: "at_risk",
    decomposing: "decomposing",
    handed_off: "handed_off",
    budget_exceeded: "budget_exceeded",
    iteration_limit: "iteration_limit"
  }, validate: true

  validates :prompt, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :for_team, ->(team) { joins(:team_membership).where(team_memberships: { agent_team: team }) }
end
