---
name: Rails ViewComponent
description: Modular UI components using the ViewComponent gem.
---

## When to use
- Building reusable UI pieces (buttons, cards, agent status panes)
- Moving logic out of templates and into Ruby classes
- Unit testing UI components in isolation

## Required conventions
- Place components in `app/components/`
- Use `test/components/` for unit tests inheriting from `ViewComponent::TestCase`
- Follow `agent-forge` patterns in `app/components/agents/` or `app/components/shared/`

## Examples
```ruby
# app/components/shared/button_component.rb
class Shared::ButtonComponent < ViewComponent::Base
  def initialize(label:, path:, type: :primary)
    @label = label
    @path = path
    @type = type
  end
end
```

```erb
<%# app/components/shared/button_component.html.erb %>
<%= link_to @label, @path, class: "btn btn-#{@type}" %>
```

## Do / Don’t
**Do**:
- Pass data through the constructor (`initialize`)
- Use Turbo Frames inside components if needed

**Don’t**:
- Access global state or `params` directly inside a component
- Overcomplicate components with too many responsibilities
