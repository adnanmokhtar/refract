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

## Mechanical halt — hand-wave grep

See [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Use the audit report draft as the grep target; anchors are `<path:line>` / `<index name>` / `<eval case-id>` per the premise above. **Also** grep for AI-audit tokens: `should be fine`, `probably`, `roughly`, `approximately`, `~%`, `several call sites`, `and N others`, `looks correct`, `seems tuned`. A bypass count without every site enumerated is a hand-wave; so is a recall or cost figure with no run behind it.

## When to use / NOT to use

- USE: an inherited LLM feature nobody measured; pre-launch hardening; "why is our LLM bill like this"; a whole-repo sweep with no diff.
- NOT: building a feature (`/add-ai-feature`) · a security-only ask (`/security-audit`) · running an existing set (`eval-run`) · building one (`/add-eval-set`) · the learning pack's `/eval` (the knowledge base — a different subject).

## Phases applied

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = ranked findings; Phase 5 writes the audit artifact; Phase 7 surfaces systemic patterns.

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

## Phase 5 — Update

`ai/audits/<YYYY-MM-DD>-ai.md` — the full report: the six-axis coverage table, every finding with its site + verb, the security handoff list, and each `UNVERIFIED` axis with its unblocking step. This artifact is what the next run diffs against. `ai/dynamic/changelog.md` — one line. `ai/status.md § Recent Changes` — a bullet on any BLOCKER or any `UNVERIFIED` eval axis. **Nothing else is written**: this command does not edit code, does not tune a parameter, and does not create an eval set.

## Phase 6 — Validate

Every finding has a site, an impact, a fix, and a closure verb. Every axis has a grade — `PASS` / `REQUEST` / `BLOCK` / `N-A` (signal absent) / `UNVERIFIED` (could not be measured); no axis is blank. No number appears that this run did not read. The verdict matches the body: `BLOCK` iff ≥1 BLOCKER; `REQUEST_CHANGES` iff ≥1 REQUEST and no BLOCKER; a clean verdict only when neither — **and never while the eval axis is `UNVERIFIED`**. Every security-shaped finding appears in the handoff list, by site, and nowhere in the graded axes as though it had been cleared. Findings de-duped across axes — one defect, one row.

## Phase 7 — Improve

`/learn-from-task` — capture each finding class. A finding class that appears in **two** audits (check prior `ai/audits/<date>-ai.md`) is SYSTEMIC: queue an ADR proposal and a mechanical guard — an import-boundary lint for the gateway seam (AI-8), a CI grep for an uncapped generation (AI-3), a required eval step on LLM paths (AI-2). Repeated retrieval misses of the same shape → the labelled set is missing a case class; wire the incident→case path. If the same axis comes back `UNVERIFIED` twice, that is itself the top finding of the second audit — an unmeasurable surface is not improving, it is accumulating.

## Output

```
## /ai-audit — <scope>            Verdict: CLEAN | REQUEST_CHANGES | BLOCK
  eval           UNVERIFIED  no harness → /add-eval-set <feature>
  prompt         BLOCK       regex-parsing structured output (extract/invoice.ts:52)
  retrieval      BLOCK       filtered recall 0.62 vs 0.90 unfiltered (retrieval-eval, set v3, n=40)
  ANN index      REQUEST     target UNSTATED · params defaulted (migrations/0087:6)
  agent loop     N-A         no tools or loop on this surface
  gateway/cost   REQUEST     3 of 7 call sites bypass the seam; cost field not logged
Handed to @llm-security-reviewer: rag/retrieve.ts:31 (LLM09:2026) · support/answer.ts:31 (LLM01:2026)
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
