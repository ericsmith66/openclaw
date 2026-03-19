#### PRD-4-01: PersonaConversation & PersonaMessage Schema + Persona Configuration

**Log Requirements**
Junie: Read `<project root>/knowledge_base/prds/prds-junie-log/junie-log-requirement.md` and log your plan/questions.
- In the log put detailed steps for human to manually test and what the expected results.
- If asked to review please create a separate document called <epic or prd name>-feedback.md.

**Overview**
Create NEW database models `PersonaConversation` and `PersonaMessage` (separate from admin `SapRun`/`SapMessage`) for user-facing persona chat interface at `/chats/[persona]`. Implement hybrid title generation (truncation + async LLM upgrade), add model methods and scopes, create TitleGenerationJob for async LLM summarization, and define persona configuration via config/personas.yml with Warren Buffett financial advisor as first persona. This provides the data foundation for the entire Epic 4 user-facing persona chat interface, completely separate from admin Agent Hub.

**Requirements**

**Functional**:
- **NEW Models**: Create `PersonaConversation` and `PersonaMessage` models (separate from `SapRun`/`SapMessage`)
  - `PersonaConversation` table with columns: `user_id:integer`, `persona_id:string`, `model_name:string`, `title:string`, `created_at`, `updated_at`
  - `PersonaMessage` table with columns: `persona_conversation_id:integer`, `role:string` (user/assistant), `content:text`, `created_at`, `updated_at`
  - Index on `persona_conversations[user_id, persona_id]` for fast lookup
  - Foreign key: `persona_messages.persona_conversation_id` → `persona_conversations.id`
- **Validations**:
  - `validates :persona_id, presence: true, inclusion: { in: -> { Personas.ids } }` (dynamic from config)
  - `validates :model_name, presence: true`
  - `validates :title, presence: true`
  - `validates :user_id, presence: true`
  - PersonaMessage: `validates :role, inclusion: { in: %w[user assistant] }`
- **Scopes**:
  - `scope :for_persona, ->(persona_id) { where(persona_id: persona_id) }`
  - `scope :for_user, ->(user) { where(user_id: user.id) }`
  - `scope :recent_first, -> { order(updated_at: :desc) }`
- **Methods**:
  - `PersonaConversation#generate_title_from_first_message` — Hybrid approach:
    1. Set truncated title immediately: `persona_messages.where(role: 'user').first&.content&.truncate(40, separator: ' ', omission: '...')` or `"Chat #{created_at.strftime('%b %d')}"`
    2. Enqueue `TitleGenerationJob.perform_later(id)` if exactly 1 user message
  - `PersonaConversation#last_message_preview` — Returns last message content truncated to 60 chars
  - `PersonaConversation.create_conversation(user_id:, persona_id:)` — Creates new conversation with last-used model for persona (query `where(user_id:, persona_id:).order(updated_at: :desc).limit(1).pluck(:model_name).first || "llama3.1:70b"`)
- **TitleGenerationJob** (ActiveJob):
  - Prompt: "Summarize this message in 3-5 words for a chat title: [user_message_content]"
  - Call SmartProxyClient with lightweight model: llama3.1:8b or claude-haiku (via smart_proxy)
  - Timeout: 5 seconds
  - On success: Update persona_conversation.title with LLM response (cleaned, max 50 chars)
  - On failure: Keep truncated title, log error with Rails.logger
- **Persona Config** (config/personas.yml):
  ```yaml
  personas:
    - id: financial-advisor
      name: Warren Buffett
      default_model: llama3.1:70b
      system_prompt_ref: prompts/warren_buffett_financial_advisor.txt
      rag_namespace: financial_advisor
      description: Learn investment principles from the Oracle of Omaha
      system_prompt: |
        You are Warren Buffett, teaching value investing principles and long-term financial thinking.
        Focus on educational guidance about investment philosophy, business analysis, and wealth-building principles.
        Reference your experiences at Berkshire Hathaway, lessons from Benjamin Graham, and timeless investment wisdom.
        Keep responses conversational and accessible - explain complex concepts simply.
        This is an educational simulation to help users learn financial principles.
  ```
