---
description: Final sweep — confirms every feature in the ledger is done + parity-passing across ALL phases. Proposes V1 retirement plan if green. Runs the full audit one more time to catch regressions.
kind: command
pack: migration
---

# /migration-final

## The Premise (read this first)

**Refuse on red. The final sweep is mechanical.** This command does not soften, does not "approve with caveats," does not write a retirement plan over a failing ledger. If any feature is `failed`, any phase is missing from `_history.md`, any ADR is `Proposed` instead of `Accepted`, any `intentional-break` cites a missing file — verdict is INCOMPLETE and the retirement plan is NOT written. V1 is production; retiring it requires zero ambiguity. No hand-waves.

The final verifier. Run when every phase has passed `/migration-gate`. Confirms zero gaps remain across the whole migration AND proposes the V1 retirement sequence.

## Pre-requisites

- Every phase in `ai/migration/plan.md` has a corresponding entry in `ai/migration/_history.md` with `passed`.
- All ledger rows have `status: done` OR `intentional-break: ADR-NNNN`.

If any phase isn't passed → halt; tell user which phase is incomplete.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/migration/ledger.md` — feature inventory.
- `ai/migration/plan.md` — original plan.
- `ai/migration/_history.md` — phase completion log.
- All `ai/migration/audits/*.md`.

Optional flags:
- `--re-audit` — actually re-run audits on every feature (catches regressions since the phase passed). Slow but thorough.
- `--no-retirement` — skip the V1 retirement plan output.

## Phase 2 — Organize (decompose the work)

Three checks in sequence:

1. **Ledger completeness** — every row `done` or `intentional-break`.
2. **Audit consistency** — every `done` row has an audit file; every `intentional-break` cites a real ADR.
3. **Re-audit (optional)** — re-run parity tests on a sample (or all if `--re-audit`).

Then produce:
- Final report.
- V1 retirement plan (unless `--no-retirement`).

## Phase 3 — Retrieve (read the right context)

- Full ledger.
- All audit files.
- All ADRs cited by `intentional-break` rows.
- Cutover mechanism from project anchors (feature-flag / strangler / DNS / blue-green).

## Phase 4 — Generate (produce the output)

### Output 1: `ai/migration/final-report.md`

```markdown
# Migration final report — <YYYY-MM-DD>

## Summary
- Total features:           <N>
- Status=done:              <D>
- Intentional-break:        <I>
- Failed:                   <F>     ← MUST be 0
- Phases completed:         <K>/<K>

## Re-audit results (if --re-audit)
- Re-audited:               <X>
- Still passing:            <Y>
- New regressions:          <Z>     ← MUST be 0

## Intentional breaks (with ADR)
| Feature | ADR | Summary |
|---|---|---|
| F042 | ADR-0017 | V2 returns ISO timestamps, V1 returned epoch ms. Documented. |
| ... | | |

## Verdict
**COMPLETE** — every feature ported + verified. V1 retirement is now safe.

OR

**INCOMPLETE** — <F> features failing + <Z> regressions. See per-feature blockers below.
```

### Output 2: `ai/migration/retirement-plan.md` (if --no-retirement not set)

```markdown
# V1 retirement plan — <YYYY-MM-DD>

## Cutover mechanism
<feature-flag | strangler proxy | DNS swap | blue-green>

## Sequence
1. **Soak window** — V2 takes 100% traffic; V1 stays warm for <X> days.
2. **V1 read-only** — disable writes on V1; reads pass through.
3. **V1 zero traffic** — flip last route group; monitor for <Y> days.
4. **V1 archive** — move V1 to archive repo / cold storage.

## Rollback procedure
At each step, rollback action:
- Step 1 → flip feature-flag back; <Z> seconds to recover.
- Step 2 → re-enable V1 writes.
- Step 3 → re-route through V1.
- Step 4 → restore from archive (RTO: <hours>).

## Monitoring during retirement
- Error rate: V1 should approach 0; V2 stable.
- Latency: V2 within budget per `ai/migration/perf-decisions/`.
- Audit logs: no orphan V1 references in V2 logs.

## V1 retirement checklist
- [ ] All ports ledger-confirmed.
- [ ] All parity tests passing.
- [ ] V1 read-only window observed without errors.
- [ ] Stakeholders signed off (link to issue/ticket).
- [ ] Archive location documented.
```

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/migration/final-report.md` — managed-block; idempotent.
- `ai/migration/retirement-plan.md` — managed-block; idempotent.
- `ai/migration/_history.md` — append final entry: `<YYYY-MM-DD> | final | passed | total: <N>`.

## Phase 6 — Validate (verify correctness)

- The final report's verdict matches the underlying data (no false-positive PASS).
- Retirement plan's rollback procedures are concrete (named steps, named tools, measurable RTO).
- All cited ADRs exist and are `Accepted` status.

If the verdict is INCOMPLETE → halt; do NOT write retirement plan.

## Phase 7 — Improve (feed the learning loop)

- Total migration duration vs original estimate → record in `ai/failures/` if >50% over.
- Recurring port patterns → propose canonical patterns in `ai/patterns/`.
- ADRs that survived re-review → mark as `validated` in their frontmatter.
- Run `/learn-from-task` to promote durable lessons.

## Output to user

On COMPLETE:
```
Migration FINAL: COMPLETE
  Features:                 <N>
  Phases:                   <K>/<K> passed
  Intentional breaks:       <I> (all ADR-cited)
  Regressions detected:     0

Reports:
  ai/migration/final-report.md       (the verdict)
  ai/migration/retirement-plan.md    (V1 retirement sequence)

Next: execute the retirement plan when ready. /migration-final --re-audit before each step is recommended.
```

On INCOMPLETE:
```
Migration FINAL: INCOMPLETE
  <F> features still failing.
  <Z> regressions detected (use --re-audit to confirm).

See ai/migration/final-report.md § Per-feature blockers.

Fix the blockers; re-run /migration-phase <N> for the affected phase; then re-run /migration-final.
```

## Mechanical halt — refuse retirement plan on any red

Verdict computation is deterministic: `failed_count == 0` AND `regression_count == 0` (when `--re-audit`) AND every phase in `plan.md` has a corresponding `passed` entry in `_history.md` AND every `intentional-break` cites an `Accepted` ADR file that exists on disk. If any condition fails → verdict = INCOMPLETE; do NOT write `retirement-plan.md`; surface the per-feature blocker list. There is no "passed with notes" mode.

## Hard rules

- **No PASS without all phases gated.** This command refuses to run if any phase entry in `_history.md` is missing.
- **No retirement plan without COMPLETE.** Refuse to write `retirement-plan.md` while any feature is failing.
- **Re-audit re-runs the validator.** When `--re-audit`, run `~/.claude/scripts/validate-migration-artifacts.sh --all --strict` across the full ledger. Treats artifact decay (a contract whose citations no longer resolve because V1 evolved; a tolerance.yaml that no longer covers a contract field) as a regression — refuses COMPLETE.
- **Re-audit is opt-in.** It's slow and runs the parity tests against current state. Important when phases shipped over weeks/months and code may have drifted since each phase was gated.
- **Append-only history.** Final entries in `_history.md` are immutable. A new run appends another entry; never edits past ones.

## Related

- `/migration-gate <N>` — must have run + passed for every phase before this command can succeed.
- `/migration-status` — lighter read of the ledger; doesn't enforce.
- `/migration-rollback <N>` — use if final reveals a regression in a previously-gated phase.
- `ai/patterns/migration-ledger.md` — schema for the ledger this command verifies.
- `ai/migration/retirement-plan.md` — output this command produces (cutover sequence + rollback procedure).
