---
description: Generate a safe, reversible, deploy-compatible DB migration. Expand-contract for breaking changes on populated tables. Rehearsed against realistic data before prod.
---

# /add-migration

Migrations are the highest-risk code in a repo. One bad migration = hours of prod pain. This command enforces the discipline.

## The Premise (read this first, internalize, do not deviate)

**Existing migrations are the truth. Mirror their shape: naming, reversibility pattern, transactional wrapping, batch-size for backfills.**

The repo already has N migrations that shipped to prod and worked. Their shape — file naming (`<NNNN>-<slug>.ts` vs `<timestamp>_<slug>.sql`), `up()`/`down()` symmetry, transactional vs `CONCURRENTLY` boundary, batch size constants (1000 vs 5000), `SKIP LOCKED` usage, locale of comments — IS the convention. A new migration that deviates from that shape is wrong by default, regardless of whether the SQL is correct.

**The agent's job is exactly this:**
1. Read the 3-5 most recent migrations on the same table family.
2. Mirror their shape: same file-name template, same `up`/`down` symmetry, same wrapping idiom, same batch constant, same comment style.
3. Write the new SQL inside that shape. Never invent a new shape.

**The agent does NOT:** ask about file naming, batch size, `down()` shape, or transactional wrapping when ≥1 sibling migration exists. The sibling IS the answer. No ADR-as-closure for shape divergence.

**The agent ONLY asks the user when:** no sibling migrations exist, sibling shapes contradict each other, or the change is irreversible by physics (DROP COLUMN with data loss) and `down()` cannot mirror sibling pattern. Three escalation triggers; everything else is silent shape-mirroring.

## Closure-verb tiers (mandatory dispatch table)

| Severity | Closure | User prompt? |
|---|---|---|
| **P0** — production-scale (>10M rows) + breaking op (DROP / RENAME / type-incompat) | `escalate` | YES — surface expand-contract plan, wait |
| **P0** — `synchronize: true` / auto-migrate path detected in config | `escalate` | YES — halt, no migration generated until removed |
| **P1** — populated table (>100k) + risky op (NOT NULL DEFAULT, CREATE INDEX, FK) | `code-edit` (mirror sibling expand-contract) | NO — auto-generate multi-step |
| **P2** — small table (<100k) OR safe op (ADD COLUMN NULL, new table) | `code-edit` (single migration, sibling shape) | NO — auto-generate |
| Sibling migrations contradict OR none exist | `escalate` | YES — halt, ask for canonical shape |

**Forbidden:** asking the user about file naming, batch size, transactional wrapping, or `down()` emptiness when ≥1 sibling migration exists. The sibling IS the answer.

## Mechanical halt — sibling-shape gate

**Before generating, the agent MUST run the sibling-shape scan:**

1. List the 3-5 most recent migration files in the project's migration folder.
2. Extract the shape signature: file-name template, `up()`/`down()` presence, transactional boundary, batch constant (if backfill), comment header style.
3. The new migration's shape signature MUST match. If it diverges on any axis without justification recorded in the migration's comment header, HALT.
4. The validator-equivalent check: `gaps_in: <shape-axes-checked>` and `gaps_matched: <shape-axes-matched>` must be equal.

If `gaps_matched != gaps_in` → HALT. Surface the divergence (e.g., "siblings use `down()` with reverse SQL; this draft has empty `down()` — refix or escalate").

If no siblings exist → halt and ask user to confirm canonical shape before generating.

## Lightweight default

**Default closure is single-migration generation in sibling shape, no chatter.** The agent does NOT ask questions on file naming, comment header, batch size, or wrapper shape when sibling migrations answer them. It generates, runs the sibling-shape gate, and reports in a batched summary:

```
Auto-applied (no prompt): sibling-shape mirror
  - file naming: <NNNN>-<slug>.ts (matched 5/5 recent siblings)
  - down() symmetry: full reverse SQL (matched 5/5)
  - batch constant: 1000 (matched 3/3 backfills)
  - transactional wrap: outside-transaction for CONCURRENTLY (matched 2/2 index migrations)
Escalated to user: <K>
  - <only genuine P0 / sibling-contradiction / first-of-kind cases>
```

## Phases applied

