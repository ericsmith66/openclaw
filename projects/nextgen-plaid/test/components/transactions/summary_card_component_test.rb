# frozen_string_literal: true

require "test_helper"

module Transactions
  class SummaryCardComponentTest < ViewComponent::TestCase
    setup do
      @transactions = [
        OpenStruct.new(amount: -50.0),
        OpenStruct.new(amount: -30.0),
        OpenStruct.new(amount: 100.0)
      ]
    end

    test "renders stat cards" do
      render_inline(SummaryCardComponent.new(transactions: @transactions))
      assert_selector ".stat-value", text: "3" # total count
      assert_selector ".stat-value", text: "$20.00" # net amount
      assert_selector ".stat-value", text: "$6.67" # average
      assert_selector ".stat-value", text: "$50.00" # largest expense
    end

    test "net amount positive styles" do
      transactions = [ OpenStruct.new(amount: 100.0) ]
      render_inline(SummaryCardComponent.new(transactions: transactions))
      assert_selector ".stat-value.text-success"
    end

    test "net amount negative styles" do
      transactions = [ OpenStruct.new(amount: -100.0) ]
      render_inline(SummaryCardComponent.new(transactions: transactions))
      assert_selector ".stat-value.text-error"
    end
  end
end
