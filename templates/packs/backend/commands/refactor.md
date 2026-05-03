---
description: Backend-targeted refactor — preserves API contracts, error envelopes, DI, and layer boundaries. Behaviour-preserving only; uses refactoring-sweep verbs.
---

# /refactor [<scope>]

## Pack overlay — backend

**Canonical orchestration:** [`commands/refactor.md`](../../../../commands/refactor.md).

### Backend-specific gates

- **Layering** — controllers stay thin; no new business logic in routes; data access stays in repositories / ORM layer per siblings.
- **Error envelope** — HTTP status + body shape unchanged unless explicitly approved as breaking (then not a pure refactor).
- **Validation / DTOs** — renaming internal helpers OK; public request/response schemas unchanged.
- **DI** — new constructor params must match sibling services (mirror existing injection style).

### Dispatch

Follow [`commands/refactor.md`](../../../../commands/refactor.md); apply [`templates/packs/code-quality/skills/refactoring-sweep.md`](../../code-quality/skills/refactoring-sweep.md); consult this pack's `STACK.md` and `.claude/_extracted-idioms.md` for oracle shapes.

### When NOT

Cross-cutting architectural extraction across services → `/optimize`. Database query perf → `/optimize` or `/optimize-query`.
