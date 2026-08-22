---
description: Performance pass — performance-optimizer single dispatch, ranked by impact. Optionally pairs with caching-architect for cache-strategy work.
---

# /perf-audit [path|endpoint]

> **`--plan-only`** (alias `--plan`): honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/perf-audit <scope> --plan-only` runs the read-only measurement phases (1-3 + the Phase 4 baseline capture), writes the ranked findings as a plan to `.claude/plans/`, and exits before applying any fix — execute it later with `/execute-plan <file>`. Honesty clause: a plan-only run still measures real baselines; it never ships a projected win without the `<before>` number behind it.

Audit command. Profiles changed code or a named endpoint and returns ranked findings. Phases 1-3 + 6 dominate; Phase 4 produces measurements + proposals (no edits without approval); Phase 7 surfaces patterns.

## When to use / NOT to use
- USE: endpoint timed out or breached SLO in dev/staging.
- USE: after adding a list endpoint or a join.
- USE: during P2/P3 hardening.
- NOT: during P1 prototyping — premature; feature works at current scale = move on.
- NOT: as a substitute for production profiling — local measurements approximate, not authoritative.

## Boundary — pick the right perf command

`perf-audit` is the **ranked-findings sweep**: scan a scope, surface the top N issues by `impact / effort`, propose fixes. It is deliberately broad and shallow. When the job is narrower or wider, route elsewhere:

| Job | Command | Why |
|---|---|---|
| One known-slow path, cause unknown | `/profile-perf` | single-bottleneck deep-dive with flame-graph + per-axis attribution; goes deeper than a sweep |
| Web bundle / page-load / Core Web Vitals + page-to-page navigation timing (soft-nav / route-change→paint) | `/bundle-perf` | bundle size + hydration + LCP/INP/CLS + nav timing; perf-audit doesn't measure the browser |
| Authoritative field INP / real-user CWV | `web-vitals-field` skill | field CWV with attribution is the ONLY authoritative INP source — Lighthouse lab INP is a synthetic proxy, not the measurement |
| Page-to-page navigation speed (prefetch / Speculation Rules / bfcache / instant-loading / View Transitions) | `navigation-speed` skill | fast-nav specialist that `/bundle-perf` routes to |
| The slowness is structural (layer violation, god module, wrong-level responsibility) | `/optimize` | architectural diagnosis; perf-audit only sees the symptom, not the layering that caused it |
| Whole-system review across security + DB + scale + perf | `/audit` | full-stack multi-axis pass; perf-audit is the perf slice of it |

If a `perf-audit` finding turns out to be one slow path that needs a real profile, hand it to `/profile-perf`. If it's a web frontend, hand it to `/bundle-perf`. Don't make `perf-audit` do their job.

## Phase 1 — Understand
- Resolve scope:
  - No arg → changed files since last commit.
  - Path arg → that file/dir.
  - Endpoint arg (e.g. `GET /orders`) → trace controller → service → repo → downstream calls.
- Confirm: are we measuring an actual SLO breach, or speculating? A finding with no baseline behind it is tagged `speculative` and dropped from the GO list.
- **Classify the question before opening any taxonomy — `regression` or `always-slow`. They need different work and this is the branch the sweep used to skip.**

| Branch | The user said | First move |
|---|---|---|
| **`regression`** | "it got slow", "since the deploy", "it used to be fast" | **A known-good state existed. Recover it and diff.** Do NOT open the bottleneck taxonomy yet — a taxonomy lists what is *sometimes* slow, and on a regression you already know the answer is *whatever changed*. |
| **`always-slow`** | "this endpoint has never been fast", "we're adding a list view" | Proceed to Phase 2. The taxonomy is the right tool: nothing changed, so the cost is structural. |

  On the `regression` branch, establish **when** before **why**, then diff these — cheapest first, stopping at the first that explains the magnitude:

  1. **Deploy range** — what shipped between the last known-good measurement and the first bad one. This is usually the whole answer and costs one `git log`.
  2. **Migration / schema** — an index dropped or added, a column type widened, a constraint added.
  3. **Data volume + distribution** — the query did not change; the table grew, or one tenant's row count did. A plan that was fine at 10k rows is not fine at 10M.
  4. **Query plan flip** — same SQL, different plan. Re-run the plan-explainer and compare node types against the known-good plan; a planner that switched from index scan to seq scan on updated statistics is invisible in the diff.
  5. **Cache hit-rate** — an unchanged code path in front of a cache that stopped hitting (key change, TTL change, eviction pressure) looks exactly like the code got slower.
  6. **Downstream latency** — the dependency regressed, not you. Check its p95 over the same window before touching your own code.

  If the last known-good measurement does not exist, say so — *that* is the first finding, and establishing a baseline is the first deliverable. A regression hunt with nothing to diff against is an `always-slow` sweep wearing a regression's clothes; call it one rather than pretending to bisect.

## Phase 2 — Organize
- Decide tooling per scope: the DB engine's plan-explainer for DB, the project's web-vitals profiler + framework dev-tools for frontend, the project's HTTP load-tester for endpoint-level measurement.
- Dispatch plan: single dispatch of `performance-optimizer` (covers N+1, missing indexes, blocking I/O, memory, renders, bundle). Add `caching-architect` only if scope is explicitly cache-strategy.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Perf-specific:
- `ai/patterns/caching-strategy.md`, `ai/patterns/indexing-strategy.md` — project's existing approach (don't propose a different distributed cache product if the project has already standardised on one).
- Existing dashboards / SLO docs (`ai/observability.md`).
- Recent migrations affecting the scope (new column / index changes).

## Phase 4 — Generate (measurements + proposals)
- Dispatch `performance-optimizer` with the resolved scope (single agent, single dispatch). It covers DB queries / indexes / N+1 in addition to code-level perf.
- For each finding, capture a baseline if locally measurable:
  - HTTP path: a quick load test via the project's load-tester (e.g., k6 / hey / wrk / autocannon / `oha`) or a timed `curl` loop.
  - Query: the DB engine's plan-explainer (`EXPLAIN ANALYZE` in Postgres, `EXPLAIN FORMAT=JSON` in MySQL, or the equivalent in your DB).
  - Frontend render: the framework's dev-tools profiler / the project's web-vitals profiler.
- **Establish the noise band once, before ranking anything.** Re-run the unchanged baseline harness ≥3× and record the spread. That spread is the floor for every later claim in this run: a before→after delta inside it is `NO-CHANGE`, and a guardrail delta inside it is clean. Without it, "(noise)" in a verdict cell is an assertion — the exact failure Phase 6 gate 1 exists to catch, printed in this command's own output.
- Rank by `(impact / effort)`. A projected win inside the noise band is not a finding.
- Print ranked table. **The `Issue` column holds what the measurement showed, not what the reader expects to be there** — filling it from the taxonomy before profiling is how a sweep confirms its own guess:
  ```
  # Endpoint     Issue                        Baseline    Evidence                Proposed          Expected    Risk
  1 <endpoint>   <cause, from the profile>    <n>ms p95   <plan / flamegraph:line> <fix>            <n>ms p95   Low
  2 <endpoint>   <cause, from the plan>       <n>ms p95   <EXPLAIN node>           <fix>            <n>ms p95   Low
  ```
  Every row's `Evidence` cell names the profile artifact the `Issue` was read off. A row whose `Evidence` is empty is `speculative` and does not rank.

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-perf.md` — findings + baselines + proposed deltas (timestamped) AND the **production-grade verdict table** (the required output artifact Phase 6's gate is read from — a `--plan-only` run writes the same table with every row `PROPOSED [pre-apply]`):
  ```
  # Metric               Budget   Before      After       Harness           Guardrails re-checked (Δ)          Verdict
  # noise band for this run: ±3% on p95 (3 baseline re-runs, Phase 4) — every "within noise" below is read against THAT number
  1 GET /orders p95      ≤200ms   820ms p95   180ms p95   k6 same script    write p95 +2% (within band); err 0   PRODUCTION-GRADE
  2 orders list index    ≤20ms    410ms seq   9ms idx     EXPLAIN ANALYZE   insert p95 +3% (at band edge)       PRODUCTION-GRADE
  3 /products LCP        ≤2.5s    3.2s        2.6s        Lighthouse CI     INP: field-only, not re-measured    INCOMPLETE — over budget (2.6s vs 2.5s)
  ```
  A reader opens this file and checks each applied-finding row: a real numeric `Before`+`After` from a named `Harness` (or the whole row `SKIPPED [no-harness]`), an at/under-budget `After`, a filled `Guardrails` cell, and a `Verdict`. An empty cell, or an adjective ("faster", "snappier", "should be quicker") in `Before`/`After`, is a failed run.
- `ai/dynamic/changelog.md` — one-line: `perf audit on <scope>: N findings, top win = X ms`.

## Phase 6 — Validate (the production-grade gate — measured, not asserted)

A perf change is **production-grade only when it is measured against a budget, the hotspot was profiled, and no guardrail metric regressed.** "Feels faster" is the floor, not the bar. This phase is the mechanical form of that — the perf analog of a before→after superiority gate: the change must BEAT the baseline *against its budget*, verified from two measurements, never asserted with an adjective. It reads its verdict off the Phase-5 verdict table (the required output artifact); it never declares a bare "COMPLETE".

- **Baseline discipline.** Every finding has a measured baseline (no "looks slow"). Speculative findings are tagged `speculative` and dropped from the GO list.
- DB index proposals routed through `/migration-review` BEFORE any apply attempt. Caching proposals justified — only when the underlying call is genuinely irreducible.

**The four gates (evaluated per applied finding; a `--plan-only` run marks each `PROPOSED [pre-apply]` and stops here):**

1. **Measured, not asserted.** The `<after>` is a number from the SAME harness that produced `<before>` — same load test / `EXPLAIN ANALYZE` / web-vitals profile, same conditions, same dataset shape. An adjective in the after-column ("much faster", "snappier", "should be quicker", "feels fast") FAILS the gate — it is the exact defect this phase exists to catch. `[self-policed]` — no shell parses the prose; the smell test is `grep -inE '(faster|snappier|smoother|should be|feels|much quicker)'` over the `Before`/`After` cells of applied rows in `ai/audits/<date>-perf.md`: any hit is an unmeasured claim → convert to a number or mark SKIPPED.
   - **No harness for this metric?** Label the row `SKIPPED [no-harness]` and name the harness that would be needed (e.g., "no k6 script for this endpoint; needs a staging load profile"). Never fake a pass; never launder an adjective as a measurement.
2. **Beats the budget, not just the before.** The `<after>` must land at or under the stated budget (p95/p99/LCP/INP/bundle/memory target from `ai/runtime/perf-budgets.md` or a sibling SLO doc). Faster-than-before but still over budget is `INCOMPLETE — over budget (<after> vs <budget>)`, not done. If no budget exists, the first deliverable is to state one (with the projection's basis) and measure against it — not to ship an un-budgeted "win".
3. **No guardrail regression** (the perf analog of "the old must not win any dimension"). Re-measure the neighbor metrics the fix could have slowed — per the guardrail matrix in `@performance-optimizer` (index → insert/update latency + write p95; caching → staleness + memory/GC; parallel-I/O / fan-out → downstream RPS + error-rate + pool saturation; bundle-split → request-waterfall round-trips; memoization → heap retention) — not only the metric you improved. ANY guardrail worse than baseline beyond the **measured noise band from Phase 4** (never an eyeballed "that's probably noise") → `INCOMPLETE — regressed <metric> (<before> → <after>)`, HALT, keep the change behind review, re-diagnose or revert.
4. **Profiled, not guessed.** The hotspot the fix targets was chosen from a profile artifact (flamegraph excerpt / `EXPLAIN ANALYZE` plan / slow-query-log row / web-vitals attribution), cited in the finding — not eyeballed. A fix whose target has no profile behind it is `INCOMPLETE — unprofiled`; re-run `/profile-perf` on that path first.

**Terminal verdict.** The run reports `PRODUCTION-GRADE` ONLY when every applied finding is PASS or honestly `SKIPPED [no-harness]` (with zero adjectives in `Before`/`After`). If any finding is `INCOMPLETE — …`, the run reports `INCOMPLETE` and names every unmet item — it never rounds a partial pass up to done. The first-pass mechanical HALT (below-projection re-measure) is replaced by gate 2 — budget is the stronger bar: it checks `<after>` against the *budget*, not the projected win, so an over-budget `after` is `INCOMPLETE — over budget` (a change that hits budget but misses its projection still passes; a change that hits its projection but misses budget does not).

## Phase 7 — Improve
- `/learn-from-task` — capture each accepted optimization.
- If 3+ N+1 findings across modules → queue ADR: enforce eager-load defaults at repo layer.
- If same index pattern needed repeatedly → queue to `ai/patterns/indexing-strategy.md`.

## Output format
```
## /perf-audit — <N> findings, top win <delta>

Phase 1 (Understand): scope = <files | endpoint>; SLO breach = <yes|no>
Phase 3 (Retrieved): caching + indexing patterns; recent migrations
Phase 4 (Generated): ranked findings table (above)
Phase 5 (Updated): ai/audits/<date>-perf.md (incl. production-grade verdict table), changelog
Phase 6 (Validated): every applied finding measured <before>→<after> from the same harness, at/under budget, guardrails re-checked (no p95/interaction regression), profiled — or row marked SKIPPED [no-harness]; index proposals queued for /migration-review
Phase 7 (Improved): patterns queued

Status: PRODUCTION-GRADE          # every applied finding measured, at/under budget, guardrails clean, profiled
  # OR
Status: INCOMPLETE — <unmet items named>   # e.g. "Finding 3 over budget 2.6s vs 2.5s; Finding 4 SKIPPED [no-harness]"
  # OR
Status: PLAN — proposals only, no fix applied (--plan-only); each finding PROPOSED [pre-apply]
```

`PRODUCTION-GRADE` is reserved for a run whose verdict table has zero `INCOMPLETE` rows and zero adjectives in the number columns. A bare "COMPLETE" is never a valid terminal status — the reader must be able to tell measured-and-under-budget from merely-functional at a glance.

## What to do next — required closing section

Every run MUST end its report with a `## What to do next` block: the findings re-expressed as ONE ordered, numbered to-do — **MUST FIX** (measured regressions / SLO breaches) → **SHOULD FIX** (real measured wins) → **OPTIONAL** (marginal) — each step carrying `<file:line>` + **Fix** (concrete; index proposals route through `/migration-review`) + **Verify** (the measurement that proves the win), then the closing steps (re-run `/perf-audit` to confirm the number improved, `/learn-from-task`, then ship). A clean run collapses to a single line ("No findings — clear to proceed"). The reader must never assemble the next steps themselves. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- "Looks slow" without a number → mark `speculative` and stop; don't ship guess-work.
- **Adjective in the after-column** ("much faster", "snappier", "should be quicker") → the finding is unmeasured; it is `SKIPPED [no-harness]` at best, never `PRODUCTION-GRADE`. The whole point of the gate.
- **Reported done while still over budget** → `after` beat `before` but not the SLO; that's `INCOMPLETE — over budget`, not a win. Faster ≠ fast enough.
- **Re-measured the improved metric only** → a fix can win its own number and silently regress a neighbor (index speeds reads, slows writes; parallel fan-out saves wall-clock, melts a downstream). Guardrail matrix, always.
- Premature optimization in P1 → feature ships, audit later.
- Index added without `/migration-review` → table-lock risk in prod; always route the proposal.
- Caching proposed as default → hides root cause; only when the work is genuinely irreducible.
- Mid-tier mobile blind-spot → frontend wins on a fast laptop ≠ wins on 3G + throttled CPU; test the right device class.

## Related

### Sibling commands in performance pack
- `/profile-perf` — one slow path deep-dive (flame graph + per-axis attribution). Route here when a finding needs a real profile.
- `/bundle-perf` — web bundle + Core Web Vitals audit; now ALSO covers navigation timing (soft-nav / route-change→paint). Route here for frontend page-load work. For authoritative field INP / real-user CWV route to the `web-vitals-field` skill (Lighthouse lab INP is a synthetic proxy, not the measurement); for page-to-page navigation speed route to the `navigation-speed` skill.

### Route out
- `/optimize` — architectural diagnosis when the slowness is structural, not local.
- `/audit` — full-stack review when perf is one of several axes.

### Rules
- `.claude/rules/performance-principles.md`
