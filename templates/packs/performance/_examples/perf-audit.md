---
description: Performance pass — single performance-optimizer dispatch, ranked by impact, gated on measured before/after. Optionally pairs with caching-architect for cache-strategy work.
---

# /perf-audit [path|endpoint]

Audit command. Profiles changed code or a named endpoint and returns ranked findings. Phases 1-3 + 6 dominate; Phase 4 produces measurements + proposals (no edits without approval); Phase 7 surfaces patterns.

`--plan-only` (alias `--plan`) runs the read-only measurement phases and writes the ranked findings as a plan instead of applying anything. A plan-only run still measures real baselines; it never ships a projected win without the `<before>` number behind it.

## When to use / NOT to use
- USE: endpoint timed out or breached SLO in dev/staging.
- USE: after adding a list endpoint or a join.
- USE: during P2/P3 hardening.
- NOT: during P1 prototyping — premature; feature works at current scale = move on.
- NOT: as a substitute for production profiling — local measurements approximate, not authoritative.

## Boundary — pick the right perf command

`perf-audit` is the ranked-findings sweep: broad and shallow. Route elsewhere when the job is narrower or wider:

| Job | Route to | Why |
|---|---|---|
| One known-slow path, cause unknown | `/profile-perf` | single-bottleneck deep-dive; goes deeper than a sweep |
| Web bundle / page-load / Core Web Vitals | `/bundle-perf` | perf-audit doesn't measure the browser |
| Authoritative field INP / real-user CWV | `web-vitals-field` skill | field CWV with attribution is the ONLY authoritative INP source — lab INP is a synthetic proxy, not the measurement |
| Slowness is structural (layering, god module) | `/optimize` | perf-audit sees the symptom, not the layering that caused it |
| Whole-system review across security + DB + scale | `/audit` | perf-audit is the perf slice of it |

## Phase 1 — Understand
- Resolve scope:
  - No arg → changed files since last commit.
  - Path arg → that file/dir.
  - Endpoint arg (e.g. `GET /orders`) → trace controller → service → repo → downstream calls.
- Confirm: are we measuring an actual SLO breach, or speculating? A finding with no baseline behind it is tagged `speculative` and dropped from the GO list.
- **Classify the question before opening any taxonomy — `regression` or `always-slow`.**
  - **`regression`** ("it got slow", "since the deploy") — a known-good state existed. Recover it and **diff**, cheapest first, stopping at the first that explains the magnitude: deploy range → migration/schema → data volume + distribution → query-plan flip → cache hit-rate → downstream latency. Do NOT open the bottleneck taxonomy first: a taxonomy lists what is *sometimes* slow, and here you already know the answer is *whatever changed*.
  - **`always-slow`** ("never been fast", "we're adding a list view") — nothing changed, the cost is structural; proceed to Phase 2 and use the taxonomy.
  - If no last-known-good measurement exists, say so — that is the first finding, and establishing a baseline is the first deliverable. A regression hunt with nothing to diff against is an `always-slow` sweep wearing a regression's clothes.

## Phase 2 — Organize
- Decide tooling per scope: the DB engine's plan-explainer for DB, the project's web-vitals profiler + framework dev-tools for frontend, the project's HTTP load-tester for endpoint-level measurement.
- Dispatch plan: single dispatch of `performance-optimizer` (covers N+1, missing indexes, blocking I/O, memory, renders, bundle). Add `caching-architect` only if scope is explicitly cache-strategy.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight):
- `CLAUDE.md` — stack, conventions, persona, decision boundaries.
- `.claude/codebase-profile.md` — every detected fact about this project.
- `ai/conventions.md` — auto-detected naming + style.
- `ai/business-domain.md` — kind of product + canonical entities.
- `ai/project-goals.md` — mission + KPIs + anti-goals.
- `ai/dynamic/feedback-learned.md` — corrections from prior sessions.
- `ai/status.md` — current phase + in-flight work + recent changes.

