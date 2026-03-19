require "test_helper"

require Rails.root.join("lib", "agents", "sdlc_sap_prompt_builder")

class SdlcSapPromptBuilderTest < ActiveSupport::TestCase
  test "builds default template using input and rag_content" do
    prompt = Agents::SdlcSapPromptBuilder.build(input: "hello", rag_content: "ctx")
    assert_includes prompt, "hello"
    assert_includes prompt, "[RAG]"
    assert_includes prompt, "ctx"
  end

  test "builds prompt from override ERB template with locals" do
    dir = Rails.root.join("tmp", "test_templates")
    FileUtils.mkdir_p(dir)
    path = dir.join("sap_override.md.erb")
    File.write(path, "INPUT=<%= input %>\nRAG=<%= rag_content %>\n")

    prompt = Agents::SdlcSapPromptBuilder.build(input: "abc", rag_content: "xyz", prompt_path: path.to_s)
    assert_equal "INPUT=abc\nRAG=xyz\n", prompt
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
