---
description: Regenerate the phased migration plan from the current ledger state. Run when the original plan has aged out (codebase changed, V1 features added/dropped, prior phases revealed wrong sequencing). Preserves `done` rows; recomputes phasing for the rest.
kind: command
pack: migration
---

# /migration-replan

## The Premise (read this first)

**Read before writing. Cite real V1 paths, never invented.** Replan reads the current ledger + history + failures-catalog and rewrites `plan.md` — preserving every `done` row's original phase number and re-phasing only the rest. Every re-phased row's `v1_path` and `v2_path` must still point at real files (or `<unmapped>` for explicit gaps). Don't paraphrase V1 paths from memory. If the ledger has aged out (V1 changed materially), halt and run `--re-scan-first` instead of guessing.

The plan written on day 1 doesn't survive contact with reality. By phase 3, the codebase has changed, V1 may have shifted, dependencies may have surfaced. Replan reads the current ledger and produces a fresh `ai/migration/plan.md` for everything still in flight.

## When to use

- A phase took 3× longer than estimated → other phase estimates need recalibration.
- New V1 features landed since the original scan → ledger has new `unverified` rows that need phasing.
- A phase revealed a hidden dependency that should have been in foundation but wasn't → reorder.
- After `/migration-rollback <N>` → previous plan's assumptions are stale.
- After `/migration-park <feature>` accumulated 5+ parked features → re-plan once they're unparked.

## When NOT to use

- A single feature failed → use `/migration-phase <N> --feature=<id>` to retry.
- The plan is fresh (run today) → no replan needed.

## Pre-requisites

- `ai/migration/ledger.md` exists.
- `ai/migration/plan.md` exists (replan rewrites it).

## Phase 1 — Understand (the ask)

Inputs:
- `ai/migration/ledger.md` — current feature inventory + status.
- `ai/migration/plan.md` (existing) — the plan being replaced.
- `ai/migration/_history.md` — phases passed; phases rolled-back.
- `ai/migration/scan-report.md` — original structural analysis.
- `ai/_baseline/failures/` — recent failures (rollbacks contribute here).

Optional flags:
- `--re-scan-first` — runs `/migration-scan` before replanning. Use when V1 has changed materially since last scan.
- `--phases=<N>` — target number of remaining phases.
- `--preserve-passed` (default true) — keep `phase_passed` rows in the same phase number; renumber only future phases.

## Phase 2 — Organize (decompose the work)

Replan strategy:

1. **Categorize ledger rows by status:**
   - `done` (phase passed) → preserve in their original phase numbers.
   - `parked` → eligible for next phase if user signals readiness; otherwise stay parked.
   - `deprecated` → exclude from plan (V1 feature being killed, not ported).
   - `unverified`, `in-flight`, `failed` → re-phase.

2. **Re-evaluate dependency graph** for the rows being re-phased. Dependencies may have shifted since original plan (V2 has new helpers; some V1 features got deprecated).

3. **Honor failures-learned.** If `_history.md` shows phase N rolled back due to "auth-foundation incomplete," the replanned phase 1 expands to cover the gap.

4. **Renumber only future phases.** Past passed phases keep their numbers. New phases are `<last-passed> + 1`, `<last-passed> + 2`, etc.

## Phase 3 — Retrieve (read the right context)

- Current ledger.
- History (passed + rolled-back).
- Failure catalog entries from rollbacks.
- ADRs that constrain phase ordering (e.g., ADR-0017 says auth must use new-lib; that affects which features can ship together).

## Phase 4 — Generate (produce the output)

Rewrite `ai/migration/plan.md`. The structure stays the same (per-phase tables) but content is fresh:

