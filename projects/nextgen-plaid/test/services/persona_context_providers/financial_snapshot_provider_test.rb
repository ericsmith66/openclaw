require "test_helper"

class PersonaContextProviders::FinancialSnapshotProviderTest < ActiveSupport::TestCase
  test "returns snapshot context for user and omits sensitive keys" do
    user = users(:one)
    snapshot = user.financial_snapshots.create!(
      snapshot_at: Time.current,
      schema_version: 1,
      status: :complete,
      data: {
        "core" => { "total_net_worth" => 1_000_000 },
        "account_numbers" => [ "1234" ],
        "institution_ids" => [ "ins_1" ],
        "raw_transaction_data" => { "x" => 1 }
      }
    )

    result = PersonaContextProviders::FinancialSnapshotProvider.call(user)
    assert_includes result[:content], "FINANCIAL SNAPSHOT"
    assert_includes result[:content], snapshot.snapshot_at.to_date.to_s
    refute_includes result[:content], "account_numbers"
    refute_includes result[:content], "institution_ids"
    refute_includes result[:content], "raw_transaction_data"

    assert_equal snapshot.id, result[:metadata]["financial_snapshot_id"]
  end
end
