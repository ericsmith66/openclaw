# frozen_string_literal: true

require "test_helper"

class ConductorDecisionTest < ActiveSupport::TestCase
  setup do
    @workflow_execution = create(:workflow_execution)
  end

  test "factory creates valid record" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution)
    assert decision.valid?
  end

  test "associations to workflow_execution" do
    decision = create(:conductor_decision, workflow_execution: @workflow_execution)
    assert_equal @workflow_execution, decision.workflow_execution
    assert_includes @workflow_execution.conductor_decisions, decision
  end

  test "workflow_execution presence validation" do
    decision = build(:conductor_decision, workflow_execution: nil)
    assert_not decision.valid?
    assert_includes decision.errors[:workflow_execution], "must exist"
  end

  test "decision_type enum with all 4 values" do
    decision_types = %w[approve reject modify escalate]
    decision_types.each do |type|
      decision = build(:conductor_decision, workflow_execution: @workflow_execution, decision_type: type)
      assert decision.valid?, "Decision type #{type} should be valid"
    end
  end

  test "decision_type enum helpers work correctly" do
    decision = create(:conductor_decision, workflow_execution: @workflow_execution, decision_type: "approve")

    assert decision.approve?
    refute decision.reject?          # reject? is aliased on the model
    refute decision.modify_decision?
    refute decision.escalate_decision?

    decision.reject_decision!        # use enum key name for bang method
    assert decision.reject?          # reject? alias confirms the change
    refute decision.approve?
  end

  test "decision_type enum with validation" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, decision_type: "invalid_type")
    assert_not decision.valid?
    assert_includes decision.errors[:decision_type], "is not included in the list"
  end

  test "payload JSON validation - valid JSON string" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, payload: '{"key": "value"}')
    assert decision.valid?
  end

  test "payload JSON validation - invalid JSON string" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, payload: "{invalid json")
    assert_not decision.valid?
    assert_includes decision.errors[:payload], "must be valid JSON"
  end

  test "payload JSON validation - empty string" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, payload: "")
    assert decision.valid?
  end

  test "payload JSON validation - nil payload" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, payload: nil)
    assert decision.valid?
  end

  test "payload JSON validation - non-string payload (hash)" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, payload: { key: "value" })
    assert decision.valid?
  end

  test "duration_ms field is nullable" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, duration_ms: nil)
    assert decision.valid?
  end

  test "duration_ms field is settable" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, duration_ms: 1500)
    assert_equal 1500, decision.duration_ms
  end

  test "tokens_used field is nullable" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, tokens_used: nil)
    assert decision.valid?
  end

  test "tokens_used field is settable" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, tokens_used: 2500)
    assert_equal 2500, decision.tokens_used
  end

  test "estimated_cost field is nullable" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, estimated_cost: nil)
    assert decision.valid?
  end

  test "estimated_cost field is settable" do
    decision = build(:conductor_decision, workflow_execution: @workflow_execution, estimated_cost: 0.05)
    assert_equal 0.05, decision.estimated_cost
  end

  test "chronological ordering by created_at" do
    decision1 = create(:conductor_decision, workflow_execution: @workflow_execution, created_at: 1.hour.ago)
    decision2 = create(:conductor_decision, workflow_execution: @workflow_execution, created_at: 30.minutes.ago)
    decision3 = create(:conductor_decision, workflow_execution: @workflow_execution, created_at: Time.now)

    assert_equal [ decision1, decision2, decision3 ], @workflow_execution.conductor_decisions.chronological.to_a
  end

  test "count scope" do
    decision1 = create(:conductor_decision, workflow_execution: @workflow_execution)
    decision2 = create(:conductor_decision, workflow_execution: @workflow_execution)

    assert_equal 2, ConductorDecision.for_execution(@workflow_execution.id).count
    assert_includes ConductorDecision.for_execution(@workflow_execution.id), decision1
    assert_includes ConductorDecision.for_execution(@workflow_execution.id), decision2
  end
end
