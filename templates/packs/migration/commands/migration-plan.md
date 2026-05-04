---
description: Forces a phased migration plan from the scan output. Groups features into phases by dependency + domain. Sequence within each phase. Honors V2's NEW structure (no lift-and-shift). Stack-agnostic — works for frontend, API, jobs, scripts, anything.
kind: command
pack: migration
---

# /migration-plan

## The Premise (read this first)

**Read before writing. Cite real V1 paths, never invented.** The plan groups features that ALREADY exist in the ledger (produced by `/migration-scan`); it does not invent features, does not paraphrase V1 paths, does not assume V2 modules that don't exist. Every plan row's `v1_path` matches the ledger row exactly; every `v2_path` is either a real V2 file or a planned home cited from `ai/architecture.md`. If the ledger is missing a feature you "remember V1 having," halt and re-run `/migration-scan` — do NOT add a row by hand.

Reads the ledger + scan report, produces `ai/migration/plan.md` — the phased execution plan.

## Pre-requisites

- `/migration-scan` has been run (ledger + scan-report exist).
- `ai/migration/ledger.md` has rows with `status: unverified`.

If pre-requisites missing → halt + tell user to run `/migration-scan` first.

## Phase 1 — Understand (the ask)

Inputs:
- `ai/migration/scan-report.md` — structural deltas + recommended phasing.
- `ai/migration/ledger.md` — feature inventory.
- `ai/architecture.md` — declared V2 module boundaries (constraints).
- ADRs in `ai/decisions/` — past decisions that constrain the order.

Optional flags:
- `--phases=<N>` — target number of phases (default: auto from scan recommendation).
- `--max-features-per-phase=<N>` — cap per phase (default: 12).

## Phase 2 — Organize (decompose the work)

Decomposition strategy, in priority order:

1. **Foundation first.** Auth, tenant resolution, shared infrastructure — every feature depends on these. Phase 1.
2. **Group by domain.** Auth → Tenant → Core flow → Payments → Reporting → Admin → Cleanup.
3. **Honor dependency graph.** A feature that calls another must be ported AFTER its dependency.
4. **Cap phase size.** Phases over `--max-features-per-phase` get split (smaller phases ship more reliably than huge ones).
5. **Mix shapes within domain.** A "core flow" phase can include the API endpoint AND the frontend page AND the scheduled job that processes the result — all together, since they're one logical user-facing capability.

## Phase 3 — Retrieve (read the right context)

For each feature in the ledger:
- Read 1-2 V1 source files for the feature — understand what it does + what it depends on.
- Read existing V2 file (if any) — understand current state + structure.
- Cross-reference `ai/patterns/v1-patterns-crossref.md` if it exists — known V1↔V2 mappings.

This is heavy work; fan out via Explore subagents capped per `--max-subagents`.

## Phase 4 — Generate (produce the output)

Write `ai/migration/plan.md` following this exact structure. **Each MUST-section is a halt condition checked by `validate-migration-artifacts.sh § check_plan_completeness`**:

