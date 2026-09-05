---
description: Roll back an alignment phase. Restores the ledger + source + halts to their state before /align-phase <N> ran. Uses git revert + ledger time-travel. Read-confirm-execute pattern; never silent.
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-rollback <N>

## The Premise (read this first)

**Rollback is a deliberate, confirmed operation.** It undoes phase N — reverting all of phase N's commits, restoring the ledger rows to their pre-phase state, archiving the phase's halt files, and removing the gate-history entry for phase N. It does NOT silently rebuild; the user confirms each step.

**Use rollback when:**
- A phase merged + a regression surfaced in production / staging that wasn't caught by the gate.
- A phase's findings were mis-classified (e.g., several rows turned out to be `/refactor`-class, not alignment).
- The user wants to re-run a phase with different scope / strategy.

**Don't use rollback for:**
- A halted row mid-phase — use `/align-park <id>` instead.
- A regression that affects only one row in the phase — manually revert that row's commit + update the ledger.
- A phase that was never started — the ledger has nothing to roll back.

## When to use

- After a regression is detected post-merge of phase N.
- When `/align-final` returns `REGRESSION` and points to a specific phase.
- When the user wants to retry a phase with a different strategy.

## When NOT to use

- During an active `/align-phase` run — the phase isn't merged yet; just abort the run.
- For a phase that's already been rolled back — duplicate rollback is a no-op halt.
- For phase 1 if there are no later phases — there's no rollback target; the alignment effort hasn't started effectively.

## Pre-requisites

- `ai/align/ledger.md` exists.
- Phase N exists in the ledger (rows have `phase: <N>`).
- Phase N has commits in git history (the phase actually ran).
- No later phase has dependencies on phase N's findings (rollback would cascade; refuse).

If pre-requisites missing → halt + report.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/align/ledger.md` — current state.
- `ai/align/plan.md` — phase definitions.
- `ai/align/gate-history.md` — past gate verdicts.
- `ai/align/runs/` — per-phase logs (used to identify phase N's commit range).
- Git history.

Mandatory user prompt: confirm the rollback. Display:
- Phase N's findings count + rows.
- Phase N's commit range (`<base>..<HEAD-of-phase>`).
- Whether later phases (N+1, N+2, ...) depend on phase N's outputs (cascading rollback warning).

Optional flags:
- `--dry-run` — show what would be rolled back; don't execute.
- `--cascade` — automatically roll back later phases that depend on phase N.
- `--no-confirm` — skip the user prompt (DANGEROUS; only for scripted contexts).

## Phase 2 — Organize (decompose the work)

The rollback procedure (in order):

1. **Identify phase N's commit range** — read `ai/align/runs/<phase-N>.log` for the commit range. If missing, fall back to `git log --grep='align/<N>/'`.
2. **Check for later-phase dependencies** — for each phase M > N, scan its rows' `idiom_cited` fields and `evidence` for references to phase N's outputs. If dependencies exist, warn (or cascade if `--cascade`).
3. **Confirm with user** — display the rollback plan; demand explicit confirmation (or `--no-confirm`).
4. **Revert commits** — for each commit in phase N's range, run `git revert --no-commit <sha>`. Combine into one revert commit OR multiple per-row reverts (configurable).
5. **Update ledger — per row, by its current status, not uniformly.** Rollback undoes work; it does not undo decisions somebody made deliberately.

   | Row's status in phase N | After rollback | Why |
   |---|---|---|
   | `in-progress`, `fixed`, `verified`, `pending-review` | `planned` (the phase is still in the plan, so the row is still assigned) + `rollback_at`, `rollback_reason` | its work was reverted; it is queued again |
   | `halted` | stays `halted` | the blocker was never the commit; reverting does not clear it |
   | **`parked`** | **stays `parked`, untouched — `prior_*` fields preserved verbatim** | a park is a human deferral with a reason and a revival contract. Resetting it to `planned` destroys `prior_status` / `prior_phase` and silently converts a deferral into re-queued work nobody asked for |
   | `archived-pre-existing`, `archived-deprecated` | untouched | terminal; the fingerprint was never there, or the won't-fix is on record with an ADR |

   Never write `status: detected` here. `detected` means "the scan found this and it has not been triaged"; after a plan exists, the un-started state is `planned`. Dropping rows back to `detected` makes `@align-ledger-auditor` reconciliation 5 read the plan as drifted.
6. **Archive halt files** — move `ai/align/halts/<phase-N-row-ids>.md` to `ai/align/halts/archive/<YYYY-MM-DD>/`. **Do not touch `ai/align/halts/parked/`** — those belong to parked rows this rollback left alone.
7. **Remove gate-history entry** — delete the line for phase N from `ai/align/gate-history.md`. Append a `ROLLBACK` line to `ai/align/rollback-history.md`.
8. **Restore plan** — phase N stays in the plan; reverted rows return to `phase: <N>` + `status: planned`, ready for re-run. Parked rows keep the `phase: <N>` they already had.

## Phase 3 — Retrieve (read the right context)

- Phase N's run log + commit range.
- Phase N+1..K's row references (for cascade detection).
- Git history.

## Phase 4 — Generate (produce the output)

Pre-execution display (for user confirmation):

```
Align rollback — phase <N>

