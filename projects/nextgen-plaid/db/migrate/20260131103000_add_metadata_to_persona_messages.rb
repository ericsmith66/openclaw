class AddMetadataToPersonaMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :persona_messages, :metadata, :jsonb, null: false, default: {} unless column_exists?(:persona_messages, :metadata)
  end
end
