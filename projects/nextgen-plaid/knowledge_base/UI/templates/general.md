# General Template

For standard pages: show, new/edit forms, summaries, dashboards (non-chat, non-table-heavy).

```erb
<main class="flex-1 p-6 bg-base-200">
  <!-- Breadcrumbs -->
  <div class="text-sm breadcrumbs mb-4">
    <ul>
      <li><a href="/">Home</a></li>
      <li>Section</li>
      <li>Current Page</li>
    </ul>
  </div>

  <!-- Optional Hero / Summary -->
  <div class="text-center py-8 mb-8">
    <h1 class="text-4xl font-bold mb-2">Page Title</h1>
    <p class="text-lg text-gray-500">Brief subtitle or status</p>
  </div>

  <!-- Content Grid -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
    <!-- Card Example -->
    <div class="card bg-base-100 shadow border p-6">
      <h2 class="text-2xl font-bold mb-4">Section One</h2>
      <p>Content, stats, or form fields...</p>
      <!-- Truncated example -->
      <p class="truncate" title="Very long account description here">Long description that might overflow...</p>
    </div>

    <div class="card bg-base-100 shadow border p-6">
      <h2 class="text-2xl font-bold mb-4">Section Two</h2>
      <!-- More content -->
    </div>
  </div>

  <!-- Actions -->
  <div class="mt-8 flex justify-center lg:justify-end gap-4">
    <button class="btn btn-primary">Save / Primary Action</button>
    <button class="btn btn-ghost">Cancel</button>
  </div>
</main>
```

**Notes**:
- Use `grid` for 1-3 column layouts.
- Hero optional for welcome/summary pages.
- Forms: Wrap fields in cards; use DaisyUI input/select/checkbox.
- Truncation: `truncate` + `title` on any overflow text.
