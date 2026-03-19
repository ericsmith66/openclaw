# frozen_string_literal: true

require "test_helper"
require "capybara/rails"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers

  driven_by :rack_test

  def setup
    super
    Warden.test_mode!
  end

  def teardown
    Capybara.reset_sessions!
    Warden.test_reset!
    super
  end
end
