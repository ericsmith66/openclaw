class AddLivenessToModels < ActiveRecord::Migration[8.1]
  def change
    add_column :sensors, :last_seen_at, :datetime
    add_index :sensors, :last_seen_at
    add_column :accessories, :last_seen_at, :datetime
    add_index :accessories, :last_seen_at
  end
end
