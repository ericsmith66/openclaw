---
name: Rails Minitest + VCR
description: Unit and integration testing using Minitest and recording HTTP interactions with VCR.
---

## When to use
- Testing services, models, and controllers
- Recording external API calls for fast, deterministic tests
- Ensuring regressions are caught in a Rails 7+ environment

## Required conventions
- Use `test/` directory. Do NOT use `spec/`.
- Inherit from `ActiveSupport::TestCase`, `ActionDispatch::IntegrationTest`, `ActionDispatch::SystemTestCase`, or `ViewComponent::TestCase`.
- Use `VCR.use_cassette` for any tests hitting external APIs (Claude, Grok, etc.).
- **System Tests**: Use Capybara matchers for UI-level assertions.

## Examples
```ruby
# test/services/agent_orchestrator_test.rb
require "test_helper"

class AgentOrchestratorTest < ActiveSupport::TestCase
  test "orchestrates an agent task" do
    VCR.use_cassette("claude_completion") do
      result = AgentOrchestrator.new.run(task: "Hello")
      assert_equal "World", result
    end
  end
end
```

## Do / Don’t
**Do**:
- Use descriptive test names
- Use `bin/rails test` to run the suite

**Don’t**:
- Use `describe`/`it` blocks or `spec/` directory conventions
- Commit real API keys in VCR cassettes (use filtering)
