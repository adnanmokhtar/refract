---
description: Performance pass — performance-optimizer single dispatch, ranked by impact. Optionally pairs with caching-architect for cache-strategy work.
---

# /perf-audit [path|endpoint]

Audit command. Profiles changed code or a named endpoint and returns ranked findings. Phases 1-3 + 6 dominate; Phase 4 produces measurements + proposals (no edits without approval); Phase 7 surfaces patterns.

## When to use / NOT to use
- USE: endpoint timed out or breached SLO in dev/staging.
- USE: after adding a list endpoint or a join.
- USE: during P2/P3 hardening.
- NOT: during P1 prototyping — premature; feature works at current scale = move on.
- NOT: as a substitute for production profiling — local measurements approximate, not authoritative.

## Phase 1 — Understand
- Resolve scope:
  - No arg → changed files since last commit.
  - Path arg → that file/dir.
  - Endpoint arg (e.g. `GET /orders`) → trace controller → service → repo → downstream calls.
- Confirm: are we measuring an actual SLO breach, or speculating? Speculative wins under 5% are discarded.

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
- Rank by `(impact / effort)`. Discard speculative wins under 5%.
- Print ranked table:
  ```
  # Endpoint     Issue                      Baseline   Proposed                Expected   Risk
  1 GET /orders  N+1 in items load          820ms p95  Eager join via repo qb  ~120ms p95 Low
  2 GET /orders  Missing index tenant_id+ts full scan  Composite idx           10× list   Low
  ```

## Phase 5 — Update
- `ai/audits/<YYYYMMDD>-perf.md` — findings + baselines + proposed deltas (timestamped).
- `ai/dynamic/changelog.md` — one-line: `perf audit on <scope>: N findings, top win = X ms`.

## Phase 6 — Validate
- Every finding has a measured baseline (no "looks slow"). Speculative findings are tagged `speculative` and dropped from the GO list.
- DB index proposals routed through `/migration-review` BEFORE any apply attempt.
- Caching proposals justified — only when the underlying call is genuinely irreducible.

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
Phase 5 (Updated): ai/audits/<date>-perf.md, changelog
Phase 6 (Validated): all findings have baselines; index proposals queued for /migration-review
Phase 7 (Improved): patterns queued

Status: COMPLETE
```

## Failure modes
- "Looks slow" without a number → mark `speculative` and stop; don't ship guess-work.
- Premature optimization in P1 → feature ships, audit later.
- Index added without `/migration-review` → table-lock risk in prod; always route the proposal.
- Caching proposed as default → hides root cause; only when the work is genuinely irreducible.
- Mid-tier mobile blind-spot → frontend wins on a fast laptop ≠ wins on 3G + throttled CPU; test the right device class.

## Related

### Rules
- `.claude/rules/performance-principles.md`
