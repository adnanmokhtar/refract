# MongoDB reference

## Design

- Design for query shape, not normalization.
- Embed when data is fetched together and bounded in size (< 16MB doc limit).
- Reference when:
  - The related entity is large
  - Many documents need the same related entity (normalize to avoid duplication)
  - Independent lifecycle / access patterns

## Indexes

- Index on every query field. Compound indexes for multi-field queries.
- Leftmost-prefix rule: `{ a: 1, b: 1 }` serves queries on `a`, and on `a + b`, but NOT on `b` alone.
- Unique indexes enforce uniqueness.
- TTL indexes for auto-expiring docs (sessions, caches).

## Schemas

- Mongoose / Prisma / manual — pick one.
- Validate at the driver level with `$jsonSchema` validators on collections.
- Version your schema (`schemaVersion` field) when you evolve.

## Transactions

- Multi-document transactions supported on replica sets.
- Keep transactions short — long transactions hold locks and fail under write conflicts.
- Use `causal consistency` sessions for read-after-write guarantees across replicas.

## Queries

- Avoid `$where` — server-side JS, slow and dangerous.
- Use `$lookup` sparingly — joins in Mongo are expensive. Denormalize when hot.
- Projections (`{ field: 1 }`) reduce network cost.
- `countDocuments()` > `estimatedDocumentCount()` when accuracy matters.

## Aggregation

- `$match` first, `$project` early, `$group` late — order matters for performance.
- Pipelines use indexes only on the initial `$match`.

## Anti-patterns

- Unbounded array growth (chat history in a single doc) — split into sub-collection
- Deep nesting beyond 3 levels
- Using Mongo as a relational DB with `$lookup` everywhere
- No indexes (dev speed → prod pain)
