# frozen_string_literal: true

class CreateWorkflowRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_runs do |t|
      t.references :project, null: false, foreign_key: true
      t.references :team_membership, null: false, foreign_key: true
      t.text :prompt, null: false
      t.string :status, null: false, default: "queued"
      t.integer :iterations, default: 0
      t.integer :duration_ms
      t.text :result
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :workflow_runs, :status
    add_index :workflow_runs, :created_at
  end
end
