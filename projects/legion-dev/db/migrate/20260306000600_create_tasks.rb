# frozen_string_literal: true

class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.references :project, null: false, foreign_key: true
      t.references :workflow_run, foreign_key: true, null: true  # parent decomposition run
      t.references :team_membership, null: false, foreign_key: true
      t.references :execution_run, foreign_key: { to_table: :workflow_runs }, null: true
      t.integer :position, null: false, default: 0
      t.text :prompt, null: false
      t.string :task_type, null: false
      t.string :status, null: false, default: "pending"
      t.integer :files_score
      t.integer :concepts_score
      t.integer :dependencies_score
      t.integer :total_score
      t.integer :estimated_iterations
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :tasks, [ :workflow_run_id, :position ]
    add_index :tasks, :status
  end
end
