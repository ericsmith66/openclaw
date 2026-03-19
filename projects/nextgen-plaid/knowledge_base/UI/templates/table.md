# Table Template

For index/list views (e.g., holdings, transactions, accounts) with tabular data. Use real `<table>` for sort/filter potential.

```erb
<main class="flex-1 p-6 bg-base-200">
  <!-- Breadcrumbs -->
  <div class="text-sm breadcrumbs mb-4">
    <ul>
      <li><a href="/">Home</a></li>
      <li>Resource</li>
    </ul>
  </div>

  <div class="flex justify-between items-center mb-6">
    <h1 class="text-3xl font-bold">Resource List</h1>
    <%= link_to "New", new_path, class: "btn btn-primary" %>
  </div>

  <!-- Search/Filter -->
  <div class="mb-4">
    <input type="text" class="input input-bordered w-full max-w-xs" placeholder="Search..." />
  </div>

  <div class="overflow-x-auto">
    <table class="table table-zebra w-full">
      <thead class="bg-base-300">
        <tr>
          <th class="w-1/4">Name / Symbol</th>
          <th>Value</th>
          <th>Description</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        <% @records.each do |record| %>
          <tr class="hover">
            <td class="truncate max-w-xs" title="<%= record.full_name_or_desc %>">
              <%= record.name %>
            </td>
            <td><%= number_to_currency(record.value) %></td>
            <td>
              <div class="tooltip tooltip-left" data-tip="<%= record.description || 'None' %>">
                <span class="truncate max-w-[200px] cursor-help">
                  <%= record.description&.truncate(60) || '-' %>
                </span>
              </div>
            </td>
            <td class="space-x-2">
              <%= link_to "View", record, class: "btn btn-ghost btn-xs" %>
              <%= link_to "Edit", edit_path(record), class: "btn btn-ghost btn-xs" %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>

    <% if @records.empty? %>
      <div class="text-center py-8 text-gray-500">No records found.</div>
    <% end %>

    <!-- Pagination -->
    <div class="flex justify-center mt-6">
      <%= paginate @records if defined?(paginate) %>
    </div>
  </div>
</main>
```

**Notes**:
- Truncation: Native `truncate` + `title` (default); DaisyUI `tooltip` for styled/mobile.
- Zebra striping for readability.
- Add Stimulus/Turbo if real-time row updates needed (e.g., sync status via streams).
