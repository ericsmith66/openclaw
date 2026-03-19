require "test_helper"

# ---------------------------------------------------------------------------
# GreetingsController — functional / controller tests
#
# These tests are intentionally RED until the following are created:
#   • app/models/greeting.rb          (Greeting model with :message attribute)
#   • app/controllers/greetings_controller.rb
#   • resources :greetings (or equivalent) in config/routes.rb
#
# Expected controller behaviour being tested:
#   index  GET  /greetings        → 200 + collection
#   create POST /greetings valid  → 201 (JSON/API) or 302 redirect (HTML)
#   create POST /greetings invalid→ 422 or re-render with errors
# ---------------------------------------------------------------------------

class GreetingsControllerTest < ActionDispatch::IntegrationTest
  # -------------------------------------------------------------------------
  # Helpers
  # -------------------------------------------------------------------------

  # Builds attribute hashes for POST /greetings so every test is explicit
  # about what it sends rather than relying on hidden magic.
  def valid_params
    { greeting: { message: "Hello" } }
  end

  def invalid_params
    { greeting: { message: "" } }
  end

  # =========================================================================
  # (1) GET /greetings — index
  # =========================================================================

  test "GET /greetings returns HTTP 200" do
    get greetings_url

    assert_response :success,
                    "Expected GET /greetings to return 200 OK, " \
                    "got #{response.status} instead"
  end

  test "GET /greetings response body includes a greetings collection" do
    # The controller must expose @greetings (or equivalent) so the view has
    # something to iterate over.  We verify the rendered output is not an
    # error page by asserting the response is successful, and additionally
    # confirm the controller assigns @greetings as an enumerable.
    get greetings_url

    assert_response :success

    # ActionDispatch::IntegrationTest exposes controller instance variables
    # via `controller.instance_variable_get`.
    greetings = controller.instance_variable_get(:@greetings)
    assert_not_nil greetings,
                   "Expected @greetings to be assigned by GreetingsController#index, got nil"
    assert_respond_to greetings, :each,
                      "Expected @greetings to be a collection (respond to #each), " \
                      "got #{greetings.class} instead"
  end

  # =========================================================================
  # (2) POST /greetings — create with VALID params
  # =========================================================================

  test "POST /greetings with valid params returns 201 or a redirect" do
    post greetings_url, params: valid_params

    acceptable = [ 201, 302 ]
    assert_includes acceptable, response.status,
                    "Expected POST /greetings with valid params to return 201 or 302, " \
                    "got #{response.status} instead"
  end

  test "POST /greetings with valid params creates exactly one new Greeting record" do
    assert_difference "Greeting.count", 1,
                      "Expected POST /greetings with valid params to create 1 Greeting record" do
      post greetings_url, params: valid_params
    end
  end

  test "POST /greetings with valid params persists the submitted message" do
    post greetings_url, params: valid_params

    greeting = Greeting.last
    assert_equal "Hello", greeting.message,
                 "Expected persisted Greeting#message to equal 'Hello', " \
                 "got #{greeting.message.inspect} instead"
  end

  # =========================================================================
  # (3) POST /greetings — create with INVALID params (blank message)
  # =========================================================================

  test "POST /greetings with blank message returns 422 or re-renders with errors" do
    post greetings_url, params: invalid_params

    acceptable = [ 422, 200 ]   # 422 Unprocessable Entity (API / Turbo) or
                                 # 200 re-render (classic HTML form)
    assert_includes acceptable, response.status,
                    "Expected POST /greetings with invalid params to return 422 or 200, " \
                    "got #{response.status} instead"
  end

  test "POST /greetings with blank message does NOT create a Greeting record" do
    assert_no_difference "Greeting.count",
                         "Expected POST /greetings with invalid params to not create any records" do
      post greetings_url, params: invalid_params
    end
  end

  test "POST /greetings with blank message exposes validation errors via @greeting" do
    post greetings_url, params: invalid_params

    greeting = controller.instance_variable_get(:@greeting)
    assert_not_nil greeting,
                   "Expected @greeting to be assigned even on validation failure, got nil"
    assert greeting.errors.any?,
           "Expected @greeting to have validation errors on failed create, " \
           "but errors were empty"
  end
end
