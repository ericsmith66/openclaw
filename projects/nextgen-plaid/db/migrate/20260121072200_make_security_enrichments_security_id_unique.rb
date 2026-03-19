class MakeSecurityEnrichmentsSecurityIdUnique < ActiveRecord::Migration[8.1]
  def change
    remove_index :security_enrichments, column: [ :security_id, :source ]
    add_index :security_enrichments, :security_id, unique: true
  end
end
