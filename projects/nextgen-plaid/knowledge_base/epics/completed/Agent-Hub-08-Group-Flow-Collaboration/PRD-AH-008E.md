# PRD-AH-008E: Conversation Management

## Overview
Implement conversation management capabilities to allow users to create, track, 
and manage multiple conversation threads with different personas. Each conversation should maintain its own context 
and message history, 
enabling users to organize and switch between different topics or workflows.

## Problem Statement
**Issue #7 from Smoke Test**: No way to add a new conversation; unclear if messages are associated with a conversation. Users cannot manage multiple conversation threads, leading to confusion and inability to organize different topics or workflows separately.

## Requirements

### Functional
- **New Conversation Creation**: Provide a UI control (e.g., "+ New Conversation" button) to start a fresh conversation thread
- **Conversation List**: Display all active conversations in the sidebar with clear identification (title, timestamp, persona)
- **Conversation Selection**: Allow users to switch between conversations by clicking on them in the sidebar
- **Conversation Association**: All messages must be clearly associated with a specific conversation (SapRun)
- **Conversation Persistence**: Each conversation maintains its own message history and context independently
- **Conversation Metadata**: Track conversation title, creation date, last updated date, associated persona, and status
- **Visual Indicators**: Show which conversation is currently active with clear visual feedback

### Non-Functional
- **Performance**: Conversation switching should be instantaneous (< 100ms)
- **Scalability**: Support at least 50 active conversations per user without performance degradation
- **Data Integrity**: Ensure messages are never orphaned or associated with wrong conversations
- **User Experience**: Clear visual distinction between different conversations; intuitive navigation

### Rails Guidance
- **Model**: Leverage existing `SapRun` model as the conversation container
  - Each `SapRun` represents one conversation thread
  - `correlation_id` format: `"agent-hub-{persona_id}-{user_id}-{conversation_id}"`
  - Add `title` field to `SapRun` for user-friendly conversation naming
  - Add `conversation_type` enum: `[:single_persona, :multi_persona, :workflow]`
- **Controller**: Extend `AgentHubsController` with conversation management actions
  - `create_conversation`: Initialize new SapRun with unique correlation_id
  - `list_conversations`: Return all active conversations for current user and persona
  - `switch_conversation`: Load selected conversation's message history
  - `archive_conversation`: Mark conversation as archived (soft delete)
- **Channel**: Update `AgentHubChannel` to include conversation_id in all broadcasts
  - Ensure messages are scoped to specific conversation
  - Update `handle_chat` to accept conversation_id parameter
- **Component**: Create `ConversationListComponent` for sidebar
  - Display conversation title, last message preview, timestamp
  - Highlight active conversation
  - Show unread message count (future enhancement)

### Traceability
- **Original Issue**: Smoke Test Issue #7 - Conversation Management
- **Related PRDs**: 
  - PRD-AH-008A (Workflow Monitor) - Multi-conversation visibility
  - PRD-AH-004 (Workflow Persistence) - SapRun foundation
- **Dependencies**: 
  - `SapRun` and `SapMessages` models (already implemented)
  - Conversation sidebar UI (ConversationSidebarComponent exists, needs enhancement)

## Acceptance Criteria

### AC1: Create New Conversation
- **Given** a user is on the Agent Hub interface
- **When** they click the "+ New Conversation" button
- **Then** a new conversation is created with a unique correlation_id
- **And** the new conversation becomes the active conversation
- **And** the chat pane is cleared and ready for new messages
- **And** the new conversation appears in the sidebar conversation list

### AC2: List Conversations
- **Given** a user has multiple conversations
- **When** they view the Agent Hub interface
- **Then** all active conversations are displayed in the sidebar
- **And** each conversation shows: title/preview, persona icon, last updated timestamp
- **And** conversations are sorted by most recently updated first
- **And** the currently active conversation is visually highlighted

### AC3: Switch Between Conversations
- **Given** a user has multiple conversations
- **When** they click on a different conversation in the sidebar
- **Then** the chat pane loads that conversation's message history
- **And** the context window reflects that conversation's state
- **And** new messages are associated with the selected conversation
- **And** the selected conversation is visually highlighted as active

### AC4: Message Association
- **Given** a user is in a specific conversation
- **When** they send a message or receive a response
- **Then** the message is saved to the database with the correct `sap_run_id`
- **And** the message only appears in that conversation's chat pane
- **And** switching to another conversation does not show this message

### AC5: Conversation Persistence
- **Given** a user has sent messages in a conversation
- **When** they switch to another conversation and then back
- **Then** all previous messages are displayed in correct order
- **And** the conversation context is maintained
- **And** no messages are lost or duplicated

### AC6: Conversation Metadata
- **Given** a conversation exists
- **When** viewing the conversation in the sidebar
- **Then** the conversation displays a meaningful title (auto-generated from first message or user-defined)
- **And** the last updated timestamp is accurate
- **And** the associated persona is clearly indicated

## Test Cases

### Unit Tests
- **Test**: `SapRun.create_conversation` creates unique correlation_id
- **Test**: `SapRun.for_user_and_persona` returns correct conversations
- **Test**: `SapMessage.for_conversation` returns only messages for that conversation
- **Test**: Conversation title auto-generation from first user message

### Integration Tests
- **Test**: Create new conversation via UI, verify database record created
- **Test**: Send message in conversation A, switch to conversation B, verify message only in A
- **Test**: Load conversation with 50+ messages, verify all messages display correctly
- **Test**: Create multiple conversations with same persona, verify independent contexts
- **Test**: Archive conversation, verify it no longer appears in active list

### System Tests
- **Test**: User creates 3 conversations, sends messages in each, switches between them, verifies correct message history in each
- **Test**: User creates conversation, refreshes browser, verifies conversation persists and messages reload
- **Test**: Two users with same persona have independent conversation lists

## Implementation Notes

### Database Schema Changes
```ruby
# Migration: Add conversation management fields to sap_runs
add_column :sap_runs, :title, :string
add_column :sap_runs, :conversation_type, :string, default: 'single_persona'
add_index :sap_runs, [:user_id, :status, :updated_at]
```

### Correlation ID Format
- **Current**: `"agent-hub-{persona_id}-{user_id}"` (one conversation per persona per user)
- **New**: `"agent-hub-{persona_id}-{user_id}-{uuid}"` (multiple conversations per persona per user)
- **Migration Strategy**: Existing conversations keep current format; new conversations use new format

### UI/UX Considerations
- **Conversation Title**: Auto-generate from first 50 characters of first user message, allow user to edit later
- **Empty State**: When no conversations exist, show helpful prompt to create first conversation
- **Active Conversation Indicator**: Use accent color border and background highlight
- **Conversation Actions**: Provide context menu for rename, archive, delete (future enhancement)

### Future Enhancements (Out of Scope for 008E)
- Conversation search and filtering
- Conversation sharing between users
- Conversation export (PDF, Markdown)
- Conversation templates
- Unread message indicators
- Conversation tags/labels
- Bulk conversation operations

## Success Metrics
- Users can create and manage at least 5 concurrent conversations without confusion
- Zero message association errors (messages appearing in wrong conversations)
- Conversation switching completes in < 100ms
- User feedback indicates improved organization and workflow management
