##AI-disruption-monitor##
Here is the full document compiling **all the prompts we built and discussed** throughout the conversation. This includes the original separate prompts, the combined version, and the evolutions we iterated on (fact-based, no drama, with sources specified).

### AI Disruption Analysis Prompts Document

#### Version 1: Original Three Separate Prompts
These were the first set you asked for.

1. **Positive case prompt**  
   "You are an economist analyzing AI's impact. Using only data from BLS, OECD, PwC, McKinsey, World Bank, and official government reports published 2023–2026, build a trend line for the positive case: AI as productivity booster without net job loss. Include:
- U.S. non-farm productivity growth (quarterly, 2023–Q4 2025)
- Job growth in AI-exposed sectors (BLS projections to 2033)
- Consumer spending contribution to GDP (2024–2025)
- Wage growth in middle-skill roles outside tech
- AI adoption rates in small businesses (Thryv, McKinsey surveys)  
  Show quarterly or annual changes, no forecasts beyond published projections. Output as a table + one-paragraph summary."

2. **Negative case prompt**  
   "You are an economist analyzing AI's impact. Using only data from BLS, OECD, PwC, McKinsey, World Bank, Layoffs.fyi, and official reports 2023–2026, build a trend line for the negative case: AI as displacement driver. Include:
- AI-linked layoffs (U.S., 2024–2025 totals)
- Job postings decline in AI-exposed roles (LinkedIn, Indeed data)
- Wage growth stagnation in middle-skill occupations (BLS hourly earnings)
- Electricity price increases tied to data centers (EIA, 2024–2025)
- Worker anxiety metrics (Mercer, Gallup surveys)  
  Show quarterly or annual changes, no forecasts beyond published projections. Output as a table + one-paragraph summary."

3. **Early-warning threshold prompt**  
   "You are an economist building an early-warning system for AI disruption. Using only published data from BLS, OECD, PwC, McKinsey, World Bank, Epoch AI, and government sources 2023–2026, define a three-level alert scale:
- Green: stable (unemployment <4.5%, productivity >2% annual, non-tech job growth >1%)
- Yellow: pressure (unemployment 4.5–5.5%, middle-skill wage growth <2%, AI layoffs >100k/year)
- Red: threshold crossed (unemployment >5.5%, productivity flat or negative, AI adoption >80% in large firms)  
  Track these metrics from Q1 2025 to latest available. Output current status, trend direction, and data sources. No narrative—just numbers and levels."

#### Version 2: Combined + Expanded Single Prompt (with Fear Index + Suicide Demographics)
This merged everything into one runnable prompt.

**Combined Prompt (Positive/Negative/Early-Warning + Fear + Suicide)**  
"You are an economist analyzing AI's societal impact using only published data from BLS, OECD, PwC, McKinsey, World Bank, Layoffs.fyi, Mercer, Gallup, Reuters/Ipsos, CDC, and official government reports 2023–2026. Build three trend lines:

1. **Positive case** (AI as productivity booster): include U.S. non-farm productivity growth, job growth in AI-exposed sectors (BLS projections to 2033), consumer spending contribution to GDP, wage growth in middle-skill roles outside tech, AI adoption rates in small businesses.

2. **Negative case** (AI as displacement driver): include AI-linked layoffs totals, job postings decline in AI-exposed roles, wage growth stagnation in middle-skill occupations, electricity price increases tied to data centers, worker anxiety metrics (Mercer/Gallup).

3. **Early-warning threshold**: define a three-level alert scale (Green: unemployment <4.5%, productivity >2% annual, non-tech job growth >1%; Yellow: unemployment 4.5–5.5%, middle-skill wage growth <2%, AI layoffs >100k/year; Red: unemployment >5.5%, productivity flat/negative, AI adoption >80% in large firms). Track Q1 2025 to latest.

Add a fourth section: **Fear index** (AI job anxiety)—use Mercer, Gallup, Reuters/Ipsos surveys on percentage of workers fearing permanent displacement or job security loss, with year-over-year changes.

Add a fifth section: **Suicide rates by age group**—use CDC provisional/final data (2023–2024 or latest), report age-adjusted rates and percentage changes for 15–24, 25–34, 35–44, and 45+ groups.

Output: tables for each trend, current status for early-warning, and one-paragraph summary per section. No forecasts, no narrative—just numbers, sources, and levels."

#### Version 3: Prompts with Normalized Scores (1–100)
We later added scoring to each section. You can append this line to any of the above prompts:  
"Add a normalized score 1–100 for each section at the end (100 = strongest signal in that direction; 0 = opposite/no signal)."

Example scores we generated (for reference, from Feb 2026 runs):
- Positive: 68/100
- Negative: 32/100
- Early-warning: 22/100
- Fear index: 45/100
- Suicide demographics: 18/100

Historical (12 months prior):
- Positive: 72/100
- Negative: 18/100
- Early-warning: 12/100
- Fear: 28/100
- Suicide: 25/100

