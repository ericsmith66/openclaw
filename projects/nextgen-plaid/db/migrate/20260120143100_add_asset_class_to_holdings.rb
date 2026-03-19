class AddAssetClassToHoldings < ActiveRecord::Migration[8.1]
  def change
    add_column :holdings, :asset_class, :string
    add_column :holdings, :asset_class_source, :string
    add_column :holdings, :asset_class_derived_at, :datetime

    add_index :holdings, :asset_class
  end
end
