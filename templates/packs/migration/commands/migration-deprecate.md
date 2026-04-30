---
description: Mark a V1 feature as deprecated — it will NOT be ported to V2. Excludes the feature from plan, gate, and final checks. Requires an ADR. Append-only — deprecated features stay in the ledger forever for historical traceability.
kind: command
pack: migration
---

# /migration-deprecate <feature-id>

## The Premise (read this first)

**State changes are atomic. Confirm before mutating the ledger.** Deprecation is permanent — there is no `/migration-undeprecate`. Read the ledger row, read the cited ADR, verify the ADR is `Accepted` (not `Proposed`), confirm tenant-impact is captured, then mutate. No silent flips. No partial writes. If any pre-condition is missing, halt — do NOT write a half-deprecated row.

For features that exist in V1 but are intentionally being killed in V2 — not ported.

## When to use

- V1 had a feature that's no longer part of the product (deprecated by the business).
- V1 had a feature subsumed by a new V2 feature (split / merge case — see `composes` ledger field).
- V1 had a feature that was always a workaround / hack; V2 doesn't need it.
- V1 had a feature with no users (verified via analytics) → safe to drop.

## When NOT to use

- The feature is hard to port → don't deprecate; use `/migration-park` instead.
- You're not sure if it's needed → keep `unverified`; gather data before deprecating.
- The feature exists in V2 but in a different shape → that's not deprecation, that's `composes`.

## Pre-requisites

- Feature exists in `ai/migration/ledger.md`.
- An ADR exists (or will be created) justifying the deprecation: `ai/decisions/<NNNN>-deprecate-<feature>.md`.
- For multi-tenant projects: tenant-impact analysis done (which tenants used this feature; have they been notified?).

## Phase 1 — Understand (the ask)

Inputs:
- `<feature-id>` — required.
- `--adr=<NNNN>` — required. The ADR number justifying deprecation.
- `--reason=<text>` — required. One paragraph: why this is being killed.
- `--tenant-impact=<low|medium|high>` — required for multi-tenant projects.

## Phase 2 — Organize (decompose the work)

1. Verify ADR exists in `ai/decisions/`.
2. Update ledger row to `status: deprecated`.
3. Capture deprecation context in `ai/migration/deprecated/<feature-id>.md`.
4. Append history entry.
5. (Optional) flag related features that depended on this one — they may need adjustment.

## Phase 3 — Retrieve (read the right context)

- Ledger row.
- ADR cited in `--adr=<NNNN>` — read it to confirm it actually deprecates this feature.
- Other ledger rows that may depend on this feature (grep for the feature in their `depends_on` field if present).

## Phase 4 — Generate (produce the output)

### Update ledger row

```yaml
- id: F042
  feature: order-archive
  status: deprecated
  deprecated_at: 2026-04-28T16:00:00Z
  deprecated_by: <user>
  deprecation_adr: ADR-0042
  deprecation_reason: |
    Feature was a 2023 workaround for V1's lack of soft-delete.
    V2 has native soft-delete; archive is redundant.
    Analytics shows 0 calls in last 90 days.
    Tenant impact: low — 2 tenants used it; both notified 2026-04-15.
  tenant_impact: low
  v1_path: <still recorded for audit>
  v2_path: <unmapped — never going to V2>
```

### Write `ai/migration/deprecated/F042.md`

```markdown
---
feature_id: F042
deprecated_at: 2026-04-28T16:00:00Z
adr: ADR-0042
tenant_impact: low
---

# Deprecated: order-archive (F042)

## ADR
ai/decisions/0042-deprecate-order-archive.md

## Reason
<full text from --reason>

## Tenant impact
- Risk level: low
- Affected tenants: 2 (TenantA, TenantB)
- Notification: 2026-04-15 via <channel>
- Sunset date: 2026-05-15 (V1 endpoint returns 410 Gone after this)

## V1 → V2 path
- V1 path: <v1/path>
- V2 path: <unmapped — never going to V2>
- V2 alternative for users: <V2 path or "no replacement; use V2's native soft-delete">

## Cross-references
- Features that depended on this: <list>
- Features that supersede this: <list, if any>
```

