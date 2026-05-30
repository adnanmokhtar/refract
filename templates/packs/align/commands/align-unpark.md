---
description: Reverse /align-park. Restores a parked alignment finding's prior status and phase from the parked-context file, archives that file, and appends a history entry. Read-confirm-execute; mutates nothing if the parked context is missing or malformed. The revival pair of /align-park.
kind: command
pack: align
---

# /align-unpark <id>

**One command. Revive a parked alignment finding when its blocker clears.** The pair of `/align-park` — restores the finding to exactly the status + phase it held at park time, so the gate sees it as outstanding work again.

## Premise

**State changes are atomic. Confirm before mutating the ledger.** Unpark restores `prior_status` and `prior_phase` exactly as captured at park time — not a best-guess, not "probably detected." Read the parked-context first; verify `prior_status` + `prior_phase` are populated; then mutate the ledger row + archive the park record + append history together. Resolution note mandatory. If the parked context is missing or malformed, **halt and mutate nothing.**

## When to use

- A finding parked via `/align-park` is now unblocked (the missing idiom was adopted, the reviewer is available, the verb was corrected).
- NOT for findings that are `archived-pre-existing` (false positive) or `archived-deprecated` (won't-fix) — those are terminal, not parked.

## Args

```
/align-unpark <id> [reason]   # restore the finding; reason recorded as unparked_reason
```

## Pre-requisites

- `ai/align/ledger.md` exists.
- The finding `<id>` exists with `status: parked`.
- A parked-context record (the `parked_*` fields / park file) with non-empty `prior_status` + `prior_phase`.

If any missing/malformed → halt + report; mutate nothing.

## What happens

1. Read the ledger row + parked context; verify `prior_status` ∈ {detected, in-progress, halted} and `prior_phase` populated.
2. **Confirm** the restore (id, `parked → prior_status`, target phase) before mutating.
3. Restore the row: `status: <prior_status>`, `phase: <prior_phase>`, add `unparked_at` + `unparked_reason`; remove the `parked_*` fields.
4. **Archive** the parked-context (preserve for audit — which findings were parked, why, how long).
5. Append a one-line entry to `ai/align/_history.md`.

## Output (brief)

- id · `parked → <prior_status>` · restored phase · archive path.

## See also

- `/align-park` — the command this reverses.
- `/align-status` — surfaces parked + outstanding findings.
- `templates/packs/migration/commands/migration-unpark.md` — the migration-pack analogue.