Projected end-2026 (trend extrapolation):
- Positive: 65/100
- Negative: 38/100
- Early-warning: 28/100
- Fear: 52/100
- Suicide: 15/100

#### Additional Layer Prompts (Financial & Acceleration)
**Financial layer (with MAG-7)**  
"Using only published financial data 2025–2026 (company filings, Bloomberg, S&P, EIA), produce a 1–100 score for AI financial concentration in MAG-7 (Amazon, Meta, Microsoft, Google, Nvidia, Apple, Tesla): track capex totals, combined market caps, data-center electricity impact. 100 = extreme concentration (> $600B capex + >$4T combined cap). Output table + score."

**Financial layer (without MAG-7)**  
Same as above but "for non-MAG-7 AI players (Oracle, AMD, Broadcom, etc.)—score reflects fragmented/lower scale."

**AI Acceleration / Singularity Proxy**  
"You are tracking AI scaling laws using only Epoch AI, METR, OpenAI, DeepMind published benchmarks 2023–2026. Produce a 1–100 acceleration score based on: frontier compute FLOPs/year, % saturation on MMLU/GPQA/SWE-Bench, training efficiency (params vs. gain), inference tokens/second on consumer hardware. Thresholds: 100 = multiple 95%+ benchmarks + compute doubling <6 months. Output table + score."

This covers every prompt variant we built—from the initial three, through the combined, scored, and layered versions. Copy-paste any of these directly into models like Claude, Gemini, or me for daily runs. Let me know if you want one expanded into full script-ready format (e.g., with exact output JSON structure).
## Epic and PRDS ##

Here is the full **Product Requirements Document-style compilation** I provided earlier in our conversation, exactly as it was shared (the consolidated Epic + the 10 atomic PRDs in their final form):

### Epic: AI Disruption Monitoring System

As a researcher monitoring AI's societal, economic, financial, political, and acceleration impacts,  
I want a modular, atomic suite of ten daily (or quarterly) standalone trackers—each focused on one specific score layer or quality function—  
so that I can run them independently with multiple consumer AI models, capture immutable timestamped raw metrics, generate daily snapshots, compare historical trends, forecast deviations, critique hallucinations/bias, and maintain architectural oversight, all without building a monolithic application.

**Key outcomes**
- 10 atomic PRDs, each <1 page, self-contained, runnable standalone
- Daily multi-model execution (Gemini, Claude, GPT, Grok, etc.) for score variance
- Append-only archive of immutable raw metrics (metric name, value, source URL + fetch date, timestamp)
- Historical snapshot comparison + future-look deviation flagging
- Built-in daily hallucination/fact-check layer
- Quarterly architectural health audit
- Output format: JSON/CSV per run (no UI required)

**Acceptance criteria**
- Each PRD produces: normalized 1–100 score + immutable raw metrics table
- Critique PRD runs last each day and verifies all prior outputs
- Architectural PRD runs quarterly and documents the whole system
- No inter-PRD runtime dependencies (loose coupling via shared archive)
- Immutable data rows are never edited after creation

### The 10 Atomic PRDs (one-sentence summaries)

1. **Daily Positive Trend Snapshot**  
   Produces the positive-case 1–100 score and immutable table tracking non-farm productivity, AI-exposed job growth, consumer GDP contribution, middle-skill wages outside tech, and small-business AI adoption.

2. **Daily Negative Trend Snapshot**  
   Produces the negative-case 1–100 score and immutable table tracking AI-linked layoffs, job postings decline in exposed roles, middle-skill wage stagnation, data-center electricity price increases, and worker anxiety metrics.

3. **Daily Early-Warning Snapshot**  
   Produces the early-warning 1–100 score (Green/Yellow/Red levels) and immutable table tracking unemployment (U-3 & U-6), productivity, non-tech job growth, and annual AI layoffs.

4. **Daily Fear Index Snapshot**  
   Produces the fear-index 1–100 score and immutable table capturing percentage of workers fearing AI job displacement or security loss from Mercer, Gallup, Reuters/Ipsos surveys with year-over-year changes.

5. **Daily Suicide Demographics Snapshot**  
   Produces the suicide-demographics 1–100 score (lower = declining concern) and immutable table logging CDC age-adjusted suicide rates and percentage changes for age groups 15–24, 25–34, 35–44, and 45+.

6. **Daily Financial-with-MAG7 Snapshot**  
   Produces the financial-with-MAG7 1–100 score and immutable table tracking capex, combined market caps, and electricity impact specifically for Amazon, Meta, Microsoft, Google/Alphabet, Nvidia, Apple, Tesla.

7. **Daily Financial-without-MAG7 Snapshot**  
   Produces the financial-without-MAG7 1–100 score and immutable table tracking the same capex/market/electricity metrics but only for non-MAG7 AI players (Oracle, AMD, Broadcom, hyperscalers outside MAG7, etc.).

