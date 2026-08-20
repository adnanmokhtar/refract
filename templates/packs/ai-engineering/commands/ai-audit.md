---
description: Read-only audit of an existing LLM/AI surface across six axes — eval coverage, prompt quality, retrieval quality, ANN index health, agent-loop budgets and tool gates, and gateway/cost/observability — dispatching the pack's detector skills and @ai-feature-reviewer, and routing the trust boundary to @llm-security-reviewer. Ranked findings + a dated audit artifact. TRIGGER — "audit the AI feature / our RAG / our LLM costs", inheriting an LLM feature nobody measured, pre-launch hardening of an AI surface, a whole-repo AI sweep with no diff to review. ANTI-TRIGGERS (do NOT fire) — building a new LLM feature (/add-ai-feature); a security-only ask (/security-audit → @llm-security-reviewer); running an eval set that already exists (eval-run); building one that does not (/add-eval-set); grading the project's own accumulated knowledge base (the learning pack's /eval — a different subject entirely).
---

> **STACK ASSUMPTION**: see this pack's `STACK.md`. This pack is provider-agnostic — examples name a provider illustratively; substitute the project's from `_extracted-codebase.md § AI/LLM integration`.

# /ai-audit [<scope>] [--plan-only]

> **`--plan-only`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). Runs Phases 1–3, writes the plan, and exits before any finding is generated or any file is written.

Audit command. Read-only six-axis sweep of an existing AI surface. Phases 1-3 + 6 dominate; Phase 4 produces ranked findings; Phase 5 logs the audit; Phase 7 surfaces systemic patterns. Nothing is fixed here — every finding closes on a **closure verb** drawn from the owning pattern, and the fixes route to `/add-ai-feature`, `/add-eval-set`, `/optimize`, or `/fix-bug`.

## The Premise (read this first, internalize, do not deviate)

**Find real issues, no hand-waves. Every finding cites `<path:line>` + a real 1-line excerpt + its closure verb.** For an *absence* finding — no eval set, no timeout, no tenant filter, no recall target — the citation is the concrete site that should have carried it: the call site, the index definition, the write path. "The RAG pipeline could use better chunking" is worthless; `src/rag/chunk.ts:14 — fixed 1000-char split mid-sentence, no boundary rule → tune-chunking` is a finding.

**No number this command did not read.** No projected cost saving, no estimated recall, no hypothetical cache hit-rate, no "roughly 30% of calls". Where the project's telemetry supplies a figure, cite it with its source. Where it does not, the value is `UNMEASURED` and the finding names the one change that would produce it. An axis that could not be examined is `UNVERIFIED`, never OK.

**The eval axis governs the verdict.** `/ai-audit` may never print a green verdict on an `UNVERIFIED` eval axis. A surface nobody can measure is not a surface anybody can call healthy — and the next step for that axis is always `/add-eval-set`, named as a paste-ready command, never a vague "build some evals".

**Security is routed, never graded here.** Output→sink, the injection surface, a destructive tool the model can fire, a cross-tenant retrieval leak: these are `@llm-security-reviewer`'s (`LLM01` / `LLM05` / `LLM06` / `LLM08`). This command reports the engineering half and hands the boundary across, by site. Never absorb, never silently drop.

## Mechanical halt — hand-wave grep

See [`templates/snippets/hand-wave-grep.md`](../../../snippets/hand-wave-grep.md). Use the audit report draft as the grep target; anchors are `<path:line>` / `<index name>` / `<eval case-id>` per the premise above. **Also** grep for AI-audit tokens: `should be fine`, `probably`, `roughly`, `approximately`, `~%`, `several call sites`, `and N others`, `looks correct`, `seems tuned`. A bypass count without every site enumerated is a hand-wave; so is a recall or cost figure with no run behind it.

## When to use / NOT to use

