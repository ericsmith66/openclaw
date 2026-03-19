# Agent Hub Grok Streaming Duplication Issue

## Problem Summary

Users experienced garbled, duplicated text when using Grok model in Agent Hub (e.g., "I'm I'm Gro Grokk,, an an AI AI built built by by x xAIAI"). The issue was specific to:
- **Grok model only** (Ollama worked fine)
- **Agent Hub only** (SAP Collaborate worked fine)
- **All personas** in Agent Hub

## Root Cause

The `AgentHub::SmartProxyClient#broadcast_token` method was broadcasting each token to TWO ActionCable channels:
1. The target agent channel (e.g., `agent_hub_channel_sap-agent`)
2. The workflow monitor channel (`agent_hub_channel_workflow_monitor`)

This dual broadcast was intended to allow the workflow_monitor persona to observe all agent interactions. However, 
users' browsers were somehow subscribed to BOTH channels simultaneously, 
causing each token to be received and appended twice, resulting in the garbled output.

## Why Only Grok?

The issue appeared only with Grok because:
- **SAP Collaborate** uses Turbo Streams (database updates), not ActionCable, so it never had the dual broadcast issue
- **Ollama** in Agent Hub likely had the same dual broadcast, but the issue may not have been noticed or reported

## The Fix

**File:** `app/services/agent_hub/smart_proxy_client.rb`

**Change:** Removed the secondary broadcast to `workflow_monitor` channel.

**Before:**
```ruby
def broadcast_token(token, stream_to)
  payload = { type: "token", token: token }
  ActionCable.server.broadcast("agent_hub_channel_#{stream_to}", payload)
  
  # Also broadcast to workflow monitor
  unless stream_to.to_s.include?("workflow_monitor")
    ActionCable.server.broadcast("agent_hub_channel_workflow_monitor", payload)
  end
end
```

**After:**
```ruby
def broadcast_token(token, stream_to)
  payload = { type: "token", token: token }
  
  # TEMPORARY FIX: Only broadcast to the target channel to prevent duplication
  # The workflow_monitor broadcast was causing users subscribed to multiple channels
  # to receive duplicate tokens. This can be re-enabled once the client-side
  # subscription management is fixed.
  ActionCable.server.broadcast("agent_hub_channel_#{stream_to}", payload)
end
```

**Impact:** 
- ✅ Fixes the duplication issue immediately
- ⚠️ Disables the workflow_monitor feature (it will no longer receive updates from other agents)

## Rollback Plan for Diagnostic Changes

During the investigation, several diagnostic changes were made that should be rolled back:

### 1. Remove Shared Consumer Changes (chat_pane_controller.js)
**File:** `app/javascript/controllers/chat_pane_controller.js`

**Changes to rollback:**
- Lines 4-13: Remove the `sharedConsumer` and `getConsumer()` function
- Line 36: Change back to `createConsumer()` instead of `getConsumer()`
- Lines 29-33: Remove the unsubscribe logic in the `subscribe()` method

**Reason:** This was an attempted fix for multiple subscriptions, but it wasn't the root cause and the JavaScript changes weren't loading properly anyway.

### 2. Remove Deduplication Logic Changes (smart_proxy_client.rb)
**File:** `app/services/agent_hub/smart_proxy_client.rb`

**Changes to rollback:**
- Lines 108-162: The `deduplicate` method can be simplified or removed if it's not needed
- Lines 83-89: The deduplication call in `chat_stream` can be simplified

**Reason:** The deduplication logic was added to handle overlapping tokens from Grok, but the real issue was the dual broadcast. The deduplication may still be useful for handling Grok's streaming format, so review before removing.

### 3. Remove Test Changes (smart_proxy_client_test.rb)
**File:** `test/services/agent_hub/smart_proxy_client_test.rb`

**Changes to rollback:**
- Lines 56-87: Remove the "chat stream deduplicates when upstream sends full text in delta" test
- Lines 89-121: Remove the "chat stream handles word-level duplication" test
- Lines 42-46: Update the "chat stream broadcasts tokens" test to remove the workflow_monitor broadcast expectations

**Reason:** These tests were added to verify the deduplication logic and dual broadcast behavior, which are no longer needed.

### 4. Review SapAgentService Changes
**File:** `app/services/sap_agent_service.rb`

**Changes to review:**
- Lines 155-207: The `deduplicate` method - determine if this is still needed for SAP Collaborate
- Lines 39-40: The `SAP_DISABLE_GROK_STREAMING` environment variable handling

**Reason:** These changes were made during earlier investigation attempts. SAP Collaborate doesn't have the duplication issue, so these may not be necessary.

### 5. Review Test File Changes
**File:** `test/services/sap_agent_service_test.rb`

**Changes to review:**
- The entire test file was added during investigation
- Determine if these tests are valuable to keep or should be removed

### 6. Review Agent Hub Channel Test Changes
**File:** `test/channels/agent_hub_channel_test.rb`

**Changes to review:**
- Lines 28-32: The cache stub in the "enforces max streams cap" test
- Determine if this change should be kept or reverted

## Recommended Next Steps

1. **Commit the broadcast-issue.md file** (this document)
2. **Review each file** listed in the rollback plan
3. **Decide which changes to keep** (e.g., useful tests, deduplication logic)
4. **Rollback unnecessary changes** one file at a time
5. **Test thoroughly** after each rollback to ensure functionality remains intact
6. **Consider re-enabling workflow_monitor** once client-side subscription management is fixed

## Long-Term Solution

To properly re-enable the workflow_monitor feature without duplication:

1. **Fix client-side subscription management** to ensure users only subscribe to ONE channel at a time
2. **Implement proper cleanup** when switching between personas
3. **Add client-side deduplication** as a safety net
4. **Re-enable the workflow_monitor broadcast** in `broadcast_token`

## Testing Checklist

After rollback, verify:
- [ ] Grok streaming works without duplication in Agent Hub (all personas)
- [ ] Ollama streaming works without duplication in Agent Hub
- [ ] SAP Collaborate still works correctly with Grok
- [ ] All existing tests pass
- [ ] No console errors in browser
- [ ] ActionCable connections are properly cleaned up when switching personas
