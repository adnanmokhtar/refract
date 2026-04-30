---
description: Produce a system design — service boundaries, data ownership, consistency, failure modes, ADRs.
---

# /design-system <feature>

Design-before-implementation for features that cross service boundaries, change data ownership, or alter the consistency model.

## Phases applied

All 7. Phase 4 = the design doc + ADRs (no code generation here).

## When to use / NOT to use
- USE: feature spans ≥ 2 services; introduces a new data store or changes existing ownership; changes async/sync communication; touches consistency guarantees.
- NOT: single-service CRUD (`/add-feature` covers that); pure refactor with no boundary change (`/refactor`).

## Phase 1 — Understand

- Collect: feature name, goal, scale (RPS / data volume / growth), SLO targets (p95 latency, availability), constraints (compliance, cost ceiling).
- Consolidated question if any of these missing — design without scale numbers is hand-waving.
- Success: doc names every cross-service call, owners every entity, declares consistency model with reasoning, has rollout phases.

## Phase 2 — Organize

- Sub-tasks: context diagram, data ownership table, communication matrix, failure-mode matrix, consistency model, SLO contract, ADRs, rollout plan.
- Sequence: architect first (the design), then resilience-reviewer (the failure modes), then ADR authoring.
- Pause after architect's draft — user confirms before resilience pass.
- **Scope gate**: If the design has ≤2 services and no cross-region/event-sourcing/saga concerns, run `architect` only and skip `resilience-reviewer` + auto-ADR. Promote to full chain only when the architect flags ≥1 distributed-systems risk (network partition, exactly-once requirement, eventual-consistency window).

## Phase 3 — Retrieve

ALWAYS:
- `CLAUDE.md` — current architecture rules.
- `ai/architecture.md` — current system shape.
- `ai/decisions/` — scan filenames; read ADRs touching affected services.
- `ai/business-domain.md` — entity ownership.
- Service inventory (existing services, their owners, their tech).

SIGNAL-BASED:
| Signal | Read |
|---|---|
| Event-driven | `ai/patterns/event-bus.md`, `ai/patterns/outbox.md` |
| Saga / cross-tx | `ai/patterns/saga.md`, `ai/patterns/idempotency.md` |
| Multi-region | `ai/patterns/replication.md` |

## Phase 4 — Generate

Dispatch `system-architect` with the assembled brief. Architect produces:
- **Context diagram** (ASCII) — services + external systems + the new boundaries.
- **Data ownership table** — every entity + which service owns writes + which read replicas.
- **Communication matrix** — for each cross-service call: sync vs async, transport (HTTP / gRPC / event bus / queue), retry policy, idempotency strategy.
- **Failure-mode matrix** — per cross-service call: what fails, how detected, how mitigated, blast radius.
- **Consistency model** — strong where needed, eventual elsewhere, with reasoning.
- **SLO contract** — composed SLO across new dependencies.

Then dispatch `resilience-reviewer` (timeouts, retries, circuit breakers, bulkheads, fallbacks).

Author 1-3 ADRs capturing non-obvious choices (each one decision).

Phased rollout plan: which service ships first, behind which flag, with what dual-write/dual-read pattern.

## Phase 5 — Update

- `specs/<YYYYMMDD>-<slug>.md` — the design doc.
- `ai/decisions/` — append the ADRs (status: Proposed).
- `ai/architecture.md` — append a forward-reference to the new design.
- `ai/status.md` — Recent Changes entry.

## Phase 6 — Validate

- Self-audit: every cross-service call has timeout + behavior-on-timeout documented.
- Every shared entity has exactly ONE write owner.
- Consistency model matches UI requirements (eventual + UI assumes strong = bug factory).
- Observability called out IN the design (alerts, traces, metrics) — not deferred.

## Phase 7 — Improve

- ADRs queued in `ai/decisions/` move to Accepted only after team review — append review checklist.
- If the design introduced a new pattern (saga shape, outbox layout), queue to `ai/dynamic/learned-patterns.md`.

## Output

```
Saved:
  specs/20260424-bulk-export-pipeline.md      (design + diagrams + matrix)
  ai/decisions/0042-event-bus-not-rest.md     (Proposed)
  ai/decisions/0043-saga-for-cross-service-tx.md  (Proposed)

Rollout phases:
  1. Producer service emits events behind flag (no consumers yet).
  2. Consumer service consumes events behind flag, writes shadow data, compares.
  3. Cut over reads.
  4. Remove old code path.
```

## Failure modes

- "Just use a transaction across services" — distributed transaction; use a saga or rethink ownership.
- Shared DB across services — STOP; write the ADR for ownership before any code.
- Synchronous request chains > 3 deep — fan-out latency cliff; push down or move async.
- Eventual consistency claimed but UI assumes strong reads — bug factory; UI requirement decides the model.
- Cross-service call without documented timeout AND behavior-on-timeout — production fire.
- "We'll add observability later" — engineer paged at 3am with no signal; telemetry is part of the design.

## Related

### Patterns
- `ai/patterns/circuit-breaker.md`
- `ai/patterns/cqrs.md`
- `ai/patterns/event-sourcing.md`
- `ai/patterns/idempotency.md`
- `ai/patterns/outbox.md`
- `ai/patterns/saga.md`

### Rules
- `.claude/rules/distributed-principles.md`
