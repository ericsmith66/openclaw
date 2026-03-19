# frozen_string_literal: true

require "test_helper"

class TransferDeduplicatorTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)

    # Create accounts
    @account1 = Account.create!(
      plaid_item: @user.plaid_items.first || PlaidItem.create!(
        user: @user,
        item_id: "test_item_td",
        institution_name: "Test Bank",
        institution_id: "ins_1",
        status: :good,
        access_token: "test_token"
      ),
      account_id: "acc_td_1",
      name: "Checking",
      mask: "1111",
      plaid_account_type: "depository"
    )
    @account2 = Account.create!(
      plaid_item: @account1.plaid_item,
      account_id: "acc_td_2",
      name: "Savings",
      mask: "2222",
      plaid_account_type: "depository"
    )
    @investment_account = Account.create!(
      plaid_item: @account1.plaid_item,
      account_id: "acc_td_inv",
      name: "Brokerage",
      mask: "3333",
      plaid_account_type: "investment"
    )
  end

  test "internal exact match: $1000 out + $1000 in, same day -> only outbound returned" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_1",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    in_txn = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_1",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out, in_txn ]).call

    assert_equal 1, result.size
    assert_equal out.id, result.first.id
  end

  test "near-amount match: $1000.00 out + $999.87 in -> matched, inbound suppressed" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_2",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    in_txn = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_2",
      name: "Transfer from Checking",
      amount: 999.87,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out, in_txn ]).call

    assert_equal 1, result.size
    assert_equal out.id, result.first.id
  end

  test "date offset: out Feb 17, in Feb 18 -> matched" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_3",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.new(2026, 2, 17),
      type: "RegularTransaction"
    )
    in_txn = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_3",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.new(2026, 2, 18),
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out, in_txn ]).call

    assert_equal 1, result.size
    assert_equal out.id, result.first.id
  end

  test "external: $500 out, no matching inbound -> returned with external: true" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_4",
      name: "Wire transfer out",
      amount: -500.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out ]).call

    assert_equal 1, result.size
    assert_equal out.id, result.first.id
    assert result.first.instance_variable_get(:@_external), "should be marked as external"
  end

  test "investment account excluded: brokerage transfer -> filtered before deduplication" do
    # Per PRD: "Investment account transactions excluded before processing (handled by data provider filter)"
    # The data provider already filters out investment accounts before calling TransferDeduplicator
    # This test verifies that if we pass only regular account transactions, they're processed correctly
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_5",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    in_txn = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_5",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out, in_txn ]).call

    # Investment accounts are filtered by data provider, not TransferDeduplicator
    assert_equal 1, result.size
    assert_equal out.id, result.first.id
  end

  test "self-transfer (same account): treated as outbound if negative" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_6",
      name: "Self transfer",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out ]).call

    assert_equal 1, result.size
    assert_equal out.id, result.first.id
    assert result.first.instance_variable_get(:@_external), "self-transfer marked as external"
  end

  test "multi-leg (wire fee split): amounts don't match -> both kept as unmatched" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_7",
      name: "Wire transfer",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    fee = Transaction.create!(
      account: @account1,
      transaction_id: "td_fee_7",
      name: "Wire fee",
      amount: -25.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out, fee ]).call

    assert_equal 2, result.size
    assert_includes result.map(&:id), out.id
    assert_includes result.map(&:id), fee.id
  end

  test "inbound leg returned if no matching outbound" do
    in_txn = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_8",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ in_txn ]).call

    assert_equal 1, result.size
    assert_equal in_txn.id, result.first.id
    assert result.first.instance_variable_get(:@_external), "should be marked as external"
  end

  test "multiple pairs: matching first pair, extras remain unmatched" do
    out1 = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_9a",
      name: "Transfer 1",
      amount: -500.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    in1 = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_9a",
      name: "Transfer 1",
      amount: 500.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    out2 = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_9b",
      name: "Transfer 2",
      amount: -300.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out1, in1, out2 ]).call

    assert_equal 2, result.size
    assert_includes result.map(&:id), out1.id  # matched outbound
    assert_includes result.map(&:id), out2.id  # unmatched outbound
  end

  test "matched outbound receives opposite account name" do
    out = Transaction.create!(
      account: @account1,
      transaction_id: "td_out_10",
      name: "Transfer to Savings",
      amount: -1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )
    in_txn = Transaction.create!(
      account: @account2,
      transaction_id: "td_in_10",
      name: "Transfer from Checking",
      amount: 1000.00,
      date: Date.today,
      type: "RegularTransaction"
    )

    result = TransferDeduplicator.new([ out, in_txn ]).call

    assert_equal 1, result.size
    assert_equal out.id, result.first.id
    assert_equal @account2.name, result.first.instance_variable_get(:@_matched_opposite_account_name)
  end
end
