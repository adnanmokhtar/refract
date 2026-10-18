---
description: Park a hairy alignment finding so it doesn't block the phase gate. Sets status=parked with a recorded reason. The finding is excluded from current phase scope and from /align-final's "must-be-done" check (until unparked). Append-only — parked findings stay in the ledger forever for historical traceability.
kind: command
pack: align
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /align-park <id> [reason]

## The Premise (read this first)

**Park = "this finding can't be fixed in this phase, with this strategy, with this team, right now."** Park is the legitimate escape hatch from the gate. A halted row that can't be resolved by re-running the closure verb (the verb is wrong; the idiom is missing; the test suite is too slow; the reviewer is unavailable) gets parked instead of being silently ignored.

**A parked finding is NOT a fixed finding.** It's deferred — explicitly, with a reason — so the phase can advance without lying about its state. The parked row stays in the ledger; `/align-status` and `/align-final` surface it as outstanding work; `/align-unpark <id>` revives it when the blocker clears.

**Park is also NOT a deletion.** A finding that was scanned but turned out to be a false positive uses `status: archived-pre-existing` (re-detect returns 0 hits) — different from park. Park is for findings that ARE real but can't be fixed now.

## When to use

- A halted row whose closure verb halt has no quick remediation (e.g., idiom missing, would require `/setup-project --refine` + idiom adoption first).
- A finding that should be re-classified to a different class but the user is mid-effort and doesn't want to derail the phase.
- A finding whose fix is correct but blocked by a cross-repo dependency.
- A finding the team has decided to defer to a later cadence (e.g., "this clean-code finding requires a renaming sprint; defer to Q3").

## When NOT to use

