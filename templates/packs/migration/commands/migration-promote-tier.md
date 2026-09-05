---
description: Promote (or demote) a migration ledger row's tier mid-port. When the agent realizes a row's tier was wrong (scan classified standard, but fix touches > 25 files; or trivial port turns out to remove a public API symbol), this command updates the ledger row, backfills required artifacts for the new tier, and resumes the fix loop. Demotion of P0 / cross-repo / contract-break / write-path / security rows is forbidden.
kind: command
pack: migration
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /migration-promote-tier <feature-id> <new-tier> [--reason="<text>"]

## The Premise (read this first)

**Tier is set at scan, but real-world ports surface complexity.** Sometimes mid-port the agent realizes:
- A "trivial" port turns out to remove a symbol used by 47 sibling repos.
- A "standard" port hits a P0 finding the audit missed.
- A "heavy" port is actually mechanical after the user reviews the audit.

This command lets you change a row's tier explicitly, with the ceremony required for the new tier:
- **Promotion** (trivial → standard → heavy): backfill required artifacts before resuming.
- **Demotion** (heavy → standard → trivial): requires `--reason=`. Some demotions are forbidden.

## When to use

- Mid-port halt: agent surfaces "tier mismatch — recommend promotion."
- Code review: reviewer says "this needs a contract" → promote to standard.
- Audit re-classification: a standard row's audit shows it's actually heavy.
- Late simplification: a heavy row turns out to be 1-line; demote with rationale.

## When NOT to use

- A row that's already `done` / `verified` — tier is locked post-completion.
- A row that's deprecated / parked — change status instead.
- To skip artifact requirements — promotion REQUIRES backfill; this is not a shortcut.

## Pre-requisites

- `<feature-id>` must exist in `ai/migration/ledger.md`.
- Row's status must be one of: `unverified`, `in-flight`, `halted`, `failed`, `pending-review`. Done / deprecated / parked rows refuse promotion.

## Args

- `<feature-id>` — ledger row ID (e.g., `F042`).
- `<new-tier>` — `trivial` | `standard` | `heavy`.
- `--reason="<text>"` — required for demotion. Free text; logged in `_history.md`.

## Forbidden demotions

