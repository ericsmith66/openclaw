require "test_helper"

class LiabilitiesGatingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.first || User.create!(email: "gating@example.com", password: "Password!123")
  end

  test "SyncAllItemsJob does not enqueue SyncLiabilitiesJob when item is not intended for liabilities" do
    item = PlaidItem.create!(
      user: @user,
      item_id: "it_no_liab",
      institution_name: "No Liab",
      access_token: "tok",
      status: "good",
      intended_products: "investments,transactions"
    )

    assert_enqueued_jobs 2 do
      SyncAllItemsJob.perform_now
    end

    assert_enqueued_with(job: SyncHoldingsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "DailyPlaidSyncJob does not enqueue SyncLiabilitiesJob when item is not intended for liabilities" do
    item = PlaidItem.create!(
      user: @user,
      item_id: "it_no_liab_daily",
      institution_name: "No Liab",
      access_token: "tok",
      status: "good",
      intended_products: "investments,transactions",
      last_webhook_at: nil
    )

    assert_enqueued_jobs 3 do
      DailyPlaidSyncJob.perform_now
    end

    assert_enqueued_with(job: SyncAccountsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncHoldingsJob, args: [ item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ item.id ])
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "ForcePlaidSyncJob skips liabilities when not intended" do
    item = PlaidItem.create!(
      user: @user,
      item_id: "it_no_liab_force",
      institution_name: "No Liab",
      access_token: "tok",
      status: "good",
      intended_products: "transactions"
    )

    assert_enqueued_jobs 0 do
      ForcePlaidSyncJob.perform_now(item.id, product: "liabilities")
    end
  end
end
