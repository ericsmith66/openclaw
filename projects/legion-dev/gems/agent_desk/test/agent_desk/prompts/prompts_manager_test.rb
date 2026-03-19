# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class PromptsManagerTest < Minitest::Test
  def setup
    @project_dir = Dir.mktmpdir("agent_desk_test_project")
    @global_dir = Dir.mktmpdir("agent_desk_test_global")
    @bundled_dir = File.expand_path("../../../templates", __dir__)

    @manager = AgentDesk::Prompts::PromptsManager.new(
      templates_dir: @bundled_dir,
      global_prompts_dir: @global_dir
    )

    @all_enabled_profile = AgentDesk::Agent::Profile.new(
      name: "Full Agent",
      use_power_tools: true,
      use_aider_tools: true,
      use_todo_tools: true,
      use_memory_tools: true,
      use_skills_tools: true,
      use_subagents: true,
      use_task_tools: true
    )

    @minimal_profile = AgentDesk::Agent::Profile.new(
      name: "Minimal Agent",
      use_power_tools: false,
      use_aider_tools: false,
      use_todo_tools: false,
      use_memory_tools: false,
      use_skills_tools: false,
      use_subagents: false,
      use_task_tools: false
    )

    @partial_profile = AgentDesk::Agent::Profile.new(
      name: "Partial Agent",
      use_power_tools: true,
      use_aider_tools: false,
      use_todo_tools: false,
      use_memory_tools: true,
      use_skills_tools: false,
      use_subagents: false,
      use_task_tools: false
    )
  end

  def teardown
    FileUtils.rm_rf(@project_dir) if @project_dir && File.exist?(@project_dir)
    FileUtils.rm_rf(@global_dir) if @global_dir && File.exist?(@global_dir)
  end

  # --- AC1: Renders valid XML-structured system prompt ---

  def test_renders_valid_xml_prompt
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_instance_of String, result
    assert_includes result, "<AiderDeskSystemPrompt"
    assert_includes result, "</AiderDeskSystemPrompt>"
    assert_includes result, "<Agent"
    assert_includes result, "<Persona>"
    assert_includes result, "<CoreDirectives>"
    assert_includes result, "<ToolUsageGuidelines>"
    assert_includes result, "<ResponseStyle>"
    assert_includes result, "<SystemInformation>"
  end

  def test_agent_name_in_prompt
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "Full Agent"
  end

  # --- AC2: Conditional sections based on profile ---

  def test_power_tools_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<PowerTools"
  end

  def test_power_tools_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<PowerTools"
  end

  def test_todo_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<TodoManagement"
  end

  def test_todo_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<TodoManagement"
  end

  def test_memory_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<MemoryTools"
  end

  def test_memory_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<MemoryTools"
  end

  def test_skills_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<SkillsTools"
  end

  def test_skills_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<SkillsTools"
  end

  def test_subagents_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<SubagentsProtocol"
  end

  def test_subagents_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<SubagentsProtocol"
  end

  def test_aider_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<AiderTools"
  end

  def test_aider_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<AiderTools"
  end

  def test_task_tools_section_included_when_enabled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<TaskTools"
  end

  def test_task_tools_section_excluded_when_disabled
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    refute_includes result, "<TaskTools"
  end

  def test_partial_profile_includes_only_enabled_sections
    result = @manager.system_prompt(
      profile: @partial_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<PowerTools"
    assert_includes result, "<MemoryTools"
    refute_includes result, "<TodoManagement"
    refute_includes result, "<AiderTools"
    refute_includes result, "<SkillsTools"
    refute_includes result, "<SubagentsProtocol"
    refute_includes result, "<TaskTools"
  end

  # --- AC3: Rules content injected ---

  def test_rules_content_injected
    rules = '<File name="RULES.md"><![CDATA[Do not use eval]]></File>'
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir,
      rules_content: rules
    )

    assert_includes result, "<Rules>"
    assert_includes result, "Do not use eval"
    assert_includes result, "</Rules>"
  end

  def test_empty_rules_content_omits_section
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir,
      rules_content: ""
    )

    refute_includes result, "<Rules>"
  end

  # --- AC4: Custom instructions injected ---

  def test_custom_instructions_injected
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir,
      custom_instructions: "Always use Minitest over RSpec"
    )

    assert_includes result, "<CustomInstructions>"
    assert_includes result, "Always use Minitest over RSpec"
    assert_includes result, "</CustomInstructions>"
  end

  def test_empty_custom_instructions_omits_section
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir,
      custom_instructions: ""
    )

    refute_includes result, "<CustomInstructions>"
  end

  # --- AC5: Template override chain ---

  def test_template_override_chain_project_overrides_global
    # Create a project-level template override
    project_prompts_dir = File.join(@project_dir, ".aider-desk", "prompts")
    FileUtils.mkdir_p(project_prompts_dir)
    File.write(
      File.join(project_prompts_dir, "system-prompt.liquid"),
      "<ProjectOverride>{{ agent.name }}</ProjectOverride>"
    )

    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    # Clear cache so we don't pollute other tests
    @manager.clear_cache!

    assert_includes result, "<ProjectOverride>"
    assert_includes result, "Full Agent"
    refute_includes result, "<AiderDeskSystemPrompt"
  end

  def test_template_override_chain_global_overrides_bundled
    # Create a global-level template override
    File.write(
      File.join(@global_dir, "system-prompt.liquid"),
      "<GlobalOverride>{{ agent.name }}</GlobalOverride>"
    )

    # Use a fresh manager without project overrides
    manager = AgentDesk::Prompts::PromptsManager.new(
      templates_dir: @bundled_dir,
      global_prompts_dir: @global_dir
    )

    result = manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<GlobalOverride>"
    assert_includes result, "Full Agent"
    refute_includes result, "<AiderDeskSystemPrompt"
  end

  def test_template_override_chain_project_over_global_over_bundled
    # Set up both project and global overrides
    project_prompts_dir = File.join(@project_dir, ".aider-desk", "prompts")
    FileUtils.mkdir_p(project_prompts_dir)
    File.write(
      File.join(project_prompts_dir, "system-prompt.liquid"),
      "<ProjectWins>{{ agent.name }}</ProjectWins>"
    )
    File.write(
      File.join(@global_dir, "system-prompt.liquid"),
      "<GlobalLoses>{{ agent.name }}</GlobalLoses>"
    )

    manager = AgentDesk::Prompts::PromptsManager.new(
      templates_dir: @bundled_dir,
      global_prompts_dir: @global_dir
    )

    result = manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<ProjectWins>"
    refute_includes result, "<GlobalLoses>"
  end

  def test_bundled_template_used_when_no_overrides
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<AiderDeskSystemPrompt"
  end

  # --- AC6: Workflow sub-template rendered and embedded ---

  def test_workflow_subtemplate_rendered
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<Workflow>"
    assert_includes result, "</Workflow>"
    assert_includes result, "<Step"
  end

  def test_workflow_subtemplate_can_be_overridden
    project_prompts_dir = File.join(@project_dir, ".aider-desk", "prompts")
    FileUtils.mkdir_p(project_prompts_dir)
    File.write(
      File.join(project_prompts_dir, "workflow.liquid"),
      "<CustomWorkflow>Custom steps here</CustomWorkflow>"
    )

    manager = AgentDesk::Prompts::PromptsManager.new(
      templates_dir: @bundled_dir,
      global_prompts_dir: @global_dir
    )

    result = manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<CustomWorkflow>"
    assert_includes result, "Custom steps here"
  end

  # --- System information ---

  def test_system_information_included
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<SystemInformation>"
    assert_includes result, "<CurrentDate>"
    assert_includes result, "<OperatingSystem>"
    assert_includes result, "<ProjectWorkingDirectory>"
    assert_includes result, @project_dir
  end

  # --- Minimal profile (all tools disabled) ---

  def test_minimal_profile_produces_valid_prompt
    result = @manager.system_prompt(
      profile: @minimal_profile,
      project_dir: @project_dir
    )

    assert_includes result, "<AiderDeskSystemPrompt"
    assert_includes result, "</AiderDeskSystemPrompt>"
    assert_includes result, "<Persona>"
    assert_includes result, "<CoreDirectives>"
    assert_includes result, "<SystemInformation>"

    # No tool sections
    refute_includes result, "<PowerTools"
    refute_includes result, "<TodoManagement"
    refute_includes result, "<MemoryTools"
    refute_includes result, "<SkillsTools"
    refute_includes result, "<SubagentsProtocol"
    refute_includes result, "<AiderTools"
    refute_includes result, "<TaskTools"
  end

  # --- Error handling ---

  def test_missing_template_raises_error
    manager = AgentDesk::Prompts::PromptsManager.new(
      templates_dir: "/nonexistent/path",
      global_prompts_dir: "/nonexistent/global"
    )

    error = assert_raises(AgentDesk::TemplateNotFoundError) do
      manager.system_prompt(
        profile: @all_enabled_profile,
        project_dir: @project_dir
      )
    end

    assert_includes error.message, "Template"
    assert_includes error.message, "not found"
  end

  def test_liquid_syntax_error_raises_template_syntax_error
    project_prompts_dir = File.join(@project_dir, ".aider-desk", "prompts")
    FileUtils.mkdir_p(project_prompts_dir)
    File.write(
      File.join(project_prompts_dir, "system-prompt.liquid"),
      "{% if unclosed"
    )

    manager = AgentDesk::Prompts::PromptsManager.new(
      templates_dir: @bundled_dir,
      global_prompts_dir: @global_dir
    )

    assert_raises(AgentDesk::TemplateSyntaxError) do
      manager.system_prompt(
        profile: @all_enabled_profile,
        project_dir: @project_dir
      )
    end
  end

  # --- Performance ---

  def test_rendering_performance_under_50ms
    # Warm up the cache
    @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    10.times do
      @manager.system_prompt(
        profile: @all_enabled_profile,
        project_dir: @project_dir
      )
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    avg_ms = (elapsed / 10.0) * 1000

    assert avg_ms < 50, "Average rendering time #{avg_ms.round(2)}ms exceeds 50ms threshold"
  end

  # --- Template caching ---

  def test_clear_cache_allows_new_template_resolution
    # First render uses bundled template
    result1 = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )
    assert_includes result1, "<AiderDeskSystemPrompt"

    # Create a project override
    project_prompts_dir = File.join(@project_dir, ".aider-desk", "prompts")
    FileUtils.mkdir_p(project_prompts_dir)
    File.write(
      File.join(project_prompts_dir, "system-prompt.liquid"),
      "<AfterCacheClear>{{ agent.name }}</AfterCacheClear>"
    )

    # Without cache clear, old template is still cached
    result2 = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )
    assert_includes result2, "<AiderDeskSystemPrompt"

    # After cache clear, new template is picked up
    @manager.clear_cache!
    result3 = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )
    assert_includes result3, "<AfterCacheClear>"
  end

  # --- Constants in template ---

  def test_constants_available_in_template
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: @project_dir
    )

    # Verify tool group constants are rendered in the prompt
    assert_includes result, AgentDesk::POWER_TOOL_GROUP_NAME
    assert_includes result, AgentDesk::TODO_TOOL_GROUP_NAME
    assert_includes result, AgentDesk::MEMORY_TOOL_GROUP_NAME
  end

  # --- nil project_dir ---

  def test_nil_project_dir_uses_global_and_bundled
    result = @manager.system_prompt(
      profile: @all_enabled_profile,
      project_dir: nil
    )

    assert_instance_of String, result
    assert_includes result, "<AiderDeskSystemPrompt"
  end
end
