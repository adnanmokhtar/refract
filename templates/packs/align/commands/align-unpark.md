---
description: Reverse /align-park. Restores a parked alignment finding's prior status and phase from the parked-context file, archives that file, and appends a history entry. Read-confirm-execute; mutates nothing if the parked context is missing or malformed. The revival pair of /align-park.
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-unpark <id>

**One command. Revive a parked alignment finding when its blocker clears.** The pair of `/align-park` — restores the finding to exactly the status + phase it held at park time, so the gate sees it as outstanding work again.

## Premise

**State changes are atomic. Confirm before mutating the ledger.** Unpark restores `prior_status` and `prior_phase` exactly as captured at park time — not a best-guess, not "probably detected." Read the parked-context first; verify `prior_status` + `prior_phase` are populated; then mutate the ledger row + archive the park record + append history together. Resolution note mandatory. If the parked context is missing or malformed, **halt and mutate nothing.**

**Why the halt is absolute, and not a convenience default.** The tempting fallback is to restore a malformed row to `detected` and let the sweep re-derive its state. That silently discards the phase assignment, the closure verb, the evidence-to-gap accounting and any reviewer approval the row had accumulated — and it does so in the one case where the ledger has already demonstrated it cannot be trusted. A row that cannot say where it came from is reported, not guessed at.

## When to use

- A finding parked via `/align-park` is now unblocked (the missing idiom was adopted, the reviewer is available, the verb was corrected).
- Any parked `class: security` row whose SLA has aged past its threshold — `/align-status --blockers` surfaces these; parking does not stop a security clock.
- NOT for findings that are `archived-pre-existing` (false positive) or `archived-deprecated` (won't-fix, ADR recorded) — those are terminal, not parked.

## Args

```
/align-unpark <id> [reason]        # restore the finding; reason recorded as unparked_reason
    --list-unrevivable             # instead of restoring: report every parked row that is
                                   # missing prior_status / prior_phase and cannot be revived
```

## Pre-requisites

- `ai/align/ledger.md` exists.
- The finding `<id>` exists with `status: parked`.
- A parked-context record (the `parked_*` fields / park file) with non-empty `prior_status` + `prior_phase`.

If any missing/malformed → halt + report; mutate nothing.

## What happens

1. Read the ledger row + parked context; verify `prior_status` ∈ {detected, planned, in-progress, halted} and `prior_phase` is an integer that `ai/align/plan.md` defines.
2. **Confirm** the restore (id, `parked → prior_status`, target phase) before mutating.
3. Restore the row: `status: <prior_status>`, `phase: <prior_phase>`, add `unparked_at` + `unparked_reason`; remove the `parked_*` fields.
4. **Archive** the parked-context (preserve for audit — which findings were parked, why, how long).
5. Append a one-line entry to `ai/align/_history.md`. This entry is what makes the subsequent `parked → … → fixed` path legal; without it `@align-ledger-auditor` reconciliation 2 reads the transition as illegal.

## Output (brief)

- id · `parked → <prior_status>` · restored phase · days parked · archive path.
- For `class: security` rows: the SLA age carried forward from `parked_sla_from`, not from `unparked_at`.

## Mechanical halt — no reconstruction, no partial restore

- **`prior_status` absent, empty, or not one of the four legal values** → halt. Report the row, name the missing field, and state that the row was parked by a `/align-park` run that did not persist its revival context. Do not restore to a default.
- **`prior_phase` names a phase `ai/align/plan.md` does not define** → halt and route to `/align-replan`. Restoring a row into a phase that no longer exists produces plan drift the gate will refuse on anyway.
- **The row is not `parked`** → halt; report its actual status. Unpark is not a general state-setter.
- **Partial write** — the ledger row, the park-record archive and the `_history.md` entry are one unit. If any one cannot be written, roll back the others and report. A restored row with no history entry is worse than a still-parked row, because the illegal-transition check will fire on it later and nobody will know why.

## Failure modes

- **Row not found** — halt; check the id with `/align-status --blockers`.
- **Row parked before revival fields existed** — this is the common case on any ledger written by an older `/align-park`. Halt, and offer `--list-unrevivable` to size the problem across the whole ledger rather than discovering it one row at a time. The remedy is a human deciding each row's prior state and writing it once, not a default.
- **Blocker has not actually cleared** — unpark is not a fix. The row returns to `halted` or `in-progress` and will halt again on the same condition. Confirm the blocker cleared before reviving; a row unparked and re-parked twice is a signal for `/setup-project --refine`.
- **`_history.md` missing** — create it; an empty history is legal, an absent one breaks the park→unpark→fixed audit trail.

## Related

### Sibling commands in align pack
- `/align-park <id>` — the command this reverses, and the producer of the `prior_status` + `prior_phase` this one consumes. The two are one contract; change either field name in one file and the pair silently stops working.
- `/align-status --blockers` — lists parked rows with their age; the input to deciding what to unpark.
- `/align-replan` — re-phases the ledger after a batch of unparks changes what each phase contains.
- `/align-gate <N>` — starts blocking on the row again once it is restored.
- `/migration-unpark` — the migration pack's analogue, available only when that pack is installed. Same procedure over a different oracle: it restores a V1→V2 port row, so its prior states include the shadow / canary stages align has no equivalent for.
