---
description: Read ai/migration/ledger.md and report per-feature state, blockers, stalled rows, and aggregate perf uplift. Read-only — never modifies the ledger. Run on demand or via weekly cron.
---

# /migration-status

## The Premise (read this first)

**Read-only. Cite real ledger rows. No hand-waves.** Every count, every per-feature row, every drift flag in the report traces to a real `ai/migration/ledger.md` row, a real `ai/migration/parity-runs/<feature>.md`, a real `ai/migration/halts/<feature>-*.md`. No "approximately N stalled" — exact counts. No grep-based guesses for state distribution; parse the ledger. If the ledger is malformed or a referenced file is missing, halt with the offending row + line; do NOT fill in plausible numbers.

Reports the current state of the V1→V2 migration. Reads `ai/migration/ledger.md` (and optionally git log + parity-run reports) and produces a structured summary that is checkable by humans + parseable by tooling.

This command is the read-side counterpart to `/port-feature`. It never modifies the ledger; for transitions, use `/port-feature`.

## Phases applied

Standard pipeline phases 1–4 (Understand → Organize → Retrieve → Generate). No Update / Validate / Improve — read-only.

## When to use

- Daily / weekly check on migration health.
- Before a planning meeting — what's done, what's blocked, what's stalled.
- After a cutover stage advance — confirm the ledger reflects the advance.
- On `/port-feature` halt — get an overview of impacted rows.
- As part of weekly cron (`.claude/git-hooks/post-merge-learn.sh` may invoke this and append to `ai/migration/status-weekly-<iso>.md`).

## Pre-flight checks (halt if fail)

1. `ai/migration/ledger.md` exists. If absent — halt: "no migration in progress; nothing to report."
2. Ledger has at least one feature row. If empty — halt: "ledger has no features; run `/setup-project --refresh` to populate."

## Phase 1 — Understand (read inputs)

1. Parse `ai/migration/ledger.md`. Each `## <feature>` section is a feature row with YAML frontmatter (per `migration-ledger.md` § Per-feature record shape).
2. For each row, collect: name, state, owner, v1_commit_pinned, contract path, plan path, parity_runs (most recent), perf_decisions path, shadow_started, canary_stage, dependencies.
3. Read most recent parity-run report (`ai/migration/parity-runs/`) per feature in `V2-shadow` / `V2-canary` — get mismatch_rate, latency / error / business KPIs.
4. Read most recent audit (`ai/migration/audits/`) per feature in advance-pending state — get the audit verdict.
5. Read `ai/migration/halts/` for any feature in `Halted` state — get root cause.

## Phase 2 — Organize (compute report)

Aggregate:

- **Per-state counts**: how many features in each of {V1-only, In-progress, V2-shadow, V2-canary, V2-only, V1-deleted, Halted}.
- **Stalled rows**: features in same state past their SLA. Defaults: `In-progress > 30d`, `V2-shadow > 14d`, `V2-canary > 7d per stage`, `V2-only without progressing to V1-deleted > 30d`.
- **Blocked rows**: features whose dependencies are not yet `V2-only`. Group by blocking feature.
- **Owner load**: per owner, how many active rows (not in V1-only, not in V1-deleted).
- **Perf uplift summary**: from all `perf-decisions/<feature>.md` files — count applied / deferred / rejected per category (caching, indexes, query, columns, parallel, etc.); aggregate measurements where available.
- **Recent transitions**: features that changed state in the last 7 days (from git log of `ai/migration/ledger.md`).
- **Drift detection** (per `migration-ledger.md` § Drift detection): features whose code state contradicts their ledger state.

## Phase 3 — Retrieve (cross-reference)

For each row in V2-shadow or V2-canary, retrieve:
- Most recent parity mismatch_rate trend (last 7 days) — flag rows with rising mismatch rate.
- Most recent latency / error / KPI delta (V2 vs V1) — flag rows with degrading deltas.

For each blocked row, retrieve:
- The blocking feature's ETA (its plan's cutover_complete date if available).
- Owner of the blocking feature.

## Phase 4 — Generate (write report)

Output to stdout AND optionally to `ai/migration/status-<iso>.md` (for cron):

