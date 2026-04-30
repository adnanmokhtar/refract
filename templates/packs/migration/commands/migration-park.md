---
description: Park a hairy feature so it doesn't block the phase gate. Sets status=parked with a recorded reason. The feature is excluded from current phase scope and from /migration-final's "must-be-done" check (until unparked).
kind: command
pack: migration
---

# /migration-park <feature-id>

## The Premise (read this first)

**State changes are atomic. Confirm before mutating the ledger.** Park is reversible but not free — the row's `prior_status` and `prior_phase` MUST be captured exactly so `/migration-unpark` can restore them. No silent parks (reason mandatory). No parking `done` rows. No partial writes — ledger row, `parked/<id>.md`, and history entry land together or not at all. If any pre-condition fails, halt; mutate nothing.

The relief valve. Use when one feature in a phase is genuinely stuck (third-party blocker, requires human decision, technical debt that needs its own ADR) and you don't want it blocking the entire phase from gating.

## When to use

- A feature requires a decision the team hasn't made yet (e.g., "what's our data-residency policy for this entity?") — port it later.
- A feature depends on third-party work (vendor API, library upgrade) outside this migration's scope.
- A feature uncovered architectural debt that warrants its own design discussion (separate from migration).
- The audit revealed an `intentional-break` proposal you're not ready to ADR yet.

## When NOT to use

- The feature is just hard → don't park; spend the time. Parking is for blockers, not difficulty.
- The feature has a parity test that's flaky → fix the test, don't park.
- The user wants to skip a feature → use `status: deprecated` (`/migration-deprecate <id>`), not `parked`.

## Pre-requisites

- Feature exists in `ai/migration/ledger.md`.
- Feature's current status is `unverified`, `in-flight`, or `failed` (cannot park `done` features).

## Phase 1 — Understand (the ask)

Inputs:
- `<feature-id>` — required. ID from the ledger.
- Reason — user-supplied (required). One paragraph minimum.
- `--blocker=<type>` — optional. One of: `decision-pending`, `third-party`, `arch-debt`, `adr-needed`, `other`.

## Phase 2 — Organize (decompose the work)

Park action:
1. Update ledger row: `status=parked`, `parked_reason=<text>`, `parked_at=<ts>`, `parked_blocker=<type>`.
2. Remove feature from current phase's effective scope (next `/migration-gate <N>` won't fail on this row).
3. Append entry to `ai/migration/_history.md`.
4. Create `ai/migration/parked/<feature-id>.md` capturing the full parking context.

## Phase 3 — Retrieve (read the right context)

- Ledger row for `<feature-id>`.
- Audit file (`ai/migration/audits/<feature-id>.md`) if it exists — preserve any findings.
- Phase plan section for the feature's phase.

## Phase 4 — Generate (produce the output)

### Update ledger row (managed-block)

```yaml
- id: F042
  feature: order-export
  status: parked
  parked_reason: |
    Awaiting decision on data-residency policy for V2.
    Compliance review in progress (ticket: COMP-1234).
    Re-evaluate when policy lands.
  parked_blocker: decision-pending
  parked_at: 2026-04-28T15:32:00Z
  parked_by: <user>
  prior_status: unverified
  prior_phase: 4
```

### Write `ai/migration/parked/F042.md`

```markdown
---
feature_id: F042
parked_at: 2026-04-28T15:32:00Z
blocker: decision-pending
---

# Parked: order-export (F042)

## Reason
<full text>

## What's needed to unpark
- Decision on data-residency policy.
- Compliance review (COMP-1234) lands.
- ADR authored if policy creates an intentional-break.

## State at park time
- V1 path: <v1/path>
- V2 path: <v2/path>
- Original phase: 4
- Audit findings (if any): <link to audit file>

## When to revisit
- After COMP-1234 closes.
- Before V1 retirement final sweep.
```

### Append history entry

```
<ts> | park | F042 | blocker: decision-pending | reason: <one-line>
```

## Phase 5 — Update (persist changes to the knowledge base)

- Ledger row (managed-block).
- `ai/migration/parked/<feature-id>.md` (new file; append-only history per feature).
- `ai/migration/_history.md` appended.

## Phase 6 — Validate (verify correctness)

- Feature's prior status preserved in `prior_status` field (so unparking can restore correctly).
- Feature's phase number preserved in `prior_phase`.
- Reason is non-empty (no silent parks).
- `parked/<feature-id>.md` exists and is well-formed.

## Phase 7 — Improve (feed the learning loop)

- If `parked_blocker=third-party` accumulates → flag for project-level dependency review.
- If `parked_blocker=arch-debt` accumulates → consider pausing migration for an architecture spike.
- Parked-but-never-unparked features after 90 days → flag in `/migration-status` so they don't quietly accumulate.

## Sibling: `/migration-unpark <feature-id>`

Reverses parking. Restores `prior_status` and `prior_phase`, deletes the `parked/<id>.md` file (or archives it under `parked/_resolved/`), appends to history. Same flag pattern as park.

```
/migration-unpark F042
```

Re-run `/migration-replan` after unparking ≥3 features so their phasing is fresh.

## Output to user

```
Parked: F042 (order-export)
  Blocker:    decision-pending
  Phase:      4 (preserved as prior_phase)
  Status:     parked (was: unverified)

Files written:
  ai/migration/ledger.md (row updated)
  ai/migration/parked/F042.md (new)
  ai/migration/_history.md (appended)

To unpark:
  /migration-unpark F042

Phase 4 gate will no longer block on F042.
```

## Mechanical halt — refuse atomic park without confirmation

Before any write, verify: (1) feature exists in ledger, (2) current `status` ∈ {`unverified`, `in-flight`, `failed`} (NOT `done`, NOT `deprecated`, NOT already `parked`), (3) `--reason` is non-empty and ≥1 sentence, (4) `prior_status` + `prior_phase` captured from current row before mutation. If any check fails → halt; print which check failed; write nothing. The three artifacts (ledger row update, `parked/<id>.md`, `_history.md` line) are written together; a partial set is forbidden.

## Hard rules

- **Reason is mandatory.** No silent parks.
- **Prior status preserved.** Unparking must restore exactly the state at park time.
- **Park is reversible; deprecate is not.** If you're sure the feature won't ever be ported, use `/migration-deprecate <id>` instead.
- **Parked features must surface.** `/migration-status` and `/migration-final` always list parked rows so they don't quietly rot.
- **Stale parks flagged.** Parked > 90 days appears as a warning in `/migration-status`.

## Related

- `/migration-unpark <feature-id>` — sibling; reverses parking.
- `/migration-deprecate <feature-id>` — terminal alternative to parking when feature wont ever be ported.
- `/migration-replan` — run after unparking 3+ features.
- `/migration-status` — surfaces stale parks (>90d).
- `ai/migration/parked/` — directory holding per-feature park context.
