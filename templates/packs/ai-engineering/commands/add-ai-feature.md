---
description: Build an LLM feature end-to-end — prompt/gateway wiring + structured output + retrieval (if RAG) + agent budgets (if agentic) + a MANDATORY regression-gating eval set + a security handoff. 8 phases with Evaluate load-bearing. The AI analog of /add-endpoint.
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. This pack is provider-agnostic — examples name a provider illustratively; substitute the project's from `_extracted-codebase.md § AI/LLM integration`. Access the model through the project's gateway seam / SDK, structured output through its tool/JSON-schema mode, retrieval through its embedding model + vector store.

# /add-ai-feature

Build an LLM-backed feature the right way: the eval set is built FIRST or alongside and gates the change; the prompt uses structured output; calls go through the gateway seam with a cost + token + timeout budget; retrieval (if RAG) is tenant-filtered with a no-context guard; agent loops (if agentic) are budgeted with human-in-loop on destructive tools; and the trust-boundary surface is handed to `@llm-security-reviewer`. The AI analog of `/add-endpoint`.

## Phases applied

All 8: **Understand → Organize → Retrieve → Generate → Evaluate → Update → Validate → Improve.** Phase 5 (Evaluate) is load-bearing — an LLM feature with no regression-gating eval is unshippable, so the eval set is built FIRST or alongside Generate, never bolted on after.

## Phase 1 — Understand (the ask)

### Intent gate

If the description suggests a different intent, halt with a redirect:
- "fix / broken / wrong output" on an existing LLM feature → `/fix-bug` (then re-run `eval-run`).
- "slow / expensive / cache the model" → this command's cost/latency wiring applies, but a pure optimization of an existing feature → `/optimize`.
- "audit / review the AI feature" → `@ai-feature-reviewer` (engineering) or `@llm-security-reviewer` (security).
- "prompt injection / the model can be tricked / output is rendered unsafely" → `@llm-security-reviewer` — this command builds; that agent secures.
- **Not an LLM feature at all** (no model call in the plan) → route to the matching `/add-endpoint` / `/add-feature` / frontend command. Proceed here ONLY when the feature calls a model.

### Standard inputs

Ask (one consolidated question):
- What is the feature (one line — the task the model performs, the input, the expected output)?
- What defines a **good** output (the properties an eval must check — correctness, format, faithfulness, refusal-on-unknown)? *This is the eval spec; it is not optional.*
- Is it **RAG** (answers grounded in a corpus), **agentic** (the model calls tools / loops), or a single **generation/extraction/classification** call?
- Provider + model, and is there a **gateway seam** already, or scattered SDK calls?
- Multi-tenant? (If yes, retrieval + logging must be tenant-scoped.)
- Any **destructive side effect** the feature could trigger (write, pay, email, delete)?

State the success criteria: feature live + a **versioned eval set that gates in CI** + structured output + cost/token/timeout budget + (RAG) tenant-filtered retrieval + no-context guard + (agentic) loop budgets + human-in-loop on destructive tools + `@llm-security-reviewer` handoff cleared + zero placeholders.

## Phase 2 — Organize (design)

Design the feature against the patterns before writing code:
- **Shape** — generation / extraction / classification / RAG / agent (from `ai/patterns/agent-design.md § when_agent_vs_workflow` — prefer a fixed workflow over an agent unless the task genuinely needs open-ended tool use).
- **Prompt** — system vs user roles, instruction/data separation, the output schema (mirror `prompt-engineering.md`).
- **Retrieval** (if RAG) — corpus, chunking, embedding model, top-k, reranker, tenant filter, context assembly (mirror `rag-pipeline.md`).
- **Tools + loop** (if agentic) — tool set, input schemas, loop budget, which tools are destructive (mirror `agent-design.md`).
- **Gateway** — routing / fallback / caching / cost trace seam (mirror `llm-gateway.md`).
- **Eval plan** — the dataset source (seed cases now, grow from prod later), the scorers (assertion + LLM-as-judge + retrieval metric if RAG), the baseline + threshold (mirror `evals.md`). *Design this in Phase 2 so Phase 5 has a spec, not an afterthought.*

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