8. **Daily AI Acceleration Snapshot**  
   Produces the AI-acceleration 1–100 score (proxy toward singularity) and immutable table tracking frontier-model compute FLOPs/year, benchmark saturation (MMLU/GPQA/SWE-Bench), training efficiency, and inference tokens/second.

9. **Daily Critique & Hallucination Checker**  
   Scans yesterday’s outputs from PRDs 1–8, produces a verification table flagging fact mismatches/hallucinations/bias, confirms immutable metric integrity, and suggests one-line fixes; runs last each day.

10. **Quarterly Architectural Analysis**  
    Audits dependencies, shared data sources, pipeline latency, redundancies, failure points, scaling risks, and model/API health across all nine daily PRDs; produces a summary report every three months.

That's the complete version from our earlier exchange. Let me know if you want any part expanded, formatted differently (e.g., Markdown sections, bullet points for criteria), or if you'd like the older versions (e.g., the three original separate prompts) included as well.

## Architectural Overview ##
Understood—the AI Disruption Monitoring System Epic and its 10 atomic PRDs (including PRD 0) need to live inside the **nextgen-plaid** Rails application stack, not as a separate Python-only project. This shifts the architecture to leverage Rails strengths (MVC, background jobs, PostgreSQL, existing encryption/auth) while still achieving modularity, immutability, and daily/quarterly execution.

**Revised Architectural Approach (for PRD 0 update)**  
We'll adapt the system to fit nextgen-plaid's Rails 8.0+ environment:

- **Core Implementation**: Ruby/Rails services + rake tasks or Solid Queue jobs (since the repo already uses Solid Queue for background syncs). No new external Python repo—keep everything in one monorepo for consistency with Plaid sync logic, user auth, and encryption patterns.
- **Daily/Quarterly Execution**:
    - Use Rails rake tasks (e.g., `rails ai_disruption:daily_positive`) runnable via cron or Solid Queue recurring jobs.
    - Each PRD becomes a focused Service class (e.g., `AiDisruption::PositiveTrendService`) under `app/services/ai_disruption/`.
    - Shared append-only storage: PostgreSQL table `ai_disruption_snapshots` (immutable via triggers or app-level enforcement—no updates/deletes allowed post-create).
- **Multi-LLM Calls**:
    - Leverage existing local Ollama integration (AiFinancialAdvisor service pattern) as primary/default (Claude Sonnet 4.5 via Anthropic API if API key configured, fallback to local Llama 3.1).
    - Add thin wrappers for external APIs (Gemini, Grok/xAI, OpenAI) in `lib/llm_clients/`—store keys in encrypted credentials.
    - Parallel or sequential calls for variance, store raw responses.
- **Data Fetching**:
    - Use `HTTParty` or `Faraday` (add to Gemfile if needed) for BLS/OECD/etc. APIs or CSV downloads.
    - Cache fetches daily in `Rails.cache` (short TTL) to reduce external calls.
- **Immutability & Archive**:
    - Model: `AiDisruptionSnapshot` (columns: run_at:datetime, metric_type:string, llm_model:string, score:integer, raw_json:jsonb, sources:jsonb, checksum:string).
    - Enforce append-only: `before_save :prevent_update_if_persisted`, raise on update/delete attempts.
    - Checksum (SHA256 of content) for integrity.
- **Critique & Quarterly**:
    - `AiDisruption::CritiqueService` runs after dailies (via job chain or manual trigger).
    - Quarterly: `AiDisruption::ArchitecturalAuditJob` (scheduled).
- **Output**:
    - JSON export per run to `storage/ai_disruption/` (or S3 later), plus console/ log output.
    - Optional: Admin view in Mission Control dashboard (defer until core stable).
- **Configuration**:
    - Add to `config/credentials.yml.enc`: LLM API keys, allowed sources.
    - `config/ai_disruption.yml` for thresholds, prompts (load from knowledge_base or inline).
- **Prompts Integration**:
    - Store the full AI Disruption Analysis Prompts Document in `knowledge_base/ai_disruption_prompts.md`.
    - Services load exact prompt text, interpolate dates/sources.

**Why This Fits nextgen-plaid**:
- Reuses Devise (owner-only access to run/audit tasks).
- Reuses attr_encrypted patterns for any sensitive keys.
- Aligns with background job philosophy (Solid Queue).
- Keeps data private/local-first (PostgreSQL with RLS possible later).
- Easy to extend: future tie-in to user FinancialSnapshotJob JSON for context augmentation.
- No Python needed here (unlike curriculum sims)—Ruby handles orchestration, HTTP, parsing.

**Next Steps**:
- Update PRD 0 to reflect this Rails-native strategy (I'll revise and output the full adjusted PRD 0 if you confirm).
- Add `ai_disruption` namespace to backlog.
- Decide initial priority: Start with PRD 1 (Positive Trend) as a service + rake task prototype?

Confirm if this Rails-integrated direction works, or if you prefer keeping it fully separate (e.g., in a subfolder with Python scripts called via system/exec). Any specific constraints from current repo state (e.g., avoid adding new gems initially)?