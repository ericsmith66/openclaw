class AddMetadataToWorkflowExecutions < ActiveRecord::Migration[8.1]
  def change
    add_column :workflow_executions, :metadata, :jsonb
  end
end