**MUST read** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) before generating code.

AI-SPECIFIC:
- `ai/patterns/evals.md` + `prompt-engineering.md` (always).
- `ai/patterns/rag-pipeline.md` (if RAG), `agent-design.md` (if agentic), `llm-gateway.md` (provider client / routing).
- `.claude/rules/ai-engineering-principles.md`.
- `_extracted-codebase.md § AI/LLM integration` — the existing gateway seam, prompt sites, eval harness.

EXISTING CODE:
- Mirror a sibling LLM feature EXACTLY (same gateway call, same structured-output mechanism, same eval harness) — no new pattern introduced silently.
- The existing eval harness (`promptfoo` / `deepeval` / custom) — the new eval cases plug into it.

## Phase 4 — Generate (files + wiring)

Follow the sibling feature's shape. Wire every applicable element:

### Prompt + structured output
- Prompt as an **owned/versioned** module, not inline-duplicated across call sites.
- **Structured output via the provider's tool/JSON-schema mode** — never regex/`split`/`JSON.parse` on free text where a schema is available.
- **`temperature: 0`** for extraction / classification / any deterministic surface; non-zero only for genuinely generative output, and justified.
- **Instruction/data separation** — user + retrieved content in a distinct role/delimited block, never concatenated into the instruction body.

### Gateway seam + cost/latency budget
- Route the call through the project's **single gateway module** (routing / fallback / caching / retry), not a fresh raw SDK client.
- **`max_tokens` / `max_output_tokens` set** on every generation.
- **Timeout** on every provider call.
- **Cost traced** — prompt+completion tokens + derived cost logged/metered per call (per tenant if multi-tenant).

### Retrieval (if RAG)
- **Tenant/ACL filter applied at query time** (in the vector query), not post-filtered after fetch.
- **No-context guard** — below the score threshold, the feature abstains ("I don't know") rather than answering from parametric memory.
- Chunking + top-k mirror `rag-pipeline.md`, not copy-pasted defaults.

### Agent loop (if agentic)
- **Budgets** — max steps/iterations + token budget + wall-clock timeout on the loop.
- **Human-in-the-loop / dry-run** on any destructive or irreversible tool (write / pay / email / delete).
- **Typed + validated tool inputs**; tool errors returned to the loop as data; terminate on repeated failure.

### Domain-specific requirements (signal-based)

| Signal | Extra requirement |
|---|---|
| Any generation | `max_tokens` + timeout set; tokens + cost logged. |
| Extraction / classification | Structured output (tool/JSON-schema); `temperature: 0`; NO regex-parsing. |
| RAG | Retrieval tenant-filtered at query time; no-context guard; retrieval metric (recall@k) in the eval, not answer-only. |
| Multi-tenant | Vector query + logs + cost trace all tenant-scoped. Cross-tenant retrieval e2e test. Leak = security handoff. |
| Agentic (tools / loop) | Loop budget (steps + tokens + timeout); human-in-loop on destructive tools; typed tool inputs. |
| Destructive tool (write / pay / delete / email) | Confirmation or dry-run gate; the model cannot fire it unmediated. Excessive-agency review → `@llm-security-reviewer`. |
| Streaming response | Token cap + timeout still apply; cost logged after the stream; mid-stream error handled. |
| Output rendered as HTML / used in SQL / shell / eval / an auth decision | Validate the output shape here; **hand the SINK to `@llm-security-reviewer`** (`LLM05` improper output handling / `LLM06` excessive agency) — do not treat model output as trusted. |
| User content in the prompt | Instruction/data separation; prompt-injection surface → `@llm-security-reviewer` (`LLM01`). |

## Phase 5 — Evaluate (MANDATORY — the gate)

This phase does not skip. The feature is not done until it is measurable.