The following rows CANNOT be demoted, regardless of `--reason`:
- Any row whose audit flagged a **P0** finding.
- Any row with a **cross-repo** dependency (has a `cross_repo_task` field).
- Any row that is a **contract break** (has an associated ADR).
- Any row touching **write-path mutation** (data-changing endpoints).
- Any row in the **security** finding class (security rows can't fall below standard ever).

The command halts with the specific reason if any of these apply.

## Phase 1 — Understand (the ask)

Reads:
- `ai/migration/ledger.md` — current row state.
- `ai/migration/audits/<feature>.md` (if exists) — current audit.
- `ai/migration/contracts/<feature>.md` (if exists) — current contract.

Validates:
- Feature ID exists.
- Row is in promotable state.
- New tier is valid + different from current tier.
- For demotions: forbidden-demotion checks pass.

## Phase 2 — Organize (decompose the work)

```
1. VALIDATE      — confirm row state + tier transition allowed
2. CLASSIFY      — promotion or demotion?
3. BACKFILL      — generate / extend artifacts for new tier
4. UPDATE LEDGER — flip tier field, append history note
5. RESUME        — agent re-enters fix loop with new tier's discipline
```

## Phase 3 — Retrieve (read the right context)

For backfill (promotion):
- **trivial → standard**: read V1 source for the feature; agent extracts a 3-section contract (Inputs / Outputs / Known V1 bugs) + a short plan.
- **standard → heavy**: full 8-artifact set per `migration-discipline.md § Heavy-tier artifact spec` — contract (9 sections), plan, parity tests (≥30 fixtures + tolerance.yaml + golden snapshots), perf-decisions, rollback runbook, audit, mapping, ledger row update.

## Phase 4 — Generate (produce the output)

### Promotion: backfill artifacts

For trivial → standard:
- Generate `ai/migration/contracts/<feature>.md` with 3 sections (or skip if exists and complete).
- Generate `ai/migration/plans/<feature>.md` with V2 module shape + non-goals.
- Generate parity test scaffold at `<parity-test-root>/<feature>/`.

For standard → heavy:
- Backfill remaining artifacts: tolerance.yaml, perf-decisions, rollback runbook, mapping doc, API samples (if service layer touched).
- Trigger reviewer-approval flow: write `ai/migration/halts/<id>-pending-review.md`.

### Demotion: cleanup (optional)

The command does NOT delete artifacts on demotion. Demoting heavy → standard leaves the heavy artifacts in place; they're harmless overhead and document the prior tier-decision history.

The user may delete them manually if desired, but the command leaves them.

### Update ledger

```yaml
- id: F042
  ...
  tier: standard           # was: trivial
  tier_history:
    - 2026-04-15: trivial (set by scan)
    - 2026-05-02: trivial → standard | reason: "fix touches 18 files; cross-component swap"
  ...
```

### Append `_history.md`

```
2026-05-02T18:30Z  promote-tier F042  trivial → standard  reason: "fix touches 18 files; cross-component swap"
```

## Phase 5 — Update (persist changes)

- `ai/migration/ledger.md` — `tier:` field updated; `tier_history` appended.
- `ai/migration/_history.md` — one-line entry.
- `ai/migration/contracts/<feature>.md` etc. — backfilled if promotion.
- `ai/migration/halts/<id>-pending-review.md` — created if promotion to heavy.

## Phase 6 — Validate (verify correctness)

- Tier field reflects the new tier.
- Tier history has the new entry.
- Required artifacts for the new tier all exist.
- Forbidden-demotion check passed (or command halted earlier).

## Phase 7 — Improve (feed the learning loop)

- If the same row promotes twice (trivial → standard → heavy), surface "scan classified this row two tiers wrong; check scan accuracy."
- If demotions are common in a project, surface "scan over-promotes; tune scan tier rules."

## Output to user

```
Tier promotion: F042 trivial → standard
  Reason:                  fix touches 18 files; cross-component swap
  Backfilled artifacts:
    ai/migration/contracts/F042.md       (3-section contract from V1 source)
    ai/migration/plans/F042.md           (short plan with V2 module shape)
    tests/parity/F042/                   (parity test scaffold; corpus pending)
  Ledger updated:          tier=standard, tier_history appended
  History recorded:        ai/migration/_history.md

Resume: /find-and-fix F042   (now runs with standard-tier discipline)
```

For forbidden demotion:

```
Refused: F058 cannot be demoted from heavy.
  Forbidden demotion reason: row's audit flagged a P0 finding (auth bypass).
  Heavy-tier ceremony is required for security-sensitive rows.

To override (rare): re-run audit, document why P0 was a false positive, and re-attempt.
```

## Hard rules

- **No silent tier change.** Every promotion / demotion writes to `_history.md`.
- **Backfill is required, not optional.** Promotion without backfill is forbidden — the command halts if backfill fails.
- **Forbidden demotions are absolute.** No `--force` flag overrides them.
- **Security rows can't fall below standard.** Always.
- **Tier is locked post-completion.** Done / verified rows refuse tier change. Use `/migration-rollback` first if you really need to redo.

## Failure modes

- **Feature ID not found** → halt; check ledger.
- **Row already at requested tier** → no-op; surface "row is already at tier X."
- **Row in non-promotable state** (done / deprecated / parked) → halt; explain.
- **Backfill artifact generation fails** (e.g., V1 source missing) → halt; row stays at old tier.
- **Forbidden demotion** → halt; explain which forbidden-demotion rule fired.

## Related

### Sibling commands
- `/find-and-fix <id>` — resumes the fix loop after promotion.
- `/migration-status` — shows current tier + tier_history.
- `/migration-rollback <N>` — undoes a phase if tier change cascades.

### Rules
- `.claude/rules/migration-discipline.md § Mid-port tier promotion` — the procedure this command implements.
