require "test_helper"

class AgentHub::CommandExecutorTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test_cmd_#{rand(1000)}@example.com", password: "password")
    @broadcasts = []
    @callback = proc { |agent_id, payload| @broadcasts << { agent_id: agent_id, payload: payload } }
    @executor = AgentHub::CommandExecutor.new(user: @user, broadcast_callback: @callback)
  end

  test "call with unknown command should broadcast recognition" do
    @executor.call({ command: "unknown", args: "some args" }, "agent_1")

    assert @broadcasts.any? { |b| b[:payload][:type] == "token" && b[:payload][:token].include?("Command recognized: unknown") }
  end

  test "call with approve should broadcast legacy warning and confirmation" do
    # Stubbing ApplicationController.render to avoid view dependencies in unit test
    ApplicationController.stub :render, "<div>Mock Bubble</div>" do
      @executor.call({ command: "approve", args: nil }, "agent_1")
    end

    assert @broadcasts.any? { |b| b[:payload][:type] == "token" && b[:payload][:token].include?("deprecated") }
    assert @broadcasts.any? { |b| b[:payload][:type] == "confirmation_bubble" && b[:payload][:html] == "<div>Mock Bubble</div>" }
  end
end
