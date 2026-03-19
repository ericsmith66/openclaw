# frozen_string_literal: true

class CreateWorkflowEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :workflow_events do |t|
      t.references :workflow_run, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :channel
      t.string :agent_id
      t.string :task_id
      t.jsonb :payload, null: false, default: {}
      t.datetime :recorded_at, null: false
      t.timestamps
    end

    add_index :workflow_events, [ :workflow_run_id, :event_type ]
    add_index :workflow_events, :recorded_at
  end
end
