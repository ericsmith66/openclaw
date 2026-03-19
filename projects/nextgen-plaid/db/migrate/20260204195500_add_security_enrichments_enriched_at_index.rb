class AddSecurityEnrichmentsEnrichedAtIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :security_enrichments, :enriched_at unless index_exists?(:security_enrichments, :enriched_at)
  end
end
