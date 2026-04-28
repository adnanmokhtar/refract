# ai/patterns/

Worked examples of HOW to do things in this codebase. The "if you're writing X, follow Y" reference.

## What goes here

Each file is a single pattern: name, problem, structure, code example, trade-offs, common mistakes, testing.

Common patterns (populated by `/setup-project` based on detected stack + signals):

- `project-structure.md` — folder layout, layer boundaries.
- `data-access.md` — repository pattern, base class, criteria system.
- `error-handling.md` — typed domain errors → HTTP mapping.
- `caching-strategy.md` — when, where, TTL, invalidation, stampede protection.
- `multi-tenancy.md` — request context propagation, tenant filtering, cache key scoping.
- `webhook-flow.md` — signature verification, idempotency, retry, DLQ.
- `prompt-builder.md` — for AI-using projects.
- `ai-cost-tracking.md` — token + cost accounting.
- `api-contract.md` — DTO + validation + OpenAPI sync.
- `test-strategy.md` — unit vs integration vs e2e split.
- `migrations.md` — schema changes on populated tables, zero-downtime.
- `idempotency.md` — safe retries.
- `feature-flags.md` — flag lifecycle.
- `auth-flow.md` — JWT + refresh rotation.
- `i18n.md` — key conventions, ICU messages, RTL.

## Distinction

- `core/` — what (entities, invariants).
- `patterns/` — how (concrete structure with code).
- `decisions/` — why (with alternatives considered).
- `runbooks/` — when (step-by-step for triggered events).

## Format per pattern

See `_template.md` in this folder — copy it for any new pattern.

## Empty?

`repo-baseline` ships only `_template.md` here. **Concrete pattern files** (e.g. `project-structure.md`) are **authored or copied at `/setup-project` run time** from pack `ai-patterns/` or Phase 4.2-AUTHOR — they are not all present as static seeds in the template tree. If this folder only has `_template.md`, the next setup/enhance run should populate it for the detected stack.
