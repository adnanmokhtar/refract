---
description: Roll back a migration phase. Restores ledger + audits + ported files to their state before /migration-phase <N> was run. Uses Phase 0 backups + git history + per-phase manifest. Read-confirm-execute pattern; never silent.
kind: command
pack: migration
---

# /migration-rollback <N>

The safety net. Use when a shipped phase produces a regression in production OR when a phase reveals it was the wrong direction. Restores phase N's pre-run state.

## When to use

- A regression surfaced after `/migration-gate <N>` passed.
- Production traffic on V2 is failing for features in phase N.
- A planning error means phase N's approach was wrong; need to redo from scratch.
- A phase shipped with `intentional-break` ADRs you've since revoked.

## When NOT to use

- A single feature regressed → use `/migration-phase <N> --feature=<id>` to re-port that one.
- The ledger is correct but production state is wrong → use deployment rollback, not migration rollback.
- Phase < 1 or phase > current-max → halt; nothing to roll back.

## Pre-requisites

- Phase N was previously executed via `/migration-phase <N>`.
- Phase N's pre-run snapshot exists in `.claude/backups/migration-phase-<N>-<ts>/`.
- The ledger has rows assigned to phase N.

If pre-run snapshot is missing → halt; tell user that this phase was either:
- Shipped before rollback support existed (M11 or earlier), OR
- The backup was deleted by user (`.claude/backups/` is sacred — see N20).

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — phase to roll back (required).
- `ai/migration/plan.md` § Phase N — what was supposed to happen.
- `ai/migration/_history.md` — when phase N ran + passed.
- `.claude/backups/migration-phase-<N>-<ts>/` — pre-run snapshot.

Optional flags:
- `--keep-audits` — preserve `ai/migration/audits/` files even though ledger rows revert. Useful when the audit findings are still valuable for the next attempt.
- `--dry-run` — show what would be rolled back; write nothing.

## Phase 2 — Organize (decompose the work)

Rollback scope (per phase N feature):
1. **Ledger row** — revert `status`, `parity_test`, `phase_passed_at`, `ported_in_phase` to pre-phase values.
2. **Ported files** — restore from snapshot (managed-block content reverted; user-authored sections OUTSIDE markers are preserved as-is).
3. **Audit files** — `ai/migration/audits/<feature-id>.md` removed unless `--keep-audits`.
4. **Perf decisions** — `ai/migration/perf-decisions/<feature-id>.md` removed unless cited by a still-Accepted ADR.
5. **Phase history entry** — `_history.md` gets an append-only `<ts> | phase <N> | rolled-back` line. The original PASS entry stays (audit trail).

## Phase 3 — Retrieve (read the right context)

- Pre-run snapshot tree.
- Current state of every file the snapshot covers.
- ADRs cited as `intentional-break: ADR-NNNN` for any phase-N feature — verify each ADR's status (Accepted / Superseded / Rejected) before reverting.

## Phase 4 — Generate (produce the output)

For each feature in phase N:

```
For F in phase_N_features:
    snapshot_path = .claude/backups/migration-phase-<N>-<ts>/<F.target>
    current_path = <F.target>

    if --dry-run:
        diff snapshot_path current_path  # show what reverts

    else:
        # 1. Restore file content (managed blocks revert; user content preserved)
        revert_managed_blocks(current_path, from=snapshot_path)

        # 2. Revert ledger row
        revert_ledger_row(F.id, to=snapshot_state)

        # 3. Remove audit file unless --keep-audits
        if not --keep-audits:
            rm ai/migration/audits/<F.id>.md

        # 4. Remove perf-decision file unless ADR-cited
        if not has_active_adr(<F.id>):
            rm ai/migration/perf-decisions/<F.id>.md

# 5. Append rollback entry
echo "<ts> | phase <N> | rolled-back | features: <Y> | reason: <user-supplied>" >> ai/migration/_history.md
```

The user is prompted for a one-line reason (logged in `_history.md`). Cannot be skipped — the audit trail requires it.

## Phase 5 — Update (persist changes to the knowledge base)

- Ledger rows reverted (managed-block update).
- `_history.md` appended (never edits prior entries).
- Backup directory `.claude/backups/migration-phase-<N>-<ts>/` is **NOT deleted** — keep it for possible re-rollback.

## Phase 6 — Validate (verify correctness)

- Every phase-N feature's ledger row matches snapshot state.
- Every reverted file matches its snapshot byte-for-byte (within managed blocks).
- User-authored sections (outside markers) are byte-identical to current state — never touched.
- ADRs cited by `intentional-break` rows are flagged for review (status may need to change to `Superseded` if the rollback invalidates them).

## Phase 7 — Improve (feed the learning loop)

- Append failure-catalog entry: `ai/_baseline/failures/<NNNN>-phase-<N>-rollback.md` with the user-supplied reason + observable behavior that triggered rollback.
- The next `/migration-replan` will read this failure entry and avoid the same approach.

## Output to user

```
Phase <N> rolled back:
  Features reverted:    <Y>
  Files restored:       <F>
  Audits removed:       <A>   (or 0 if --keep-audits)
  Perf decisions kept:  <P>   (ADR-cited)

History:
  ai/migration/_history.md (rollback entry appended)

Backup preserved:
  .claude/backups/migration-phase-<N>-<ts>/ (kept for possible re-rollback)

Next steps:
  - Investigate root cause; update plan if needed via /migration-replan.
  - Re-run /migration-phase <N> when fix is ready.
  - If the approach was wrong: edit the plan, then re-run /migration-phase <N>.
```

## Hard rules

- **Reason is mandatory.** No silent rollbacks. The reason goes into `_history.md` for the audit trail.
- **Backup directory NEVER auto-deleted.** Even after rollback, the backup stays. Future rollback attempts may need it. Per Hard Rule N20.
- **User-authored content preserved.** Rollback only reverts managed blocks. Anything outside `setup-project:managed` markers is left intact.
- **History is append-only.** Rollback adds a new entry; the original PASS entry from `/migration-gate <N>` stays — for the audit trail.
- **No partial rollback within a phase.** Either every phase-N feature reverts, or none. To undo one feature, use `/migration-phase <N> --feature=<id>` instead.
- **Verify before reverting.** If the snapshot's ADR citations don't match current ADR status, flag for user; don't auto-revert.
