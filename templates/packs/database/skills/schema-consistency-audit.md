---
description: Schema + migration consistency audit. Detects drift in column naming, type choice, index naming, foreign-key naming, migration patterns, timestamp column conventions, soft-delete coverage, audit field coverage, timezone handling, charset/collation, nullability. Emits findings with closure verbs that ship as reversible migrations. Used by /polish on data-* stacks. Behaviour-preserving (renames via dual-read window; type changes via expand-then-contract pattern).
kind: skill
pack: database
---

# Skill: schema-consistency-audit

## Purpose

Detect drift across the project's database schema + migration history so /polish can unify it. The skill operates on the live schema (introspection) + migration history + the project's conventions (`_extracted-idioms.md § Schema conventions` or `ai/schema-conventions.md`).

## When to use

- Dispatched by `/polish` on `data-*` stacks (or `backend-*` stacks with significant schema scope).
- Dispatched by `/db-audit` for read-only audit.
- Standalone: `/polish --diagnose-only --stack=data` writes the artifact, no fixes.
- NOT for adding new tables (use `/add-migration`) or query optimisation (use `/optimize-query`).

## Inputs (precise contract)

| Input | Source | Required |
|---|---|---|
| Codebase root | Orchestrator | YES |
| `PROJECT_KIND` | `_extracted-codebase.md § Gold standards` | YES (`data-*` or `backend-*` with schema scope) |
| Schema conventions | `_extracted-idioms.md § Schema conventions` OR `ai/schema-conventions.md` | YES (without it, drift is undefined — halt) |
| Schema introspection access | DB connection OR migration history dump | YES (one of the two) |
| Scope filter (optional) | Caller flag (e.g., `--scope=analytics`) | NO (default: all tables) |

## Outputs (precise contract)

```yaml
class: schema-consistency
subclass: <one of: column-naming-drift | type-drift | index-naming-drift |
                   fk-naming-drift | migration-pattern-drift |
                   timestamp-column-drift | soft-delete-drift |
                   audit-field-drift | timezone-drift | charset-drift |
                   collation-drift | nullable-drift>
table: <table-name>
column: <column-name OR null for table-level findings>
file: <migration-path:line OR schema-file:line>
canonical: <what the project's convention says>
divergence: <what this column/table does differently>
closure_verb: <one of the verbs below>
migration_strategy: simple | expand-contract | rename-with-dual-read
risk: low | medium | high
```

## The 12 detectors

### 1. column-naming-drift

**Fingerprint**: column names mix case styles within the same database (e.g., `created_at` and `createdAt` and `CreatedAt` for the same conceptual field across tables).

**Detection**: introspect every column; classify case style; flag tables/columns deviating from the project's canonical (declared in conventions).

**Closure verb**: `unify-column-naming`.

**Migration strategy**: `rename-with-dual-read` — add new column, backfill, dual-read in code, drop old column in next migration. NEVER blind rename in production.

### 2. type-drift

**Fingerprint**: same conceptual field uses different types across tables.

Common drifts:
- `email` is `VARCHAR(255)` in some tables, `TEXT` in others.
- `description` is `TEXT` in some, `VARCHAR(2000)` in others.
- Money: `DECIMAL(10,2)` in some, `BIGINT` (storing cents) in others.
- IDs: `BIGINT` in some, `UUID` in others, `VARCHAR(36)` in others.

**Closure verb**: `unify-type-choice`.

**Migration strategy**: `expand-contract` (add new column with right type; backfill; switch reads; switch writes; drop old column).

### 3. index-naming-drift

**Fingerprint**: index names follow different patterns:
- `idx_orders_status`
- `ix_orders_status`
- `orders_status_idx`
- `orders_idx_status`

**Closure verb**: `unify-index-naming`.

**Migration strategy**: `simple` — drop + recreate (most DBs support `ALTER INDEX RENAME` natively, no downtime).

### 4. fk-naming-drift

**Fingerprint**: foreign-key constraint names follow different patterns.

**Closure verb**: `unify-fk-naming`.

**Migration strategy**: `simple`.

### 5. migration-pattern-drift

**Fingerprint**: migration files don't follow the project's pattern. Common drifts:
- Some have `down()` / rollback, others don't.
- Some are reversible, others irreversible without comment explaining why.
- Some run as transactions, others don't (where the project's convention says they should).
- Some include data migrations inline, others separate.

**Detection**: walk migrations directory; check each against the project's template (in `_extracted-idioms.md § Migration template`).

**Closure verb**: `unify-migration-pattern` — for forward-only fixes, refactor the migration before merge. For already-merged migrations, document the deviation in a follow-up migration's header.

**Migration strategy**: meta — fixes the structure of future migrations, not data.

### 6. timestamp-column-drift

**Fingerprint**: timestamp columns named inconsistently.