All 7 (Understand → Organize → Retrieve → Generate → Update → Validate → Improve).

## `--plan`

Accepts `--plan` (see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md)). With the flag set: run Phases 1-3 read-only (classify the op, size the table, run the sibling-shape scan), then emit the migration file(s) it WOULD generate — full `up()`/`down()` SQL, the expand-contract step sequence, batch constants — as a plan artifact under `.claude/plans/`. **Write no migration file, run no rehearsal, touch `ai/` not at all.** A normal run (no flag) generates as documented.

## Honesty clause

No claim without the artifact behind it: do not report a duration, lock window, or rollback time without a real `migration-rehearsal` timed run (per its "no number without a real timed run" discipline); do not list a Phase-3 read (e.g. `zero-downtime-deploys.md`) the agent did not actually open; do not mark a safety-checklist line ✓ without verifying it against the generated SQL. Unrun checks are reported as `not run`, never as ✓.

## Migration-Safety Gate — production-grade-or-INCOMPLETE (the closing verdict)

**"It applies on an empty DB" is the FLOOR, not the bar.** A migration that generates cleanly, has a non-empty `down()`, and mirrors sibling shape is merely FUNCTIONAL. The run declares **`Status: COMPLETE`** ONLY when the migration is PRODUCTION-GRADE against all five dimensions below — each PASS backed by a cited artifact, or ADR-JUSTIFIED-and-stated. Any dimension unmet, or whose evidence could not be produced, forces **`Status: INCOMPLETE — <unmet dims named>`**. A `COMPLETE` sitting on bare ✓ marks with no cited evidence is enforcement theater — forbidden here.

| # | Dimension | PASS requires (evidence, not assertion) | ADR-justified alternative (must state the accepted cost, not "should be fine") |
|---|---|---|---|
| **D1 Reversible** | `down()` reverses AND a real rollback was rehearsed | `down()` non-empty + reverse SQL, AND the `migration-rehearsal` report's **Rollback** block shows `Schema: restored ✓ (baseline diff = 0)` — cite that line | ADR at `<path>` declares irreversible-by-physics (data-destroying `down()`), names the accepted one-way cost, and cites the pre-drop backup/archive step |
| **D2 Online / zero-downtime** | The lock + backfill profile is **REPORTED from a real timed run**, never assumed away | Max lock mode + hold-time on the target table, cited from the rehearsal report's **Forward/Locks** block; hold ≤ deploy SLO (default 30s) OR expand-contract splits every step below SLO. `CONCURRENTLY` (PG) / `pt-osc`/`gh-ost` (MySQL) on populated-table index or ALTER | ADR at `<path>` accepts a maintenance-window lock — states the **measured** hold from rehearsal (e.g. `ACCESS EXCLUSIVE 2m18s`), the booked window, and why online was rejected |
| **D3 Index coverage** | Every new WHERE / ORDER BY / JOIN column this change introduces is served by an index | Name the `<index_name>` on `<table.(cols)>` for each new access path; leftmost-prefix confirmed via `EXPLAIN` showing Index Scan (not `Seq Scan` + Filter dropping >90%). Index in THIS migration set or a named follow-up migration file on the branch | ADR states the path is intentionally unindexed (write-hot / low-selectivity column) with the write-amplification trade-off |
| **D4 Rename / type-change carries a backfill + dual-read/write plan** | A bare `RENAME COLUMN` / incompatible `ALTER COLUMN TYPE` on a populated table is NEVER production-grade | The expand-contract sequence exists as N real migration files (add → dual-write → backfill → switch-read → drop) AND the app dual-write phase is named in the deploy plan | **none** — no ADR launders a bare rename on a populated table; it breaks rolling deploys by construction |
| **D5 No data loss** | Destructive or narrowing steps are recoverable | `DROP COLUMN`/`DROP TABLE`/narrowing type/dedup-before-unique each cite a pre-step backup or archive-table copy, and `down()` restores OR is D1-ADR'd | ADR states the drop is safe because the column/table has been unread ≥ 1 release — cite the grep proving no code path reads it |

### How this gate is actually enforced (honest mechanism — no theater)

