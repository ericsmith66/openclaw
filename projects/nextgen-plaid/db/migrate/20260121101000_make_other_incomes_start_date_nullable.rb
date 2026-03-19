class MakeOtherIncomesStartDateNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :other_incomes, :start_date, true
  end
end
