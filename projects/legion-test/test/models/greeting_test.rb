require "test_helper"

class GreetingTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Builds a Greeting with sensible defaults; keyword args override any field.
  def build_greeting(message: "Hello, world!")
    Greeting.new(message: message)
  end

  # ---------------------------------------------------------------------------
  # (1) Valid greeting — message within 100-character limit saves successfully
  # ---------------------------------------------------------------------------

  test "valid greeting with message of 100 characters or fewer saves successfully" do
    greeting = build_greeting(message: "A" * 100)

    assert greeting.valid?,
           "Expected a Greeting with a 100-char message to be valid, " \
           "but got errors: #{greeting.errors.full_messages.inspect}"
    assert greeting.save,
           "Expected Greeting#save to return true for a valid record"
  end

  # ---------------------------------------------------------------------------
  # (2) Presence validation — blank message is invalid
  # ---------------------------------------------------------------------------

  test "greeting with blank message is invalid" do
    greeting = build_greeting(message: "")

    assert_not greeting.valid?,
               "Expected a Greeting with a blank message to be invalid"
  end

  # ---------------------------------------------------------------------------
  # (3) Length validation — message longer than 100 characters is invalid
  # ---------------------------------------------------------------------------

  test "greeting with message longer than 100 characters is invalid" do
    greeting = build_greeting(message: "A" * 101)

    assert_not greeting.valid?,
               "Expected a Greeting with a 101-char message to be invalid"
  end

  # ---------------------------------------------------------------------------
  # (4) Error messages are present for each failing validation
  # ---------------------------------------------------------------------------

  test "blank message produces an error message on the message attribute" do
    greeting = build_greeting(message: "")
    greeting.valid?

    assert_includes greeting.errors[:message], "can't be blank",
                    "Expected errors[:message] to include \"can't be blank\" " \
                    "for a blank message, but got: #{greeting.errors[:message].inspect}"
  end

  test "message exceeding 100 characters produces a length error on the message attribute" do
    greeting = build_greeting(message: "A" * 101)
    greeting.valid?

    assert(
      greeting.errors[:message].any? { |msg| msg.match?(/too long|maximum|100/i) },
      "Expected errors[:message] to include a length-related error for a 101-char message, " \
      "but got: #{greeting.errors[:message].inspect}"
    )
  end
end
