require "test_helper"

class OtherIncomeTest < ActiveSupport::TestCase
  test "valid with required fields" do
    user = User.create!(email: "oi@example.com", password: "Password!123")
    oi = OtherIncome.new(
      user: user,
      name: "Consulting",
      amount: 1000.00,
      frequency: "monthly",
      start_date: Date.current
    )

    assert oi.valid?
  end

  test "invalid without required fields" do
    oi = OtherIncome.new(frequency: nil)
    assert_not oi.valid?
    assert_includes oi.errors.full_messages.join(" "), "User must exist"
    assert_includes oi.errors.full_messages.join(" "), "Name can't be blank"
    assert_includes oi.errors.full_messages.join(" "), "Amount can't be blank"
    assert_includes oi.errors.full_messages.join(" "), "Frequency can't be blank"
  end

  test "invalid when end_date is before start_date" do
    user = User.create!(email: "oi-dates@example.com", password: "Password!123")
    oi = OtherIncome.new(
      user: user,
      name: "Consulting",
      amount: 1000.00,
      frequency: "annual",
      start_date: Date.new(2026, 1, 10),
      end_date: Date.new(2026, 1, 9)
    )

    assert_not oi.valid?
    assert_includes oi.errors[:end_date], "must be on or after the start date"
  end
end
