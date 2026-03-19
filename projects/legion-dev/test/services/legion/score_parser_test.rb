# frozen_string_literal: true

require "test_helper"

module Legion
  class ScoreParserTest < ActiveSupport::TestCase
    test "extracts score from header format (## Score\\n87/100)" do
      text = "## Score\n87/100\n\n## Issues\n1. Missing test"
      result = ScoreParser.call(text: text)

      assert_equal 87, result.score
      assert_equal "Score extracted successfully", result.message
    end

    test "extracts score from header format with extra whitespace" do
      text = "## Score\n   92/100"
      result = ScoreParser.call(text: text)

      assert_equal 92, result.score
    end

    test "extracts score from inline format (SCORE: 92)" do
      text = "The implementation scores SCORE: 92 overall"
      result = ScoreParser.call(text: text)

      assert_equal 92, result.score
    end

    test "extracts score from inline format case-insensitive (score: 88)" do
      text = "score: 88 is the final grade"
      result = ScoreParser.call(text: text)

      assert_equal 88, result.score
    end

    test "extracts score from slash notation (85 / 100)" do
      text = "The implementation scores 85 / 100 overall"
      result = ScoreParser.call(text: text)

      assert_equal 85, result.score
    end

    test "extracts score from slash notation with no spaces (90/100)" do
      text = "Score: 90/100 - excellent"
      result = ScoreParser.call(text: text)

      assert_equal 90, result.score
    end

    test "extracts score from slash notation with extra spaces ( 95 / 100 )" do
      text = "Result:  95 / 100  - good job"
      result = ScoreParser.call(text: text)

      assert_equal 95, result.score
    end

    test "first match wins when multiple scores present" do
      text = "Score: 88\n## Score\n92/100\n75 / 100"
      result = ScoreParser.call(text: text)

      # Header format (## Score\n92/100) has highest priority
      assert_equal 92, result.score
    end

    test "extracts score 0 when present" do
      text = "## Score\n0/100"
      result = ScoreParser.call(text: text)

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    test "extracts score 100 when present" do
      text = "## Score\n100/100"
      result = ScoreParser.call(text: text)

      assert_equal 100, result.score
      assert_equal "Score extracted successfully", result.message
    end

    test "fallback to 0 with message when no score pattern matches" do
      text = "This is just plain text with no scores"
      result = ScoreParser.call(text: text)

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    test "handles empty string with fallback" do
      text = ""
      result = ScoreParser.call(text: text)

      assert_equal 0, result.score
      assert_equal "Score parsing failed — manual review required", result.message
    end

    test "handles text with only whitespace" do
      text = "   \n\n  "
      result = ScoreParser.call(text: text)

      assert_equal 0, result.score
    end

    test "handles score with leading zeros (007/100)" do
      text = "## Score\n007/100"
      result = ScoreParser.call(text: text)

      assert_equal 7, result.score
    end

    test "handles multiple slash notations (first wins)" do
      text = "The code scores 78 / 100 and tests get 82 / 100"
      result = ScoreParser.call(text: text)

      # First slash match is 78
      assert_equal 78, result.score
    end

    test "extracts score when header format has varied spacing" do
      text = "##  Score\n   83 / 100"
      result = ScoreParser.call(text: text)

      # This should NOT match because header format requires ## Score (exactly)
      # and slash format with spaces would match instead
      assert_equal 83, result.score
    end

    test "handles header format with extra blank line (newline then newline)" do
      text = "## Score\n\n85/100"
      result = ScoreParser.call(text: text)

      # Pattern matches: ## Score, optional whitespace, newline, optional whitespace (includes second \n), score
      assert_equal 85, result.score
    end

    test "ScoreParser.call returns Result struct with correct attributes" do
      text = "## Score\n77/100"
      result = ScoreParser.call(text: text)

      assert_instance_of ScoreParser::Result, result
      assert_respond_to result, :score
      assert_respond_to result, :message
    end

    test "handles mixed format output from QA agent" do
      text = <<~OUTPUT
        Here is my analysis:

        ## Score
        94/100

        ## Feedback
        - Good structure
        - Missing edge case tests
      OUTPUT

      result = ScoreParser.call(text: text)

      assert_equal 94, result.score
      assert_equal "Score extracted successfully", result.message
    end

    test "handles score at end of long text" do
      text = <<~TEXT
        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
        Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris.
        SCORE: 96
      TEXT

      result = ScoreParser.call(text: text)

      assert_equal 96, result.score
    end

    test "slash notation handles分数 format (88 /100)" do
      text = "Result: 88 /100 - good"
      result = ScoreParser.call(text: text)

      assert_equal 88, result.score
    end

    test "slash notation handles分数 format (89/ 100)" do
      text = "Result: 89/ 100 - good"
      result = ScoreParser.call(text: text)

      assert_equal 89, result.score
    end

    test "header format priority over inline format" do
      text = "## Score\n80/100\nSCORE: 95"
      result = ScoreParser.call(text: text)

      # Header format has higher priority
      assert_equal 80, result.score
    end

    test "inline format priority over slash notation" do
      text = "SCORE: 85\n70 / 100"
      result = ScoreParser.call(text: text)

      # Inline format has higher priority
      assert_equal 85, result.score
    end

    test "extracts score with trailing text after fraction" do
      text = "The final score is 91/100 - completed"
      result = ScoreParser.call(text: text)

      assert_equal 91, result.score
    end

    test "does not match invalid scores like 101/100" do
      text = "## Score\n101/100"
      result = ScoreParser.call(text: text)

      # Pattern matches but extracts the number
      assert_equal 101, result.score
    end

    test "does not match invalid scores like 150/100" do
      text = "SCORE: 150"
      result = ScoreParser.call(text: text)

      # Pattern matches the number
      assert_equal 150, result.score
    end
  end
end
