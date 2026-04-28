# Invariants

System-wide rules that MUST hold. Different from `.claude/rules/` (which are coding conventions): invariants are about CORRECTNESS — violating one is a bug, not a style issue.

## Data integrity

- Every entity belongs to a tenant (if multi-tenant); `tenantId` is non-null + foreign-keyed.
- Soft-deleted records (`deletedAt IS NOT NULL`) are excluded from default queries.
- Money is stored as integer minor units (cents) or `Decimal` — never `Float`.
- Currency is co-stored with money (`{amount, currency}` pair, never `amount` alone).
- Timestamps are UTC at storage; locale conversion is presentation-only.

## Tenant isolation

- No query crosses tenants except explicitly-marked admin endpoints.
- Cache keys include tenant prefix (no exception unless documented in ADR).
- Events emitted include `tenantId` in metadata, never in payload.

## Authentication + authorization

- Every endpoint enforces auth (no accidental public endpoints).
- Tokens never appear in logs.
- Refresh tokens are stored hashed.

## Audit + compliance

- Every state-changing admin action is audit-logged with actor + timestamp.
- PII access is logged for compliance review.
- Sensitive fields (passwords, tokens, card data) never appear in logs / traces / replies.

## Concurrency

- Every endpoint that can be retried supports `Idempotency-Key` semantics.
- Mutations on the same aggregate use optimistic-lock OR row-lock (never read-then-write without protection).
- Webhook handlers are idempotent (same `event.id` processed twice = no double-effect).

## Observability

- Every request has a correlation id (`reqId` / `traceId`) propagated to logs + downstream calls.
- Errors surface to operators via the documented alerting path; nothing is silently swallowed.

## How to keep this current

- Add an invariant when an incident reveals a missed assumption.
- Cross-reference to the ADR that established each invariant.
- When code violates an invariant, that's a P0 bug — file it; don't downgrade the rule.

## See also

- `ai/decisions/` — ADRs that established each invariant.
- `.claude/rules/` — coding conventions (style level).
- `ai/runtime/context.md` — project-specific gotchas.