- **Persona Loader** (initializer or constant):
  - `Personas.all` — Returns array of persona configs
  - `Personas.find(id)` — Returns persona config by id
  - `Personas.ids` — Returns array of persona IDs for validation (`["financial-advisor"]`)

**Non-Functional**:
- Migrations run safely (reversible, no data loss)
- NEW models completely separate from SapRun/SapMessage (admin-only)
- TitleGenerationJob retries on transient failures (3 attempts, exponential backoff)
- Config loads once at boot (no repeated YAML parsing)

**Rails-Specific**:
- Models: `rails g model PersonaConversation user:references persona_id:string model_name:string title:string`
- Models: `rails g model PersonaMessage persona_conversation:references role:string content:text`
- Add index: `add_index :persona_conversations, [:user_id, :persona_id]`
- Add index: `add_index :persona_messages, :persona_conversation_id`
- Job: `rails g job TitleGeneration`
- Config loader: `config/initializers/personas.rb` or `lib/personas.rb` with `PERSONAS` constant
- Queue: Use Solid Queue (existing project queue)
- RAG directory: Create `knowledge_base/personas/financial_advisor/` for persona-specific docs

**Error Scenarios & Fallbacks**:
- **Migration fails**: Ensure reversible migrations with proper rollback logic
- **TitleGenerationJob timeout**: Keep truncated title, log: `Rails.logger.warn "[TitleGenJob] timeout for conversation_id=#{conversation_id}"`
- **SmartProxyClient unavailable**: Fallback to truncated title, retry job after 5 minutes
- **Invalid persona_id on create**: Validation error, return to user: "Invalid persona selected"
- **Persona config file missing**: Raise error on boot with clear message: "config/personas.yml not found"

**Architectural Context**
MVC: PersonaConversation and PersonaMessage are NEW ActiveRecord models, completely separate from SapRun/SapMessage (which remain admin-only). TitleGenerationJob uses SmartProxyClient (existing service) to call Ollama via smart_proxy. Personas config loaded via initializer, accessible as `Personas` module/class. Controller (in PRD 4-02) will call `PersonaConversation.create_conversation` to initialize conversations. Job enqueued from model callback or controller action after first message saved. PostgreSQL RLS enforces user isolation. No frontend changes in this PRD—pure backend foundation for NEW user-facing `/chats/[persona]` interface.

**Acceptance Criteria**
- `persona_conversations` table exists with columns: `user_id`, `persona_id`, `model_name`, `title`, timestamps
- `persona_messages` table exists with columns: `persona_conversation_id`, `role`, `content`, timestamps
- Index on `persona_conversations[user_id, persona_id]` for fast lookup
- Foreign key relationship: persona_messages → persona_conversations
- Validations prevent invalid persona_id or missing model_name
- Scopes work: `PersonaConversation.for_persona("financial-advisor").for_user(user).recent_first` returns correct records
- `PersonaConversation.create_conversation(user_id: 1, persona_id: "financial-advisor")` inherits last-used model for financial-advisor (or defaults to llama3.1:70b)
- `PersonaConversation#generate_title_from_first_message` sets truncated title immediately and enqueues job
- `TitleGenerationJob` calls smart_proxy with lightweight model, updates title on success, logs on failure
- `Personas.all` returns array of persona configs from YAML
- `Personas.ids` returns `["financial-advisor"]` for validation
- `Personas.find("financial-advisor")` returns Warren Buffett config with system prompt
- RAG directory exists: `knowledge_base/personas/financial_advisor/`
- All Minitest model tests pass
- No console errors on `rails c` after migration
- Models are completely separate from SapRun/SapMessage (admin-only)

**Test Cases**

