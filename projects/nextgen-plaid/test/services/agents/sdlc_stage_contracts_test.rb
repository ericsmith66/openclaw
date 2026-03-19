require "test_helper"

class SdlcStageContractsTest < ActiveSupport::TestCase
  test "validate_intent_summary! accepts required keys" do
    obj = {
      "business_requirement" => "Do X",
      "user_interaction" => "User clicks Y",
      "change_impact" => "Touches A/B"
    }

    assert_equal obj, Agents::SdlcStageContracts.validate_intent_summary!(obj)
  end

  test "validate_intent_summary! rejects missing keys" do
    err = assert_raises(Agents::SdlcStageContracts::ContractError) do
      Agents::SdlcStageContracts.validate_intent_summary!({ "business_requirement" => "x" })
    end

    assert_equal "contract_failure_intent_summary", err.code
  end

  test "validate_plan_json! accepts tasks and test_command" do
    obj = { "tasks" => [ { "id" => "t1", "title" => "Do" } ], "test_command" => "bundle exec rails test" }
    assert_equal obj, Agents::SdlcStageContracts.validate_plan_json!(obj)
  end

  test "validate_plan_json! rejects missing test_command" do
    err = assert_raises(Agents::SdlcStageContracts::ContractError) do
      Agents::SdlcStageContracts.validate_plan_json!({ "tasks" => [ { "id" => "t1" } ] })
    end

    assert_equal "contract_failure_plan_json", err.code
  end
end
