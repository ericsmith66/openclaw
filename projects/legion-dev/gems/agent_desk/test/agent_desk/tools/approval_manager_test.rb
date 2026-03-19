# frozen_string_literal: true

require "test_helper"

class ApprovalManagerTest < Minitest::Test
  ALWAYS = AgentDesk::ToolApprovalState::ALWAYS
  ASK    = AgentDesk::ToolApprovalState::ASK
  NEVER  = AgentDesk::ToolApprovalState::NEVER

  def make_manager(approvals: {}, auto_approve: false, &ask_block)
    AgentDesk::Tools::ApprovalManager.new(
      tool_approvals: approvals,
      auto_approve: auto_approve,
      &ask_block
    )
  end

  # ── ALWAYS state ─────────────────────────────────────────────────────────────

  def test_always_state_returns_true_nil
    mgr = make_manager(approvals: { "power---bash" => ALWAYS })
    result = mgr.check_approval("power---bash", text: "run bash")
    assert_equal [ true, nil ], result
  end

  def test_unknown_tool_defaults_to_always
    mgr = make_manager(approvals: {})
    result = mgr.check_approval("unknown---tool", text: "something")
    assert_equal [ true, nil ], result
  end

  # ── NEVER state ──────────────────────────────────────────────────────────────

  def test_never_state_returns_false_with_reason
    mgr = make_manager(approvals: { "power---bash" => NEVER })
    approved, reason = mgr.check_approval("power---bash", text: "run bash")
    assert_equal false, approved
    assert_equal "Tool is disabled", reason
  end

  # ── ASK state (no block) ──────────────────────────────────────────────────────

  def test_ask_state_with_no_block_returns_false_nil
    mgr = make_manager(approvals: { "power---bash" => ASK })
    result = mgr.check_approval("power---bash", text: "run bash")
    assert_equal [ false, nil ], result
  end

  # ── ASK state (with block) ────────────────────────────────────────────────────

  def test_ask_state_yes_answer
    mgr = make_manager(approvals: { "power---bash" => ASK }) { |text, subject| "y" }
    assert_equal [ true, nil ], mgr.check_approval("power---bash", text: "run bash")
  end

  def test_ask_state_always_answer
    mgr = make_manager(approvals: { "power---bash" => ASK }) { |text, subject| "a" }
    assert_equal [ true, nil ], mgr.check_approval("power---bash", text: "run bash")
  end

  def test_ask_state_remember_for_run_answer
    mgr = make_manager(approvals: { "power---bash" => ASK }) { |text, subject| "r" }
    assert_equal [ true, nil ], mgr.check_approval("power---bash", text: "first call")
  end

  def test_ask_state_other_answer_returns_false_with_answer
    mgr = make_manager(approvals: { "power---bash" => ASK }) { |text, subject| "no" }
    approved, reason = mgr.check_approval("power---bash", text: "run bash")
    assert_equal false, approved
    assert_equal "no", reason
  end

  def test_ask_state_n_answer_returns_false
    mgr = make_manager(approvals: { "power---bash" => ASK }) { |text, subject| "n" }
    approved, _reason = mgr.check_approval("power---bash", text: "run bash")
    assert_equal false, approved
  end

  def test_ask_block_receives_text_and_subject
    received = {}
    mgr = make_manager(approvals: { "t---tool" => ASK }) do |text, subject|
      received[:text] = text
      received[:subject] = subject
      "y"
    end
    mgr.check_approval("t---tool", text: "do something", subject: "My Tool")
    assert_equal "do something", received[:text]
    assert_equal "My Tool", received[:subject]
  end

  def test_ask_block_subject_nil_by_default
    received_subject = :unset
    mgr = make_manager(approvals: { "t---tool" => ASK }) do |text, subject|
      received_subject = subject
      "y"
    end
    mgr.check_approval("t---tool", text: "do something")
    assert_nil received_subject
  end

  # ── always_for_run memory ─────────────────────────────────────────────────────

  def test_remember_for_run_skips_ask_on_subsequent_calls
    call_count = 0
    mgr = make_manager(approvals: { "power---bash" => ASK }) do |text, subject|
      call_count += 1
      "r"
    end
    mgr.check_approval("power---bash", text: "first")
    mgr.check_approval("power---bash", text: "second")
    mgr.check_approval("power---bash", text: "third")
    assert_equal 1, call_count, "Ask block should only be called once after 'r' answer"
  end

  def test_remember_for_run_returns_true_nil_on_subsequent_calls
    mgr = make_manager(approvals: { "power---bash" => ASK }) { |text, subject| "r" }
    mgr.check_approval("power---bash", text: "first")
    result = mgr.check_approval("power---bash", text: "second")
    assert_equal [ true, nil ], result
  end

  def test_remember_for_run_is_per_tool
    calls = Hash.new(0)
    mgr = make_manager(
      approvals: { "power---bash" => ASK, "power---grep" => ASK }
    ) do |text, subject|
      calls[text] += 1
      "r"
    end
    mgr.check_approval("power---bash", text: "bash")
    mgr.check_approval("power---grep", text: "grep")
    mgr.check_approval("power---bash", text: "bash")
    # bash should be called once (remembered), grep called once
    assert_equal 1, calls["bash"]
    assert_equal 1, calls["grep"]
  end

  # ── auto_approve mode ─────────────────────────────────────────────────────────

  def test_auto_approve_bypasses_never_state
    mgr = make_manager(approvals: { "power---bash" => NEVER }, auto_approve: true)
    assert_equal [ true, nil ], mgr.check_approval("power---bash", text: "run bash")
  end

  def test_auto_approve_bypasses_ask_state
    ask_called = false
    mgr = make_manager(approvals: { "power---bash" => ASK }, auto_approve: true) do |text, subject|
      ask_called = true
      "y"
    end
    result = mgr.check_approval("power---bash", text: "run bash")
    assert_equal [ true, nil ], result
    refute ask_called, "Ask block should not be called in auto_approve mode"
  end

  def test_auto_approve_returns_true_nil_for_all_tools
    mgr = make_manager(approvals: {}, auto_approve: true)
    assert_equal [ true, nil ], mgr.check_approval("any---tool", text: "do it")
  end
end
