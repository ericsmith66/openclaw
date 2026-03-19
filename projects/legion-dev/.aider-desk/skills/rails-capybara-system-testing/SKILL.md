---
name: Rails Capybara System Testing
description: End-to-end system testing using Capybara and Minitest.
---

## When to use
- Testing user flows (login, task creation, dashboard interaction)
- Verifying Turbo Stream and Turbo Frame updates
- Ensuring the 3-pane layout behaves correctly in the browser

## Required conventions
- Place tests in `test/system/`
- Inherit from `ActionDispatch::SystemTestCase`
- Use Capybara matchers (`assert_selector`, `assert_text`, `click_on`)
- **Hotwire**: Use `assert_turbo_stream` or check for content within `turbo_frame_tag` IDs.

## Examples
```ruby
# test/system/agents_test.rb
require "application_system_test_case"

class AgentsTest < ActionDispatch::SystemTestCase
  test "visiting the dashboard" do
    visit agents_path
    assert_selector "h1", text: "Agents"
    
    within "turbo-frame#agent_list" do
      click_on "Junie"
    end

    assert_selector "turbo-frame#task_detail", text: "Junie Status"
  end
end
```

## Do / Don’t
**Do**:
- Use `driven_by :selenium, using: :headless_chrome` (or project default)
- Use `within` blocks to scope assertions to specific Turbo Frames
- Reset VCR cassettes or use `VCR.use_cassette` if system tests trigger API calls

**Don’t**:
- Use `sleep` to wait for elements; Capybara handles waiting automatically
- Test low-level logic that should be in a unit test
