---
description: Read ai/align/ledger.md and report per-finding state, blockers, stalled rows, and aggregate progress per phase. Read-only — never modifies the ledger. Run on demand or via weekly cron. Stack-agnostic.
kind: command
pack: align
---

# /align-status

## The Premise (read this first)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — finding-class vocabulary including `solid-violation` (single source of truth).

**Read-only progress reader.** This command does NOT modify the ledger, source, or any artifact. It reports the current state of the alignment effort across all phases — per-finding status, per-phase progress, stalled rows, halted rows, security findings awaiting fixes, perf findings without baselines. Use it to surface drift, surface blockers, surface readiness for the next phase.

## When to use

- Daily / weekly check during an active alignment effort.
- Before invoking `/align-phase <N+1>` to confirm phase N is closed.
- After `/align-rollback` to confirm the ledger reflects the rollback.
- As a scheduled cron task (`/schedule align-status weekly`) to surface drift and stalled rows automatically.

## When NOT to use

- As a substitute for `/align-gate` — status reports state, gate validates exit criteria.
- Mid-fix in `/align-phase` — the ledger is mid-update; results are noisy.

## Pre-requisites

- `ai/align/ledger.md` exists.

If pre-requisites missing → halt + tell user to run `/align-scan` first.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/align/ledger.md` — full finding inventory.
- `ai/align/plan.md` (if exists) — phase definitions.
- `ai/align/halts/` — halt registry.
- `ai/align/gate-history.md` (if exists) — past gate verdicts.
- `_session-digest.md` — last update timestamp.

Optional flags:
- `--phase=<N>` — report only for phase N (default: all phases).
- `--class=<list>` — filter by finding class (e.g., `--class=security` for security-only report).
- `--stalled` — show only rows older than the SLA (default: any `in-progress` row > 7d, any `halted` row > 24h, any `halted` security row > 12h).
- `--blockers` — show only halted rows + parked rows.
- `--summary` — single-line per phase (compact view).
- `--json` — emit machine-readable output for downstream tooling.

## Phase 2 — Organize (decompose the work)

Read ledger + halts + gate-history; aggregate by phase; surface in priority order:
1. Critical security halted (any).
2. Halted rows > 24h.
3. Halted rows < 24h.
4. Stalled `in-progress` rows.
5. Phase progress summary.
6. Class breakdown.

## Phase 3 — Retrieve (read the right context)

- Ledger entries.
- Halt files (one per halted row).
- Gate-history line per past gate run.

No source-reading; this is purely reporting.

## Phase 4 — Generate (produce the output)

Default report:

```
Align status — <YYYY-MM-DD>

PROJECT_KIND: <kind>
Last scan:    <YYYY-MM-DD>
Last gate:    phase <N> PASS at <YYYY-MM-DD>
Total findings: <N> (across <K> phases)

────────────────────────────────────────
Critical / blocked
────────────────────────────────────────
  <none>   — OR —
  ! A047 (security/sql-injection, heavy, halted 18h)
       Reason: parameterize verb halted; idiom not found in _extracted-idioms.md.
       Remediation: run /setup-project --refine to add the parameterized-query primitive.
  ! A082 (performance/n-plus-one, standard, halted 6h)
       Reason: re-detect failed; the fix introduced a NEW abstraction.
       Remediation: re-classify as /refactor; OR run /align-park A082 with rationale.

────────────────────────────────────────
Phase progress
────────────────────────────────────────
  Phase 1 (mechanical cleanup)        [done]    12/12 fixed, gate PASS
  Phase 2 (security critical)         [done]    4/4 fixed, gate PASS
  Phase 3 (security standard)         [active]  6/10 fixed, 2 halted, 2 in-progress
  Phase 4 (mechanical / silent-catch) [pending] 0/8
  Phase 5 (auth UI/UX)                [pending] 0/15
  ...

