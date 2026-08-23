---
name: system-design
description: "Pattern: System Design Document"
kind: ai-pattern
pack: documentation
---

# Pattern: System Design Document

> **Hard rule** — System designs ship BEFORE coding starts, include numbered testable goals, a failure-modes table, and an alternatives-considered section. Skipping any of those three sections is forbidden.

**When to apply**
- Feature spans more than one service or crosses a major architecture boundary.
- Decision is hard to reverse (data model, async vs sync boundary, consistency model).
- Multiple engineers / squads will implement against the same design.

**When NOT to apply**
- Single-service refactor that doesn't change external contracts.
- Bug fix or small enhancement contained to one module.
- Throwaway prototype with explicit "won't ship" labelling.

**Halt conditions / mandatory cites**
- Cite the load-projection source as `<path:line>` (current dashboard, capacity model file); "handles N req/s" without a citation is a halt.
- Cite the failing baseline or incident that forced the design as `<path>` of postmortem or ticket; designs without a triggering signal drift into speculation.
- Cite at least 2 rejected alternatives with concrete reject reasons; single-option designs are halted.
- Cite the ADR(s) that record the strategic choices made inside the design (`ai/decisions/NNNN-*.md`); design + ADR are paired artifacts.
- Hand-wave grep ban — never claim "current architecture supports this" without citing the relevant module/service files by path.

For features / systems beyond a single service. Written BEFORE coding.

## Structure

```markdown
# <System name> — System Design

Status: Draft | Under review | Accepted | Superseded
Author: <name> / <team>
Date: YYYY-MM-DD

## Context

Why we're designing this NOW. Business driver. What triggered it.

## Goals

Numbered, testable.
1. Handle N req/s at p95 < 250ms.
2. Tolerate single-region outage with < 15min RTO.
3. Support M tenants without cross-tenant leakage.

## Non-goals

What we're explicitly NOT doing.
- Real-time chat (Phase 5, not now).
- Multi-currency support (Phase 2).

## High-level architecture

A **generated** diagram, not a hand-drawn one. Run `diagram-sync` (this pack) — it renders the real
module/import graph as mermaid or C4 and drift-checks the committed picture against it. A hand-drawn
box diagram is worse than none: it teaches a wrong mental model with the authority of a picture, and
nothing detects it going stale. If the design predates the code (no graph exists yet), draw the
INTENDED shape and label it `Status: intended — not yet verified against a dependency graph`, then
re-render from the graph once the code lands.

## Data model

Tables / collections with key fields + relationships.
Data ownership: which service owns writes to what.

## API surface

Per endpoint: method, path, request, response, auth, errors.

## Key flows

Sequence diagrams for the 2-3 most important user journeys.

## Consistency model

Per entity:
- Strong consistency within: <scope>
- Eventual consistency across: <scope>, max lag: <time>
- Conflict resolution: <strategy>

## Scalability

Current load + projected (6m, 2y). Bottlenecks + mitigations.

## Failure modes

Per external dependency / cross-service call:
| Failure | Probability | Impact | Mitigation |

## Security

- AuthN / AuthZ model.
- Data encryption (at rest + in transit).
- Tenant isolation.
- Audit logging.
- Compliance: GDPR / HIPAA / PCI as relevant.

## Observability

- Logs: what's emitted, structure, retention.
- Metrics: RED + business KPIs.
- Traces: key spans.
- Alerts + SLOs.

## Operational concerns

- Deployment model.
- Rollback path.
- Backup + restore for stateful components.
- Runbooks for common incidents.

## Open questions

Things not yet decided. Each with an owner + deadline.

## Alternatives considered

What else we looked at + why rejected.

## Rollout plan

Phased. What ships first, what waits, what's feature-flagged.

## Success metrics

How we know this worked. Tied to goals.
```

## Rules

- Ground every number in evidence (current load, benchmarks). Back-of-envelope > guessed.
- Failure modes section is NOT optional.
- Alternatives considered is NOT optional (forces articulation of why).
- Keep it terse — 3 pages beats 30.
- Review BEFORE coding. Feedback is cheaper here than after implementation.
