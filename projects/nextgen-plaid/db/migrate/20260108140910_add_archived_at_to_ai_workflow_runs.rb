class AddArchivedAtToAiWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_workflow_runs, :archived_at, :datetime
    add_index :ai_workflow_runs, :archived_at
  end
end
