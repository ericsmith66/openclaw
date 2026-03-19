class AddHoldingsGridIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :holdings, [ :security_id, :market_value ] unless index_exists?(:holdings, [ :security_id, :market_value ])
    add_index :holdings, [ :security_id, :account_id ] unless index_exists?(:holdings, [ :security_id, :account_id ])

    # `security_enrichments` is currently unique per `security_id`, but PRD 5-02 expects
    # quick lookups by `enriched_at` as well.
    add_index :security_enrichments, [ :security_id, :enriched_at ] unless index_exists?(:security_enrichments, [ :security_id, :enriched_at ])
  end
end
