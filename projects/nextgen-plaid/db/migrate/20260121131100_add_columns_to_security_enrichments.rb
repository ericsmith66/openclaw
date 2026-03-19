class AddColumnsToSecurityEnrichments < ActiveRecord::Migration[8.1]
  def change
    change_table :security_enrichments, bulk: true do |t|
      t.decimal :price, precision: 18, scale: 6
      t.bigint :market_cap

      t.string :sector
      t.string :industry
      t.string :company_name
      t.string :website
      t.text :description
      t.string :image_url

      t.decimal :change_percentage, precision: 10, scale: 4
      t.decimal :dividend_yield, precision: 10, scale: 6
      t.decimal :pe_ratio, precision: 12, scale: 4
      t.decimal :price_to_book, precision: 12, scale: 4
      t.decimal :net_profit_margin, precision: 10, scale: 6
      t.decimal :dividend_per_share, precision: 10, scale: 4
      t.decimal :free_cash_flow_yield, precision: 10, scale: 6

      t.decimal :roe, precision: 10, scale: 6
      t.decimal :roa, precision: 10, scale: 6
      t.decimal :beta, precision: 10, scale: 6
      t.decimal :roic, precision: 10, scale: 6

      t.decimal :current_ratio, precision: 10, scale: 4
      t.decimal :debt_to_equity, precision: 10, scale: 4
    end
  end
end