Perf-specific:
- `ai/patterns/caching-strategy.md`, `ai/patterns/indexing-strategy.md` — project's existing approach (don't propose a different distributed-cache product if the project has already standardised on one).
- Existing dashboards / SLO docs (`ai/observability.md`).
- Recent migrations affecting the scope (new column / index changes).

## Phase 4 — Generate (measurements + proposals)
- Dispatch `performance-optimizer` with the resolved scope (single agent, single dispatch). It covers DB queries / indexes / N+1 in addition to code-level perf.
- For each finding, capture a baseline if locally measurable:
  - HTTP path: a quick load test via the project's load-tester, or a timed request loop.
  - Query: the DB engine's plan-explainer.
  - Frontend render: the framework's dev-tools profiler / the project's web-vitals profiler.
- **Establish the noise band once, before ranking.** Re-run the unchanged baseline harness ≥3× and record the spread. A before→after delta inside that spread is `NO-CHANGE`; a guardrail delta inside it is clean. Without this, "(noise)" in a verdict cell is an assertion — exactly what Phase 6 gate 1 exists to catch.
- Rank by `(impact / effort)`. A projected win inside the noise band is not a finding.
- Print ranked table. The `Issue` column holds what the measurement showed, not what the reader expects to be there — filling it from the taxonomy before profiling is how a sweep confirms its own guess:
  ```
  # Endpoint     Issue                     Baseline    Evidence                 Proposed   Expected   Risk
  1 <endpoint>   <cause, from the profile> <n>ms p95   <plan / flamegraph:line> <fix>      <n>ms p95  Low
  ```
  A row whose `Evidence` cell is empty is `speculative` and does not rank.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-perf.md` — findings + baselines + proposed deltas, AND the **production-grade verdict table** (the required output artifact Phase 6 reads its verdict from; a `--plan-only` run writes the same table with every row `PROPOSED [pre-apply]`):
  ```
  # noise band for this run: ±<n>% on p95 (<N> baseline re-runs, Phase 4)
  # Metric            Budget   Before    After     Harness         Guardrails re-checked (Δ)   Verdict
  1 <endpoint> p95    <n>ms    <n>ms     <n>ms     <same harness>  <metric> <Δ> (within band)  PRODUCTION-GRADE
  ```
  A reader checks each applied-finding row: a real numeric `Before`+`After` from a named `Harness` (or the whole row `SKIPPED [no-harness]`), an at/under-budget `After`, a filled `Guardrails` cell, and a `Verdict`. An empty cell, or an adjective ("faster", "snappier") in `Before`/`After`, is a failed run.
- `ai/dynamic/changelog.md` — one-line: `perf audit on <scope>: N findings, top win = X ms`.

## Phase 6 — Validate (the production-grade gate — measured, not asserted)

A perf change is **production-grade only when it is measured against a budget, the hotspot was profiled, and no guardrail metric regressed.** "Feels faster" is the floor, not the bar. This phase reads its verdict off the Phase-5 table; it never declares a bare "COMPLETE".

**The four gates (per applied finding; `--plan-only` marks each `PROPOSED [pre-apply]` and stops here):**

1. **Measured, not asserted.** The `<after>` is a number from the SAME harness that produced `<before>` — same load test / plan-explainer / web-vitals profile, same conditions, same dataset shape. An adjective in the after-column ("much faster", "snappier", "should be quicker") FAILS the gate — it is the exact defect this phase exists to catch. **No harness for this metric?** Label the row `SKIPPED [no-harness]` and name the harness that would be needed. Never fake a pass; never launder an adjective as a measurement.
2. **Beats the budget, not just the before.** The `<after>` lands at or under the stated budget. Faster-than-before but still over budget is `INCOMPLETE — over budget (<after> vs <budget>)`, not done. If no budget exists, stating one is the first deliverable.
3. **No guardrail regression.** Re-measure the neighbour metrics the fix could have slowed, per the guardrail matrix in `performance-optimizer` (index → insert/update latency + write p95; caching → staleness + memory/GC; parallel I/O → downstream RPS + error-rate + pool saturation; bundle-split → request-waterfall round-trips; memoization → heap retention). ANY guardrail worse beyond the **measured noise band from Phase 4** → `INCOMPLETE — regressed <metric>`, HALT, keep behind review, re-diagnose or revert.
4. **Profiled, not guessed.** The hotspot the fix targets was chosen from a profile artifact (flamegraph excerpt / query plan / slow-query-log row / web-vitals attribution), cited in the finding. A fix whose target has no profile behind it is `INCOMPLETE — unprofiled`.

Also: DB index proposals routed through `/migration-review` BEFORE any apply attempt; caching proposals justified only when the underlying call is genuinely irreducible.

**Terminal verdict.** `PRODUCTION-GRADE` ONLY when every applied finding is PASS or honestly `SKIPPED [no-harness]`, with zero adjectives in the number columns. Any `INCOMPLETE — …` finding makes the run `INCOMPLETE`, naming every unmet item. It never rounds a partial pass up to done.

## Phase 7 — Improve
- `/learn-from-task` — capture each accepted optimization.
- If 3+ N+1 findings across modules → queue ADR: enforce eager-load defaults at repo layer.
- If same index pattern needed repeatedly → queue to `ai/patterns/indexing-strategy.md`.

## Output format
```
## /perf-audit — <N> findings, top win <delta>

