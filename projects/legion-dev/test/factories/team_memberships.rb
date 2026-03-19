# frozen_string_literal: true

FactoryBot.define do
  factory :team_membership do
    association :agent_team
    position { 0 }
    config do
      {
        "id" => "ror-rails-legion",
        "name" => "Rails Lead (Legion)",
        "provider" => "deepseek",
        "model" => "deepseek-reasoner",
        "reasoningEffort" => "none",
        "maxIterations" => 200,
        "maxTokens" => nil,
        "temperature" => nil,
        "minTimeBetweenToolCalls" => 0,
        "enabledServers" => [],
        "includeContextFiles" => false,
        "includeRepoMap" => false,
        "usePowerTools" => true,
        "useAiderTools" => true,
        "useTodoTools" => true,
        "useMemoryTools" => true,
        "useSkillsTools" => true,
        "useSubagents" => true,
        "useTaskTools" => false,
        "toolApprovals" => { "power---bash" => "ask" },
        "toolSettings" => {},
        "customInstructions" => "ZERO THINKING OUT LOUD",
        "compactionStrategy" => "tiered",
        "contextWindow" => 128_000,
        "costBudget" => 0.0,
        "contextCompactingThreshold" => 0.7,
        "subagent" => {
          "enabled" => false,
          "systemPrompt" => "",
          "invocationMode" => "on_demand",
          "color" => "#3368a8",
          "description" => "",
          "contextMemory" => "off"
        }
      }
    end
  end
end
