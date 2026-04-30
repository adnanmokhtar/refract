---
name: migration-ledger
description: Pattern: Migration ledger (state machine + record format)
kind: ai-pattern
pack: migration
---

# Pattern: Migration ledger (state machine + record format)

> **Hard rule:** Every V1→V2 feature has exactly one ledger row that transitions through the documented state machine; the ledger update is part of the same PR as the work it records. Verbal status, "I'll update it after merge", and rows without owner / V1 commit hash / parity-run ID are forbidden.

**When to apply**
- A migration spans more than 2 features or > 1 sprint — informal tracking will drift.
- Multiple engineers / agents will touch ports concurrently — the ledger is the source of coordination.
- Phase gates require an audit trail (parity evidence, perf decisions, cutover stages).

**When NOT to apply**
- A one-shot single-file refactor with no V1/V2 cohabitation — overhead exceeds value.
- A spike / throwaway exploration where outputs won't ship.

**Halt conditions / mandatory cites**
- Every state transition MUST cite the PR / commit at `<path:line-or-sha>` AND the evidence file (parity-run, perf-decision, cutover dashboard).
- A row missing V1 commit hash, owner, or current state is a bug — reject the PR until filled.
- A doc that updates the ledger without the underlying work merged is a bug.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden when claiming "this feature is done".
- If the ledger path or state-machine definition isn't extracted, halt before transitioning rows.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Migration`.
>
> - **Ledger path**: `ai/migration/ledger.md` (default; override only with strong reason)
> - **Feature inventory source**: `<extracted>` (e.g., V1 module list at `Reports/views.py`'s function tree, route table, top-level controllers)
> - **Update cadence**: on every PR that transitions a feature; weekly review by migration owner
> - **Owner**: `<extracted>` (the engineering owner of the migration; default = the team owning the V2 root)

The ledger is the **single source of truth** for migration state. Its existence converts a multi-month migration from "vibes-based" tracking (Slack threads, Jira tickets, half-remembered conversations) to a checkable, queryable artifact. Phase 5 verification of any port PR fails if the ledger is not updated.

## State machine

```
   ┌──────────┐                                                                        ┌──────────┐
   │  V1-only │  initial state for every feature in the inventory                      │  Halted  │  any phase can halt
   └────┬─────┘                                                                        └────▲─────┘
        │ /port-feature claims this feature                                                 │   any failed gate
        ▼                                                                                   │
   ┌──────────┐  contract written; V1 commit pinned; plan written                           │
   │ In-progress │ ──────────────────────────────────────────────────────────────────────── │
   └────┬─────┘                                                                             │
        │ V2 code merged; parity tests green                                                │
        ▼                                                                                   │
   ┌──────────┐  V1 serves; V2 receives shadow; outputs compared offline                    │
   │ V2-shadow │ ─────────────────────────────────────────────────────────────────────────  │
   └────┬─────┘                                                                             │
        │ shadow-mismatch rate ≤ threshold for ≥7d                                          │
        ▼                                                                                   │
   ┌──────────┐  1% → 10% → 50% canary stages                                               │
   │V2-canary │ ─────────────────────────────────────────────────────────────────────────── │
   └────┬─────┘                                                                             │
        │ all canary gates green; 100% rollout sustained for observation window             │
        ▼                                                                                   │
   ┌──────────┐  V2 serves 100%; V1 path retained but idle                                  │
   │ V2-only  │ ─────────────────────────────────────────────────────────────────────────── │
   └────┬─────┘                                                                             │
        │ ≥14d zero V1 traffic; dead-code-finder confirms no V1 imports                     │
        ▼                                                                                   │
   ┌──────────┐  terminal state                                                             │
   │V1-deleted│                                                                             │
   └──────────┘                                                                             │
```

**Halted** is reachable from any of `In-progress` / `V2-shadow` / `V2-canary` / `V2-only` on a gate failure. Halted features have a root-cause file in `ai/migration/halts/<feature>-<date>.md` and are unblocked back to a prior state once the cause is fixed.

## Per-feature record shape

Each feature is a markdown section in `ai/migration/ledger.md`:

```markdown
## <feature-name>

```yaml
state: V2-shadow                          # one of the states above
owner: alice@team
v1_path: Reports/views.py:report_orders   # entry point (function / class / route)
v2_path: src/reports/orders/handler.ts    # entry point
v1_commit_pinned: 7a3b9c1                 # the V1 commit the parity tests run against
contract: ai/migration/contracts/report-orders.md
plan: ai/migration/plans/report-orders.md
parity_tests: tests/parity/report-orders/
parity_runs:                              # most-recent first
  - id: 2026-04-26T14:22Z
    result: green
    tolerance_overrides: []
perf_decisions: ai/migration/perf-decisions/report-orders.md
shadow_started: 2026-04-20
shadow_mismatch_rate: 0.0001              # 0.01% — well under threshold
canary_started: null
canary_stage: null
cutover_stage_targets:                    # configured plan
  shadow_min_days: 7
  canary_stages: [1, 10, 50, 100]
  v1_idle_min_days: 14
related_adrs:                             # for any intentional contract break
  - ADR-007: drop deprecated `legacy_id` field on response
dependencies:                             # other features that must be done first
  - getUser    # V2-only ✓
  - getOrders  # V2-only ✓
notes: |
  Shadow rate is healthy. One tolerance override added for a millisecond-level
  timestamp diff; recorded in parity_runs.tolerance_overrides.
```
```

The YAML frontmatter is the canonical, machine-readable per-feature record. The free-text `notes:` block is for humans; the structured fields are for `/migration-status` + parity-auditor + Phase 5 verification.

## Extended states (M12 — phased flow)

The phased flow (`/migration-scan` → `/migration-plan` → `/migration-phase` → `/migration-gate` → `/migration-final`) introduces three additional terminal/lateral states that compose with the original state machine:

| State | Meaning | How it's set |
|---|---|---|
| `unverified` | Status reset by `/migration-scan` — trust nothing. Re-verified before any flip to `done`. | `/migration-scan` |
| `parked` | Feature is set aside (decision pending / third-party blocker / arch-debt). Excluded from current phase scope. Reversible via `/migration-unpark`. | `/migration-park` |
| `deprecated` | V1 feature being killed in V2. Never going to be ported. **Permanent — no undeprecate.** | `/migration-deprecate` (requires ADR) |
| `failed` | Verify step failed; needs attention. Blocks `/migration-gate <N>`. | `/migration-phase <N>` (verify failure) |
| `rolled-back` | Phase containing this feature was reverted via `/migration-rollback <N>`. Returns to prior state automatically. | `/migration-rollback <N>` |

These compose with the original state machine — a feature in `V2-shadow` can be `parked` (status takes precedence; restored via `/migration-unpark`).

## New fields (M12 — phased flow)

These fields extend the YAML record. All optional; populated only when relevant.

```yaml
# --- Park / unpark ---
parked_reason: |                    # required when status=parked
  <one paragraph>
parked_blocker: decision-pending    # one of: decision-pending | third-party | arch-debt | adr-needed | other
parked_at: 2026-04-28T15:32:00Z
prior_status: unverified            # restored on /migration-unpark
prior_phase: 4
unparked_at:                        # set when /migration-unpark runs
unparked_reason:

# --- Deprecation (terminal; permanent) ---
deprecated_at: 2026-04-28T16:00:00Z
deprecated_by: <user>
deprecation_adr: ADR-0042           # mandatory; must be Accepted status
deprecation_reason: |               # mandatory; non-trivial
  <full text>
tenant_impact: low                  # required for multi-tenant projects: low | medium | high
v1_sunset_date: 2026-05-15          # when V1 stops serving this

# --- Per-feature cutover (overrides project default) ---
cutover_mechanism: shadow-read       # one of: feature-flag | strangler | dns-swap | blue-green | parallel-write | shadow-read | sticky-session | direct
cutover_progress: 50%                # 0% | 10% | 50% | 100% — for incremental ramp

# --- Composition (split / merge) ---
composes:                            # this feature is composed FROM these V1 features (1 V2 ← N V1)
  - F042
  - F043
  - F044
composite_of:                        # this V1 feature is decomposed INTO these V2 features (1 V1 → N V2)
  - F101
  - F102

# --- Soft-parity tolerance ---
soft_parity_tolerance:               # axes where exact parity isn't required (avoids ADR-per-cosmetic-diff)
  - timestamp_format
  - error_message_wording
  - currency_rounding   # ≤1 cent diff acceptable

# --- Phased flow tracking ---
phase: 4                             # which plan phase owns this feature
phase_passed_at: 2026-04-28T17:00:00Z
audit_findings: ai/migration/audits/F042.md
intentional_break: ADR-0017          # ADR cited for behavior divergence (when not just soft-parity-tolerance)
```

## Required fields per state

| State | Required fields |
|---|---|
| V1-only | feature-name, owner (can be `unassigned`), v1_path |
| In-progress | + contract, plan, v1_commit_pinned |
| V2-shadow | + v2_path, parity_tests, parity_runs (≥1 green), shadow_started |
| V2-canary | + canary_started, canary_stage, shadow ran for ≥ shadow_min_days clean |
| V2-only | + cutover_complete date, observation_window_started |
| V1-deleted | + v1_idle_observed_days ≥ 14, deletion_pr_link |
| Halted | + halt_reason, halt_root_cause_file, halt_recovery_plan |

A PR transitioning a feature to a state without that state's required fields is rejected by Phase 5 verification.

## Automation hooks

- **`/port-feature`**: when invoked on a feature, sets state `In-progress`, fills `v1_commit_pinned` (current `git rev-parse HEAD` on V1's branch), `contract`, `plan` paths.
- **`/migration-status`**: reads ledger; reports per-state counts, oldest in each state, blocked-on-dependency list, perf-uplift summary.
- **CI hook**: on PR merge to main, if any file under `ai/migration/contracts/` or `ai/migration/plans/` or `<v2-root>/<feature>/` was touched, verify ledger row touched in same PR. Fail PR otherwise.
- **`parity-auditor` agent**: at PR review time, reads the ledger row referenced by the PR, verifies the parity-run referenced is recent + green, verifies V1 commit pinned matches actual V1 path's last touched commit.
- **Weekly cron**: emit a `migration-status` report to a designated channel; flag stalled rows (in `In-progress` for >30d, in `V2-shadow` for >14d).

## Reporting views (`/migration-status`)

```text
$ /migration-status
Migration progress (12 features total):

  V1-only:    3   (waiting)
  In-progress: 2   (alice: report-orders day 4 of <30 SLA; bob: getUser day 2)
  V2-shadow:  4   (avg shadow age 5d, mismatch rates: 0.0001/0.0/0.002/0.0)
  V2-canary:  1   (auth-flow @ 50%, day 1)
  V2-only:    1   (health-check, in 14d observation, day 8)
  V1-deleted: 1
  Halted:     0

Blocked on dependency:
  - searchOrders → waiting on getUser (V2-shadow)

Stalled (>30d in same state):
  - admin-export (In-progress, day 35) — owner: charlie

Perf uplift this quarter:
  - 7 features ported; 12 perf candidates applied; 4 deferred; 1 rejected.
  - Aggregate: -42% p95 latency, -68% queries/call, +18% cache-hit rate, 3 indexes added.
```

## Drift detection

The ledger MUST agree with reality. Phase 5 verification flags:

- **Code says V2-only but V1 path still has code**: ledger row stale.
- **Ledger says V2-shadow but no shadow report in last 7d**: shadow infra broken or stale.
- **Ledger references parity-test file that doesn't exist**: ledger lying.
- **Two features claim the same v1_path**: feature taxonomy is wrong; resolve before any port.
- **A feature in canary >7d without stage advance**: stuck — owner must explain or roll back.
- **A feature in V2-shadow with mismatch_rate trending up**: parity regression — investigate.

## Bootstrap (first time the ledger is created)

`/setup-project` Phase 4.2 (when migration pack is loaded) generates the initial ledger by:

1. Reading `_extracted-codebase.md § Migration § Feature inventory` (the V1 module / route / function inventory captured in Phase 2).
2. Creating one ledger row per feature with state `V1-only` and the v1_path filled in.
3. Leaving `owner: unassigned` — the migration owner assigns owners per their team's process.
4. Writing the ledger header section (state machine reference, automation reference, this pattern's link).

If the project already has a partial ledger (e.g., user maintained it manually before adopting this pack), Phase 4.2 merges: features in extraction but not the ledger are added; features in the ledger but not extraction are flagged for review.

## Pitfalls (named)

- **Slack-as-ledger**: tracking migration state in chat threads. Decays in days. The ledger replaces it.
- **Per-feature state file sprawl**: one file per feature works for 3 features; at 30 features, one consolidated `ledger.md` is queryable by Phase 5 + cron, while 30 files aren't.
- **State invented mid-migration**: someone introduces a `Pre-shadow` or `Half-canary` state without updating this pattern. The state machine is the contract — extending it is an ADR + this pattern revision, not a free-form ledger edit.
- **Owner = team alias**: "owned by `@backend-team`" → nobody is on the hook. Owner is a person; teams are recorded separately if needed.
- **Skipping the dependency graph**: porting a feature whose dependencies aren't `V2-only` yet is a guarantee of rework. Dependency check happens in `/port-feature` Phase 1.
- **Ledger committed once, then forgotten**: the ledger lives or dies with the discipline of updating it on every PR. The CI hook makes this enforceable.
