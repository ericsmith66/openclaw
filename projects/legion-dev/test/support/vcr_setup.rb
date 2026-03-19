# frozen_string_literal: true

require "vcr"
require "webmock/minitest"

VCR.configure do |config|
  config.cassette_library_dir = File.join(Rails.root, "test", "vcr_cassettes")
  # config.hook_into :webmock # Disabled to avoid infinite recursion in tests
  config.allow_http_connections_when_no_cassette = false

  # Filter sensitive tokens from recorded cassettes
  config.filter_sensitive_data("<SMART_PROXY_TOKEN>") { ENV.fetch("SMART_PROXY_TOKEN", "changeme") }

  # Default cassette options
  # Note: body matching is excluded because Runner adds dynamic fields (e.g. stream: true)
  # and headers contain dynamic X-Correlation-ID
  # RECORD_VCR=1 forces re-recording of all cassettes
  config.default_cassette_options = {
    record: ENV["RECORD_VCR"] ? :all : :once,
    match_requests_on: %i[method uri]
  }
end
