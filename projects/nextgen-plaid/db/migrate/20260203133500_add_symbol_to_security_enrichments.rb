class AddSymbolToSecurityEnrichments < ActiveRecord::Migration[8.1]
  def change
    add_column :security_enrichments, :symbol, :string
    add_index :security_enrichments, :symbol
  end
end
