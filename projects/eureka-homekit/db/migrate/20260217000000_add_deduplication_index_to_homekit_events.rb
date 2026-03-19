class AddDeduplicationIndexToHomekitEvents < ActiveRecord::Migration[8.1]
  disable_ddl_transaction! # For concurrent index creation

  def change
    add_index :homekit_events, [ :sensor_id, :timestamp ],
      name: 'index_homekit_events_deduplication',
      algorithm: :concurrently,
      if_not_exists: true
  end
end
