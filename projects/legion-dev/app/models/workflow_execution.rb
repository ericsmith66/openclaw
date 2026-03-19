# frozen_string_literal: true

class WorkflowExecution < ApplicationRecord
  belongs_to :project
  belongs_to :agent_team, optional: true
  has_many :tasks, dependent: :nullify
  has_many :workflow_runs, dependent: :nullify
  has_many :artifacts, dependent: :nullify
  has_many :conductor_decisions, dependent: :destroy

  # Temporary workaround: find team through project's first team or workflow_runs
  def team
    agent_team || project.agent_teams.first || workflow_runs.first&.team_membership&.agent_team
  end

  enum :status, {
    running: "running",
    completed: "completed",
    failed: "failed"
  }, validate: true

  enum :phase, {
    decomposing: "decomposing",
    executing: "executing",
    planning: "planning",
    reviewing: "reviewing",
    validating: "validating",
    synthesizing: "synthesizing",
    iterating: "iterating",
    phase_completed: "phase_completed",
    cancelled: "cancelled"
  }, validate: true

  validates :concurrency, numericality: { greater_than: 0 }
  validates :task_retry_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :project, presence: true
  validates :prd_path, presence: true

  # Loads PRD content from file system into prd_snapshot
  def load_prd_snapshot!
    return unless prd_path.present?
    self.prd_snapshot = File.read(prd_path)
    self.prd_content_hash = Digest::MD5.hexdigest(prd_snapshot)
  end

  # Computes MD5 hash of prd_snapshot content
  def prd_content_hash!
    return unless prd_snapshot.present?
    self.prd_content_hash = Digest::MD5.hexdigest(prd_snapshot)
  end

  # Default values
  def attempt
    read_attribute(:attempt) || 0
  end

  def decomposition_attempt
    read_attribute(:decomposition_attempt) || 0
  end

  def task_retry_limit
    read_attribute(:task_retry_limit) || 3
  end

  def sequential
    read_attribute(:sequential) || false
  end

  def concurrency
    read_attribute(:concurrency) || 3
  end

  def workflow_run
    workflow_runs.first
  end
end
