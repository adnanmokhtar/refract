# Pattern: System Design Document

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

ASCII diagram. Box per service. Arrows for sync/async. Labels for protocols.

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
