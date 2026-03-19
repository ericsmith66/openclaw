class CreateUserPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :user_preferences do |t|
      t.string :session_id, null: false
      t.jsonb :favorites, default: []
      t.jsonb :favorites_order, default: []

      t.timestamps
    end
    add_index :user_preferences, :session_id, unique: true
  end
end
