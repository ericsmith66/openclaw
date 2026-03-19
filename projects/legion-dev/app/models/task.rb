# frozen_string_literal: true

class Task < ApplicationRecord
  belongs_to :project
  belongs_to :workflow_run, optional: true
  belongs_to :workflow_execution, optional: true
  belongs_to :team_membership
  belongs_to :execution_run, class_name: "WorkflowRun", optional: true

  has_many :task_dependencies, dependent: :destroy
  has_many :dependencies, through: :task_dependencies, source: :depends_on_task

  has_many :inverse_task_dependencies, class_name: "TaskDependency", foreign_key: :depends_on_task_id, dependent: :destroy
  has_many :dependents, through: :inverse_task_dependencies, source: :task

  enum :task_type, {
    test: "test",
    code: "code",
    review: "review",
    debug: "debug"
  }, validate: true

  enum :status, {
    pending: "pending",
    ready: "ready",
    queued: "queued",
    running: "running",
    completed: "completed",
    failed: "failed",
    skipped: "skipped"
  }, validate: true

  validates :prompt, presence: true
  validates :files_score, inclusion: { in: 1..4 }, allow_nil: true
  validates :concepts_score, inclusion: { in: 1..4 }, allow_nil: true
  validates :dependencies_score, inclusion: { in: 1..4 }, allow_nil: true

  before_validation :compute_total_score

  scope :by_position, -> { order(position: :asc) }
  scope :ready, -> {
    where(status: [ :pending, :ready ])
      .left_joins(:dependencies)
      .group("tasks.id")
      .having("COUNT(CASE WHEN dependencies_tasks.status != 'completed' THEN 1 END) = 0")
  }
  scope :ready_for_run, ->(workflow_run) { where(workflow_run: workflow_run).ready }

  def dispatchable?
    (pending? || status == "ready") && dependencies.all?(&:completed?)
  end

  def over_threshold?
    total_score && total_score > 6
  end

  def parallel_eligible?
    dependencies.empty? || dependencies.all?(&:completed?)
  end

  def resettable?
    (status == "failed" || status == "skipped") && retry_count < 3
  end

  def error_context
    {
      retry_count: retry_count,
      last_error: last_error
    }
  end

  def error_context_enriched_prompt
    return prompt if retry_count.zero?

    context = "Previous attempt failed: #{last_error}. Fix this specific issue."
    context = context.first(2000)
    "#{prompt}\n\n#{context}"
  end

  private

  def compute_total_score
    if files_score && concepts_score && dependencies_score
      self.total_score = files_score + concepts_score + dependencies_score
    end
  end
end
