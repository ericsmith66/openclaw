Prompt 1: Atomic Model Creation and Migration
textYou are an expert Ruby on Rails developer working in an agentic workflow. You have access to a terminal / shell and a fresh Rails 7+ application that was created with:

rails new myapp --database=sqlite3 --skip-javascript

You are currently inside the myapp directory.

Your task is to create a User model with the following requirements:

- Attributes: name (string), email (string with a unique index), age (integer)
- The model should include basic presence validations for name and email
- Email should be unique (database-level uniqueness constraint)

Follow an agentic process:
1. Plan your steps clearly before writing any code.
2. Use Rails generators when appropriate.
3. Execute commands (simulate running them and describe expected output).
4. If you encounter an error (or would in real life), debug it agentically and retry.
5. After finishing, verify the work by:
    - Showing the generated migration file content
    - Confirming the schema.rb has the users table with correct columns and index
    - Writing a short Rails console snippet that successfully creates a User and fails when trying to create a duplicate email

Begin now. Show your full thinking and actions step by step.

Prompt 2: Atomic Controller and Route Setup for CRUD
textYou are an expert Ruby on Rails developer in an agentic workflow.

You are inside a Rails 7+ application (already created) that has a Post model with:

- title (string)
- content (text)

The migration and model already exist.

Your goal is to implement a complete RESTful JSON API controller for Posts, including:

- Routes: full resourceful routes (index, show, create, update, destroy)
- Controller: PostsController with all standard CRUD actions
- Responses: JSON format only (no views needed)
- Create & update should accept { title, content } and return the post or errors
- Index should return array of posts
- Show, update, destroy should find by id and handle not found cases
- Use strong parameters

Follow an agentic process:
1. Plan which files you will create/edit
2. Write the exact code changes you would make
3. Add resourceful routes correctly
4. After implementing, test agentically by describing:
    - curl-like requests for each action
    - Expected successful responses (status + body shape)
    - Expected error cases (404, 422 unprocessable entity)
5. If you spot a mistake during your simulated testing, correct it and re-test

Start now. Think step-by-step and show all code you would write or change.


Prompt 3: Atomic Validation and Error Handling in Form Submission
You are an expert Ruby on Rails developer working agentically.

You are inside an existing Rails 7+ app with a Product model that has:

- name (string)
- price (decimal)
- stock (integer)

The model, migration, and basic ProductsController already exist (with standard scaffold-generated CRUD).

Your task is to:

1. Add model validations:
    - name must be present
    - price must be present and greater than 0
    - stock must be present and greater than or equal to 0
    - Add friendly error messages

2. Update the create and update actions in ProductsController to:
    - Use strong parameters
    - Return JSON
    - On success (create): 201 Created with the product
    - On success (update): 200 OK with the product
    - On failure: 422 Unprocessable Entity with { errors: { field: ["message"] } }

Follow an agentic workflow:
1. Plan your changes
2. Write the exact code you would add to app/models/product.rb
3. Write the exact changes to app/controllers/products_controller.rb (focus on create & update)
4. Simulate testing:
    - Try creating a valid product → expect 201
    - Try creating with negative price → expect 422 + error message
    - Try creating without name → expect 422 + error message
    - Try updating stock to -1 → expect 422
5. If anything would fail in your simulation, debug and fix agentically

Begin. Show clear step-by-step reasoning and all code changes.


Test4 Prompt 4: Atomic Complex Polymorphic Soft-Delete with Auditable Recovery (Hard Mode)

You are an expert Ruby on Rails 7+ developer working in a strict agentic workflow with shell/REPL access.

You are inside a fresh Rails 7+ app created with:

rails new myapp --database=postgresql --api --skip-javascript

(Assume PostgreSQL because we need proper JSONB and partial indexes.)

The app already has these models and migrations run:

- User (devise or simple: id, email:string:uniq, created_at, updated_at)
- Post (id, title:string, content:text, user:references, created_at, updated_at)
- Comment (id, body:text, commentable:references{polymorphic}, user:references, created_at, updated_at)

Your task is to implement **soft deletion** with these **very strict requirements** — there is only one clean, performant way to do it correctly under all constraints:

Requirements — all must be 100% satisfied:

1. Soft-delete: Add deleted_at:datetime (nullable) to Post and Comment.
2. Default scope: exclude deleted records (Post.all / Comment.all should never return deleted items).
3. Polymorphic commentable: When a Post is soft-deleted, ALL its associated Comments must also be soft-deleted (cascading, atomic).
4. When a Post is restored (deleted_at = nil), ALL its previously soft-deleted Comments (that were deleted exactly when the Post was) must also be restored — but ONLY those tied to that deletion event (do not restore unrelated deleted comments).
5. No extra tables (no separate delete_events table or acts_as_paranoid-style paranoia gem tricks).
6. No recursive callbacks that can cause stack overflows or infinite loops.
7. Performance:
    - Listing posts: no N+1
    - Deleting a post: single transaction, no loading all comments into memory if post has thousands
    - Restoring a post: same — efficient, no full load
8. Auditable recovery: When restoring a post, log exactly which comments were restored (output to Rails.logger.info in a specific format).
9. Edge cases to handle correctly:
    - Comment deleted independently → must stay deleted even if parent Post is restored
    - Post deleted → Comments deleted → Post restored → only auto-deleted Comments restored
    - Multiple delete/restore cycles on same Post
    - Comment on a different post remains unaffected

Follow a rigorous agentic process:

1. Plan thoroughly: Draw the exact strategy (which callbacks? which scopes? how to distinguish "cascaded" delete from manual delete? Hint: you need one extra column somewhere).
2. Write ALL code changes precisely:
    - Migration(s) to add column(s)
    - Model changes (Post, Comment)
    - Any concern/module if used
3. Show the exact migration file content
4. After implementing, simulate and verify agentically:
    - Create Post + 3 Comments
    - Soft-delete Post → prove Comments are deleted and not findable via default scope
    - Restore Post → prove exactly those 3 Comments are restored, but if you had manually deleted a 4th Comment before, it stays deleted
    - Run rails console snippets showing .count, .with_deleted if you add paranoid-like scope, logs, etc.
    - Attempt to prove no N+1 via bullet gem simulation or explain why your solution avoids it
5. If any part would fail (loop, wrong records touched, perf issue), debug, adjust column/callback strategy, and re-verify until perfect.

There is one elegant solution using one extra boolean/timestamp column + carefully placed before/after callbacks + update_all in transaction. Do not use acts_as_paranoid / paranoia gem logic directly — implement manually.

Begin now. Think step-by-step, show planning first, then exact code, then verification.