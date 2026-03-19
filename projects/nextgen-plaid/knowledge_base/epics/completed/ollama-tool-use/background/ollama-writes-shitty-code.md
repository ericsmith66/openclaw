### Why Ollama (llama3.1 via Ollama) wasn’t reliably making tool calls

There are two overlapping reasons in this repo’s architecture:

#### 1) The Ollama path is **not a structured tool-calling API** in SmartProxy
In `smart_proxy/lib/ollama_client.rb`, the payload forwarded to Ollama is essentially:
- `{ model, messages, stream: false }`

There is **no OpenAI-style `tools` field** being sent to Ollama, and Ollama’s `/api/chat` response is mapped back into OpenAI-ish `choices[].message.content`.

That means:
- the model is **not constrained** by a function/tool schema
- tool calls are not “first-class” outputs
- the model must *voluntarily* follow instructions like “call `GitTool` now” using plain text

So you’re relying on prompt-following behavior, not a tool-calling contract.

By contrast, providers like Grok/Claude return **explicit tool-use structures** (or SmartProxy can map their tool-use to OpenAI-style `tool_calls`). That is inherently more reliable.

#### 2) Model behavior + sampling makes “tool discipline” inconsistent
Even if a model *can* be prompted to emit tool calls, it may:
- answer “in prose” instead of issuing a tool call
- partially comply (plans but doesn’t execute)
- get distracted by long context (PRD + schema + instructions)
- be sensitive to temperature / top-p

Local Llama-family models often have higher variance in “structured obedience” compared to models that are tuned heavily for tool use.

### How to address it (no code)

#### A) Use a tool-call-capable model for execution phases
For “CWA execution” (where you need real `GitTool` / `SafeShellTool` calls), prefer models that are tuned and consistently produce tool calls in this environment (e.g., `grok-4-latest` via SmartProxy).

Keep Ollama/llama3.1 for:
- PRD drafting
- analysis/planning
- summarization

#### B) Tighten the human request (make tool usage non-optional)
Instead of “Execute micro tasks…”, use:
- “REQUIRED: first call `GitTool init_sandbox`, then `ProjectSearchTool` for X, then `SafeShellTool` to run Y. Do not answer until those calls are done.”

This reduces the model’s degrees of freedom.

#### C) Reduce context bloat for the execution run
If you include PRD + schema + many docs, the model may “opt out” into narration.
Operationally:
- keep the execution prompt focused on the specific tasks and files
- avoid dumping huge docs unless needed

#### D) Use deterministic-ish settings when possible
If your runtime lets you configure it:
- lower temperature
- avoid very high top-p

This tends to improve adherence to structured patterns (including tool-call sequences).

#### E) Add a human verification loop
Operationally (no code):
- treat “no tool calls occurred” as a failed run
- rerun with a more explicit instruction or a different model

### Quick diagnostic checklist (to confirm it’s the model path, not config)

1) Are tools even allowed?
- `AI_TOOLS_EXECUTE=true`
- `--sandbox-level=loose`

2) Is SmartProxy up?
- `curl http://localhost:3002/health`

3) Did the run produce any `tool_start/tool_complete` events?
- If none: model didn’t emit tool calls (common with Ollama path)

4) Did `cwa_summary.md` show executed tool calls?
- If empty sections: same conclusion.

If you want Ollama to be the execution model too, the realistic path is: accept that it’s “best effort” for tool calls, or keep Ollama for planning and use a tool-oriented hosted model for execution.