### Append history

```
<ts> | deprecate | F042 | adr: ADR-0042 | tenant-impact: low
```

## Phase 5 — Update (persist changes to the knowledge base)

- Ledger row (managed-block update).
- `ai/migration/deprecated/<id>.md` (new file; immutable).
- `_history.md` appended.
- (Optional) cross-references in dependent features' ledger rows: add `note: depends_on F042 which is deprecated` so they get reviewed.

## Phase 6 — Validate (verify correctness)

- ADR exists at the cited path.
- ADR's `Status` is `Accepted` (not `Proposed` or `Rejected`).
- Tenant-impact field is set (in multi-tenant projects).
- Reason is non-empty + non-trivial (≥1 sentence).
- No active feature has `composes: [<this-feature-id>]` — if any do, halt; the dependent feature must be re-evaluated first.

## Phase 7 — Improve (feed the learning loop)

- Track deprecation rate per migration. High rate (>20%) suggests V1 had significant scope creep / dead code.
- Update `ai/migration/scan-report.md` § "deprecated features" to reflect the latest count.
- If the deprecated feature was load-bearing for compliance → flag for audit log review.

## Effect on other commands

- `/migration-status` shows deprecated features in a separate section (not in "active migration").
- `/migration-plan` excludes deprecated features from any phase.
- `/migration-phase <N>` skips deprecated features (no audit / port / verify).
- `/migration-gate <N>` doesn't fail on deprecated rows.
- `/migration-final` reports deprecated count separately; verifies all are ADR-cited.
- `/migration-rollback <N>` does NOT un-deprecate; deprecation is permanent.

## Output to user

```
Deprecated: F042 (order-archive)
  ADR:               ADR-0042
  Tenant impact:     low
  V1 sunset:         2026-05-15
  Affected features: 0 (no active features depend on F042)

Files written:
  ai/migration/ledger.md (status: deprecated)
  ai/migration/deprecated/F042.md (immutable record)
  ai/decisions/0042-deprecate-order-archive.md (already existed)
  ai/migration/_history.md (appended)

The feature is now excluded from /migration-plan and won't block /migration-final.
```

## Mechanical halt — refuse to mutate without confirmed ADR

Before any ledger write, verify: (1) `--adr=<NNNN>` flag present, (2) ADR file exists at `ai/decisions/<NNNN>-*.md`, (3) ADR's `Status:` is exactly `Accepted` (not `Proposed`, not `Rejected`, not `Superseded`), (4) `--reason` flag present and ≥1 sentence, (5) `--tenant-impact` set on multi-tenant projects, (6) no active feature has `composes: [<this-id>]`. If ANY check fails — halt; print which check failed; write nothing. Atomic: the ledger row, the `deprecated/<id>.md` file, and the history entry are written together or not at all.

## Hard rules

- **ADR mandatory.** No deprecation without an Accepted ADR. Period.
- **Reason mandatory.** Non-trivial; at least 1 sentence.
- **Tenant impact captured** in multi-tenant projects.
- **Deprecation is forever.** No `/migration-undeprecate` command. If you change your mind, create a NEW feature in the ledger and port it; do not unbury.
- **Cross-feature dependencies checked.** If feature X depends on F042 and you deprecate F042, the user must address X first (re-port, deprecate, or document).
- **Append-only record.** `ai/migration/deprecated/<id>.md` is immutable once written.
- **V1 sunset documented.** When does V1 stop serving this endpoint / page / job? Caller-facing sunset date is recorded.

## Related

- `/migration-park <feature-id>` — reversible alternative when you might come back to the feature.
- `ai/decisions/` — where the required ADR lives.
- `ai/migration/deprecated/` — immutable record of every deprecated feature.
- `/migration-status` — surfaces deprecated count separately from active migration.
- `/migration-final` — verifies every deprecated row has a valid ADR.
