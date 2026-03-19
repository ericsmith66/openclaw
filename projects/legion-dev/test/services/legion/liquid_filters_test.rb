# frozen_string_literal: true

require "test_helper"

module Legion
  class LiquidFiltersTest < ActiveSupport::TestCase
    # Helper to call filter methods directly on the module
    def call_filter(method, *args)
      LiquidFilters.send(method, *args)
    end

    # ===========================================================================
    # truncate_tokens filter tests
    # ===========================================================================

    test "truncate_tokens truncates to approximate token count" do
      input = "one two three four five six seven eight nine ten"
      result = call_filter(:truncate_tokens, input, 5)

      assert_equal "one two three four five...", result
    end

    test "truncate_tokens returns original string if under token limit" do
      input = "one two three"
      result = call_filter(:truncate_tokens, input, 10)

      assert_equal input, result
    end

    test "truncate_tokens handles exact token count" do
      input = "one two three"
      result = call_filter(:truncate_tokens, input, 3)

      assert_equal input, result
    end

    test "truncate_tokens returns empty string for empty input" do
      result = call_filter(:truncate_tokens, "", 5)

      assert_empty result
    end

    test "truncate_tokens returns original when max_tokens is zero" do
      input = "some text"
      result = call_filter(:truncate_tokens, input, 0)

      assert_equal input, result
    end

    test "truncate_tokens returns original when max_tokens is negative" do
      input = "some text"
      result = call_filter(:truncate_tokens, input, -5)

      assert_equal input, result
    end

    test "truncate_tokens handles nil input" do
      result = call_filter(:truncate_tokens, nil, 5)

      assert_nil result
    end

    test "truncate_tokens handles nil max_tokens" do
      input = "some text"
      result = call_filter(:truncate_tokens, input, nil)

      assert_empty result
    end

    test "truncate_tokens preserves whitespace structure when truncating" do
      input = "one  two   four    five"
      result = call_filter(:truncate_tokens, input, 3)

      # split(/\s+/) normalizes whitespace, so we expect single spaces
      assert_equal "one two four...", result
    end

    # ===========================================================================
    # indent filter tests
    # ===========================================================================

    test "indent adds spaces to each line" do
      input = "line1\nline2\nline3"
      result = call_filter(:indent, input, 4)

      expected = "    line1\n    line2\n    line3"
      assert_equal expected, result
    end

    test "indent uses default 4 spaces when no argument provided" do
      input = "line1\nline2"
      result = call_filter(:indent, input)

      expected = "    line1\n    line2"
      assert_equal expected, result
    end

    test "indent handles different indentation levels" do
      input = "line1\nline2"
      result = call_filter(:indent, input, 2)

      expected = "  line1\n  line2"
      assert_equal expected, result
    end

    test "indent handles empty string" do
      result = call_filter(:indent, "", 4)

      assert_empty result
    end

    test "indent handles nil input" do
      result = call_filter(:indent, nil, 4)

      assert_nil result
    end

    test "indent handles single line without newline" do
      input = "single line"
      result = call_filter(:indent, input, 4)

      assert_equal "    single line", result
    end

    test "indent handles multiline with trailing newline" do
      input = "line1\nline2\n"
      result = call_filter(:indent, input, 4)

      expected = "    line1\n    line2\n"
      assert_equal expected, result
    end

    test "indent handles empty lines in middle" do
      input = "line1\n\nline2"
      result = call_filter(:indent, input, 4)

      expected = "    line1\n\n    line2"
      assert_equal expected, result
    end

    # ===========================================================================
    # default filter tests
    # ===========================================================================

    test "default returns original value when not nil" do
      result = call_filter(:default, "some value", "default")

      assert_equal "some value", result
    end

    test "default returns original value when not empty string" do
      result = call_filter(:default, "some value", "default")

      assert_equal "some value", result
    end

    test "default returns default when input is nil" do
      result = call_filter(:default, nil, "fallback")

      assert_equal "fallback", result
    end

    test "default returns default when input is empty string" do
      result = call_filter(:default, "", "fallback")

      assert_equal "fallback", result
    end

    test "default returns default when input is whitespace string" do
      result = call_filter(:default, "   ", "fallback")

      # Whitespace is not empty string, so it should return the original
      assert_equal "   ", result
    end

    test "default returns default when input is nil with no default provided" do
      result = call_filter(:default, nil)

      assert_empty result
    end

    test "default returns numeric value when not nil" do
      result = call_filter(:default, 42, 0)

      assert_equal 42, result
    end

    test "default returns empty when input is empty string with no default" do
      result = call_filter(:default, "")

      assert_empty result
    end

    # ===========================================================================
    # Integration tests - using filters through Liquid::Environment
    # ===========================================================================

    test "truncate_tokens filter works in Liquid template" do
      template_source = "{{ text | truncate_tokens: 3 }}"
            env = Liquid::Environment.new
            env.register_filter(Legion::LiquidFilters)
      template = Liquid::Template.parse(template_source, environment: env)
      context = { "text" => "one two three four five" }

      output = template.render(context)

      assert_equal "one two three...", output
    end

    test "indent filter works in Liquid template" do
      template_source = "{{ text | indent: 2 }}"
            env = Liquid::Environment.new
            env.register_filter(Legion::LiquidFilters)
      template = Liquid::Template.parse(template_source, environment: env)
      context = { "text" => "line1\nline2" }

      output = template.render(context)

      assert_equal "  line1\n  line2", output
    end

    test "default filter works in Liquid template" do
      template_source = "{{ value | default: 'default_value' }}"
            env = Liquid::Environment.new
            env.register_filter(Legion::LiquidFilters)
      template = Liquid::Template.parse(template_source, environment: env)
      context = {}

      output = template.render(context)

      assert_equal "default_value", output
    end
  end
end