- USE: an LLM feature you inherited and nobody has measured; pre-launch hardening of an AI surface; "why is our LLM bill like this"; a whole-repo AI sweep with no diff to review.
- USE: after `@ai-feature-reviewer` BLOCKs on a diff and the question becomes "what else on this surface is like that".
- NOT: building a new LLM feature — `/add-ai-feature`.
- NOT: a security-only ask — `/security-audit`, which dispatches `@llm-security-reviewer` for the full LLM trust boundary.
- NOT: running an eval set that already exists (`eval-run`), or building one that does not (`/add-eval-set`).
- NOT: the learning pack's `/eval` — that scores the project's accumulated knowledge base against saved cases. Different subject, different artifact.

## Phases applied

AUDIT type — 1, 2, 3, 6 dominate. Phase 4 = ranked findings; Phase 5 writes the audit artifact; Phase 7 surfaces systemic patterns.

## Phase 1 — Understand

### Intent gate

If the ask suggests a different intent, halt with a redirect:
- "build / add an LLM feature" → `/add-ai-feature`.
- "the feature exists but has no eval set" → `/add-eval-set` (this command will *report* that gap; the retrofit is that command's job).
- "run the evals" → `eval-run` directly.
- "prompt injection / the model can be tricked / output rendered unsafely / it can delete things" → `/security-audit` → `@llm-security-reviewer`. This command routes the boundary; it does not grade it.
- "review this PR / this diff" → `@ai-feature-reviewer` (diff-shaped review), not a whole-surface sweep.
- "score our knowledge base / our saved decisions" → the learning pack's `/eval`. Unrelated to LLM-feature evals despite the name.
- "make it cheaper / faster" as an optimization task → this command finds the gateway/cost gaps; `/optimize` applies them.

### Standard inputs

- **Scope.** `<scope>` may be a path, a feature name, or empty. Empty → the whole AI surface (flag the runtime cost before starting on a large repo).
- Determine whether a diff exists:
  ```bash
  git diff --name-only "origin/${BASE:-main}"...HEAD
  ```
  A diff narrows the sweep; no diff is the normal case for this command and is not a blocker.
- Confirm the provider + seam + harness from `_extracted-codebase.md § AI/LLM integration`: which provider, one gateway module or scattered SDK calls, is there an eval harness, is there a corpus.

Success criteria: every one of the six axes carries a grade with evidence or an honest `UNVERIFIED`; every finding has a site, an impact, a fix, and a closure verb; the artifact is written; the next steps are paste-ready.

## Phase 2 — Organize — the mechanical dispatch table

Route by named grep signal on the surface. One row per axis; a signal that does not fire makes its axis `N-A` (say so), never a silent skip.

| Signal on the surface | Dispatch | Axis |
|---|---|---|
| any prompt assembly / model call (`system`, `messages`, `prompt`, a completion call) | `prompt-audit` | prompt |
| any provider SDK import / gateway module (`anthropic`, `openai`, `google.genai`, `bedrock`, `vertexai`, `ollama`, `litellm`, a house `llm/` module) | `llm-gateway-audit` | gateway / cost |
| `embed` · `vector` · `retriev` · `rerank` · `chunk` | `retrieval-eval` | retrieval |
| `hnsw` · `ivf` · `ef_search` · `nprobe` · `nlist` · `faiss` · a managed vector store | `vector-index-audit` | ANN index |
| an existing eval harness (`promptfoo`, `deepeval`, `ragas`, LangSmith, `tests/eval_*`) | `eval-run` | eval |
| **no** eval harness anywhere | HALT that axis as `UNVERIFIED` + emit `/add-eval-set <feature>` as the paste-ready next step | eval |
| `tools=` · `tool_use` · `function_call` · `while … step` · `max_iterations` · `AgentExecutor` | `@agent-loop-architect` (**Audit mode**) | agent loop |
| a corpus exists but no retrieval design does (chunker + index present, no target, no labelled set) | `@rag-architect` | retrieval (design gap) |
| all axes, for the engineering verdict | `@ai-feature-reviewer` (whole-surface scope, not a diff) | all |
| output→sink · injection surface · destructive tool · cross-tenant retrieval | **hand to `@llm-security-reviewer`** — routed, never graded here | (security) |

Run the dispatched skills and agents in parallel. Each returns findings with closure verbs; this command ranks and de-dupes them — a single defect appears once, under the axis that owns it (an unversioned prompt is `prompt-audit`'s detector 5, and it is *referenced* by the gateway cache-key finding rather than counted twice).

## Phase 3 — Retrieve

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

AI-SPECIFIC, by signal:
- `ai/patterns/evals.md` (always — it is the spine) + `prompt-engineering.md` (always).
- `ai/patterns/rag-pipeline.md` + `vector-store-ops.md` (retrieval / vector store present).
- `ai/patterns/agent-design.md` (tools or a loop present).
- `ai/patterns/llm-gateway.md` (any provider call).
- `ai/patterns/fine-tuning.md` (a training pipeline, an adapter, or `.jsonl` training data present).
- `.claude/rules/ai-engineering-principles.md` — AI-1…AI-9 are the checklist this audit is a sweep of.
- `_extracted-codebase.md § AI/LLM integration` — the surface map.
- **Prior `ai/audits/<date>-ai.md`** — a finding that appears in two audits is SYSTEMIC and escalates in Phase 7.

## Phase 4 — Generate (ranked findings)

Consolidate every dispatched result into one ranked ledger. Rank by blast radius, not by axis order:

- **BLOCKER** — no eval set on a shipped feature; an eval that does not gate the build; an unbudgeted agent loop; a destructive tool with no gate; uncapped output tokens or no timeout on a user-facing generation; no tenant/permission filter at the store on a multi-tenant corpus; no no-context guard on RAG; regex-parsing structured output where a schema exists; an index serving deleted content that was deleted for a permission reason.
- **REQUEST** — scattered SDK calls with no seam; no fallback on a single-provider production path; an unstated recall/latency target; defaulted ANN parameters; non-zero temperature on a deterministic path; partial cost logging; missing redaction on a log path; an unversioned prompt.
- **NIT** — naming, duplicated prompt literals, non-load-bearing structure.

Each finding carries: `<path:line>` + excerpt (or the concrete site of the absence) · impact · fix · **closure verb** from the owning pattern's verb list · the axis it belongs to.

The closure verbs this audit may emit, by owner — never invent one:
- `evals` → `add-eval-set`, `require-eval-diff`, `fix-judge-rubric`, `swap-judge-model`, `backfill-eval-from-incident`, `wire-regression-gate`
- `prompt-engineering` → `use-structured-output`, `split-system-user`, `add-output-schema`, `set-deterministic-params`, `version-and-eval-prompt`
- `rag-pipeline` → `add-retrieval-eval`, `tune-chunking`, `unify-embedding-model`, `add-reranker`, `add-tenant-filter`, `add-context-budget`, `add-no-context-guard`
- `vector-store-ops` → `add-ann-index`, `tune-ann-params`, `fix-distance-metric`, `fix-filtered-recall`, `add-index-refresh`
- `agent-design` → `downgrade-to-workflow`, `add-tool-gate`, `add-loop-budget`, `add-context-compaction`, `make-tool-error-recoverable`, `validate-tool-args`, `add-human-gate`
- `llm-gateway` → `route-through-gateway`, `add-call-budget`, `add-fallback`, `add-prompt-cache`, `scope-semantic-cache`, `add-cost-logging`, `add-log-redaction`
- `fine-tuning` → `try-prompt-baseline-first`, `move-knowledge-to-rag`, `add-baseline-eval-gate`, `fix-train-eval-leakage`, `version-model-dataset-eval`

### Honesty clause

No finding without the artifact behind it. Every claim cites a real `<path:line>` / index definition / eval case-id the run actually read. A recall number comes from a real `retrieval-eval` run over a labelled set; a cost number comes from the project's telemetry with its source named; a "passing eval" comes from `eval-run`'s per-metric table with its `Reports:` path. Where a check could not run — no harness, no labelled set, index config unreadable, provider surface unidentified — it is reported `UNVERIFIED` with the reason and the one thing that would settle it. Never OK, never a guessed number.

## Phase 5 — Update

- `ai/audits/<YYYY-MM-DD>-ai.md` — the full report: the six-axis coverage table, every finding with its site + verb, the security handoff list, and each `UNVERIFIED` axis with its unblocking step. This artifact is what the next run diffs against.
- `ai/dynamic/changelog.md` — one line: `AI audit on <scope>: B blockers, R requests, U unverified axes`.
- `ai/status.md` `## Recent Changes` — a bullet if any BLOCKER or any `UNVERIFIED` eval axis was found (it must survive the session).
- Nothing else is written. This command does not edit code, does not tune a parameter, and does not create an eval set.

## Phase 6 — Validate

- Every finding has a site, an impact, a fix, and a closure verb from the lists above.
- Every axis has a grade: `PASS` / `REQUEST` / `BLOCK` / `N-A` (signal absent) / `UNVERIFIED` (could not be measured). No axis is blank.
- No number appears that this run did not read. Re-check each figure against its source.
- The verdict matches the body: `BLOCK` iff ≥1 BLOCKER; `REQUEST_CHANGES` iff ≥1 REQUEST and no BLOCKER; a clean verdict only when neither — **and never while the eval axis is `UNVERIFIED`**.
- Every security-shaped finding appears in the handoff list, by site, and nowhere in the graded axes as though it had been cleared.
- Findings de-duped across axes — one defect, one row.

## Phase 7 — Improve

- `/learn-from-task` — capture each finding class.
- A finding class that appears in **two** audits (check prior `ai/audits/<date>-ai.md`) is SYSTEMIC: queue an ADR proposal and a mechanical guard — an import-boundary lint for the gateway seam (AI-8), a CI grep for an uncapped generation (AI-3), a required eval step on LLM paths (AI-2).
- Repeated retrieval misses of the same shape → the labelled set is missing a case class; wire the incident→case path (`backfill-eval-from-incident`).
- If the same axis comes back `UNVERIFIED` twice, that is itself the top finding of the second audit — an unmeasurable surface is not improving, it is accumulating.

## Output

```
## /ai-audit — <scope>

Verdict: CLEAN | REQUEST_CHANGES | BLOCK        (never CLEAN while eval is UNVERIFIED)

Coverage table:
  Axis            Grade        Note
  eval            UNVERIFIED   no harness anywhere in the repo → /add-eval-set support-summarizer
  prompt          BLOCK        regex-parsing structured output (extract/invoice.ts:52)
  retrieval       BLOCK        filtered recall 0.62 vs 0.90 unfiltered (retrieval-eval, set v3, n=40)
  ANN index       REQUEST      target UNSTATED · params defaulted (migrations/0087:6)
  agent loop      N-A          no tools or loop on this surface
  gateway / cost  REQUEST      3 of 7 call sites bypass the seam; cost field not logged

BLOCKERS (3):
  - src/extract/invoice.ts:52 · `out.match(/Total:\s*\$([\d.]+)/)` · silent field loss on any phrasing
    drift · switch to the provider's schema mode + validate · use-structured-output
  - src/rag/retrieve.ts:31 · tenant predicate applied after fetch, in app code · a dropped check is a
    cross-tenant read · enforce at the store · add-tenant-filter  [also HANDED to @llm-security-reviewer]
  - <feature> · no eval dataset for a shipped LLM path · every prompt/model change is unmeasured ·
    /add-eval-set <feature> · add-eval-set

REQUESTS (4): route-through-gateway ×3 (chat/handler.ts:12, titles/generate.ts:8, backfill.py:44) ·
              add-cost-logging (llm/gateway.ts:88) · tune-ann-params (migrations/0087:6) ·
              set-deterministic-params (classify/intent.ts:19)

NITs (1): version-and-eval-prompt — near-identical prompt at prompts/titles.ts:8 + titles-batch.ts:14

Handed to @llm-security-reviewer:
  - src/rag/retrieve.ts:31 — post-fetch tenant filter on a multi-tenant corpus (LLM08)
  - src/support/answer.ts:31 — instructions + user text + retrieved chunks share one role (LLM01)

Unmeasured / unverified:
  - eval axis: no harness. Settles with /add-eval-set <feature>, then eval-run.
  - LLM spend: no cost field at the seam. Settles with add-cost-logging + one day of traffic.

Dispatched: prompt-audit · llm-gateway-audit · retrieval-eval · vector-index-audit ·
            @agent-loop-architect (N-A) · @ai-feature-reviewer
Artifact: ai/audits/2026-08-20-ai.md
```

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (BLOCKERs + any `UNVERIFIED` eval axis) → **SHOULD FIX** (REQUESTs) → **OPTIONAL** (NITs) — each step carrying `<path:line>` + **Fix** (concrete, with its closure verb) + **Verify** (the command that proves it: `eval-run`, `retrieval-eval`, a re-run of this audit), then the closing steps (re-run `/ai-audit` to confirm it comes back clean, `/learn-from-task`, then ship). Every deferred finding becomes a paste-ready command — see [`templates/snippets/actionable-next-steps.md`](../../../snippets/actionable-next-steps.md). A clean run collapses to a single line ("No findings — clear to proceed"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Hard rules

- **Never a green verdict on an `UNVERIFIED` eval axis.** No harness means the surface is unmeasurable, and unmeasurable is not healthy. The next step is `/add-eval-set`, named.
- **Every finding cites a site + an excerpt (or the concrete site of the absence) + a closure verb.** A count is not a citation; enumerate every bypassing call site, every ungated tool, every unversioned prompt.
- **No number this run did not read.** No projected saving, no estimated recall, no implied hit-rate. `UNMEASURED` + what would settle it is the correct output.
- **Security is routed, never graded.** Output→sink, injection, excessive agency, cross-tenant leak → `@llm-security-reviewer`, by site, in the handoff block.
- **Read-only.** No code edited, no parameter tuned, no eval set created, no index rebuilt. The audit writes exactly one artifact plus its changelog and status lines.
- **An axis whose signal is absent is `N-A` and says so.** Silence is not a pass.
- A finding class seen in two audits is SYSTEMIC and gets an ADR + a mechanical guard queued, not a third identical report.

## Related

### Sibling commands
- `/add-ai-feature` — builds an LLM feature end-to-end; the fixes this audit ranks are applied there.
- `/add-eval-set` — retrofits the regression-gating harness; the standing answer to an `UNVERIFIED` eval axis.
- `/security-audit` (security pack) — the security-only door; dispatches `@llm-security-reviewer` for the full LLM trust boundary.
- `/optimize` — cost/latency work once this audit has named the gateway gaps.
- `/audit` (orchestration) — the whole-repo multi-axis sweep; AI/LLM-only asks belong here instead.

### Agents
- `@ai-feature-reviewer` — the engineering verdict across all six axes (dispatched whole-surface, not diff-scoped).
- `@agent-loop-architect` — **Audit mode** for the agent-loop axis; emits the design delta plus the loop verbs.
- `@rag-architect` — dispatched when a corpus exists but no retrieval design does.
- `@llm-security-reviewer` (security pack) — receives every trust-boundary finding; this command never grades one.

### Skills
- `prompt-audit` — prompt axis · `llm-gateway-audit` — gateway/cost axis · `retrieval-eval` — retrieval axis · `vector-index-audit` — ANN index axis · `eval-run` — eval axis (when a harness exists).

### Patterns
- `ai/patterns/evals.md`, `prompt-engineering.md`, `rag-pipeline.md`, `vector-store-ops.md`, `agent-design.md`, `llm-gateway.md`, `fine-tuning.md`.

### Rules
- `.claude/rules/ai-engineering-principles.md` — AI-1…AI-9; this command is the standing whole-surface sweep for them.