```markdown
# Migration plan — V1 → V2 (replanned <YYYY-MM-DD>)

Generated: <YYYY-MM-DD>
Triggered by: /migration-replan
Replaces: previous plan (rev <commit>)

## Replan summary
- Passed phases (preserved):  <K>     (numbered 1..K — unchanged)
- Active features re-phased:  <M>
- Newly added (since scan):   <N>
- Deprecated (excluded):      <D>
- Parked (deferred):          <P>

## Phases 1..K (passed — unchanged for traceability)
<links to history entries; details abbreviated>

## Phase K+1 — <new domain>
(per-phase tables as before)

## Phase K+2 — <next domain>
...

## What changed vs previous plan
| Concern | Previous plan | Replanned |
|---|---|---|
| Phase 5 contents | order-export, order-archive | order-export only (order-archive deprecated per ADR-0042) |
| New phase 6 | n/a | added: 12 features that didn't exist at original scan |
| Re-sequenced | payments before reporting | reporting before payments (payment foundation incomplete) |
| Re-grouped | auth split across 1+2 | auth consolidated in phase 1 |
```

Also:

### Update `ai/migration/_history.md` (append-only)

```
<ts> | replan | features-re-phased: <M> | reason: <user-supplied>
```

Reason is mandatory. Logged for audit trail.

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/migration/plan.md` — rewritten (managed-block; safe to re-run).
- Ledger rows updated with new `phase: <N>` assignments.
- `_history.md` appended.
- Original plan archived to `ai/migration/_plan-archive/plan-<previous-ts>.md` for reference.

## Phase 6 — Validate (verify correctness)

- `done` rows still have their original phase numbers.
- Every active feature is assigned to a phase.
- Phase ordering respects dependency graph (foundation features are in earlier phases than dependents).
- Phase numbers are contiguous (no gap between K and K+2 with K+1 missing).
- ADR-cited constraints are honored.

## Phase 7 — Improve (feed the learning loop)

- If estimates from prior phases diverged from actuals by >50% → log to `ai/_baseline/failures/` for future estimate calibration.
- If recurring "this should have been in phase 1" patterns → propose `ai/patterns/migration-foundation-checklist.md`.
- If certain feature classes consistently get re-phased → flag for the architecture team (V2's structure may not fit those features cleanly).

## Output to user

```
Replan complete:
  Original plan:        archived to ai/migration/_plan-archive/
  New plan:             ai/migration/plan.md
  Passed phases kept:   <K> (numbers preserved)
  Re-phased features:   <M>
  New features:         <N>
  Deprecated:           <D>
  Parked:               <P>

Reason logged: <user-supplied>

Next: /migration-phase <K+1>   (continue with the new plan from the next un-passed phase)
```

## Mechanical halt — refuse to renumber passed phases or invent rows

Before writing the new plan: (1) every `done` row keeps its original phase number — verify by diffing old plan vs new plan for `phase_passed_at` rows; if any moved, halt. (2) Every re-phased row traces to a current ledger entry — no invented rows. (3) `--reason` is mandatory and lands in `_history.md`; refuse the run without it. (4) If the prior plan archive at `_plan-archive/` cannot be written (path missing, permissions), halt — replan does not proceed without preserving the audit trail.

## Hard rules

- **Passed phases NEVER renumber.** Ledger rows with `phase_passed_at` set keep their original phase number, even if the new plan would order them differently.
- **Reason is mandatory.** Replan triggers a one-line user-supplied reason in `_history.md`.
- **Original plan archived, never deleted.** `_plan-archive/` is the audit trail of how the plan evolved.
- **No silent renumbering.** If `done` rows are kept in phase N but new active rows want to be in phase N too, that's allowed — phases CAN have a mix of done + active rows.
- **Deprecated rows excluded.** `status: deprecated` features don't appear in any phase.
- **Parked rows wait.** `status: parked` features are excluded from the new plan unless `--unpark-all` is passed.

## Related

- `/migration-plan` — produced the original plan being replaced.
- `/migration-rollback <N>` — common reason replan is needed (rollback invalidates plan assumptions).
- `/migration-unpark <id>` — unparking 3+ features is a strong signal to replan.
- `/migration-scan` — run with `--re-scan-first` flag if V1 has materially changed.
- `ai/migration/_plan-archive/` — where this command archives the previous plan.
