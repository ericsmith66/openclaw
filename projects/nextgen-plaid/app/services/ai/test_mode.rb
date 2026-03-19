# frozen_string_literal: true

module Ai
  module TestMode
    THREAD_KEY = :ai_test_mode

    def self.enabled?
      !!Thread.current[THREAD_KEY]
    end

    def self.with(enabled: true)
      prior = Thread.current[THREAD_KEY]
      Thread.current[THREAD_KEY] = enabled
      yield
    ensure
      Thread.current[THREAD_KEY] = prior
    end
  end
end
