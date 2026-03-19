class DropHoldingEnrichments < ActiveRecord::Migration[8.1]
  def change
    drop_table :holding_enrichments, if_exists: true
  end
end
