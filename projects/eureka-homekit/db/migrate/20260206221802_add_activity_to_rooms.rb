class AddActivityToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :last_event_at, :datetime
    add_index :rooms, :last_event_at
    add_column :rooms, :last_motion_at, :datetime
    add_index :rooms, :last_motion_at
  end
end
