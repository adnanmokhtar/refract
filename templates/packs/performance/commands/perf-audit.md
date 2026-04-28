---
description: Performance pass — performance-optimizer + query-optimizer in parallel, ranked by impact.
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
- Decide tooling per scope: `EXPLAIN ANALYZE` for DB, Lighthouse / React profiler for frontend, `hey`/`autocannon` for HTTP.
- Dispatch plan: `performance-optimizer` + `query-optimizer` in parallel.

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
- `ai/patterns/caching-strategy.md`, `ai/patterns/indexing-strategy.md` — project's existing approach (don't propose Redis if Memcached is the standard).
- Existing dashboards / SLO docs (`ai/observability.md`).
- Recent migrations affecting the scope (new column / index changes).

## Phase 4 — Generate (measurements + proposals)
- Dispatch `performance-optimizer` and `query-optimizer` in parallel with the resolved scope.
- For each finding, capture a baseline if locally measurable:
  - HTTP path: `curl -w "@curl-format.txt" <url>` or `hey -n 100 -c 10 <url>`.
  - Query: `EXPLAIN ANALYZE` (Postgres) / `EXPLAIN FORMAT=JSON` (MySQL).
  - JS render: React DevTools profiler / Lighthouse.
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
