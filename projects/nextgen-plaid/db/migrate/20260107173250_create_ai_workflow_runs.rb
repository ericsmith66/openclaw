class CreateAiWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_workflow_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: 'draft'
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :ai_workflow_runs, :status
    add_index :ai_workflow_runs, :metadata, using: :gin
  end
end
