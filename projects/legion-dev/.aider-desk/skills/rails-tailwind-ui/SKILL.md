---
name: Rails Tailwind UI
description: Utility-first styling for Rails views and components with Tailwind CSS.
---

## When to use
- Building or refining UI layouts
- Creating responsive components
- Replacing ad-hoc CSS with utilities

## Required conventions
- Prefer Tailwind utility classes over custom CSS
- Keep class lists readable; extract repeated UI into partials/components
- Use the project design tokens and spacing scale
- Keep templates logic-light; use helpers for formatting

## Examples
```erb
<div class="flex items-center justify-between gap-3 rounded-lg border border-slate-200 bg-white p-4 shadow-sm">
  <h2 class="text-lg font-semibold text-slate-900"><%= title %></h2>
  <%= link_to "Edit", edit_path, class: "inline-flex items-center rounded-md border border-slate-300 px-3 py-1.5 text-sm font-medium text-slate-700 hover:bg-slate-50" %>
</div>
```

## Do / Don’t
**Do**:
- Keep spacing and typography consistent
- Prefer semantic HTML with utility classes

**Don’t**:
- Add custom CSS when utilities are sufficient
- Mix inline styles into templates
