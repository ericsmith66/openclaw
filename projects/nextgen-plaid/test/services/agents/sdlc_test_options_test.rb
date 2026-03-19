require "test_helper"

require Rails.root.join("lib", "agents", "sdlc_test_options")

class SdlcTestOptionsTest < ActiveSupport::TestCase
  test "parses defaults" do
    opts = Agents::SdlcTestOptions.parse([ "--dry-run" ])

    assert opts[:run_id].present?
    assert_equal "end_to_end", opts[:mode]
    assert_equal "backlog", opts[:stage]
    assert_equal "llama3.1:70b", opts[:model_sap]
    assert_equal "llama3.1:70b", opts[:model_coord]
    assert_equal "llama3.1:70b", opts[:model_planner]
    assert_equal "llama3.1:70b", opts[:model_cwa]
    assert_nil opts[:prompt_sap]
    assert_nil opts[:rag_sap]
    assert_equal "strict", opts[:sandbox_level]
    assert_equal true, opts[:dry_run]
  end

  test "parses sap prompt and rag flags" do
    opts = Agents::SdlcTestOptions.parse([ "--dry-run", "--prompt-sap=tmp/custom.md.erb", "--rag-sap=foundation,structure" ])
    assert_equal "tmp/custom.md.erb", opts[:prompt_sap]
    assert_equal "foundation,structure", opts[:rag_sap]
  end

  test "parses coordinator prompt and rag flags" do
    opts = Agents::SdlcTestOptions.parse([ "--dry-run", "--prompt-coord=tmp/coord.md.erb", "--rag-coord=foundation" ])
    assert_equal "tmp/coord.md.erb", opts[:prompt_coord]
    assert_equal "foundation", opts[:rag_coord]
  end

  test "parses planner prompt, rag, and model flags" do
    path = Rails.root.join("tmp", "planner_prompt_test.md")
    File.write(path, "# Planner override\n")

    opts = Agents::SdlcTestOptions.parse([
      "--dry-run",
      "--prompt-planner=#{path}",
      "--rag-planner=foundation,structure",
      "--model-planner=llama3.1:70b"
    ])
    assert_equal path.to_s, opts[:prompt_planner]
    assert_equal "foundation,structure", opts[:rag_planner]
    assert_equal "llama3.1:70b", opts[:model_planner]
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  test "parses mode" do
    opts = Agents::SdlcTestOptions.parse([ "--dry-run", "--mode=stage" ])
    assert_equal "stage", opts[:mode]
  end

  test "parses start agent" do
    opts = Agents::SdlcTestOptions.parse([ "--dry-run", "--start-agent=CWA" ])
    assert_equal "CWA", opts[:start_agent]
  end

  test "validates start agent" do
    assert_raises(ArgumentError) do
      Agents::SdlcTestOptions.parse([ "--dry-run", "--start-agent=Nope" ])
    end
  end

  test "parses prd path" do
    path = Rails.root.join("tmp", "test_prd.md")
    File.write(path, "# PRD\n")

    opts = Agents::SdlcTestOptions.parse([ "--dry-run", "--prd-path=#{path}" ])
    assert_equal path.to_s, opts[:prd_path]
  ensure
    FileUtils.rm_f(path) if defined?(path)
  end

  test "parses artifact id" do
    artifact = Artifact.create!(
      name: "PRD Source",
      artifact_type: "feature",
      phase: "backlog",
      owner_persona: "SAP",
      payload: { "content" => "# PRD\n\n## 1. Overview\n- Source\n" }
    )

    opts = Agents::SdlcTestOptions.parse([ "--dry-run", "--artifact-id=#{artifact.id}" ])
    assert_equal artifact.id, opts[:artifact_id]
  ensure
    artifact.destroy if artifact
  end

  test "requires input unless dry-run" do
    assert_raises(ArgumentError) do
      Agents::SdlcTestOptions.parse([])
    end
  end

  test "validates stage" do
    assert_raises(ArgumentError) do
      Agents::SdlcTestOptions.parse([ "--dry-run", "--stage=not_a_real_phase" ])
    end
  end

  test "validates model against allowlist" do
    assert_raises(ArgumentError) do
      Agents::SdlcTestOptions.parse([ "--dry-run", "--model-sap=totally-invalid-model" ])
    end
  end
end
