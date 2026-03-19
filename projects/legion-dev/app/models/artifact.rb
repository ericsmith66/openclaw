# frozen_string_literal: true

class Artifact < ApplicationRecord
  belongs_to :workflow_run
  belongs_to :workflow_execution, optional: true
  belongs_to :created_by, class_name: "AgentTeam", optional: true
  belongs_to :parent_artifact, class_name: "Artifact", optional: true
  belongs_to :project

  has_many :child_artifacts, class_name: "Artifact", foreign_key: :parent_artifact_id, dependent: :nullify

  enum :artifact_type, {
    plan: "plan",
    code_output: "code_output",
    score_report: "score_report",
    architect_review: "architect_review",
    review_feedback: "review_feedback",
    retry_context: "retry_context",
    retrospective_report: "retrospective_report"
  }, validate: true

  validates :artifact_type, presence: true
  validates :content, presence: true
  validates :workflow_run, presence: true
  validates :project, presence: true
  validates :name, presence: true

  attribute :metadata, :jsonb, default: {}

  scope :score_reports, -> { where(artifact_type: :score_report) }
  scope :architect_reviews, -> { where(artifact_type: :architect_review) }
  scope :plans, -> { where(artifact_type: :plan) }
  scope :retrospective_reports, -> { where(artifact_type: :retrospective_report) }
  scope :retry_contexts, -> { where(artifact_type: :retry_context) }
  scope :review_feedbacks, -> { where(artifact_type: :review_feedback) }
  scope :for_execution, ->(execution_id) { where(workflow_execution_id: execution_id) }

  before_validation :set_version, on: :create
  before_validation :set_project_from_workflow_run, on: :create
  before_validation :set_created_by_from_team_membership, on: :create

  def self.create_with_version!(attributes)
    max_retries = 3
    max_retries.times do |retry_count|
      begin
        transaction do
          version_number = where(
            workflow_execution_id: attributes[:workflow_execution_id],
            artifact_type: attributes[:artifact_type]
          ).maximum(:version_number).to_i + 1
          record = create!(attributes.merge(version_number: version_number))
          return record
        end
      rescue ActiveRecord::RecordNotUnique
        raise if retry_count == max_retries - 1
        sleep(0.01 * (retry_count + 1))
        retry
      end
    end
  end

  private

  def set_version
    if workflow_execution_id && artifact_type
      max_version = self.class.where(
        workflow_execution_id: workflow_execution_id,
        artifact_type: artifact_type
      ).maximum(:version_number).to_i
      self.version_number = max_version + 1
      self.version = "#{max_version + 1}.0.0"
    else
      self.version_number ||= 1
      self.version ||= "1.0.0"
    end
  end

  def set_project_from_workflow_run
    self.project = workflow_run.project if workflow_run && project.nil?
  end

  def set_created_by_from_team_membership
    self.created_by = workflow_run&.team_membership&.agent_team if workflow_run && created_by.nil?
  end
end
