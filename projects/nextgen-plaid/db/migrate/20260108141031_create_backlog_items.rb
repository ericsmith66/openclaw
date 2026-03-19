class CreateBacklogItems < ActiveRecord::Migration[8.1]
  def change
    create_table :backlog_items do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title
      t.text :content
      t.jsonb :metadata
      t.integer :priority

      t.timestamps
    end
  end
end
