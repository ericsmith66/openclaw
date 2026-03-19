require "test_helper"

class AiWorkflowRunTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
    @run = AiWorkflowRun.new(user: @user, status: "draft", metadata: { model: "gpt-4" })
  end

  test "should be valid" do
    assert @run.valid?
  end

  test "should require a user" do
    @run.user = nil
    assert_not @run.valid?
  end

  test "should require a status" do
    @run.status = nil
    assert_not @run.valid?
  end

  test "should require metadata" do
    @run.metadata = nil
    assert_not @run.valid?
  end

  test "default status should be draft" do
    new_run = AiWorkflowRun.create(user: @user, metadata: {})
    assert_equal "draft", new_run.status
  end

  test "scopes should filter by status" do
    AiWorkflowRun.delete_all
    AiWorkflowRun.create!(user: @user, status: "draft", metadata: { foo: "bar" })
    AiWorkflowRun.create!(user: @user, status: "pending", metadata: { foo: "bar" })
    AiWorkflowRun.create!(user: @user, status: "approved", metadata: { foo: "bar" })
    AiWorkflowRun.create!(user: @user, status: "failed", metadata: { foo: "bar" })

    assert_equal 1, AiWorkflowRun.draft.count
    assert_equal 1, AiWorkflowRun.pending.count
    assert_equal 1, AiWorkflowRun.approved.count
    assert_equal 1, AiWorkflowRun.failed.count
  end

  test "for_user scope should filter by user" do
    AiWorkflowRun.delete_all
    other_user = users(:two)
    AiWorkflowRun.create!(user: @user, status: "draft", metadata: { foo: "bar" })
    AiWorkflowRun.create!(user: other_user, status: "draft", metadata: { foo: "bar" })

    assert_equal 1, AiWorkflowRun.for_user(@user).count
    assert_equal 1, AiWorkflowRun.for_user(other_user).count
  end

  test "should transition from draft to pending" do
    assert @run.transition_to("pending")
    assert_equal "pending", @run.status
  end

  test "should not transition from draft to approved" do
    assert_not @run.transition_to("approved")
    assert_equal "draft", @run.status
  end

  test "should transition from pending to approved" do
    @run.status = "pending"
    assert @run.transition_to("approved")
    assert_equal "approved", @run.status
  end

  test "should log transitions in metadata" do
    @run.transition_to("pending", { note: "ready for review" })
    transition = @run.metadata["transitions"].last
    assert_equal "draft", transition["from"]
    assert_equal "pending", transition["to"]
    assert_equal "ready for review", transition["details"]["note"]
  end

  test "should store and retrieve model parameters" do
    params = { "temp" => 0.7, "top_p" => 0.9 }
    @run.model_parameters = params
    @run.save!
    assert_equal params, @run.reload.model_parameters
  end

  test "approve! should set approver_id and transition to approved" do
    approver = users(:one)
    @run.status = "pending"
    @run.approve!(approver, { note: "looks good" })

    assert_equal "approved", @run.status
    audit_entry = @run.metadata["audit_log"].last
    assert_equal "approved", audit_entry["to"]
    assert_equal approver.id, audit_entry["details"]["approver_id"]
    assert_equal "looks good", audit_entry["details"]["note"]
  end

  test "should maintain audit log for all transitions" do
    @run.submit_for_approval!
    @run.approve!(users(:one))

    assert_equal 2, @run.metadata["audit_log"].length
    assert_equal "draft", @run.metadata["audit_log"][0]["from"]
    assert_equal "pending", @run.metadata["audit_log"][0]["to"]
    assert_equal "pending", @run.metadata["audit_log"][1]["from"]
    assert_equal "approved", @run.metadata["audit_log"][1]["to"]
  end
end
