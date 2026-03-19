# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::Tools::ApprovalManager.
# These verify the public API shape that all downstream PRDs depend on.
class ApprovalManagerContractTest < Minitest::Test
  def test_responds_to_check_approval
    mgr = AgentDesk::Tools::ApprovalManager.new(tool_approvals: {})
    assert_respond_to mgr, :check_approval
  end

  def test_check_approval_returns_two_element_array
    mgr = AgentDesk::Tools::ApprovalManager.new(tool_approvals: {})
    result = mgr.check_approval("some---tool", text: "run it")
    assert_kind_of Array, result
    assert_equal 2, result.size
  end

  def test_always_state_returns_approved
    approvals = { "power---bash" => AgentDesk::ToolApprovalState::ALWAYS }
    mgr = AgentDesk::Tools::ApprovalManager.new(tool_approvals: approvals)
    approved, reason = mgr.check_approval("power---bash", text: "run bash")
    assert_equal true, approved
    assert_nil reason
  end

  def test_never_state_returns_rejected
    approvals = { "power---bash" => AgentDesk::ToolApprovalState::NEVER }
    mgr = AgentDesk::Tools::ApprovalManager.new(tool_approvals: approvals)
    approved, reason = mgr.check_approval("power---bash", text: "run bash")
    assert_equal false, approved
    refute_nil reason
  end

  def test_ask_state_calls_block
    block_called = false
    approvals = { "power---bash" => AgentDesk::ToolApprovalState::ASK }
    mgr = AgentDesk::Tools::ApprovalManager.new(tool_approvals: approvals) do |text, subject|
      block_called = true
      "y"
    end
    mgr.check_approval("power---bash", text: "run bash")
    assert block_called
  end

  def test_auto_approve_mode_approves_all
    mgr = AgentDesk::Tools::ApprovalManager.new(
      tool_approvals: { "x---y" => AgentDesk::ToolApprovalState::NEVER },
      auto_approve: true
    )
    approved, _reason = mgr.check_approval("x---y", text: "do it")
    assert_equal true, approved
  end
end
