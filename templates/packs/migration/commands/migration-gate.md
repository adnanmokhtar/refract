---
description: Phase exit gate. Reads ledger + audits, confirms every feature in phase N is status=done with parity-test=passing. Refuses success on any failure. Read-only — never writes (except a one-line history entry).
kind: command
pack: migration
---

# /migration-gate <N>

The phase exit verifier. Run after `/migration-phase <N>`. Refuses pass on any blocking issue. The next phase MUST NOT start until this is green.

## Pre-requisites

- Argument N is a valid phase from `ai/migration/plan.md`.
- `/migration-phase <N>` has been run.

## Phase 1 — Understand (the ask)

Inputs:
- `<N>` — phase number (required).
- `ai/migration/plan.md` — phase definition (which features are in phase N).
- `ai/migration/ledger.md` — feature status.
- `ai/migration/audits/` — per-feature audit files.

## Phase 2 — Organize (decompose the work)

For each feature listed in phase N:
- Confirm status = `done` OR `intentional-break` (with ADR-NNNN).
- Confirm parity_test = `passing`.
- Confirm an `audits/<feature-id>.md` exists.
- Confirm any cited ADR exists in `ai/decisions/`.

## Phase 3 — Retrieve (read the right context)

- Plan (phase N section).
- Ledger.
- Each audit file for this phase's features.
- ADRs cited as `intentional-break` justification.

## Phase 4 — Generate (produce the output)

Build a gate report:

```markdown
# Phase <N> gate report — <YYYY-MM-DD>

Plan section: ai/migration/plan.md § Phase <N>
Features in phase: <Y>

## Per-feature verification

| ID | Feature | status | parity_test | audit | ADR (if break) | Verdict |
|---|---|---|---|---|---|---|
| F001 | auth-login | done | passing | ✓ | — | PASS |
| F002 | tenant-resolver | done | passing | ✓ | — | PASS |
| F003 | shared-error-handler | failed | failing | ✓ | — | **BLOCK** |
| F004 | role-guards | done | passing | — | — | **BLOCK (audit file missing)** |
| ... | | | | | | |

## Blocking issues

- F003: parity_test failing. See ai/migration/audits/F003.md § Verify.
- F004: audit file ai/migration/audits/F004.md not found.

## Verdict

**REFUSED** — 2 blocking issues. Fix and re-run /migration-phase <N>, then re-run /migration-gate <N>.
```

OR if everything passes:

```markdown
## Verdict

**PASS** — phase <N> meets exit criteria. Safe to start phase <N+1>.

Append-once entry written to ai/migration/_history.md:
  <YYYY-MM-DD> | phase <N> | passed | <Y> features | duration: <X> days
```

## Phase 5 — Update (persist changes to the knowledge base)

ONLY on PASS:
- `ai/migration/_history.md` — append one line. (Append-only audit trail of phase completions.)
- `ai/migration/ledger.md` — set per-row `phase_passed_at` timestamp (managed-block update).

On REFUSED → no writes.

## Phase 6 — Validate (verify correctness)

This phase IS the verification — nothing further.

## Phase 7 — Improve (feed the learning loop)

- If gate passes after >2 retries → flag the phase complexity for future estimates.
- If a specific feature failed multiple times before passing → log the pattern for `ai/_baseline/failures/`.
- If `intentional-break` ADRs cluster around one domain → that's an architectural signal worth a follow-up review.

## Output to user

On PASS:
```
Phase <N>: PASS
  Features: <Y>
  All status=done OR intentional-break (with ADR)
  All parity tests passing
  All audits present

Next: /migration-phase <N+1>
```

On REFUSED:
```
Phase <N>: REFUSED — <count> blocking issues.

  <list of failing features with reason + remediation pointer>

Fix the blockers; re-run /migration-phase <N>; then re-run /migration-gate <N>.
```

## Hard rules

- **Read-only on REFUSED.** Never modifies ledger or any artifact when refusing.
- **One row per success.** `_history.md` is append-only; no edits to past entries.
- **No partial passes.** A phase with ANY blocking issue REFUSES. There is no "passed with caveats" — fix it or document an `intentional-break` ADR.
- **Audit-file presence is mandatory.** A `done` row without an audit file = data integrity failure → REFUSE.
- **ADR existence is verified.** Cited `intentional-break: ADR-NNNN` must point to a real file in `ai/decisions/`.

## Related

- `/migration-phase <N>` — runs before this gate; produces what's audited.
- `/migration-final` — runs after all gates; the final sweep across phases.
- `/migration-rollback <N>` — use if this gate refuses and the phase needs reverting.
- `ai/migration/_history.md` — append-only log this command writes one line to on PASS.
