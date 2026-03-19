class AddRawDataToHomekitModels < ActiveRecord::Migration[8.1]
  def change
    add_column :homes, :raw_data, :jsonb, default: {}, null: false
    add_column :rooms, :raw_data, :jsonb, default: {}, null: false
    add_column :accessories, :raw_data, :jsonb, default: {}, null: false
    add_column :scenes, :raw_data, :jsonb, default: {}, null: false
  end
end
