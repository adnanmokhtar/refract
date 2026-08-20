---
name: ai-audit
kind: example
pack: ai-engineering
description: Read-only six-axis audit of an existing LLM surface — eval coverage, prompt, retrieval, ANN index, agent budgets, gateway/cost — dispatching the pack's detector skills and routing the trust boundary to @llm-security-reviewer.
---

# /ai-audit [<scope>] [--plan-only]

> **`--plan-only`**: see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). Phases 1–3, write the plan, exit.

Audit command. Phases 1-3 + 6 dominate; Phase 4 = ranked findings; Phase 5 logs the audit; Phase 7 surfaces systemic patterns. Nothing is fixed here — every finding closes on a **closure verb** and the fixes route to `/add-ai-feature`, `/add-eval-set`, `/optimize`, or `/fix-bug`.

## The Premise

**Every finding cites `<path:line>` + a real excerpt + its closure verb** (for an absence, the concrete site that should carry it). **No number this run did not read** — no projected saving, no estimated recall, no hypothetical hit-rate; otherwise `UNMEASURED` + what would settle it. **The eval axis governs the verdict: never a green verdict on an `UNVERIFIED` eval axis.** **Security is routed, never graded** — output→sink, injection, excessive agency, cross-tenant retrieval go to `@llm-security-reviewer`, by site.

## When to use / NOT to use

- USE: an inherited LLM feature nobody measured; pre-launch hardening; "why is our LLM bill like this"; a whole-repo sweep with no diff.
- NOT: building a feature (`/add-ai-feature`) · a security-only ask (`/security-audit`) · running an existing set (`eval-run`) · building one (`/add-eval-set`) · the learning pack's `/eval` (the knowledge base — a different subject).

## Phase 1 — Understand

Intent gate as above. Scope = a path, a feature, or the whole AI surface (flag the cost first). A diff narrows the sweep but is not required. Confirm provider + seam + harness + corpus from `_extracted-codebase.md § AI/LLM integration`.

## Phase 2 — Organize — mechanical dispatch

| Signal | Dispatch | Axis |
|---|---|---|
| prompt assembly / model call | `prompt-audit` | prompt |
| provider SDK / gateway module | `llm-gateway-audit` | gateway / cost |
| `embed` · `vector` · `retriev` · `rerank` · `chunk` | `retrieval-eval` | retrieval |
| `hnsw` · `ivf` · `ef_search` · `nprobe` · `faiss` · a managed store | `vector-index-audit` | ANN index |
| an existing eval harness | `eval-run` | eval |
| **no** eval harness | HALT that axis `UNVERIFIED` + emit `/add-eval-set <feature>` | eval |
| `tools=` · `tool_use` · `while … step` · `max_iterations` | `@agent-loop-architect` (Audit mode) | agent loop |
| corpus present, no retrieval design | `@rag-architect` | retrieval (design gap) |
| all axes | `@ai-feature-reviewer` (whole-surface scope) | all |
| output→sink · injection · destructive tool · cross-tenant | **hand to `@llm-security-reviewer`** | (security) |

A signal that does not fire makes its axis `N-A` — said out loud, never a silent skip. De-dupe across axes: one defect, one row.

## Phase 3 — Retrieve

ALWAYS: see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md). AI-specific by signal: `evals.md` + `prompt-engineering.md` (always) · `rag-pipeline.md` + `vector-store-ops.md` · `agent-design.md` · `llm-gateway.md` · `fine-tuning.md` · `.claude/rules/ai-engineering-principles.md` · `_extracted-codebase.md § AI/LLM integration` · **prior `ai/audits/<date>-ai.md`** (a repeat finding is SYSTEMIC).

## Phase 4 — Generate (ranked findings)

BLOCKER: no eval set on a shipped feature · an eval that does not gate · an unbudgeted loop · an ungated destructive tool · uncapped tokens or no timeout · no store-side tenant filter on a multi-tenant corpus · no no-context guard · regex-parsing structured output. REQUEST: scattered SDK calls · no fallback · an `UNSTATED` recall target · defaulted ANN params · non-zero temp on a deterministic path · partial cost logging · missing redaction · an unversioned prompt. NIT: naming, duplicated prompts.

Verbs come only from the owning pattern's list (`evals`, `prompt-engineering`, `rag-pipeline`, `vector-store-ops`, `agent-design`, `llm-gateway`, `fine-tuning`) — never invented.

## Phases 5–7

**Update**: `ai/audits/<YYYY-MM-DD>-ai.md` (coverage table, findings + verbs, handoffs, each `UNVERIFIED` axis + its unblocking step) · changelog · `ai/status.md` on any BLOCKER or `UNVERIFIED` eval axis. Nothing else is written. **Validate**: every axis graded (`PASS`/`REQUEST`/`BLOCK`/`N-A`/`UNVERIFIED`), every finding has site + impact + fix + verb, no unread number, verdict matches the body. **Improve**: a finding class seen in two audits is SYSTEMIC → ADR + a mechanical guard (import-boundary lint for the seam, a CI grep for uncapped generations, a required eval step).

## Output

```
## /ai-audit — <scope>            Verdict: CLEAN | REQUEST_CHANGES | BLOCK
  eval           UNVERIFIED  no harness → /add-eval-set <feature>
  prompt         BLOCK       regex-parsing structured output (extract/invoice.ts:52)
  retrieval      BLOCK       filtered recall 0.62 vs 0.90 unfiltered (retrieval-eval, set v3, n=40)
  ANN index      REQUEST     target UNSTATED · params defaulted (migrations/0087:6)
  agent loop     N-A         no tools or loop on this surface
  gateway/cost   REQUEST     3 of 7 call sites bypass the seam; cost field not logged
Handed to @llm-security-reviewer: rag/retrieve.ts:31 (LLM08) · support/answer.ts:31 (LLM01)
Unmeasured: LLM spend — no cost field at the seam. Settles with add-cost-logging + one day of traffic.
Artifact: ai/audits/<date>-ai.md
```

## What to do next — required closing section

MUST FIX (BLOCKERs + any `UNVERIFIED` eval axis) → SHOULD FIX → OPTIONAL, each with `<path:line>` + **Fix** (with its verb) + **Verify**, then re-run `/ai-audit`, `/learn-from-task`, ship. Deferrals become paste-ready commands: [`templates/snippets/actionable-next-steps.md`](../../../snippets/actionable-next-steps.md).

## Hard rules

Never green on an `UNVERIFIED` eval axis · every finding cites a site + verb (a count is not a citation) · no number this run did not read · security routed, never graded · read-only (one artifact + changelog + status) · an absent signal is `N-A`, said out loud · a class seen twice is SYSTEMIC.

## Related

- Commands: `/add-ai-feature`, `/add-eval-set`, `/security-audit`, `/optimize`, `/audit`.
- Agents: `@ai-feature-reviewer`, `@agent-loop-architect` (Audit mode), `@rag-architect`, `@llm-security-reviewer`.
- Skills: `prompt-audit`, `llm-gateway-audit`, `retrieval-eval`, `vector-index-audit`, `eval-run`.
- Rule: `.claude/rules/ai-engineering-principles.md` — AI-1…AI-9.
