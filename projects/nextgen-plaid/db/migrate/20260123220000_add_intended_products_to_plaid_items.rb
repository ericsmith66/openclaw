class AddIntendedProductsToPlaidItems < ActiveRecord::Migration[8.1]
  def change
    add_column :plaid_items, :intended_products, :string
  end
end