```markdown
# Migration plan — V1 → V2

Generated: <YYYY-MM-DD>
Scan source: ai/migration/scan-report.md (rev <commit>)
Ledger source: ai/migration/ledger.md (revision pinned)

## V2 structure summary (non-negotiable target)

> The migration follows V2's NEW structure — never V1's lift-and-shift. Cite specifics so each phase knows what "follow new structure" means.

- Routing: <V2's route shape>
- Module layout: <V2's module boundaries>
- Data layer: <V2's ORM / repository pattern>
- Auth: <V2's auth library>
- Conventions: <V2's naming + structure rules from ai/conventions.md>

## Cross-cutting audit dimensions (MUST appear before Phase 1)

> Every per-row audit in every phase MUST verify these dimensions in addition to the per-axis enumeration. Stack-conditional — populate from `_extracted-idioms.md`.

- **Tenant-isolation gate** (multi-tenant projects): every query scopes by `tenant_id` (or project equivalent); cross-tenant read = security incident; AsyncLocalStorage / RequestContext token preserved across async boundaries.
- **Cache-key namespacing** (when Redis / cache primitive present): every cache key includes tenant scope or explicit "global" justification; TTLs match V1; invalidation paths match V1.
- **Translation parity** (multi-locale projects): for every translatable entity, all V1 locales (e.g., `en`, `ar`, `fr`) port together; `resolveOwnTranslation` / equivalent applied consistently; locale-filtered joins in list queries.
- **Naming-boundary integrity**: snake_case ↔ camelCase boundary at HTTP/DTO layer (or stack-equivalent); no leakage of V1's case style into V2's domain types.
- **Audit / soft-delete columns**: every entity preserves V1's audit fields (`created_at`, `updated_by`, `deleted_at`, etc.); base classes match per `_extracted-idioms.md`.
- **Concurrency primitive parity**: V1's bounded-concurrency choice (e.g., `p-limit`, `Semaphore`, `errgroup`) preserved in V2; sequential→parallel changes ship as documented perf-uplift only, not silent.
- **Error envelope shape**: V1's exception → response mapping preserved (e.g., `DomainException` → `{ code, message, translationKey }`); no exception class drift mid-port.

> Stack-specific: per-stack packs add their own dimensions (frontend → focus-state, contrast, motion-reduce, layout-shift; backend → idempotency-key, rate-limit headers, OpenAPI parity, log-field naming).

## Heavy-tier promoter rollup (MUST appear before Phase 1)

> Per `migration-discipline.md § Tier classification`, the following rows are PRE-FLAGGED `tier: heavy` so the reviewer-approval flow engages at audit time. Heavy-tier triggers (any one promotes): P0 finding, cross-repo blocker, contract break, write-path mutation, security-sensitive surface, multi-tenant blast radius. Pre-flagging at plan time prevents the "all-trivial-by-default" bias that lets auth/payment/order rows close as trivial.

| Row | Heavy trigger | Reason |
|---|---|---|
| F<NNN> auth-login | security + write-path | login mutation + JWT issuance |
| F<NNN> tenant-auth | security + multi-tenant | tenant-scope leak risk |
| F<NNN> payment-method | PCI surface | card data + idempotency |
| F<NNN> order | write-path + revenue | order-create mutation |
| F<NNN> cart | write-path + revenue | cart pipeline + cross-row consistency |
| F<NNN> subscription | cron + write-path | billing cron + subscription state |
| F<NNN> financial-transaction | write-path + audit | money mutation |
| F<NNN> saved-card | PCI surface | tokenized card storage |
| F<NNN> security primitives | foundation + security | guards / DDoS / rate-limit |
| F<NNN> s2s | external-auth | server-to-server credentials |
| ... | | |

> Audit MUST set `tier: heavy` on every row in this rollup. Trivial-tier closure on these rows = audit halt + tier-promotion required.

## Phase 1 — Foundation
**Goal**: every feature in later phases depends on these. Land first; nothing else can audit-pass until they're done.

### Features in this phase
| ID | Feature | V1 path | V2 path | Shape | Effort |
|---|---|---|---|---|---|
| F001 | auth-login | <v1/path> | <v2/path> | api+frontend | 3d |
| F002 | tenant-resolver | <v1/path> | <v2/path> | api | 2d |
| ... | | | | | |

### Phase exit criteria
- Every feature: status=done in ledger.
- Every feature: parity_test=passing.
- ADR exists for any intentional behavior change.

## Phase 2 — <domain>
(same shape)

## Phase 3 — <domain>
(same shape)

...

## Phase K — Cleanup + V1 retirement
**Goal**: V1 has zero traffic; archived; no remaining feature dependencies.

### Steps
- Feature-flag flip per route group (if cutover mechanism = feature-flag).
- V1 read-only window (announce + monitor).
- V1 traffic → 0%.
- V1 archive (separate repo / branch / cold storage).

### Phase exit criteria
- V1 receives 0 production traffic for 7 consecutive days.
- All ports verified in `/migration-final`.

## Total features: <N> across <K> phases
## Estimated phases per week: <X> (based on team capacity from ai/status.md)
```

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/migration/plan.md` — managed-block; re-runnable.
- `ai/migration/ledger.md` — add `phase: <N>` field to each row (managed-block update).
- `ai/index.md` — append-once entry pointing to the plan.

## Phase 6 — Validate (verify correctness)

- Every ledger row is assigned a phase (no orphans).
- Foundation phase has no incoming dependencies from later phases.
- **Foundation phase 1 includes core primitives** — error-envelope base class, tenant context primitive, cache primitive, audit/soft-delete base, concurrency primitive, locale primitive (per `_extracted-idioms.md § Detected base classes`). A foundation phase that doesn't ship these makes auth/security audits in Phase 1 un-verifiable.
- **Heavy-tier promoter rollup is present + complete** — every row matching a heavy trigger (auth, payment, order, cart, subscription, financial-transaction, saved-card, security primitives, s2s, cron-write-path, multi-tenant blast radius) appears in the rollup with reason cited. Missing rows = audit halt at execution time.
- **Cross-cutting audit dimensions section is present** before Phase 1.
- **`## Actionable next steps` section is present at the end** per `templates/snippets/actionable-next-steps.md` — paste-ready commands routing each gap / heavy-tier row to its receiving command (`/migration-fast N --audit-only`, `/migration-promote-tier`, `/migration-park`, etc.).
- No phase exceeds `--max-features-per-phase`.
- Phase exit criteria are measurable (status + parity-test, not vague language).
- ADR-references resolve (every cited ADR exists in `ai/decisions/`).

