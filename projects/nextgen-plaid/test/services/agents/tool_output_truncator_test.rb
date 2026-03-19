require "test_helper"

class ToolOutputTruncatorTest < ActiveSupport::TestCase
  test "truncate_result adds metadata and truncates by bytes" do
    big = "a" * 50
    res = Agents::ToolOutputTruncator.truncate_result({ status: 0, stdout: big, stderr: big }, max_bytes: 10)

    assert_equal 50, res[:stdout_bytes]
    assert_equal 50, res[:stderr_bytes]
    assert_equal true, res[:stdout_truncated]
    assert_equal true, res[:stderr_truncated]
    assert_operator res[:stdout].bytesize, :<=, 10 + "\n...[truncated]".bytesize
    assert_includes res[:stdout], "...[truncated]"
  end

  test "truncate_bytes scrubs invalid utf-8" do
    bad = "\xC3\x28".b # invalid utf-8 sequence
    truncated = Agents::ToolOutputTruncator.truncate_bytes(bad, 10)

    assert_equal true, truncated.encoding.name == "UTF-8"
    assert_equal true, truncated.valid_encoding?
  end
end
