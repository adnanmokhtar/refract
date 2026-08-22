---
name: schema-consistency-audit
description: Schema + migration consistency audit. Detects drift in nullability, type choice, timezone handling, charset/collation, timestamp and audit-field coverage, soft-delete coverage, migration patterns, and object naming. Findings are ranked by data-integrity risk, not by detector order. Emits closure verbs that ship as reversible migrations. Used by /polish on data-* stacks and /db-audit.
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
subclass: <one of: nullable-drift | type-drift | timezone-drift | charset-drift |
                   collation-drift | soft-delete-drift | audit-field-drift |
                   timestamp-column-drift | column-naming-drift |
                   migration-pattern-drift | object-naming-drift>
table: <table-name>
column: <column-name OR null for table-level findings>
file: <migration-path:line OR schema-file:line>
canonical: <what the project's convention says>
divergence: <what this column/table does differently>
closure_verb: <one of the verbs below>
migration_strategy: rename-in-place | expand-contract | rename-with-dual-read | meta
risk: low | medium | high
integrity_class: <one of: corrupts-data | loses-precision | breaks-queries | cosmetic>
```

## The 11 detectors

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

### 3. object-naming-drift (indexes and foreign-key constraints)

**Fingerprint**: index or FK-constraint names follow different patterns across the schema — `idx_orders_status` / `ix_orders_status` / `orders_status_idx` / `orders_idx_status`, and the equivalent spread on constraint names.

**Closure verb**: `unify-object-naming`.

**Migration strategy**: `rename-in-place` — **use the engine's rename, never drop + recreate.** Postgres: `ALTER INDEX <old> RENAME TO <new>` / `ALTER TABLE <t> RENAME CONSTRAINT <old> TO <new>`. MySQL 5.7+: `ALTER TABLE <t> RENAME INDEX <old> TO <new>, ALGORITHM=INPLACE` — the operation is In Place, permits concurrent DML, and only modifies metadata ([MySQL Table 17.16](https://dev.mysql.com/doc/refman/8.4/en/innodb-online-ddl-operations.html)). Dropping and recreating an index on a populated table is a full index build for a **cosmetic** gain — exactly the trade the rest of this pack forbids. If the engine cannot rename the object, the finding's risk becomes `medium` and it is deferred, not forced through.

**Risk**: `low` — and its rank reflects that. A naming inconsistency costs a reader five seconds; it never corrupts data. It is ordered after every integrity finding, and a run that reports only naming drift is a clean run with a note, not a finding list.

### 4. migration-pattern-drift

**Fingerprint**: migration files don't follow the project's pattern. Common drifts:
- Some have `down()` / rollback, others don't.
- Some are reversible, others irreversible without comment explaining why.
- Some run as transactions, others don't (where the project's convention says they should).
- Some include data migrations inline, others separate.

**Detection**: walk migrations directory; check each against the project's template (in `_extracted-idioms.md § Migration template`).

**Closure verb**: `unify-migration-pattern` — for forward-only fixes, refactor the migration before merge. For already-merged migrations, document the deviation in a follow-up migration's header.

**Migration strategy**: meta — fixes the structure of future migrations, not data.

### 5. timestamp-column-drift

**Fingerprint**: timestamp columns named inconsistently.

Common drifts:
- `created_at` vs `createdAt` vs `created` vs `creation_time` vs `inserted_at`
- `updated_at` vs `last_modified` vs `modified_at`

**Closure verb**: `unify-timestamp-cols`.

**Migration strategy**: `rename-with-dual-read`.

### 6. soft-delete-drift

**Fingerprint**: some tables have `deleted_at` (soft delete), others don't, where the project's convention requires soft delete.

**Detection**: cross-check tables-without-`deleted_at` against `_extracted-idioms.md § Soft-delete tables`.

**Closure verb**: `add-soft-delete` — adds `deleted_at TIMESTAMPTZ NULL`, updates queries to filter `deleted_at IS NULL` by default, updates ORM models.

**Migration strategy**: `expand-contract` (column add → query updates → enforcement).

### 7. audit-field-drift

**Fingerprint**: some tables have `created_by` / `updated_by` / `created_at` / `updated_at`, others don't, where the project's convention requires them.

**Closure verb**: `add-audit-fields`.

**Migration strategy**: `expand-contract`.

### 8. timezone-drift

**Fingerprint**: timestamp columns mix `TIMESTAMP` (timezone-naive) and `TIMESTAMPTZ` (timezone-aware) within the same conceptual schema.

**Closure verb**: `unify-timezone` — typically converges to `TIMESTAMPTZ` per modern best practice.

**Migration strategy**: `expand-contract` for prod tables (the conversion can change reads if the timezone differs).

### 9. charset-drift

**Fingerprint**: tables use different charsets (e.g., MySQL `utf8` vs `utf8mb4` for the same concept).

**Closure verb**: `unify-charset`.

**Migration strategy**: depends on the DB — some support online conversion, others require expand-contract.

### 10. collation-drift

**Fingerprint**: tables use different collations affecting ordering / comparison.

**Closure verb**: `unify-collation`.

**Migration strategy**: same as charset.

### 11. nullable-drift

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
4. **Run the 11 detectors**; emit findings. Detector order is not report order — see step 6.
5. **For each finding**:
   - Cite `<file:line>` evidence.
   - Pick `migration_strategy` per the verb's table above.
   - Estimate `risk` — the cost of *making the change*:
     - `low`: in-place object renames, audit-field additions, metadata-only changes.
     - `medium`: column renames (require a dual-read window), nullable tightening (requires a backfill).
     - `high`: type conversion (data-loss potential), charset/collation change on a populated table.
   - Assign `integrity_class` — the cost of *leaving it alone*, which is a different axis and the one that ranks the report:
     - `corrupts-data`: the drift can silently produce wrong stored values — mixed timezone-naive/aware timestamps, a money column stored as float in one table and decimal in another, `utf8` vs `utf8mb4` truncating on 4-byte characters.
     - `loses-precision`: values survive but detail does not — a narrower type, a lower-precision timestamp.
     - `breaks-queries`: comparisons or ordering behave differently across tables — collation drift, nullability that makes a `NOT IN` silently return nothing.
     - `cosmetic`: a reader is inconvenienced. Naming drift is always this.
6. **Write `ai/polish/_schema-decisions.md`** — findings **ranked by `integrity_class` first** (`corrupts-data` → `loses-precision` → `breaks-queries` → `cosmetic`), then grouped by table, then ordered foundation-first within a table (audit fields before nullability tightening; column rename before type change on the same column). Detector index carries no weight: a charset drift that truncates emoji outranks every naming finding in the report, and a report that lists them at the same level has mis-sorted the reader's afternoon.

## Hard rules

- **Reversible migrations only** — every closure verb produces a migration with a documented `down()` / rollback. Irreversible changes require ADR.
- **No blind renames in production** — column / table renames go through a dual-read window: add new, dual-write, dual-read, drop old. Multi-PR.
- **Never drop-and-recreate an object that the engine can rename.** Indexes and constraints have in-place rename syntax on both major engines; a rebuild for a naming fix is unjustifiable cost.
- **Cosmetic findings never outrank integrity findings**, whatever order the detectors ran in.
- **Type changes via expand-contract** — add new column, backfill, switch reads, switch writes, drop old. NEVER `ALTER COLUMN TYPE` directly on prod tables with significant data.
- **One conceptual change per migration** — bundling rename + type change + nullable change in one migration makes rollback ambiguous.
- **Migration tested in staging** — every closure verb's migration runs in staging before prod; staging dataset must reflect prod scale (≥ 10% sample).
- **No detector invents conventions** — canonical comes from `_extracted-idioms.md § Schema conventions`.

## Failure modes

- **Conventions missing** → halt; surface "/setup-project --refine to declare schema conventions first".
- **Cannot introspect** → halt; user provides DB access OR migration-history dump.
- **High-risk closure** (type conversion with data-loss potential) → flag, halt that finding, surface ADR template; rest continue.
- **Engine cannot rename the object in place** → the naming finding is deferred, not converted into a drop + recreate.
- **Migration framework not detected** → halt; tool-specific (Prisma / Knex / Flyway / Alembic / Django / etc.) format must be discoverable.

## References

- `_extracted-idioms.md § Schema conventions`.
- `migration-rehearsal.md` (this pack) — every `expand-contract` or high-risk closure verb's migration goes through rehearsal. In-place renames do not need one.
- `align-discipline.md` — closed-vocabulary discipline.
- `polish` command — dispatches this skill on data stacks.
