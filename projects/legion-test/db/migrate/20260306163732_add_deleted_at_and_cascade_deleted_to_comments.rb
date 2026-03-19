class AddDeletedAtAndCascadeDeletedToComments < ActiveRecord::Migration[8.1]
  def change
    add_column :comments, :deleted_at, :datetime
    add_column :comments, :cascade_deleted, :boolean, default: false, null: false
    add_index :comments, :deleted_at
    add_index :comments, :cascade_deleted
  end
end