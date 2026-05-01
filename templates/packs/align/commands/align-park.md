---
description: Park a hairy alignment finding so it doesn't block the phase gate. Sets status=parked with a recorded reason. The finding is excluded from current phase scope and from /align-final's "must-be-done" check (until unparked). Append-only — parked findings stay in the ledger forever for historical traceability.
kind: command
pack: align
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
- A finding the team has decided NOT to fix at all — that's a `/align-deprecate` (if such command exists; otherwise mark `archived-deprecated`).

## Pre-requisites

- `ai/align/ledger.md` exists.
- The finding `<id>` exists in the ledger.
- The finding's `status` is one of: `detected`, `in-progress`, `halted`. (Cannot park a `fixed` / `verified` row.)

If pre-requisites missing → halt + report.

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
2. Validate state transition (detected | in-progress | halted → parked).
3. Demand confirmation from user (display the row + reason; require explicit y/N).
4. Update the ledger row: `status: parked`, `parked_at: <iso>`, `parked_reason: <reason>`, `parked_blocker: <category>`, `parked_unpark_after: <date|event>`.
5. Move the row's halt file (if any) to `ai/align/halts/parked/<YYYY-MM-DD>-<id>.md`.
6. Remove the row from the active phase's "must-be-done" set (it stays in `phase: <N>` for ledger traceability but `/align-gate` no longer blocks on it).

## Phase 3 — Retrieve (read the right context)

- The row's full ledger entry.
- The row's halt file (if exists).

## Phase 4 — Generate (produce the output)

Pre-execution display:

```
Park finding A047

Class:         security/sql-injection
Severity:      critical
Tier:          heavy
Phase:         3 (security critical)
Status:        halted (since 2026-04-19, 2 days)

Halt reason (from ai/align/halts/A047.md):
  parameterize verb halted; the project's parameterized-query primitive
  named in _extracted-idioms.md (src/db/query.ts:14) does not exist.
  The codebase uses raw template literals for SQL throughout.

Park reason:
  "Idiom missing — needs /setup-project --refine to add a parameterized
  query primitive. Defer to phase 4 after refine."

Blocker category: idiom-missing
Unpark after: refine completes (target: 2026-04-25)

Effects:
  - status: halted → parked
  - phase 3's gate no longer blocks on A047
  - row stays in ledger with phase: 3 (historical)
  - halt file archived to ai/align/halts/parked/

Confirm? [y/N]
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
- Park fields populated (`parked_at`, `parked_reason`, `parked_blocker`).
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
- **Park doesn't fix.** A parked row is outstanding work; `/align-final` surfaces it.
- **State validation.** Cannot park `fixed` / `verified` / already-`parked` / `archived-*` rows.
- **Confirmation mandatory** (except `--no-confirm`). Silent park is forbidden — explicit deferral.

## Failure modes

- **Row not found** — halt; check the id with `/align-status`.
- **Row not in parkable state** — halt; surface current state + valid transitions.
- **Reason missing and `--no-confirm` set** — refuse; reason is mandatory.
- **Phase already gated PASS** — surface warning ("park-after-gate is unusual; the gate already passed for this phase"); confirm explicitly.

## Related

### Sibling commands in align pack
- `/align-unpark <id>` — reverses park.
- `/align-status --blockers` — lists parked rows.
- `/align-gate <N>` — phase exit; no longer blocks on parked rows.
- `/align-final` — final report; surfaces parked rows as outstanding.
- `/align-rollback <N>` — alternative for whole-phase issues.
