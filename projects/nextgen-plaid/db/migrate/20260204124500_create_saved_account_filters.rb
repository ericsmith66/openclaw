class CreateSavedAccountFilters < ActiveRecord::Migration[8.1]
  def up
    create_table :saved_account_filters do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :criteria, null: false, default: {}
      t.string :context

      t.timestamps
    end

    add_index :saved_account_filters, [ :user_id, :name ], unique: true
    add_index :saved_account_filters, [ :user_id, :created_at ]

    execute <<~SQL
      ALTER TABLE saved_account_filters ENABLE ROW LEVEL SECURITY;
      CREATE POLICY user_filters ON saved_account_filters
        USING (user_id = current_setting('app.current_user_id', true)::bigint);
    SQL
  end

  def down
    execute <<~SQL
      DROP POLICY IF EXISTS user_filters ON saved_account_filters;
      ALTER TABLE saved_account_filters DISABLE ROW LEVEL SECURITY;
    SQL

    drop_table :saved_account_filters
  end
end
