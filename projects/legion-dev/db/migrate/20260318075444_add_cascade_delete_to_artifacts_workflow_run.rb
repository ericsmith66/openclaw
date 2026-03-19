class AddCascadeDeleteToArtifactsWorkflowRun < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing FK without cascade, then re-add with on_delete: :cascade
    remove_foreign_key :artifacts, :workflow_runs
    add_foreign_key :artifacts, :workflow_runs, on_delete: :cascade
  end
end
