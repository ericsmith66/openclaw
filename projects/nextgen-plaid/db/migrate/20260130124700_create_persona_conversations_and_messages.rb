class CreatePersonaConversationsAndMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :persona_conversations, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :persona_id, null: false
      t.string :llm_model, null: false
      t.string :title, null: false

      t.timestamps
    end

    add_index :persona_conversations, [ :user_id, :persona_id ], if_not_exists: true

    create_table :persona_messages, if_not_exists: true do |t|
      t.references :persona_conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false

      t.timestamps
    end
  end
end
