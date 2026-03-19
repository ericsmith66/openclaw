class AddIndexesToSecurityEnrichments < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    add_index :security_enrichments, :price, algorithm: :concurrently
    add_index :security_enrichments, :market_cap, algorithm: :concurrently
    add_index :security_enrichments, :roe, algorithm: :concurrently
    add_index :security_enrichments, :pe_ratio, algorithm: :concurrently
    add_index :security_enrichments, :sector, algorithm: :concurrently
    add_index :security_enrichments, :industry, algorithm: :concurrently
    add_index :security_enrichments, :status, algorithm: :concurrently

    add_index :security_enrichments, [ :sector, :status ], algorithm: :concurrently
    add_index :security_enrichments, [ :industry, :status ], algorithm: :concurrently

    add_index :security_enrichments,
              :company_name,
              using: :gin,
              opclass: { company_name: :gin_trgm_ops },
              algorithm: :concurrently
  end
end
