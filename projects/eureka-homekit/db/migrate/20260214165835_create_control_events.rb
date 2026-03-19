class CreateControlEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :control_events do |t|
      t.references :accessory, foreign_key: true, null: true
      t.references :scene, foreign_key: true, null: true
      t.string :action_type, null: false
      t.string :characteristic_name
      t.text :old_value
      t.text :new_value
      t.boolean :success, null: false, default: true
      t.text :error_message
      t.float :latency_ms
      t.string :user_ip
      t.string :request_id
      t.string :source

      t.timestamps
    end

    add_index :control_events, :action_type
    add_index :control_events, :success
    add_index :control_events, :created_at
    add_index :control_events, :request_id
  end
end
