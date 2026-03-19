class AddCorrelationIdToAiWorkflowRuns < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_workflow_runs, :correlation_id, :string
    add_index :ai_workflow_runs, :correlation_id, unique: true
  end
end