**llama3-groq-tool-use:70b** (the Ollama tag) is a specialized fine-tune of Llama 3 (base from Meta's Llama 3 series, not 3.1) optimized for tool/function calling. It's **not** the same as the more recent Llama 3.1 70B or Llama 3.3 70B.

### Size & Download/Run Requirements
- **Parameters**: 70.6 billion (same as standard 70B Llama models).
- **Ollama default quantization**: Q4_0 (4-bit) – this is what `ollama pull llama3-groq-tool-use:70b` downloads and runs by default.
- **Download / disk size**: ~40 GB (confirmed from Ollama library page and multiple sources).
- **RAM / VRAM requirements** (on your maxed-out M3 Ultra, which has unified memory up to 192 GB):
    - Model weights alone (Q4_0): ~40 GB loaded.
    - KV cache + overhead (context 8k–16k typical): +5–15 GB depending on context length and batch.
    - Total active memory: Roughly 45–60 GB for comfortable runs (fits easily in your unified memory; Ollama on Apple Silicon uses Metal for acceleration and can offload to CPU/RAM if needed, but you'll get good performance with full GPU layers).
    - Higher quants (e.g., Q5_K_M or Q8_0 from Hugging Face GGUF like bartowski's repo): 45–70 GB disk, more RAM (~50–80 GB loaded), but better quality if you want to test them manually.

It will run smoothly on your hardware (M3 Ultra handles 70B Q4/Q5 very well locally via Ollama).

### Differences from Your Current 70B (likely llama3.1:70b or base llama3:70b)
Your current setup uses a general-purpose instruct model (e.g., llama3.1:70b-instruct), which is excellent at reasoning, coding, summarization, and following complex instructions but **not** specifically tuned for tool calling.

| Aspect                  | llama3-groq-tool-use:70b                          | Standard llama3.1:70b (or llama3:70b)              |
|-------------------------|---------------------------------------------------|----------------------------------------------------|
| **Base**                | Fine-tuned from Llama 3 (not 3.1) + Glaive/Groq tool data | Llama 3.1 Instruct (or Llama 3 Instruct) – general-purpose |
| **Primary Strength**    | Tool/function calling (structured outputs)        | General reasoning, coding, multilingual, long context |
| **Tool Calling**        | State-of-the-art at release (July 2024): 90.76% accuracy on BFCL leaderboard (#1 open-source/propriety at time) | Decent but inconsistent (relies on prompt; often narrates or mangles args) |
| **General Knowledge / Reasoning** | Slightly weaker than base Llama 3.1 70B (specialized fine-tune trades off some generality) | Stronger overall (higher MMLU, math, coding benchmarks) |
| **Speed / Efficiency**  | Similar inference speed to other 70B Q4 (your M3 Ultra ~30–60 t/s depending on context) | Same hardware footprint |
| **Context Length**      | Standard 8k–128k (Llama 3 family)                 | 128k native in 3.1                                 |
| **Best For**            | CWA execution phases needing reliable GitTool / SafeShellTool / ProjectSearchTool calls | PRD drafting, analysis, planning, summarization, curriculum reasoning |

### Good At (Strengths of llama3-groq-tool-use:70b)
- Extremely reliable structured tool calls when provided with `tools` schema (via Ollama /api/chat) — follows schemas precisely, fewer hallucinations in args.
- High obedience on function-calling benchmarks (outperformed many closed models at launch).
- Ideal for agent workflows where you need the model to consistently decide "call this tool now" and format arguments correctly.
- Still retains strong Llama 3 reasoning for intermediate steps.

### Bad At (Weaknesses)
- Less versatile for pure chat/reasoning tasks — can feel "narrower" or less creative than general instruct models.
- Some user reports (e.g., Reddit threads) note it occasionally ignores prompts or underperforms in complex multi-step agents without careful setup (though this improved with native tool forwarding).
- Older base (Llama 3 vs 3.1/3.3) — misses later improvements in math, multilingual, instruction following.
- If you don't send `tools` schema, it falls back to prompt-only behavior (same issues as your current setup).

### Recommendation for Your Use Case
- Use **llama3-groq-tool-use:70b** specifically for **execution/tool-heavy phases** (CWA runs, SDLC CLI tasks) once you implement tool forwarding in smart_proxy (per the PRD I drafted).
- Keep **llama3.1:70b** (or upgrade to llama3.3:70b if available in Ollama) for planning, PRD/epic drafting, and general analysis — better all-around reasoning.
- Test command: `ollama pull llama3-groq-tool-use:70b` (takes ~40 GB download; then `ollama run` a simple tool prompt like the weather example to verify structured output).

This hybrid approach maximizes your M3 Ultra's local power while fixing the reliability gap Junie flagged.

Next: Ready to pull/test this model and share a sample tool-call output? Or want tweaks to the PRD for OllamaClient?