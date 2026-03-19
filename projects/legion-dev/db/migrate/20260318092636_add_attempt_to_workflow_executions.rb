class AddAttemptToWorkflowExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_executions, :attempt, :integer, default: 0, null: false
  end
end
