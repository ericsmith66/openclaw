---
name: Rails Turbo Hotwire
description: Turbo Frames and Streams for server-driven UI updates in agent-forge.
---

## When to use
- Replacing custom JS with server-driven interactivity
- Adding partial page updates for agent status panes
- Updating the 3-pane layout dynamically

## Required conventions
- Prefer `turbo_frame_tag` for scoped updates
- Use `turbo_stream` responses for reactive UI updates
- **Troubleshooting**: If a pane is blank, check `log/browser_debug.log` or run `bin/rails debug:tail`.
- **Constraint**: Ensure `annotate_rendered_view_with_filenames = false` in `development.rb` to avoid breaking Turbo Frames.

## Examples
```erb
<%# Dashboard view %>
<div class="flex">
  <%= turbo_frame_tag "agent_list", src: agents_path %>
  <%= turbo_frame_tag "task_detail" %>
  <%= turbo_frame_tag "logs" %>
</div>
```

```ruby
# Controller response
respond_to do |format|
  format.turbo_stream { render turbo_stream: turbo_stream.replace("task_detail", partial: "tasks/show", locals: { task: @task }) }
end
```

## Do / Don’t
**Do**:
- Use Turbo for incremental updates
- Keep components small and composable

**Don’t**:
- Nest Turbo Frames unnecessarily
- Forget to check the browser console for frame mismatch errors
