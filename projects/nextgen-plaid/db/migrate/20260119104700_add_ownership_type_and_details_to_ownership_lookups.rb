class AddOwnershipTypeAndDetailsToOwnershipLookups < ActiveRecord::Migration[8.1]
  def up
    add_column :ownership_lookups, :ownership_type, :string, default: "Other", null: false
    add_column :ownership_lookups, :details, :text

    add_index :ownership_lookups, :ownership_type

    ownership_lookups = Class.new(ActiveRecord::Base) do
      self.table_name = "ownership_lookups"
    end
    ownership_lookups.reset_column_information
    ownership_lookups.where(ownership_type: nil).update_all(ownership_type: "Other")
  end

  def down
    remove_index :ownership_lookups, :ownership_type
    remove_column :ownership_lookups, :details
    remove_column :ownership_lookups, :ownership_type
  end
end
