---
description: Promote (or demote) an align ledger row's tier mid-fix. Backfills required artifacts on promotion. Demotion of security rows is forbidden. Mirrors /migration-promote-tier.
kind: command
pack: align
---

# /align-promote-tier <finding-id> <new-tier> [--reason="<text>"]

## The Premise

Tier set at scan, but real fixes surface complexity:
- Trivial dead-code turns out to remove a public API symbol → promote to standard.
- Standard reinvented-wrapper swap touches 18 files → promote to standard (already there) or surface multi-finding split.
- Heavy security row turns out mechanical → demote with rationale (only if not critical-severity).

This command updates the ledger row's `tier:` field, backfills required artifacts for the new tier, and resumes the fix loop with the new discipline.

## Args

- `<finding-id>` — ledger row ID (e.g., `A047`).
- `<new-tier>` — `trivial` | `standard` | `heavy`.
- `--reason="<text>"` — required for demotion.

## Forbidden demotions

- Security rows cannot fall below standard (security never trivial).
- Critical-severity security cannot fall below heavy.
- Rows whose `idiom_cited` references a critical idiom (the project's auth gate, validator, escape helper) — promote-only.

## Pre-requisites

- `<finding-id>` exists in `ai/align/ledger.md`.
- Row status ∈ `{detected, in-progress, halted, pending-review}`. Verified / archived rows refuse tier change.

## Procedure

```
1. VALIDATE      — confirm row state + transition allowed
2. CLASSIFY      — promotion or demotion?
3. BACKFILL      — for promotion: generate artifacts for new tier
                   trivial → standard: rationale paragraph in row.notes
                   standard → heavy: impact analysis at ai/align/impact/<id>.md
                                     reviewer-approval flow kicks in
4. UPDATE LEDGER — tier field + tier_history
5. RECORD        — ai/align/_history.md one-line entry
6. RESUME        — agent re-enters fix loop with new tier's discipline
```

## Output

```
Tier promotion: A047 standard → heavy
  Reason:                  cross-package boundary change; affects 3 sibling repos
  Backfilled artifacts:
    ai/align/impact/A047.md              (impact analysis)
    ai/align/halts/A047-pending-review.md (reviewer-approval pending)
  Ledger updated:          tier=heavy, tier_history appended

Resume: /align-recheck or /align-phase <N>   (heavy-tier discipline applies)
```

## Forbidden demotion example

```
Refused: A105 cannot be demoted from heavy.
  Reason: critical-severity security finding (sql-injection on production endpoint).
  Critical security ALWAYS heavy per align-discipline § Tier classification.
```

## Hard rules

- No silent tier change — `_history.md` entry mandatory.
- Backfill required for promotion — no shortcut.
- Forbidden demotions absolute — no `--force` override.
- Tier locked post-completion (verified / archived rows refuse change).

## Related

- `align-discipline.md § Mid-port tier promotion` — procedure this command implements.
- `/align-phase` / `/align-fast` / `/align-recheck` — resume the fix loop after promotion.
- `/align-status` — shows current tier + tier_history.