Phase: <theme>
Findings to roll back: <N>
Commit range: <base>..<head>
Commits: <list of "align/<N>/<row-id>: <description>">

Cascade analysis:
  Phase N+1 depends on rows: <list> [WARN if non-empty]
  Phase N+2 depends on rows: <list>
  ...

Rollback effects:
  Source files reverted: <list>
  Ledger rows restored to planned: <N>   (parked / halted / archived rows untouched)
  Halt files archived: <count>
  Gate-history entry removed.
  Test suite at HEAD will be re-run.

Are you sure? [y/N]
```

Post-execution summary:

```
Phase <N> rolled back.

Reverts: <N> commits (squashed to 1 revert commit "rollback: phase <N>" -OR- N per-row reverts)
Ledger: <N> rows restored to status=planned; <P> parked and <H> halted rows left untouched
Halts archived: ai/align/halts/archive/<YYYY-MM-DD>/
Rollback recorded: ai/align/rollback-history.md

Verification:
  Lint:                PASS / FAIL
  Typecheck:           PASS / FAIL
  Test suite:          PASS / FAIL (<T>/<T>)
  Coverage:            <%>

Next:
  /align-phase <N>     (re-run the phase, OR)
  /align-plan          (re-plan if findings need re-classification, OR)
  /align-scan          (re-scan if drift accumulated since the original scan)
```

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/align/ledger.md` — phase N's reverted rows restored to `status: planned` with `rollback_at` + `rollback_reason`; parked rows (and their `prior_status` / `prior_phase`), halted rows and terminal `archived-*` rows untouched.
- `ai/align/halts/archive/<YYYY-MM-DD>/` — phase N halt files moved here.
- `ai/align/gate-history.md` — phase N entry removed.
- `ai/align/rollback-history.md` — new line: `<iso> phase <N> rolled back | <commit-range> | reason: <user-provided>`.
- Git: revert commit(s) appended to current branch.

## Phase 6 — Validate (verify correctness)

After rollback:
- Phase N's source files match the pre-phase state (`git diff <pre-phase-base>..HEAD -- <phase-N-touched-files>` should be empty).
- Ledger rows restored correctly, per the per-status table: reverted rows at `planned`, parked rows still `parked` with `prior_status` + `prior_phase` intact, halted rows still `halted`, terminal rows unchanged. A rollback that reset a parked row is a data-loss bug, not a cosmetic one — the revival contract cannot be reconstructed.
- Lint + typecheck + tests pass at HEAD (the rollback shouldn't introduce red).

If any verification fails → halt; surface the specific failure; recommend manual git intervention.

## Phase 7 — Improve (feed the learning loop)

- If a row was rolled back AND its class is on a recurring rollback list, surface "row class chronically mis-classified; queue process review".
- If a phase is rolled back > once, surface "phase scope is wrong; consider re-plan".

## Output to user

The pre-execution display + post-execution summary (above).

## Hard rules

- **Mandatory confirmation.** No silent rollback (except `--no-confirm` flag for scripted contexts).
- **Cascade warning.** If later phases depend on phase N, the user is warned explicitly.
- **Git revert, not git reset.** The rollback is forward-moving (revert commits added on top), not history-rewriting (reset). This preserves audit trail.
- **Halt files preserved.** Archived, not deleted.
- **Re-runnable.** After rollback, `/align-phase <N>` can be run again on the restored rows — it picks up the `planned` rows and skips the parked ones, which is the same set it would have run before.

## Failure modes

- **Phase has no commits in git history** — halt; the phase didn't actually run; nothing to roll back.
- **Cascading dependencies** — refuse without `--cascade`; surface the dependency chain.
- **Revert conflicts** — git revert conflicts with downstream changes; halt; route to manual revert.
- **Ledger drift** — row's status doesn't match git state; surface; recommend `/align-status` first.
- **Mid-phase rollback (phase N's gate hasn't passed yet)** — refuse; the phase isn't merged; just abort the active run instead.

## Related

### Sibling commands in align pack
- `/align-phase <N>` — re-runs after rollback.
- `/align-plan` — re-plans if rollback indicates re-classification needed.
- `/align-scan` — re-scans if drift accumulated.
- `/align-status` — checks state before / after rollback.
- `/align-park <id>` — alternative for single-row issues.
