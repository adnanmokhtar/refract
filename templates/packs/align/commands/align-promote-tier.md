---
description: Promote (or demote) an align ledger row's tier mid-fix. Backfills required artifacts on promotion. Demoting an AL-15 gate row below heavy is forbidden. Mirrors /migration-promote-tier.
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-promote-tier <finding-id> <new-tier> [--reason="<text>"]

## The Premise (read this first)

**`tier` is the field every floor in this pack keys on.** Gate check 16 (per-tier artifacts) reads it; the reviewer-approval requirement reads it; the impact-analysis requirement reads it; the gate-row floor is expressed entirely in it. This command is the only artifact authorised to change it after scan, which makes it the one place a heavy row can quietly become a trivial one.

Tier is set at scan, but real fixes surface complexity the scan could not see:
- A trivial AL-17 rename turns out to touch an exported symbol → promote to standard.
- A standard AL-11 wrapper swap touches 18 files → promote to heavy, or split into several rows.
- A heavy AL-16 directory rename turns out to have one consumer → demote with rationale. An AL-15 gate row never demotes below heavy.

This command updates the row's `tier:`, backfills the artifacts the new tier requires, appends `tier_history`, and resumes the fix loop under the new discipline. **A tier change with no backfilled artifacts is not a tier change — it is a floor removal**, and the next gate REFUSES on it rather than on the row's actual defect, which wastes a whole gate cycle to discover a bookkeeping error.

## Mechanical halt — refuse rather than guess

1. **Demotion with no `--reason`** → refuse. Promotion may be silent-ish (it only ever adds obligations); demotion removes them and always carries a written reason into `notes` and `_history.md`.
2. **Any demotion below `heavy` of an AL-15 row that adds or touches a permission, tenant or auth gate (severity HIGH), or of a VC row on a shared component** → refuse, unconditionally. These are the heavy triggers of `align-discipline.md § Tier classification`. There is no `--force`, and `--no-confirm` does not apply. Cite the row's `al_class`, severity and trigger in the refusal.
3. **A row whose class an owner pack holds** (a legacy `class: security`, `performance` or code-quality row; `owner` ≠ `align`) → refuse any tier change: the row is `routed`, and its tier is the owner's business (`ai/patterns/align-ledger.md § Legacy class names`). These floors come from the row's own fields, not from the caller's judgment. Dispatch `@align-evidence-auditor` when you need the floor *derived* rather than asserted.
4. **Row status ∉ {detected, planned, in-progress, halted, pending-review, pending-approval}** → refuse. A `verified`, `routed`, `refuted` or `archived-*` row's tier is history, not state; rewriting it rewrites what the gate already checked.
5. **Promotion whose backfill cannot be produced** — the impact analysis needs consumer paths you cannot enumerate, or the reviewer is unknown → **halt with the row still at its old tier**. Writing `tier: heavy` while `ai/align/impact/<id>.md` does not exist creates a row that claims a floor it does not meet, which is worse than the under-tiered row you started with.
6. **Hand-wave grep on your own reason text** — `probably`, `should be fine`, `looks mechanical`, `just a` → halt. A tier reason names what changed: a file count, a consumer, a symbol, a path.

Refusing is always available and costs nothing. The row stays where it is and the fix loop continues under the old discipline.

## Args

- `<finding-id>` — ledger row ID (e.g., `A047`).
- `<new-tier>` — `trivial` | `standard` | `heavy`.
- `--reason="<text>"` — required for demotion.

## Forbidden demotions

- AL-15 gate rows (a permission, tenant or auth gate added or touched) cannot fall below heavy.
- A VC row on a shared component cannot fall below heavy.
- Rows whose `idiom_cited` references a critical idiom (the project's declared gate component, auth or tenant wrapper) — promote-only.
- Owner rows (`routed`) take no tier change here at all.

## Pre-requisites

- `<finding-id>` exists in `ai/align/ledger.md`.
- Row status ∈ `{detected, planned, in-progress, halted, pending-review, pending-approval}`. Verified, routed, refuted and archived rows refuse tier change.

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
  Reason: AL-15 row — adds the declared <Can action="orders.delete"> gate around a destructive action (severity HIGH).
  A permission / tenant / auth gate row is ALWAYS heavy per align-discipline § Tier classification.
```

## Hard rules

- No silent tier change — `_history.md` entry mandatory.
- Backfill required for promotion — no shortcut, and no writing the new tier before the backfill lands.
- Forbidden demotions absolute — no `--force` override.
- Tier locked post-completion (verified / archived rows refuse change).
- **Derive the floor from the row, do not accept it as an argument.** The caller says which tier they want; the row's `al_class`, `owner`, `proof_class` and severity say which tiers are legal.

## Failure modes

- **Row not found** — halt; check the id with `/align-status`.
- **Row already at the requested tier** — no-op with a one-line report. Do not append a `tier_history` entry for a change that did not happen; a history full of no-ops hides the changes that did.
- **Demotion refused (gate floor)** — report the floor, the row's AL class / severity, and the two legitimate alternatives: fix it at its current tier, or `/align-park` it (which for a HIGH row keeps its SLA clock running).
- **Backfill half-written** — the impact file exists but `reviewer_approval` is unresolvable, or vice versa. Roll back to the old tier and report; a partially-promoted row passes check 16 on one axis and fails on the other, which reads as a defect in the fix rather than in this command.
- **Promotion cascades past the phase cap** — promoting several rows to heavy can push the phase past what a reviewer can approve in one pass. Surface it and route to `/align-replan` rather than silently producing an un-reviewable phase.
- **Tier changed but the fix loop was not resumed** — the row now carries obligations nobody is working. Always end by naming the resume command.

## Related

### Agents
- `.claude/agents/align-evidence-auditor.md` — its tier-floor check is the floor this command enforces (AL-15 gate rows and VC rows on shared components → heavy; owner rows routed). Dispatch it when a demotion is requested and you need the floor derived from the row's own fields rather than asserted.
- `.claude/agents/align-gate-auditor.md` — gate check 16 verifies that the backfilled artifacts for the new tier actually landed. A promotion whose impact analysis was never written REFUSES at the next gate, not here.

### Rules and siblings
- `ai/patterns/align-guardrails.md § Mid-sweep tier promotion` — the procedure this command implements; `align-discipline.md § Tier classification` — the promoter triggers and the heavy floor.
- `/align-phase` / `/align-fast` / `/align-recheck` — resume the fix loop after promotion.
- `/align-status` — shows current tier + tier_history.
