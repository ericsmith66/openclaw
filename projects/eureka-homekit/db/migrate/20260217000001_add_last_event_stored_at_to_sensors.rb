class AddLastEventStoredAtToSensors < ActiveRecord::Migration[8.1]
  def change
    add_column :sensors, :last_event_stored_at, :datetime
    add_index :sensors, :last_event_stored_at

    # Optional: Backfill for existing sensors (use last_updated_at as approximation)
    # This prevents every sensor from triggering a heartbeat event on first webhook
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE sensors
          SET last_event_stored_at = last_updated_at
          WHERE last_updated_at IS NOT NULL
            AND last_event_stored_at IS NULL;
        SQL
      end
    end
  end
end
