---
name: Rails DaisyUI Components
description: DaisyUI component usage and theming on top of Tailwind CSS.
---

## When to use
- Building UI with DaisyUI components
- Standardizing buttons, cards, modals, and alerts
- Applying consistent themes across views

## Required conventions
- Prefer DaisyUI component classes (`btn`, `card`, `alert`, `modal`)
- Use theme tokens instead of hard-coded colors
- Keep component structure consistent across views

## Examples
```erb
<div class="card bg-base-100 shadow-sm">
  <div class="card-body">
    <h3 class="card-title">Invite sent</h3>
    <p class="text-sm text-base-content/70">We emailed the invite link.</p>
    <div class="card-actions justify-end">
      <%= link_to "View", invite_path, class: "btn btn-sm btn-primary" %>
    </div>
  </div>
</div>
```

## Do / Don’t
**Do**:
- Use DaisyUI classes for consistency
- Prefer built-in component patterns over custom markup

**Don’t**:
- Mix multiple styling systems in the same view
- Override DaisyUI styles with inline CSS
