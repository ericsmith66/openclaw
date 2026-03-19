Here is the updated **Business Problem → Capability** outline with the requested refinements:

- **Capabilities indented** under each business problem (nested list format for clarity).
- **Existing vs Future** clearly marked next to each capability (Existing = built today in repo; Future = roadmap/planned from Epics 0–18).
- Multiple capabilities per business problem where appropriate.
- Kept concise and aligned with pillars.

### Pillar 1 – Context-Rich Financial Agents

- Without clean, unified, trustworthy financial data from major institutions, heirs cannot form an accurate picture of their actual wealth
    - [Existing] As a family member / intern I can view a clean list of positions, transactions, liabilities and income sources coming from all linked accounts
    - [Future] As a family member / intern I can see fully normalized, deduplicated, consistently enriched data with manual override & re-sync controls

- Generic AI advice that is not anchored in the family’s actual portfolio, income, taxes and goals produces irrelevant or dangerous recommendations
    - [Existing] As a family member / intern I can ask the AI advisor questions and receive answers that are grounded in the latest real snapshot of my family’s financial data
    - [Future] As a family member / intern I can ask questions that are answered using the filtered snapshot + my selected time period + my selected accounts

- Silent data quality issues (sync failures, missing fields, anomalies) corrupt the entire education system
    - [Existing] As an admin / principal I can see which syncs failed and what error messages were recorded
    - [Future] As a family member / intern I can see clear visual warnings when important data is missing / stale / anomalous

- Families do not know what tomorrow’s cash flow or tax bill might look like → reactive planning & unnecessary wealth erosion
    - [Future] As a family member / intern I can see projected monthly income broken down by source (dividends / bonds / private credit)
    - [Future] As a family member / intern I can see estimated quarterly tax payments based on current income run-rate

- Heirs have no real-time market context → cannot connect news or price movements to their own holdings
    - [Future] As a family member / intern I can ask for the current live price of any of my holdings
    - [Future] As a family member / intern I can see a concise one-sentence summary of current market news that is relevant to my portfolio

### Pillar 2 – Visibility & Transparency Layer

- Young adults do not regularly look at their family wealth because there is no simple professional one-glance view
    - [Existing] As a family member / intern I can open the dashboard and immediately see my current net worth + top holdings + allocation overview
    - [Future] As a family member / intern I can see a beautiful professional hero card with MoM change arrow + clean allocation pie

- It is hard to focus learning on one institution / one time period / one asset class
    - [Future] As a family member / intern I can filter the entire dashboard & chat experience to show only one institution / one date range / one or more specific accounts

- Numbers alone do not help young people intuitively understand trends, concentration risk or drift
    - [Future] As a family member / intern I can see trend lines of my net worth
    - [Future] As a family member / intern I can see visual allocation pies/bars
    - [Future] As a family member / intern I can see mini-charts embedded directly in chat answers

- Heirs walk into real advisor/banker meetings unprepared
    - [Future] As a family member / intern I can open a structured quarterly review page for JPMC / Schwab / Amex that is pre-filled with my real numbers and suggested talking points

### Pillar 3 – Next-Gen Curriculum Engine

- There is no guided, progressive path to learn core HNW topics
    - [Future] As a family member / intern I can follow guided lesson sequences that adapt to my progress
    - [Future] As a family member / intern I can take AI-scored quizzes that use my real portfolio numbers

- Heirs cannot safely “play” with real-family scenarios
    - [Future] As a family member / intern I can run Monte Carlo simulations using my actual holdings
    - [Future] As a family member / intern I can model GRATs and estate-tax scenarios with my real numbers

- Learning remains theoretical and forgettable – no accountability
    - [Future] As a family member / intern I can receive learning tasks directly in chat
    - [Future] As a family member / intern I can track my curriculum progress on a personal Kanban board

- Infrequent contact allows bad habits to form and good ones to fade
    - [Future] As a family member / intern I can receive gentle proactive nudges when my financial behavior drifts

- Families have no objective way to measure whether the next generation is becoming competent
    - [Future] As a parent / principal I can view objective skill benchmarks and readiness scores for each child
    - [Future] As a parent / principal I can export progress reports showing generational readiness

### Pillar 4 – Agentic Leverage Toolkit

- A 3-person family office cannot quickly iterate features and curriculum without massive external help
    - [Future] As a product owner / principal I can describe a feature in natural language and receive decomposed epics + atomic PRDs
    - [Future] As a product owner / principal I can watch an autonomous agent loop that plans → codes → tests → produces a green branch

- Development artifacts are scattered and lose context over time
    - [Future] As a product owner / principal I can see clean hierarchical markdown artifacts (epics → PRDs) that inherit the vision context

### Pillar 5 – Cross-Cutting Infrastructure

- Young adults engage sporadically → weak reinforcement
    - [Future] As a family member / intern I can receive quick in-app toasts when something important happens
    - [Future] As a family member / intern I can receive optional SMS/MMS alerts and quick answers on my phone

- Poor or inconsistent UX causes young users to bounce
    - [Future] As a family member / intern I can use a consistent professional mobile-first interface everywhere in the app

- Education is limited to desktop sessions
    - [Future] As a family member / intern I can ask quick questions and get answers via text / MMS from my phone

- System health issues are invisible → data becomes stale
    - [Existing] As an admin / principal I can see which syncs failed and read the error messages
    - [Future] As an admin / principal I can monitor real-time sync status + job health + data quality from one unified screen

This outline is now ready to be used in prompts or committed to the knowledge base.

Next steps / your preference:
- Commit as `knowledge_base/Vision 2026/business-problems-capabilities.md`?
- Prioritize 5–7 capabilities for V1 (early Feb release) based on this mapping?
- Or select one business problem / capability and generate the first atomic epic + PRD table?

Let me know.