Common drifts:
- `created_at` vs `createdAt` vs `created` vs `creation_time` vs `inserted_at`
- `updated_at` vs `last_modified` vs `modified_at`

**Closure verb**: `unify-timestamp-cols`.

**Migration strategy**: `rename-with-dual-read`.

### 7. soft-delete-drift

**Fingerprint**: some tables have `deleted_at` (soft delete), others don't, where the project's convention requires soft delete.

**Detection**: cross-check tables-without-`deleted_at` against `_extracted-idioms.md § Soft-delete tables`.

**Closure verb**: `add-soft-delete` — adds `deleted_at TIMESTAMPTZ NULL`, updates queries to filter `deleted_at IS NULL` by default, updates ORM models.

**Migration strategy**: `expand-contract` (column add → query updates → enforcement).

### 8. audit-field-drift

**Fingerprint**: some tables have `created_by` / `updated_by` / `created_at` / `updated_at`, others don't, where the project's convention requires them.

**Closure verb**: `add-audit-fields`.

**Migration strategy**: `expand-contract`.

### 9. timezone-drift

**Fingerprint**: timestamp columns mix `TIMESTAMP` (timezone-naive) and `TIMESTAMPTZ` (timezone-aware) within the same conceptual schema.

**Closure verb**: `unify-timezone` — typically converges to `TIMESTAMPTZ` per modern best practice.

**Migration strategy**: `expand-contract` for prod tables (the conversion can change reads if the timezone differs).

### 10. charset-drift

**Fingerprint**: tables use different charsets (e.g., MySQL `utf8` vs `utf8mb4` for the same concept).

**Closure verb**: `unify-charset`.

**Migration strategy**: depends on the DB — some support online conversion, others require expand-contract.

### 11. collation-drift

**Fingerprint**: tables use different collations affecting ordering / comparison.

**Closure verb**: `unify-collation`.

**Migration strategy**: same as charset.

### 12. nullable-drift

**Fingerprint**: same conceptual field is nullable in some tables, NOT NULL in others, without documented reason.

**Closure verb**: `unify-nullable` — converges to whichever the project's convention requires (usually NOT NULL with default for stable fields).

**Migration strategy**: `expand-contract` (add default → backfill nulls → set NOT NULL).

## Procedure

1. **Pre-flight**:
   - `PROJECT_KIND` is `data-*` OR `backend-*` with schema scope. Halt otherwise.
   - `_extracted-idioms.md § Schema conventions` OR `ai/schema-conventions.md` exists. Halt if missing.
   - DB introspection access OR migration-history readable. Halt if neither.
2. **Introspect schema** — get tables, columns, types, indexes, FKs, constraints. Emit `_schema-snapshot.md`.
3. **Walk migration history** — emit `_migration-summary.md` listing files + patterns + reversibility.
4. **Run 12 detectors** in order; emit findings.
5. **For each finding**:
   - Cite `<file:line>` evidence.
   - Pick `migration_strategy` per the verb's table above.
   - Estimate risk:
     - `low`: index renames, audit-field additions, simple metadata.
     - `medium`: column renames (require dual-read), nullable changes (require backfill).
     - `high`: type drift conversion (data loss risk), charset/collation changes on prod tables.
6. **Write `ai/polish/_schema-decisions.md`** — findings grouped by table; ordered foundation-first (audit fields before nullability tightening; column rename before type change on the same column).

## Hard rules

- **Reversible migrations only** — every closure verb produces a migration with a documented `down()` / rollback. Irreversible changes require ADR.
- **No blind renames in production** — column / table renames go through dual-read window: add new, dual-write, dual-read, drop old. Multi-PR.
- **Type changes via expand-contract** — add new column, backfill, switch reads, switch writes, drop old. NEVER `ALTER COLUMN TYPE` directly on prod tables with significant data.
- **One conceptual change per migration** — bundling rename + type change + nullable change in one migration makes rollback ambiguous.
- **Migration tested in staging** — every closure verb's migration runs in staging before prod; staging dataset must reflect prod scale (≥ 10% sample).
- **No detector invents conventions** — canonical comes from `_extracted-idioms.md § Schema conventions`.

## Failure modes

- **Conventions missing** → halt; surface "/setup-project --refine to declare schema conventions first".
- **Cannot introspect** → halt; user provides DB access OR migration-history dump.
- **High-risk closure** (type conversion with data-loss potential) → flag, halt that finding, surface ADR template; rest continue.
- **Migration framework not detected** → halt; tool-specific (Prisma / Knex / Flyway / Alembic / Django / etc.) format must be discoverable.

## References

- `_extracted-idioms.md § Schema conventions`.
- `migration-rehearsal.md` (this pack) — every closure verb's migration goes through rehearsal.
- `align-discipline.md` — closed-vocabulary discipline.
- `polish` command — dispatches this skill on data stacks.
