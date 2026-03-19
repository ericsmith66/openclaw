class CreatePlaidApiResponses < ActiveRecord::Migration[8.0]
  def change
    create_table :plaid_api_responses do |t|
      t.references :plaid_api_call, null: false, foreign_key: true
      t.references :plaid_item, null: false, foreign_key: true

      t.string :product, null: false
      t.string :endpoint, null: false
      t.string :request_id

      t.jsonb :response_json, null: true
      t.jsonb :error_json, null: true

      t.datetime :called_at, null: false

      t.timestamps
    end

    add_index :plaid_api_responses, :called_at
    add_index :plaid_api_responses, :request_id
    add_index :plaid_api_responses, [ :plaid_item_id, :called_at ]
    add_index :plaid_api_responses, [ :product, :endpoint, :called_at ]
  end
end
