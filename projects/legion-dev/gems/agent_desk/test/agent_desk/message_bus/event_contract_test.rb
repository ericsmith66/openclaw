# frozen_string_literal: true

require "test_helper"

# Contract tests for AgentDesk::MessageBus::Event and Events module.
# Verifies the public struct fields and convenience constructors.
class EventContractTest < Minitest::Test
  def test_event_has_required_fields
    event = AgentDesk::MessageBus::Event.new(type: "test")
    assert_respond_to event, :type
    assert_respond_to event, :source
    assert_respond_to event, :agent_id
    assert_respond_to event, :task_id
    assert_respond_to event, :timestamp
    assert_respond_to event, :payload
  end

  def test_event_type_is_set
    event = AgentDesk::MessageBus::Event.new(type: "response.chunk")
    assert_equal "response.chunk", event.type
  end

  def test_events_module_provides_convenience_constructors
    %i[
      response_chunk
      response_complete
      tool_called
      tool_result
      agent_started
      agent_completed
      approval_request
      approval_response
    ].each do |method_name|
      assert_respond_to AgentDesk::MessageBus::Events, method_name,
                        "Expected Events to respond to .#{method_name}"
    end
  end
end
