# Entities

Inventory of all domain entities in this codebase + their relationships. Lives alongside `glossary.md` (vocabulary) — this file focuses on STRUCTURE.

## Entity-relationship view

```
<Entity-A> ──< (1:N) ── <Entity-B>
    │
    └──< (1:N) ── <Entity-C>
```

(Replace with actual ERD as entities are added.)

## Per-entity table

| Entity | Path | Aggregate root? | Children | Indexed by |
|---|---|---|---|---|
| `<EntityName>` | `src/.../entity.ts` | yes | `<ChildA>, <ChildB>` | `id, tenantId, createdAt` |

## Cross-entity invariants

Rules that hold ACROSS entities (not just within one):

- Every entity has `id` + `tenantId` (if multi-tenant).
- Foreign keys never cross tenant boundaries.
- Soft-delete (`deletedAt`) is non-cascading; cascading is opt-in via `onDelete: 'CASCADE'` only with explicit ADR.

## Generated artifacts

- TypeORM entities at `<path>/entities/`.
- Migrations at `<path>/migrations/`.
- ERD diagram (auto-generated): `<command to run>`.

## How to keep this current

- Add a row when a new entity is introduced.
- Update relationships when foreign keys are added/removed.
- Re-run `/refresh-knowledge` after major schema changes.

## See also

- `ai/core/glossary.md` — vocabulary + state machines.
- `ai/core/invariants.md` — rules entities must obey.
- `ai/architecture.md` — module/layer structure.