- **D1 + D2 are wired to a REQUIRED OUTPUT ARTIFACT** — the `migration-rehearsal` skill's report. That skill's own halt conditions already **refuse a duration without `time` output** and **refuse rollback-clean without a schema-diff = 0**, so the numbers this gate cites cannot be fabricated. The gate quotes the report's Forward/Locks + Rollback lines verbatim. If the rehearsal harness (a restored prod-sized backup) is **absent**, D1+D2 are marked `SKIPPED — UNVERIFIED`; for a populated table (>100k) that CANNOT be `COMPLETE` — the verdict is `INCOMPLETE (rehearsal-unverified)`, never a faked PASS. [wired-to-required-output]
- **D3 is wired to `EXPLAIN`** when the DB is reachable (Index Scan vs Seq Scan is captured output). When unreachable, D3 falls back to static index-presence only and is marked `UNVERIFIED (no EXPLAIN)`. [wired-to-required-output / partial]
- **D4 is wired to the Phase-6 follow-up-migration grep** shared with `/migration-review` (`git diff --name-only origin/main...HEAD -- '*migration*'` cross-checked against the expand-contract step slugs) — a promise in prose is not a planned migration. [wired-to-required-output]
- **D5 classification** (is this SQL step data-destroying / narrowing?) is judged by reading the SQL; no shell catches a subtle `varchar(64)→varchar(32)` truncation. It is **[self-policed]** and labelled so — the agent must not dress it as mechanical.

### Required output artifact

Every run MUST emit the **Migration-Safety Gate** verdict block (see Output § below): one `D1..D5` line each carrying `PASS <evidence-citation>` | `ADR <path>` | `INCOMPLETE <what's missing>` | `SKIPPED — UNVERIFIED <why>`, then the single `Status:` line. A reader greps this block: a `Status: COMPLETE` whose D-lines carry no citation is an **invalid artifact** — reject it and re-run. `COMPLETE` is reserved for production-grade; everything short of it is `INCOMPLETE` with the gap named, so the next actor knows exactly what remains.

## When to use / NOT to use

- USE: schema change (add/drop/alter column or table).
- USE: data migration (backfill, transformation).
- USE: index addition / removal.
- NOT: mutating data via app code (use a use-case).
- NOT: experimental schema changes (prototype in a branch DB first).

## Phase 1 — Understand (the change)

**Inference-first — do NOT interrogate the user.** Derive the four facts mechanically, then escalate only on a declared trigger:

- **What changes?** — read the entity/schema diff (uncommitted entity edits, or the diff vs `origin/main`). The op (add column / rename / drop / add table / add index / data transformation) IS the diff. No question.
- **Target table(s) + current size** — size up via `SELECT COUNT(*), pg_total_relation_size(...)` (Phase 3). Use the live count; fall back to the sibling migrations' recorded estimate if the DB is unreachable.
- **Multi-tenant?** — infer from `.claude/codebase-profile.md` (multi-tenancy declaration) + whether sibling tables on the same family carry `tenant_id`. If siblings have it, the new index gets the tenant prefix.
- **Deploy compatibility** — infer from the op class: breaking ops (DROP / RENAME / type-incompat) ⇒ expand-contract + backward-compat by construction; additive ops ⇒ backward-compat single migration. State the chosen mode; do not ask.

**Escalate to the user ONLY on the three declared triggers** (per The Premise): no sibling migrations exist, sibling shapes contradict, or the change is irreversible by physics and `down()` cannot mirror a sibling. Everything else is silent inference.

State the success criteria: a reversible, concurrent-write-safe migration (or expand-contract sequence) that ships with rehearsal evidence.

## Phase 2 — Organize (classify + choose pattern)

### Classify the operation

| Op | Small table (<100k) | Populated table (>100k) | Production-scale (>10M) |
|---|---|---|---|
| `ADD COLUMN NULL` | safe | safe | safe |
| `ADD COLUMN NOT NULL DEFAULT` | safe | PG 11+: safe; MySQL/MariaDB: unsafe (rewrite) | same |
| `ALTER COLUMN TYPE` | safe if compatible | unsafe if not exact — expand-contract | dangerous |
| `DROP COLUMN` | safe at rest; dangerous if code reads it | unsafe (expand-contract) | unsafe |
| `RENAME COLUMN` | dangerous (code breaks) | unsafe (expand-contract) | unsafe |
| `ADD FOREIGN KEY` | safe | verify no orphans first; lock scan | use `NOT VALID` + validate later |
| `CREATE INDEX` | safe | unsafe (locks) — use `CONCURRENTLY` (Postgres) | mandatory `CONCURRENTLY` |
| `CREATE UNIQUE INDEX` | verify no dupes | unsafe — find dupes first | validate online first |
| `UPDATE all rows` | safe | unsafe — batch with `SKIP LOCKED` | mandatory batching |
| `DROP TABLE` | safe if unused | unsafe if any code refers | unsafe |

