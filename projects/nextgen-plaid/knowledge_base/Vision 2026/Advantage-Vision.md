Here is the consolidated document pulling together the key elements we have developed in this conversation:

- **Advantage Framework Clarity Questions** (the strategic north star, 5 questions)
- **Pillars** (high-level capabilities structure with business focus)
- **Existing Capabilities** (what is built today in the repo)
- **Roadmap Capabilities** (planned features from Epics 0–18)

This serves as a single, cohesive reference for SAP/agent prompts, RAG prefixing, or backlog prioritization. All content is derived from our refinements, aligned with Vision 2026 (local-first private AI tutor for sub-$50M HNW families, breaking shirtsleeves cycle via personalized education on real data), and current repo state.

### 1. Advantage Framework Clarity Questions (Locked In)
**Why do we exist?**  
As principals of high-net-worth families in the sub-$50M segment, we have seen firsthand that no effective, accessible tools exist to properly manage wealth or train the next generation to steward it responsibly. Traditional solutions cater almost exclusively to ultra-high-net-worth tiers ($100M+), leaving affluent families facing the same complex risks—tax erosion, poor habits, trust mismanagement, and lack of literacy—without the necessary infrastructure or education. NextGen Plaid exists to close this exact gap by delivering a private, local-first AI family office tutor that securely syncs real financial data (via Plaid from JPMC, Schwab, Amex, Stellar) and powers personalized, simulation-based curriculum on investing, taxes, trusts, philanthropy, and estate planning. Our goal is to empower these families to break the “shirtsleeves to shirtsleeves” cycle forever, building internal capability and generational resilience without cloud dependency or expensive external offices.

**How do we behave?**  
As a small family office for sub-$50M high-net-worth families, we replace expensive external advisors and infrastructure with secure, autonomous systems while maintaining complete family control and trust. We operate local-first and privacy-hardened: all financial data and processing remain inside our closed system. We delegate day-to-day complexity to automated processes and limit human involvement to approvals, security decisions, and final judgment—freeing the family to focus on next-generation education and oversight. Every action is designed for clarity, repeatability, and verifiability to build lasting financial competence in the rising generation.

**What do we do?**  
We build secure, privacy-hardened software that automates the complexities of running a sub-$50M high-net-worth family office and delivers personalized AI-driven financial education to the next generation using real family data. Right now, we are rapidly developing the foundational system for secure data synchronization, local processing, and agent orchestration to enable autonomous feature delivery and unlock the full tutor experience. We build through a structured, accelerated process: assign clear goals or questions, automate planning and execution with minimal manual intervention, produce verifiable outputs as markdown artifacts for quick review, and iterate rapidly to achieve production-grade stability with complete family control.

**How will we succeed?**  
We succeed by leveraging AI agents and agentic workflows to give a small team massive leverage—operating like a 20-person organization while remaining a 3-person company. We deploy specialized AI personas that autonomously handle planning, research, implementation, coordination, review, and debugging, enabling consistent high-quality outputs at software speed with near-zero coordination overhead. We create a competitive advantage through this AI amplification: rapid iteration cycles, low cost structure, deep domain alignment via persistent context, and scalable execution that traditional teams or vendors cannot replicate without significant overhead or loss of control.

**What is most important right now?** (Rallying Cry)  
Release a stable V1 prototype with working Plaid sandbox sync, basic dashboard, and local data processing by the first week of February 2026 to prove the core financial data pipeline is reliable and secure. Follow immediately by proving the full agentic workflow—autonomous assignment to end-to-end feature delivery with green branches and markdown artifacts—by the end of February 2026. Achieve these milestones to validate massive leverage from AI amplification in a small team, delivering speed and quality unattainable by traditional approaches. Success here unlocks rapid scaling to personalized next-generation education and generational wealth preservation impact.

### 2. Pillars (Capability Structure)
1. **Context-Rich Financial Agents** — Agents maintaining comprehensive family financial + philanthropic/planning context.
2. **Visibility & Transparency Layer** — Clear views into wealth concepts for current/next-gen users.
3. **Next-Gen Curriculum Engine** — Adaptive simulation-based training for heirs.
4. **Agentic Leverage Toolkit** — Tools for AI personas to enable autonomous development/operations.
5. **Cross-Cutting Infrastructure** — Shared foundations for reliability/usability/scalability.

