class AddWorkflowRunIdToArtifacts < ActiveRecord::Migration[8.1]
  def change
    add_reference :artifacts, :workflow_run, null: false, foreign_key: true
  end
end