### Choose the pattern

**Simple additions (new column NULL, new table)**: single migration.

**Breaking changes**: expand-contract, split into N migrations + app code phases.

#### Add NOT NULL with default
```
M1: ALTER TABLE t ADD COLUMN x <type> NULL;
     (app keeps reading without x)
App: dual-write x on every write.
M2: UPDATE t SET x = <expr> WHERE x IS NULL;
     (batched, SKIP LOCKED, 1000 rows per batch, run off-peak or via rate-limited job)
M3: ALTER TABLE t ALTER COLUMN x SET NOT NULL;
     ALTER TABLE t ALTER COLUMN x SET DEFAULT <default>;
App: read/write x only.
```

#### Rename column
```
M1: ADD COLUMN new_name <type>;
App: dual-write old_name + new_name.
M2: backfill new_name = old_name (batched).
App: read new_name, write both.
App: read + write new_name only.
M3: DROP COLUMN old_name;
```

#### Change type (incompatible)
Same pattern as rename.

#### Add unique on populated column
```
# Verify no existing duplicates
SELECT col, COUNT(*) FROM t GROUP BY col HAVING COUNT(*) > 1;

# Then create
CREATE UNIQUE INDEX CONCURRENTLY ...
```

#### Add FK on populated table (Postgres)
```
# Use NOT VALID to avoid scan at constraint creation
ALTER TABLE child ADD CONSTRAINT fk_name FOREIGN KEY (parent_id) REFERENCES parent(id) NOT VALID;

# Then validate in a second migration, faster than adding fully:
ALTER TABLE child VALIDATE CONSTRAINT fk_name;
```

### Index-creation strategy

- **Postgres populated tables**: `CREATE INDEX CONCURRENTLY` — must be outside a transaction. TypeORM / Prisma may need a raw migration.
- **MySQL / MariaDB populated tables**: `pt-online-schema-change` or `gh-ost`. Native `ALTER` locks / rewrites.
- **New tables**: regular `CREATE INDEX` in same migration fine.

## Phase 3 — Retrieve (read the right context)

