# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"
require_relative "support/vcr_setup"
require_relative "support/e2e_helper"
require "mocha/minitest"
require "database_cleaner/active_record"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # E2E tests override this with self.use_transactional_tests = false
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.

    include FactoryBot::Syntax::Methods

    # Add more helper methods to be used by all tests here...
    # Note: E2EHelper is NOT included globally - it's included only in E2E test class

    # Register Liquid filters for all tests using Environment API
    setup do
      # Filters are registered in each test using Environment API
    end
  end
end
