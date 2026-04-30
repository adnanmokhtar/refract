---
description: Reverse /migration-park. Restores the feature's prior status and phase. Archives the parked-context file.
kind: command
pack: migration
---

# /migration-unpark <feature-id>

## The Premise (read this first)

**State changes are atomic. Confirm before mutating the ledger.** Unpark restores `prior_status` and `prior_phase` exactly as captured at park time — not a best-guess, not "probably unverified." Read the parked-context file first; verify `prior_status` and `prior_phase` are populated; then mutate ledger row + archive the park file + append history together. Resolution note mandatory. If the parked-context file is missing or malformed, halt; mutate nothing.

Sibling to `/migration-park`. Use when the blocker that caused parking is resolved.

## When to use

- The decision the team was waiting on has been made.
- The third-party blocker (vendor / library / dependency) is unblocked.
- The architectural debt has its own ADR now.
- The intentional-break ADR is written.

## Pre-requisites

- Feature exists in ledger with `status: parked`.
- `ai/migration/parked/<feature-id>.md` exists.

## Phase 1 — Understand (the ask)

Inputs:
- `<feature-id>` — required.
- Resolution note — user-supplied (required). What changed since parking.

## Phase 2 — Organize (decompose the work)

1. Read the parked-context file → confirm what the unblocking criteria were.
2. Restore ledger row to `status: <prior_status>`, `phase: <prior_phase>`.
3. Archive `ai/migration/parked/<feature-id>.md` → `ai/migration/parked/_resolved/<feature-id>.md`.
4. Append history entry.

## Phase 3 — Retrieve (read the right context)

- Ledger row.
- `parked/<feature-id>.md` for the original park context.

## Phase 4 — Generate (produce the output)

### Restore ledger row (managed-block)

```yaml
- id: F042
  status: <prior_status>            # restored from parked.prior_status
  phase: <prior_phase>              # restored from parked.prior_phase
  unparked_at: <ts>
  unparked_reason: <user-supplied>
  # parked_* fields removed; archive captures them.
```

### Archive park file

```bash
mv ai/migration/parked/<id>.md ai/migration/parked/_resolved/<id>.md
```

The archived file is preserved for audit (which features were parked, why, for how long).

### Append history

```
<ts> | unpark | F042 | resolution: <user-supplied>
```

## Phase 5 — Update (persist changes to the knowledge base)

- Ledger row (managed-block update).
- `parked/<id>.md` → `parked/_resolved/<id>.md`.
- `_history.md` appended.

## Phase 6 — Validate (verify correctness)

- Feature row no longer has `parked_*` fields.
- `prior_status` + `prior_phase` correctly restored.
- Archive file is present in `_resolved/`.

## Phase 7 — Improve (feed the learning loop)

- Park duration logged: `(unparked_at - parked_at)`. If consistently > 60 days, flag the team's prioritization (or pause migration to clear the parked queue first).
- If 5+ features unparked at once → suggest `/migration-replan` so phasing is fresh.

## Output to user

```
Unparked: F042 (order-export)
  Status restored:   <prior_status>
  Phase restored:    <prior_phase>
  Park duration:     <X> days

Archive: ai/migration/parked/_resolved/F042.md

Recommend: /migration-replan if you've unparked multiple features in a row.
```

## Mechanical halt — refuse atomic unpark without confirmed prior state

Before any write: (1) ledger row exists with `status: parked`, (2) `prior_status` field populated and ∈ {`unverified`, `in-flight`, `failed`}, (3) `prior_phase` field populated as a valid phase number, (4) `parked/<id>.md` exists and is well-formed, (5) resolution note non-empty. If any check fails → halt; print which check failed; mutate nothing. The three artifacts (ledger row update, archive move to `_resolved/`, history append) land together or not at all.

## Hard rules

- **Resolution note is mandatory.** Audit trail of what changed.
- **Park file archived, not deleted.** `_resolved/` keeps the history.
- **Original park context preserved.** The archive captures `parked_reason`, `parked_blocker`, `parked_at`.

## Related

- `/migration-park <feature-id>` — sibling; this command reverses it.
- `/migration-replan` — strongly recommended after unparking 3+ features.
- `/migration-phase <N>` — once unparked the feature returns to its phases scope.
- `ai/migration/parked/_resolved/` — archive of resolved parks.
