---
description: Roll back a migration phase. Restores ledger + audits + ported files to their state before /migration-phase <N> was run. Uses Phase 0 backups + git history + per-phase manifest. Read-confirm-execute pattern; never silent.
kind: command
pack: migration
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /migration-rollback <N>

## The Premise (read this first)

**Rollback is destructive. Confirm scope explicitly before mutating.** This command reverts ledger rows, removes audit files, and restores managed-block content from snapshots. Read-confirm-execute — never silent. If the pre-run snapshot at `.claude/backups/migration-phase-<N>-<ts>/` is missing, halt; do NOT improvise a revert from git. The `--reason` flag is mandatory. The backup directory is sacred (Hard Rule N20) — never auto-deleted, even after rollback. User-authored content outside managed blocks is byte-preserved; if any planned write would touch outside-marker content, halt.

The safety net. Use when a shipped phase produces a regression in production OR when a phase reveals it was the wrong direction. Restores phase N's pre-run state.

## When to use

- A regression surfaced after `/migration-gate <N>` passed, **and phase N's features are still pre-traffic** (`V1-only` / `In-progress` / `V2-shadow`).
- A planning error means phase N's approach was wrong; you need to redo from scratch.
- A phase shipped with `intentional-break` ADRs you've since revoked.

This command reverts **artifacts** — ledger rows, managed-block file content, audit and perf-decision files. It does not and cannot move production traffic, reverse a backfill, or flip a cutover flag. If V2 is serving users, the deployment rollback in `ai/runbooks/migration-rollback-<feature>.md` runs FIRST and this command runs after, to reconcile the repo with the state you rolled the system back to.

## When NOT to use