**Unit (Minitest)**:
- `test/models/persona_conversation_test.rb`:
  ```ruby
  test "validates persona_id inclusion" do
    conversation = PersonaConversation.new(user_id: 1, persona_id: "invalid")
    assert_not conversation.valid?
    assert_includes conversation.errors[:persona_id], "is not included in the list"
  end

  test "for_persona scope filters by persona_id" do
    create(:persona_conversation, persona_id: "financial-advisor")
    assert_equal 1, PersonaConversation.for_persona("financial-advisor").count
  end

  test "create_conversation inherits last used model" do
    user = create(:user)
    create(:persona_conversation, user: user, persona_id: "financial-advisor", model_name: "llama3.1:8b")
    conversation = PersonaConversation.create_conversation(user_id: user.id, persona_id: "financial-advisor")
    assert_equal "llama3.1:8b", conversation.model_name
  end

  test "generate_title_from_first_message sets truncated title" do
    conversation = create(:persona_conversation, persona_id: "financial-advisor")
    create(:persona_message, persona_conversation: conversation, role: "user", content: "This is a very long message that should be truncated to 40 characters")
    conversation.generate_title_from_first_message
    assert_equal "This is a very long message that...", conversation.title
  end
  ```

- `test/jobs/title_generation_job_test.rb`:
  ```ruby
  test "updates title with LLM response" do
    conversation = create(:persona_conversation, title: "Truncated...")
    create(:persona_message, persona_conversation: conversation, role: "user", content: "What are Warren Buffett's investment principles?")

    SmartProxyClient.stub :generate, "Investment Principles" do
      TitleGenerationJob.perform_now(conversation.id)
    end

    assert_equal "Investment Principles", conversation.reload.title
  end

  test "keeps truncated title on failure" do
    conversation = create(:persona_conversation, title: "Truncated...")
    SmartProxyClient.stub :generate, ->(*) { raise "timeout" } do
      TitleGenerationJob.perform_now(conversation.id)
    end
    assert_equal "Truncated...", conversation.reload.title
  end
  ```

- `test/lib/personas_test.rb`:
  ```ruby
  test "Personas.all returns array of configs" do
    assert_equal 1, Personas.all.size
    assert_equal "financial-advisor", Personas.all.first[:id]
  end

  test "Personas.find returns persona by id" do
    persona = Personas.find("financial-advisor")
    assert_equal "Warren Buffett", persona[:name]
    assert_includes persona[:system_prompt], "value investing"
  end
  ```

**Integration (Minitest)**:
- `test/integration/persona_conversation_creation_test.rb`:
  ```ruby
  test "creating conversation with last used model" do
    user = users(:alice)
    # Alice's last financial-advisor chat used 8b model
    PersonaConversation.create!(user: user, persona_id: "financial-advisor", model_name: "llama3.1:8b", title: "Old chat")

    new_conversation = PersonaConversation.create_conversation(user_id: user.id, persona_id: "financial-advisor")
    assert_equal "llama3.1:8b", new_conversation.model_name
    assert_equal "financial-advisor", new_conversation.persona_id
  end
  ```

**Manual**:
1. Run migrations: `bin/rails db:migrate` — verify no errors
2. Create RAG directory: `mkdir -p knowledge_base/personas/financial_advisor`
3. Rails console:
   ```ruby
   # Test persona config
   Personas.all # => returns 1 persona (financial-advisor)
   Personas.find("financial-advisor") # => returns Warren Buffett config

   # Test validations
   PersonaConversation.new(persona_id: "invalid").valid? # => false

   # Test scopes
   PersonaConversation.for_persona("financial-advisor").count # => returns count

   # Test create_conversation
   user = User.first
   conversation = PersonaConversation.create_conversation(user_id: user.id, persona_id: "financial-advisor")
   conversation.model_name # => should be llama3.1:70b or last-used

   # Test title generation
   conversation.persona_messages.create!(role: "user", content: "What are Warren Buffett's top investment principles?")
   conversation.generate_title_from_first_message
   conversation.title # => "What are Warren Buffett's top..."

   # Test job (in console or async)
   TitleGenerationJob.perform_now(conversation.id)
   conversation.reload.title # => should be LLM-generated 3-5 word summary like "Investment Principles"
   ```

**Workflow**
Use Claude Sonnet 4.5. `git pull origin main`. `git checkout -b feature/prd-4-01-persona-conversation-schema`. Ask questions and build detailed plan first. Create NEW models (PersonaConversation/PersonaMessage), NOT modifying SapRun/SapMessage. Commit only green (tests pass). Open PR for review.

**Dependencies**: None (foundational PRD)

**Related PRDs**: PRD 4-02 (will use schema), PRD 4-04 (will test end-to-end)
