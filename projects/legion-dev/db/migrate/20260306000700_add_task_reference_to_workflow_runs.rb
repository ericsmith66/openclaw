# frozen_string_literal: true

class AddTaskReferenceToWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    add_reference :workflow_runs, :task, foreign_key: { to_table: :tasks }, null: true
  end
end