`scripts/validate-migration-artifacts.sh § check_plan_completeness` enforces these mechanically.

If any check fails → halt + report.

## Phase 7 — Improve (feed the learning loop)

- If the dependency graph surfaced a circular dependency between V1 features → that's a pre-existing V1 architectural issue; flag for ADR before porting (don't blindly carry the cycle into V2).
- If a "shape" recurs across many features (e.g., "every order endpoint also publishes a domain event") → propose a pattern in `ai/patterns/`.
- If structural deltas suggest the V2 architecture itself needs adjustment before porting → halt and surface to user with proposed ADR.

## Output to user

```
Migration plan written:
  ai/migration/plan.md

Phases: <K>
Total features: <N>
Foundation phase: <X> features
Largest phase: <Y> features

Next: /migration-phase 1   (audits + ports + verifies phase 1 features)
```

## Mechanical halt — refuse to invent features or fabricate paths

Every plan row MUST trace to a ledger row by `id`. Forbidden: adding a feature to the plan that isn't in the ledger; citing a `v1_path` not present in the ledger row; citing a `v2_path` that doesn't exist AND isn't covered by `ai/architecture.md` as a planned module. If a plan-time discovery surfaces a missing V1 feature → halt; the user runs `/migration-scan` to re-inventory. Do NOT silently extend the ledger from this command.

## Hard rules

- **No phase ships features that aren't in the ledger.** The ledger is the source of truth; the plan reads from it, never invents features.
- **Every phase has measurable exit criteria.** Not "phase complete when most things work."
- **V2 structure is the target, not V1's.** Plan rows cite V2 paths even when the V2 file doesn't exist yet — that's the planned home.
- **Foundation first.** Auth + tenant + shared infra always go first. Refuse a plan that puts them later.
- **No partial porting in one phase.** A feature is either fully ported (verify-green) or not in this phase. Half-ports rot.
- **Dead V1 features are NOT in any phase.** Rows with `status: deprecated` and `deprecation_reason: dead-v1-no-callers` are excluded from the port queue (per `migration-discipline.md § What counts as dead V1 code`). They get deleted from V1 directly during the V1-retirement phase, never ported. The plan lists them in a "Dead — excluded from port queue" section for visibility, NOT as phase rows.

## Related

- `/migration-scan` — runs before this command; produces the inputs.
- `/migration-phase <N>` — next command; executes phase N from this plan.
- `/migration-replan` — regenerate this plan when it ages out (rollbacks / V1 changes / phase reordering).
- `ai/patterns/feature-port.md` — per-feature lifecycle each phase implements.
- `ai/architecture.md` — V2 module boundaries this plan honors.
