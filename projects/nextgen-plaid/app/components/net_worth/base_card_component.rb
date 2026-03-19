# frozen_string_literal: true

module NetWorth
  class BaseCardComponent < ViewComponent::Base
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::DateHelper
    include Chartkick::Helper

    private

    def safe_get(hash, key, default = nil)
      return default unless hash.respond_to?(:[])

      value = hash[key]
      value = hash[key.to_s] if value.nil? && key.respond_to?(:to_s)
      value = hash[key.to_sym] if value.nil? && key.respond_to?(:to_sym)
      value.nil? ? default : value
    end

    def safe_to_f(value, default = 0.0)
      Float(value)
    rescue ArgumentError, TypeError
      default
    end

    def presence(value)
      s = value.to_s
      s.strip.empty? ? nil : value
    end
  end
end
