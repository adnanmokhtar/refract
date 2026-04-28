---
description: Compare a feature / module / endpoint between V1 and V2. Reports parity findings + behavior divergences + structural differences + ports needed. Read-only — never modifies code.
---

# /compare-v1

Side-by-side comparison of V1 and V2 implementations of the same feature. Use to:
- Audit a "ported" feature for parity (does V2 match V1's observable behavior?).
- Plan a port (understand what V1 does before writing V2).
- Investigate a "regression" reported on V2 that may have existed in V1.

## Phases applied

1, 2, 3, 4 (read-only audit; no Update / Validate / Improve).

## When to use / NOT to use

- USE: pre-port investigation — know V1's behavior before writing V2.
- USE: post-port audit — verify V2 actually matches V1.
- USE: customer reports "V2 broke X" — check if X actually worked in V1.
- USE: as preliminary input to `/migration-phase <N>` for the AUDIT step.
- NOT: full migration audit across all features → `/migration-final`.
- NOT: ledger update → `/migration-status` reads + reports.

## Pre-requisites

- Both V1 and V2 codebases reachable.
- `ai/migration/ledger.md` may exist (helpful but not required).
- Project-specific anchors filled (V1 root + V2 root) by Phase 4.6.

## Phase 1 — Understand

Confirm:
- Feature / module / endpoint to compare (e.g., "auth-login", "GET /api/orders", "OrderListScreen").
- V1 location: `<v1-root>/<path>`.
- V2 location: `<v2-root>/<path>` (or `<unmapped>` if V2 doesn't yet implement).
- Comparison axes the user cares about (default: all):
  - Inputs (request shape, query params, headers).
  - Outputs (response shape, status codes, headers).
  - Error contract (codes, messages, retry behavior).
  - Auth + permissions (who can call, what's denied).
  - Side effects (DB writes, queue publishes, external API calls, audit log entries).
  - Performance envelope (P50 / P95 latency budget).

## Phase 2 — Organize

Walk each axis sequentially:

1. **Read V1 source.** Trace from entry point (route handler / view / controller) through to data layer.
2. **Read V2 source** if it exists. Same trace.
3. **Note divergences per axis.** Each divergence is a finding.
4. **Classify each finding:**
   - **parity-clean** — V2 matches V1 across all axes.
   - **missing-in-v2** — V2 has no implementation.
   - **divergent** — V2 implements but behavior differs.
   - **intentional-break** — V2 differs by design (cite ADR if known).
   - **shape-only** — V2 file exists but is empty / scaffold.

## Phase 3 — Retrieve

For each side, read:
- Entry point file (controller / handler / view).
- Service / use-case file.
- Repository / data-access file.
- DTO / serializer / schema definitions.
- Validation rules (Zod / class-validator / form requests / serializers).
- Tests (unit + integration + e2e if any).
- Permission decorators / guards.
- Logging / metrics emitted.

For V1: pin a commit (`git -C <v1-root> rev-parse HEAD`). Future re-runs compare against the same V1 state.

## Phase 4 — Generate (the comparison report)

```
## V1↔V2 comparison — <feature> — <date>

### Identity
- Feature:    <name>
- V1 path:    <v1-root>/<path>  @ commit <sha>
- V2 path:    <v2-root>/<path>  @ commit <sha> (or "MISSING")

### Verdict (overall)
**<parity-clean | missing-in-v2 | divergent | intentional-break | shape-only>**

### Per-axis findings

#### Inputs
| Axis | V1 | V2 | Match? |
|---|---|---|---|
| Method | POST | POST | ✓ |
| Path | /api/v1/orders | /api/orders | ⚠ — versioned in V1, unversioned in V2 |
| Body shape | { items: [...], shipping_address, payment_method } | { items, shippingAddress, paymentMethodId } | **DIVERGENT** — field names changed (snake_case → camelCase); shipping_address structure differs |
| Required fields | items, shipping_address, payment_method | items, shippingAddress, paymentMethodId | ✓ semantically |
| Headers | X-Tenant-Id, Authorization | Authorization (tenant from JWT) | **DIVERGENT** — V2 derives tenant from token, V1 from header |
| Query params | none | ?currency (optional) | V2 added optional |

**Verdict (Inputs):** divergent — field-name + tenant-resolution changes.

#### Outputs
| Axis | V1 | V2 | Match? |
|---|---|---|---|
| Status (success) | 201 | 201 | ✓ |
| Status (validation fail) | 400 with `{ errors: [{ field, message }] }` | 422 with Pydantic-shaped `{ detail: [{ loc, msg, type }] }` | **DIVERGENT** — status code AND shape changed |
| Status (auth fail) | 401 | 401 | ✓ |
| Body shape (success) | { order: { id, status, total } } | { id, status, total, _links } | **DIVERGENT** — wrapper removed; HATEOAS links added |
| Headers | none | X-RateLimit-Remaining | V2 added |

**Verdict (Outputs):** divergent — multiple shape changes.

#### Error contract
| V1 | V2 |
|---|---|
| insufficient inventory → 409 | insufficient inventory → 409 ✓ |
| payment declined → 402 | payment declined → 422 (subsumed under validation) **DIVERGENT** |
| rate limit → 429 (no Retry-After) | rate limit → 429 with Retry-After header ✓ improvement |

#### Auth + permissions
| V1 | V2 |
|---|---|
| Roles allowed: tenant_member, tenant_admin | Roles allowed: tenant_member, tenant_admin ✓ |
| Auth method: session cookie + CSRF token | Auth method: JWT bearer **DIVERGENT** |
| Tenant scope: from header | Tenant scope: from JWT claim **DIVERGENT** |

#### Side effects
| V1 | V2 |
|---|---|
| Insert into orders table | Insert into orders table ✓ |
| Insert into order_items table | Insert into order_items table ✓ |
| Publish OrderCreated to RabbitMQ | Publish OrderCreated to Kafka **DIVERGENT** (different broker) |
| Send email via SendGrid | Send email via Postmark **DIVERGENT** (vendor change) |
| Audit log entry | Audit log entry ✓ |
| Stripe charge | Stripe charge ✓ |

#### Performance envelope
| Metric | V1 (last 7d) | V2 (last 7d) | Status |
|---|---|---|---|
| P50 | 120 ms | 95 ms | improvement |
| P95 | 380 ms | 290 ms | improvement |
| P99 | 950 ms | 1100 ms | regression |
| Throughput | 240 req/sec | 180 req/sec | regression |

### Summary of divergences

**Intentional breaks (with cited ADR):**
- ADR-0017: tenant from JWT (not header) — design choice.
- ADR-0023: Switch from RabbitMQ to Kafka — infra consolidation.
- ADR-0029: Snake_case → camelCase API naming.

**Unintentional divergences (need attention):**
- Validation error status: 400 → 422 (BREAKING for clients). Was this discussed? No ADR. **Action**: confirm intentional or revert.
- Wrapper field `order` removed from response. Was this discussed? No ADR. **Action**: confirm intentional or revert.
- Email vendor change SendGrid → Postmark. ADR present. ✓
- P99 regression + throughput drop. **Action**: investigate via `/profile-perf`.

### Parity-test recommendations

Tests that should exist (some may already; verify):
1. POST /api/orders with V1-shaped body → server normalizes; V2 internal handles either shape.
2. Validation error response: snapshot the V1 + V2 shapes; if a 3rd-party client integrates, surface the change.
3. Payment-declined response: V2 subsumes under 422; verify clients can still detect "payment specifically failed" from the error body.

### Open questions (for human review)
- Was the response wrapper removal intentional or oversight?
- Was the validation status code change (400 → 422) discussed?
- Is the P99 regression in V2 acceptable or a bug to fix before more cutover?
```

## Output format

```
## /compare-v1 — <feature>

V1 path: <path> @ <sha>
V2 path: <path> @ <sha or "MISSING">

Verdict: parity-clean / missing-in-v2 / divergent / intentional-break / shape-only

Divergences (summary):
- intentional-break (ADR-cited): <count>
- divergent (no ADR): <count>  ← needs review
- missing in V2: <count>

Report: ai/migration/audits/<feature>-compare-<date>.md
```

## Hard rules

- **Read-only.** Never edits code. Findings only.
- **Cite the V1 commit.** Without pinning, audit comparisons drift.
- **Distinguish intentional break (ADR-cited) from unintentional divergence (no ADR).** The latter is the actionable category.
- **Per-axis verdict.** Don't compress to "they're different" — say which dimensions match and which don't.
- **No PII / secrets in the report.**

## Failure modes

- Compared the wrong V1 commit (e.g., V1 has been updated since the original port).
- Missed a side effect that fires conditionally (only on certain inputs).
- Treated a refactor (same behavior, different code shape) as a divergence.
- Compared static code without verifying actual runtime behavior — V1 may have a config flag that changes behavior.
- Performance comparison across different traffic patterns (V1 has 10× the load) — normalize before declaring regression.

## Related

- `/migration-scan` — bulk version of this command (audits all features).
- `/migration-phase <N>` — uses this comparison in its AUDIT step.
- `@parity-auditor` agent — produces compare reports as part of audit.
- `extract-v1-contract` skill — captures V1 behavior in structured form.
- `parity-testing` pattern — golden-master / record-replay test patterns.
- `migration-discipline` rule — parity-non-negotiable contract.

## Related

### Sibling commands in migration pack
- `/migration-scan` — runs this for every feature.
- `/migration-phase` — uses this in AUDIT step.
- `/migration-status` — reads ledger; this command writes individual comparison reports.
- `/port-feature` — uses this in pre-port investigation.