```markdown
# Migration status — <iso>

**Total features**: 24
**Migration started**: 2026-03-15
**Estimated completion** (linear projection): 2026-08-22
**Owner**: <name>

## State distribution

| State | Count | % | Notes |
|---|---|---|---|
| V1-only | 6 | 25% | 3 unassigned |
| In-progress | 4 | 17% | 1 stalled (>30d) |
| V2-shadow | 5 | 21% | avg shadow age 5d, mismatch_rate p95 0.0001 |
| V2-canary | 1 | 4% | auth-flow @ 50%, day 1 |
| V2-only | 2 | 8% | health-check (day 8/14), admin-export (day 22/14 — ready to delete) |
| V1-deleted | 6 | 25% | terminal |
| Halted | 0 | 0% | — |

## Recent transitions (last 7 days)

- 2026-04-25: `report-orders` In-progress → V2-shadow
- 2026-04-23: `getCustomer` V2-only → V1-deleted
- 2026-04-20: `auth-flow` V2-canary 10% → 50%

## Stalled (intervention needed)

| Feature | State | Days in state | SLA | Owner | Last activity |
|---|---|---|---|---|---|
| admin-export | In-progress | 35 | 30 | charlie | parity tests red on 2 inputs (2026-04-20) |

## Blocked on dependency

| Feature | Blocked by | Blocking state | Blocking ETA |
|---|---|---|---|
| searchOrders | getUser | V2-shadow | 2026-05-04 (per plan) |

## Owner load

| Owner | Active features | Stalled |
|---|---|---|
| alice | 3 (1 In-progress, 2 V2-shadow) | 0 |
| bob | 2 (V2-shadow + V2-canary) | 0 |
| charlie | 1 (In-progress) | 1 |

## Perf uplift (cumulative, applied across V2-shadow + later)

| Category | Applied | Deferred | Rejected |
|---|---|---|---|
| Caching (per-request) | 7 | — | — |
| Caching (Redis) | 2 | 5 | — |
| DB index added | 4 | — | — |
| Query optimisation (N+1, join push-down) | 11 | — | 1 |
| Column projection | 9 | — | 2 |
| Parallel I/O (sequential→bounded parallel) | 6 | — | — |
| Off-hot-path side effects | 1 | 2 | 3 |

**Aggregate measured impact** (post-cutover features):
- Avg p95 latency: -38%
- Avg DB queries/call: -52%
- Avg bytes/response: -41%
- 4 indexes added (1 reverted in dev — was redundant; rest stable)

## Drift / risk flags

- ⚠ `legacy-export` ledger says V2-only since 2026-04-01; `git grep` finds 1 V1 import in `cron/nightly_export.py` — investigate before deletion.
- ⚠ `report-orders` shadow mismatch_rate trending up (+0.001%/d for 5d); investigate parity gap before advancing to canary.
- ✅ no other drift detected.

## Next-up (recommended actions)

1. Unblock `searchOrders` — getUser's plan has it landing 2026-05-04; on track.
2. Charlie: `admin-export` stalled — pair / re-architect / split?
3. `health-check` reaches V1-deletion eligibility on 2026-04-29 (14d at V2-only).
4. Investigate `report-orders` rising shadow mismatch.

## Migration milestones

- 25% complete (6/24 features in V1-deleted).
- 50% target: 2026-06-15 — on-track if velocity holds (1.2 ports/week).
- 100% target: 2026-08-22.
```

## Output for tooling (machine-readable)

If invoked with `--json`, emit the same data as JSON for dashboards / metrics:

```json
{
  "generated_at": "2026-04-27T18:00:00Z",
  "total": 24,
  "by_state": {"V1-only": 6, "In-progress": 4, "V2-shadow": 5, "V2-canary": 1, "V2-only": 2, "V1-deleted": 6, "Halted": 0},
  "stalled": [{"feature": "admin-export", "state": "In-progress", "days_in_state": 35, "sla": 30, "owner": "charlie"}],
  "blocked": [{"feature": "searchOrders", "blocked_by": "getUser", "blocker_state": "V2-shadow"}],
  "drift": [{"feature": "legacy-export", "issue": "V1 import in cron/nightly_export.py", "severity": "warn"}],
  "perf_aggregate": {"applied_total": 40, "deferred_total": 7, "rejected_total": 6, "p95_delta_pct": -38, "queries_per_call_delta_pct": -52, "bytes_per_response_delta_pct": -41}
}
```

## Failure modes

- **Ledger malformed** (YAML frontmatter unparseable in some row) — halt with the offending row + line number.
- **Inconsistent state vs required fields** — halt and list per `migration-ledger.md` § Required fields per state.
- **Parity-run reports referenced by ledger but missing on disk** — flag as drift.
- **No git history for ledger** (e.g., shallow clone) — emit report without "recent transitions" section; warn user.

## Related

- `migration-ledger.md` — pattern this command reads.
- `port-feature.md` — sibling command that performs transitions.
- `migration-discipline.md` — the rule.
- `parity-auditor.md` — produces the audit reports this command summarises.
- `code-quality/legacy-modernizer.md` — strategic dashboard; this command is the operational dashboard underneath it.
