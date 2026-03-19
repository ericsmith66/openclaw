### Which document is better (and why) for a “Vision statement” in a context menu
You’re proposing to replace `knowledge_base/Vision 2026/ignore/010 - Vision 2026.md` with:
- `knowledge_base/Vision 2026/Advantage-Vision.md`
- `knowledge_base/Vision 2026/business-problems-capabilities.md`

That’s a good direction, but the key is: **don’t treat these three as interchangeable**. They serve different retrieval roles.

---

### 1) `010 - Vision 2026.md` (current)
**Best at:** being a short “north star” + agentic-system intent.
- Very compact, easy to include in every prompt/context menu.
- Clear principles + roles (SAP/Conductor/CWA/SmartProxy) + success metrics.

**Weak for PRD generation / RAG grounding:**
- It doesn’t encode *what to build next* in a structured way (few concrete capabilities, few “business problem → capability → acceptance criteria” anchors).
- It doesn’t connect well to epics/PRDs/components (no IDs, no explicit cross-links).

**RAG behavior:** high recall, low precision. It will “match” lots of queries but rarely adds actionable constraints.

---

### 2) `business-problems-capabilities.md` (proposed)
**Best at (for RAG):** retrieval precision + PRD scaffolding.
- It’s already a **chunkable map**: business problem → capability statements.
- It distinguishes **[Existing] vs [Future]**, which is extremely helpful for SAP PRDs (reduces hallucinated scope).

**Weaknesses:**
- It’s not a full narrative “vision statement”; it’s more like a capability backlog lens.
- It has little explicit linkage to the actual codebase/epics unless you add IDs or references.

**RAG behavior:** high precision. Great for “what capability solves X?” and for generating good PRD “Problem/Goal/Outcomes/AC”.

---

### 3) `Advantage-Vision.md` (proposed)
**Best at:** being the “full vision anchor” with reasoning + pillar structure.
- It’s a strong strategic narrative and has richer context.
- It includes “Existing Capabilities” with repo-related pointers, and a roadmap.

**Main risk for RAG/context menus:**
- It’s long and hierarchical; if you naively include it in context, you’ll add noise and reduce retrieval quality.
- It’s best used as **targeted retrieval** (pull just the relevant pillar subsection), not as a global always-on prefix.

**RAG behavior:** high value but only if you chunk it and retrieve selectively.

---

### Recommendation (what to replace, what to keep)
If your “vision statement” is meant to be **always available in the context menu**, then:

1) **Keep `010 - Vision 2026.md` (or rewrite it slightly) as the short always-on north-star.**
   - It’s the right size and communicates the agentic system intent cleanly.

2) **Add `business-problems-capabilities.md` as the primary *retrieval* doc for PRD generation.**
   - This is the single best improvement for PRD quality because it gives SAP a structured problem→capability mapping.

3) **Use `Advantage-Vision.md` as the “deep backing doc” retrieved on demand** (by pillar / capability).
   - It should not replace the short vision statement in a context menu; it should be a deeper layer.

If you insist on “replacement” (only 1–2 docs), then:
- Best 2-doc replacement set is exactly what you proposed: **`010` → replaced by (a) a *short excerpt* of `Advantage-Vision.md` + (b) `business-problems-capabilities.md`**.
- But I’d still keep a very short north-star somewhere because it helps the agent stay aligned.

---

### How to integrate into your existing `rag-structure` + context menu (minimal disruption)
You already have the right scaffolding in `knowledge_base/epics/backlog/agentic-planning/rag-structure/`:

#### A) Vision index (`rag-structure/vision/index.yml`)
Right now, it anchors vision on `knowledge_base/static_docs/MCP.md` (`master_control_plan`). For PRD generation, you want the vision index to point at:
- `Vision 2026` short north-star (today that’s `010 - Vision 2026.md`)
- `business-problems-capabilities.md` (retrieval map)
- `Advantage-Vision.md` (detailed backing)

Even if you don’t change code yet, conceptually the **vision index summary-level** should reference the short doc, and **detailed/full** should pull from the other two.

#### B) Cross-references (`rag-structure/cross-references/map.json`)
Add concept IDs that link pillars/capabilities to:
- functional features (`rag-structure/functional/index.yml`) and
- structural code paths (`rag-structure/structural/index.yml`)

This is how you make PRDs stop being generic: the PRD can cite “Pillar 2 dashboard” *and* list actual routes/controllers.

#### C) Context menu behavior (the important part)
Instead of “include these docs wholesale”, make menu options like:
- **Vision (short)** → inject `010 - Vision 2026.md` (or a 1–2 paragraph excerpt from `Advantage-Vision.md`)
- **Vision (capability map)** → inject `business-problems-capabilities.md`
- **Vision (deep, by pillar)** → retrieve the relevant pillar section from `Advantage-Vision.md`

This matches your multi-index / phase-budget approach and avoids blowing up context.

---

### The practical “best” choice depends on how you chunk/retrieve
So in terms of “which doc is better”:
- **For a context-menu always-on “vision statement”:** `010 - Vision 2026.md` is best (short, stable).
- **For RAG retrieval + PRD generation quality:** `business-problems-capabilities.md` is best (atomic, precise).
- **For deep strategic grounding when needed:** `Advantage-Vision.md` is best (rich, but must be selectively retrieved).

If you tell me how your context menu is implemented (is it selecting files, or selecting “queries” like `fetch:vision:*`?), I can suggest the exact menu entries that map cleanly onto your `rag-structure/config.yml` phase system.