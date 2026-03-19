# frozen_string_literal: true

require "test_helper"

class ChannelTest < Minitest::Test
  # Convenience alias
  Channel = AgentDesk::MessageBus::Channel

  def test_exact_match
    assert Channel.match?("agent.qa.response.chunk", "agent.qa.response.chunk")
  end

  def test_no_match_different_channel
    refute Channel.match?("agent.qa.response.chunk", "agent.qa.tool.called")
  end

  def test_no_match_partial_prefix_without_wildcard
    refute Channel.match?("agent.qa", "agent.qa.response.chunk")
  end

  def test_bare_wildcard_matches_any_channel
    assert Channel.match?("*", "agent.qa.response.chunk")
    assert Channel.match?("*", "anything")
    assert Channel.match?("*", "a.b.c.d.e")
  end

  def test_trailing_wildcard_matches_direct_child
    assert Channel.match?("agent.*", "agent.qa")
  end

  def test_trailing_wildcard_matches_deep_child
    assert Channel.match?("agent.*", "agent.qa.response.chunk")
  end

  def test_trailing_wildcard_does_not_match_sibling_prefix
    # "agent.*" should NOT match "agentic.stuff" (different prefix)
    refute Channel.match?("agent.*", "agentic.stuff")
  end

  def test_trailing_wildcard_does_not_match_parent
    # "agent.qa.*" should not match "agent.qa" itself
    refute Channel.match?("agent.qa.*", "agent.qa")
  end

  def test_multi_segment_wildcard_matches_deep_child
    assert Channel.match?("agent.qa.*", "agent.qa.response.chunk")
  end

  def test_multi_segment_wildcard_does_not_match_different_branch
    refute Channel.match?("agent.qa.*", "agent.other.response.chunk")
  end

  def test_exact_match_beats_wildcard_check
    # Ensure exact pattern with a dot-star suffix still works as wildcard
    assert Channel.match?("agent.*", "agent.started")
  end

  def test_empty_channel_does_not_match_nonempty_exact_pattern
    refute Channel.match?("agent.qa", "")
  end

  def test_channel_with_no_dots_matches_exact
    assert Channel.match?("started", "started")
  end

  def test_channel_with_no_dots_does_not_match_wildcard_prefix
    # "agent.*" has "agent" prefix; "started" doesn't start with "agent."
    refute Channel.match?("agent.*", "started")
  end

  def test_trailing_dot_channel_matches_wildcard_by_definition
    # "agent." starts with "agent." — documented degenerate case.
    # Publishers should avoid trailing dots, but the matcher is consistent.
    assert Channel.match?("agent.*", "agent.")
  end
end
