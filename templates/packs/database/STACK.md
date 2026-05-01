# Database pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A relational engine** OR a **document store** (Postgres / MySQL-MariaDB / SQLite / MongoDB — engine-specific guidance lives in `references/<engine>.md`)
- **Migrations as code**, reversible where feasible (Flyway / Liquibase / Alembic / Knex / Prisma Migrate / Rails / Django / TypeORM / Atlas)
- **A connection pooler** in production (`pgbouncer` / `proxysql` / driver pool)
- **A migration linter** (`squawk` / `pgsanity` / `sqlfluff` / `migra`)
- **A query profiler** (`pg_stat_statements` / Performance Schema / slow-query log)
- **An ORM or query builder** chosen explicitly per stack (TypeORM / Prisma / SQLAlchemy / Hibernate / GORM / ActiveRecord / Eloquent)

## Engine variants

The database principles rule is engine-agnostic. Engine-specific syntax + safe-migration rules live in:

- `references/postgres.md` — Postgres 14+ (`CONCURRENTLY`, `pg_stat_statements`, `EXPLAIN (ANALYZE, BUFFERS)`, partial indexes, `jsonb`, `citext`).
- `references/mysql.md` — MySQL 8 / MariaDB (`pt-online-schema-change`, `gh-ost`, `EXPLAIN ANALYZE` / `EXPLAIN FORMAT=TREE`, InnoDB tuning).
- `references/mongodb.md` — Mongo replica sets, compound indexes, `$jsonSchema`, transactions.

If your project uses an engine without a current `references/<engine>.md` (e.g., CockroachDB, SQLite at scale, ScyllaDB), add the file modeled on `references/postgres.md` and document the deviations.

## Inline examples in this pack

Wherever this pack's files show concrete migration / query syntax, examples lean **Postgres + TypeORM** for illustration. Substitute per ORM:

| Postgres + TypeORM (illustrated) | Prisma | SQLAlchemy + Alembic | Django ORM | Eloquent (Laravel) | Spring Data JPA | Substitution source |
|---|---|---|---|---|---|---|
| `@Entity` + `@Column` | `model` block in schema.prisma | `class User(Base)` | `models.Model` subclass | Eloquent Model | `@Entity` (JPA) | entity declaration |
| `@CreateDateColumn` / `@UpdateDateColumn` | `@default(now())` / `@updatedAt` | `Column(DateTime, default=...)` | `auto_now_add` / `auto_now` | timestamps trait | `@CreatedDate` / `@LastModifiedDate` | timestamps |
| migration via `typeorm migration:generate` | `prisma migrate dev` | `alembic revision --autogenerate` | `manage.py makemigrations` | `php artisan make:migration` | Flyway / Liquibase migration | migration tooling |
| `repo.find({ where: ..., relations: ... })` | `prisma.user.findMany` | session.query() / .options(joinedload) | `qs.select_related()` | `Model::with(...)` | `findById` / JPQL | repo / query |
| `synchronize: true` (BANNED in prod) | `prisma db push` (dev only) | `Base.metadata.create_all` (BANNED) | `runserver` auto-migrate | `Schema::create` outside migration | Hibernate `hbm2ddl=update` (BANNED) | the forbidden auto-schema flag |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual ORM, migration tool, base repo helpers, soft-delete + tenant-filter convention.
- The project's `_extracted-codebase.md § Data layer` — entity directory, migration directory, connection-pool location, slow-query threshold.
- `references/<engine>.md` — engine-specific syntax + lint tooling.

Universal hard rules (UUID v7 PKs, FK indexes, parameterized queries, expand-contract for breaking schema changes, NO transactions held across external calls) apply across all engines.
