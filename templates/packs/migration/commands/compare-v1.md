---
description: Compare a feature / module / endpoint between V1 and V2. Reports parity findings + behavior divergences + structural differences + ports needed. Read-only — never modifies code.
kind: command
pack: migration
allowed-tools: [Read, Grep, Glob, Bash, Task]
---

# /compare-v1

## The Premise (read this first)

**V1 is production. V1 is the truth.** Every comparison axis here measures V2 *against V1's observable behavior* — not against an idealized spec, not against the V2 author's recollection. Read before writing. Cite real V1 paths with a pinned commit; never invent paths or paraphrase what "V1 probably does." If V1 source is genuinely unreachable, halt — do not fabricate a comparison row.

**Read-only command.** No edits, no ledger writes, no auto-fixes. Findings only.

Side-by-side comparison of V1 and V2 implementations of the same feature. Use to:
- Audit a "ported" feature for parity (does V2 match V1's observable behavior?).
- Plan a port (understand what V1 does before writing V2).
- Investigate a "regression" reported on V2 that may have existed in V1.

## Mechanical halt — refuse hand-waved findings

The comparison report MUST cite `<v1-path:line>` AND `<v2-path:line>` for every per-axis row. Forbidden tokens in any axis cell: `...`, `etc.`, `and so on`, `N+ filters`, `looks similar`, `appears to match`, `roughly equivalent`, `deferred to port-phase`. If V1 source cannot be read for an axis, the verdict is `unknown — V1 source unreadable at <path>`, NOT a guess. A report containing any forbidden token is invalid; halt and re-run the read.

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
| Publish OrderCreated to broker-A | Publish OrderCreated to broker-B **DIVERGENT** (different broker) |
| Send email via email-vendor-A | Send email via email-vendor-B **DIVERGENT** (vendor change) |
| Audit log entry | Audit log entry ✓ |
| Charge via payment-provider | Charge via payment-provider ✓ |

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
- ADR-0023: Switch broker (broker-A → broker-B) — infra consolidation.
- ADR-0029: Snake_case → camelCase API naming.

**Unintentional divergences (need attention):**
- Validation error status: 400 → 422 (BREAKING for clients). Was this discussed? No ADR. **Action**: confirm intentional or revert.
- Wrapper field `order` removed from response. Was this discussed? No ADR. **Action**: confirm intentional or revert.
- Email vendor change (vendor-A → vendor-B). ADR present. ✓
- P99 regression + throughput drop. **Action**: investigate via `/profile-perf`.

### Parity-test recommendations

Tests that should exist (some may already; verify):
1. POST /api/orders with V1-shaped body → server normalizes; V2 internal handles either shape.
2. Validation error response: snapshot the V1 + V2 shapes; if a 3rd-party client integrates, surface the change.
3. Payment-declined response: V2 subsumes under 422; verify clients can still detect "payment specifically failed" from the error body.

### Open questions (decide before the fix lands)

Each row is a decision YOU make. State the recommendation, WHERE the answer gets recorded, and WHICH command consumes it — never leave a bare question.

| # | Question | Recommendation | Where to answer | Consumed by |
|---|---|---|---|---|
| 1 | Was the response wrapper removal intentional? | revert (no ADR justifies it) | reply here, or add `ADR-NNNN` if intentional | `/find-and-fix <feature>` |
| 2 | Validation status 400 → 422 — discussed? | keep 422, document it | new `ADR-NNNN` (new error contract) | `/find-and-fix <feature>` |
| 3 | Is the P99 regression acceptable? | investigate before cutover | reply here | `/profile-perf <feature>` |

### Next steps (do this next)

This was a **read-only** audit — nothing was changed. To act on it:

1. **Answer the open questions above** (reply in chat, or create the ADR(s) noted in the "Where to answer" column). Any question marked *new error contract* / *intentional break* needs an ADR before the fix; routine reverts just need your "yes, fix it".
2. **Apply the fixes** — for each `divergent (no ADR)` finding:
   - routine port → `/find-and-fix <feature>` (drives detect→fix→verify→record).
   - security / contract-breaking / cross-repo → `/port-feature --heavy <feature>`.
3. **Verify parity** — `/migration-gate <phase>` (or re-run `/compare-v1 <feature>`) to confirm the divergence is closed.

> If verdict is `parity-clean` and there are no open questions, there is nothing to do — stop here.
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

Next steps:
1. Decide the open questions (see report § Open questions) — reply here, or add the ADR(s) noted.
2. Apply fixes: /find-and-fix <feature>  (or /port-feature --heavy for security/contract/cross-repo).
3. Verify: /migration-gate <phase>  (or re-run /compare-v1 <feature>).
(parity-clean + no open questions → nothing to do.)
```

Every `/compare-v1` run MUST end its terminal output with this **Next steps** block. A report that states a verdict but leaves the user without a next command is incomplete — surface what to run and where to answer.

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
