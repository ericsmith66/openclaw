# Chat Template

For AI persona interaction pages (e.g., agent_hub style: tabs + sidebar conversations + central chat pane + optional right preview).

```erb
<div class="drawer lg:drawer-open">
  <input id="chat-drawer" type="checkbox" class="drawer-toggle" />
  <div class="drawer-content flex flex-col">
    <!-- Navbar (reuse if possible) -->
    <%= render "shared/navigation" %>

    <main class="flex-grow p-4 bg-base-200">
      <!-- Optional alert -->
      <div class="alert alert-info mb-4">Session Info</div>

      <!-- Persona Tabs / Model Selector -->
      <div class="flex items-center justify-between bg-base-200 rounded-t-box p-1">
        <div class="tabs tabs-lifted overflow-x-auto">
          <!-- Example tab -->
          <%= link_to "Persona Name", path, class: "tab #{'tab-active bg-primary text-white' if active}", data: { turbo_frame: "chat_content" } %>
        </div>
        <!-- Model dropdown (if needed) -->
        <div class="dropdown dropdown-end">
          <button class="btn btn-ghost btn-sm">Model ▼</button>
          <ul class="menu dropdown-content bg-base-100 rounded-box w-52">...</ul>
        </div>
      </div>

      <turbo-frame id="chat_content">
        <div class="flex flex-grow mt-4 border border-base-300 rounded-box overflow-hidden min-h-[600px]">
          <!-- Collapsible Sidebar (conversations) -->
          <div class="flex h-full border-r border-base-300" data-controller="sidebar">
            <div class="w-64 bg-base-200 overflow-y-auto transition-all">
              <!-- Search + New Conversation -->
              <div class="p-4 border-b">
                <input type="text" class="input input-bordered w-full" placeholder="Search..." data-action="input->search#filter" />
                <button class="btn btn-primary btn-sm w-full mt-2">New Conversation</button>
              </div>
              <!-- List -->
              <ul class="menu p-2">...</ul>
            </div>
            <button class="btn btn-ghost btn-xs" data-action="click->sidebar#toggle">◄</button>
          </div>

          <!-- Central Chat Pane -->
          <div class="flex-grow bg-base-100 p-6 flex flex-col overflow-y-auto">
            <h1 class="text-2xl font-bold mb-4">Chat Title (e.g., Workflow Monitor)</h1>
            <div class="flex-grow bg-base-200 rounded-lg p-4 overflow-y-auto" data-controller="chat-pane">
              <div id="messages" class="space-y-4" data-chat-pane-target="messages"></div>
              <div id="typing" class="hidden flex items-center">Loading...</div>
            </div>
          </div>

          <!-- Optional Right Preview (artifact style) -->
          <div class="w-96 border-l border-base-300 bg-base-50 flex flex-col">
            <!-- Header + Tabs -->
            <div class="p-4 border-b">
              <h2 class="font-bold truncate" title="Full Title">Preview Title</h2>
              <div class="tabs tabs-boxed mt-2">
                <button class="tab tab-sm">View 1</button>
                <button class="tab tab-sm">View 2</button>
              </div>
            </div>
            <div class="flex-grow p-4 overflow-y-auto prose prose-sm">
              <!-- Content -->
            </div>
          </div>
        </div>
      </turbo-frame>
    </main>
  </div>

  <div class="drawer-side">
    <!-- Mobile sidebar menu if needed -->
  </div>
</div>
```

**Notes for implementation**:
- Stimulus controllers: sidebar, search, chat-pane.
- Turbo: Use frames/streams for tab switches and real-time messages (like agent_hub).
- Limit tabs: 6-8 max.
- Truncation: Use `truncate` + `title` on titles/messages.
