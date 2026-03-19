# PRD-AH-011A: Markdown Response Formatting

Part of Epic 11: Consolidated SDLC Spike & Core Bridge.

---

## Problem

Agent responses in the Agent Hub are currently plain text or inconsistently formatted, making it difficult to read long PRDs, technical plans, or structured data.

## User story

As a user, I want to see agent responses rendered in beautiful, structured Markdown (headers, bold, lists, code blocks) so I can easily digest complex information.

---

## A) What SAP/CWA produce (workflow output)

Agents will now explicitly use standard Markdown syntax in their responses.

- Use `#`, `##` for structure.
- Use `**bold**` for emphasis.
- Use triple backticks for code/JSON blocks.
- Ensure proper spacing between paragraphs.

---

## B) What we build (platform/engineering work)

- Integration of a Markdown rendering library (e.g., `marked.js` on the frontend or `redcarpet`/`commonmarker` on the backend).
- Ensure `SmartProxyClient` and `AgentHubChannel` preserve formatting during transmission.
- Update the message bubble component to render Markdown.

---

## C) UI elements introduced/changed

- **Message Bubbles:** Updated to support HTML rendering of Markdown content.
- **CSS:** Styles for headers, code blocks, and lists within message bubbles.

---

## Functional requirements

- All agent responses must be rendered as Markdown.
- Support for:
  - Headers (H1-H3)
  - Bold and Italic text
  - Unordered and Ordered lists
  - Code blocks with syntax highlighting (optional but preferred)
  - Tables

---

## Acceptance criteria

- AC1: Responses with `# Header` render as H1.
- AC2: Code blocks are enclosed in `<pre><code>` or equivalent.
- AC3: Prevent "running together" of text by ensuring block-level elements have proper margins.
- AC4: Sanitization is applied to prevent XSS while allowing safe Markdown-generated HTML.

---

## Human Testing Steps & Expected Results

1.  **Step:** Ask an agent to "Create a structured PRD with headers, bold text, and a table."
    *   **Expected Result:** The agent responds with visible `#` or `##` headers that render as large, bold HTML headings. Tables are rendered as clean HTML tables, not raw text.
2.  **Step:** Ask an agent to "Provide a Ruby code snippet for a hello world function."
    *   **Expected Result:** The code is enclosed in a formatted code block (monospaced font, distinct background) rather than being inline text.
3.  **Step:** Inspect the message bubble in the browser developer tools.
    *   **Expected Result:** The content is wrapped in HTML tags (e.g., `<h1>`, `<ul>`, `<li>`, `<table>`) rather than being a single `<p>` or `<div>` with `white-space: pre-wrap`.
