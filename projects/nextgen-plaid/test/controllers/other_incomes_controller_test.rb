require "test_helper"

class OtherIncomesControllerTest < ActionDispatch::IntegrationTest
  test "redirects to sign in when unauthenticated" do
    get other_incomes_path
    assert_response :redirect
  end

  test "user can access their own other incomes" do
    user = User.create!(email: "owner-oi@example.com", password: "Password!123")
    sign_in user, scope: :user

    oi = OtherIncome.create!(
      user: user,
      name: "Consulting",
      amount: 1000.00,
      frequency: "annual",
      start_date: Date.current
    )

    get other_incomes_path
    assert_response :success

    get edit_other_income_path(oi)
    assert_response :success
  end

  test "user cannot access another user's other income" do
    user_a = User.create!(email: "a-oi@example.com", password: "Password!123")
    user_b = User.create!(email: "b-oi@example.com", password: "Password!123")

    oi_b = OtherIncome.create!(
      user: user_b,
      name: "B Income",
      amount: 10.00,
      frequency: "monthly",
      start_date: Date.current
    )

    sign_in user_a, scope: :user

    get edit_other_income_path(oi_b)
    assert_response :not_found
  end

  test "index can be sorted by amount desc" do
    user = User.create!(email: "sort-oi@example.com", password: "Password!123")
    sign_in user, scope: :user

    OtherIncome.create!(user: user, name: "A", amount: 5.00, frequency: "annual")
    OtherIncome.create!(user: user, name: "B", amount: 10.00, frequency: "annual")

    get other_incomes_path(sort: "amount_desc")
    assert_response :success
    assert_match(/10\.00/, @response.body)
  end
end
