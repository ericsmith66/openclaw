class AddMissingPlaidFieldsToHoldings < ActiveRecord::Migration[8.1]
  def change
    add_column :holdings, :close_price, :decimal, precision: 15, scale: 8
    add_column :holdings, :close_price_as_of, :date
    add_column :holdings, :ticker_symbol, :string
    add_column :holdings, :market_identifier_code, :string
    add_column :holdings, :iso_currency_code, :string
    add_column :holdings, :proxy_security_id, :string
    add_column :holdings, :is_cash_equivalent, :boolean, default: false, null: false

    add_index :holdings, :ticker_symbol
    add_index :holdings, :market_identifier_code
  end
end
