# frozen_string_literal: true

require "test_helper"

class WorkflowEventTest < ActiveSupport::TestCase
  setup do
    @workflow_run = create(:workflow_run)
  end

  test "factory creates valid record" do
    event = build(:workflow_event, workflow_run: @workflow_run)
    assert event.valid?
  end

  test "event_type validation" do
    event = build(:workflow_event, workflow_run: @workflow_run, event_type: nil)
    assert_not event.valid?
    assert_includes event.errors[:event_type], "can't be blank"
  end

  test "recorded_at validation" do
    event = build(:workflow_event, workflow_run: @workflow_run, recorded_at: nil)
    assert_not event.valid?
    assert_includes event.errors[:recorded_at], "can't be blank"
  end

  test "associations" do
    event = create(:workflow_event, workflow_run: @workflow_run)
    assert_equal @workflow_run, event.workflow_run
  end

  test "scopes" do
    event1 = create(:workflow_event, workflow_run: @workflow_run, event_type: "agent.started", recorded_at: 1.hour.ago)
    event2 = create(:workflow_event, workflow_run: @workflow_run, event_type: "agent.finished", recorded_at: Time.current)
    assert_equal [ event1 ], WorkflowEvent.by_type("agent.started").to_a
    assert_equal [ event1, event2 ], WorkflowEvent.chronological.to_a
  end
end
