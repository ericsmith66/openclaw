require "test_helper"

class ArtifactTest < ActiveSupport::TestCase
  def setup
    @artifact = Artifact.new(
      name: "Test Feature",
      artifact_type: "feature",
      owner_persona: "SAP",
      phase: "backlog"
    )
  end

  test "should be valid" do
    assert @artifact.valid?
  end

  test "name should be present" do
    @artifact.name = ""
    assert_not @artifact.valid?
  end

  test "artifact_type should be present" do
    @artifact.artifact_type = ""
    assert_not @artifact.valid?
  end

  test "owner_persona should be present" do
    @artifact.owner_persona = ""
    assert_not @artifact.valid?
  end

  test "phase should be in PHASES" do
    @artifact.phase = "invalid_phase"
    assert_not @artifact.valid?
  end

  test "should set default phase and payload on initialize" do
    a = Artifact.new
    assert_equal "backlog", a.phase
    assert_equal "SAP", a.owner_persona
    assert_equal({}, a.payload)
  end

  test "transition_to approve moves through phases" do
    @artifact.save!

    # backlog -> ready_for_analysis
    assert @artifact.transition_to("approve", "Human")
    assert_equal "ready_for_analysis", @artifact.phase
    assert_equal "SAP", @artifact.owner_persona

    # ready_for_analysis -> in_analysis
    assert @artifact.transition_to("approve", "Human")
    assert_equal "in_analysis", @artifact.phase
    assert_equal "Coordinator", @artifact.owner_persona

    # in_analysis -> ready_for_development_feedback
    assert @artifact.transition_to("approve", "Human")
    assert_equal "planning", @artifact.phase
    assert_equal "Coordinator", @artifact.owner_persona
  end

  test "transition_to reject moves back" do
    @artifact.phase = "in_analysis"
    @artifact.save!

    assert @artifact.transition_to("reject", "Human")
    assert_equal "ready_for_analysis", @artifact.phase
    assert_equal "SAP", @artifact.owner_persona
  end

  test "transition_to maintains audit trail" do
    @artifact.save!
    @artifact.transition_to("approve", "Human")

    audit = @artifact.payload["audit_trail"].last
    assert_equal "backlog", audit["from_phase"]
    assert_equal "ready_for_analysis", audit["to_phase"]
    assert_equal "approve", audit["action"]
    assert_equal "Human", audit["actor_persona"]
  end

  test "optimistic locking prevents concurrent updates" do
    @artifact.save!
    a1 = Artifact.find(@artifact.id)
    a2 = Artifact.find(@artifact.id)

    a1.update!(name: "Update 1")

    assert_raises(ActiveRecord::StaleObjectError) do
      a2.update!(name: "Update 2")
    end
  end
end