1. **Build the eval set** — a versioned dataset (checked in), seeded from the Phase-2 eval spec (10–20 real-ish cases minimum), with expected properties per case. Cases are **held out** from the few-shot examples baked into the prompt.
2. **Wire the scorers** — assertion (exact / JSON-schema / contains) + LLM-as-judge (faithfulness / relevance / correctness) + a retrieval metric (recall@k / context-precision) if RAG. Pin the judge model + `temperature: 0` + seed.
3. **Declare the ABSOLUTE pass threshold per gated metric** — the production bar the feature must clear, not merely a self-referential "baseline" (e.g. `exact-match ≥ 0.90`, `faithfulness ≥ 0.85`, `context-recall@k ≥ 0.80` for RAG). A NEW feature has no prior baseline: its first `eval-run` ESTABLISHES the baseline **and must clear this declared absolute bar** — a first run below the bar is a FAIL, not a low baseline to ratchet from. A CHANGE to an existing feature gates on `baseline − ε` as well as the absolute bar. Then **wire the CI eval-gate** — add/confirm the eval-gate step in the pipeline config and verify that step is *present* in the CI file (assert the config, not the pipeline's runtime outcome — this command cannot prove a remote build fails). The real measured gate is `eval-run` in step 4; CI is the standing enforcement of it.
4. **Dispatch the `eval-run` skill** — run the set through the new code and **record the measured score per gated metric** (`<metric> = <score>` vs `≥ <threshold>`) from `eval-run`'s output table + its `Reports:` path. The verdict is the measured number vs the declared threshold, not "it ran green". A metric below its absolute threshold (new feature) or below `baseline − ε` (change) HALTS this command to **INCOMPLETE** — name the failing metric + score; do not ship an unmeasured or below-bar feature. If NO eval harness exists in the repo, `eval-run` HALTS: build the set + scorers (`ai/patterns/evals.md`) first; until it runs, the eval axis is **UNVERIFIED**, never a faked pass.
5. **Security handoff — dispatch `@llm-security-reviewer`** for the trust boundary: prompt injection (direct + indirect), improper output handling (any sink the output reaches), and excessive agency (destructive tools). This is a required handoff, not optional — `@ai-feature-reviewer` reviews engineering quality but does NOT clear security.

HALT conditions for this phase: no eval set built; eval doesn't gate in CI; `eval-run` reports a gated metric below its declared threshold (or below `baseline − ε` on a change); no eval harness so the score is UNVERIFIED; security handoff skipped.

## Phase 6 — Update (persist to the knowledge base)

- Prepend `ai/status.md` Recent Changes entry.
- Record the eval dataset version + baseline in the feature's doc / `ai/patterns/evals.md § datasets`.
- New ADR if a genuinely new pattern emerged (first agent loop, first RAG corpus, new gateway).
- Append a one-line summary to `ai/dynamic/changelog.md`.

## Phase 7 — Validate (verify + review)

- Lint + unit/integration tests on the new files (tool-input validators, output parsers, retrieval filter).
- **`eval-run`** green at/above baseline (re-run — this is the gate, not a formality).
- Multi-tenant → cross-tenant retrieval test passes (tenant A never retrieves tenant B's chunks).
- Agentic → a test asserts the loop budget terminates a runaway loop and a destructive tool requires confirmation.

### Review (parallel)
- **`@ai-feature-reviewer`** — engineering quality (eval coverage / prompt / RAG / agent / cost-latency / output handling).
- **`@llm-security-reviewer`** — the trust boundary (prompt injection / output handling / excessive agency). REQUIRED whenever user content enters the prompt, output reaches a sink, or the model can call a destructive tool.
- `@tenant-isolation-reviewer` — if multi-tenant retrieval.

If a named agent is not installed, run its checklist inline — never silently skip the axis. If any check fails: HALT, report, do not paper over.

## Phase 8 — Improve (feed the learning loop)

- Run `/learn-from-task` to capture: feature shape, sibling mirrored, eval cases added, follow-ups.
- **Grow the eval set from the first production failure** — wire the path from a real bad output back to a new eval case (the loop that makes the gate get stronger over time).
- If a new domain signal surfaced (first RAG corpus, first agent loop) → queue an ADR.

## Ship gate — production-grade or INCOMPLETE (the closing verdict)

"It responds" is the floor, not the ship bar. An AI feature is **production-grade** only when it is **eval-gated** (a measured score at/above a declared threshold), has **guardrails** (input validation, output validation, injection defense, PII redaction), and holds a **cost/latency budget**. Declare **PRODUCTION-READY** only when all three axes below are satisfied *with evidence* — a measured eval score, not "the eval exists"; a named guardrail, not "the output looked safe". Do not print `COMPLETE` on a functional-but-unmeasured feature.

| Production axis | The bar (verified, not asserted) | How it's enforced |
|---|---|---|
| **Eval gate** | The gated metrics were MEASURED by `eval-run` and each cleared its declared threshold — cite the number (`<metric> = <score>` vs `≥ <threshold>`). NEW feature → the ABSOLUTE bar (first run is the baseline yet must clear the bar). CHANGE → `baseline − ε` and the bar. | **mechanical** — read from `eval-run`'s recorded per-metric table + `Reports:` path (a required output artifact a reader/next agent can check), and the CI eval-gate step is grep-confirmed present in the pipeline file (Phase 5.3). No harness ⇒ this axis is **UNVERIFIED**, so the feature is UNVERIFIED, never READY. |
| **Guardrails** | Input validated (length / shape / allow-list) before it reaches the prompt; output schema-validated before any use; PII/secret **redaction on the prompt + log path** (AI-9); the prompt-injection surface handed to `@llm-security-reviewer` and returned **CLEARED**. | **mechanical for the security seam** — `@llm-security-reviewer` returns `CLEARED` / `BLOCKERS`. **[self-policed]** for input-validation + PII redaction in this command, and independently re-graded by `@ai-feature-reviewer` (Phase 7); no shell here catches a missing redaction call. |
| **Budget** | `max_tokens` / `max_output_tokens` set; wall-clock timeout set; per-call token + cost traced; a **per-request cost ceiling** declared (the dollar figure a single call may not exceed). | **[self-policed]** in this command; re-graded by `@ai-feature-reviewer`'s cost/latency dimension (Phase 7). |

Pick exactly one terminal state, honestly:
- **PRODUCTION-READY** — all three axes satisfied with the cited evidence above.
- **UNVERIFIED** — built + functional, but the eval axis could not be measured (no harness). Name it (`eval UNVERIFIED — no harness; set + scorers built, gate not yet run`). The ship decision is the human's, made eyes-open; this command does NOT upgrade it to READY.
- **INCOMPLETE** — a named axis is unmet (a below-threshold metric; a missing guardrail; an unset budget; security `BLOCKERS`). List every unmet item; do not paper over it.

## Output

```
✅ AI feature added: <feature>

Phase 1 (Understand): shape=<generation|extraction|RAG|agentic>, provider=<X>, multi-tenant=<y/n>, signals: <list>.
Phase 2 (Organize): prompt + gateway + (retrieval) + (tools) + eval plan designed.
Phase 3 (Retrieved): universals + evals/prompt-engineering (+ rag-pipeline/agent-design/llm-gateway) + sibling feature.
Phase 4 (Generated): prompt module, gateway call (max_tokens + timeout + cost trace), structured output, (retrieval tenant-filtered + no-context guard), (agent loop budgets + human-in-loop).
Phase 5 (Evaluated): eval set v1 (<N> cases) built + gated in CI; eval-run measured <metric>=<score> vs ≥<threshold> (new: absolute bar / change: baseline−ε); @llm-security-reviewer handoff cleared.
Phase 6 (Updated): ai/status.md, changelog, eval baseline recorded.
Phase 7 (Validated): lint, tests, eval-run green, reviewers.
Phase 8 (Improved): /learn-from-task queued; prod-failure→eval-case path wired.

Files:
  - prompts/<feature>.prompt.ts            (owned prompt + output schema)
  - src/<feature>/<feature>.ts             (gateway call, budget, structured output)
  - src/<feature>/retrieval.ts             (if RAG — tenant-filtered + no-context guard)
  - src/<feature>/agent.ts                 (if agentic — loop budget + human-in-loop)
  - evals/<feature>.eval.yaml              (versioned dataset + scorers, gated in CI)
  - __tests__/<feature>.spec.ts

Eval: <N> cases, scorers=<assertion + judge (+ recall@k)>, measured=<score> vs threshold=≥<bar>, gate=CI.
Cost/latency: max_tokens=<n>, timeout=<ms>, cost traced per call, per-request ceiling=$<x>.

Review verdict (engineering): APPROVE / REQUEST_CHANGES / BLOCK
Security handoff (@llm-security-reviewer): CLEARED / BLOCKERS: <list>

Domain checks:
  - Structured output (no regex-parse) ✓
  - Tenant-filtered retrieval + cross-tenant test ✓ (if RAG multi-tenant)
  - Agent loop budget + human-in-loop on destructive tools ✓ (if agentic)
  - No-context guard ✓ (if RAG)

Ship verdict: PRODUCTION-READY | UNVERIFIED | INCOMPLETE
  Eval axis:      <metric>=<measured> vs ≥<threshold> — PASS | FAIL | UNVERIFIED(no harness)
  Guardrail axis: input-validated ✓ · output schema-validated ✓ · PII redacted ✓ · @llm-security-reviewer CLEARED
  Budget axis:    max_tokens=<n> · timeout=<ms> · cost traced ✓ · per-request ceiling=$<x>
  Unmet (if UNVERIFIED/INCOMPLETE): <named list — the exact items blocking PRODUCTION-READY>

Next:
  - /review-changes
  - Commit + PR
```

## Hard rules

- **Declare PRODUCTION-READY only on evidence, else UNVERIFIED / INCOMPLETE.** "It responds" is the floor. READY requires a MEASURED eval score at/above the declared threshold (cited from `eval-run`), guardrails (input + output validation + PII redaction + injection handoff CLEARED), and a held budget. No harness ⇒ **UNVERIFIED** (name it), never a faked pass. Any unmet axis ⇒ **INCOMPLETE** with the unmet items named. Never print `COMPLETE` on a functional-but-unmeasured feature.
- **A NEW feature gates on the ABSOLUTE threshold, not a self-referential baseline.** The first `eval-run` establishes the baseline AND must clear the declared production bar; a first run below the bar is a FAIL. A change additionally gates on `baseline − ε`.
- **PII/secret redaction is a guardrail, not an afterthought** — the prompt + log path redacts PII/secrets at the gateway seam (AI-9) before READY.
- **The eval set is mandatory and gates in CI.** No eval → not done. This is the load-bearing phase; a feature you cannot regression-test is unshippable.
- **Structured output via the provider's schema mode** — never regex-parse a structured response.
- **Every generation has `max_tokens` + a timeout + a traced cost.** Calls go through the gateway seam, not scattered raw SDK clients.
- **RAG**: tenant-filtered at query time + no-context guard + a retrieval metric in the eval.
- **Agentic**: loop budgeted (steps + tokens + timeout) + human-in-loop on destructive tools.
- **`temperature: 0`** for extraction/classification.
- **Security is a required handoff, not optional** — `@llm-security-reviewer` clears prompt injection / output handling / excessive agency. `@ai-feature-reviewer` does NOT cover security.
- Mirror a sibling LLM feature EXACTLY — no new pattern introduced silently.
- Tests + eval shipped with the code, not bolted on.

## Related

### Sibling commands
- `/add-endpoint` (backend pack) — the non-AI analog; use it when the feature is a plain endpoint with no model call.
- `/fix-bug` — for fixing a broken existing LLM feature (then re-run `eval-run`).
- `/optimize` — for cost/latency optimization of an existing feature.

### Agents
- `@ai-feature-reviewer` — reviews this feature's engineering quality (dispatched in Phase 7).
- `@llm-security-reviewer` (security pack) — clears the trust boundary (required handoff in Phase 5 + 7).

### Skills
- `eval-run` — the regression gate dispatched in Phase 5 + 7.

### Patterns
- `ai/patterns/evals.md`, `prompt-engineering.md`, `rag-pipeline.md`, `agent-design.md`, `llm-gateway.md`.

### Rules
- `.claude/rules/ai-engineering-principles.md`