- **Production traffic on V2 is failing.** That is a deployment event, not an artifact event. Execute `ai/runbooks/migration-rollback-<feature>.md` (the runbook halt #8 forced every heavy port to author, naming the cutover mechanism + per-stage steps + on-call). Come back here only once traffic is off V2.
- A single feature needs a different implementation → `/migration-phase <N> --feature=<id>` **re-ports** it. Note this is a fresh port, NOT a revert: there is no per-feature revert path, by design (see Hard rules).
- The ledger is correct but production state is wrong → deployment rollback.
- Phase < 1 or phase > current-max → halt; nothing to roll back.

## Pre-requisites

- Phase N was previously executed via `/migration-phase <N>`.
- Phase N's pre-run snapshot exists in `.claude/backups/migration-phase-<N>-<ts>/`.
- The ledger has rows assigned to phase N.

If pre-run snapshot is missing → halt; tell user that this phase was either:
- Shipped before rollback support existed (M11 or earlier), OR
- The backup was deleted by user (`.claude/backups/` is sacred — see N20).

## Pre-flight — irreversibility triage (runs BEFORE every other check)

Restoring a snapshot is safe only when nothing outside this repo has already acted on phase N's output. A backfill that moved rows, a consumer that reads the new shape, a flag that is already flipped — none of these are in the snapshot, and none of them un-happen when the files revert. **The triage REFUSES; it does not warn.** Each refusal names the artifact that clears it.

For every phase-N ledger row, read the row, then read `ai/runbooks/migration-rollback-<feature>.md`, then apply this table:

| Signal | Where it is read | What it means | Verdict |
|---|---|---|---|
| `status` is `V2-canary`, `V2-only` or `V1-deleted` | ledger row | live traffic is served by V2 (`canary_stage` names the percentage) | **REFUSE.** Run the runbook's per-stage rollback to return the row to `V2-shadow` first, then re-run this command. |
| `status` is `V2-shadow` with a non-null `shadow_mismatch_rate` | ledger row | V2 is executing on real traffic but not serving it — reverting the code stops the shadow, which is safe, but the mismatch history is evidence | **PROCEED** — copy `shadow_mismatch_rate` into the `_history.md` entry before reverting, or it is lost with the row. |
| A backfill checkpoint exists with a cursor past its start | `data-cutover-orchestrate` readiness evidence for the row; the mapping at `ai/migration/mapping/<feature>.md` | rows have already been written into V2's store. Reverting `<F.target>` restores the *code* and leaves the *data* moved — the two stores diverge silently, permanently, and no gate looks again | **REFUSE.** A cross-store port is unwound by reconciliation, not by file restore. Re-run reconciliation and record the divergence before any revert. |
| An `open` or `in-flight` row naming a phase-N feature | `ai/migration/cross-repo-tasks.md` | a consumer in another repo is already coded against the new shape. Reverting V2 here breaks that consumer, in a repo this command cannot see | **REFUSE.** Drain or revert the cross-repo task first (`/cross-repo-task`), then return. |
| The runbook is missing, or names a cutover mechanism whose current state you cannot read | `ai/runbooks/migration-rollback-<feature>.md` | you cannot establish whether the flag is flipped. Unknown is not the same as off | **REFUSE.** Establish the mechanism's current state, or halt to the user. Never assume off. |
| Any row in a phase **> N** cites a phase-N feature in `depends_on` / `notes` | ledger rows for phases N+1…max | later phases were built on top of what you are about to remove | **REFUSE** unless the user passes `--cascade-ack` naming each dependent row. `/migration-plan` grouped phases by dependency, so this is answerable from the ledger — do not skip it. |

If every phase-N row clears the table, print `IRREVERSIBILITY: CLEAR — <Y> rows, all pre-traffic` and continue. If any row refuses, print the refusing rows with their verdict text and **write nothing** — the refusal is the output.

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
- `ai/runbooks/migration-rollback-<feature>.md` for every phase-N row — the cutover mechanism and its current state. This is the input the triage table above consumes; halt #8 guarantees the file exists for every standard/heavy row.
- `ai/migration/cross-repo-tasks.md` (if present) — open consumer coupling.

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

- Append failure-catalog entry: `ai/failures/<NNNN>-phase-<N>-rollback.md` with the user-supplied reason + observable behavior that triggered rollback.
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

## Mechanical halt — refuse to mutate without confirmed scope

Before any write: (0) the irreversibility triage above returned CLEAR for every phase-N row — a single REFUSE stops the command, and `--dry-run` is the only thing that runs past it, (1) `--reason` non-empty (≥1 sentence), (2) snapshot dir exists at `.claude/backups/migration-phase-<N>-<ts>/`, (3) explicit user confirmation of the feature list (`--dry-run` first is recommended), (4) no planned write touches content outside `setup-project:managed` markers — if a feature's target file has no managed block, halt and surface for manual handling, (5) ADRs cited as `intentional-break` for phase-N rows have been classified (Accepted / Superseded / Rejected) — auto-revert without ADR review is forbidden. Atomic per-feature: row + file + audit either all revert or none.

## Hard rules

- **Reason is mandatory.** No silent rollbacks. The reason goes into `_history.md` for the audit trail.
- **Backup directory NEVER auto-deleted.** Even after rollback, the backup stays. Future rollback attempts may need it. Per Hard Rule N20.
- **User-authored content preserved.** Rollback only reverts managed blocks. Anything outside `setup-project:managed` markers is left intact.
- **History is append-only.** Rollback adds a new entry; the original PASS entry from `/migration-gate <N>` stays — for the audit trail.
- **No partial rollback within a phase.** Either every phase-N feature reverts, or none — a half-reverted phase leaves the ledger describing a state no snapshot holds. There is deliberately **no per-feature revert**: `/migration-phase <N> --feature=<id>` re-ports the feature forward from the contract, which is a different operation with a different risk profile. Do not describe it to a user as "undo".
- **Artifacts only, never traffic.** This command cannot flip a flag, drain a canary, reverse a backfill or notify a consumer. When any of those is in play the runbook leads and this command follows.
- **Verify before reverting.** If the snapshot's ADR citations don't match current ADR status, flag for user; don't auto-revert.

## Related

- `/migration-phase <N>` — produced the state being rolled back.
- `/migration-replan` — recommended after rollback; the original plan's assumptions may be stale.
- `/migration-gate <N>` — re-run after rollback + fix to confirm phase is recoverable.
- `ai/migration/_history.md` — append-only log this command writes the rollback entry to.
- `ai/failures/` — this command appends a failure-catalog entry on rollback.
