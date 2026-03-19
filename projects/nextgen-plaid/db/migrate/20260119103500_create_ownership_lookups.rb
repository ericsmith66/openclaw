class CreateOwnershipLookups < ActiveRecord::Migration[8.1]
  def change
    create_table :ownership_lookups do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :ownership_lookups, :name
  end
end
