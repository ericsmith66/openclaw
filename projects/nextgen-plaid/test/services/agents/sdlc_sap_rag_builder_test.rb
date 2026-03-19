require "test_helper"

require Rails.root.join("lib", "agents", "sdlc_sap_rag_builder")

class SdlcSapRagBuilderTest < ActiveSupport::TestCase
  test "returns empty tiers and content when tiers are blank" do
    rag = Agents::SdlcSapRagBuilder.build(nil)
    assert_equal [], rag[:tiers]
    assert_equal "", rag[:content]
    assert_equal false, rag[:truncated]
  end

  test "foundation tier reads static docs and includes file content" do
    static_dir = Rails.root.join("knowledge_base", "static_docs")
    FileUtils.mkdir_p(static_dir)
    file_path = static_dir.join("_rag_test.md")
    File.write(file_path, "hello-static")

    rag = Agents::SdlcSapRagBuilder.build("foundation")
    assert_equal [ "foundation" ], rag[:tiers]
    assert_includes rag[:content], "RAG TIER: foundation"
    assert_includes rag[:content], "hello-static"
  ensure
    File.delete(file_path) if file_path && File.exist?(file_path)
  end
end