────────────────────────────────────────
Class breakdown (cumulative across all phases)
────────────────────────────────────────
  Structural:
    dead-code              fixed: <F>/<N>
    duplicated-logic       fixed: <F>/<N>
    reinvented-wrapper     fixed: <F>/<N>
    silent-catch           fixed: <F>/<N>
    over-abstraction       fixed: <F>/<N>
    drift                  fixed: <F>/<N>
  Functional:
    solid-violation        fixed: <F>/<N>
    clean-code             fixed: <F>/<N>
    performance            fixed: <F>/<N>
    security               fixed: <F>/<N>  (critical: <Cf>/<Cn>, high: <Hf>/<Hn>)
  Frontend (PROJECT_KIND=frontend-*):
    a11y-violation         fixed: <F>/<N>
    design-token-drift     fixed: <F>/<N>
    i18n-key-drift         fixed: <F>/<N>
    ...

────────────────────────────────────────
Stalled rows (in-progress > 7d)
────────────────────────────────────────
  <none>   — OR —
  A032 (drift, standard, in-progress 9d)
        Last touched: 2026-04-22
        Phase 5 (auth UI/UX)
  A056 (clean-code, trivial, in-progress 12d)
        Last touched: 2026-04-19
        Phase 8 (clean-code)

────────────────────────────────────────
Aggregate
────────────────────────────────────────
  Fixed:                <F> / <N>  (<%>)
  Verified (gated):     <V> / <F>
  Archived:             <A>
  Halted:               <H>
  Parked:               <P>
  In-progress:          <I>
  Detected (queued):    <D>

  Cumulative diff (across verified phases):
    Lines added:        <added>
    Lines removed:      <removed>
    Net:                <net>  (structural net: <struct-net>, functional net: <func-net>)

  Days since last gate PASS: <D>
  Recommended next: /align-phase <N+1>   OR   /align-fast <N+1>
```

## Phase 5 — Update (persist changes)

This command is read-only. **Zero writes.** No ledger modification, no source modification, no halt-file modification.

Optional: writes a single line to `ai/align/status-history.md` recording the timestamp + summary, for trend analysis. (Disable with `--no-history`.)

## Phase 6 — Validate (verify correctness)

- Every halted row has a corresponding `ai/align/halts/<id>.md`.
- Every fixed row has a `commit` field.
- Every verified row's commit exists in git history.
- Phase progress percentages sum correctly.

If any cross-reference fails → surface as a "ledger drift" warning at the top of the report (the ledger says X but git history says Y).

## Phase 7 — Improve (feed the learning loop)

- If a halted row's reason has appeared 3+ times across phases (e.g., "idiom not found"), surface "queue ADR for `/setup-project --refine` to fill the gap".
- If `Days since last gate PASS` > 30, surface "alignment effort stalling; consider re-scoping or `/align-replan`".
- If a row has been in-progress > 14 days, surface "consider `/align-park <id>` to defer with rationale, OR `/align-rollback <N>` to restart the phase".

## Output to user

The report itself (above). No summary line.

## Hard rules

- **Read-only.** This command writes nothing (except optionally to `status-history.md`).
- **No interpretation beyond stalled / halted thresholds.** The command reports facts; the user decides what to do.
- **No filtering by user input modifies the actual ledger.** `--class=security` filters the view; the ledger is unchanged.

## Failure modes

- **Ledger missing or corrupt** — halt; route to `/align-scan` (or `git restore` for ledger).
- **Halt files orphaned** (halt file exists but ledger row says fixed) — surface as ledger drift.
- **Gate history claims a phase passed but ledger has detected rows in that phase** — surface as ledger drift.
- **Plan file missing** (ledger has `phase: <N>` but no plan) — surface as plan drift; recommend `/align-plan`.

## Related

### Sibling commands in align pack
- `/align-scan` — produces the ledger this reads.
- `/align-plan` — produces the plan this reads.
- `/align-phase <N>` — modifies rows; this reads them.
- `/align-gate <N>` — produces gate-history this reads.
- `/align-park <id>` — parks a halted row.
- `/align-rollback <N>` — undoes a phase.
- `/align-final` — final cross-phase report (this command's read-only sibling for end-of-effort).

### Patterns
- `ai/patterns/align-ledger.md` — schema this command reads.
