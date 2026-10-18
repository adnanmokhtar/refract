---
description: Read ai/align/ledger.md and report per-finding state, blockers, stalled rows, and aggregate progress per phase. Read-only — never modifies the ledger. Run on demand. Stack-agnostic.
kind: command
pack: align
allowed-tools: [Read, Grep, Glob, Bash, Task]
---

# /align-status

## Phases applied

**1, 3, 6** — Diagnostic / read-only per `templates/canonical-command-template.md` § Phase selection. Phase 2 (Organize) N/A — there is no work to decompose, only state to read. Phase 4 (Generate) N/A — the output is a report, not an artifact the project keeps. Phase 5 (Update) N/A — **zero writes**: no ledger, source or halt-file modification. Phase 7 (Improve) N/A — this command reads the loop, it does not feed it.

## The Premise (read this first)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — finding-class vocabulary including `solid-violation` (single source of truth).

**Read-only progress reader.** This command does NOT modify the ledger, source, or any artifact. It reports the current state of the alignment effort across all phases — per-finding status, per-phase progress, stalled rows, halted rows, HIGH rows (permission, tenant or auth gates) awaiting fixes, owner rows routed out, perf or data carve-out rows without a measured baseline. Use it to surface drift, surface blockers, surface readiness for the next phase.

## When to use

- Daily / weekly check during an active alignment effort.
- Before invoking `/align-phase <N+1>` to confirm phase N is closed.
- After `/align-rollback` to confirm the ledger reflects the rollback.
- On demand, whenever you need the current picture. **There is no scheduler in the shipped baseline**: no cron, no auto-invoking post-task hook, and the git hooks (`.claude/hooks/post-merge-learn.sh`, invoked by the `.claude/git-hooks/post-merge` shim) only append review hints to `ai/dynamic/.review-queue` — they invoke nothing. To get a recurring report, a human runs this command or wires it into their own scheduler.

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
- `--class=<list>` — filter by AL class (e.g., `--class=AL-15,AL-11` for the gate and wrapper rows). A legacy class name in an old ledger is read through `ai/patterns/align-ledger.md § Legacy class names`.
- `--stalled` — show only rows older than the SLA. Defaults: any `in-progress` row > 7d · any `halted` HIGH row (an AL-15 permission, tenant or auth gate) > 24h · **any `parked` row past its `parked_unpark_after`** · **any `parked` row > 90d** · **any `parked` HIGH row whose age from `parked_sla_from` exceeds 24h** · **any `parked` row missing `prior_status` / `prior_phase`** (unrevivable — no command can restore it).
- `--blockers` — show only halted rows + parked rows, each with its age and its blocker category.

**Parked rows are aged, not just counted.** A parked row is the only kind that leaves every other escalation in the pack: the gate stops blocking on it, its halt file moves out of `halts/`, and any SLA keyed on `halted` stops firing. If this command reports parked rows as a bare number, a dropped permission gate parked six months ago looks exactly like a misnamed file parked yesterday. Age a parked HIGH row from `parked_sla_from`, never from `parked_at` — otherwise parking silently resets the clock. See `ai/patterns/align-guardrails.md § Named anti-patterns → The Silent Park`.
- `--summary` — single-line per phase (compact view).
- `--json` — emit machine-readable output for downstream tooling.

## Phase 2 — Organize (decompose the work)

Read ledger + halts + gate-history; aggregate by phase; surface in priority order:
1. HIGH rows halted or parked (any age): a permission, tenant or auth gate.
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
  ! A047 (AL-15 permission gate, HIGH, heavy, halted 18h)
       Reason: add-gate verb halted; the oracle names <Can>, but no orders.refund ability is declared.
       Remediation: run /setup-project --refine to declare the ability; parking needs --override-high.
  ! A082 (AL-11 raw primitive, standard, halted 6h)
       Reason: re-detect failed; the fix introduced a NEW abstraction.
       Remediation: re-run the verb as replace-with-shared; OR run /align-park A082 with rationale.

────────────────────────────────────────
Phase progress
────────────────────────────────────────
  Phase 1 (oracle and ratchets)       [done]    5/5 fixed, gate PASS
  Phase 2 (raw imports, AL-11/22)     [done]    4/4 fixed, gate PASS
  Phase 3 (gates and props, AL-15)    [active]  6/10 fixed, 2 halted, 2 in-progress
  Phase 4 (naming, AL-16/17)          [pending] 0/8
  Phase 5 (token snaps, EQ rows)      [pending] 0/15
  ...

────────────────────────────────────────
Class breakdown (cumulative across all phases)
────────────────────────────────────────
  Align (AL ids; one line per class with rows):
    AL-11 raw primitive    fixed: <F>/<N>
    AL-15 prop / gate      fixed: <F>/<N>  (HIGH: <Hf>/<Hn>)
    AL-16 file names       fixed: <F>/<N>
    AL-29 suppressions     fixed: <F>/<N>
    ...
  Reports (0 ledger rows): AL-02 splits <s> · AL-04 doc stale <d> · pending-ratification <t>
  Routed to owners (graded there, never closed here):
    ui-ux <u> · frontend <f> · code-quality <q> · backend <b> · security <x>

────────────────────────────────────────
Stalled rows (in-progress > 7d)
────────────────────────────────────────
  <none>   — OR —
  A032 (AL-16 file name, standard, in-progress 9d)
        Last touched: 2026-04-22
        Phase 4 (naming, AL-16/17)
  A056 (AL-29 suppression, trivial, in-progress 12d)
        Last touched: 2026-04-19
        Phase 1 (oracle and ratchets)

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

**Dispatch `@align-ledger-auditor` for this step.** It reconciles in both directions — a row marked `fixed` with no commit, AND a commit carrying a row id the ledger has no row for — checks state-machine legality, and applies the SLA thresholds below. This command is the read-only view over its report; it does not perform the reconciliation itself, so that `/align-final` and `/align-replan` get the identical answer.

## Phase 7 — Improve (feed the learning loop)

- If a halted row's reason has appeared 3+ times across phases (e.g., "idiom not found"), surface "queue ADR for `/setup-project --refine` to fill the gap".
- If `Days since last gate PASS` > 30, surface "alignment effort stalling; consider re-scoping or `/align-replan`".
- If a row has been in-progress > 14 days, surface "consider `/align-park <id>` to defer with rationale, OR `/align-rollback <N>` to restart the phase".

## Output to user

The report itself (above). No summary line.

## Hard rules

- **Read-only.** This command writes nothing (except optionally to `status-history.md`).
- **No interpretation beyond stalled / halted thresholds.** The command reports facts; the user decides what to do.
- **No filtering by user input modifies the actual ledger.** `--class=AL-15` filters the view; the ledger is unchanged.

## Failure modes

- **Ledger missing or corrupt** — halt; route to `/align-scan` (or `git restore` for ledger).
- **Halt files orphaned** (halt file exists but ledger row says fixed) — surface as ledger drift.
- **Gate history claims a phase passed but ledger has detected rows in that phase** — surface as ledger drift.
- **Plan file missing** (ledger has `phase: <N>` but no plan) — surface as plan drift; recommend `/align-plan`.

## Related

### Agents
- `.claude/agents/align-ledger-auditor.md` — owns the reconciliation this command reports. Dispatch it to produce the drift, illegal-transition, SLA, and systemic sections; this command formats and filters what it returns.

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
