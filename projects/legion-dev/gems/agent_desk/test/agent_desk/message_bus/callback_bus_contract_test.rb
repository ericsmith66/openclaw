# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::MessageBus::CallbackBus.
# These tests verify the public API surface as defined by the MessageBusInterface.
# External adapters (e.g., PostgresBus) must satisfy the same contract.
class CallbackBusContractTest < Minitest::Test
  def setup
    @bus = AgentDesk::MessageBus::CallbackBus.new
  end

  def test_responds_to_publish
    assert_respond_to @bus, :publish
  end

  def test_responds_to_subscribe
    assert_respond_to @bus, :subscribe
  end

  def test_responds_to_unsubscribe
    assert_respond_to @bus, :unsubscribe
  end

  def test_responds_to_clear
    assert_respond_to @bus, :clear
  end

  def test_includes_message_bus_interface
    assert_includes AgentDesk::MessageBus::CallbackBus.ancestors,
                    AgentDesk::MessageBus::MessageBusInterface
  end

  def test_publish_delivers_event_to_matching_subscriber
    received = []
    event    = AgentDesk::MessageBus::Event.new(type: "test")
    @bus.subscribe("test.*") { |ch, ev| received << ev }
    @bus.publish("test.channel", event)
    assert_equal [ event ], received
  end
end
