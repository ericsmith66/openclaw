class AddArtifactIdToSapRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :sap_runs, :artifact_id, :integer
  end
end
