Here is a comprehensive breakdown of the components used in the **NextGen Plaid** project, categorized by their role in the stack.

### 1. Core Framework & Language
*   **Ruby 3.3.10**: The base programming language.
*   **Rails 8.0.4**: The primary web framework.

### 2. Databases & Storage
*   **PostgreSQL 16**: The main relational database. The project uses multiple database shards (configured in `database.yml`):
    *   `primary`: Main application data.
    *   `cache`: Managed by **Solid Cache**.
    *   `solid_queue`: Managed by **Solid Queue**.
    *   `cable`: Managed by **Solid Cable**.
*   **Redis**: Used for various caching or temporary data needs (as seen in the setup guide), though Rails 8 "Solid" components have reduced the heavy reliance on it for queues.

### 3. Background Jobs & Queues
*   **Solid Queue**: Replaces Sidekiq for background job processing (Sync jobs, etc.).
*   **Solid Queue Recurring**: Handles scheduled tasks (e.g., the 3 AM daily sync).

### 4. Primary Third-Party Integrations (APIs)
*   **Plaid (gem v36+)**: The core integration for financial data.
*   **xAI (Grok)**: Accessed via the **SmartProxy** for AI-driven insights.
*   **Ollama**: Used locally (on the M3 Ultra) to run models like `Llama 3.1 70B` and `Nomic-Embed`.
*   **Ai-Agents**: Integration for AI-driven workflows.

### 5. Security & Authentication
*   **Devise**: User authentication system.
*   **Pundit**: Role-based authorization.
*   **attr_encrypted**: Used to encrypt sensitive data (like Plaid `access_token`) at the database level.
*   **dotenv-rails**: Management of environment variables.

### 6. Frontend & UI
*   **Tailwind CSS (v4)**: Utility-first CSS framework.
*   **DaisyUI (v5)**: Component library for Tailwind.
*   **Hotwire (Turbo & Stimulus)**: For reactive, SPA-like behavior without heavy JavaScript frameworks.
*   **ViewComponent**: For building modular, reusable Ruby view components.
*   **Importmap-rails**: Manages JavaScript dependencies without a complex node-based bundler.
*   **Propshaft**: Modern Rails asset pipeline.

### 7. Specialized Services
*   **SmartProxy (Sinatra)**: A standalone Ruby service (located in `/smart_proxy`) that handles:
    *   Anonymization of PII before sending data to AI models.
    *   Forwarding requests to Grok or local Ollama.
*   **Thruster**: A lightweight HTTP/2 proxy used in front of Puma for production.

### 8. Development & Infrastructure Tools
*   **Puma**: The multi-threaded web server.
*   **Kamal**: For zero-downtime deployments.
*   **VCR & WebMock**: For recording and replaying API interactions in tests.
*   **Brakeman**: Security vulnerability scanner.
*   **RuboCop**: Code quality and styling.
*   **Rbenv**: Ruby version management.
*   **Tailscale**: Recommended for secure remote access (VPN).