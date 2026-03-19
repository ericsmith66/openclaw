# frozen_string_literal: true

class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.string :path, null: false, index: { unique: true }
      t.jsonb :project_rules, null: false, default: {}
      t.timestamps
    end
  end
end
