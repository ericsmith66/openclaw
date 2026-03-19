# NextGen Plaid UI Style Guide

## Purpose
This guide ensures all pages and components are consistent, professional, elegant, and simple — tailored for young adults (22-30) in high-net-worth families. No playful or "kid-friendly" elements. All UI follows existing patterns from dashboard, agent_hub, and application layout.

## Core Principles
- **Theme**: Always apply `data-theme="business"` (DaisyUI business theme) at `<body>` or root.
- **Base Stack**: Tailwind CSS + DaisyUI components (btn, card, tabs, menu, drawer, alert, dropdown, tooltip, table-zebra, modal).
- **Layout Patterns**:
  - Full-height: `min-h-screen flex flex-col`
  - Drawers: `drawer lg:drawer-open` for persistent sidebars (e.g., main nav or conversations)
  - Main content: `flex-1 p-6 bg-base-200`
  - Cards: `bg-base-100 p-6 rounded-lg border shadow` or `bg-base-200` variants
- **Responsiveness**: Mobile-first; use `lg:`/`md:` prefixes only when needed. Overflow handling: `overflow-y-auto` for scrollable panes.
- **Simplicity & Elegance**:
  - Limit nesting depth (max 2-3 levels in cards/flex).
  - Prefer DaisyUI over custom CSS.
  - Use ViewComponents for reusable pieces (e.g., navigation_component).
  - Empty states: Centered text + subtle icon (e.g., "No accounts connected yet").
- **Accessibility**: Semantic HTML, `cursor-pointer`, ARIA labels (e.g., drawer-overlay), good contrast via business theme.
- **Interactivity**: Turbo Frames for partial reloads, Action Cable + Turbo Streams for real-time, Stimulus for lightweight behaviors (sidebar toggle, search filter, chat-pane).
- **Truncated Text & Hover Reveal**:
  - Default: `truncate` class + `title="full value"` (native browser tooltip) — zero JS, matches artifact preview pattern.
  - Styled: DaisyUI `tooltip tooltip-bottom` with `data-tip="full text"` for better mobile/tap support.
  - Advanced (full record preview): Stimulus controller + Turbo Frame load from record_path, or Action Cable stream (follow agent_hub artifact preview: `turbo_stream_from` + broadcast_replace_to).
  - Never truncate critical numeric/date fields — wrap or use responsive columns.
- **Testing**: Component isolation in views, RSpec for logic, optional Capybara for e2e responsiveness.

## Color Palette (DaisyUI business theme — do not override yet)
- primary: #3b82f6 (vibrant blue — CTAs, links)
- primary-content: #ffffff
- secondary: #f472b6
- accent: #fbbf24
- neutral: #1f2937
- base-100: #1f2937 (main surfaces)
- base-200: #111827 (cards/panels)
- base-300: #0f172a (borders, alerts)
- base-content: #f3f4f6 (text)
- info: #0ea5e9
- success: #10b981
- warning: #f59e0b
- error: #ef4444

Use primary for actions, success/info for status badges, error for alerts. Neutrals for backgrounds/text.

## Dos & Don'ts
- Do: Reuse existing components (navigation_component, etc.); mock data in previews.
- Do: Use Turbo Frames for dynamic sections (e.g., agent_hub_content).
- Don't: Over-nest (avoid deep card-in-card-in-card); invent custom colors/themes.
- Don't: Heavy Stimulus unless for core interactions (sidebar, chat, search).

## Templates
Reference knowledge_base/UI/templates/{chat|table|general}.md for page skeletons. Use them as starting points; adapt minimally.

Last updated: January 16, 2026