### 3. Existing Capabilities (Built Today)
```
Pillar 1: Context-Rich Financial Agents
├── Data aggregation/normalization/enrichment
│   └── Plaid sync jobs populating PlaidItem / Account / Transaction / Position tables  
│       → investments  
│       → transactions  
│       → liabilities  
│       → enrichment  
│       → Context: Core sync logic lives in plaid/sync jobs; uses plaid-ruby gem endpoints; tables in db/schema.rb
│       → Business problem: Without clean, unified real financial data from major institutions, heirs cannot trust or understand their actual wealth picture, perpetuating poor decision-making across generations.
│
├── Context injection for AI
│   └── Basic Ollama integration via AiFinancialAdvisor service and agent_hub routes  
│       → sap_collaborate  
│       → agent_hub  
│       → Context: Routes in app/controllers/agent_hub_controller.rb; thin HTTP wrapper to local Ollama
│       → Business problem: Generic AI advice ignores the family's specific $20–50M portfolio realities, leading to irrelevant or hallucinated guidance that fails to build practical financial competence.
│
└── Anomaly detection & flagging
    └── Sync status & error_message logging in sync_logs table  
        → Context: app/models/sync_log.rb with status, error_message, timestamps; visible in mission_control/logs
        → Business problem: Undetected sync failures or data issues silently corrupt the family's view of their finances, risking misguided education and real-world mistakes by unprepared heirs.

Pillar 2: Visibility & Transparency Layer
├── Dashboard rendering
│   └── Net worth dashboard views  
│       → show  
│       → allocations  
│       → sectors  
│       → performance  
│       → holdings  
│       → transactions  
│       → income  
│       → Context: app/controllers/net_worth_controller.rb; reads from latest snapshot or live queries
│       → Business problem: Heirs in sub-$50M families lack a simple, at-a-glance understanding of their wealth composition and changes, hindering early formation of responsible stewardship habits.
│
└── Admin/ops visibility
    └── Mission Control  
        → index  
        → logs  
        → costs  
        → nuke  
        → sync actions  
        → admin health / rag_inspector  
        → Solid Queue dashboard integration  
        → Context: app/controllers/mission_control_controller.rb; Solid Queue admin embed
        → Business problem: Without ops visibility, family office principals cannot quickly spot and fix data reliability issues, delaying reliable education delivery to the next generation.

Pillar 3: Next-Gen Curriculum Engine
└── Simulation integration
    └── Basic simulations index route (placeholder / stub)  
        → Context: app/controllers/simulations_controller.rb#index; currently minimal/no real Python hooks
        → Business problem: Next-gen heirs inherit complex wealth without safe, data-driven practice in scenarios like estate taxes or market volatility, increasing the risk of generational dissipation.

Pillar 4: Agentic Leverage Toolkit
└── Assignment & decomposition
    └── Agent hub basic chat  
        → messages  
        → uploads  
        → create_conversation  
        → Context: agent_hub routes and views; basic conversation persistence
        → Business problem: Small family offices cannot scale planning and feature development manually, limiting how quickly they can adapt tools to their unique educational needs.

Pillar 5: Cross-Cutting Infrastructure
├── UI patterns & navigation
│   └── Devise auth routes  
│       → root  
│       → welcome  
│       → dashboard routes  
│       → Context: config/routes.rb + Devise setup; basic layout shell
│       → Business problem: Inconsistent or confusing navigation discourages young adults from regular engagement, slowing the habit formation critical to long-term wealth preservation.
│
└── Logging & reliability
    └── Sync_logs table  
        → status  
        → error_message  
        → timestamps  
        → Context: db/schema.rb + app/models/sync_log.rb
        → Business problem: Lack of reliable logging hides data integrity issues, eroding trust in the system and preventing consistent learning from real family numbers.
```