- A halted row that's a quick fix away (just re-run the verb).
- A "false positive" finding (re-detect already returns 0 hits) — use `archived-pre-existing` instead.
- A finding the team has decided NOT to fix at all. That is not a park — it is the terminal `archived-deprecated` state, which requires an ADR and is set by hand (there is no command for it, deliberately: a won't-fix on a scanned finding is a human decision with a written reason).
- **A HIGH row** (an AL-15 permission, tenant or auth gate, or a wrapper bypass that drops one) without a signed override. See § Mechanical halt.
- **An owner-class row** (a legacy `class: security`, `performance` or code-quality row). It is not parked here: it is re-written `status: routed` to its owner's fix command (`/security-fix` for security), per `ai/patterns/align-ledger.md § Legacy class names`.

## Args

```
/align-park <id> [reason]                      # the normal form; prompts for a reason if omitted
    --blocker=<idiom-missing|cross-repo|reviewer|scope|cadence|other>
    --unpark-after=<date|event>                # when to revisit; aged by /align-status --stalled
    --no-confirm                               # scripted contexts; does NOT waive a HIGH override
    --override-high="<reason>"                 # the ONLY way to park a HIGH row (a permission, tenant or auth gate)
```

## Pre-requisites

- `ai/align/ledger.md` exists.
- The finding `<id>` exists in the ledger.
- The finding's `status` is one of: `detected`, `planned`, `in-progress`, `halted`. (Cannot park a `fixed` / `verified` / already-`parked` / `archived-*` row.)

If pre-requisites missing → halt + report.

## Mechanical halt — refuse to park a HIGH row silently

**Park is the one transition that removes a row from every escalation the pack has.** After a park: `/align-gate` stops blocking on it, the halt file moves to `halts/parked/` (so the "same halt reason on ≥ 3 rows → systemic" detector loses it), and `@align-ledger-auditor`'s 24-hour escalation for a HIGH row keys on `status: halted` — which the row no longer is. Nothing else in the pack re-surfaces it except `/align-final`'s `PARTIAL`.

So:

1. **A HIGH row → REFUSE** unless the invocation carries `--override-high="<reason>"`. Align's severities stop at High, and High is reserved for a permission, tenant or auth gate (an AL-15 gate drop, an AL-11 bypass of an auth or tenant wrapper, an AL-29 suppression of the rule that guards one). The override text is written into `parked_reason` verbatim and appended to `ai/align/_history.md` as `HIGH-PARK`. `--no-confirm` does NOT satisfy this; an override is never implicit.
2. **An overridden HIGH park does not stop the SLA clock.** The row is written with `parked_sla_from: <the row's original halted_at or detected_at>`, so `@align-ledger-auditor` ages the escalation from when the problem was found, not from when it was parked.
3. **A legacy owner-class row → REFUSE the park.** A `class: security` (or `performance`, `silent-catch`, …) row in an old ledger is routed to its owner's fix command, never parked or closed in align.
4. **A park that would leave zero unparked rows in the phase → surface it.** A phase that advances because every row in it was parked has not been aligned; say so before confirming.

Refusing to park is always available. Parking a dropped permission gate because the gate component the oracle names does not exist yet is a legitimate decision — but it is a decision someone signs.

## Phase 1 — Understand (the ask)

Inputs:
- `<id>` — the row id to park.
- `[reason]` — optional 1-line park rationale (defaults to prompted entry if not provided).

Optional flags:
- `--blocker=<idiom-missing | cross-repo | reviewer | scope | cadence | other>` — categorise the blocker for trend analysis.
- `--unpark-after=<date | event>` — note when to revisit (free-text; surfaced in status reports).
- `--no-confirm` — skip the user prompt (for scripted contexts).

## Phase 2 — Organize (decompose the work)

Steps:
1. Read the ledger row.
2. Validate state transition (detected | planned | in-progress | halted → parked). **Capture the row's current `status` and `phase` in this step — they are what step 4 persists and what `/align-unpark` restores.**
3. If the row is HIGH, or carries a legacy owner class, apply § Mechanical halt (HIGH requires `--override-high` and carries its SLA origin forward; an owner-class row is routed, not parked).
4. Demand confirmation from user (display the row + reason; require explicit y/N).
5. Update the ledger row:
   - `status: parked`
   - **`prior_status: <the status read in step 2>`** — never a guess, never `detected` by default
   - **`prior_phase: <the phase read in step 2>`**
   - `parked_at: <iso>`, `parked_reason: <reason>`, `parked_blocker: <category>`, `parked_unpark_after: <date|event>`
   - `parked_sla_from: <the row's halted_at, else detected_at>` for HIGH rows
6. Move the row's halt file (if any) to `ai/align/halts/parked/<YYYY-MM-DD>-<id>.md`.
7. Remove the row from the active phase's "must-be-done" set (it stays in `phase: <N>` for ledger traceability but `/align-gate` no longer blocks on it).

**Why steps 2 and 5 are one contract.** `/align-unpark` refuses to restore a row whose `prior_status` + `prior_phase` are missing or malformed — it mutates nothing and halts. A park that validates the prior status and then discards it produces a row that is parked forever: the only remaining exit is `parked → fixed`, which `@align-ledger-auditor` reconciliation 2 flags as an illegal transition. Writing both fields is not bookkeeping; it is the entire difference between a deferral and a deletion.

## Phase 3 — Retrieve (read the right context)

- The row's full ledger entry.
- The row's halt file (if exists).

## Phase 4 — Generate (produce the output)

Pre-execution display:

```
Park finding A047

Class:         AL-15 (permission gate drop)
Severity:      high
Tier:          heavy
Phase:         3 (gates and permission wrappers)
Status:        halted (since 2026-04-19, 2 days)

Halt reason (from ai/align/halts/A047.md):
  add-gate verb halted; the oracle (ai/conventions.md:39) names
  <Can action="…"> from @acme/ui, but no `orders.refund` ability is
  declared in packages/ui/src/can/permissions.ts.

Park reason:
  "Idiom missing — the refund ability must be declared first
  (/setup-project --refine). Defer to phase 4 after refine."

Override:  --override-high="<who decided, and until when>"   (A047 is HIGH)

Blocker category: idiom-missing
Unpark after: refine completes (target: 2026-04-25)

Effects:
  - status: halted → parked
  - prior_status: halted     ← restored by /align-unpark
  - prior_phase: 3           ← restored by /align-unpark
  - phase 3's gate no longer blocks on A047
  - row stays in ledger with phase: 3 (historical)
  - halt file archived to ai/align/halts/parked/

Confirm? [y/N]
```

Note what this display would produce **without** an override, because A047 is HIGH:

```
REFUSED: A047 is HIGH (AL-15 permission gate).

Parking it removes it from every escalation this pack has:
  - /align-gate 3 stops blocking on it
  - the 24h HIGH-row escalation keys on status=halted; it will no longer be halted
  - its halt file leaves halts/, so the "same reason on >= 3 rows" detector loses it

The blocker is real (no orders.refund ability is declared).
Three ways forward:
  /setup-project --refine          declare the ability, then re-run the verb   ← preferred
  /align-park A047 --override-high="<who decided, and until when>"
  leave it halted                  the 24h clock keeps running, which is the point
```

Post-execution summary:

```
Finding A047 parked.

Status:        halted → parked
Reason:        Idiom missing — needs /setup-project --refine ...
Blocker:       idiom-missing
Unpark after:  refine completes (target: 2026-04-25)

Halt file archived: ai/align/halts/parked/2026-04-21-A047.md
Phase 3 unblocked: 4/4 active rows can advance to gate.

Next:
  /align-gate 3                    (now no longer blocked by A047)
  /align-unpark A047               (revive when blocker clears)
  /align-status --blockers          (review all parked findings)
```

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/align/ledger.md` — row updated with park fields.
- `ai/align/halts/parked/<YYYY-MM-DD>-<id>.md` — halt file archived here (if existed).
- `ai/align/park-history.md` — append one line: `<iso> A<id> parked | blocker: <category> | reason: <reason>`.

NO source modification. NO commit.

## Phase 6 — Validate (verify correctness)

- Row's status is now `parked`.
- Park fields populated (`parked_at`, `parked_reason`, `parked_blocker`, `parked_unpark_after`).
- **Revival fields populated and non-empty: `prior_status` ∈ {detected, planned, in-progress, halted} and `prior_phase` is an integer.** If either is absent, the park is INCOMPLETE — revert the row and halt. This is the check that makes the park reversible; it is not optional and it is not a warning.
- For a HIGH row: `parked_sla_from` present, the `--override-high` reason in `parked_reason`, and a `HIGH-PARK` line in `_history.md`.
- Halt file moved (if existed).
- `/align-gate` for the row's phase no longer blocks on this row.

## Phase 7 — Improve (feed the learning loop)

- If `--blocker=idiom-missing` is the most common parked-blocker, surface "queue `/setup-project --refine` priority".
- If a parked row has been parked > 90 days without unpark, surface "consider re-classification or deprecation".
- Trend analysis: count parks per blocker category over time; surface in `/align-status` if trends emerge.

## Output to user

Pre-execution display + post-execution summary (above).

## Hard rules

- **Append-only ledger.** Park doesn't delete the row; it transitions state.
- **Reason mandatory.** Park without a reason is a refusal. The reason is what makes park different from "ignore".
- **Park doesn't fix.** A parked row is outstanding work; `/align-final` surfaces it, by class.
- **State validation.** Cannot park `fixed` / `verified` / already-`parked` / `archived-*` rows.
- **Confirmation mandatory** (except `--no-confirm`). Silent park is forbidden — explicit deferral.
- **A park without `prior_status` + `prior_phase` is not a park.** It is an undocumented deletion wearing a reversible label. Write both or refuse.
- **A HIGH row is never parked implicitly.** `--no-confirm` does not carry an override; `--override-high="<reason>"` is the only path and it leaves a `HIGH-PARK` line in `_history.md`.
- **An owner-class row is never parked here.** It is routed to its owner's fix command.

## Failure modes

- **Row not found** — halt; check the id with `/align-status`.
- **Row not in parkable state** — halt; surface current state + valid transitions.
- **Reason missing and `--no-confirm` set** — refuse; reason is mandatory.
- **HIGH row without `--override-high`** — refuse; name the severity and the fact that parking removes it from the 24-hour escalation. Offer `/align-promote-tier` or `/setup-project --refine` (when the blocker is a missing primitive) as the alternatives.
- **`prior_status` could not be read** (row malformed, status field absent) — refuse and mutate nothing. A row you cannot describe is a row you cannot defer.
- **Phase already gated PASS** — surface warning ("park-after-gate is unusual; the gate already passed for this phase"); confirm explicitly.
- **Every remaining row in the phase is parked** — surface it before confirming. The phase will advance and the gate will pass, and neither fact means the phase was aligned.

## Related

### Sibling commands in align pack
- `/align-unpark <id>` — reverses park.
- `/align-status --blockers` — lists parked rows.
- `/align-gate <N>` — phase exit; no longer blocks on parked rows.
- `/align-final` — final report; surfaces parked rows as outstanding.
- `/align-rollback <N>` — alternative for whole-phase issues.
