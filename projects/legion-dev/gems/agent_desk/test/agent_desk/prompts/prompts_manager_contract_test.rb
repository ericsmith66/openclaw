# frozen_string_literal: true

require "test_helper"

class PromptsManagerContractTest < Minitest::Test
  def setup
    @manager = AgentDesk::Prompts::PromptsManager.new
    @profile = AgentDesk::Agent::Profile.new(name: "Contract Test Agent")
    @project_dir = Dir.mktmpdir("agent_desk_contract_test")
  end

  def teardown
    FileUtils.rm_rf(@project_dir) if @project_dir && File.exist?(@project_dir)
  end

  def test_system_prompt_returns_string
    result = @manager.system_prompt(
      profile: @profile,
      project_dir: @project_dir
    )

    assert_instance_of String, result
    refute_empty result
  end

  def test_template_override_chain
    # Bundled template produces AiderDeskSystemPrompt
    result = @manager.system_prompt(
      profile: @profile,
      project_dir: @project_dir
    )

    assert_includes result, "<AiderDeskSystemPrompt"

    # Project override takes precedence
    project_prompts_dir = File.join(@project_dir, ".aider-desk", "prompts")
    FileUtils.mkdir_p(project_prompts_dir)
    File.write(
      File.join(project_prompts_dir, "system-prompt.liquid"),
      "<ContractOverride>{{ agent.name }}</ContractOverride>"
    )

    manager = AgentDesk::Prompts::PromptsManager.new
    result2 = manager.system_prompt(
      profile: @profile,
      project_dir: @project_dir
    )

    assert_includes result2, "<ContractOverride>"
    assert_includes result2, "Contract Test Agent"
  end
end
