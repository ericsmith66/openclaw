require "test_helper"

class PlaidItemRetriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "user_retry@example.com", password: "Password123", roles: "parent")
    @other_user = User.create!(email: "other_retry@example.com", password: "Password123", roles: "parent")

    @failed_item = PlaidItem.create!(
      user: @user,
      item_id: "it_failed",
      institution_name: "Test Bank",
      access_token: "tok_failed",
      status: "failed",
      retry_count: 0,
      last_retry_at: nil
    )
  end

  test "user can retry a failed plaid item and jobs are enqueued" do
    login_as @user, scope: :user

    assert_enqueued_jobs 3 do
      post plaid_item_retry_path(@failed_item)
    end

    assert_redirected_to accounts_link_path
    assert_includes flash[:notice], "Retry enqueued"

    @failed_item.reload
    assert_equal 1, @failed_item.retry_count
    assert @failed_item.last_retry_at.present?
  end

  test "retry is blocked during cooldown" do
    @failed_item.update!(retry_count: 1, last_retry_at: 1.minute.ago)
    login_as @user, scope: :user

    assert_no_enqueued_jobs do
      post plaid_item_retry_path(@failed_item)
    end

    assert_redirected_to accounts_link_path
    assert_equal "Retry not available right now.", flash[:alert]
  end

  test "user cannot retry someone else's plaid item" do
    other_item = PlaidItem.create!(
      user: @other_user,
      item_id: "it_other",
      institution_name: "Other Bank",
      access_token: "tok_other",
      status: "failed",
      retry_count: 0
    )

    login_as @user, scope: :user

    assert_no_enqueued_jobs do
      post plaid_item_retry_path(other_item)
    end

    assert_redirected_to accounts_link_path
    assert_equal "Account connection not found.", flash[:alert]
  end

  test "retry only enqueues jobs for intended_products when set to investments,transactions" do
    @failed_item.update!(intended_products: "investments,transactions")
    login_as @user, scope: :user

    assert_enqueued_jobs 2 do
      post plaid_item_retry_path(@failed_item)
    end

    # Verify only investments and transactions jobs were enqueued
    assert_enqueued_with(job: SyncHoldingsJob, args: [ @failed_item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ @failed_item.id ])

    # Verify liabilities job was NOT enqueued
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "retry only enqueues jobs for intended_products when set to transactions only" do
    @failed_item.update!(intended_products: "transactions")
    login_as @user, scope: :user

    assert_enqueued_jobs 1 do
      post plaid_item_retry_path(@failed_item)
    end

    # Verify only transactions job was enqueued
    assert_enqueued_with(job: SyncTransactionsJob, args: [ @failed_item.id ])

    # Verify other jobs were NOT enqueued
    assert_no_enqueued_jobs(only: SyncHoldingsJob)
    assert_no_enqueued_jobs(only: SyncLiabilitiesJob)
  end

  test "retry enqueues all jobs when intended_products is NULL (legacy item)" do
    @failed_item.update!(intended_products: nil)
    login_as @user, scope: :user

    assert_enqueued_jobs 3 do
      post plaid_item_retry_path(@failed_item)
    end

    # Verify all jobs were enqueued (legacy behavior)
    assert_enqueued_with(job: SyncHoldingsJob, args: [ @failed_item.id ])
    assert_enqueued_with(job: SyncTransactionsJob, args: [ @failed_item.id ])
    assert_enqueued_with(job: SyncLiabilitiesJob, args: [ @failed_item.id ])
  end
end
