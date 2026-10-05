# ADR 0002 — The billing domain is framework-free

Status: accepted (2025-11-04)

## Decision

Pricing, proration and tax rules in `api/src/domain/` import nothing from Nest, Prisma or any I/O
library. Money crosses into the domain as integer minor units; persistence types are mapped at the
application layer.

## Consequences

Domain rules are unit-tested without a database, and the worker can port them without the ORM.
