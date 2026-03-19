require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  VALID_TOKEN = "test-health-token-abc123"

  setup do
    # Ensure a clean token env for every test
  end

  test "returns 200 with valid token" do
    ClimateControl.modify(HEALTH_TOKEN: VALID_TOKEN) do
      get "/health", params: { token: VALID_TOKEN }
      assert_response :ok
      assert_equal({ "status" => "ok" }, JSON.parse(response.body))
    end
  end

  test "returns 401 with wrong token" do
    ClimateControl.modify(HEALTH_TOKEN: VALID_TOKEN) do
      get "/health", params: { token: "wrong-token" }
      assert_response :unauthorized
      assert_equal "error", JSON.parse(response.body)["status"]
    end
  end

  test "returns 401 with blank token" do
    ClimateControl.modify(HEALTH_TOKEN: VALID_TOKEN) do
      get "/health", params: { token: "" }
      assert_response :unauthorized
    end
  end

  test "returns 401 with missing token" do
    ClimateControl.modify(HEALTH_TOKEN: VALID_TOKEN) do
      get "/health"
      assert_response :unauthorized
    end
  end

  test "returns 503 when HEALTH_TOKEN is not configured" do
    ClimateControl.modify(HEALTH_TOKEN: nil) do
      get "/health", params: { token: VALID_TOKEN }
      assert_response :service_unavailable
      assert_equal "error", JSON.parse(response.body)["status"]
    end
  end

  test "returns 503 when database is unavailable" do
    ClimateControl.modify(HEALTH_TOKEN: VALID_TOKEN) do
      ActiveRecord::Base.stub(:connection, -> { raise ActiveRecord::StatementInvalid, "DB down" }) do
        get "/health", params: { token: VALID_TOKEN }
        assert_response :service_unavailable
      end
    end
  end
end
