# Workspace::LayoutComponent — Reusable Chat UI

A configurable, AiderDesk-inspired chat workspace component for Agent-Forge. Built with ViewComponent, Stimulus, Tailwind CSS, and DaisyUI.

## Architecture

```
Workspace::LayoutComponent          ← Main orchestrator (configurable)
├── Left Drawer (overlay)           ← Slide-out navigation (optional)
├── Right Drawer (overlay)          ← Slide-out details panel (optional)
├── Left Panel (persistent)         ← Collapsible sidebar (optional)
├── Center Chat Pane                ← Always present (uses Chat::BubbleComponent / Chat::InputComponent)
├── Right Panel (persistent)        ← Collapsible sidebar (optional)
└── Bottom Toolbar                  ← Status bar (optional)
```

## Configuration API

### Parameters

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `task` | Object/nil | `nil` | Current task object. If nil, shows empty state. |
| `workspace_id` | String | `"default"` | Unique ID. Allows multiple workspaces per page. Persists panel state to localStorage. |
| `left_panel` | Hash/false | `false` | Left sidebar config or `false` to hide. |
| `right_panel` | Hash/false | `false` | Right sidebar config or `false` to hide. |
| `left_drawer` | Hash/false | `false` | Left overlay drawer config or `false` to hide. |
| `right_drawer` | Hash/false | `false` | Right overlay drawer config or `false` to hide. |
| `toolbar` | Boolean | `false` | Show bottom toolbar strip. |
| `chat` | Hash | `{}` | Chat pane config. |

### Panel Config Hash

```ruby
{
  width: "280px",       # Initial width (CSS value)
  collapsible: true,    # Show collapse/expand toggle
  title: "Artifacts"    # Header text
}
```

### Drawer Config Hash

```ruby
{
  title: "Navigation"   # Header text in drawer
}
```

### Chat Config Hash

```ruby
{
  show_header: true,                           # Show chat header bar
  show_slash_commands: true,                   # Enable slash command menu
  placeholder: "Type a message or /command..." # Input placeholder text
}
```

### Content Slots

| Slot | Description |
|------|-------------|
| `with_left_panel_content` | Content for the left persistent panel |
| `with_right_panel_content` | Content for the right persistent panel |
| `with_left_drawer_content` | Content for the left overlay drawer |
| `with_right_drawer_content` | Content for the right overlay drawer |
| `with_toolbar_content` | Content for the bottom toolbar |
| `with_chat_header_content` | Custom chat header (replaces default task header) |
| `with_chat_empty_state` | Custom empty state when no task is active |

---

## Usage Examples

### 1. Full Dashboard (left panel + right panel + toolbar)

```erb
<%= render Workspace::LayoutComponent.new(
  task: @current_task,
  workspace_id: "dashboard",
  left_panel: { width: "280px", collapsible: true, title: "Artifacts" },
  right_panel: { width: "480px", collapsible: true, title: "Viewer" },
  toolbar: true,
  chat: { show_header: true, show_slash_commands: true }
) do |layout|

  layout.with_left_panel_content do %>
    <%= render Artifacts::TreeComponent.new(project: @project) %>
  <% end

  layout.with_right_panel_content do %>
    <turbo-frame id="artifact_viewer">
      <p>Select an artifact to view.</p>
    </turbo-frame>
  <% end

  layout.with_toolbar_content do %>
    <span>AiderDesk Connected</span>
  <% end

end %>
```

### 2. Chat-Only (no panels, no toolbar)

```erb
<%= render Workspace::LayoutComponent.new(
  task: @task,
  workspace_id: "simple-chat",
  chat: { placeholder: "Ask me anything...", show_slash_commands: false }
) %>
```

### 3. Chat + Left Drawer (mobile-friendly)

```erb
<%= render Workspace::LayoutComponent.new(
  task: @task,
  workspace_id: "mobile-chat",
  left_drawer: { title: "Tasks" },
  chat: { show_header: true }
) do |layout|

  layout.with_left_drawer_content do %>
    <ul class="menu">
      <li><a>Task 1</a></li>
      <li><a>Task 2</a></li>
    </ul>
  <% end

end %>
```