Phase 1 (Understand): scope = <files | endpoint>; branch = <regression|always-slow>; SLO breach = <yes|no>
Phase 3 (Retrieved): caching + indexing patterns; recent migrations
Phase 4 (Generated): ranked findings table; noise band ±<n>%
Phase 5 (Updated): ai/audits/<date>-perf.md (incl. production-grade verdict table), changelog
Phase 6 (Validated): every applied finding measured <before>→<after> from the same harness, at/under budget, guardrails re-checked, profiled — or row marked SKIPPED [no-harness]
Phase 7 (Improved): patterns queued

Status: PRODUCTION-GRADE          # every applied finding measured, at/under budget, guardrails clean, profiled
  # OR
Status: INCOMPLETE — <unmet items named>
  # OR
Status: PLAN — proposals only, no fix applied (--plan-only); each finding PROPOSED [pre-apply]
```

A bare "COMPLETE" is never a valid terminal status — the reader must be able to tell measured-and-under-budget from merely-functional at a glance.

## What to do next — required closing section

Every run MUST end with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (measured regressions / SLO breaches) → **SHOULD FIX** (real measured wins) → **OPTIONAL** (marginal) — each step carrying `<file:line>` + **Fix** (concrete; index proposals route through `/migration-review`) + **Verify** (the measurement that proves the win), then the closing steps (re-run `/perf-audit` to confirm the number improved, `/learn-from-task`, then ship). A clean run collapses to a single line ("No findings — clear to proceed"). The reader must never assemble the next steps themselves.

## Failure modes
- "Looks slow" without a number → mark `speculative` and stop; don't ship guess-work.
- Opening the bottleneck taxonomy on a regression → you get a list of things that are sometimes slow instead of the one thing that changed.
- Calling a delta "(noise)" without having measured the noise band → an asserted classification, which is the defect gate 1 exists to catch.
- Premature optimization in P1 → feature ships, audit later.
- Index added without `/migration-review` → table-lock risk in prod; always route the proposal.
- Caching proposed as default → hides root cause; only when the work is genuinely irreducible.
- Mid-tier mobile blind-spot → frontend wins on a fast laptop ≠ wins on 3G + throttled CPU; test the right device class.

## Related
- `/profile-perf` — single-bottleneck deep-dive.
- `/bundle-perf` — browser-side bundle + Core Web Vitals.
- `performance-optimizer` — the agent this command dispatches; owns the bottleneck taxonomy + guardrail matrix.
- `caching-architect` — cache strategy, when the scope is explicitly caching.