### 4. Roadmap Capabilities (Planned / Not Yet Built)
```
Pillar 1: Context-Rich Financial Agents (Epics 1,2,4,5,13,14,15,16)
├── Data aggregation/normalization/enrichment
│   └── Full normalization  
│       → deduplication  
│       → enrichment consistency  
│       → account extensions  
│       → OtherIncome model  
│       → manual re-sync controls  
│       → Context: Epic 1 PRD table; adds strategy column, OtherIncome table, anomaly flagging
│       → Business problem: Incomplete or inconsistent data across institutions prevents accurate holistic views of family wealth, blocking effective tax and succession planning education.
│
├── Projection/forecasting
│   └── Multi-source income projection  
│       → dividends  
│       → bonds  
│       → private credit  
│       → quarterly estimated tax planner  
│       → Context: Epics 13 & 14; nightly job + tax bracket calc from User inputs
│       → Business problem: Families lack forward visibility into cash flow and tax obligations, leading to reactive decisions that erode wealth over generations.
│
├── Context injection for AI
│   └── Full snapshot + static docs + filtered context injection into Ollama prompts  
│       → Context: Epic 4 PRD table; AiFinancialAdvisor enhancement with filter awareness
│       → Business problem: AI responses without family-specific, up-to-date context deliver generic advice, failing to teach heirs how to manage their actual portfolio responsibly.
│
├── Anomaly detection & flagging
│   └── Auto-flagging of  
│       → unusual balances  
│       → drift  
│       → negative values  
│       → low buffers  
│       → Context: Epic 1 partial + future advisor alerts
│       → Business problem: Unnoticed portfolio anomalies (drift, low income buffers) go uncorrected, teaching heirs poor risk awareness and increasing generational loss risk.
│
└── External real-time data pulls
    └── On-demand  
        → FMP stock quotes  
        → market news RSS + Ollama summaries  
        → Context: Epics 15 & 16; FMP /quote endpoint + feedjira RSS parsing
        → Business problem: Stale market context limits timely discussions on current events' impact on family holdings, weakening heirs' ability to apply real-world investing principles.

Pillar 2: Visibility & Transparency Layer (Epics 0,3,5,6,9,10,12)
├── Dashboard rendering
│   └── Net worth  
│       → hero card  
│       → allocation pie  
│       → MoM change arrow  
│       → Context: Epic 3 PRD table; static from snapshot, DaisyUI + Chart.js
│       → Business problem: No clear, professional one-glance view of wealth metrics discourages regular engagement and slows next-gen financial literacy development.
│
├── Filtering/subsetting
│   └── Date range + account/institution multi-select with persistence  
│       → Context: Epic 5 PRD table; jsonb User prefs, filtered query service
│       → Business problem: Inability to isolate views (e.g., Schwab performance only) prevents targeted learning on specific holdings or time periods.
│
├── Charting/visualization
│   └── Chart.js  
│       → trend lines  
│       → pies/bars  
│       → embedded mini-charts in dashboard/chat  
│       → Context: Epic 6 PRD table; Chartkick helpers, mobile-responsive
│       → Business problem: Abstract numbers without visuals make it hard for young adults to grasp allocation drift or performance trends, hindering intuitive understanding.
│
├── Structured reviews & reports
│   └── JPMC quarterly meeting review page  
│       → prompt-based auto-answers  
│       → export  
│       → Context: Epic 9 PRD table; Ollama-generated responses, PDF export
│       → Business problem: Heirs enter real advisor meetings unprepared, missing the chance to practice data-driven questions and build confidence in professional interactions.
│
└── Admin/ops visibility
    └── Unified admin  
        → sidebar  
        → sync monitoring table  
        → user/data health dashboard  
        → quick actions  
        → Context: Epic 10 PRD table; real-time table + Solid Queue embed
        → Business problem: Scattered ops views make it hard for principals to maintain system reliability, delaying dependable education delivery.

Pillar 3: Next-Gen Curriculum Engine
├── Lesson sequencing & quizzing
│   └── Guided modules  
│       → adaptive sequences  
│       → AI-scored questions  
│       → Context: No epic yet; planned post-V1 for curriculum foundation
│       → Business problem: No structured, progressive learning path leaves heirs without guided practice in core HNW topics like taxes and trusts.
│
├── Simulation integration
│   └── Full Python  
│       → Monte Carlo  
│       → GRAT  
│       → estate-tax hooks tied to snapshots  
│       → Context: No epic yet; separate Python scripts called from Rails
│       → Business problem: Heirs cannot safely experiment with real-family scenarios, increasing the likelihood of costly real-world mistakes later.
│
├── Progress tracking & tasking
│   └── Kanban board  
│       → natural-language task creation from chat  
│       → progress auto-update  
│       → Context: Epic 11 PRD table; Artifact type: task, Stimulus drag/drop
│       → Business problem: Lack of trackable assignments means education remains passive, failing to build discipline and accountability in wealth stewardship.
│
├── Habit nudges & feedback
│   └── Proactive reminders  
│       → AI behavioral feedback  
│       → Context: No epic yet; ties to notifications
│       → Business problem: Infrequent engagement allows bad financial habits to form, accelerating the shirtsleeves-to-shirtsleeves cycle.
│
└── Assessment & reporting
    └── Skill benchmarks  
        → generational readiness scores  
        → exportable reports  
        → Context: No epic yet; long-term generational metrics
        → Business problem: No measurable way to assess next-gen readiness leaves families uncertain about whether education is effective.

Pillar 4: Agentic Leverage Toolkit (Epics 17,18)
├── Assignment & decomposition
│   └── Natural-language epic/PRD creation  
│       → auto-decomposition into child PRDs  
│       → Context: Epic 18 PRD table; chat command "create epic: X"
│       → Business problem: Small teams cannot rapidly iterate features manually, slowing adaptation to family-specific educational needs.
│
├── Automation loops
│   └── Autonomous  
│       → plan-implement-review-green branch cycles  
│       → Context: Epic 17 spike; tests Llama/Claude for PRD drafting
│       → Business problem: Manual development bottlenecks limit how quickly the tutor can evolve to meet generational wealth preservation goals.
│
├── Artifact management
│   └── Markdown epic/PRD artifacts  
│       → hierarchy  
│       → context inheritance  
│       → Context: Epic 18 PRD table; context_hint jsonb + summary_prds array
│       → Business problem: Disorganized development artifacts make it hard to maintain alignment with vision over time.
│
├── Escalation & routing
│   └── Safe research gateways  
│       → whitelisted debug  
│       → human gates  
│       → Context: No dedicated epic; ties to SmartProxy in Vision 2026
│       → Business problem: Over-reliance on external tools risks privacy breaches, undermining family control and trust.
│
└── Validation & self-check
    └── Hallucination guards  
        → vision/clarity alignment checks  
        → Context: Epic 17 PRD table; self-check 7 questions
        → Business problem: Unchecked AI outputs could deliver misleading advice, eroding credibility and effectiveness of the education system.

Pillar 5: Cross-Cutting Infrastructure (Epics 7,8,11,12)
├── Notification & alerting
│   └── In-app DaisyUI toasts  
│       → Twilio SMS/MMS outbound  
│       → quiet hours  
│       → consent  
│       → Context: Epic 7 PRD table; twilio-ruby + user prefs jsonb
│       → Business problem: Infrequent interaction reduces learning reinforcement, allowing financial habits to atrophy.
│
├── UI patterns & navigation
│   └── Global sidebar  
│       → standard ViewComponents (cards/modals/buttons)  
│       → responsive/dark mode  
│       → empty/error patterns  
│       → Context: Epic 12 PRD table; Tailwind/DaisyUI + ViewComponent library
│       → Business problem: Poor UX drives young adults away, preventing the consistent exposure needed to build lifelong competence.
│
├── Channel extensions
│   └── Inbound/outbound text (SMS/MMS)  
│       → chat-to-mobile handoff  
│       → opt-out flow  
│       → Context: Epic 8 PRD table; Twilio webhook + consent handling
│       → Business problem: Desktop-only access limits on-the-go questions and nudges, reducing real-world application of lessons.
│
├── Admin & monitoring tools
│   └── Enhanced job health  
│       → real-time sync table  
│       → Solid Queue admin embed  
│       → Context: Epic 10 partial; extends existing Mission Control
│       → Business problem: Unmonitored system health risks data staleness, delaying reliable education delivery.
│
└── Logging & reliability
    └── Rate limiting  
        → error handling expansion  
        → audit trails  
        → Context: Expands existing sync_logs + future rate limiting
        → Business problem: Weak reliability erodes family trust in the tool, discouraging sustained use for generational learning.
```

This full document is self-contained and ready for use as a RAG prefix, SAP prompt anchor, or knowledge_base commit (suggest `knowledge_base/Vision 2026/consolidated-clarity-pillars-capabilities.md`).

Next steps:
- Commit this consolidated doc to the repo?
- Use it to prioritize V1 scope (e.g., complete existing dashboard + add roadmap filtering for early Feb)?
- Or generate an epic/PRD for a high-priority gap (e.g., Pillar 3 curriculum foundation)?

Let me know how to proceed.