### 4. Workflow Monitor (left panel + right panel + both drawers + toolbar)

```erb
<%= render Workspace::LayoutComponent.new(
  task: @current_task,
  workspace_id: "workflow-monitor",
  left_panel: { width: "240px", collapsible: true, title: "Phases" },
  right_panel: { width: "360px", collapsible: true, title: "Task Detail" },
  left_drawer: { title: "All Workflows" },
  right_drawer: { title: "Agent Config" },
  toolbar: true,
  chat: { show_header: true, show_slash_commands: true, placeholder: "/implement PRD-4B-03..." }
) do |layout|

  layout.with_left_panel_content do %>
    <!-- Workflow phase list -->
  <% end

  layout.with_right_panel_content do %>
    <!-- Task detail / scoring -->
  <% end

  layout.with_left_drawer_content do %>
    <!-- Full workflow list -->
  <% end

  layout.with_right_drawer_content do %>
    <!-- Agent profile editor -->
  <% end

  layout.with_chat_header_content do %>
    <div class="flex items-center gap-2">
      <div class="badge badge-warning badge-xs"></div>
      <span class="text-sm font-bold">Φ9: Architect Review</span>
      <span class="text-xs opacity-50">PRD-4B-03</span>
    </div>
  <% end

  layout.with_toolbar_content do %>
    <span class="badge badge-success badge-xs"></span>
    <span>AiderDesk</span>
    <div class="divider divider-horizontal mx-0 h-4"></div>
    <span>SmartProxy ✅</span>
    <div class="divider divider-horizontal mx-0 h-4"></div>
    <span class="opacity-50">Cost: $0.52</span>
    <div class="flex-1"></div>
    <span>Workflow: Φ9 → Φ8 (auto-retry)</span>
  <% end

end %>
```

### 5. Multiple Instances on One Page

```erb
<!-- Agent A workspace -->
<div class="h-[50vh]">
  <%= render Workspace::LayoutComponent.new(
    task: @task_a,
    workspace_id: "agent-a",
    chat: { placeholder: "Talk to Agent A..." }
  ) %>
</div>

<!-- Agent B workspace -->
<div class="h-[50vh]">
  <%= render Workspace::LayoutComponent.new(
    task: @task_b,
    workspace_id: "agent-b",
    right_panel: { width: "300px", title: "Output" },
    chat: { placeholder: "Talk to Agent B..." }
  ) do |layout|
    layout.with_right_panel_content do %>
      <pre class="p-4 text-xs">Agent B output...</pre>
    <% end
  end %>
</div>
```

---

## Stimulus Controller

The `workspace-layout` controller handles:

- **Panel collapse/expand** — click toggle button, state persisted to `localStorage`
- **Panel resize** — drag the 4px handle between panels
- **Drawer open/close** — animated slide-in overlay with backdrop
- **Per-workspace persistence** — each `workspace_id` has independent panel states

### Keyboard/Action Bindings

All actions are bound via `data-action` attributes in the template. No manual wiring needed.

---

## File Structure

```
app/components/workspace/
├── layout_component.rb         # Ruby class (config, helpers)
├── layout_component.html.erb   # Template (all panes, drawers, toolbar)
└── README.md                   # This file

app/components/chat/
├── interface_component.rb      # Legacy standalone (still works)
├── interface_component.html.erb
├── bubble_component.rb         # Message bubble (used by both)
├── bubble_component.html.erb
├── input_component.rb          # Chat input (now accepts placeholder, show_slash_commands)
└── input_component.html.erb

app/javascript/controllers/
├── workspace_layout_controller.js  # Panel/drawer/resize behavior
└── chat_scroll_controller.js       # Auto-scroll (existing)
```

## Backward Compatibility

- `Chat::InterfaceComponent` still works standalone for pages that don't need the workspace
- `Chat::InputComponent` now accepts optional `placeholder:` and `show_slash_commands:` params (defaults match original behavior)
- The existing `dashboard/show.html.erb` has been refactored to use `Workspace::LayoutComponent`
