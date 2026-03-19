# frozen_string_literal: true

require "test_helper"

class ModelManagerContractTest < Minitest::Test
  def test_responds_to_chat
    manager = AgentDesk::Models::ModelManager.new(
      provider: :smart_proxy,
      api_key: "test"
    )
    assert_respond_to manager, :chat
  end

  def test_provider_attribute_readable
    manager = AgentDesk::Models::ModelManager.new(
      provider: :smart_proxy,
      api_key: "test"
    )
    assert_equal :smart_proxy, manager.provider
  end

  def test_base_url_attribute_readable
    manager = AgentDesk::Models::ModelManager.new(
      provider: :smart_proxy,
      api_key: "test"
    )
    assert_equal "http://localhost:4567", manager.base_url
  end

  def test_model_attribute_readable
    manager = AgentDesk::Models::ModelManager.new(
      provider: :smart_proxy,
      api_key: "test",
      model: "custom-model"
    )
    assert_equal "custom-model", manager.model
  end
end
