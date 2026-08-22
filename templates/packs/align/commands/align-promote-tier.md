---
description: Promote (or demote) an align ledger row's tier mid-fix. Backfills required artifacts on promotion. Demotion of security rows is forbidden. Mirrors /migration-promote-tier.
kind: command
pack: align
---

# /align-promote-tier <finding-id> <new-tier> [--reason="<text>"]

## The Premise (read this first)

**`tier` is the field every floor in this pack keys on.** Gate checks 10 and 14 read it; the reviewer-approval requirement reads it; the impact-analysis requirement reads it; the security floor is expressed entirely in it. This command is the only artifact authorised to change it after scan, which makes it the one place a heavy row can quietly become a trivial one.

Tier is set at scan, but real fixes surface complexity the scan could not see:
- Trivial dead-code turns out to remove a public API symbol → promote to standard.
- Standard reinvented-wrapper swap touches 18 files → promote to heavy, or split into several findings.
- Heavy security row turns out mechanical → demote with rationale, and only if not critical-severity.

This command updates the row's `tier:`, backfills the artifacts the new tier requires, appends `tier_history`, and resumes the fix loop under the new discipline. **A tier change with no backfilled artifacts is not a tier change — it is a floor removal**, and the next gate REFUSES on it rather than on the row's actual defect, which wastes a whole gate cycle to discover a bookkeeping error.

## Mechanical halt — refuse rather than guess

1. **Demotion with no `--reason`** → refuse. Promotion may be silent-ish (it only ever adds obligations); demotion removes them and always carries a written reason into `notes` and `_history.md`.
2. **Any demotion of a `class: security` row below `standard`** → refuse, unconditionally. There is no `--force`, and `--no-confirm` does not apply. Cite the row's class and severity in the refusal.
3. **Any demotion of a row whose `severity: critical`, or whose `subclass` ∈ {`sql-injection`, `secret-in-code`, `unsafe-deserialize`}, below `heavy`** → refuse. These floors come from the row's own class and severity, not from the caller's judgment. Dispatch `@align-evidence-auditor` when you need the floor *derived* rather than asserted.
4. **Row status ∉ {detected, planned, in-progress, halted, pending-review}** → refuse. A `verified` or `archived-*` row's tier is history, not state; rewriting it rewrites what the gate already checked.
5. **Promotion whose backfill cannot be produced** — the impact analysis needs consumer paths you cannot enumerate, or the reviewer is unknown → **halt with the row still at its old tier**. Writing `tier: heavy` while `ai/align/impact/<id>.md` does not exist creates a row that claims a floor it does not meet, which is worse than the under-tiered row you started with.
6. **Hand-wave grep on your own reason text** — `probably`, `should be fine`, `looks mechanical`, `just a` → halt. A tier reason names what changed: a file count, a consumer, a symbol, a path.

Refusing is always available and costs nothing. The row stays where it is and the fix loop continues under the old discipline.

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
- Backfill required for promotion — no shortcut, and no writing the new tier before the backfill lands.
- Forbidden demotions absolute — no `--force` override.
- Tier locked post-completion (verified / archived rows refuse change).
- **Derive the security floor from the row, do not accept it as an argument.** The caller says which tier they want; the row's `class`, `subclass` and `severity` say which tiers are legal.

## Failure modes

- **Row not found** — halt; check the id with `/align-status`.
- **Row already at the requested tier** — no-op with a one-line report. Do not append a `tier_history` entry for a change that did not happen; a history full of no-ops hides the changes that did.
- **Demotion refused (security floor)** — report the floor, the row's class/severity, and the two legitimate alternatives: fix it at its current tier, or `/align-park` it (which for a critical row itself requires an explicit override).
- **Backfill half-written** — the impact file exists but `reviewer_approval` is unresolvable, or vice versa. Roll back to the old tier and report; a partially-promoted row passes check 10 on one axis and fails on the other, which reads as a defect in the fix rather than in this command.
- **Promotion cascades past the phase cap** — promoting several rows to heavy can push the phase past what a reviewer can approve in one pass. Surface it and route to `/align-replan` rather than silently producing an un-reviewable phase.
- **Tier changed but the fix loop was not resumed** — the row now carries obligations nobody is working. Always end by naming the resume command.

## Related

### Agents
- `.claude/agents/align-evidence-auditor.md` — its check 5 is the tier floor this command enforces (security ≥ standard; `sql-injection` / `secret-in-code` / `unsafe-deserialize` / `severity: critical` → heavy). Dispatch it when a demotion is requested and you need the floor derived from the row's own class and severity rather than asserted.
- `.claude/agents/align-gate-auditor.md` — gate checks 10 and 14 verify that the backfilled artifacts for the new tier actually landed. A promotion whose impact analysis was never written REFUSES at the next gate, not here.

### Rules and siblings
- `align-discipline.md § Mid-port tier promotion` — procedure this command implements.
- `/align-phase` / `/align-fast` / `/align-recheck` — resume the fix loop after promotion.
- `/align-status` — shows current tier + tier_history.