ALWAYS (the universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

DB-SPECIFIC:
- `ai/patterns/migrations.md`, `indexing-strategy.md`. Also `ai/patterns/zero-downtime-deploys.md` (infrastructure pack, if present) — read only when it exists; never claim a read of it otherwise.
- Engine + migration tool (TypeORM / Prisma / Alembic / Django / Flyway / goose / Laravel / Rails) from `.claude/codebase-profile.md` — the canonical engine/ORM source for every Retrieve phase in this pack.
- Size up target table(s): `SELECT COUNT(*), pg_total_relation_size(...)` — migration safety depends on size.
- Read existing migrations in the repo — match naming + style.
- The ORM entity / schema file the migration will sync with.

## Phase 4 — Generate (the migration file)

Per tool:

- **TypeORM**: `pnpm migration:generate -- src/migrations/<Name>` (auto from entity diff) then EDIT.
- **Prisma**: `prisma migrate dev --name <name>` (dev); `prisma migrate deploy` (prod).
- **Alembic**: `alembic revision --autogenerate -m "<name>"` then EDIT.
- **Django**: `python manage.py makemigrations` then EDIT if needed.
- **Laravel**: `php artisan make:migration <name>`.
- **Rails**: `rails generate migration <Name>`.
- **Raw (Flyway / goose / sqlx)**: write `up` + `down` files by hand.

Review the generated file:

- `up()` / `down()` both present.
- `down()` ACTUALLY reverses (not empty, not `DROP TABLE IF EXISTS` for a mutation).
- Concurrent-write safety matches target size (see classification above).
- Index creation uses `CONCURRENTLY` where needed.
- No mixing of schema + data in one migration (separate files).
- Single deploy concern per migration (schema OR data OR index).

## Phase 5 — Update (persist changes to the knowledge base)

- `ai/architecture.md` schema section reflects new state.
- `ai/status.md` Recent Changes entry mentioning the migration + deploy-compatibility declaration.
- ADR if an architectural decision was made (new table introducing a new module, schema pattern change).
- `ai/dynamic/changelog.md` one-line summary.
- If multi-step expand-contract → document the deploy plan in `ai/runbooks/<slug>-deploy.md`.

## Phase 6 — Validate (rehearse + safety check)

### Rehearse (populated tables, mandatory)

Run `migration-rehearsal` skill:
- Restore a prod backup (anonymized if regulated).
- Apply the migration; measure duration + locks held.
- Test app compatibility post-migration.
- Apply `down()` — confirm reversibility.
- Report: is forward < SLO? Is rollback clean?

### Safety checklist — evidence-bearing, maps 1:1 to the Migration-Safety Gate

**Every line below is `PASS <cited-evidence>` | `ADR <path>` | `UNVERIFIED <why>` — never a bare ✓.** A ✓ with no citation is exactly the enforcement theater this gate forbids. The Gate verdict (§ above) is computed from these lines.

- **D1 Reversible** — `down()` reverses (cite the SQL) AND rehearsal Rollback shows `baseline diff = 0` (cite report line). No rehearsal harness → `UNVERIFIED (rehearsal-absent)`.
- **D2 Online-safe** — lock/backfill profile REPORTED (cite rehearsal Forward/Locks: mode + hold-time); hold ≤ SLO or expand-contract splits it; `CONCURRENTLY` / `pt-osc` on populated index/ALTER. Never "should be fast".
- **D3 Index coverage** — each new WHERE/ORDER BY/JOIN column names its `<index_name>`; `EXPLAIN` shows Index Scan (cite), or `UNVERIFIED (no EXPLAIN)`.
- **D4 Backfill/dual-write for rename/type-change** — expand-contract step files present on branch (cite the grep) + app dual-write phase named. Bare rename = INCOMPLETE.
- **D5 No data loss** — destructive/narrowing steps cite a backup/archive step; `down()` restores or D1-ADR'd. [self-policed — read the SQL]
- **Hygiene** — data step batched with `SKIP LOCKED`; schema ≠ data in one file; NO `synchronize: true` / auto-migrate path (grep the config — this is always a P0 escalate).

### Verify with `schema-diff` skill — entity matches DB after migration (cite the drift-report `diff = 0`).

If any D-line is unmet or `UNVERIFIED` on a populated table: the migration is **INCOMPLETE**, not COMPLETE. HALT, name the unmet dimension in the Gate verdict, do not paper over with a ✓.

## Phase 7 — Improve (feed the learning loop)

- If this migration revealed a NEW expand-contract recipe (e.g., specific to project's ORM quirks): queue to `ai/dynamic/learned-patterns.md`.
- If rehearsal surfaced a slow-down (e.g., index creation took 10x expected time on production-like data): append to `ai/dynamic/drift-log.md` for capacity planning.
- If a coordination concern arose (devops needs to know about multi-step deploy): mention in handoff + queue to `ai/dynamic/decisions-pending.md` if it warrants an ADR.
- Run `/learn-from-task` post-migration.

## Example — complex migration design

User asks: "add `status` column to `orders` (5M rows), values from a fixed list".

Single-migration approach REJECTED (would lock orders for minutes). Proposed:

```
Migration 001: add-orders-status-nullable
  ALTER TABLE orders ADD COLUMN status VARCHAR(32) NULL;
  -- safe: instantaneous

App deploy 1:
  - On write: set status = <computed default based on row state>.
  - On read: tolerate NULL (treat as 'pending').

Migration 002: backfill-orders-status (DATA migration)
  -- Separate script, batched:
  UPDATE orders SET status = 'pending'
  WHERE id IN (
    SELECT id FROM orders WHERE status IS NULL
    FOR UPDATE SKIP LOCKED
    LIMIT 1000
  );
  -- Loop with sleep 100ms between batches, run off-peak.
  -- Monitor: rows remaining. When 0, proceed.

App deploy 2:
  - Read + write status only. Stop computing fallback.

Migration 003: enforce-orders-status-not-null
  ALTER TABLE orders ALTER COLUMN status SET NOT NULL;
  ALTER TABLE orders ALTER COLUMN status SET DEFAULT 'pending';
  ALTER TABLE orders ADD CONSTRAINT orders_status_check
    CHECK (status IN ('pending', 'paid', 'shipped', 'cancelled'));

Migration 004 (optional, index): add-orders-status-index
  CREATE INDEX CONCURRENTLY idx_orders_tenant_status_created_desc
    ON orders (tenant_id, status, created_at DESC);
  -- CONCURRENTLY on 5M rows: ~2-5 minutes.
```

Total deploy: 4 migrations + 2 app deploys over ~1 week.

## Output

```
✅ Migration generated: <name>

Phase 1 (Understand): ADD COLUMN status to orders (5.2M rows), fixed enum.
Phase 2 (Organize): expand-contract — 3 migrations + 2 app deploys.
Phase 3 (Retrieved): migrations.md, indexing-strategy.md, 7 universals.
Phase 4 (Generated): migrations/<NNNN>-<slug>.ts (or equivalent).
Phase 5 (Updated): ai/status.md Recent Changes, ai/architecture.md schema section.
Phase 6 (Validated): rehearsal passed (forward 4.2min, rollback 1.1min); schema-diff clean.
Phase 7 (Improved): /learn-from-task queued; multi-step deploy plan handed to devops.

Files:
  - migrations/<NNNN>-<slug>.ts (or equivalent)

Classification:
  Target table: orders (5.2M rows, 3.1 GB)
  Operation: ADD COLUMN + BACKFILL + SET NOT NULL
  Approach: expand-contract (3 migrations + 2 app deploys)

Migration-Safety Gate (production-grade bar — each line carries evidence, no bare ✓):
  D1 Reversible      PASS  down() reverses; rehearsal Rollback baseline diff = 0
  D2 Online-safe     PASS  rehearsal Forward: max ACCESS SHARE, no ACCESS EXCLUSIVE > 30s;
                           CONCURRENTLY on the 5M-row index (measured ~2-5m, non-blocking)
  D3 Index coverage  PASS  idx_orders_tenant_status_created_desc serves the new
                           (tenant_id, status) filter — EXPLAIN: Index Scan
  D4 Backfill/dual-write  PASS  expand-contract M1-M4 present on branch; app dual-write phase named
  D5 No data loss    PASS  additive only; down() drops the added column; no destructive step [self-policed]
  Hygiene            PASS  backfill batched (SKIP LOCKED); schema≠data split; no synchronize:true

Next migrations planned:
  - <name-step-2>
  - <name-step-3>
  - <name-step-4>

Deploy compat: backward-compatible (app works before + after each migration).
ADR: <path if architectural decision> OR n/a.

Status: COMPLETE — production-grade (all D1-D5 evidenced). Proceed with M1 deploy when devops ready.
  ── OR, if any dimension is unmet/unverified ──
Status: INCOMPLETE (rehearsal-unverified) — D2 lock profile not measured (no restored backup).
  Unmet: D2. Do not ship to prod until migration-rehearsal runs on a prod-sized copy.
```

## Hard rules

- Reversible `down()`.
- Concurrent-write safe on populated tables.
- `CREATE INDEX CONCURRENTLY` for Postgres populated tables (MUST be outside a transaction).
- `pt-online-schema-change` / `gh-ost` for MySQL populated-table ALTERs.
- Expand-contract for breaking changes — never single-migration.
- Schema ≠ data migrations — separate files.
- `migration-rehearsal` mandatory for populated tables before prod.
- No `synchronize: true` / auto-migrate in prod — EVER.

## Related

### Sibling commands in database pack
- `/db-audit` — sibling command in database pack
- `/migration-review` — sibling command in database pack
- `/optimize-query` — sibling command in database pack

### Patterns
- `ai/patterns/indexing-strategy.md`
- `ai/patterns/migrations.md`
- `ai/patterns/sharding-partitioning.md`

### Rules
- `.claude/rules/database-principles.md`
