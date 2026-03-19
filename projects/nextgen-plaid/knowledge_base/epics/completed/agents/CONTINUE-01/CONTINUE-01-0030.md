### PRD 0030: Streaming Support for `/v1/chat/completions` (only if required)

**Overview**: Continue may require streaming (`stream: true`) and expect Server-Sent Events (SSE) in OpenAI format. Implement streaming only if log evidence shows it is required.

**Requirements**:
1) **Streaming Detection**
   - Add log visibility for whether incoming requests have `stream: true`.
2) **SSE Streaming Output (OpenAI-style)**
   - When `stream: true`, respond as:
     - `Content-Type: text/event-stream`
     - `data: {...}` chunked events
     - final `data: [DONE]`
   - Ensure Grok and Ollama streaming both function, or document limitations.
3) **Non-Streaming Path Unchanged**
   - When `stream` is false/absent, return standard JSON response.

**Architectural Context**: Many OpenAI clients set `stream: true` by default. If Continue does, SmartProxy must implement SSE. If Continue does not, streaming should not be added prematurely.

**Acceptance Criteria**:
- If Continue sends `stream: true`, it displays output without errors.
- SmartProxy logs show streaming requests and clean completion.

**Test Cases**:
- Manual: run Continue and observe if it sends `stream: true`.
- Manual: if yes, verify streaming works; if no, mark PRD as not needed and do not implement.

**Workflow**: Observe Continue behavior first; implement streaming only if required.

**Context Used**:
- `smart_proxy/app.rb` (`POST /v1/chat/completions`)
- `log/smart_proxy.log` (detecting `stream: true` requests)
