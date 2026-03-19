# Rails 8 Base Rules

## 1. Idiomatic Ruby & Rails 8
- **Ruby 3.3+ Syntax**: Use modern Ruby features like anonymous block forwarding (`&`), pattern matching where appropriate, and safe navigation (`&.`).
- **Active Record Standards**:
  - Always use `find_by` or `find_or_create_by!` for lookups.
  - Use `scopes` for queries; avoid complex logic in class methods.
  - Prefer `pluck` or `pick` over `map` for extracting single attributes.
- **Modern Asset Pipeline**: We use **Propshaft**, **Turbo**, and **Stimulus**. Use Turbo-friendly methods for destructive actions.

## 2. Testing & Quality (Minitest)
- **Mandatory Coverage**: No code changes without a corresponding Minitest file.
- **FactoryBot**: Use factories for all model setup; never use manual `Model.create` in tests.
- **Component Testing**: Since we use **ViewComponent**, test them in isolation using `ViewComponent::TestCase`.
- **System Testing**: Use Capybara for system/smoke tests.
- **Mocking**: Mock external hardware/API interactions to ensure tests run offline and fast. Use VCR where appropriate.

## 3. Architecture & Service Objects
- **Thin Models/Controllers**: Business logic belongs in `app/services/` or `app/commands/`.
- **Service Pattern**: Use a consistent entry point: `MyService.call(args)`.
- **Composition**: Favor small, focused modules over deep inheritance hierarchies.

## 4. Security & Performance
- **Strong Parameters**: Never bypass `params.require(...).permit(...)`.
- **Concurrency**: Use `with_lock` or atomic cache operations (`fetch` with `race_condition_ttl`) when handling rapid API webhooks to prevent race conditions.
- **N+1 Avoidance**: Use `.includes`, `.preload`, or `.eager_load` for all associated data.

## 5. Logging & Communication
- **Agent Logging**: Every agent action MUST follow the standards in `knowledge_base/ai-instructions/task-log-requirement.md`.
- **Structured Logging**: Use `Rails.logger` with specific levels.
- **COMMIT POLICY**:
  - Commit plans always (no approval needed)
  - Commit code only when all tests pass (green gate)
  - NEVER run destructive git commands (drop, reset, truncate) without explicit user confirmation
- **Commit Messages**: Follow the format `Component: Short imperative description`.
