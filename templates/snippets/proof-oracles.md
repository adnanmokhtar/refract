# Proof oracles — the failing-first proof for each detector class

Used by [`refute-before-report.md`](refute-before-report.md) gate 6, by `/db-fix`, `/perf-fix`, `/test-fix`,
`/quality-fix`, `/frontend-fix`, `/mobile-fix`, `/obs-fix`, `/devops-fix`, `/infra-fix`, `/ds-fix` and `/backend-fix` (reproduce failing-first, then validate the fix), and by every
detector whose PROOF line names an oracle. Security's counterpart is [`exploit-payloads.md`](exploit-payloads.md).
Each class has one **oracle** — a deterministic, no-human pass/fail signal — a failing-first test shape per stack,
and a **whole-class variant list** the fix must survive. Sections are per domain; later domains append their own
and continue the V-numbers after the last one in the file, never renumbering:

| Section | Variants | Oracles added after the section first shipped |
|---|---|---|
| `## Data` | V1–V24 | — |
| `## Performance` | V25–V47 | — |
| `## Frontend` | V48–V53, V147–V151 | Render-blocking list, Third-party ablation, Layout-shift observer, Build-output grep; § Lighthouse median carries the Lighthouse 13 ids |
| `## Testing` | V54–V73 | — |
| `## Code quality` | V74–V86 | — |
| `## Accessibility and UI states` | V87–V146 | render and SSR (Heap slope, Server render, Build gate, Server + client request count, Cross-request leak probe, Console warning, View update); client data and routing (Request timeline … First protected frame); i18n (Missing-key run … Bidi isolation); design tokens, motion and charts (Token conformance … Colour-vision emulation); Render measurement |
| `## Mobile` | V152–V179 | — (new section) |
| `## SEO` | V180–V188 | — (new section) |
| `## Observability` | V189–V208 | — (new section) |
| `## DevOps` | V209–V243, V290 | Out-of-band apply (V290, `gitops-audit` §1) |
| `## Infrastructure` | V244–V289 | — (new section) |
| `## Distributed` | V291–V327 | — (new section; V290 is DevOps) |
| `## Backend` | V328–V357 | — (new section) |

## Scope of use (read first)

- Run against a local, CI, branch or restored copy — never the production primary without the user's explicit go. `EXPLAIN ANALYZE` executes the statement: wrap data-changing statements in `BEGIN; … ROLLBACK;`.
- Query counting needs the **real ORM against a real database** (a container, a CI service), not a mocked repository. Concurrency and lock oracles need the project's real engine: an in-memory fake, or SQLite standing in for Postgres, hides the race and the lock.
- Seed generated data at the production **growth class** (row estimate, tenants, fan-out), not three rows. Copy production data only when anonymised.

## A fix passes the whole class, not the one query

A fix tested against the reported list endpoint is a fix for that endpoint. The regression test runs
**every** variant of the class (the class-variant list of its domain) against the
patched entry point and asserts the oracle stays quiet for all of them, while a **benign control** —
the same entry point on its legitimate path — still succeeds with its count, plan or latency unchanged.

## Failing first, then green

1. Drive the **real entry point**: the route (supertest, `fastify.inject`, Django or DRF test client, MockMvc, a request spec, a Laravel HTTP test), the job handler, or the resolver.
2. Run the test **before** the fix. It must fail on the oracle's assertion — not on setup. Paste the failing line into the finding.
3. Apply the fix; the same test goes green; then run the class variants and the control.
4. A test that passes before the fix proves nothing: the candidate goes back to the verifier, where either the claim or the test is wrong.
5. Keep the test, named after its class (`orders-list.query-count.spec.ts`). It is the regression guard.

**Reuse the repo's own counter first.** Zero hits means the harness is part of the fix:

```bash
rg -l --pcre2 'django_assert_(?:max_)?num_queries|assertNumQueries|assert_queries_count|perform_constant_number_of_queries|expectsDatabaseQueryCount|getPrepareStatementCount|SQLStatementCountValidator|\$on\(\s*["\x27]query|loggerFactory|\blogQuery\(|before_cursor_execute|QueryTracer|DbCommandInterceptor|preventLazyLoading|shouldBeStrict|strict_loading|raiseload|\bzeal(?:_context|_ignore|\.middleware)\b|nplusone|Prosopite|Bullet\.enable' -g '!**/node_modules/**' -g '!**/vendor/**' -g '!**/dist/**' .
```

## Counting queries per stack

Every query-count oracle shares this harness. Count every statement the entry point sends, writes
included; drop `begin` / `commit` / `savepoint` lines when the claim is about reads.

| Stack / ORM | Counter |
|---|---|
| **MikroORM 6** | `class CountingLogger extends DefaultLogger { override logQuery(ctx: LogContext) { if (ctx.query) sql.push(ctx.query); super.logQuery(ctx); } }`, wired with `loggerFactory: (o: LoggerOptions) => new CountingLogger(o)` in the test config. The connection hands every executed statement to `logQuery` whether or not `debug` is on (checked against 6.6.16) |
| **Prisma** | `new PrismaClient({ ...options, log: [{ emit: 'event', level: 'query' }] })`, then `prisma.$on('query', () => { n++; })` — count SQL there, not `$extends` operations |
| **TypeORM** | a `Logger` whose `logQuery()` increments (the other five methods empty), passed as `logger: counter` with `logging: ['query']` |
| **Sequelize · Drizzle · Knex · Mongoose** | `logging: () => { n++; }` · `drizzle(client, { logger: { logQuery: () => { n++; } } })` · `knex.on('query', () => { n++; })` · `mongoose.set('debug', () => { n++; })` |
| **Django** | pytest-django `django_assert_num_queries(n)` / `django_assert_max_num_queries(n)` (each yields `captured.captured_queries`); `TestCase.assertNumQueries(n)` as a context manager. Savepoints from nested `atomic()` are counted |
| **SQLAlchemy 2** | `event.listen(engine, "before_cursor_execute", lambda *a: calls.append(1))` — for an `AsyncEngine`, listen on `engine.sync_engine` |
| **Rails** | ≥ 7.2 (2024-08-09): `assert_queries_count(n) { … }` (`ActiveRecord::Assertions::QueryAssertions`; skips SCHEMA queries and query-cache hits). RSpec: the `n_plus_one_control` gem's `expect { … }.to perform_constant_number_of_queries` with a `populate { \|n\| create_list(:order, n) }` block, or count `sql.active_record` notifications (below) |
| **Laravel** | `$this->expectsDatabaseQueryCount($n)` (since 9.51.0) counts from the call to the end of the test, so call it **after** seeding; or `DB::listen(fn () => $n++)` |
| **Hibernate / Spring** | `hibernate.generate_statistics=true`; `Statistics s = emf.unwrap(SessionFactory.class).getStatistics(); s.clear(); …; s.getPrepareStatementCount()` (every statement acquired, lazy loads included); or hypersistence-utils `SQLStatementCountValidator.assertSelectCount(n)` over datasource-proxy |
| **Go** | GORM: register a callback after `gorm:query` (and the create, update, delete, row and raw processors). pgx v5: a `QueryTracer` on `ConnConfig.Tracer` whose `TraceQueryStart` increments |
| **EF Core** | a `DbCommandInterceptor` overriding `ReaderExecuting`, `NonQueryExecuting`, `ScalarExecuting` **and their `…Async` twins** (async queries call only those), added with `AddInterceptors` |
| **Ecto** | `:telemetry.attach` on `[:my_app, :repo, :query]` with a counter |

```ruby
# RSpec, or Rails before 7.2: the notifications counter, skipping what assert_queries_count skips
def sql_count(&blk)
  n = 0
  counter = ->(*, payload) { n += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
  ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &blk)
  n
end
```

## Data

### Oracle taxonomy (data)

| Oracle | Asserts | Classes |
|---|---|---|
| **Query-count scaling** | The count at N = 2 equals the count at N = 20 | V1, V3 (writes in a loop) |
| **Plan shape** | `EXPLAIN` on production-shaped, `ANALYZE`d data uses the intended access path | V2, V3, V4 |
| **Invariant under concurrency** | After N barrier-synchronised operations a stated invariant holds | V5, V6, V9, V10 |
| **Constraint rejection** | A raw write as the app role is rejected with the constraint's SQLSTATE | V6, V20, V21 |
| **Lock budget** | Under concurrent load no statement waits on the migration longer than the budget | V11 |
| **Compatibility (N-1)** | The previous release's suite passes against the new schema | V12 |
| **Round-trip** | `up → down → up` leaves a zero schema diff and the data intact | V13, V14, V15 |
| **Cross-tenant denial** | As tenant A, every path to tenant B's ids returns nothing and writes nothing | V16, V17 |
| **Fault injection** | Failing step k of a multi-step write leaves no partial state and no side effect | V7, V8 |
| **Value vectors** | Fixed and property-based vectors on money, time and id boundaries give the specified result | V18, V19, V21 |

### Query-count scaling

**Fails first when:** the count at N = 20 is the count at N = 2 plus 18 × (queries per row).
Ask for a page size that holds all 20 rows, or pagination hides the growth.

```ts
// Jest/Vitest — NestJS on Fastify + MikroORM (sql[] from the CountingLogger above)
it('lists orders in a constant number of queries', async () => {
  await seedOrders(2);  orm.em.clear(); sql.length = 0;
  await app.inject({ method: 'GET', url: '/orders?limit=50' }); const small = sql.length;
  await seedOrders(18); orm.em.clear(); sql.length = 0;
  await app.inject({ method: 'GET', url: '/orders?limit=50' }); const large = sql.length;
  expect(large).toBe(small);   // before the fix: small + 18 × (queries per order)
});
```

| Stack | Same shape |
|---|---|
| pytest + Django | seed 20 rows, then `with django_assert_num_queries(small): client.get("/api/orders/?page_size=50")`, where `small` is the count measured at 2 rows |
| Go | `seed(2); small := count(func() { get("/orders?limit=50") }); seed(18); large := count(…); if large != small { t.Fatalf("queries grew with rows: %d → %d", small, large) }` |
| JUnit + Hibernate | `seed(2); stats.clear(); mvc.perform(get("/orders?size=50")); long small = stats.getPrepareStatementCount();` — again at 20, `assertEquals(small, large)`. Seed in its own transaction and `em.clear()`; a test-wide `@Transactional` keeps seeded entities in the persistence context and hides the lazy loads |
| RSpec | `create_list(:order, 2); small = sql_count { get orders_path(per_page: 50) }` — again at 20, `expect(large).to eq(small)`; Minitest ≥ 7.2: `assert_queries_count(small) { get orders_path(per_page: 50) }` |
| PHPUnit (Laravel) | `Order::factory()->count(20)->create(); $this->expectsDatabaseQueryCount($small); $this->getJson('/api/orders?per_page=50')->assertOk();` |

**Bulk runtime form** (thousands of candidates): switch on the ORM's lazy-load-raise mode and run the
existing e2e suite — Rails `strict_loading_by_default`, Laravel `Model::preventLazyLoading()`,
SQLAlchemy `raiseload('*')`, Django `django-zeal` (`nplusone` is unmaintained since 2018) or, from
6.1, `FETCH_RAISE` set in a test-only manager's `get_queryset().fetch_mode(…)` (raises
`FieldFetchBlocked`; Django 6.1 docs, *Fetch modes*), Hibernate
statistics with a per-request threshold. A raise names the line; each one still gets its constancy
test. Blind spots: Laravel flags lazy loading only on results of more than one row, and with
`automaticallyEagerLoadRelationships()` on (12.8+) it stops flagging at all from 12.15; SQLAlchemy's
raiseload does not apply during flush; Bullet misses a finder inside a loop. There, only a count proves it.

### Plan shape

**Fails first when:** the plan for the statement the ORM emits (captured from the query log, not
re-typed) shows a `Seq Scan` on a large relation with high `Rows Removed by Filter`, a
`Sort Method: external`, or a misestimate above 10× on the hot node.

```ts
// seed to the production row estimate, then ANALYZE, then plan the captured SQL
await conn.execute(`INSERT INTO orders (customer_id, created_at)
  SELECT (random() * 50000)::int, now() - random() * interval '365 days' FROM generate_series(1, 2000000)`);
await conn.execute('ANALYZE orders');
const [{ 'QUERY PLAN': [{ Plan }] }] = await conn.execute(`EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) ${capturedSql}`, params);
const nodes = (n: any): any[] => [n, ...(n.Plans ?? []).flatMap(nodes)];
expect(nodes(Plan).find(n => n['Node Type'] === 'Seq Scan' && n['Relation Name'] === 'orders')).toBeUndefined();
```

| Stack | Same shape |
|---|---|
| pytest | `cursor.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql, params)`; Django `queryset.explain(format="json", analyze=True)` on Postgres |
| Go | `db.QueryRow(ctx, "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) "+sql, args...).Scan(&raw)`, walk `Plans` |
| JUnit | `jdbcTemplate.queryForObject("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql, String.class, args)` |
| RSpec | `ActiveRecord::Base.connection.select_value("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{relation.to_sql}")` |
| PHPUnit | `DB::select('EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) '.$q->toSql(), $q->getBindings())` |
| MySQL · MongoDB · SQLite | `EXPLAIN FORMAT=JSON` / `EXPLAIN ANALYZE` · `explain("executionStats")` (`totalDocsExamined` ≫ `nReturned` fails) · `EXPLAIN QUERY PLAN` (`SCAN` vs `SEARCH … USING INDEX`) |

Before any migration, `SELECT * FROM hypopg_create_index('CREATE INDEX ON orders (customer_id, created_at)')`
then a plain `EXPLAIN` turns the before/after into a pure plan test — an estimate only. Prepared
statements switch to a generic plan after repeated executions; test that plan too with
`SET plan_cache_mode = force_generic_plan`.

### Invariant under concurrency

**Fails first when:** after N concurrent operations the invariant breaks — more successes than
stock, a balance below zero, two rows for one natural key, a counter short by the lost updates.

```ts
await seedProduct({ id, stock: 10 });
const res = await Promise.all(Array.from({ length: 20 }, () =>
  app.inject({ method: 'POST', url: `/products/${id}/reserve`, payload: { qty: 1 } })));
const ok = res.filter(r => r.statusCode < 300).length;
const { stock } = await orm.em.fork().findOneOrFail(Product, id);
expect(ok).toBe(10);       // before the fix: more than 10
expect(stock).toBe(0);     // before the fix: above 0 (lost decrements) or below 0
```

Make the interleaving deterministic with a two-party latch between the read and the write (a spy on
the read that awaits the barrier), or step two raw connections by hand: c1 reads, c2 reads, c1
writes and commits, c2 writes and commits, assert the sum of both changes. For SQL-level proof,
Postgres's `isolationtester` runs a `.spec` of sessions, steps and permutations.

| Stack | Same shape |
|---|---|
| pytest + Django | `@pytest.mark.django_db(transaction=True)` (the default test transaction shares one connection); `ThreadPoolExecutor` over the client call; `connection.close()` at the end of each thread |
| Go | goroutines released by `close(start)` on a shared channel, joined with `sync.WaitGroup`, against the real DB |
| JUnit | `ExecutorService` + `CountDownLatch` start gate; no `@Transactional` on the test |
| RSpec | `self.use_transactional_tests = false` (or a truncation cleaner); threads inside `ActiveRecord::Base.connection_pool.with_connection` |
| PHPUnit | no in-process threads: step two PDO connections through the read and the write by hand, or fire parallel requests at a served instance |

### Constraint rejection

**Fails first when:** a raw write that skips the ORM's validation **succeeds**. Expected SQLSTATEs:
`23502` not-null, `23503` FK, `23505` unique, `23514` check, `23P01` exclusion.

| Stack | Shape |
|---|---|
| Jest/Vitest | `await expect(orm.em.getConnection().execute('INSERT INTO sellers (slug) VALUES (?), (?)', ['a', 'a'])).rejects.toThrow(UniqueConstraintViolationException)` (MikroORM also maps FK, not-null and check violations); node-postgres errors carry `.code === '23505'` |
| pytest | `with pytest.raises(IntegrityError): Seller.objects.bulk_create([Seller(slug="a"), Seller(slug="a")])` (bulk paths skip model validation) |
| Go | `var pgErr *pgconn.PgError; if !errors.As(err, &pgErr) \|\| pgErr.Code != "23505" { t.Fatal(err) }` |
| JUnit | `assertThrows(DataIntegrityViolationException.class, () -> jdbc.update("INSERT …"))`; the SQLSTATE is on the cause's `getSQLState()` |
| RSpec | `expect { Seller.insert_all([{ slug: "a" }, { slug: "a" }]) }.to raise_error(ActiveRecord::RecordNotUnique)` |
| PHPUnit | `DB::table('sellers')->insert([...])` inside `try`; assert `QueryException` with `$e->errorInfo[0] === '23505'` |

Paths that skip validation are the variants (V20): `update_all`, `QuerySet.update()`, `insertMany`,
bulk import, raw SQL.

### Lock budget

**Fails first when:** a long reader holds `ACCESS SHARE`, the migration queues for its
`ACCESS EXCLUSIVE`, and an ordinary `SELECT` queues behind the migration past the budget.

```text
session A  BEGIN; SELECT 1 FROM orders LIMIT 1;          -- a long reader; hold it open
session B  run the migration under test through the project's runner, with production settings
session C  SET statement_timeout = '<budget>'; SELECT count(*) FROM orders;   -- must succeed
pass:      B fails fast with 55P03 (lock_not_available) under its lock_timeout and C succeeds
fail:      B waits, C times out behind it (57014) — the lock queue, not the DDL, took the table
```

Runner entry points for session B: MikroORM `orm.migrator.up()` (`getMigrator()` is gone in v7), TypeORM
`dataSource.runMigrations()`, Knex `knex.migrate.latest()`, Django `call_command("migrate")`,
Alembic `command.upgrade(cfg, "head")`, `bin/rails db:migrate`, `Artisan::call('migrate')`,
golang-migrate `m.Up()`, Flyway `migrate()`. Statically, `eugene trace` (MIT) runs a script in a
transaction and reports the locks each statement takes, and squawk names the rule. A table rewrite
needs the timed rehearsal on a restored copy: `migration-rehearsal` (database pack).

### Compatibility (N-1)

**Fails first when:** the previous release's suite fails against the migrated schema — a renamed or
dropped column still selected, a `NOT NULL` the old inserts omit, a removed enum value.

```bash
git worktree add ../prev "$(git describe --tags --abbrev=0)"
# migrate the test database with the NEW migrations, then run the OLD suite against it
(cd ../prev && DATABASE_URL="$TEST_DATABASE_URL" npm test)     # pytest · go test ./... · mvn test · bundle exec rspec · php artisan test
```

The reverse order (new code against the old schema, before migrating) is the code-first variant.

### Round-trip

**Fails first when:** `up → down → up` leaves a schema diff, or the down step loses data it claims
to keep.

```bash
pg_dump --schema-only --no-owner "$TEST_DATABASE_URL" > before.sql
# one step down, then up again, with the project's runner
pg_dump --schema-only --no-owner "$TEST_DATABASE_URL" > after.sql
diff -u before.sql after.sql          # must be empty; also compare row counts or checksums of the touched tables
```

Runner steps: MikroORM `migration:down` / `migration:up` (and `migration:check` for model drift);
Django `migrate <app> <previous>` / `migrate <app>` (and `makemigrations --check --dry-run`); Rails
`bin/rails db:migrate:redo`; Laravel `migrate:rollback --step=1` then `migrate`; Alembic
`downgrade -1` / `upgrade head`; Prisma `migrate diff … --exit-code` for drift. A runner with no down
step makes the class forward-only by policy (`precedents/data.md § 16`) and this oracle `N/A`.

### Cross-tenant denial

**Fails first when:** acting as tenant A, any path to tenant B's ids returns B's data or changes B's
rows.

| Stack | Shape |
|---|---|
| Jest/Vitest | `inject({ url: '/orders/' + idOfB, headers: authAs(A) })` → 404; the list as A contains no id of B; `PATCH` B's id as A → 404 and B's row unchanged |
| pytest · Go · JUnit · RSpec · PHPUnit | the same three requests through the stack's HTTP test client, with a two-tenant fixture |
| RLS (SQL) | as the **runtime** role: `BEGIN; SELECT set_config('app.tenant_id', '<A>', true); SELECT count(*) FROM orders WHERE tenant_id = '<B>';` → 0 |
| Pooler leak | after tenant A's transaction commits, a new transaction on the same pooled connection reads `current_setting('app.tenant_id', true)` → empty |

This class belongs to security when the security pack is installed (`refute-before-report.md § 9`).

### Fault injection

**Fails first when:** making step k of a multi-step write fail leaves a partial row, or a side
effect (email, webhook, queue message) fires for a transaction that rolled back.

| Stack | Shape |
|---|---|
| Jest/Vitest | `jest.spyOn(gateway, 'capture').mockRejectedValueOnce(new Error('boom'))`; call the use case; assert no order row, stock unchanged, nothing in the outbox |
| pytest | `with mock.patch.object(svc.gateway, "capture", side_effect=RuntimeError): …`; assert the same |
| Go | a fake implementing the dependency's interface that returns an error on call k |
| JUnit | `Mockito.doThrow(new RuntimeException()).when(gateway).capture(any())` |
| RSpec | `allow(gateway).to receive(:capture).and_raise(StandardError)` |
| PHPUnit | `$this->mock(Gateway::class, fn ($m) => $m->shouldReceive('capture')->andThrow(new RuntimeException()))` |

A database-level failure is a stronger variant: pre-insert a row that makes step k violate a
constraint, so the failure happens inside the transaction rather than in a mock.

### Value vectors

**Fails first when:** a fixed vector gives the wrong result. Money: `0.1 + 0.2`; `100.00 / 3` must
allocate back to `100.00`; 0-decimal (JPY) and 3-decimal (KWD, BHD) currencies; refunds and
negatives; amounts beyond 2^53 minor units in JS; JSON carries decimals as strings. Time: run the
suite under `TZ=Asia/Kolkata`, `America/St_Johns` and `Pacific/Chatham` with a database session zone
that differs from the app's; DST gap and overlap; 29 February; MySQL `TIMESTAMP` after 2038-01-19.
Property tests generate the rest: fast-check, Hypothesis, jqwik, Go fuzzing (`go test -fuzz`),
PHPUnit data providers, RSpec shared examples over a table.

### Class variants (data)

Each class lists the minimal discriminating variants — one per distinct way the defect re-appears.
V-numbers are unique across this file; later domains continue the sequence.

#### V1. N+1 / lazy loading — query-count scaling
- top-level relation on a list endpoint (orders → customer); second-level relation (order → items → product)
- relation touched by a serializer, DTO getter, `toJSON` or computed property, not by the controller
- count or existence per row (`.count` vs `.size` in Rails, `relation.count()` per item, `exists?` in a loop)
- conditional access behind a flag, feature or role (run the test with it on); per-row authorization loading the owner or membership
- GraphQL field resolver per parent; template or view iteration; CSV / export path; a background job over the same set
- polymorphic association; `has_many :through`; soft-delete-scoped relation
- writes in a loop (N `INSERT`/`UPDATE` where one bulk statement would do)
- page 2 of the same list (some paginators take a different code path)

#### V2. Missing index / non-sargable predicate — plan shape on production-shaped data
- every filter combination the endpoint accepts; every allowed sort column and direction, incl. `NULLS FIRST/LAST`
- first page and a deep page; an `IN` list of 1 and of hundreds of values
- case-insensitive match (`lower(col) = …` needs an expression index or `citext`); prefix vs infix `LIKE`
- parameter type differing from the column type (implicit cast disables the index)
- generic vs custom plan (`SET plan_cache_mode = force_generic_plan`)
- most-common vs rare value; largest vs smallest tenant
- a partial index whose predicate (`deleted_at IS NULL`) the query must repeat

#### V3. Unbounded read — seed cap + 1 rows; the response holds ≤ cap and the SQL carried a `LIMIT`
- no `limit`; `limit=0`, `-1`, `1e9`, `abc` (clamped, not trusted)
- export, report, admin and background-job paths; GraphQL `first:`
- a nested collection inside one item (an order with 10k lines); an empty search term that matches everything

#### V4. Pagination correctness — walk every page while inserting and deleting; no duplicates, no gaps
- ties in the sort key without a unique tiebreaker; NULLs in the sort key; descending order
- a tampered cursor; a cursor pointing at a deleted row; the last page

#### V5. Lost update (read-modify-write) — invariant under concurrency
- the same endpoint × N; two endpoints on one counter (debit vs refund, redeem vs cancel)
- the same idempotency key replayed concurrently; two app processes (an in-process mutex is not a fix)
- retry-after-timeout; bulk vs single endpoint; a cross-row invariant (stock row + order row)

#### V6. Uniqueness / write skew — N concurrent creates of one natural key → exactly one row, the rest a clean 409
- case and accent variants (`A@x.com` / `a@x.com`; `José` / `Jose` under an `_ai_ci` collation)
- trailing space under PAD SPACE collations; NFC vs NFD; zero-width characters
- re-create after soft delete (allowed → partial unique index); the same key in another tenant (allowed → tenant-scoped constraint)
- a NULL in one column of a composite key (`NULLS NOT DISTINCT`, Postgres ≥ 15)
- overlapping ranges (`EXCLUDE USING gist`, or Postgres 18 `WITHOUT OVERLAPS` — not SELECT-then-INSERT)

#### V7. Missing transaction / partial write — fault injection
- a failure after each statement of the multi-step write
- the external call failing after the DB write (needs an outbox, not a try/catch)
- the worker killed mid-job and retried (idempotent re-run); nested services each opening their own transaction

#### V8. Side effect inside a transaction — rollback emits nothing; the after-commit consumer sees committed data
- email, webhook or queue message sent before commit, then rollback
- a job enqueued inside the transaction runs before commit and reads "not found"
- a cache invalidated before commit (the stale value is re-cached)

#### V9. Deadlock — 100 iterations of two opposite-order transactions, zero `40P01` / MySQL 1213
- batch update over unsorted ids; parent + child inserts in different orders; cascade delete vs child insert; upserts racing on two unique keys

#### V10. Serialization failure without retry — force a `40001`; the operation still completes exactly once
- the retry wraps the whole transaction, not the failed statement; side effects fire once across retries; the retry is bounded with backoff

#### V11. Blocking DDL — lock budget under load
- each statement of the migration separately (one safe statement does not clear the file)
- production-scale rows (an empty dev table hides rewrites)
- a long reader holding `ACCESS SHARE` when the DDL arrives — with `lock_timeout` the migration must fail fast
- `CREATE INDEX CONCURRENTLY` interrupted → an `INVALID` index; the re-run must drop and recreate it
- MySQL: an open transaction holding the metadata lock; `ALGORITHM=INSTANT` / `INPLACE, LOCK=NONE` spelled out so an unsupported change errors instead of copying

#### V12. Backward-incompatible schema change — compatibility (N-1)
- rename or drop a column or table (ORM schema caches and explicit column lists still name it)
- `NOT NULL` added while old code inserts without the column; a changed default (Rails omits default-valued columns from `INSERT`)
- an enum value removed or renamed; a narrowed type; a new FK or CHECK that rows written by old code violate
- code-first order: new code against the old schema

#### V13. Backfill / data migration — run on a production-shaped copy
- bounded batches, each under the time budget, throttled, resumable after a kill, idempotent on re-run
- rows written concurrently by new code during the backfill; NULL, malformed and boundary rows; replica lag under budget

#### V14. Reversibility — round-trip
- a destructive step has a data-preserving down, or an explicit reviewed "irreversible" marker and a backup point

#### V15. Schema drift — the diff tool exits 0
- model vs migrations; migrations vs the live schema per environment; ORM auto-sync off in production (`synchronize`, `db push`, `ddl-auto=update`, `sync({ alter })`, MikroORM `schema:update --run` at start)

#### V16. Tenant isolation at the DB layer — cross-tenant denial
- read by id, list, search, count / aggregate, export, raw SQL; reach through a child table
- a background job or cron with no request tenant; admin impersonation
- insert or update with `tenant_id = B` (RLS `WITH CHECK`)
- a pooled connection reused after tenant A (session `SET` leaks; `SET LOCAL` does not)
- as the table owner (needs `FORCE ROW LEVEL SECURITY`); through a view without `security_invoker`; through a `SECURITY DEFINER` function
- the same email in two tenants; a composite FK that stops pointing at B's row; the anonymous API role

#### V17. Soft delete — soft-delete a row, then every path hides it (except explicit admin and restore)
- list, get-by-id, count / aggregate, search index, export; a relation loaded from the parent; a raw-SQL join
- unique re-create after delete; FK children of the deleted row; restore; hard-delete / erasure job

#### V18. Money / decimal — value vectors
- `0.1 + 0.2`; `1.005` under the business rounding rule (half-even vs half-up)
- 0-decimal and 3-decimal currencies; negatives and refunds; beyond 2^53 minor units in JS; `numeric(p,s)` overflow
- `100.00 / 3` allocates back to `100.00`; tax per line vs per invoice; FX rounding
- `Decimal` / `BigInt` serialised as strings; DB `SUM` equals the app's sum

#### V19. Time — the suite under non-UTC `TZ` and a DB session zone that differs from the app's
- `Asia/Kolkata` (+05:30), `America/St_Johns` (−03:30), `Pacific/Chatham` (+12:45), `Australia/Lord_Howe` (30-minute DST)
- the DST gap and overlap; local vs UTC midnight bucketing; month end; 29 February
- MySQL `TIMESTAMP` beyond 2038-01-19; an inclusive `BETWEEN` upper bound
- future local events across a zone-rule change; `now()` is transaction start; JS `new Date('YYYY-MM-DD')` parses as UTC midnight

#### V20. Missing constraint — constraint rejection
- one raw write per constraint (not-null, FK, unique, check, exclusion)
- paths that skip ORM validation: `update_all`, `QuerySet.update()`, `insertMany`, bulk import, raw SQL
- a parent deleted concurrently while a child is inserted

#### V21. Identifier exhaustion — the sequence set near the type maximum
- `ALTER SEQUENCE … RESTART WITH 2147483640`, then insert (int4)
- every FK column referencing the key has the same width; JS clients receiving ids > 2^53 get strings

#### V22. Connections and timeouts — deliberate slow or blocked work
- `pg_sleep` beyond `statement_timeout` → cancelled (`57014`)
- the pool exhausted by concurrent slow requests → an acquire timeout, not a hang
- an idle-in-transaction session killed by `idle_in_transaction_session_timeout`
- a transaction-mode pooler: session `SET`, advisory locks, `LISTEN`, named vs unnamed prepared statements

#### V23. Retention / unbounded growth — seeded aged rows
- the retention job deletes in indexed batches (or drops partitions), leaves in-policy rows, and covers soft-deleted rows and log / audit tables with PII

#### V24. Backup / restore — a restore drill, not a backup log
- restore the latest backup into a scratch instance, run row-count and checksum queries, record the time (RTO) and the newest recovered commit (RPO); PITR to a timestamp; the key for encrypted backups is available

## Performance

### The core rule: existence by invariant, cost by statistics

**Existence is proved by a run-invariant check** — a number that does not move between runs on the
same code: the query count at two sizes, allocations per operation, a call or render count, bundle
bytes, the time **ratio** at N vs 10N (about 10× per decade is linear, about 100× is quadratic), an
`EXPLAIN` plan. One run per side is enough, and the check is a deterministic test.

**Cost is proved by a noise-aware timing comparison**, and only when the claim is about cost: the
same harness, data, machine and tool version on both sides; **at least 10 runs per side, never fewer
than 5**; A and B **interleaved** (ABAB…), never all-A-then-all-B; a Mann-Whitney U or Welch test
whose 95% confidence interval of the shift **excludes zero**; and an effect **larger than the noise**
(above the measured band and a practical floor of 1–2%). Never re-run until it turns significant.
Two consequences to know before trusting a CI number:

- Go's `go test -bench -count=3` can never reach significance — an exact two-sided Mann-Whitney at 3 vs 3 cannot go below p = 0.10. Build both test binaries, run each `-test.count=1` interleaved ten times, and compare with `benchstat`; its `~` means no detectable change.
- A 2% wall-clock gate on shared CI runners raises false alarms about 45% of the time (GitHub-hosted, CV ≈ 2.7%, CodSpeed's measurement). Gate shared CI on run-invariant counts; gate timing only on a dedicated runner, or with a threshold above the measured noise.

A proof of existence makes a Finding (`precedents/performance.md § 2`); a cost number only ranks it.

**Tool notes.** k6 is AGPL-3.0: run it as a tool, never vendor its code into the project. Lighthouse
CI 0.15.1 bundles Lighthouse 12.6.1, so its assertions must use the Lighthouse 12 audit ids — the
Lighthouse 13 `*-insight` ids may not resolve there.

### Oracle taxonomy (performance)

| Oracle | Asserts | Classes |
|---|---|---|
| **Wall-clock with mocked latency** | Independent calls each mocked at latency L finish in < 2L, not ≈ k × L | V25 |
| **Max in-flight** | The peak number of concurrent calls is ≥ 2 where they should overlap, and ≤ the cap where they must be bounded | V25, V26 |
| **Event-loop delay** | The p99 event-loop delay under concurrent requests stays under the stated budget | V28 |
| **Heap growth** | Retained memory stays flat across batches of distinct inputs after a forced GC | V29, V32 |
| **Timeout firing** | A dependency that never answers is abandoned within timeout + margin | V22, V34 |
| **Socket / handle count** | Connections opened, handles and pool slots return to baseline across N calls | V30, V32 |
| **Time ratio at N vs 10N** | Work on request- or data-sized input grows about 10× per decade, not about 100× | V35 |
| **Two replicas behind round-robin** | A second replica sees the same session, state, limit, file and broadcast, and once-per-fleet work runs once | V36–V42 |
| **Queue age at a fixed arrival rate** | At a fixed λ the oldest-message age stays flat, and more consumers raise throughput up to the cap | V43 |
| **Redelivery** | A redelivered, duplicated or over-long job causes exactly one effect; a poison message reaches the DLQ | V44 |
| **Server limits** | Keep-alive outlives the load balancer's idle timeout; a slow header is cut off; an oversized body gets 413 | V45 |
| **Admission control** | Past the cap, excess work is refused fast instead of queued | V46 |
| **Probe independence** | Liveness keeps answering while a shared dependency is down | V47 |

Three run-invariant checks serve beside them. **Query-count scaling** from the data section proves
network N+1 against a cache or HTTP batch API (V27, count calls instead of queries), and
**cross-tenant denial** proves a cache key without its tenant (V33). **Allocations per operation**
proves per-call construction and allocation-heavy loops without a clock (V31): Go
`testing.AllocsPerRun` or `b.ReportAllocs()`, JMH `-prof gc` (`gc.alloc.rate.norm`),
BenchmarkDotNet `[MemoryDiagnoser]`.

### Wall-clock with mocked latency

**Fails first when:** three independent dependencies mocked at L = 100 ms take ≈ 3L together.

```ts
const L = 100;
const after = <T>(v: T) => () => new Promise<T>(r => setTimeout(() => r(v), L));
jest.spyOn(inventory, 'get').mockImplementation(after(stock));
jest.spyOn(pricing, 'quote').mockImplementation(after(price));
jest.spyOn(reviews, 'list').mockImplementation(after([]));
const t0 = performance.now(); await service.orderDetail(id);
expect(performance.now() - t0).toBeLessThan(2 * L);   // before the fix ≈ 3L
```

The deterministic form needs no clock: with fake timers, start the call, advance by L, and assert it
settled — `let done = false; p.then(() => (done = true)); await vi.advanceTimersByTimeAsync(L); expect(done).toBe(true)`.

| Stack | Same shape |
|---|---|
| pytest (asyncio) | `AsyncMock(side_effect=lambda *a, **k: asyncio.sleep(L, result=v))` per dependency; `time.perf_counter()` around the call; assert `< 2 * L` |
| Go | fakes that `time.Sleep(L)`; `start := time.Now(); svc.Detail(ctx, id); if time.Since(start) >= 2*L { t.Fatal(…) }` |
| JUnit | `doAnswer(inv -> { Thread.sleep(L); return v; }).when(dep).call(any())`; `System.nanoTime()` around the call |
| RSpec | `allow(dep).to receive(:call) { sleep(L); v }`; `Process.clock_gettime(Process::CLOCK_MONOTONIC)` around the call |
| PHPUnit | only where the code issues concurrent requests (`Http::pool`, Guzzle promises): a local stub that sleeps L per endpoint |

### Max in-flight

**Fails first when:** the peak is 1000 for a 1000-item fan-out that must be capped, or 1 for calls
that should overlap.

```ts
let inFlight = 0, peak = 0;
jest.spyOn(shipping, 'quote').mockImplementation(async () => {
  peak = Math.max(peak, ++inFlight); await new Promise(r => setTimeout(r, 5)); inFlight--; return 1;
});
await service.quoteCart(cartWithItems(1000));
expect(peak).toBeLessThanOrEqual(8);   // the limiter's cap; before the fix: 1000
```

Python: the same counter inside the `AsyncMock`. Go: `atomic.AddInt64` with a compare-and-swap
peak. Java: `AtomicInteger`. Ruby: a `Mutex`-guarded counter. Add the concurrent-requests variant:
two requests each fanning out must still respect a **global** cap when the limit is meant to protect
the downstream.

### Event-loop delay

**Fails first when:** synchronous work on the request path (a `…Sync` call, `bcrypt.hashSync`, a
large `JSON.parse`) pushes the p99 loop delay past the budget under concurrent requests.

```ts
import { monitorEventLoopDelay } from 'node:perf_hooks';
const h = monitorEventLoopDelay({ resolution: 10 }); h.enable();
await Promise.all(Array.from({ length: 20 }, () => app.inject({ method: 'POST', url: '/signup', payload })));
h.disable();
expect(h.percentile(99) / 1e6).toBeLessThan(BUDGET_MS);   // the histogram records nanoseconds
```

Measure the benign control (an endpoint with no such work) the same way first; the budget is a
margin over that baseline, not an absolute number. Python asyncio: run with `loop.set_debug(True)`
and `loop.slow_callback_duration = 0.05`, and assert the `asyncio` logger emitted no slow-callback
warning. Reactor / WebFlux: `BlockHound.install()` makes a blocking call on a non-blocking thread
throw. Thread-per-request servers have no loop to stall (`precedents/performance.md § 27`): measure
worker-seconds instead.

### Heap growth

**Fails first when:** retained memory grows with each batch of **distinct** inputs (the same key
repeated hides a per-key leak). Prefer a structural count when one exists — the cache map's size,
the listener count, the active timer count — it is exact and needs no noise band.

```ts
// run the worker with --expose-gc (e.g. node --expose-gc node_modules/.bin/jest --runInBand)
const retained = () => { global.gc!(); return process.memoryUsage().heapUsed; };
for (let i = 0; i < 200; i++) await hit(i);                 // warm-up
const a = retained(); for (let i = 200; i < 2200; i++) await hit(i);
const b = retained(); for (let i = 2200; i < 4200; i++) await hit(i);
const c = retained();
expect(c - b).toBeLessThan(EPSILON_BYTES);                  // a leak shows c − b ≈ b − a, both large
```

| Stack | Same shape |
|---|---|
| pytest | `tracemalloc.start()`; `gc.collect()`; snapshots between batches; `sum(s.size_diff for s in s2.compare_to(s1, "filename"))` |
| Go | `runtime.GC(); runtime.ReadMemStats(&m)` → `m.HeapAlloc` between batches; `runtime.NumGoroutine()` back to baseline; `goleak.VerifyNone(t)` |
| JUnit | a structural count through a test hook, or a `WeakReference` to a per-request object that must clear after `System.gc()` in a bounded loop; raw heap numbers on the JVM are too noisy to assert |
| RSpec | `GC.start; ObjectSpace.each_object(Klass).count` between batches |
| PHPUnit | per-request PHP-FPM memory resets each request; assert `memory_get_usage()` across N jobs only in long-running workers (queue workers, Octane) |

Anything the test cannot isolate goes to `memory-leak-hunt` (performance pack) for a soak.

### Timeout firing

**Fails first when:** a dependency that never answers holds the caller past timeout + margin, or a
statement past the database's timeout is not cancelled.

- **Database:** lower the timeout through the **same configuration path production uses** (the env var or role setting), then run `SELECT pg_sleep(<timeout + 1 s>)` through the app's own pool and expect SQLSTATE `57014`; assert the production value separately with `SHOW statement_timeout` on a pooled connection. A lock wait past `lock_timeout` raises `55P03`.
- **Outbound HTTP:** a real socket that accepts and never answers — Node `http.createServer(() => {})`, Go `httptest.NewServer` whose handler waits on `r.Context().Done()`, a Python `asyncio.start_server` that never writes. Assert the call rejects with the client's timeout error within timeout + margin. A mock that *raises* a timeout error proves the handler of the error, not that the timeout is configured.

### Socket and handle count

**Fails first when:** N calls open N connections (a client or agent built per call), or handles and
pool slots do not return to baseline.

```ts
let opened = 0;
const stub = http.createServer((_, res) => res.end('ok')).on('connection', () => opened++);
await new Promise<void>(r => stub.listen(0, r));
const url = `http://127.0.0.1:${(stub.address() as AddressInfo).port}`;
for (let i = 0; i < 50; i++) await client.fetchQuote(url);
expect(opened).toBeLessThanOrEqual(POOL_SIZE);   // before the fix: 50
```

Go: `srv := httptest.NewUnstartedServer(h); srv.Config.ConnState = func(_ net.Conn, s http.ConnState) { if s == http.StateNew { atomic.AddInt64(&opened, 1) } }; srv.Start()`.
Python: count connections in an `asyncio.start_server` callback. Handles and pool slots: Jest
`--detectOpenHandles`; `goleak`; Python `-W error::ResourceWarning`; node-postgres `pool.totalCount`
/ `idleCount` / `waitingCount`, HikariCP's pool MXBean, SQLAlchemy `engine.pool.checkedout()`
back to baseline after N iterations, including the error path.

### Time ratio at N vs 10N

**Fails first when:** the work at 10N costs about 100× the work at N (quadratic) on an input the
request or the data sizes. Count operations where you can — a counter in the comparator or the
inner lookup gives N × M before the fix and N + M after, with no clock. Otherwise time each size
the median of 5 runs after a warm-up, and separate pass from fail by a factor, not a percentage
(§ Noise band rules for timing oracles, rule 2).

```ts
const time = (n: number) => { const { orders, ids } = seed(n); const t0 = performance.now(); reconcile(orders, ids); return performance.now() - t0; };
const median = (n: number) => { const xs = Array.from({ length: 5 }, () => time(n)).sort((a, b) => a - b); return xs[2]; };
time(1_000);                                             // warm-up
expect(median(10_000) / median(1_000)).toBeLessThan(30); // linear ≈ 10 per decade; before the fix (includes in a loop) ≈ 100
```

Python: `min(timeit.repeat(lambda: f(data(n)), number=1, repeat=5))` at n and 10n. Go: a benchmark
per size (`b.Run(fmt.Sprint(n), …)`) and the ratio of ns/op. JMH: `@Param` over the sizes. Take
the sizes from production (the largest page, import or tenant), not from the fixture.

### Two replicas behind round-robin

**Fails first when:** what holds on one replica breaks on two — a login served by A is unknown to
B, a value written through A is stale through B, the effective limit doubles, an upload 404s on B,
a tick runs twice, an event emitted on B never reaches a client on A, queued work dies with its
process. Run it only in a disposable environment.

```bash
docker compose up -d --scale api=2      # the service under test, reachable only through the proxy below
# proxy: nginx with `upstream app { server api:3000; }` — a name that resolves to several addresses defines one server per
# address, so requests alternate between the replicas; publish the proxy's port, not the replicas'
docker kill -s KILL "$(docker compose ps -q api | head -1)"     # the kill -9 variant
```

- **Prove the alternation first:** ten requests to a route that returns the host name show both replicas. A test that passes because every request hit one replica proves nothing.
- **Override schedules through the path production uses** (`CRON_EXPR`, a feature flag, an env var), never by editing the code under test.
- **Count effects where they land** — rows, outbox entries, a provider mock's call log — not in logs.
- Each class's pass condition is in its variant (V36–V42). A test that passes before the fix proves nothing (§ Failing first, then green).

### Queue age at a fixed arrival rate

**Fails first when:** the cited arithmetic shows capacity below the arrival rate — workers needed ≈
λ × service time (Little's law) against concurrency × replicas — or concurrency × replicas ×
connections per job exceeds the database pool, or consumers exceed the partition count. The
arithmetic, with every term's `<file:line>` or metric, is a static-fact proof; the run that
confirms it holds a fixed λ for 10 minutes with the `load-test` skill (performance pack): the
oldest-message age stays flat, and doubling consumers roughly doubles throughput up to the cap.
With λ unknown the candidate is Unconfirmed, carrying the metric to read.

### Redelivery

**Fails first when:** a job that outlives its lock or visibility timeout runs twice, a message
delivered twice causes two effects, or one poison message blocks the rest.

| Probe | Pass |
|---|---|
| a job that sleeps 1.5 × the lock or visibility timeout | exactly 1 side effect (count rows or provider calls) |
| the same good message delivered twice | 1 effect |
| 1 poison message among 100 good | the 100 drain; the poison lands in the dead-letter queue after the configured tries |

BullMQ: set `lockDuration` low in the test config and block the processor. SQS: a visibility
timeout shorter than the handler. Celery: `acks_late` with a worker killed mid-task. Kafka: a
batch that outlives `max.poll.interval.ms`.

### Server limits

**Fails first when:** the app closes idle keep-alive connections before the load balancer does
(intermittent 502s), `headersTimeout` is not above `keepAliveTimeout`, a client that sends headers
slowly holds a connection open, or an oversized body is read into memory. The configuration
arithmetic, with both terms cited (the LB idle timeout from the infrastructure code or the
provider's default, the app's keep-alive from code or the runtime default for the installed
version), is the static-fact proof. The runtime checks: a soak through the real load balancer with
idle gaps longer than its idle timeout gives 0 × 502; a slow-header client (`slowhttptest`) is cut
off at the header-read timeout; an oversized body gets 413.

### Admission control

**Fails first when:** with every worker busy, work past the cap is queued without bound instead of
refused. Block the workers (a downstream mock that waits on a latch), submit cap + K items, and
assert the K excess are rejected fast — a 429 or 503 with `Retry-After`, or the executor's
rejection — while memory stays flat; release the latch and the accepted items complete. Cost,
when it matters: an open-model run to twice the measured knee (`load-test`), where goodput
plateaus and the accepted requests' p99 stays under the client's timeout.

### Probe independence

**Fails first when:** the liveness endpoint fails while a shared dependency is down, so the
orchestrator restarts every pod at once. Stop the dependency (or make its client fail) and assert
liveness still returns 200; readiness may fail only where a degraded mode is not offered and that
decision is written down. In a disposable cluster, stop the database for 60 s: no pod restarts.

### Noise band rules for timing oracles

1. **Prefer a run-invariant check.** Queries, calls, allocations, in-flight peak, sockets, listeners, map size and bytes are exact; a timing assertion is the fallback (§ The core rule).
2. **Separate pass from fail by a factor, not a percentage.** Mock at L ≥ 50 ms and assert `< 2L` where the failure is `≈ 3L`: a margin of L on each side survives a noisy machine. Use fake timers where the runtime allows.
3. **Measure the band before reading any delta.** Re-run the unchanged baseline at least three times; the spread is the band, and a before→after delta inside it is `NO-CHANGE` (the performance pack's own rule).
4. **Warm up, then take at least 10 runs per side, interleaved.** Discard the warm-up runs (JIT, connection pools, caches); never fewer than 5 per side; ABAB order, so drift lands on both sides.
5. **Decide with a confidence interval.** Mann-Whitney U or Welch; the 95% interval of the shift excludes zero **and** the effect exceeds the band and the 1–2% practical floor. A p-value without an effect size, or an effect inside the noise, is `NO-CHANGE`.
6. **Run timing tests serially and alone.** `--runInBand`, `-p 1`, no `pytest-xdist`; parallel test workers are noisy neighbours, and so is a shared CI runner (§ The core rule).
7. **Compare against a control, not an absolute.** Event-loop delay and heap are judged as a margin over the benign control measured in the same run.
8. **A flaky timing test is not a proof.** Convert it to a run-invariant check, or record the candidate as Unconfirmed with the measurement that would settle it.
9. **Label every number.** `measured` with the harness, run count and interval, or `ESTIMATED` with the model written out; a number with no label is deleted.

### Class variants (performance)

#### V25. Sequential awaits of independent I/O — wall-clock with mocked latency / max in-flight
- two calls and three or more; calls inside a branch taken only for some inputs
- one dependency failing: the error path must not serialise the others (`Promise.all` vs `allSettled` semantics kept as designed)
- "async, so concurrent": `await` in sequence inside an `async` function; `for … of` with `await` over independent items
- a dependent pair as the control (cursor pagination, a rate-limited or ordered downstream): it must stay sequential

#### V26. Unbounded fan-out — max in-flight
- `map` + `Promise.all`; `for` + `push` + `allSettled`; `asyncio.gather(*…)`; `create_task` in a loop; a goroutine per item; `parallelStream`; a `CompletableFuture` per item; `Task.WhenAll(Select)`; `Parallel.ForEach` without a max degree; a consumer with unbounded prefetch
- 1,000 items; 0 and 1 item; nested fan-out (each item fans out again)
- retries multiplying the in-flight count; two concurrent requests against a global cap

#### V27. Network N+1 — call-count scaling
- per-item `fetch` or SDK call (payments, storage, LLM) where a batch API exists; per-item cache `GET` where `MGET` or a pipeline exists
- a per-field resolver calling a service; webhook fan-out per row; a cache-miss loop
- the same at N = 2 and N = 20; a partial cache hit (some keys cached, some not)

#### V28. Blocking work on the event loop or async runtime — event-loop delay
- Node: `fs.*Sync`, `crypto.pbkdf2Sync` / `scryptSync` / `generateKeyPairSync`, `zlib.*Sync`, `child_process.*Sync`, sync `bcrypt`, large `JSON.parse` / `stringify` or a deep-clone idiom, a big `sort`, a template compiled per request, a catastrophic regex
- Python async: `requests` / `urllib`, `time.sleep`, a sync DB driver or ORM call, file I/O, `subprocess`, boto3, a sync Redis client, `asyncio.to_thread` with no limiter
- JVM and .NET: `.block()` or JDBC on a Netty / WebFlux thread; `.Result`, `.Wait()` or `Thread.Sleep` in a handler; `async void`
- the largest realistic payload; K concurrent requests; the first (cold) call vs warm; the cost parameter turned up (hash rounds, compression level)

#### V29. Full buffering of large payloads — heap growth (RSS high-water)
- a payload 10× the typical size; the export route building a whole array; a slow consumer (backpressure ignored); a body or stream never consumed

#### V30. Client, agent or pool built per call — socket count
- N sequential and N concurrent calls; the error path (a client built in `catch`); a retry path; a pool per tenant built per request

#### V31. Compile, construct or format per call — allocations per operation, else the timing protocol
- regex, schema validator, template, serializer or formatter config built per call; the cold first call vs warm

#### V32. Memory growth — heap growth / structural count
- N **distinct** keys, not one key repeated; a module-level map keyed by id; memoisation on unbounded arguments
- a listener per request; an interval never cleared; a closure capturing the request; a `ThreadLocal` in a pool; a leaked goroutine; a promise chain that never settles
- a worker loop over batches with one unit of work (no `clear()` / `fork()`)

#### V33. Cache correctness — cross-tenant denial / write-then-read / call count
- the key across tenant A and B, user, role or permission, locale and currency; `public` caching on an authenticated response; a missing `Vary`
- no TTL; a TTL with no size bound; identical TTLs on keys written together; invalidation on every write path (update, delete, bulk, admin, import)
- K concurrent misses on a hot key → exactly 1 origin call; hot-key expiry; the cache down → the request still served within budget

#### V34. Outbound timeout — timeout firing
- connect, TLS handshake, DNS, response headers; idle between chunks (a slow drip) vs a **total** deadline including the body
- pool acquire; a retry loop's total budget; a Redis command; a queue handler's deadline
- retries multiplying the total time past the caller's own budget
- each fails within deadline + margin, and sockets, handles and pool slots return to baseline

#### V35. Accidental complexity — time ratio at N vs 10N
- `includes` / `indexOf` / `find` inside a loop; nested loops over two inputs; `remove` / `pop(0)` in a loop; a sort inside a loop; string `+=` in a loop; a repeated `filter().length`
- the ratio is about 10× per decade after the fix and about 100× before (quadratic); owned by the algorithms pack when it is installed

#### V36. Session or auth state in one process — two replicas
- the session store; flash messages and the CSRF token; an OAuth `state` or PKCE verifier held in memory; a WebSocket's auth context
- a per-replica signing secret (generated at boot); a key ring that is not persisted (.NET DataProtection)
- pass: log in through A, then 10 authenticated calls round-robin give 0 × 401; the OAuth round trip completes; both again after `kill -9` of the replica that served the login

#### V37. Process-local state used as truth — two replicas
- an eviction that clears only the local copy; read-your-writes; an authorization cache; a per-replica feature flag; a module map keyed by user or tenant
- an embedded SQLite file; an id counter in a module variable; "instance 0" or "primary" work gated on a process index
- pass: write through A, read through B within the TTL, and the value is fresh; ids stay unique across two pods; primary-only work runs exactly once

#### V38. Limiter, quota, dedupe set or lock held per replica — two replicas
- an inbound per-IP or per-user limit; a login lockout; an OTP or SMS cap; an outbound third-party quota; a per-tenant plan quota; an in-flight limit
- check-then-insert; a read-modify-write counter; a "send once" flag; a lease with no fencing token; a file lock used as leader election
- pass: a 10/min limit and 30 requests across two replicas accept ≤ 10 (plus the stated tolerance); a provider mock sees ≤ its quota; with the lease holder stopped (`SIGSTOP`) past its TTL, no second write is accepted

#### V39. Local filesystem for uploads or generated files — two replicas
- uploads; exports and PDFs served later; thumbnails; temp files shared between requests; local logs used as data; an on-disk queue
- pass: upload through A, then 10 GETs round-robin give 0 × 404; again after the pod is recreated

#### V40. Once-per-fleet work run per replica — two or three replicas
- a scheduler decorator; a module-level interval; a scheduler started at boot; an embedded beat; a host crontab; an overlapping Kubernetes CronJob; a DST double-fire; a missed-tick catch-up storm
- a migration in the entrypoint; ORM auto-sync; seeders, index or bucket bootstrap at boot
- pass: the schedule overridden to every 10 s, 5 ticks give exactly 5 executions; `kill -9` of the holder mid-run, and the next tick runs once; 3 simultaneous cold starts on an empty database give 0 crashes and the schema of a single run

#### V41. Broadcast that reaches one replica — two replicas
- Socket.IO rooms; a raw WebSocket broadcast; SSE; GraphQL subscriptions; an in-process event emitter feeding clients; presence maps
- pass: a client connected to A receives an event triggered through B within 2 s; presence counts read the same from A and B

#### V42. Durable work held in process memory — kill -9
- a `setTimeout` retry; a fire-and-forget email or webhook; an in-memory job array; a framework background task; an in-memory metrics buffer
- pass: enqueue 100, `kill -9` the process after 1 s, restart, and 100 complete — or the loss is an accepted, written decision

#### V43. Worker concurrency, prefetch, partitions and the scaling signal — queue age at a fixed arrival rate
- concurrency; prefetch or QoS; batch size; concurrency × replicas × connections per job against the database pool
- partitions against consumers; a constant FIFO group key; slow and fast job classes on one queue; a CPU-based autoscaler on an I/O-bound consumer; warm-up lag
- pass: the arithmetic holds with every term cited; oldest-message age flat at a fixed λ; a fast job's wait unchanged by 10 slow ones

#### V44. Redelivered jobs — redelivery
- visibility timeout against a delayed (ETA) task; lock duration; `max.poll.interval.ms`; an ack deadline
- no dead-letter queue; a whole batch retried for one bad message; at-least-once delivery with no dedupe key on a side effect
- pass: the three probes of § Redelivery

#### V45. Inbound server timeouts and limits — server limits
- header read (a slow-header client); body read; response write; keep-alive against the load balancer's idle timeout; `headersTimeout` above `keepAliveTimeout`
- body, multipart and header size limits per route; a WebSocket idle timeout
- pass: 0 × 5xx through an idle-gap soak; the slow client is cut off at the timeout; the oversized body gets 413

#### V46. No admission control or load shedding — admission control
- an executor with an unbounded queue; a queue or channel with no maximum; one connection pool shared by every downstream (one slow dependency starves the rest)
- every tenant's job scheduled at the same minute; reconnect loops with no jitter
- pass: cap + K submitted with the workers blocked, and K are refused fast; per-second load around a scheduled minute stays near the steady rate

#### V47. Health probe on a shared dependency — probe independence
- liveness that queries the database, pings Redis or calls a downstream; readiness on a shared dependency with no degraded mode written down; a slow boot with no startup probe
- pass: each dependency stopped in turn, liveness still returns 200; no pod restarts while the database is down for 60 s

## Frontend

The core rule holds in the browser (§ The core rule: existence by invariant, cost by statistics).
**Existence** is a run-invariant check: brotli bytes per route from a production build, a
Lighthouse audit that fails on the median of five runs, a trace insight, a render count, a yield
count, a heap-leak cluster, a render-blocking list, a layout-shift observer, a build-output
grep. **Cost** is Lighthouse medians under the noise rules (lab) and field
p75 (truth). **INP is field-only**: lab INP and Total Blocking Time are proxies. Every variant runs
on **mobile** (Lighthouse's default throttling: 4× CPU, slow 4G) **and desktop**, against a
production build (`vite preview`, `next start`, the deployed site) — never a dev server.

### Oracle taxonomy (frontend)

| Oracle | Asserts | Classes |
|---|---|---|
| **Bytes per route** | Brotli bytes per route are equal across two builds of one commit; base → head is an exact delta under the budget | V48, V150 |
| **Lighthouse median** | A Lighthouse audit id (the `*-insight` id when the version has it) passes on the median of 5 runs, mobile and desktop | V48–V51, V147, V149 |
| **Trace insight** | A DevTools performance insight no longer names the element, request or script | V49–V51 |
| **Field attribution** | The web-vitals attribution build no longer attributes the metric to the element or sub-part | V49–V51 |
| **Render count** | A subtree's commits are unchanged by an unrelated update | V52 |
| **Yield count** | A chunked handler yields at least once per chunk | V51 |
| **Heap leak (memlab)** | An action repeated and reverted leaves no leak cluster; retained size stays flat | V53 |
| **Render-blocking list** | After load, `performance.getEntriesByType('resource')` has no entry with `renderBlockingStatus === 'blocking'` for the candidate URL (Chromium) | V147 |
| **Third-party ablation** | Aborting the vendor host moves the 5-run median LCP or TBT outside the measured band; LoAF `scripts[].sourceURL` grouped by host names it | V148 |
| **Layout-shift observer** | No `layout-shift` entry (excluding `hadRecentInput`) of 0.01 or more has the candidate's node in `sources`, and session-window CLS ≤ 0.1, across load, consent accept/reject and a two-viewport scroll | V149, V50 |
| **Build-output grep** | A dev-only marker or transpiler helper is absent from the production build output (deterministic, n = 1) | V150, V151 |

### Bytes per route

Build for production twice on the same commit; the bytes must match exactly, or find the
non-deterministic input before trusting any delta. Base and head on the same lockfile give an
exact delta with no noise band. Vite (manifest at `.vite/manifest.json` from Vite 5; run in the
app's directory, `dist` is the default `outDir`) — the entry closure, then what each lazy route adds:

```bash
npx vite build --manifest >/dev/null && node -e '
const fs=require("fs"),z=require("zlib"),p=require("path"),d=process.argv[1],m=JSON.parse(fs.readFileSync(p.join(d,".vite/manifest.json")));
const br=f=>z.brotliCompressSync(fs.readFileSync(p.join(d,f))).length, kb=n=>(n/1024).toFixed(1).padStart(8)+" KB br";
const walk=(k,s)=>{if(s.has(k))return 0;s.add(k);const c=m[k];return br(c.file)+(c.css||[]).reduce((a,f)=>a+br(f),0)+(c.imports||[]).reduce((a,i)=>a+walk(i,s),0)};
for(const[k,c]of Object.entries(m))if(c.isEntry){const E=new Set;console.log(kb(walk(k,E))+"  entry  "+k);
  for(const[r,rc]of Object.entries(m))if(rc.isDynamicEntry)console.log(kb(walk(r,new Set(E)))+"  +route "+r)}' dist
```

Next.js 16.1+: `npx next experimental-analyze --output` (writes `.next/diagnostics/analyze`;
webpack builds: `ANALYZE=true` with `@next/bundle-analyzer`). Any bundler: `size-limit` (brotli by
default) with one entry per route chunk glob, `npx size-limit --json`. Label the number
`measured (brotli, <tool@version>, <sha>)`; raw or "stat" sizes are not what users download.

### Lighthouse median

`lighthouse-ci` (frontend pack) on the production build: `numberOfRuns: 5`, assertions with
`aggregationMethod: "median-run"`, mobile and desktop. **Read the Lighthouse version before choosing
an id.** `@lhci/cli` 0.15.1 (still the latest release) bundles Lighthouse 12.6.1, where both the
Lighthouse 12 audit ids and the `*-insight` audits exist. Lighthouse 13 (13.5.0, 2026-09-18) removed
`render-blocking-resources`, `third-party-summary`, `third-party-facades`, `legacy-javascript`,
`lcp-lazy-loaded`, `largest-contentful-paint-element`, `duplicated-javascript`, `dom-size` and
`font-display`, so a standalone `npx lighthouse` 13 run has only the insight ids. Assert on the
insight id when the version has both (it survives the upgrade), and print the version and the id
beside the result.

| Area | Lighthouse 12 id | Lighthouse 13 id (also present in 12.6.1) |
|---|---|---|
| Render-blocking requests | `render-blocking-resources` | `render-blocking-insight` |
| Third parties | `third-party-summary` | `third-parties-insight` |
| Legacy JavaScript | `legacy-javascript` | `legacy-javascript-insight` |
| Duplicated JavaScript | `duplicated-javascript` | `duplicated-javascript-insight` |
| LCP request discovery | `lcp-lazy-loaded`, `prioritize-lcp-image` | `lcp-discovery-insight` |
| Layout-shift culprits | `layout-shifts` (kept in 13) | `cls-culprits-insight` |
| DOM size · font display | `dom-size` · `font-display` | `dom-size-insight` · `font-display-insight` |
| Third-party facades | `third-party-facades` | no named successor |
| Metrics | `largest-contentful-paint`, `total-blocking-time`, `cumulative-layout-shift` | unchanged |

The pairing in each row is by area: that an insight covers exactly what the removed audit covered is
not verified. `largest-contentful-paint-element` names the element and carries no pass/fail, so it is
not asserted: read the element from § Trace insight or `lcp-breakdown-insight` (`lcp-phases-insight`
in Lighthouse 12).

```json
{ "ci": { "collect": { "numberOfRuns": 5, "startServerCommand": "npm run start", "url": ["http://localhost:3000/"] },
  "assert": { "assertions": {
    "lcp-discovery-insight": ["error", { "minScore": 1 }],
    "largest-contentful-paint": ["error", { "maxNumericValue": "<the route's budget, ms>", "aggregationMethod": "median-run" }] } } } }
```

The placeholder becomes a number from `ai/runtime/perf-budgets.md`; with no budget, declaring one is
the first finding.

Measure the band before reading a delta: three re-runs of the unchanged build, each a 5-run median;
a delta inside the spread is `NO-CHANGE`, and base and head are interleaved on one machine (§ Noise
band rules for timing oracles). One Lighthouse run (±5–10 points) is not evidence.

### Trace insight

A DevTools trace of the interaction or the load, or Chrome DevTools MCP:
`performance_start_trace { reload: true, autoStop: true }`, then
`performance_analyze_insight` with `LCPBreakdown`, `LCPDiscovery`, `RenderBlocking`,
`INPBreakdown`, `CLSCulprits`, `ForcedReflow`, `ThirdParties` or `DuplicatedJavaScript`. One trace
is one lab sample: it localises a defect and shows that the fix removed it, and it never measures
cost. Throttle to the mobile profile (`emulate { cpuThrottlingRate: 4 }`).

### Field attribution

The `web-vitals` attribution build (`import { onLCP, onINP, onCLS } from 'web-vitals/attribution'`)
names the cause: LCP `timeToFirstByte`, `resourceLoadDelay`, `resourceLoadDuration`,
`elementRenderDelay`, `target`; INP `inputDelay`, `processingDuration`, `presentationDelay`,
`interactionTarget`, `longAnimationFrameEntries`; CLS `largestShiftTarget`, `largestShiftValue`,
`loadState`. A field "after" from CrUX needs 28 days of post-deploy traffic; the project's own RUM
reads sooner. **Soft navigations:** Chrome 151 (2026-07-28) shipped the `soft-navigation` and
`interaction-contentful-paint` entry types, and `web-vitals` reports per-route vitals with
`reportSoftNavs: true` in Chromium 151+ only; CrUX has published no timeframe for including them
(web.dev, *How SPA architectures affect Core Web Vitals*, updated 2026-08-11). Elsewhere, mark
route boundaries with `performance.mark` around the router's start and end events.

### Render count

Wrap the subtree in `<Profiler id="list" onRender={() => commits++}>` (or count a child's
`vi.fn()` renders), make an update the subtree does not depend on N times, and assert the commit
count is unchanged. It fails first on an unstable context value or a whole-store selector. With
React Compiler on, confirm the component is compiled (no `'use no memo'`) before writing the test.
Timing under the profiler needs the `react-dom/profiling` build.

### Yield count

Stub the yield helper (`yieldToMain`), run the handler over N = 10,000 items, and assert it
yielded at least `ceil(N / chunk)` times — 0 before the fix. Deterministic, no clock; pair it with
a LoAF check that `forcedStyleAndLayoutDuration` is 0 for the handler's script when the class is
layout thrash.

### Heap leak (memlab)

`npx memlab run --scenario leak.js` (memlab 2.0.5, MIT): the scenario exports `url`, `action` and
`back`; memlab repeats the action, reverts it and reports leak clusters, filtering detached DOM and
unmounted React Fibers by default. `memlab find-leaks --snapshot-dir <dir>` analyses saved
snapshots. Pass: no leak cluster for the action, and retained size flat across 10 cycles. On a
server, `memlab analyze unbound-object --snapshot-dir <dir>` reads three or more Node heap
snapshots of the same workload (§ Heap growth).

### Render-blocking list

Chromium, production build, after load:

```ts
const blocking = await page.evaluate(() => performance.getEntriesByType('resource')
  .filter((e: any) => e.renderBlockingStatus === 'blocking')
  .map((e: any) => ({ url: e.name, bytes: e.transferSize, end: Math.round(e.responseEnd) })));
// fails first: the candidate URL is listed; green: it is gone. Lab cost: LH 12 `render-blocking-resources`
// (maxLength: 0) / LH 13 `render-blocking-insight`; field: web-vitals onLCP attribution `elementRenderDelay`.
```

`renderBlockingStatus` exists in Chromium and is not Baseline (MDN, *PerformanceResourceTiming.renderBlockingStatus*,
fetched 2026-10-05): on another engine the list is empty, which proves nothing.

### Third-party ablation

Measure the band first (three re-runs of the unchanged build, each a 5-run median). Then interleave
5 runs with `await page.route(/googletagmanager|hotjar|intercom|…/, (r) => r.abort())` and 5 without,
on the mobile profile. A delta inside the band is `NO-CHANGE`. Localise with
`new PerformanceObserver((l) => …).observe({ type: 'long-animation-frame', buffered: true })`, grouping
each entry's `scripts[]` by the host of `sourceURL` and summing `duration` and
`forcedStyleAndLayoutDuration` (`PerformanceScriptTiming` is not Baseline either). Lab: LH 12
`third-party-summary` / LH 13 `third-parties-insight`.

### Layout-shift observer

```ts
await page.addInitScript(() => { (window as any).__ls = []; new PerformanceObserver((l) => { for (const e of l.getEntries() as any[])
  if (!e.hadRecentInput) (window as any).__ls.push({ v: e.value, t: e.startTime,
    src: e.sources.map((s: any) => ({ node: s.node?.outerHTML?.slice(0, 120), prev: s.previousRect.toJSON(), cur: s.currentRect.toJSON() })) }); })
  .observe({ type: 'layout-shift', buffered: true }); });
// load the route on a production build; accept, then (fresh context) reject consent with its own buttons;
// scroll two viewports; wait 5 s. CLS = the largest session window (gaps < 1 s, window ≤ 5 s) of summed values.
// Fails first: one shift ≥ 0.01 names the candidate node, or session CLS > 0.1. Field: web-vitals 6.2.3 onCLS
// attribution `largestShiftTarget`, `largestShiftValue`, `loadState`. Lab: `layout-shifts`, `cls-culprits-insight`.
```

### Build-output grep

Build with the project's production command; grep `dist`, `build`, `.next/static` or `.output/public`
(never the source) for the class's markers: React's development warning text, `[Vue warn]`,
`setupWorker`, `whyDidYouRender`, `react-scan`, `redux-logger`, `@faker-js`, RTK `devTools:!0`,
`sourceMappingURL=…map` (and `curl` the map: 200 = served); for legacy JS, `regeneratorRuntime`,
`_classCallCheck`, `core-js/modules/`, `_asyncToGenerator`, `@babel/runtime/helpers`, esbuild's
`__publicField(` / `__spreadValues(` / `__async(` per chunk. Present before the fix, absent after,
same build command. No noise band: one run decides.

### Class variants (frontend)

#### V48. Bundle bytes per route — bytes per route
- a static route import; a dynamic import made static by another import of the same module
- a heavy library in a shared layout; a heavy library in a `'use client'` file that could render on the server; dev-only code in the build output; one vendor chunk from `manualChunks`; a CSS-in-JS runtime
- barrel imports: a full-package named import, `* as`, a side-effectful internal barrel, icon packs, moment locales, `ns[key]`, re-export chains
- duplicates: semver-major twins, a hoisting failure, CJS and ESM twins, two copies of the UI framework

#### V49. LCP resource — Lighthouse median, trace insight, field attribution
- the element: `<img>`; `<picture>` / `srcset` (preload with `imagesrcset`); a CSS background; `<video poster>`; text blocked by a web font
- how it arrives: client-rendered; mounted behind a gate; the first carousel slide; a framework image component without its priority flag
- the viewport: a different LCP element on mobile and on desktop

#### V50. Layout shift — Lighthouse median, field attribution
- an unsized `<img>`; `fill` without a sized parent; embeds; ad slots; a banner inserted above content; a skeleton of the wrong height; a font swap; infinite scroll inserting above the viewport; `content-visibility` without an intrinsic size

#### V51. Interaction latency — yield count, trace insight, field attribution
- click, typing, submit, drag, an SPA route click, an interaction during hydration
- layout thrash: read and write in a loop, in a scroll or resize handler, a write then a read in one `requestAnimationFrame`, a library that forces reflow

#### V52. Re-render waste (React) — render count
- context value identity; prop identity into a memoised child; state held too high; a whole-store selector; a component defined inside a component; an index key on a reordered list; `setState` in an effect; an expensive list not deferred

#### V53. SPA memory growth across navigations — heap leak (memlab)
- `window` / `document` listeners; intervals; RxJS, store, WebSocket or EventSource subscriptions; Resize, Intersection or Mutation observers; detached DOM; module-level caches; a third-party widget initialised again on every route

#### V147. Render-blocking head — render-blocking list, Lighthouse median
- a sync `<script src>` in `index.html`, `_document`, `app/layout`, `root.tsx`, `src/app.html`, Angular `index.html`, a Nuxt `app.head.script` entry
- a cross-origin stylesheet in either attribute order; a CSS `@import` of a URL; a raw-served `@import` chain; a first-party `beforeInteractive` script; a tag a build plugin or edge rule adds to the emitted shell

#### V148. Third party on the critical path — third-party ablation
- a tag manager in the head; a pixel or tag manager injected from a mount effect; a sync consent stub; a leftover anti-flicker (`async-hide`) snippet
- `next/script` `beforeInteractive` with a vendor src; `@nuxt/scripts` `useScript` with no trigger; a chat widget loaded eagerly instead of behind a facade

#### V149. Late-inserted layout shift — layout-shift observer (extends V50)
- a data-driven warning band in a `sticky` stack; a consent bar in flow; `Suspense fallback={null}` above the fold; `<ClientOnly>` with no sized `#fallback`
- `dynamic(…, { ssr: false })` with no `loading`; Angular `@defer` with no `@placeholder`; an unsized iframe or ad slot; a skeleton of the wrong height

#### V150. Legacy JS and polyfills — build-output grep, bytes per route
- an explicit `build.target` below the bundler default; a browserslist with `ie 11` / `op_mini`; `core-js` entry imports; `polyfill.io` (also a security row); a `tsconfig` target that only matters when `tsc` emits

#### V151. Dev-only code in the build — build-output grep
- a development React or Vue build; MSW registered (`setupWorker` in a chunk); faker data; render debuggers; redux-logger; RTK `devTools` defaulting to true; served source maps; a mock arm chosen by a runtime flag (both arms ship)

## Testing

A testing claim says a suite would stay green while something is wrong. Its proof makes the suite
answer that question: break the code under test and watch the test, flip the test's own expected
value, list what the runner collects, turn the mask off, perturb what should not matter. Every
oracle here is deterministic except the repeat-run bound. Every probe runs on a scratch branch or
worktree, is never committed, and its restore is proven with `git diff --exit-code` on the probed
files. The claim sentences, gate readings and version precedents are in
[`precedents/testing.md`](precedents/testing.md). Users: `assertion-strength-scan`,
`suite-execution-scan`, `flake-source-scan`, `test-double-scan`, `coverage-gap`, `mutation-probe`,
`/test-audit`, `/test-fix`, `/flaky-test-hunt` and `@test-reviewer`.

### Oracle taxonomy (testing)

| Oracle | Asserts | Classes |
|---|---|---|
| **Break the SUT** | The function the test claims, made to return a wrong value of the right type (a constant, `0`, `''`, `[]`, the wrong enum member, an off-by-one), leaves the test green before the fix and turns it red after. Never a `throw`: a throwing body fails even an existence-only test | V54–V56, V59, V60, V71, V73 |
| **Assertion flip** | The test's own expected value, changed in a scratch copy, turns it red; green means the assertion never runs, is not awaited, or is swallowed | V57–V59 |
| **Mutant kill** | A tool mutant on the line survives before the fix and is killed after, with its sibling operators on that line | V66 |
| **Strictness switch** | A runner flag that refuses the class fails the run before the fix and passes after | V54, V57, V61 |
| **Collection count** | The test id is absent from the runner's collected list before the fix and present after; a base-vs-head list that shrinks with no deleted test file is a weakened gate | V62 |
| **CI canary** | A deliberately failing test on a throwaway branch turns the CI job red; green means the job masks failure | V63 |
| **Coverage inventory** | The source file is present in the coverage report, and the lines a pragma or exclusion hid show their hit counts | V64 |
| **Retry unmask** | The retried test, run N times with retries off, fails k of N; the runner's report marks it flaky | V65 |
| **Perturbation** | Changing what should not matter — order, `TZ`, the date, the seed, the network, workers, CPU load — fails the test before the fix and not after | V67–V69 |
| **Repeat-run bound** | No failure in N runs states `p < 3/N` at 95%, never "not flaky" | V65, V67–V69 fallback |
| **Interface conformance** | The double typed or spec'd against the real interface fails where it drifted | V70 |
| **Real-engine parity** | The same test on the production engine (Testcontainers) fails where the fake passed | V70 |
| **Seeded violation** | The guard, predicate or error branch removed on a scratch branch leaves the suite green before the fix; the new negative test turns it red | V71 |
| **Env parity** | The production path with the test flag off behaves differently from the path the tests exercise | V72 |
| **Old test on new code** | The base version of an edited test fails against the head source where the edited test passes: the oracle was moved to fit the code | V72; every fix's self-check |

### Break the SUT

Edit the one function the test claims so it returns a wrong value of the right type, run only the
tests that claim it, restore:

```bash
cp src/pricing/total.ts "${TMPDIR:-/tmp}/probe.bak"       # then edit: `return total;` → `return 0;` (never `throw`)
npx jest src/pricing -t 'totals a basket'                   # pytest path::test -q · go test -run '^TestTotal$' ./pricing
                                                            # mvn -Dtest=TotalTest#basket test · rspec spec/x_spec.rb:42 · phpunit --filter basket
                                                            # dotnet test --filter FullyQualifiedName~Basket · cargo test basket
cp "${TMPDIR:-/tmp}/probe.bak" src/pricing/total.ts && git diff --exit-code -- src/pricing/total.ts
```

Green under the probe proves the claim. Run three probes per class variant — a constant, an empty
or zero value, an off-by-one or the wrong member — and a fix passes only when all three go red. For
an interaction-only test the probe changes what the SUT returns or persists and keeps the call; for
a mock echo it changes the transformation. Mutation tools automate the same probe (`mutation-probe`).

### Assertion flip

```bash
cp test/orders.spec.ts "${TMPDIR:-/tmp}/flip.bak"        # then change the expected literal under review: toBe(200) → toBe(299)
npx jest test/orders.spec.ts -t 'refunds the order'     # must FAIL; a pass means the assertion never ran
cp "${TMPDIR:-/tmp}/flip.bak" test/orders.spec.ts && git diff --exit-code -- test/orders.spec.ts
```

The cheapest oracle for an assertion that is unreached (a `catch` the code never enters, a
callback never called, a loop over an empty collection), un-awaited, or swallowed. Run the flip
with the file set and flags the CI job uses: Jest 30 masks a floating failure only beside another
file or under `--forceExit` ([`precedents/testing.md`](precedents/testing.md) § 2).

### Strictness switches

| Runner | Switch | Refuses |
|---|---|---|
| Jest / Vitest | a setup file (`setupFilesAfterEnv` / `setupFiles`) with `beforeEach(() => { expect.hasAssertions(); })` | assertion-free cases and never-called callbacks — **not** a try/catch-swallowed `expect`, which still counts as a call (Jest 30.5.2, Vitest 5.0.3) |
| pytest | `-W error::pytest.PytestUnraisableExceptionWarning -W error::pytest.PytestCollectionWarning -o xfail_strict=true` | `assert coro()` and un-awaited calls; `Test*` classes with `__init__`; a passing non-strict `xfail` |
| pytest helpers | `PYTHONOPTIMIZE=1 pytest` | assert-based helpers outside test modules, which pass when stripped |
| PHPUnit | `--fail-on-risky --fail-on-empty-test-suite` | assertion-free tests; an empty run |
| Mocha / Playwright | `--forbid-only --forbid-pending` · `forbidOnly: !!process.env.CI` · `--fail-on-flaky-tests` | focus; pending; retried flakes |
| Lint on test files | `npx eslint --no-warn-ignored --max-warnings 0 "**/*.{test,spec}.{js,jsx,ts,tsx}"` · `ruff check --select PT,B011,B015,B017,F631,PGH005 <test files>` | WARN-level rules that otherwise read clean |

A switch is the proof when the run fails with it and passes without it; it is also the guard the
fix leaves behind (V61).

### Collection count

```bash
rg --files -g '*.{test,spec}.{js,jsx,ts,tsx,mjs,cjs}' -g '**/__tests__/**' -g '!**/node_modules/**' . | sed 's#^\./##' | sort > looks.txt
npx jest --listTests --config <cfg> | sed "s#^$PWD/##" | sort > collected.txt   # npx vitest list --filesOnly
#   pytest --collect-only -q | sed -n '/::/p' | cut -d: -f1 | sort -u · go test -list '.*' ./... · rspec --dry-run --format json
#   phpunit --list-tests · dotnet test --list-tests · cargo test -- --list
comm -23 looks.txt collected.txt                                                 # looks like a test, never collected
```

Widen `looks.txt` to every pattern any runner config names, and union the collected lists of every
config and project before the `comm`. A suite some config collects but no CI job invokes is the
same class one level up: list the test scripts and configs, then the CI steps that call them.
Base-vs-head: the same list on the merge base and on head; a shorter list with no deleted test file
is a weakened gate. The Jest, Vitest and pytest commands were run on 2026-10-05; the Go, RSpec,
PHPUnit, .NET and Rust ones are from the research catalog — confirm their output on the repo's
toolchain. A fix passes when the test is listed **and** fails under break the SUT.

### CI canary

On a throwaway branch, add one failing test (`it('canary', () => expect(1).toBe(2))`,
`def test_canary(): assert False`, `t.Fatal("canary")`) in a file and directory the job's glob
collects, push, and read the job's conclusion **and its log** — a masked job prints the failure and
exits 0. Red: the job blocks. Green: masked (`continue-on-error`, `|| true`, a pipe without
`pipefail`, a path filter, a skipped job). Delete the branch afterwards. Whether the job is a
required check lives in the host (`gh api repos/<owner>/<repo>/branches/<branch>/protection` with
admin rights); without that, the required-check half stays Unconfirmed. Where pushing is not
allowed, the masking line and the job it sits in pass gate 6 as a static fact, and the canary is
the settling probe.

### Coverage inventory

```bash
comm -23 <(rg --files -g '*.{ts,tsx,js}' -g '!**/*.{test,spec}.*' src | sort) \
         <(grep '^SF:' coverage/lcov.info | cut -c4- | sed "s#^$PWD/##" | sort)       # shipped files missing from the report
```

diff-cover skips a changed file that has no data in the report, so diff coverage reads 100% for a
file no test imports, and Vitest and c8 include only imported files unless `coverage.include` is set
(diff-cover 10.6.0 source, Vitest 5.0.3). For a pragma or an exclusion, remove it in a scratch copy,
re-run coverage and show the hit counts it hid; mutmut's `mutate_only_covered_lines` also skips
`# pragma: no cover` lines, so one pragma takes a line out of both oracles.

### Retry unmask

Run the retried test with retries off, N times, and read the flaky markers the runner writes:
`npx playwright test <f> --repeat-each=50 --retries=0 --fail-on-flaky-tests` ·
`npx vitest run <f> --repeats=50 --retry=0` · `jest.retryTimes` removed in a scratch copy, then the
file run N times · `pytest -p no:rerunfailures --count=50 <id>` (pytest-repeat) ·
`mvn -Dtest=<T> -Dsurefire.rerunFailingTestsCount=0 test` in a loop, or
`-Dsurefire.failOnFlakeCount=1` · Gradle `failOnPassedAfterRetry = true` ·
`cargo nextest run --retries 0` or `--flaky-result fail`. Reports: Surefire `<flakyFailure>` /
`<flakyError>`, Playwright JSON `"status": "flaky"`, nextest `TRY n PASS`.

### Perturbation and the repeat-run bound

| Perturb | Command |
|---|---|
| Order | `vitest run --sequence.shuffle --sequence.seed=N` · `jest --randomize --seed=N` (within a file only) · pytest-randomly `-p randomly --randomly-seed=N` · `go test -shuffle=on -count=1` · JUnit `-Djunit.jupiter.testmethod.order.default='org.junit.jupiter.api.MethodOrderer$Random'` · `rspec --order rand:N`, `--seed N --bisect` · the victim alone vs in the suite |
| Clock and zone | `TZ=Pacific/Kiritimati` (UTC+14) · `TZ=America/St_Johns` (half hour) · `TZ=Pacific/Chatham` (+12:45) · `TZ=America/Santiago` (2026-09-06 00:00 does not exist) · `faketime '2028-02-29 23:59:59' <cmd>` (libfaketime 0.9.13; not for Go — inject a clock) |
| Locale | `LANG=tr_TR.UTF-8 LC_ALL=tr_TR.UTF-8` |
| Network | `pytest --disable-socket --allow-hosts=127.0.0.1,::1` (pytest-socket) · `unshare -rn sh -c 'ip link set lo up; <cmd>'` · `docker run --network none` |
| Parallelism and load | `pytest -n auto` · `jest --maxWorkers=100%` · `go test -p 8 -race -count=20` · `stress-ng --cpu $(nproc)` beside the run |
| Leaks | `jest --detectOpenHandles` · `vitest --reporter=hanging-process` · goleak `VerifyTestMain` · `python -X dev -W error::ResourceWarning -m pytest` |

A perturbation that fails every time (a zone, a date, network off) is deterministic: one red run
before the fix and one green run after prove it. Otherwise use the bound: detecting a failure rate
p with confidence c needs N = ln(1−c)/ln(1−p) runs — 299 for p = 1% at 95%. A clean run of N
reports `p < 3/N at 95%`; a fix is verified with N from the observed rate (p ≈ 5% → N = 59; never
observed → N = 300). `/flaky-test-hunt` owns the N-run loop.

### Interface conformance, real-engine parity, env parity

- **Interface conformance:** type the double against the real interface (`jest.Mocked<Repo>`, `vi.mocked`, `create_autospec(Repo, spec_set=True)`, `MagicMock(spec=Repo)`, generated mockery or uber-go/mock mocks, Mockito strict stubs, `MockBehavior.Strict`), then rename a method on the real interface: the spec'd double fails, the loose one stays green. The type error or `AttributeError` at the cited line is the proof.
- **Real-engine parity:** run the same test on the fake and on Testcontainers pinned to the production major. The duplicate key, over-length value, FK or `ON CONFLICT` case that passes on the fake and fails on the real engine is the proof; § Data's constraint and concurrency oracles take it from there.
- **Env parity:** run the production path with the test flag off (`NODE_ENV=production`, `TESTING=False`) on the same input; an outcome that differs from the tested path proves a seam no test covers.

### Seeded violation

Remove the guard, predicate or error branch the claim names on a scratch branch — the auth guard on
a route, the tenant predicate in a query, the `catch` that maps an error — run the whole suite, and
restore. A green suite proves nothing pins it (QG-3). The fix's new negative test (wrong user,
wrong role, other tenant, expired token; the injected dependency failure on an error path) must go
red under the same removal. It is `tdd-orchestrator`'s RED-UNOBSERVABLE mechanic applied to a suite
that already exists.

### Old test on new code, and the anti-cheat rule

```bash
B=$(git merge-base HEAD origin/main)
git show "$B":test/orders.spec.ts > test/orders.base.spec.ts && npx jest test/orders.base.spec.ts; rm test/orders.base.spec.ts
```

Red while the edited test is green means the change moved the oracle to fit the code.

**A fix to a test finding fixes the test or the gate — never by weakening an oracle.** A change to
an existing expected value, matcher, skip, snapshot, threshold, ignore glob or retry setting carries
a spec citation for each change and passes old-test-on-new-code. Adding a skip, `.only`, `xfail` or
quarantine, net-removing assertion lines, rewriting a snapshot wholesale, raising a timeout, adding
a sleep or a retry, mocking the SUT, or special-casing production code for a test input
(`NODE_ENV === 'test'`, a literal from a test, an equality override) is not a fix. When the
repo-baseline is installed, `.claude/scripts/test-integrity.py` and `.claude/scripts/oracle-check.py`
run on the fix's own diff and must report nothing. When the spec and the test disagree, stop and
escalate: in ImpossibleBench (arXiv 2510.20270, 2025-10-23) an explicit escalate exit cut GPT-5's
test-tampering on impossible tasks from 54% to 9%.

### Evidence block (testing)

```text
claim:     <strength | presence | determinism> — the sentence from precedents/testing.md
oracle:    <name>: <exact command>; before: <green | absent | k/N>; after: <red | collected | 0/N>
probe:     <the scratch edit or switch at file:line>; restore: git diff --exit-code → clean
runner:    <runner@version from the lockfile>, <config file>, CI job <name> (CI, TZ, workers, shard)
variants:  <V-number>: <k of n variant probes red after the fix>
verdict:   proven (oracle) | Unconfirmed (probe: <exact command>) | Refuted (gate <n>: <reason>)
```

### Class variants (testing)

#### V54. Absent or weak oracle — break the SUT, strictness switch
- an empty body; setup only; a log only; a call only; an assertion inside a helper that is not an assertion function; an assertion only in `afterEach`
- a weak matcher as the sole check: `toBeDefined`, `toBeTruthy`, `not.toBeNull`, `not.toBeUndefined`, `not.toThrow`, `toBeInstanceOf` only, a length greater than 0 only, `assert x`, `assert x is not None`, `assertIsNotNone`, `assertTrue(x)`, `assert.NotNil` / `NotEmpty`, RSpec `to be` / `be_present`, `assertNotNull` / `isNotNull`, `Assert.NotNull`, `assert!(r.is_ok())`; a 2xx-only status on an endpoint whose body is the behaviour
- probes: a constant of the right type, an empty or zero value, an off-by-one, the wrong enum member — all red after the fix

#### V55. Interaction-only assertion — break the SUT
- a call count with no arguments pinned (`toHaveBeenCalled()`, `toHaveBeenCalledTimes(n)`, `assert_called()`, `verify(mock).save(any())`, gomock `Any()`) where the SUT returns or persists a checkable value
- probes: the SUT returns or persists a wrong value but still makes the call; the SUT passes a wrong argument to the collaborator

#### V56. Tautology, mirror and echo — break the SUT
- expected = SUT(same input); expected computed with a copy of the SUT's algorithm; `assertEqual(x, x)`; an `assert (cond, "msg")` tuple; `assertTrue(x, y)` where `y` is the message; a literal compared with a literal; a mocked return echoed back through a SUT that transforms it
- the fix uses literals derived without the implementation: the spec, a worked example, an independent reference

#### V57. Unreached or un-awaited assertion — assertion flip, strictness switch
- un-awaited `.resolves` / `.rejects`, Playwright `expect(locator)`, `expect.poll`, `test.step`, `fc.asyncProperty`, user-event v14 calls, `findBy*` / `waitFor`; `assert coro()`; an un-awaited SUT call then an assertion; an `async void` test (xUnit1048 / 1049, MSTEST0040); `Assert.ThrowsAsync` without `await`; a Kotlin coroutine test without `runTest`
- an `expect` only inside a `catch` the code never enters, an event or `then` callback never called, an `if` / `switch` / ternary choosing the matcher, or a loop over a computed and possibly empty collection; Python `assert all([])`
- assert-based Python helpers under `PYTHONOPTIMIZE`; JUnit 4 `@Test(expected = …)`, which passes when any statement throws; Go `t.Fatal` or `require` from a goroutine
- the verdict depends on the installed runner major ([`precedents/testing.md`](precedents/testing.md) § 1–3)

#### V58. Swallowed failure — assertion flip
- `try { … expect … } catch {}`; `catch (Throwable)` / `catch (AssertionError)`; `.catch(() => {})` on a chain holding an `expect`; `except: pass` or `except Exception: pass` around an `assert`; `with suppress(AssertionError)`; Go `recover()` in a test; `Mock(unsafe=True)` turning off the mock typo guard

#### V59. Assertion-API misuse — assertion flip, break the SUT
- AssertJ or Truth `assertThat(x);` with no terminal call; `verify(mock)`; `verify(mock.m())`; `when(…)` without `then…`; `m.assert_called_once` without parentheses; RSpec `expect(x)` without a matcher; a bare `#[should_panic]`; `raises(Exception)` or a bare `toThrow()` where a type or message is the contract; a multi-statement `pytest.raises` block; Go `t.Error` followed by a nil dereference

#### V60. Snapshot as the sole or rewritten oracle — break the SUT with the snapshot kept
- `toMatchSnapshot` / `toMatchInlineSnapshot` / `toMatchFileSnapshot`, syrupy, insta, go-snaps, Verify or ApprovalTests as the only assertion on new logic; a whole rendered tree; unscrubbed ids and timestamps
- snapshot writing wired into scripts or CI: `-u`, `--updateSnapshot`, `--update-snapshots`, `--snapshot-update`, `cargo insta accept`, `INSTA_UPDATE=always`
- proof: revert the SUT change and keep the new snapshot — the old one must fail meaningfully; two clean runs produce no snapshot diff

#### V61. Focused, skipped or non-strict — static fact, strictness switch
- `.only`, `fit`, `fdescribe`, `focus: true`, `:focus`, a hard-coded `--grep` / `-t` / `-k` / `-run` in the CI command
- `.skip`, `xit`, `xdescribe`, `@Disabled`, `@Ignore`, `[Fact(Skip = …)]`, `#[ignore]`, an unconditional `t.Skip()`, a module-level `pytestmark = pytest.mark.skip`, `markTestSkipped`; a non-strict `xfail`; a suite gated on a variable or capability the CI job never provides
- the fix also leaves the runtime guard (`forbidOnly`, `--forbid-only`, `xfail_strict`, an error-level lint rule in CI)

#### V62. Never collected, never run — collection count
- outside every config's glob, regex or roots; an ignore pattern; a name, visibility, signature, `static` or non-void method; JUnit 4 `@Test` under Jupiter without the vintage engine; `*IT` under Surefire only; a Mocha nested `it` or a non-recursive spec glob; a pytest class with `__init__`; a function or file outside `python_functions` / `python_files`; a build tag no job passes; a Rust file outside the `mod` tree; PHPUnit docblock `@test` on 12+; a non-public xUnit method; MSTest without `[TestClass]`
- a configured suite — a second config, a Playwright or Storybook project, a fuzz runner — that no CI job invokes
- proof: the collected list is complete **and** each re-collected test fails under break the SUT

#### V63. CI masking and gate weakening — CI canary, the gate at the old and the new value
- `continue-on-error`, `allow_failure`, `|| true`, `; exit 0`, a pipe without `pipefail`, `--passWithNoTests`, `-DskipTests`, `testFailureIgnore`, `ignoreFailures`, `--do-not-fail-on-*`, `failOnRisky="false"`, `-p no:warnings`, `--forceExit` on Jest, `PYTHONOPTIMIZE` in the test environment, a path filter or `if:` that skips the test job, shards that do not cover the matrix, a test job missing from the required checks
- in a diff: a threshold lowered or removed, ignore globs widened, `forbidOnly` or `xfail_strict` removed, retries added

#### V64. Coverage that hides code — coverage inventory
- `coveragePathIgnorePatterns`, `collectCoverageFrom` negations, `omit` / `exclude` reaching shipped source, `sonar.coverage.exclusions`, Codecov `informational: true`, `diff-cover --minimum-change`, a floor of 0, a coverage `include` left at imported files only
- pragmas on hand-written code: `istanbul` / `v8` / `c8 ignore`, `# pragma: no cover`, `:nocov:`, `@Generated` on non-generated code, `[ExcludeFromCodeCoverage]`, `#[coverage(off)]`, `@codeCoverageIgnore`, `coverage:ignore-*`, Stryker, mutmut and cargo-mutants skip markers
- a changed or new file absent from the report

#### V65. Retry masking — retry unmask
- config-level (`retries`, `retry`, `rerunFailingTestsCount`, test-retry `maxRetries`, nextest `retries`), marker-level (`jest.retryTimes`, `this.retries`, `@pytest.mark.flaky`, `@RetryingTest`, `[Retry]`, rspec-retry `retry:`), CI-level (`--reruns`, `gotestsum --rerun-fails`, a retry action around the test step)
- each without its flaky gate (`--fail-on-flaky-tests`, `failOnPassedAfterRetry = true`, `failOnFlakeCount ≥ 1`, `--flaky-result fail`), an owner or an expiry

#### V66. Surviving mutant or pseudo-tested method — mutant kill
- relational (`>` → `>=` / `<` / `<=` / `==` / `!=`), a condition forced `true` or `false`, negation, `&&` ↔ `||`, ±1 and `+` ↔ `-`, the return value (null, 0, empty, default), statement and block removal; a method whose emptied or constant-returning body fails nothing (Descartes)
- the killing test also kills the non-equivalent siblings on the same line; an equivalent mutant is dismissed with a stated reason ([`precedents/testing.md`](precedents/testing.md) § 41)

#### V67. Order dependence and shared state — perturbation (order)
- module-level containers, non-final statics, singletons and caches; spies, `patch().start()` and fake timers not restored; env vars, system properties, default `TZ` and locale, cwd, `sys.path` and logger level mutated without restore; wide `beforeAll` or session fixtures returning mutable objects; a shared database row or sequence
- proof: three or more shuffle seeds, the victim alone vs in the suite, and the polluter → victim pair bisected

#### V68. Clock, zone and locale — perturbation (`TZ`, faked date, `LANG`)
- `today()`, `utcnow()`, `new Date()`, DB `NOW()` defaults in fixtures, JWT `exp`, cron, TTLs, ages on 29 February, month and year ends, a fixture date that expires, DST gaps, `toLocaleDateString`, Turkish-i casing — under every boundary zone and instant in § Perturbation

#### V69. Randomness, sleeps, leaks, network and shared resources — perturbation, repeat-run bound
- unseeded faker, random or UUID values that are asserted; fixed sleeps used as synchronisation (`setTimeout` promises, `time.sleep`, `waitForTimeout`, `cy.wait(<ms>)`); open handles, timers, goroutines, unclosed files; DNS, OAuth token fetches, SDK default endpoints, telemetry init; fixed ports, fixed temp paths and shared database names under parallel workers; over-tight timing assertions

#### V70. Test doubles that lie — interface conformance, real-engine parity
- the SUT mocked (a `jest.mock` of the test's own module, a `patch` of the function under test, a stubbed spy of the SUT); loose doubles (`MagicMock()` without `spec`, `as any` doubles passed into the SUT, `RETURNS_DEEP_STUBS`, `mockk(relaxed = true)`, Moq loose, `mock.Anything`); mocks of what the project does not own (an ORM builder, an HTTP client's internals) instead of a port; frontend mocks (MSW, `page.route`, fixtures) not typed or validated from the API schema
- an emulated database (SQLite, H2, pg-mem, EF in-memory) for a production Postgres or MySQL; a repository mocked in an "integration" test; transaction-wrapped tests hiding commit-time hooks

#### V71. Missing negative and error-path tests — seeded violation
- authorization: another user, another tenant, no role, an expired or revoked token, on every route of the family (QG-3)
- error branches: each typed error and each mapped status asserted for type and external shape; the injected failure of each dependency the path calls
- boundaries: min − 1, min, max, max + 1, empty, null, non-ASCII

#### V72. Test seams and special-casing in production — env parity, old test on new code
- `if (process.env.NODE_ENV === 'test')`, `settings.TESTING`, `@VisibleForTesting` members called from production code, test helpers imported by shipped modules; an input literal from a test compared in production code; `__eq__` / `equals` / `[Symbol.toPrimitive]` returning a constant

#### V73. UI, end-to-end and property-based tests — break the SUT, markup mutation, injected violation
- three UI breaks (remove the element, change its text, delay the render past the timeout); five markup mutations for selectors (class rename, sibling reorder, wrapper added, text moved, attribute dropped); an overlay over a `force: true` click
- six injected accessibility violations on the stories or pages the a11y gate claims; three visual deltas and 20 of 20 stable re-renders
- three seeded codec mutants for a round-trip property, with the shrunk counterexample pinned as an `@example` or a regression file

### Sources (testing)

The taxonomy, commands and V54–V73 come from the Track A testing research catalog (2026-10-05) and
its notes: local runs of Jest 30.5.2, Vitest 5.0.3, pytest 9.1.1 and CPython 3.14.6 (break the SUT,
`hasAssertions`, floating assertions and coroutines, collected-list diffs); Maven Surefire 3.6.0,
Gradle test-retry 1.6.6, cargo-nextest 0.9.146 and Playwright 1.63.0 documentation (retry gates);
diff-cover 10.6.0 source (files absent from the report); libfaketime 0.9.13 and Go
`testing/synctest`; ImpossibleBench (Zhong, Raghunathan and Carlini, arXiv 2510.20270, 2025-10-23)
for the escalate exit; the rule of three for the repeat bound. Paraphrased; no text reproduced.

## Code quality

A correctness claim says one concrete input makes the code produce the wrong outcome. Its proof
runs that input against the real entry point: the dependency made to fail at its port, the
malformed value fed at the boundary, the flag turned on, the runner told to fail on what it
normally forgives. A maintainability claim says the change made a measured number worse; its proof
is the same command on the merge-base and on the head, printing both numbers. Reading proves
neither. Every probe runs on a scratch branch or worktree, and its restore is proven with
`git diff --exit-code`. The claim sentences, gate readings and precedents are in
[`precedents/code-quality.md`](precedents/code-quality.md). Users: `error-handling-scan`,
`type-safety-scan`, and every later code-quality detector and fix command.

### Oracle taxonomy (code quality)

| Oracle | Asserts | Classes |
|---|---|---|
| **Port fault injection** | The dependency at its port throws, rejects, times out, answers an error status or returns a partial result; the caller-visible outcome (status, typed error, rethrow with cause, retry scheduled, nothing published, error state shown) is wrong before the fix and right after | V74–V76, V78 |
| **Unhandled-failure hook** | The runner set to fail on an unobserved failure (an unhandled rejection, a never-awaited coroutine, an unobserved task) fails before the fix and passes after; ordering is observable with a deferred dependency | V77 |
| **Cause chain** | The original failure is reachable from what surfaces (`cause`, `__cause__`, `errors.Is`, `getCause()`, `InnerException`, `source()`), the interrupt flag survives, a `finally` does not replace the throw | V78 |
| **Paired-state restore** | After an injected failure every paired resource or flag is back at baseline: the lock is free, the busy flag false, `close` called exactly once, handles at their starting count | V79 |
| **Boundary value vector** | A malformed, null or wrong-typed value at the boundary crashes deep inside or writes a wrong value before the fix, and is refused with a typed error at the boundary after | V80, V81, V83 |
| **Checker diagnostic** | The checker, with the strictness turned on in a scratch config, prints a diagnostic at the cited line; quiet after the fix. A static fact | V82 |
| **Unsuppressed re-run** | The rule re-run with its suppressions ignored prints a live diagnostic at the suppressed line | V84 |
| **Divergence** | Two implementations of one rule, fed the same generated inputs with a fixed seed, disagree; the first differing input is the witness | V85 |
| **Metric ratchet** | The same command on base and head: the number on changed code does not grow, the targeted number falls, and no suppression, ignore path or threshold was loosened to get there | V82, V86 |
| **Boot** | The application starts, or every entry module imports, after a cycle is cut or dead code is removed (`smoke-verify`) | V86 |

### Port fault injection

**Fails first when:** the failure is injected and the caller still sees success — a 200, an empty
list, a `null`, a sent confirmation, a spinner that never stops.

| Stack | Shape |
|---|---|
| Jest / Vitest | `vi.spyOn(gateway, 'charge').mockRejectedValueOnce(new Error('boom'))` (Jest: `jest.spyOn`); call the route through `supertest` or `fastify.inject`; assert the documented error status, the logger or tracker spy called once with the error, nothing published |
| pytest | `mocker.patch.object(svc.gateway, "charge", side_effect=ProviderError("boom"))`; `with pytest.raises(BillingError) as ei: …`; assert `ei.value.__cause__` is the provider error |
| Go | a fake implementing the port that returns `errBoom`; `if !errors.Is(err, errBoom) { t.Fatalf(…) }` |
| JUnit | `when(gateway.charge(any())).thenThrow(new IOException("boom"))`; `assertThrows(BillingException.class, …)`; AssertJ `hasCauseInstanceOf(IOException.class)` |
| RSpec | `allow(gateway).to receive(:charge).and_raise(Net::ReadTimeout)`; `expect { … }.to raise_error(BillingError)` |
| PHPUnit | `$gateway->method('charge')->willThrowException(new RuntimeException('boom'))`; `$this->expectException(BillingException::class)` |
| .NET | Moq `.ThrowsAsync(new HttpRequestException("boom"))`; `await Assert.ThrowsAsync<BillingException>(…)`; assert `InnerException` |
| HTTP dependency | a local stub (msw, nock, `httptest.NewServer`, WireMock, respx) answering `500` with a JSON body, a non-JSON body, and a hang past the client timeout. An unchecked status (`fetch` does not throw on 4xx / 5xx) is proven by the `500` with a valid-looking JSON body |

Inject each dependency on the path in turn, and once **inside cleanup** (a `finally`, a `close`).
The control: the same entry point with no failure injected returns its normal result.

### Unhandled-failure hook

Turn the silent failure into a red test, then assert the caller observes it. Measured on Node 23.8.0
(2026-10-05): an unhandled rejection exits 1 by default and under `NODE_OPTIONS=--unhandled-rejections=strict`,
and a registered `process.on('unhandledRejection')` handler keeps the process alive — read the
error-handling pre-flight's context lines before trusting the default.

```bash
NODE_OPTIONS=--unhandled-rejections=strict npx jest test/orders/refund.spec.ts   # an unhandled rejection kills the process
npx vitest run test/orders/refund.spec.ts                                       # Vitest reports unhandled rejections as errors (research; not re-run)
PYTHONASYNCIODEBUG=1 pytest -W error::RuntimeWarning -W error::pytest.PytestUnraisableExceptionWarning tests/test_refund.py
```

.NET: a test fixture that subscribes `TaskScheduler.UnobservedTaskException` and fails the test.
Ordering: hold the dependency on a deferred promise, call, assert the caller has **not** reported
completion, resolve, assert it has (`expect(done).toBe(false)` → resolve → `true`).

### Cause chain

`expect(err.cause).toBe(original)` · `assert exc.__cause__ is original` · `errors.Is(err, ErrNotFound)` ·
`assertThat(e).hasCause(original)` · `Assert.Same(original, ex.InnerException)` · Rust
`err.source()` downcast. Interrupt: run the call in a thread, interrupt it, assert
`Thread.currentThread().isInterrupted()` afterwards. Finally override: the body throws and the
`finally` returns — assert the throw is observed. Status mapping: a table test where each documented
error reaches its documented status (validation 400 / 422, unauthenticated 401, forbidden 403,
missing 404, conflict 409, upstream 502 / 503).

### Paired-state restore

After the injected failure: a second `acquire` of the lock succeeds within a short timeout (Go
`mu.TryLock()` is true); the hook's busy flag is false (`renderHook` + `act`, then
`expect(result.current.pending).toBe(false)`); `close` was called exactly once (a spy, `verify(…)`);
a file written through a fake whose `Close` returns an error makes the function return that error;
Python runs under `python -X dev -W error::ResourceWarning`. Handle counts that grow with load are
the performance pack's socket-and-handle-count oracle (§ Performance).

### Boundary value vector

Feed the boundary the null family (absent key, `null`, `undefined`, `""`, `0`, `false`, `NaN`, an
empty array), a wrong type (`"12"` for `12`), a missing required field, an extra field, an unknown
enum string, truncated JSON and a non-JSON body. For a non-null assertion, make its source miss: the
map lookup, the `find`, the optional relation, the unset config key. Before the fix: a `TypeError`
deep in the call, `undefined` rendered, a wrong row written. After: a typed 400 / 422 or a typed
parse error at the boundary. Property tests generate the rest (fast-check, Hypothesis, jqwik, Go
fuzzing); record the seed in the finding.

### Checker diagnostic

Turn the strictness on in a scratch config, run, keep the lines in the cited files, delete the
scratch config:

```bash
printf '{"extends":"./tsconfig.json","compilerOptions":{"strict":true,"noEmit":true}}\n' > tsconfig.cq-probe.json
npx tsc -p tsconfig.cq-probe.json | rg -n 'src/orders/'; rm tsconfig.cq-probe.json; git status --porcelain
mypy --strict app/orders/                       # or a scratch [tool.mypy] override removing ignore_errors for the module
dotnet build -p:Nullable=enable -p:WarningsAsErrors=nullable
vendor/bin/phpstan analyse -l max src/Orders
```

A per-file opt-out (`@ts-nocheck`, `# mypy: ignore-errors`, `#nullable disable`, `# typed: false`)
is removed in the scratch copy instead. The number of diagnostics in the blind zone is the
finding's size; each one at a reachable line is a correctness candidate of its own.

### Unsuppressed re-run

Re-run the suppressed rule with suppressions ignored: `npx eslint --no-inline-config <file>`;
`ruff check --ignore-noqa <file>`; `mypy --warn-unused-ignores`; for `@ts-ignore`,
`@ts-expect-error`, `//nolint`, `@SuppressWarnings` or `#[allow]`, delete the directive in a scratch
copy and run the compiler or linter. A diagnostic at the line is live and hidden; none is a stale
suppression (a maintainability item).

### Divergence

```ts
fc.assert(fc.property(arbPeriod, (p) => { expect(prorateApi(p)).toEqual(prorateWorker(p)); }), { seed: 42, numRuns: 1000 });
```

Hypothesis: `@given(...)` with `@settings(derandomize=True)`. The first differing input is the
witness; `git log -S '<the fixed token>' --oneline -- <both paths>` shows which copy got the last
fix.

### Metric ratchet

```bash
BASE=$(git merge-base origin/main HEAD); W="${TMPDIR:-/tmp}/cq-base"; git worktree add -q "$W" "$BASE"
CHANGED=$(git diff --name-only --diff-filter=AM "$BASE"...HEAD -- '*.ts' '*.tsx')
for t in "$W" .; do echo "== $t"; (cd "$t" && for f in $CHANGED; do [ -f "$f" ] && printf '%5s %s\n' "$(rg -c --pcre2 '\bas\s+unknown\s+as\b|:\s*any\b|<any>' "$f" || echo 0)" "$f"; done); done
git worktree remove "$W"
```

Swap the counting command for the class: `npx type-coverage --at-least <base %> --strict --detail`,
`lizard -C 10 -w <files>`, `npx depcruise src --output-type json`,
`npx jscpd@5 --baseline-from-ref "$BASE" --fail-on-new-clones src`. Then prove nothing was gamed:
`git diff "$BASE"...HEAD -U0 | rg '^\+' | rg -n '<suppression or escape regex>'` prints nothing, and
`git diff "$BASE"...HEAD -- eslint.config.* tsconfig*.json pyproject.toml .golangci.yml` loosens no
threshold, adds no ignore path and turns off no strict flag. Baseline files (`eslint-suppressions.json`,
`phpstan-baseline.neon`, `.dependency-cruiser-known-violations.json`) may only shrink.

### The fix loop (code quality)

**Correctness lane, per finding:** re-verify; reproduce failing-first at the real entry point with
the reported input and paste the failing line; fix at the root with the project's own primitive (the
error mapper, the shared HTTP client, the validator, the clock); run the class's variants below
(the ones that already pass are the controls); re-run the detector that raised it on the patched
line; sweep siblings with the ledger `N_found == N_fixed + N_explained + N_followup`
([`fix-bug-core.md`](fix-bug-core.md)); run the suite. These fixes **change behaviour** on purpose:
a characterization test that pins the old behaviour is the wrong harness for them.

**Maintainability lane, per finding:** pin behaviour on the base commit first (characterization
tests committed before the change); refactor with an engine where one exists, one refactoring kind
per commit; then the metric ratchet, a clean suite run, zero snapshot updates in the refactor
commit, and a one-line canary break that turns the pin red.

**Never a fix:** widening a catch, adding a suppression or `as any`, special-casing the reported
input, deleting the test that failed, or loosening a threshold. **Stop and ask** before changing a
public API or wire contract, a stored data format, a rounding mode or business timezone, or deleting
code with no in-repo caller that may be public API.

### Evidence block (code quality)

```text
claim:     <correctness | maintainability> — the sentence from precedents/code-quality.md
oracle:    <name>: <exact command>; before: <wrong output | crash | count>; after: <expected | count>
input:     <the concrete value, the failure injected, the environment>          (correctness)
base/head: <metric> <base> → <head> on <files>, by <tool@version>               (maintainability)
variants:  <V-number>: <k of n> pass after the fix; controls unchanged
redetect:  <detector §n> at <file:line> quiet after the fix
verdict:   proven (oracle) | Unconfirmed (settling test: <path or command>) | Refuted (gate <n>: <reason>)
```

### Class variants (code quality)

#### V74. Swallowed or dropped error — port fault injection
- an empty or comment-only handler; a handler that only logs; a handler that never reads the error; `.catch(() => {})`; Go `if err != nil {}`; Python `except: pass`, `except Exception: continue`; Ruby `rescue nil`
- each dependency on the path fails in turn: throw, reject, timeout, error status, partial result (2 of 3 batch items), and a failure inside cleanup
- pass: the documented status or typed error reaches the caller, logged once (not swallowed, not twice), state rolled back or compensated

#### V75. Failure turned into a success value — port fault injection
- `catch → return [] / null / {} / false / 0`; `.catch(() => setData([]))`; a 2xx or `{ ok: true }` after a caught failure; Go `if err != nil { return nil }`; Python `except …: return None`
- pass: the caller can tell failure from empty (a typed error, an error state, a `Result` / discriminated union), and a declared degrade mode is visible (log with context or metric)

#### V76. Unchecked failure signal — port fault injection
- an HTTP body parsed with no status check (`fetch`, `requests`, `httpx`, `net/http`): the stub answers `500` with a JSON body, a `404`, a non-JSON body
- Go errors assigned to `_`; Rust `let _ =` / `.ok();` on a `Result`; `subprocess.run` without `check=True`; a Node callback whose `err` is never read; a Java boolean result (`File.delete()`) ignored
- pass: each signal turns into the documented failure

#### V77. Unobserved async failure — unhandled-failure hook
- a promise neither awaited, returned nor caught; `forEach(async …)`; `.map(async …)` not collected; an async callback to an emitter or timer; `new Promise(async …)`; a `.then` chain with no rejection handler
- Python `create_task` with no reference kept, a coroutine never awaited; C# `async void`; Kotlin `GlobalScope.launch`
- the dependency rejects; resolves after the caller returned; rejects after a timeout; the action is invoked twice; it is aborted mid-flight
- pass: the hook stays quiet and the caller observes the rejection and the completion order

#### V78. Catch-all, lost cause, rewritten outcome — cause chain
- a bare `except`, `except BaseException`, `catch (Throwable | Exception)`, `rescue Exception` around business logic: inject a programmer error and an interrupt / cancellation and assert both leave the handler
- a new error thrown in a handler without the original as `cause`; Python `raise X` without `from`; Go `%v` where callers use `errors.Is`; an error compared by its message text
- `return` / `throw` in `finally`; `InterruptedException` swallowed; a validation error mapped to 500
- pass: the cause chain, the interrupt flag, the original throw and the documented status all survive

#### V79. Paired state not restored on the error path — paired-state restore
- a lock, semaphore or mutex acquired with no `finally` / `defer` / `with` release; a busy, pending or in-flight flag set before an await and cleared only on success; a counter incremented and decremented around a call; a file opened for writing outside `with` / try-with-resources / `using`, and its `Close` error dropped
- failure at each await between acquire and release, plus cancellation and timeout
- pass: every paired value is back at baseline after each failure, and a written file's close error is returned

#### V80. Unchecked cast at a boundary — boundary value vector
- `JSON.parse(x) as T`, `(await res.json()) as T`, `req.body as T`, a queue or event payload `as T`, `process.env.X as T`, a storage value `as T`; Python `cast(T, json.loads(…))`, `Model(**payload)` with no validation; Go `x.(T)` without `, ok`; Kotlin `as`, Swift `as!`, Rust `.unwrap()` on parsed input; a Java or C# cast of a deserializer's result
- per boundary: the null family, a wrong type, a missing and an extra field, an unknown enum value, truncated and non-JSON input
- pass: a typed refusal at the boundary for every vector; valid input unchanged

#### V81. Non-null assertion on a nullable — boundary value vector
- TypeScript / C# / Swift postfix `!`, Kotlin `!!`, Rust `.unwrap()` on a lookup, Python `assert x is not None` (gone under `-O`)
- the source misses: a map lookup, a `find`, an optional relation or column, an unset config key, an empty array's first element, a DOM query
- pass: the miss takes a defined path (typed error, 404, default per spec), never a crash or `"undefined"` in output

#### V82. Checker off or untyped surface — checker diagnostic, metric ratchet
- a strict flag set false; a per-file opt-out; a module-wide ignore; a low analysis level; `any` / `Any` / `interface{}` / `dynamic` / `mixed` / a raw type on an exported signature; a double cast (`as unknown as`)
- pass: the scratch strict run is quiet on the cited files, and on a diff the escape count on changed files does not grow

#### V83. Logic, equality, number and time traps — boundary value vector, TZ perturbation
- an ignored pure result (`str.replace`, `concat`, immutable date math); `==` coercion, NaN, `is` on literals, `equals` without `hashCode`; a mutable default argument; a closure over a loop variable on Go < 1.22; numeric `.sort()` with no comparator; float money; a non-exhaustive switch on a domain enum (add a member); naive time
- time: the suite under `TZ=Pacific/Kiritimati`, `TZ=Etc/GMT+12` and `TZ=Asia/Kathmandu`, the US and EU DST gap and overlap days of the current year, 29 February, month-end + 1 month
- pass: every partition gives the specified result

#### V84. Suppression hiding a live diagnostic — unsuppressed re-run
- a line-scoped, file-wide and blanket suppression, each re-run with suppressions ignored
- pass: the code no longer triggers the rule with the suppression removed; a stale suppression is deleted

#### V85. Divergent copy of one rule — divergence
- every copy of the rule (API and worker, client and server, two services), ≥ 1,000 generated inputs with a fixed seed, plus the input the one-sided fix was for
- pass: all copies agree, or one implementation remains

#### V86. Maintainability regression — metric ratchet, boot
- complexity, length, coupling, cycles, dead code, duplication and type escapes, each measured on the changed files at base and head
- pass: the targeted number falls, no other number on changed code grows, baselines only shrink, and the app boots

### Sources (code quality)

The taxonomy, the fix loop and V74–V86 come from the code-quality research catalog for this pack
(2026-10-05) and its notes: the correctness variant partitions and runner hooks (Node
`--unhandled-rejections`, pytest warning filters, `ResourceWarning`, .NET `UnobservedTaskException`),
the maintainability ratchet checks (type-coverage 2.30.3, lizard 1.24.0, dependency-cruiser 18.5.0,
jscpd 5.4.0), and the refactor-equivalence recipe of Anthropic's `code-modernization` plugin
(<https://github.com/anthropics/claude-plugins-official>, Apache-2.0; adapted with attribution).
The pre-flight hit counts behind V74–V82 were measured on the benchmark fixtures and a read-only
real TypeScript monorepo on 2026-10-05 (the detectors record them). Paraphrased; no text
reproduced.

## Accessibility and UI states

An accessibility claim says a real user, on a real route in a real state, cannot perceive, reach or
operate something WCAG 2.2 A/AA requires. A UI-state claim says the surface renders nothing, the
wrong thing, or loses input when the network answers something other than success. Both are proven
in a **production build** driven by Playwright (or Testing Library for a component), at a named
**route-state**: the route, plus the state that exposes the defect — the dialog or menu open, the
theme, the viewport, the locale, the response the API gave. Reading proves neither, except for the
static-fact classes listed in [`precedents/ui.md`](precedents/ui.md) (the proof rule). No oracle here
replaces the manual pass: automation finds part of the problem (`precedents/ui.md` § 58), so a run
that passes every oracle is reported as "automated floor clean", never as "accessible". Users:
`a11y-code-scan`, `a11y-scan`, `render-correctness-scan`, `ssr-audit`, `client-data-scan`, `routing-scan`
and `i18n-scan` (frontend pack); `ui-state-scan`, `state-matrix`, `design-token-audit`, `motion-audit`,
`chart-encoding-audit` and `ui-design-sweep` (ui-ux pack); and `/frontend-fix`. The section holds the
accessibility and UI-state oracles (V87–V112), then render and SSR (V113–V119), client data and
navigation (V120–V131), i18n (V132–V140), design tokens, motion and charts (V141–V144) and render
measurement (V145–V146).

### Oracle taxonomy (accessibility and UI states)

| Oracle | Asserts | Classes |
|---|---|---|
| **Axe at route-state** | One axe rule id has no violation node at the route-state, with the WCAG 2.2 tag set; `incomplete` nodes are listed, never dropped | V88, V94, V97, V98, V101–V103, V142 |
| **Keyboard path** | Tab reaches the control, Enter / Space activate it, Escape closes what it opened, focus returns to the trigger, nothing traps focus outside a modal | V87, V90, V92, V95, V96, V99, V100, V142 |
| **Role and label query** | `getByRole(role, { name })` or `getByLabel(text)` resolves exactly one element | V88 |
| **Aria snapshot diff** | `toMatchAriaSnapshot` before and after the interaction shows the state change (`[expanded]`, `[selected]`, `[checked]`, `[pressed]`) | V94, V95 |
| **Focus-visible delta** | The keyboard-focused element differs from its blurred render, in normal and forced-colours modes | V89 |
| **Obscured rect** | No focused element is entirely covered by a `fixed` / `sticky` element | V91 |
| **Live-region presence** | The status region exists and is empty before the action and holds the message after it; a field error is the input's accessible description or error message | V92, V93 |
| **Geometry** | Each target's box is ≥ 24×24 CSS px or meets the spacing exception | V102 |
| **Reflow probe** | At 320 CSS px wide nothing scrolls horizontally outside a 2-D container; injected 1.4.12 spacing clips nothing | V103 |
| **Media emulation** | Under `reducedMotion: 'reduce'` no long animation runs; under `forcedColors: 'active'` the focus ring is still drawn | V89, V98, V143 |
| **Paste probe** | A value pasted into a credential or OTP field arrives intact | V97 |
| **Clock fast-forward** | A session-timeout warning with an extend action appears before sign-out | V100 |
| **Injected violation** | A known violation added to the page turns the project's a11y gate red | V104 |
| **State matrix** | The surface renders the specified state for each network answer (pending, `[]`, 500, network error, 403, 404, partial, offline, failed refetch) | V105 |
| **Request count** | One user intent sends exactly the specified number of requests | V106 |
| **Console hydration** | A production SSR load logs no framework hydration message and throws no `pageerror` | V107 |
| **Mount/unmount balance** | After unmount, timers, listeners, observers and subscriptions are back at their starting count | V108 |
| **Reorder identity** | Local state (typed text, focus, expansion) follows its item when the list reorders | V109 |
| **Request order** | When responses arrive out of order, the UI shows the latest request's data | V110 |
| **Pseudo-locale** | Every visible string carries the pseudo-locale marks, and +40 % text clips nothing | V111, V132, V134 (`bidi` strategy) |
| **RTL mirror** | Under `dir="rtl"` the layout mirrors and `lang` / `dir` follow the locale | V112, V136 |
| **Heap slope** | Across 20 A → B → A client navigations on a production build, the GC'd JS heap does not grow linearly, or it plateaus | V113, V53, V108 (cost) |
| **Server render** | A production SSR server answers the route 200 and logs no `ReferenceError` for a browser global | V114 |
| **Build gate** | The framework's production build fails on the boundary violation before the fix and passes after it; on the Next App Router, `next build` exits 0 with no `missing-suspense-with-csr-bailout` in its log | V115, V116 (Next 16 request APIs), V131 |
| **Server + client request count** | One navigation fetches each URL once across the server render and the hydrated client | V116 |
| **Cross-request leak probe** | 60 interleaved requests as two users and anonymous never return another session's marker | V117 |
| **Console warning** | A component test logs none of the framework's warning family for the class | V119; `render-correctness-scan` §1 (update loops) |
| **View update** | Changing the state through the real action changes the rendered output | V118 |
| **Request timeline** | For one navigation, the request log (url, start, end) shows the independent reads overlapping, and the request count does not grow with N | V120 |
| **Write-then-read** | After a create, update or delete through the UI, the list and the detail show the change with no reload, and stay correct after back/forward | V121 |
| **Failed optimistic write** | A write that fails after a delay first shows the optimistic value, then restores the previous value and shows an error; a concurrent second write survives the rollback | V122 |
| **Identity switch** | Switching the entity, the tenant or the signed-in user never paints the previous identity's data, and sign-out leaves no cached rows | V123 |
| **Idle request rate** | With no input, the request count stays flat; with the tab hidden, polling stops (or runs at the declared background rate) | V124 |
| **Open in new tab** | Middle-click / Ctrl-click on the navigating element opens a new page, and the element exposes an `href` | V125 |
| **URL round trip** | The view state (filter, sort, page, tab, search) survives reload, back/forward and a fresh browser context opened on the copied URL | V126 |
| **Garbage param** | A malformed route or search param renders a handled not-found or normalized view, with no `pageerror` and no request carrying `NaN` / `undefined` | V127 |
| **Unknown URL** | A path no route matches answers 404 (SSR) or renders not-found content with a way home (SPA; 200 allowed) | V128 |
| **Redirect hop count** | Each route, signed in and signed out, settles after at most one redirect; no `ERR_TOO_MANY_REDIRECTS`, no navigation ping-pong | V129 |
| **First protected frame** | Signed out, opening a protected route sends no protected API request and paints no protected content before the redirect | V130 |
| **Missing-key run** | The suite run under every shipped locale logs no missing key: i18next `saveMissing: true` + a `missingKeyHandler` that throws, vue-i18n `missingWarn` / `fallbackWarn` turned into failures, the formatjs or Angular compile step | V133 |
| **Catalog parity (static fact)** | `catalog-parity.py` (frontend pack, `i18n-scan`) reports no `missing-key`, `placeholder` or `plural-forms` row for the set; the row is the two-ended trace | V133, V134 (catalog half) |
| **Plural matrix** | Rendering n ∈ {0, 1, 2, 3, 11, 100, 101} under the locale gives one distinct, correct string per `Intl.PluralRules(locale).select(n)` category (Arabic: zero, one, two, few, many, other) | V134 |
| **Locale format matrix** | The same fixture instant or amount renders as `Intl.DateTimeFormat` / `Intl.NumberFormat` produce for each shipped locale (`test.use({ locale, timezoneId })`); money across three locales × three currencies including JPY (0 decimals) and KWD (3) | V135 |
| **Locale switch** | After the app's own switcher (and on first load), `html` carries `lang` matching the locale and `dir="rtl"` for an RTL one; an SPA switch updates both without a reload | V137 |
| **Collation order** | A display list sorted by the code equals the same list sorted with `new Intl.Collator(locale).compare` (`['Ä','Z','A']` under `de` and `sv`; Arabic with and without diacritics) | V138 |
| **Server-text sentinel** | With the API answering 4xx/5xx carrying the message `ZZ_SERVER_TEXT`, the sentinel is not visible under a non-base locale | V139 |
| **Bidi isolation** | A user value such as `"Ali (CEO) 2"` interpolated into an RTL sentence keeps its parenthesis and digit in logical order (`Range.getClientRects()` x-order, or a screenshot) | V140 |
| **Token conformance** | Every rendered colour, spacing, type and radius value at the route × theme is in the resolved token set (canvas-normalised); a value that stays identical across themes while its tokens change is the themed miss | V141 |
| **Behavioural diff vs the DS component** | The same keyboard path and axe run pass on the design-system component and fail on the local re-implementation, both opened | V142 |
| **Animation census** | `document.getAnimations()` at the route-state lists no layout or paint property, no duration over the ceiling, and no infinite animation still running on loaded content | V143 |
| **Rendered chart geometry** | The value axis's lowest tick is 0 on a length mark; rendered bar heights and circle areas are proportional to their values; a seeded null breaks the path | V144 |
| **Colour-vision emulation** | Under each CDP vision-deficiency type the series stay distinguishable, and each series clears 3:1 against the plot background | V144 |
| **Render measurement** | On the rendered route × theme, `measure.ts` reports no `floating` surface (all three boundary cues absent against the nearest painted ancestor) and no `same-role`, `size` or `centre` control-row disagreement | V145, V146 |

### Axe at route-state

`@axe-core/playwright` 4.13.0 on the production build (`vite preview`, `next start`, the deployed
preview). Reach the state first — open the dialog or menu, set the theme with
`page.emulateMedia({ colorScheme: 'dark' })`, the viewport, the locale — and wait for a locator that
proves the content rendered, never `networkidle`.

```ts
import AxeBuilder from '@axe-core/playwright';
const TAGS = ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'];   // wcag22aa is what runs target-size
const r = await new AxeBuilder({ page }).withTags(TAGS).analyze();        // no .options() after .withTags()
expect(r.violations.filter((v) => v.id === 'button-name')).toEqual([]);   // assert the ONE rule the finding names
console.log(JSON.stringify(r.incomplete.map((i) => [i.id, i.nodes.length])));   // needs-review: listed in the finding
```

`.options()` replaces the whole option object and `.disableRules()` wipes rules enabled through it
(`precedents/ui.md` § 50): use one `.options({ runOnly, rules })` object, or `.withTags()` and at most
one `.disableRules()`. Assert the one rule id the finding names; a "zero violations" assertion fails
first on unrelated debt and proves nothing about this fix. Pin the axe version in the evidence:
4.13 changed issue counts.

### Keyboard path

```ts
const seen: string[] = [];
for (let i = 0; i < 2 * (await page.locator('a,button,input,select,textarea,[tabindex]').count()) + 5; i++) {
  await page.keyboard.press('Tab');
  seen.push(await page.evaluate(() => { const e = document.activeElement as HTMLElement | null;
    return e?.dataset.testid ?? `${e?.tagName}:${(e?.textContent ?? '').trim().slice(0, 30)}`; }));
}
expect(seen).toContain('refund-close');                                 // reachability — fails first on a clickable div
await page.getByTestId('refund-close').focus(); await page.keyboard.press('Enter');
await expect(page.getByRole('dialog')).toBeHidden();                    // activation by keyboard
```

Overlays: open with the keyboard; Tab `2 × focusables` times and assert
`dialog.contains(document.activeElement)` after each press; `Escape` closes;
`await expect(trigger).toBeFocused()`. A trap is the last `2k` entries cycling inside a subtree that
is not an open modal. Route change: navigate by clicking a link (never `page.goto`), then
`await expect(page).toHaveTitle(/Orders/)` and assert focus is on the new `h1`, `main` or `body` —
not on the removed link.

### Focus-visible delta

Focus the element by keyboard until `toBeFocused()`, capture a clip 4 px larger than its box, blur,
capture again: the two images must differ. Repeat under
`page.emulateMedia({ forcedColors: 'active' })`, where a `box-shadow`-only ring disappears. The
computed-style form compares `outline-style`, `outline-width` and `box-shadow` between the two states.

### Obscured rect

For every element the keyboard path visits, sample `document.elementsFromPoint()` at its centre and
four inset corners; it fails 2.4.11 when **every** sample's top element is a `position: fixed` or
`sticky` element that neither is nor contains it. Partial cover is AAA 2.4.12. Repeat with the
cookie banner and the chat bubble open, and at the mobile viewport.

### Live-region presence

```ts
await expect(page.getByRole('status')).toHaveCount(1);   // the region exists BEFORE the action
await expect(page.getByRole('status')).toBeEmpty();
await page.getByRole('button', { name: 'Save' }).click();
await expect(page.getByRole('status')).toHaveText(/saved/i);
// field errors: association, not just text on screen
await expect(page.getByLabel('Email')).toHaveAttribute('aria-invalid', 'true');
await expect(page.getByLabel('Email')).toHaveAccessibleErrorMessage(/required/i);   // or toHaveAccessibleDescription
```

A region mounted together with its text fails the first assertion. That is the defect the test
proves. `@guidepup/virtual-screen-reader` 0.33.0 (`spokenPhraseLog()`) is the CI-able announcement
oracle when the team wants the spoken text; real VoiceOver / NVDA through `@guidepup/guidepup` belongs
in a nightly macOS / Windows job.

### Geometry, reflow and media

- **Target size:** axe `target-size` (it runs only with `wcag22aa` in the tags) plus `boundingBox()`
  of every `getByRole('button' | 'link' | 'checkbox' | 'radio' | 'switch')` ≥ 24×24, or a 24 px circle
  centred on it that intersects no other target's circle. A 44 px house target is checked the same way
  and reported as the house rule.
- **Reflow:** `page.setViewportSize({ width: 320, height: 256 })`, then
  `document.documentElement.scrollWidth <= 321` and no text element's `getBoundingClientRect().right`
  past 320 outside a 2-D container. **Text spacing:** `page.addStyleTag` with
  `* { line-height: 1.5 !important; letter-spacing: .12em !important; word-spacing: .16em !important } p { margin-bottom: 2em !important }`;
  no text container with `overflow: hidden` then has `scrollHeight > clientHeight`. **Zoom:** axe
  `meta-viewport`. **Orientation:** the main content is visible at a portrait and a landscape viewport.
- **Motion:** `page.emulateMedia({ reducedMotion: 'reduce' })`, then
  `document.getAnimations().filter((a) => a.playState === 'running' && (a.effect?.getTiming().duration ?? 0) > 200)`
  is empty; with default motion a carousel exposes a pause control that stops it.

### Paste probe and clock fast-forward

Paste: grant clipboard permissions (Chromium), `navigator.clipboard.writeText('Pa55-word')`, focus the
field, `ControlOrMeta+V`, and assert `toHaveValue('Pa55-word')`; an OTP split input must accept the
whole code in its first box. Timing: `await page.clock.install()` before load, sign in,
`await page.clock.fastForward('14:40')`, assert a dialog with an extend action is visible before the
sign-out time, and that extending keeps the session.

### Injected violation

The gate-integrity oracle. Add one known violation the gate must catch — an unnamed icon button on a
test-only route, or a story with `parameters.a11y.test: 'error'` and a missing label — and run the
project's own a11y gate command unchanged. It must exit non-zero. It fails first when the gate is
neutered: a broad `disableRules`, `.exclude('main' | 'body')`, an `includedImpacts` filter, a
Storybook `a11y.test` of `'todo'` or `'off'`, contrast checked only in jsdom, or no `wcag22aa` tag.

### State matrix

One handler set per endpoint, shared by the component test, Storybook and Playwright. MSW 3.0.2
(`http`, `HttpResponse`, `delay` from `'msw'`; `graphql` now from `'msw/graphql'`):

```ts
export const states = {
  loading:   http.get('/api/orders', async () => { await delay('infinite'); }),
  empty:     http.get('/api/orders', () => HttpResponse.json([])),
  error500:  http.get('/api/orders', () => HttpResponse.json({ message: 'boom' }, { status: 500 })),
  network:   http.get('/api/orders', () => HttpResponse.error()),
  forbidden: http.get('/api/orders', () => HttpResponse.json({}, { status: 403 })),
  notFound:  http.get('/api/orders/:id', () => new HttpResponse(null, { status: 404 })),
  partial:   http.get('/api/orders', () => HttpResponse.json({ items: [ok1], errors: [{ id: 2, code: 'TIMEOUT' }] })),
};
test.each(Object.keys(states))('orders list renders the %s state', async (s) => { server.use(states[s]); /* render, assert */ });
```

Assert the role and copy each state specifies: a `progressbar` or skeleton with `aria-busy` (loading),
the empty copy and its action (empty), an `alert` with a retry that recovers and **not** the empty copy
(error), distinct forbidden copy with no retry loop (403), a not-found state with a way back (404),
the other widgets still rendered (partial). Without MSW: `page.route(url, (r) => r.fulfill({ status: 500, json: {} }))`,
`r.abort('failed')`, a handler that never fulfils, and `context.setOffline(true)`. Stale: serve v1,
then fail the refetch; the old rows stay visible with a stale or updating indicator. Every state also
asserts `page.on('pageerror')` fired zero times.

MSW 3 keeps `setupServer` in `msw/node` and `setupWorker` in `msw/browser`, and needs Node ≥ 22.12: read
the engines before the first import. A Storybook story takes the same handler
(`parameters: { msw: { handlers: [states.empty] } }`, msw-storybook-addon 3.0.3, matched to the msw major).
With a service-worker MSW in the page, Playwright's `page.route` sees the requests only under
`serviceWorkers: 'block'`; assert with `getByRole('alert' | 'status')` and one `toHaveScreenshot()` per state.

- **The state sweep (the bulk oracle):** for each route in the route table × each state in {500, network
  error, 403, `[]`, held, offline}, route every API call to that state, open the route and assert three
  things: an error or status role is present, the empty copy is absent under an error, and no page error
  fired. One run per state confirms or refutes whole groups of `ui-state-scan` candidates.
- **Mobile:** RNTL with the API client mocked per state; a Flutter widget test whose fake repository returns
  `Future.error(…)`, an empty list, or a `Completer` that never completes; a Compose UI test fed a
  `MutableStateFlow` of each `UiState`; an XCTest per enum case of the view's state. The device-tier rules
  are in § Mobile.

### Request count

`let n = 0; await page.route('**/api/orders', (r) => { n++; return r.fulfill({ status: 201, json: {} }); });`
then `await Promise.all([btn.click(), btn.click()])` (and `dblclick()`, Enter twice in a field) under a
held response; `expect(n).toBe(1)`, and the inputs survive a 500. Money, stock and single-use actions
also need the server-side idempotency proof from the security pack, when it is installed.

### Console hydration

Production build and SSR start (`next build && next start`, `nuxi build`, `vite build --ssr`, the
SvelteKit adapter, `ng build` with SSR). Collect `page.on('console')` and `page.on('pageerror')` for one
load of the route and fail on the framework's hydration family: React 19 `Hydration failed because`,
`A tree hydrated but some attributes`, `cannot be a child of` / `cannot be a descendant of`; Vue 3.5
`Hydration … mismatch`; Svelte 5 `hydration_mismatch`; Angular `NG050\d` (strings from the
frameworks' shipped sources, read 2026-10-05; React production builds report minified codes through
`hydrateRoot`'s `onRecoverableError`). Run once more under `timezoneId: 'Pacific/Kiritimati'` and
`locale: 'ar-SA'`. A message that disappears in a clean browser profile is an extension
(`precedents/ui.md` § 45).

### Mount/unmount balance, reorder identity, request order

- **Balance:** with fake timers, mount, exercise, unmount, then `expect(vi.getTimerCount()).toBe(0)`;
  spy `window.addEventListener` / `removeEventListener` (and `observe` / `disconnect`, `subscribe` /
  `unsubscribe`) and assert the counts match per event type. Under React StrictMode the double mount
  must not double-register. The browser-level form across navigations is memlab (§ Heap leak (memlab)).
- **Reorder identity:** type into row 2's input, then insert at the head, delete the middle, sort and
  filter; the typed value, focus and expansion stay with the same item id.
- **Request order:** two requests for one view, the first delayed past the second (per-request MSW
  `delay`, or `page.route` holding the first); the UI must show the second request's data and never
  flash the first's.

### Pseudo-locale and RTL mirror

- **Pseudo-locale:** wrap every catalog **value** with `pseudoLocalizeString()` (accented, about +35–40 %
  length) — never `PseudoLocalizeDom.start()`, which rewrites hard-coded text too and cannot tell the two
  apart. Walk the visible text nodes: a node with two or more ASCII letters and no pseudo marks is
  hard-coded. At 320 px, no labelled control has `scrollWidth > clientWidth` under `overflow: hidden`.
- **RTL mirror:** switch to an RTL locale through the app's own switcher; assert
  `html[lang="ar"][dir="rtl"]`, then compare bounding boxes of the shell landmarks and directional
  icons with the LTR render: the x-order flips, and text that must stay LTR (numbers, code, phone
  numbers) does not.

### Heap slope

Chromium only (CDP), on the **production** build (`vite preview`, `next start`, `nuxi preview`), never a
dev server: StrictMode mounts twice and HMR keeps old modules alive. Three warm-up cycles, then 20
measured A → B → A cycles through client-side links; GC before every sample.

```ts
const cdp = await page.context().newCDPSession(page); await cdp.send('Performance.enable');
const sample = async () => { await cdp.send('HeapProfiler.collectGarbage');
  const m = Object.fromEntries((await cdp.send('Performance.getMetrics')).metrics.map((x) => [x.name, x.value]));
  return { heap: m.JSHeapUsedSize, nodes: m.Nodes, listeners: m.JSEventListeners }; };
const s = []; for (let i = 0; i < 23; i++) {
  await page.click('a[href="/b"]'); await page.waitForURL('**/b'); await page.click('a[href="/a"]'); await page.waitForURL('**/a');
  if (i >= 3) s.push(await sample()); }
```

- **Finding:** the least-squares slope of `heap` over the 20 samples is greater than max(64 KB, 0.5 % of
  the first sample) per cycle, **and** R² ≥ 0.8, **and** `nodes` or `listeners` is also non-decreasing.
- **Plateau check (refutes):** the slope over the second 10 cycles is under 10 % of the slope over the
  first 10 — a bounded cache warming up (TanStack Query `gcTime`, a router cache, Apollo with eviction).
  Run past the cache's TTL before calling a plateau a leak.
- **Severity input:** > 1 MB per cycle on a primary route is high.
- **Retainers:** memlab (§ Heap leak (memlab)) names what holds the memory: `npx memlab analyze
  unbound-object`, `detached-DOM`, `unmounted-fiber-node`.
- `performance.memory` is Chromium-only and quantised; prefer the CDP metrics.

### Server render

Production build and start (`next build && next start`, `nuxi build && node .output/server/index.mjs`,
`vite build --ssr` + the project's server, the SvelteKit adapter's server, `ng build` + the SSR server).
Request the route with no browser: `curl -s -o /dev/null -w '%{http_code}' <url>` is `200`, and the
server log for that request holds no `ReferenceError: (window|document|localStorage|sessionStorage|navigator) is not defined`.
Failing first: the route 500s (or renders the error page) before the guard moves into an effect or a
client-only lifecycle, and answers 200 after.

### Build gate

The framework's own build is the oracle; the message is the evidence (strings read from Next 16.3.8):

- a server module imported by a client module: add `import 'server-only'` to the server module;
  `next build` fails with `This module cannot be imported from a Client Component module.` — failing
  first proves the client reaches it;
- a function or class instance passed from a Server to a Client Component: `next build && next start`
  and a request log `Functions cannot be passed directly to Client Components unless you explicitly
  expose it by marking it with "use server"` or `Only plain objects, and a few built-ins, can be passed
  to Client Components from Server Components.`;
- `dynamic(…, { ssr: false })` in a Server Component: the build error `` `ssr: false` is not allowed with
  `next/dynamic` in Server Components. Please move it into a Client Component. ``;
- synchronous `params` / `searchParams` / `cookies()` / `headers()` on Next 16: `next build` type errors
  (with `next typegen` route types) — Next 16 removed the synchronous form;
- `useSearchParams()` with no `<Suspense>` boundary (V131): `next build` (or `next build --debug-prerender`,
  which names the component) on the unfixed tree exits non-zero, or prerenders the route as client-only,
  with `missing-suspense-with-csr-bailout` in the log; after the fix it exits 0 with no such line. Next
  App Router only.

### Server + client request count

One navigation, counted on both sides: the API's own access log (or a mock API that counts requests
per URL and tags them by `user-agent` / an `x-ssr` header the server fetch adds) for the server render,
plus `page.on('request')` for the browser after hydration. The same URL fetched by both is a double
fetch (Nuxt `await $fetch` in setup, a SvelteKit universal `load` using the global `fetch` or axios,
Angular without the HTTP transfer cache). After the fix each URL appears once.

### Cross-request leak probe

Node 22 global `fetch` against the production server; two signed-in sessions whose rendered page
carries a unique marker (a display name `ZZ_U1_MARK` / `ZZ_U2_MARK`) plus anonymous requests,
interleaved and concurrent:

```ts
const jobs = Array.from({ length: 60 }, (_, i) => (i % 6 === 5 ? ['anon', ''] : i % 2 ? ['U1', c1] : ['U2', c2]));
const res = await Promise.all(jobs.map(async ([who, cookie]) => [who, await (await fetch(url, { headers: { cookie } })).text()]));
const leaks = res.filter(([who, body]) => (who !== 'U1' && body.includes('ZZ_U1_MARK')) || (who !== 'U2' && body.includes('ZZ_U2_MARK')));
```

Any leak confirms the class (blocker when the state holds user or tenant data). 0 of 60 is evidence,
not proof: interleaving depends on the server's concurrency, so cite the module-scope variable as the
mechanism and keep the row `report-flagged` until a deterministic test (two requests with an awaited
gap that writes and then reads the shared value) fails. Also request as U1, then anonymously: the
anonymous HTML holds no U1 marker.

### Console warning

`vi.spyOn(console, 'error')` (or `warn`) in the component test, or `page.on('console')` in Playwright;
fail on the framework's family for the class: React `Maximum update depth exceeded`, the React warning
that a component changed an uncontrolled input to be controlled (wording not re-verified for 19.3 —
match the regex `uncontrolled input to be controlled|controlled input to be uncontrolled`), Svelte runtime
`effect_update_depth_exceeded`, `state_unsafe_mutation`, `ownership_invalid_mutation`.

### View update

Change the state through the real action (the store action, the emitted event, the signal setter), not
by assigning the test's own reference, and assert the rendered text changes. Angular: under `fakeAsync`
with one `fixture.detectChanges()`; Vue: `await nextTick()`; Svelte 5: `flushSync()`. It fails before
the fix (destructured store state, a same-reference `signal.update`, a mutated non-bound `$props`).

### Client data and navigation oracles

Every oracle below runs on a production build (or a component test with MSW 3), fails on the unfixed
code first, and is re-run for each class variant. **Request count** (V106), **Request order** (V110)
and **State matrix** (V105) are reused as they stand for the client-data classes that need them.

#### Request timeline

`const log = []; page.on('request', (r) => log.push({ url: r.url(), t: Date.now() })); page.on('requestfinished', (r) => { const e = log.find((x) => x.url === r.url() && !x.end); if (e) e.end = Date.now(); });`
Load the route once with MSW or a real backend seeded with **N = 2** and once with **N = 20**
parents. Fails first when the request count for the route grows with N (an N-requests defect, the
browser twin of § Query-count scaling), or when request B's start is at or after request A's end
although B does not use A's response (a waterfall). Passes when the count is constant in N and
independent requests overlap. Read the dependency before asserting overlap: a second read that needs
the first one's id is not a waterfall.

#### Write-then-read

A stateful handler — `const db = [...seed]; http.post('/api/orders', async ({ request }) => { db.push(await request.json()); return HttpResponse.json({}, { status: 201 }); }), http.get('/api/orders', () => HttpResponse.json(db))` —
or a real backend. Create (then update, then delete) through the UI on the list's own route; assert the
row appears (changes, disappears) **without** `page.reload()`, on the list **and** on the detail view, and
again after `page.goBack()` / `page.goForward()` (router cache, bfcache).

#### Failed optimistic write

`http.patch('/api/todos/:id', async () => { await delay(300); return HttpResponse.json({}, { status: 500 }); })`.
Trigger the write; assert the optimistic value is visible within the delay, then that the previous value
is back and an error is announced after it. With two writes in flight and the first failing, the second's
value must survive (snapshot per mutation, `cancelQueries` before the write, invalidate on settle).

#### Identity switch

Render entity A; switch to B with B's response held (`delay(800)`); sample the visible heading or rows
with `expect.poll` (or a `MutationObserver` log) and fail if any sample shows A's data under B's route.
For users: sign in as U1, load a list, sign out, sign in as U2 on the same page — no U1 row ever paints;
after sign-out, the query cache holds no entries (`queryClient.getQueryCache().getAll().length === 0`, or
the app's own cache API) and any persisted cache is gone. The device-side twin is in § Mobile (V173).

#### Idle request rate

Component test with fake timers and an MSW request counter (`server.events.on('request:start', () => n++)`):
hide the tab (TanStack: `focusManager.setFocused(false)`; otherwise stub `document.visibilityState` to
`'hidden'` and dispatch `visibilitychange`), advance 60 s, assert `n` did not grow (or equals the declared
background rate). Loop variant: visible, no input, 5 s → `n < 2` after the initial load.

#### Open in new tab

`const [popup] = await Promise.all([context.waitForEvent('page'), el.click({ button: 'middle' })]);` (or
`click({ modifiers: ['ControlOrMeta'] })`), then `await expect(el).toHaveAttribute('href', /\/orders\//)`.
Fails first on an element that navigates through a click handler only: no page opens and there is no
`href`. A row that also contains a real link for the same action passes through that link.

#### URL round trip

Set the view state through the UI (a filter, the sort, page 2, a tab, a search); then (a) `page.reload()`,
(b) `page.goBack()` after changing it once more, (c) open `page.url()` in a fresh `browser.newContext()`.
Each must show the same control values and the same rows. Search typing writes with `replace`, not one
history entry per keystroke: `history.length` grows by at most one per committed search.

#### Garbage param

`page.goto('/orders/abc')`, `/orders/-1`, `/orders/%27`, `/list?page=-5&size=1e9&sort=%27`. Collect
`page.on('pageerror')` and the request log. Assert a handled state — the not-found view (SSR status 404)
or a normalized view (page 1) — zero `pageerror`, and no request whose URL contains `NaN`, `undefined`
or `null`.

#### Unknown URL

`const r = await page.goto('/__refract_404_probe');` On SSR or a static host that knows the route table,
`expect(r.status()).toBe(404)`. On an SPA behind a history fallback the status is 200: assert the
not-found heading and a link home instead, and that the home page did **not** render (a soft 404).

#### Redirect hop count

For each of the protected route, the login route and the root, signed in and signed out: count
`framenavigated` on the main frame for 3 s after `goto` (fail above 2), catch `net::ERR_TOO_MANY_REDIRECTS`,
and walk `response.request().redirectedFrom()` (server chain ≤ 1 hop).

#### First protected frame

Signed out, `page.on('request')` from before `goto(protectedRoute)`. Assert no request to a protected API
path fired before the URL reached the login route, and that a screenshot taken at `waitUntil: 'commit'`
plus the first `requestAnimationFrame` shows no protected content. Whether the server refuses those
requests is the security pack's proof, not this one.

### i18n oracles

**Pseudo-locale** (V111) and **RTL mirror** (V112) above are reused as they stand. **Catalog parity** is a
static fact: `catalog-parity.py` (`i18n-scan`, frontend pack) prints the row, and the two-ended trace (the
catalog line and the code that reads the key) passes gate 6. **Collation order** needs no harness: sort the
display list both ways in a unit test and compare.

#### Missing-key run

```ts
// i18next: the test setup, before the app renders
i18n.init({ ...config, saveMissing: true, missingKeyHandler: (lngs, ns, key) => { throw new Error(`missing ${ns}:${key} [${lngs}]`); } });
// vue-i18n: createI18n({ ..., missingWarn: true, fallbackWarn: true, missing: (locale, key) => { throw new Error(`missing ${key} [${locale}]`); } })
// then run the e2e or component suite once per shipped locale; one throw is one confirmed key.
```

A key reached only through a dynamic prefix fails here only when the run renders that value: pair it with the
prefix × union sweep (enumerate the bound, then `` i18next.exists(`status.${v}`, { lng }) `` for every value × locale).

#### Plural matrix

```ts
for (const n of [0, 1, 2, 3, 11, 100, 101]) {
  const cat = new Intl.PluralRules('ar').select(n);                 // zero one two few many other other
  render(<CartCount count={n} />, { locale: 'ar' });
  expect(screen.getByTestId('cart-count')).toHaveTextContent(expectedFor[cat](n));
}
```

Fails first when the code branches on `n === 1`, or when the catalog lacks a category the locale needs (the
category's key is missing, so the raw key or the fallback renders).

#### Locale format matrix

```ts
for (const [locale, timezoneId] of [['ar-SA', 'Asia/Riyadh'], ['en-US', 'America/Los_Angeles'], ['de-DE', 'Europe/Berlin']]) {
  test.use({ locale, timezoneId });   // one describe block per pair
  // render the fixture order; expect the date cell to equal new Intl.DateTimeFormat(locale, opts).format(FIXTURE_INSTANT)
  // and the total to equal new Intl.NumberFormat(locale, { style: 'currency', currency }).format(FIXTURE_AMOUNT)
}
```

Digits are a product decision for Arabic locales: read the runtime's default with
`new Intl.NumberFormat('ar-SA').resolvedOptions().numberingSystem` (do not assume it), `-u-nu-latn` selects Latin,
and assert what the product declares, cited where it declares it.

#### Locale switch

Switch through the app's own control, never by setting `localStorage` and reloading:
`await expect(page.locator('html')).toHaveAttribute('lang', /^ar/)`, `toHaveAttribute('dir', 'rtl')`; switch back and
assert `en` / `ltr`; repeat after a hard reload on each locale.

#### Server-text sentinel

`await page.route('**/api/**', (r) => r.fulfill({ status: 422, contentType: 'application/json', body: JSON.stringify({ message: 'ZZ_SERVER_TEXT', code: 'validation_failed' }) }))`;
trigger the action under the non-base locale; `await expect(page.getByText('ZZ_SERVER_TEXT')).toHaveCount(0)` and the
localized error for `validation_failed` is visible. A server that localizes by `Accept-Language` passes when the
request carries the header and the body is localized: assert the header on the intercepted request.

#### Bidi isolation

Seed a user whose display name is `Ali (CEO) 2`; render the sentence that interpolates it under `ar`; take the
`Range.getClientRects()` of the `(`, `)` and `2` characters and assert their x-order is the logical order of the
name, not the reordered one. A screenshot diff against a reviewed baseline is the fallback.

### Design tokens, motion and chart encoding

#### Token conformance

On a production build, at each route × theme, after the route's own content marker is visible. Resolve the palette from
`getComputedStyle(document.documentElement).getPropertyValue('--token')` for every declared token, normalise each colour by
painting it on a 1×1 canvas (`ctx.fillStyle = v; ctx.fillRect(0, 0, 1, 1); ctx.getImageData(0, 0, 1, 1).data`) so hex,
`rgb()` and `oklch()` compare equal, and resolve the spacing and type scales to px. Then sample every visible element's
`color`, `background-color`, `border-*-color`, `outline-color`, `padding-*`, `margin-*`, `gap`, `font-size`,
`border-radius` and `z-index`; report (value, count, example selector) for every value not in the set. Exclude
`transparent`, `rgba(0, 0, 0, 0)`, `0px`, `auto`, `currentColor`-derived borders, iframes and `svg *`. **Theme flip:** run
light and dark; an element whose colour is identical in both while the tokens around it change is a literal on a themed
surface. **Fails first:** the literal's value (or the off-scale px) is in the list with the candidate's selector before the
fix, and gone after it, with nothing new added. Translucent tokens compare as their composited value; a ±1-channel
difference is rounding. One run confirms or refutes whole groups of static hits: a literal that never renders is dead code.
`design-token-audit` (ui-ux pack) carries the full `offToken` helper.

#### Behavioural diff vs the DS component

Render the design-system component and the local re-implementation in the same state (open, focused, with an error) on
the same route or story. Run the keyboard path (Tab in, Enter / Space, Escape, focus return to the trigger) and axe at the
route-state on both. **Fails first:** the DS component passes and the local copy fails at least one step. After the fix
(the copy replaced by the DS component, or the DS component extended) both pass. A copy that passes every step is visual
drift only: the finding keeps its visual severity, never the behavioural one.

#### Animation census

```ts
export const census = (page: Page) => page.evaluate(() => document.getAnimations().map((a) => {
  const t = a.effect?.getComputedTiming(); const el = (a.effect as KeyframeEffect | null)?.target as Element | null;
  return { kind: a.constructor.name, name: (a as CSSAnimation).animationName ?? (a as CSSTransition).transitionProperty ?? a.id,
    props: [...new Set(((a.effect as KeyframeEffect | null)?.getKeyframes() ?? []).flatMap((k) => Object.keys(k))
      .filter((p) => !['offset', 'easing', 'composite', 'computedOffset'].includes(p)))],
    duration: t?.duration, iterations: t?.iterations, state: a.playState,
    target: el ? el.tagName.toLowerCase() + '.' + [...el.classList].slice(0, 3).join('.') : '' };
}));
```

Trigger the hover, press, state change or mount, then census. A CSS transition reports the property that really moved even
when it was declared `all`; a Web Animations or Motion animation reports its keyframe properties. **Fails first:** a
layout property (`width`, `height`, `top`, `left`, `margin`, `padding`, `font-size`), a duration over the
`motion.md` ceiling, or (after the data marker is visible) an `iterations: Infinity` animation in `running` state is in
the list before the fix and absent after it. A `requestAnimationFrame`- or scroll-listener-driven animation is invisible
here: prove it with a DevTools trace (§ Trace insight). A cost claim (frames dropped) always needs a trace or profile file
on a throttled mobile profile; the census proves existence only.

#### Rendered chart geometry

Read the chart's SVG on the route, with the route's data or a seeded fixture holding a null, a zero and a large value:
`text` nodes for the axis ticks, `rect` bounding-box heights for bars, `circle` `r` for bubbles, the line `path` across the
null. **Fails first:** the lowest value tick on a bar, column or area chart is not 0; two bars' height ratio differs from
their value ratio; two circles' area ratio (r²) differs from their value ratio; the path stays continuous across the
seeded null, or a zero mark appears where the reading was missing. A canvas renderer has no DOM marks: switch it to its
SVG renderer for the test, or read its option model.

#### Colour-vision emulation

Chromium only, through a CDP session:

```ts
const cdp = await page.context().newCDPSession(page);
for (const type of ['deuteranopia', 'protanopia', 'tritanopia', 'achromatopsia'] as const) {
  await cdp.send('Emulation.setEmulatedVisionDeficiency', { type });
  await page.locator(chart).screenshot({ path: `${out}/${type}.png` });
}
await cdp.send('Emulation.setEmulatedVisionDeficiency', { type: 'none' });
```

**Fails first:** under at least one type two series cannot be told apart by any channel but colour (no label, pattern,
marker shape or direct label separates them), or a series' computed colour falls below 3:1 against the plot background
(1.4.11). After the fix (a second channel, direct labels, a CVD-safe ramp) every screenshot separates the series and every
ratio clears 3:1, in light and dark. The screenshots are the artifact the report cites; "looks distinguishable" with no
artifact is not a result.

### Render measurement (floating surface, control rows)

`ui-design-sweep`'s `scripts/measure.ts` (ui-ux pack; installed at `.claude/skills/ui-design-sweep/scripts/measure.ts`,
needs only `@playwright/test`) measures two properties of the rendered box that no source read can answer: a card's fill
can be inherited and its shadow flattened, and a control's height is padding + line-height + border from three separate
declarations. The thresholds and every exclusion are in sections A–E of `ui-design-sweep/references/measured-from-the-render.md`.

- **Floating surface** (V145) — `floatingSurfaces(page, theme)` skips viewport-filling boxes (≥ 95 % of the width and
  ≥ 90 % of the height), composites each container's fill over its **nearest painted ancestor** (never the page), skips a
  container whose fill equals that ancestor's (a layout box, not a surface), and reports `floating` when all three cues are
  absent: no border at ≥ 3:1 against the adjacent fill, no elevation cue that survives the render, and a surface-pair ratio
  under 1.2:1. A declared shadow with alpha under 0.05 is a `review` row, read on the screenshot.
- **Control rows** (V146) — `controlRows(page, { steps, controlClass })` builds a row from three conditions together: the
  same landmark region, vertical centres within 6 px, and a horizontal gap under 64 px. It reports `same-role`, `size`
  (≥ 2 px apart, unless both heights are declared steps) and `centre` (≥ 2 px offset) rows, each with
  `scale: declared | none`.
- **Navigation** — `sweep(page, routes, opts)` loads the first route and reaches the rest through the app's own history
  (`navigateInApp`) with a route-specific `ready` marker; a route that lands on the login path is
  `blocked (redirected-to-login)` and is never measured.

**Fails first:** the candidate's container or row is in the module's output before the fix and absent after it, on the same
route, in light **and** dark, at every breakpoint the row renders in. A run with no render harness reports both classes
`NOT RUN`, never pass. The module finds candidates and edits nothing. It has been run on a synthetic fixture page only
(Playwright 1.63.0, Chromium 153, 2026-10-05): treat its first run on a real app as the stage where false positives are
still being found, and record each new exclusion in the reference with its measurement.

### Class variants (accessibility and UI states)

#### V87. Non-semantic control — keyboard path
- `div`, `span`, `li`, `td`, `img` with a click handler; a handler supplied through spread props; Vue `@click.stop`; Svelte 5 `onclick` and Svelte 4 `on:click`; Angular `(click)` with a half fix (`(keydown.enter)` but no Space); touch-only handlers
- pass: Tab reaches it, Enter and Space both activate it, `toHaveRole('button' | 'link')`; or it became a native `<button>` / `<a href>`

#### V88. Missing accessible name or label — role and label query, axe at route-state
- icon-only and glyph-only `<button>`; `<a href>` holding only an SVG; `<div role="button">`; `<input type="image">`; a design-system `IconButton`; a button inside a portal (scan it open); a tooltip used as the name; the dark-theme icon swap; the label in every locale (a missing key renders the key)
- inputs: placeholder as label, a visual label not associated, a design-system input, select, radio group (`fieldset` / `legend`), date picker, OTP split input; images: `<img>`, Next `<Image>`, `NuxtImg`, `ngSrc`, inline SVG, a linked image
- pass: `getByRole(role, { name })` / `getByLabel()` resolves one element; axe `button-name`, `link-name`, `image-alt`, `label` clean at the route-state; the visible label is contained in the name (2.5.3)

#### V89. Focus indicator removed — focus-visible delta, media emulation
- every variant of Button, Link and Input; light, dark, forced-colours and `contrast: 'more'`; inside a card with `overflow: hidden` that clips the ring
- pass: a visible delta in every mode

#### V90. Overlay focus — keyboard path
- dialog, drawer, menu, popover, combobox list; a nested dialog; an embedded editor that captures Tab
- pass: focus moves in on open, stays inside a modal, Escape closes, focus returns to the trigger

#### V91. Focus obscured — obscured rect
- sticky header, sticky footer CTA, cookie banner open, chat bubble, mobile viewport

#### V92. Route change — keyboard path, live-region presence
- link click, programmatic navigation after a submit, back and forward, a query-only change, the 404 route
- pass: the title changes, focus lands on the new heading or `main`, the announcer text changes (or the framework's built-in announcer is present, `precedents/ui.md` § 27)

#### V93. Status and error messages — live-region presence
- toast, inline "Saved", cart count, search result count, form result, offline banner; the first and a repeated identical message
- field errors: client-side on blur, server-side 422 after submit, a field on a later wizard step; focus moves to the first invalid field or an announced summary

#### V94. ARIA validity and widget state — axe at route-state, aria snapshot diff
- `aria-hidden` on a focusable or on its container, `role="presentation"` on a focusable, invalid role or attribute value, a positive `tabindex`, `role="button"` on `a[href]`
- state: tabs `[selected]`, disclosure `[expanded]`, switch and checkbox `[checked]`, toggle `[pressed]`, each on the SSR first paint and after hydration

#### V95. Composite widget keyboard model — keyboard path, aria snapshot diff
- tabs (arrows, Home / End, roving `tabindex`), menu (arrows, Escape returns focus), combobox (`aria-activedescendant`, listbox options), listbox, grid, tree, radio group; in LTR and RTL (arrow direction flips)

#### V96. Dragging movement — keyboard path
- sortable list, kanban, slider, resizable panel, map pin, file drop zone
- pass: the same result with single clicks (move buttons or a menu) **and** with the keyboard; a keyboard sensor alone does not satisfy 2.5.7

#### V97. Input purpose and accessible authentication — paste probe, axe at route-state
- password, new password, OTP split input, email, phone, address, name fields; reveal-password toggle; a CAPTCHA step
- pass: paste works, the autocomplete tokens are present and valid (axe `autocomplete-valid`), no cognitive test without an alternative

#### V98. Media and motion — media emulation, axe at route-state
- autoplay video and audio, carousel, parallax, smooth scroll, CSS and JS animation (Framer Motion, GSAP, Vue and Svelte transitions); video captions (axe `video-caption` is needs-review)

#### V99. Hover and focus content — keyboard path
- custom tooltip, hover card, mega-menu; triggered by hover **and** by focus
- pass: Escape dismisses without moving focus, the pointer can move onto the content, it stays until dismissed or no longer relevant (1.4.13)

#### V100. Context change on input and timing — keyboard path, clock fast-forward
- a `select` that navigates on change, a field that submits on input, focus that opens a window; session timeout, idle sign-out, `meta refresh`
- pass: ArrowDown in the select changes no URL until an explicit action; a warning with extend appears before sign-out

#### V101. Contrast per theme — axe at route-state
- text in light and dark, hover, focus, active and visited states, placeholder, text over images and gradients (axe `incomplete`); non-text: input borders, focus ring, icons, chart series against their background (≥ 3:1, computed — axe has no rule)

#### V102. Target size — geometry, axe at route-state
- toolbar icon buttons, table row actions, pagination, close "×", chips with remove, the mobile breakpoint

#### V103. Reflow, zoom, text spacing, orientation — reflow probe, axe at route-state
- 320 px, 200 % zoom (640 px of a 1280 layout), the 1.4.12 spacing injection, long German and Arabic strings, RTL; `user-scalable=no` / `maximum-scale=1`; a portrait-only lock

#### V104. The a11y gate neutered — injected violation
- broad `disableRules`; `.exclude('main' | 'body')`; `includedImpacts`; Storybook `a11y.test` not `'error'`; jsdom-only contrast; no `wcag22aa`; `.options()` after `.withTags()`; a lint suppression with no reason

#### V105. UI state coverage — state matrix
- list, detail and infinite list (page 2 fails); a refetch error while data is present (stale, not blank); a dependent query idle ≠ loading; a client-only first paint; one of N widgets failing; 403 vs 404 vs 500; offline then online (a paused mutation resumes exactly once)
- the dialog and the drawer, not only the page; the second locale and RTL; dark theme; 320 px; both mobile platforms

#### V106. Pending and double submit — request count
- click twice, `dblclick`, Enter twice in a field, Enter while the button is disabled, `requestSubmit()`, a mobile double tap; pending covers the whole await chain, including the navigation after save

#### V107. Hydration mismatch — console hydration
- `Date` / `Math.random()` / `crypto.randomUUID()` in render; locale and time-zone formatting; a `typeof window` branch; storage or `matchMedia` in initial state; invalid nesting (`div` in `p`, `a` in `a`); under the far time zone and an RTL locale

#### V108. Effect and subscription cleanup — mount/unmount balance
- listener, interval, timeout, observer, WebSocket, EventSource, store or RxJS subscription, `matchMedia` listener, a `requestAnimationFrame` loop; StrictMode remount

#### V109. Keys and identity — reorder identity
- insert at head, delete middle, sort, filter, drag-reorder; rows with uncontrolled inputs, focus or animation; Angular `track $index` on a mutable list

#### V110. Out-of-order responses — request order
- typeahead, route-param change, tab switch, pagination, filter change

#### V111. Hard-coded strings and expansion — pseudo-locale
- text nodes, `alt`, `title`, `placeholder`, `aria-label`, toast and validation messages; at 320 px

#### V112. RTL — RTL mirror
- shell, forms, tables, directional icons, carousels, charts; `lang` and `dir` after a runtime locale switch

#### V113. SPA memory growth per navigation — heap slope, heap leak (memlab) (extends V53)
- a listener, an interval, a timeout chain, an observer, a WebSocket / EventSource, a store or RxJS subscription, detached DOM held by a closure, a module-level cache, a third-party widget initialised again on every route
- a bounded cache that must plateau (run past its TTL)

#### V114. Browser global during SSR — server render
- module scope; the render body; a plugin or composable at module top; a SvelteKit universal `load`; a React Router route-module body; Angular DOM access outside `afterNextRender`

#### V115. Server → client boundary — build gate
- a server module or secret imported by a client module; a function or class instance passed as a prop; `ssr: false` in a Server Component; a secret-reading module with no `server-only`

#### V116. SSR data semantics — server + client request count, build gate
- Nuxt `$fetch` in setup; an unkeyed `useAsyncData` in a reused composable; a SvelteKit universal `load` with the global `fetch`; Angular without `withHttpTransferCache`
- Next 16 synchronous request APIs; `cookies()` in a layout making the subtree dynamic

#### V117. Cross-request state on the server — cross-request leak probe
- module `let`; a module `Map` / `Set` cache; module-scope `ref` / `reactive` / `writable` / signal / `$state`; a Zustand or Pinia store created at module scope and imported by SSR
- `axios.defaults.headers.Authorization`; a server-side `i18next.changeLanguage`; a global dayjs / moment locale

#### V118. Reactivity loss — view update
- Pinia / `reactive` destructure; mutated props; `signal.update` returning the same array; OnPush opt-out with in-place mutation; a Svelte 5 child mutating a non-bound prop

#### V119. Controlled ↔ uncontrolled — console warning
- `useState()` feeding `value`; `value={x?.y}` before data loads; a form keyed by a value that changes during editing

#### V120. Request waterfall; N requests where one would do — request timeline
- independent reads awaited in sequence in a loader, an effect or a hook; one request per row, per selected item or per parent (`Promise.all(ids.map(get))`, a `for … of` with `await`)
- N = 2 and N = 20 parents; a dependent read whose second request does not use the first's response
- pass: the request count is constant in N and independent requests overlap; a read that needs the first one's id is not a waterfall

#### V121. Write with no invalidation — write-then-read
- create, update and delete; the list **and** the detail view; a paginated or infinite list (prefix invalidation); a second list under another filter
- a Next Server Action (needs `revalidatePath` / `revalidateTag` / `updateTag` / `refresh()`); back and forward after the write (router cache, bfcache); server state copied into a global store
- pass: the change shows on every view with no reload, and still after back/forward

#### V122. Optimistic update with no rollback — failed optimistic write
- a 500 after a delay; a 409 or 422; two writes in flight, the first failing; an infinite-query cache (`pages[]`); a refetch in flight during the mutation
- pass: the previous value returns, an error is announced, and the surviving write's value is kept

#### V123. Key missing an input; cache kept across identities — identity switch
- entity A → B with B's response held; a tenant switch; sign-out and sign-in as another user on the same page; an expired session
- a key that omits an input the fetch reads; a persisted cache (a storage or IndexedDB persister)
- pass: no sample shows the previous identity's data; after sign-out the query cache and every persisted cache are empty

#### V124. Polling and refetch loops — idle request rate
- an interval refetch with the tab hidden; a `setInterval` fetch with no visibility check; a refetch on every render (an unstable key or dependency); a failing poll with no backoff; a poll that keeps running after the job completes
- pass: hidden → no polling request (or the declared background rate); visible with no input for 5 s → fewer than 2 requests after the initial load

#### V125. Navigation by click on a non-link — open in new tab
- a table row, a card, an image, an icon, a breadcrumb and a menu item that navigate through a click handler, in each router present
- pass: middle-click and Ctrl/Cmd-click open a new page and the element exposes an `href`; a row that also holds a real link for the same target passes through that link

#### V126. View state kept only in component state — URL round trip
- filter, sort, page, page size, tab, date range, search
- pass: reload, back/forward and a fresh context on the copied URL show the same controls and rows; a typed search adds at most one history entry

#### V127. Route or search params not validated — garbage param
- `/orders/abc`, `/orders/-1`, `/orders/%27`, `?page=-5&size=1e9&sort=%27`; a defaulted destructure (`const { id = '' } = useParams()`); a cast with no parse
- pass: a not-found view (SSR 404) or a normalized view, zero `pageerror`, no request URL carrying `NaN`, `undefined` or `null`

#### V128. Unknown URL with no catch-all, or a soft 404 — unknown URL
- an SSR or static host that knows the route table; an SPA behind a history fallback; an unmatched child of a nested layout; a locale prefix
- pass: 404 where the host knows the table; on an SPA, the not-found heading and a link home, and the home page did not render

#### V129. Redirect loop — redirect hop count
- the protected route, the sign-in route and the root, each signed in and signed out; an expired session (a 401 from the API → one redirect, no loop); a trailing-slash or locale prefix; a deep link with `?redirect=`
- pass: at most one server hop, at most two main-frame navigations in 3 s, no `ERR_TOO_MANY_REDIRECTS`

#### V130. Protected content painted before the guard redirects — first protected frame
- a hard load of the protected route; a client navigation from a public page; a session that expires mid-session
- pass: no protected API request before the URL reaches sign-in, and no protected content in the first frame

#### V131. Next `useSearchParams` with no `<Suspense>` boundary — build gate
- a page or a layout that reads `useSearchParams()` in a client component with no `<Suspense>` above it; Next App Router only
- pass: `next build` exits 0 with no `missing-suspense-with-csr-bailout` line, and the route still prerenders

#### V132. Hard-coded copy — pseudo-locale (extends V111)
- JSX text; an attribute (`alt`, `title`, `placeholder`, `aria-label`, `aria-description`); a template literal in JSX; both ternary branches (`{ok ? 'Saved' : 'Failed'}`); a default prop value (`label = 'Submit'`); a label map rendered elsewhere (`const LABELS = { open: 'Open' }`); `<option>` text
- `<title>`, `document.title`, `useHead({ title })`, `generateMetadata`; `confirm()` / `alert()`; toast and validation messages (failure injected); email, push and print templates
- a Vue `v-bind` literal; a Svelte `{'…'}` expression; an Angular `[title]="'…'"`; an icon button's `aria-label`; SVG `<title>`; native `android:text`, Compose `Text("…")`, Flutter `Text('…')`

#### V133. Catalog defects — missing-key run, catalog parity
- a key missing in one shipped locale; a whole namespace file missing; a key used in code and defined nowhere; a dynamic prefix whose bound has a value with no key
- a placeholder spelled differently (`{{n}}` vs `{n}`, `%1$s` vs `%s`); invalid ICU; an Android `plurals` or `.xcstrings` plural variation missing a category; an `.xcstrings` entry `needs_review`; a fuzzy PO entry; an XLIFF unit with no target

#### V134. Plurals and concatenation — plural matrix, pseudo-locale `bidi`
- `count === 1`, `count > 1`, `count !== 1`, a truthy `count ? … : …` with 0; a `+ 's'` suffix
- fragments joined with `+`, a template literal or `.join(' ')`; an ICU message with only `one|other` for Arabic; `#` vs `{count}` placement

#### V135. Presentation formatting — locale format matrix
- `toLocaleString()` with no arguments; `toLocaleDateString(undefined, …)`; a hard-coded `'en-US'`; `Intl.*()` with no locale; date-fns `format` with no `{ locale }`; a dayjs or moment global locale
- `getMonth() + 1` built for display; `toFixed(2)` money; `'$' + x`; `` `${x} SAR` ``; server-side formatting with no `timeZone`

#### V136. RTL physical layout — RTL mirror (extends V112)
- a CSS property; a CSS value (`text-align`, `float`, `clear`); a 4-value `margin` / `padding` shorthand; `background-position: left`; a `translateX` slide-in; a `box-shadow` x-offset; a `border-radius` 4-value shorthand; an absolutely positioned close button
- a Tailwind class; an inline style object; CSS-in-JS; an icon glyph; Android XML margins and gravity; Compose `absolutePadding`; Flutter `EdgeInsets.only`; UIKit `leftAnchor`

#### V137. `<html lang>` and `dir` — locale switch
- first load per locale; an SPA switch; a hard reload after a switch; an SSR first paint; a per-subtree `lang` on a quote (correct, must survive)

#### V138. Collation and casing — collation order
- names, cities and product titles sorted with `<` / `>` or `localeCompare` with no locale; `toLowerCase() ===` on user text (Turkish `İ` / `ı`); Arabic with diacritics

#### V139. Raw server or exception text — server-text sentinel
- JSX `{err.message}`; Vue / Angular `{{ error.message }}`; `toast.error(e.message)`; `error.message || t(…)` (the server message wins whenever it exists); `response.data.detail`

#### V140. Bidi isolation — bidi isolation
- a name in a sentence; a name beside a count or a price; a phone number or an order code inside RTL text; a `t()` interpolation of a user field; a comment of unknown direction in a list

#### V141. Design-token drift — token conformance
- CSS; a locally defined SCSS variable; styled-components / Emotion; an inline style; a Tailwind arbitrary value; the Tailwind default palette on a semantic theme; a component SVG `fill`; raw-scale theme access (`theme.colors.blue[500]`)
- the dark-theme variant of the swapped token; the hover, focus and disabled states of the same control

#### V142. Re-implemented DS component — behavioural diff, keyboard path, axe at route-state
- a styled `<button>`; an `<a>` styled as a button; a hand-rolled `div role="dialog"`; a native `<select>`; `<input type="checkbox">`; a tooltip via `title` or a hover `div`; tabs built from buttons and state; a toast as a fixed `div`

#### V143. Motion — animation census, media emulation
- `transition: all`; a bare duration; `transition-[width]`; `@keyframes` on height; Motion `animate={{ height }}`; GSAP on `left`; a permanent `will-change`; an animated `filter: blur()`
- a looping Lottie on a hidden tab; a shimmer over loaded data; an autoplay carousel past 5 s; parallax and scroll-linked motion under `reducedMotion: 'reduce'`

#### V144. Chart encoding — rendered chart geometry, colour-vision emulation
- Recharts, Chart.js, ECharts, Vega-Lite, hand-rolled d3 SVG and a canvas renderer; a bar axis from 50; a value mapped to radius; two y-axes; `connectNulls` / `spanGaps`; `?? 0` in the data transform
- 2, 8 and 12 series; light and dark; print (greyscale)

#### V145. Floating surface (1.4.11 boundary) — render measurement
- cards, panels, modals, popovers, sticky headers, table row-groups; light and dark; 100 % zoom; a container on a painted ancestor that is not the page
- pass: every container's boundary resolves by a ≥ 3:1 border, an elevation cue that survives the render, or a surface step ≥ 1.2:1 against its nearest painted ancestor, in both themes; the fix uses the project's existing elevation language at the role, never a darker page

#### V146. Control-row disagreement — render measurement
- a toolbar, a filter bar, a form row, a search + button pair; every breakpoint; composite controls (tag input, combobox, date picker) measured at the wrapper
- text-entry and action controls compared on one scale; binary (switch, checkbox, radio) and icon-only controls compared within their own class only; across classes, centres only
- pass: one border-box height per class (or a declared step), vertical centres within 1 px, and no control snapped under the 24×24 floor

### Sources (accessibility and UI states)

The taxonomy and V87–V112 come from the frontend research notes for this batch (2026-10-05): the
accessibility pass (axe-core 4.13.0 and `@axe-core/playwright` 4.13.0 source, Playwright 1.63.0
types, Lighthouse 13.5.0, `@guidepup/virtual-screen-reader` 0.33.0, the WCAG 2.2 understanding
documents as summarised there), the UX-states pass (MSW 3.0.2 exports, TanStack Query 5.104 option
signatures, Playwright route and offline APIs) and the i18n / SSR pass (hydration message strings read
from React 19.3.0, Vue 3.5.43, Svelte 5.57.1 and Angular 22.2.1 shipped sources; the
`pseudoLocalizeString` vs `PseudoLocalizeDom` distinction). The keyboard-path, live-region and
geometry shapes follow the research's ranked techniques. Paraphrased; no text reproduced.

V113–V146 and their oracles were merged on 2026-10-10 from the batch-3 builders' drafts (written
2026-10-05): render correctness and SSR (hydration and build-error strings read from React 19.3.0,
Vue 3.5.43, Svelte 5.57.1, Angular 22.2.1 and Next 16.3.8 shipped sources), client data and routing
(MSW 3.0.2 API names, TanStack Query 5.104 option signatures, Playwright route and navigation APIs, the
Next.js `missing-suspense-with-csr-bailout` page), i18n (the frontend research catalog § 1.6 and § 5;
pseudo-localization 3.1.3), design tokens, motion and charts (the catalog § 1.7 and technique 14; the
Chrome DevTools Protocol `Emulation.pdl` vision-deficiency enum, read 2026-10-05), and render measurement
(`ui-design-sweep/references/measured-from-the-render.md`, measured 2026-10-05). Paraphrased.

## Mobile

The core rule holds on a device (§ The core rule: existence by invariant, cost by statistics).
**Existence** is a run-invariant check on a booted device or emulator, a release (or profile) build,
and the OS event the class is about: the typed text is back after process death; the denied flow
reaches Settings; one queued write reaches the server once; the call fails within its timeout.
**Cost** (frames, startup, render counts) is measured under the frontend noise rules, release builds
only. Every oracle names a **tier**: D (device or emulator), I (instrumented or widget test), A (the
shipped artifact: merged manifest, signed entitlements, the bundle), S (static trace). **No booted
device means `SKIPPED`, never PASS**, and a host-only unit test proves no lifecycle, permission,
link, push or background fix. Every variant runs on **both platforms** the product ships to; a
one-platform run is `PARTIAL`. Settled questions are in [`precedents/mobile.md`](precedents/mobile.md).
Users: `mobile-lifecycle-scan`, `mobile-a11y-scan`, `mobile-perf-scan`, `offline-sync-scan`,
`store-compliance-scan`, `platform-conventions-audit`, `native-bridge-audit`, `app-size-scan` and
`device-harness` (mobile pack), and `/mobile-fix`.

Tags: **[K]** — a command or API name not re-verified when this section was written (the authoring host
had no Xcode, so every iOS command carries it): keep "read the installed version" wording or verify it
before quoting it as fact. **[V]** — run on 2026-10-05 against a real release APK (build-tools 36.0.0).

### Oracle taxonomy (mobile)

| Oracle | Tier | Asserts | Classes |
|---|---|---|---|
| **Process-death restore** | D (I partial) | After background + system kill + relaunch from Recents, the screen, its typed input and its flow position are restored; the restore path does not crash | V152 |
| **Scheduler trigger** | A + D | The declared job, service or BG task runs when the OS triggers it, stops within its budget, and is declared where the OS requires | V153 |
| **Permission-denied flow** | D | Deny, deny twice and revoke-while-backgrounded each degrade in place and reach a Settings path; nothing crashes or loops | V154 |
| **Network never answers** | I | A request held forever fails within the client timeout and the screen renders its error state | V155 |
| **Link matrix** | D | Every link in {cold, warm} × {logged out, in, expired} × {valid, malformed, foreign} lands where the route table says, without a crash | V156 |
| **Push matrix** | D | Each app state × payload kind is shown, routed on tap, and never delivered to a logged-out account | V157 |
| **OTA compatibility** | D | An update that needs native code absent from the binary is not offered; a tampered update is rejected; a crash at first render rolls back | V158 |
| **Offline kill** | D | A write submitted offline survives a system kill and reaches the server exactly once | V159 |
| **Native a11y checker** | I | The platform checker reports no new violation at the screen-state (RNTL role and name queries; Flutter `meetsGuideline`; Compose / Espresso ATF; XCUITest `performAccessibilityAudit()`; versions in § Native accessibility checkers) | V160, V167 |
| **Render count (Reassure)** | I | A component's render count and duration do not grow against the baseline run | V161 |
| **Release-mode tripwire** | I/D | StrictMode `penaltyDeath`, Main Thread Checker or TSan stays silent on the path | V162, V178 |
| **Store probe** | A | The shipped artifact carries the declaration the store requires (merged manifest, `PrivacyInfo.xcprivacy`, entitlements, 16 KB alignment) | V163 |
| **Name and role query** | I | Every interactive element on the screen-state is found by role **and** accessible name; the custom action fires through the accessibility API | V164, V166 |
| **Largest-size render** | D (I for Flutter) | At the largest font / display size the text has grown and nothing clips; targets meet 44 pt / 48 dp | V165 |
| **Frame and render cost** | I / D | Render count, mount time and frame timing stay inside `THR-PERF-REGRESSION` against the baseline, release or profile build, ≥ 10 runs a side | V168 |
| **Oversized-decode log** | I | No image decodes larger than its display size × scale on the screen-state | V169 |
| **Startup metric** | D | Cold-start time to initial display, release + profileable build, named device, repeated runs, against the project budget (MOB-9) | V170 |
| **Leak assertion** | I / D | After the owner is destroyed, nothing retains it: LeakCanary, a weak-reference teardown, `leaks` exit code, `leak_tracker` | V171 |
| **Lost-response replay** | D (I with a mock server) | A write whose first response is dropped after the server committed it is applied exactly once when the client retries or the queue replays | V172 |
| **Identity switch** | D | After sign-out and a second account's sign-in, nothing of the first account is on screen, in the local store, in the query cache, in the queue or in scheduled work; a fresh install starts signed out | V173 |
| **Conflict and rollback** | I / D | A rejected optimistic write rolls the screen back and says so; two devices editing one record end in the entity's written policy, never a silent overwrite | V174 |
| **Store flow walk** | D | The store-required flow works on the release build: account deletion from inside the app, the ATT prompt before any tracking call, restore purchases on a fresh install | V175 |
| **Platform-convention capture** | D | The same screen captured on both platforms at the gate's API level shows no control under a system bar, the notch, the home indicator or the IME, and each platform's back and modal idiom intact | V176 |
| **Back-gesture probe** | D (I for Flutter) | On an API 36 emulator running Android 16, the back gesture on a dirty screen runs the guard (the discard dialog appears) instead of leaving | V177 |
| **Bridge contract test** | I | Every method one side calls is answered on every shipped platform; every failure path rejects within a bound; a synchronous method stays under the release-mode tripwire | V178 |
| **Release-artifact size delta** | A | The release artifact the store receives shrinks by the claimed bytes, same toolchain, same artifact type (per-device download size for Play), stable across two builds | V179 |

### Process-death restore

The only Android trigger that kills the process the way the OS does is a **system kill of a
backgrounded app**. `adb shell am kill` only kills a process that is safe to kill, so it is a no-op
on a foreground app; `am force-stop`, Maestro `stopApp` and Android Studio Stop enter the stopped
state and discard saved state by design; "Don't keep activities" keeps singletons alive;
`ActivityScenario.recreate()` keeps the ViewModel. Those three are extra variants, never the test.

```yaml
# Maestro (killApp = am kill on Android)
appId: com.example.app
---
- launchApp
- tapOn: { id: "note_input" }
- inputText: "draft-123"
- pressKey: Home
- killApp
- launchApp: { stopApp: false }
- assertVisible: "draft-123"
```

Shell form: `adb shell input keyevent KEYCODE_HOME`, `adb shell am kill <pkg>`, then
`adb shell ps -A | grep <pkg>` must print nothing (otherwise `SKIPPED (kill did not land)`), then
relaunch from Recents. Instrumented: UiAutomator `device.pressHome()` +
`executeShellCommand("am kill <pkg>")`; Compose `StateRestorationTester` proves `rememberSaveable`
only. Flutter: `tester.restartAndRestore()` (I), then the device run. iOS: background, stop the
process from Xcode, relaunch from the home screen; `terminate()` + `launch()` is a cold start.
React Native has no JS restoration: the oracle is no crash on restore plus every promised draft
reloaded from storage.

### Scheduler trigger

Declaration first (A): the merged manifest carries the service's `foregroundServiceType` and its
`FOREGROUND_SERVICE_<TYPE>` permission; the BG identifiers in `BGTaskSchedulerPermittedIdentifiers`
equal the registered ones (`comm -3` set-difference with constants resolved). Behaviour (D):
`adb shell cmd jobscheduler run -f <pkg> <jobId>`; WorkManager `TestDriver.setAllConstraintsMet`
(I); `adb shell dumpsys alarm` / `dumpsys power` for alarms and wake locks; Doze with
`adb shell dumpsys deviceidle force-idle`; iOS LLDB
`_simulateLaunchForTaskWithIdentifier:` / `_simulateExpirationForTaskWithIdentifier:` on a device
(debug builds only; private API, never shipped); Expo `triggerTaskWorkerForTestingAsync()` (dev
builds).

### Permission-denied flow

Maestro `launchApp: { permissions: { all: deny } }` and `setPermissions` mid-flow; Detox
`launchApp({ permissions })` (iOS only); `adb shell pm revoke <pkg> <perm>` (the OS kills the
process; the relaunch must re-check), `adb shell pm clear-permission-flags <pkg> <perm> user-set
user-fixed`, and `dumpsys package <pkg>` showing `USER_FIXED` for permanently denied; iOS
`xcrun simctl privacy booted revoke <service> <bundle>` [K]. Pass: the feature degrades in place,
the permanently-denied state shows a Settings path, nothing crashes or loops.

### Network never answers

A test server that accepts the connection and never responds: MSW with `delay('infinite')`,
OkHttp `MockWebServer` with a no-response socket policy [K name per version], a `URLProtocol`
stub that never calls back, a Dart `MockClient` returning a never-completing future. Assert the call
fails within the configured timeout (fake clock where the client allows it) and the error state with
a retry renders — not the loader.

### Link, push and OTA matrices

Links: `adb shell am start -W -a android.intent.action.VIEW -d "<url>" <pkg>` after a force-stop
(a true cold start is right here) and backgrounded; `xcrun simctl openurl booted "<url>"`; Maestro
`openLink`; Detox `launchApp({ newInstance: true, url })`. Push: FCM HTTP v1 send to the device token,
`xcrun simctl push booted <bundle> payload.apns`, Detox `sendUserNotification`; after logout, a send
to the old token shows nothing and the server receives `UNREGISTERED` (404). OTA: build binary B1,
add a native module and a JS call, publish with the same runtime version → under the `fingerprint`
policy the update is not offered; publish a tampered or wrongly signed update → rejected; publish one
that throws at first render → rolled back on next launch.

### Offline kill

Airplane mode (`adb shell svc wifi disable && adb shell svc data disable`, Maestro
`setAirplaneMode`), submit, background + `am kill`, relaunch, restore the network, and count the
records on the server: exactly one. The proxy variant (mitmproxy drops the **response** of the first
POST) proves idempotency.

### Native accessibility checkers (verified 2026-10-05)

- React Native: `@testing-library/react-native` 14.0.1 — `await render(<Screen />)` then
  `screen.getByRole('button', { name: 'Add to cart' })`; a nameless or role-less control throws (I, host).
- Flutter: `final handle = tester.ensureSemantics();` then
  `await expectLater(tester, meetsGuideline(androidTapTargetGuideline));` and likewise
  `iOSTapTargetGuideline` (44 × 44), `labeledTapTargetGuideline`, `textContrastGuideline`; `handle.dispose();`
  (docs.flutter.dev accessibility testing, updated 2026-05-05) (I, host).
- Compose: `androidx.compose.ui:ui-test-junit4-accessibility` (Compose 1.8.0 and later) —
  `composeTestRule.enableAccessibilityChecks()` then `composeTestRule.onRoot().tryPerformAccessibilityChecks()`
  (developer.android.com, updated 2026-09-22) (D; I where the project runs Robolectric).
- Views: `androidx.test.espresso:espresso-accessibility` 3.7.0 — `AccessibilityChecks.enable().setRunChecksFromRootView(true)`,
  on Accessibility Test Framework 4.1.1 (Google Maven, 2024-03-29) (D).
- iOS: `XCUIApplication().performAccessibilityAudit(for:_:)` — iOS 17 / Xcode 15 and later; audit types
  `contrast`, `elementDetection`, `hitRegion`, `sufficientElementDescription`, `dynamicType`, `textClipped`,
  `trait`, `action`, `parentChild`, `all` (D, simulator).
- Largest size: `adb shell settings put system font_scale 2.0`; iOS simulator
  `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` [K]; Flutter
  `MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(2.0)))` around the widget under test.

A host-runnable checker (RNTL, Flutter) runs without a device; the Compose, Views and iOS checkers need
an emulator or simulator, and without one the row is `SKIPPED (no device)`, never PASS.

### Performance oracles (verified 2026-10-05 unless marked)

- Render cost: Reassure 1.6.0 — `await measureRenders(<Screen />, { scenario })`, `reassure --baseline` on the
  base, `reassure` on the change; compare against `THR-PERF-REGRESSION` (I, host).
- Frames: Macrobenchmark `androidx.benchmark:benchmark-macro-junit4:1.5.0` with `FrameTimingMetric` on a
  release, profileable, non-debuggable build; Flutter `flutter drive --profile` with `traceAction` (D).
- Startup: Macrobenchmark `StartupTimingMetric` (`StartupMode.COLD`, `CompilationMode.None()` vs `Partial()`);
  `XCTApplicationLaunchMetric` (iOS 13+) in `measure(metrics:)`; `flutter run --profile --trace-startup` (D).
- Images: Flutter `debugInvertOversizedImages = true` in a widget test, assert no oversized-decode log line (I);
  a heap dump's bitmap total or `dumpsys meminfo` before and after (D).
- Leaks: LeakCanary 2.14 `DetectLeaksAfterTestSuccess` rule (I/D); XCTest
  `addTeardownBlock { [weak sut] in XCTAssertNil(sut) }` [K]; `leaks -atExit -- <cmd>` exits 1 on a leak
  (macOS man page); Flutter `LeakTesting.enable()` from `leak_tracker_flutter_testing` in
  `test/flutter_test_config.dart` (I); Jest fake timers — timer and listener counts are zero after unmount (I).

### Offline oracles

- Airplane mode: `adb shell svc wifi disable && adb shell svc data disable` (restore with `enable`); Maestro
  `setAirplaneMode: enabled`; iOS: Network Link Conditioner profile "100% Loss" on a device [K].
- Lost response: a proxy (mitmproxy) script that forwards the first POST to the server and kills the
  connection before the response reaches the app; or a mock server (MSW, `MockWebServer`
  `SocketPolicy.DISCONNECT_AFTER_REQUEST` [K], a `URLProtocol` stub) that records the request and then fails
  it. Assert the server-side count is 1 after the client's retry or replay.
- Rollback: the proxy or mock answers the optimistic mutation with 500 or 409; assert the screen shows the
  previous value and an error, and that a refetch in flight did not overwrite it.
- Identity switch: sign in as A, load data, queue one offline write, sign out, sign in as B; then inspect the
  screen, `adb shell run-as <pkg> ls databases files shared_prefs`, the simulator container
  (`xcrun simctl get_app_container booted <bundle> data`), and send a push to A's old token. On iOS also delete
  the app, reinstall it and launch: it must start signed out (Keychain items survive the uninstall). The web
  twin is § Accessibility and UI states, *Identity switch* (V123).
- Count, never assume: "exactly once" is a server-side count or a request log, not the absence of an error.

### Store probes

`apkanalyzer` needs a Java runtime and failed on a host without one, so `aapt2` is the primary Android probe.

- Android, on the release artifact (APK; for an AAB, `bundletool build-apks --mode=universal` first):
  `aapt2 dump badging app-release.apk | rg "targetSdkVersion|uses-permission"` [V];
  `zipalign -c -P 16 -v 4 app-release.apk` → `Verification successful` [V]; `check_elf_alignment.sh app-release.apk`
  or `llvm-objdump -p lib.so | rg LOAD` (`align 2**14` or higher) for each `arm64-v8a` / `x86_64` library;
  `apkanalyzer manifest print app-release.apk` where a Java runtime exists.
- iOS, on the archive or IPA: `plutil -p Payload/<App>.app/Info.plist | rg "DTXcode|DTSDKName|MinimumOSVersion"`
  (the Xcode and SDK that built it, the deployment target) [K]; `plutil -p Payload/<App>.app/PrivacyInfo.xcprivacy`
  and each `Frameworks/*.framework/PrivacyInfo.xcprivacy`; Xcode Organizer → the archive → Generate Privacy
  Report [K]; `codesign -d --entitlements :- Payload/<App>.app`.
- A probe on a stale build proves nothing about the change: record the artifact's build date beside the result.
- No artifact and no toolchain on the host → `SKIPPED (no build artifact)`; the row stays `[report-flagged]`
  with the probe written out, never PASS.

### Platform-convention capture and back-gesture probe

`device-harness` captures the screen on an API 35 and an API 36 emulator with gesture and 3-button navigation
(`adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton` / `…gestural` [K: overlay names per image]), the
keyboard up and down, and on a notched iOS simulator (`xcrun simctl io booted screenshot` [K]). Fail: a control's bounds intersect a
system-bar or gesture inset (read from the UI tree's bounds against the status-bar height, or from the screenshot). Back: on the API
36 emulator, make the screen dirty, send back — an edge swipe (`adb shell input swipe 0 <y> <x> <y>`) is the decisive variant;
`adb shell input keyevent KEYCODE_BACK` is a second one [K: whether an injected key takes the same predictive-back path as the
gesture is unverified] — and assert the guard's dialog in the tree. Flutter cheap first run:
`await tester.binding.handlePopRoute()` in a widget test asserts `PopScope` decides.

### Bridge contract test

Per module or channel: a host test compares the codegen schema (or the Pigeon definition) with the call sites; an instrumented build
(Android instrumented test, XCTest on a simulator [K], Detox, `integration_test`) calls each method once and asserts no
`undefined is not a function` / `MissingPluginException`; a native unit test forces each failure path and asserts the promise
rejects (or the result is `notImplemented`) within a bound; a sync method runs under StrictMode `penaltyDeath` / Main Thread
Checker (V162). A platform with no runtime on the host is `SKIPPED (no <platform> runtime)`.

### Release-artifact size delta

`./gradlew :app:bundleRelease`, then `bundletool build-apks` and `bundletool get-size total --apks=<app>.apks` [K] for the per-device
download size; `flutter build appbundle --analyze-size`; `EXPO_ATLAS=true npx expo export` + `npx expo-atlas .expo/atlas.jsonl`
(expo-atlas 0.4.3); iOS App Thinning Size Report from the archive export [K]. Before and after on the same toolchain; a debug or
universal-APK size against an AAB refutes the claim.

### Class variants (mobile)

#### V152. State lost on process death — process-death restore
- config change (rotation, dark mode, font scale, locale, fold or resize, multi-window); Android 16 ignores orientation locks at sw600dp+ (`targetSdk` 36)
- Don't keep activities; **background + `am kill` (mandatory)**; permission revoked while backgrounded
- the state of screen N−1, not only the top; a dialog or sheet open at kill time; cursor and focus; scroll position; an in-flight request at kill time (resumes or re-issues idempotently); saved-state size (`TransactionTooLargeException`)
- pass: input, position and selection restored on both platforms; no crash on restore

#### V153. Background work — scheduler trigger
- Doze; App Standby buckets; battery saver; no-network constraint; reboot; app update [K]; force-stop (jobs and alarms cancelled — must be re-scheduled on next launch)
- Android 15 `dataSync` budget reached → `onTimeout`; `BOOT_COMPLETED` start; exact-alarm permission revoked or not restored from backup
- iOS Low Power Mode; app swiped away (BG tasks wait for relaunch); a second `register` of the same id
- pass: the work runs, stops inside its budget, and never crashes the process

#### V154. Permissions — permission-denied flow
- first request; deny once; deny twice (permanent on Android 11+); "Only this time"; revoke in Settings while running; auto-reset after disuse; partial photos (Android 14, iOS limited); approximate location; upgrade from an older `targetSdk`; restore to a new device
- pass: no crash, no loop, a Settings path when permanently denied, a re-check on every use

#### V155. Network timeouts — network never answers
- connect never completes; headers never arrive; body stalls mid-stream; DNS hangs; a retry wrapper around the stalled call
- pass: fails within the timeout on every path; the error state and retry render; a write is not silently dropped

#### V156. Deep links — link matrix
- {cold, warm, hot} × {logged out, logged in, expired} × {valid, malformed, `javascript:`, foreign host} × {verified https, custom scheme}; a link received during splash or init
- pass: no crash; authed targets go through sign-in and then to the target; malformed input reaches a safe fallback

#### V157. Push — push matrix
- {foreground, background, terminated, killed by the system} × {notification, notification + data, data-only} × {before permission, denied, granted later} × token rotation (reinstall, restore, `deleteToken`) × account switch
- pass: shown and routed in every state the product promises; nothing shown for a logged-out account; the server prunes `UNREGISTERED` tokens

#### V158. OTA — OTA compatibility
- same runtime with a new native call; a tampered or unsigned update; a throw at first render; a throw after the recovery window; `NEVER` policy; rollback to the embedded bundle
- pass: incompatible updates are not offered, tampered ones are rejected, early crashes roll back

#### V159. Offline writes — offline kill
- kill during enqueue; during upload; after the server commit and before the ack; during a local migration; token expired while offline; clock skew; two devices; logout with a pending outbox (never replayed as the next account)
- the drain trigger itself: reconnect, app start, the platform scheduler; a queue filled on one screen and drained with that screen closed
- a payload written by the previous app version and read by this one (a migration, or a discard the user is told about)
- a row that can never succeed (a 4xx): it reaches a terminal state the user can see, and the rows behind it are not blocked forever
- pass: each write reaches the server exactly once, under the account that made it

#### V160. Native accessibility — native a11y checker
- the screen in each state (loading, empty, error, content); the largest font scale; dark theme; RTL; both platforms; an open dialog or sheet
- pass: no new checker violation; every interactive element has a name and role; targets meet 48 dp / 44 pt

#### V161. Render waste — render count (Reassure)
- an unrelated parent update; a list scroll; typing in a sibling input; with the React Compiler on and off when the project toggles it
- pass: render count and duration within the baseline's noise band (release build, repeated runs)

#### V162. Main-thread and concurrency — release-mode tripwire
- prefs `commit`, Room on main, `runBlocking` (including in an interceptor), sync `execute`, `Data(contentsOf:)`, `DispatchQueue.main.sync`, large JSON decode on main, Flutter `*Sync` IO
- pass: StrictMode `penaltyDeath` / Main Thread Checker / TSan silent along the path

#### V163. Store declarations — store probe
- the merged manifest (permissions, FGS types, exported components); `PrivacyInfo.xcprivacy` vs required-reason APIs; release entitlements (`aps-environment`, `get-task-allow`); 16 KB alignment (`zipalign -c -P 16 -v 4`)
- each dated gate in `store-compliance-scan` § The dated store gates, judged against the date of the run; the extension date where a store grants one
- library-injected permissions (the merged manifest, not the source); every embedded framework's privacy manifest; the Xcode and SDK recorded in the built app, not the one in the README
- pass: the shipped artifact carries every declaration the dated gate requires, cited "per the page as of <date>" with the page's URL and its last-updated date

#### V164. Native names and roles — name and role query
- every interactive element of the screen in each state (loading, empty, error, content); an open dialog or sheet; icon-only buttons; rows whose name should come from merged text; wrappers (`AppButton`, `Tappable`) and their call sites
- both platforms; RN touchables, Flutter `IconButton` / `GestureDetector` / `InkWell`, Compose `clickable` / `pointerInput`, Views image controls and touch listeners, SwiftUI icon-only `Button` and `onTapGesture`, UIKit image buttons
- pass: each element is found by role and name; no checker reports a missing name, description or trait

#### V165. Target size and text scaling — largest-size render
- the largest font scale (Android 2.0, iOS AX5) and display size; dark theme; RTL; landscape; both platforms
- every pinned scope: a root builder, a theme density, a global default, each fixed-size text; every small target, `hitSlop`-only enlargement, shrink-wrapped Material target and turned-off minimum
- pass: body text reaches 200 % without clipping; every target meets 44 pt / 48 dp (`THR-A11Y`); fixed-size marks are the only pinned text

#### V166. Grouping, gestures and announcements — name and role query + action + announcement
- every container that merges, clears or hides semantics; each swipe, drag or multi-finger action; each toast, banner, inline error and count that changes without focus moving
- pass: no interactive child is hidden; every gesture action is invocable through the accessibility API; every status change is announced or sits in a live region

#### V167. Contrast — native a11y checker
- light and dark themes; disabled, pressed and focused states; text over images; the error colour on its surface
- pass: text ≥ 4.5 : 1 (3 : 1 large text and non-text) by the platform checker on a render; no render, no pass

#### V168. Lists and render waste — frame and render cost
- 0, 1, 20 and 200+ rows; a reorder, insert and filter (row state stays with its item); an unrelated parent update; a scroll; typing in a sibling input; with the React Compiler on and off when the project toggles it
- pass: the list is virtualized; identity holds across reorder; render count and duration within `THR-PERF-REGRESSION`, release or profile build

#### V169. Image decode — oversized-decode log
- list thumbnails from camera and remote photos; a GIF or animated image in a list; the image cache under a long scroll; a CDN-resized URL; a zoom viewer
- pass: no decode above display size × scale in a list; every in-memory image cache is bounded

#### V170. Startup — startup metric
- cold, warm and hot start; first launch after install; with and without a baseline profile (`CompilationMode.None()` vs `Partial()`); the slowest device class in scope
- pass: time to initial display within the project budget on a release build, with n and the spread reported; work not needed for the first useful frame is deferred

#### V171. Leaks — leak assertion
- open and leave the screen repeatedly; rotate; background and return; each listener, observer, receiver, timer, display link, controller, subscription, stored closure, delegate, fragment binding and static reference on the screen
- pass: the destroyed owner is collected (LeakCanary, weak teardown, `leaks` exit 0, `leak_tracker` clean); listener and timer counts return to zero after unmount

#### V172. Replay identity — lost-response replay
- the first response dropped after the server commits; a timeout before the server answers; the app killed between send and response, then the queue replayed on next launch; two devices replaying one shared queue; a retry wrapper (axios-retry, dio_smart_retry, WorkManager backoff) around the call
- pass: one record per user action on the server, on every path; the key on the retry equals the key on the first attempt

#### V173. Identity bleed — identity switch
- sign-out with an empty queue and with a non-empty queue; account switch without sign-out; token expiry while offline; a fresh install after an uninstall (iOS Keychain); every cache the root uses: query cache, persisted state, local DB, files and images, WebView cookies, scheduled work, push token
- pass: B sees none of A's data; A's queued writes are never sent under B's session; a fresh install starts signed out

#### V174. Conflict policy — conflict and rollback
- the server rejects the optimistic write (409, 422, 500); a background refetch lands while the mutation is pending; two devices edit one record offline then sync; a device clock set a day ahead
- pass: the screen rolls back and says why; the entity's written policy holds (server-wins, versioned reject, merge or prompt); a skewed clock changes nothing

#### V175. Store-required flows — store flow walk
- account deletion: from the account screen, signed in with each provider the app offers (email, Google, Sign in with Apple), with an unpaid order or an active subscription; Play's web deletion link opened from a browser
- tracking: a fresh install with tracking denied and with it allowed; no ad-ID or attribution request before the prompt is answered (proxy log)
- purchases: a fresh install on a second device, then Restore; a refunded or expired subscription
- pass: deletion completes or tells the user its timeline; no tracking traffic before consent; owned items come back on restore

#### V176. Edge-to-edge and safe area — platform-convention capture
- API 35 and API 36 emulators; gesture and 3-button navigation; keyboard up and down; landscape; a notched iOS simulator; the largest font; every screen with a bottom-pinned action or a custom top bar; screens behind the edge-to-edge opt-out
- pass: no control or text under a bar, the gesture area, the notch, the home indicator or the IME on either platform

#### V177. Back handling — back-gesture probe
- every screen whose back guard lived in `onBackPressed`, `onKeyDown(KEYCODE_BACK)`, `WillPopScope`, `Form.onWillPop`; with the temporary opt-out on and off; a nested navigator; a dialog open; iOS edge swipe on screens that hid the system back button
- pass: the guard runs on the gesture on Android 16 at target 36; nothing leaves a dirty screen silently; iOS swipe-back works or an equivalent exit exists

#### V178. Native boundary — bridge contract test
- every module and channel; every method; each platform the app ships (an absent platform folder is SKIPPED, never PASS); the error path, the cancel path and an unknown method; a sync method with cold caches; module teardown on reload
- pass: called = answered on every platform; every promise or future settles exactly once within its bound; no tripwire fires; nothing acquired at the boundary outlives teardown

#### V179. App size — release-artifact size delta
- AAB per-device download size and the APK if one is distributed; the IPA thinned for the smallest and largest device in scope; the JS / Dart bundle; each ABI; two consecutive builds
- pass: the claimed bytes are gone on the artifact the store receives; the release smoke test on a device passes (shrinking on can strip a reflected class)

### Sources (mobile)

The taxonomy and V152–V179 come from the mobile research notes for this batch (2026-10-05) and the
mobile pack builders' passes: the checker and performance tool versions were verified against primary
sources on 2026-10-05 (`@testing-library/react-native` 14.0.1, the Flutter accessibility-testing page
updated 2026-05-05, the Compose accessibility-checks page updated 2026-09-22, espresso-accessibility
3.7.0 on ATF 4.1.1, Reassure 1.6.0, Macrobenchmark 1.5.0, LeakCanary 2.14, the macOS `leaks` man
page, expo-atlas 0.4.3); the Android 15 and 16 behaviour facts are from developer.android.com's
behaviour-change pages (updated 2026-10-01); the `aapt2` and `zipalign` probes were run against a real
release APK with build-tools 36.0.0. Rows tagged [K] were not re-verified. Paraphrased; no text
reproduced.

## SEO

A technical-SEO claim says a crawler that runs no JavaScript receives the wrong thing from the
server: a `noindex` on a route meant to rank, the layout's title on every post, a canonical carrying
`?utm_source=`, an empty `<div id="root">`. A browser, a unit test and a lint run never see the
server HTML, so none of them is the oracle. The oracle is the **server HTML of a production build**,
fetched as a crawler fetches it. A class is graded only on the route classes `seo-audit` assigns it
to (its § Route class decides which classes run: indexable · public, not meant to rank · auth-gated ·
not a document); a row with no route class is not graded. Settled questions are in [`precedents/seo.md`](precedents/seo.md). Users:
`seo-audit` (frontend pack), judged by `@technical-seo`, and `/frontend-fix`.

### Oracle taxonomy (SEO)

| Oracle | Asserts | Classes |
|---|---|---|
| **Server HTML (`seo-head.py`)** | The finding's row (`title-dup`, `canonical-tracking`, `noindex`, `hreflang-not-reciprocal`, …) prints for the route set before the fix and is gone after it, on the same routes | V180–V188 |
| **Rendered vs server text** | The server HTML's visible body text agrees with the rendered page's; a route whose content arrives only by script is a client-only shell | V187 |
| **Two user agents** | The head is the same under `--ua=googlebot` and `--ua=facebook`; on Next.js, no metadata is streamed into `<body>` for the agent that reads it | V180, V182 |
| **Robots and sitemap sampling** | `robots.txt` blocks no render asset and names a sitemap; each sitemap is absolute and within the limits, and a sample of its `<loc>` URLs answers 200 with no `noindex` | V184, V185 |

### Server HTML (`seo-head.py`)

`seo-head.py` ships with `seo-audit` (installed as `.claude/skills/seo-audit/scripts/seo-head.py`): Python 3
standard library, read-only — GET requests only, no file written.

```bash
python3 .claude/skills/seo-audit/scripts/seo-head.py --self-test
python3 .claude/skills/seo-audit/scripts/seo-head.py --base=http://localhost:3000 --routes=/,/blog/a,/blog/b,/en/shoes,/ar/shoes --expect-index=/,/blog/,/en/,/ar/ --robots
python3 .claude/skills/seo-audit/scripts/seo-head.py --html=dist/browser/index.html --expect-index='*'   # a static or prerendered build
```

Fetch a **production** build — `next build && next start`, `nuxi build && node .output/server/index.mjs`,
`vite build && vite preview` (plus the prerender output), `astro build && astro preview`, `ng build` with its
SSR server or the built `index.html`. A dev server's HTML is not what ships. Exit 0 is no finding, 1 is at
least one finding, 2 is a usage, fetch or parse error — never read as clean. `--expect-index` names the route
prefixes meant to rank: a `noindex` there is a finding; elsewhere it is printed as a fact.

The rows, by `seo-audit` class: §1 `title-missing`, `title-multiple`, `title-dup`, `desc-missing`, `desc-dup`,
`meta-in-body` · §2 `canonical-missing`, `canonical-multiple`, `canonical-relative`, `canonical-in-body`,
`canonical-tracking` · §3 `og-missing`, `og-image-relative`, `twitter-card-missing` · §4 `jsonld-invalid` ·
§5 `noindex`, `status` · §6 `robots-disallow-all`, `robots-disallow-assets`, `robots-no-sitemap`,
`sitemap-relative-loc`, `sitemap-over-limit`, `sitemap-loc-bad` · §7 `hreflang-code`, `hreflang-relative`,
`hreflang-self-missing`, `hreflang-x-default-missing`, `hreflang-not-reciprocal` · §8 `csr-shell` ·
§9 `h1-count`. **Candidates** print without changing the exit code and each needs a read:
`jsonld-no-rich-result`, `canonical-elsewhere`, `anchor-generic`, and `meta-in-body` / `canonical-in-body` on a
Next.js page.

**Fails first:** the row prints for the cited route before the fix and is gone after it, on the **same route
set** — every route template, not the one example (list, detail, article, category; every locale for §7).
Google's Rich Results Test and Search Console URL Inspection (the rendered HTML Google stored) are manual rows,
reported `manual-required`.

### Rendered vs server text

`await page.goto(url)`, wait for the route's own content marker (`networkidle` only when the route has none),
then `(await page.locator('body').innerText()).length`, set beside the oracle's `text_chars` column for the same
route. Server text under `--min-text` (200 visible characters by default) while the rendered page shows the
content is `csr-shell`. Report it first: on that route, the §1–§4 and §7 rows grade tags a crawler that runs no
JavaScript never reads, so they wait for the rendering fix (`ssr-audit`, the `rendering-strategy` pattern).

### Two user agents

`--ua=googlebot` (the default) and `--ua=facebook`. Next.js streams `generateMetadata` output into `<body>` for
user agents it does not list as HTML-limited bots and keeps it in `<head>` for those on its `htmlLimitedBots`
list (Next.js docs, *generateMetadata*, 16.3.8, updated 2026-08-25): run both agents and compare.
`meta-in-body` / `canonical-in-body` on a Next page is a candidate settled by URL Inspection. Social scrapers
run no JavaScript, so social cards are graded on the `facebook` run.

### Robots and sitemap sampling

`--robots` fetches `/robots.txt` and up to five sitemaps it names (else `/sitemap.xml`). It checks
`Disallow: /`, a `Disallow` on the asset folders the pages render with (`/_next/`, `/_nuxt/`, `/assets/`), the
`Sitemap:` line, absolute `<loc>` values and the 50,000-URL / 50 MB limit, then fetches a sample of `<loc>` URLs
(`--sitemap-sample=20` by default): each must answer 200 with no `noindex` in the header or the meta. A sitemap
index is checked for its limits, but its children are not sampled: name a child sitemap's routes with
`--routes` to cover them.

### Class variants (SEO)

#### V180. Title and description — server HTML, two user agents (`seo-audit` §1)
- a route file with no metadata of its own inheriting the layout's; one literal title in two metadata files; a project wrapper's fallback description; a React `<title>` with text and an expression as two children
- every route template; both user agents on Next.js (`meta-in-body`)
- pass: one title and one description per indexable route, unique across the route set, in `<head>` for both agents

#### V181. Canonical — server HTML (§2)
- a canonical built from the request URL (it keeps `?utm_source=` and every filter); a relative canonical with no `metadataBase` or site URL; two canonicals by two methods; a canonical in `<body>`; trailing-slash, `www` and `http` variants
- pass: one absolute canonical in `<head>`, self-referencing or deliberately elsewhere, with no tracking parameters

#### V182. Social cards — server HTML under `--ua=facebook` (§3)
- articles, products and the home page; the layout's default image; a relative `og:image`; a client-only tag on an SPA
- pass: `og:title`, an absolute `og:image` and `twitter:card` in the server HTML of every shareable route

#### V183. Structured data — server HTML, Rich Results Test (manual) (§4)
- a block that does not parse (the whole block is ignored); a property the page does not show (`aggregateRating` with no visible rating); a type that does not match the page
- FAQ, How-to and `SearchAction` markup (candidates, Hardening); JSON-LD written with `JSON.stringify` into a raw `<script>` (`xss-scan`, security pack, when installed)
- pass: every block parses, its type matches the page, and every property describes visible content

#### V184. Indexable route blocked, or a private route left open — server HTML, robots sampling (§5)
- a layout-level `robots: { index: false }` left from staging; a `noindex` added or removed by script; an `X-Robots-Tag` from a route rule or the host; a `noindex` route that robots.txt also disallows; an admin route with no auth gate and no `noindex`; a non-200 status on an indexable route
- pass: no `noindex` and status 200 on every `--expect-index` route; must-not-rank routes that are server-rendered and reachable carry `noindex` in the first HTML or sit behind an auth wall

#### V185. Sitemap and robots.txt — robots and sitemap sampling (§6)
- `Disallow: /`; a `Disallow` on `/_next/`, `/_nuxt/` or `/assets/`; no `Sitemap:` line; a hand-written sitemap that lists only static pages; a relative `<loc>`; over 50,000 URLs or 50 MB; a sampled `<loc>` that answers non-200 or carries `noindex`
- pass: render assets crawlable, a sitemap named and generated from the dynamic routes, every sampled `<loc>` 200 and indexable

#### V186. hreflang — server HTML on every locale (§7)
- an invalid code (`en-uk`, `en_US`); a relative URL; a version that omits itself; no `x-default`; a set that is not reciprocal across the fetched locales
- pass: every localized URL lists every version and itself, with absolute URLs and valid codes, plus `x-default`

#### V187. Client-only content on a route that must rank — rendered vs server text (§8)
- `ssr: false` / `export const ssr = false`; Angular `RenderMode.Client`; a Vite SPA with no prerendering; a Next page that fetches its content in an effect; every indexable route template
- pass: the server HTML carries the content (`text_chars` at or above `--min-text`) and agrees with the rendered text; the fix is a rendering change, never a client-side tag

#### V188. Discoverable views and link signals — server HTML (§9)
- hash routing (`#/`); an indexable target reachable only through a click handler (`routing-scan` §1, V125); zero or several `<h1>`; a generic anchor (`click here`, `read more`) as the only link to its target
- pass: History-API routes, a real `<a href>` to every indexable target, exactly one `<h1>` per indexable route

### Sources (SEO)

`seo-audit` (frontend pack) and its `scripts/seo-head.py`, written 2026-10-05, and the pages that skill read
and dates: Google Search Central — *How to specify a canonical URL* (updated 2026-07-10), *JavaScript SEO
basics* (2026-03-04), *Block indexing with noindex* and *Introduction to robots.txt* (2025-12-10), *Build and
submit a sitemap* (2026-07-08), *Tell Google about localized versions* (2026-09-21), the search gallery
(2026-06-15) and the Search Central blog of 2023-08-08 on FAQ and How-to results; the Next.js
*generateMetadata* page (16.3.8, 2026-08-25); react.dev *title*. Paraphrased; no text reproduced.

## Observability

An observability claim says a signal will fail on-call during a real incident: the error is logged
without its stack, the request id collides across replicas, the trace breaks at the queue, the page
rule can never fire, the critical alert routes to a null receiver, the burn rule's factor does not
match its objective. Reading the code does not settle any of these, because the signal is only what
the logger, exporter, registry, rule evaluator or route tree actually emits. The oracle drives the
failure through the real entry point (or the real rule evaluation) and asserts on the **emitted**
signal. Every oracle names a **tier**: T (a tool's exit code), U (a test with log capture, an
in-memory span exporter, the metrics registry or a tracker test transport), L (a live backend), S (a
static trace). **An L-tier class with no reachable backend is `NO-DATA(<source>)`, never PASS**, and
its static half (inventory grounding) still runs. Three rules hold for every variant below:

- **Read the version first.** The Prometheus and Alertmanager majors, the logger and SDK majors and
  the semconv opt-in are read from files (gate 3); a promtool test runs on the binary of the
  server's Prometheus major.
- **Ground every name.** A metric, label or log field a test, rule or fix names must resolve in the
  repo inventory (metric names registered in code, recording-rule outputs, exporter defaults, the
  logger's fields) or a live series call; a mocked series never proves a metric exists
  ([`precedents/observability.md`](precedents/observability.md) § 16, § 37).
- **Tools run on copies.** Every tool runs in `${TMPDIR:-/tmp}` on a copy. `mimirtool rules lint`
  without `-n`, `lokitool rules lint` without `--dry-run` and `dashboard-linter lint --fix` rewrite
  in place and never run in the project tree; pint 0.89.2 `lint` left every file byte-identical
  (measured 2026-10-10) and runs on copies all the same.

Settled questions are in [`precedents/observability.md`](precedents/observability.md). Users:
`log-signal-scan`, `trace-propagation-scan`, `metric-hygiene-scan`, `error-tracking-scan`,
`alert-rule-lint`, `slo-rule-scan` and `telemetry-config-scan` (observability pack), judged by
`@observability-reviewer`, and `/obs-fix`. The redaction variant list (every logger, sink, span
attribute, breadcrumb, access log, crash dump and metric label a seeded canary must be absent from)
is security's: `data-exposure-scan` § 6, cited, not restated here. A fix that touches a logger, a
serializer or a sink re-runs that canary.

### Oracle taxonomy (observability)

| Oracle | Tier | Asserts | Classes |
|---|---|---|---|
| **Captured log** | U | The line the failure emits, captured from the logger's real destination and parsed, carries the error type, message and a stack frame, at the expected level, with the request and trace ids | V189–V193 |
| **Fault injection** | U | A handled failure (a dependency error, a timeout, a fallback taken) produces a log at ≥ warn, **or** a counter +1, **or** a span `exception` event | V190 |
| **In-memory span exporter** | U | One traceId with correct parentage (or a span link) across the hop; finished spans; `status=ERROR` plus an exception event on failure; resource `service.name` ≠ `unknown_service*` | V194–V197 |
| **Registry scrape** | U | After randomized ids and paths the series count is bounded and holds only route templates; durations land in finite buckets; a bucket edge exists at each SLO threshold; each entry point observes a counter and a duration | V198–V201 |
| **Tracker test transport** | U (L for symbolication) | The event the SDK sends carries `release` and `environment`; an unhandled rejection and a boundary 500 reach it | V202 |
| **promtool rule test** | T | One test fires at the failure point and one stays silent at a blip; annotations render; a total outage is not silent | V203, V204 |
| **pint and the rule inventory** | T | Per rule, never per file: `alerts/for`, `alerts/annotation`, `alerts/template`, `alerts/comparison`, `promql/counter`, `promql/rate`, `promql/nan`, `alerts/absent`, `promql/impossible`; offline, or `rule-inventory.py --check=…` when pint is not installed | V203, V204 |
| **Routes matrix** | T (L for inhibition) | Every emitted {severity × team} label set reaches the receiver the design names; `amtool config routes test --verify.receivers` exits 1 on mismatch | V206 |
| **Vendor no-data check** | S (L for an export diff) | Each alerting tool has one no-data mechanism per signal | V205 |
| **Regenerate and diff** | T | `sloth generate` / `pyrra generate` from the committed spec diffs empty against the committed rules; the burn arithmetic holds | V207 |
| **Pipeline validate + key diff** | T + S | `otelcol-contrib validate` exits 0, no component is defined but unreferenced, `memory_limiter` is first and `batch` last; shipper and Loki configs validate with both retention keys; each loaded dashboard has 0 error rows under the scoped linter rules | V208 |
| **Weaver live-check** | T | Emitted attributes pass the semconv registry: no `deprecated`, `missing_attribute` or `type_mismatch` violation | V194 |
| **Live series** | L only | `count(<selector>) > 0` on the running server; label cardinality from the TSDB or `logcli series --analyze-labels` | V198, V204 |

### Captured log

Drive the failure through the real entry point (`fastify.inject`, supertest, a job handler called
with a real job object), capture the logger's own destination, parse each line, and assert on the
emitted fields. A test that spies on the call arguments proves what was passed, not what was
written; use it only for a façade that has no destination of its own (the Nest `ConsoleLogger`).

| Stack | Capture | Assert (fails first on an LG-02 line) |
|---|---|---|
| **pino + Fastify 5** | `const lines = []; const logger = pino({ level: 'info' }, { write: (s) => lines.push(JSON.parse(s)) });` then `Fastify({ loggerInstance: logger })` (Fastify 5 takes a pino instance through `loggerInstance` [K?: read the installed major]) | `const e = lines.find((l) => l.level === 50); expect(e.err.type).toBeDefined(); expect(e.err.stack).toMatch(/\n\s+at /);` |
| **nestjs-pino** | `LoggerModule.forRoot({ pinoHttp: [{ level: 'info' }, stream] })` in the testing module, with `stream` the same `{ write }` collector, then `app.useLogger(app.get(Logger))` | same assertion on the parsed line; run `error(msg, err)`, `error(err)` and `error(msg, err.stack)` once each to settle what the installed version emits [K?] |
| **Nest `ConsoleLogger`** | `class Capture extends ConsoleLogger { calls: unknown[][] = []; error(...a: unknown[]) { this.calls.push(a); } }`, `app.useLogger(capture)` | a call carries the stack string as its second argument (precedents § 38), or a JSON line under `json: true` carries it [K?] |
| **winston 3** | a `new winston.transports.Stream({ stream })` transport on the app's own logger (keep its `format`) | the parsed line has `stack`; without `format.errors({ stack: true })` it is `{"level":"error"}` |
| **Python logging / structlog** | pytest `caplog`; `structlog.testing.capture_logs()` | `caplog.records[-1].exc_info is not None` (or `exc_text`); the structlog entry carries `exc_info` / `exception` |
| **Go slog / zap** | `slog.New(slog.NewJSONHandler(&buf, nil))` then decode `buf`; `core, logs := observer.New(zap.ErrorLevel)` (`zaptest/observer`) | the `error` field is the error value, not a `%v` string with the context stripped; for zap, `logs.All()[0].ContextMap()["error"]` is present |
| **Logback** | `ListAppender<ILoggingEvent> app = new ListAppender<>(); app.start();` added to the class's `ch.qos.logback.classic.Logger` | `app.list.get(0).getThrowableProxy()` is not null |
| **.NET** | `FakeLogger<T>` (`Microsoft.Extensions.Diagnostics.Testing`) | `logger.Collector.LatestRecord.Exception` is not null and the level is `Error` |

**Level (V192):** drive a 404, a validation failure and a 500 through the same entry point; assert
the 404 and the validation failure log at ≤ warn, the 500 at error, and the 500 logs **once** per
request (`THR-LOG-LEVEL`). **Correlation (V193):** fire two requests concurrently and one job they
enqueue; every captured line carries its own request id, the two ids differ, the job's lines carry
the originating id or `trace_id`, and with tracing on, the log `trace_id` equals the exporter's
traceId for that request. **Volume (V192, V201):** count bytes per request against the budget and
lines per probe hit (expected 0).

### In-memory span exporter

| Stack | Exporter |
|---|---|
| **JS** | `InMemorySpanExporter` + `SimpleSpanProcessor`, passed as `spanProcessors: [...]` to the tracer provider (SDK 2.x removed `addSpanProcessor` [K?: read the installed major]); `exporter.getFinishedSpans()` |
| **Python** | `InMemorySpanExporter` (`opentelemetry.sdk.trace.export.in_memory_span_exporter`) + `SimpleSpanProcessor`; `get_finished_spans()` |
| **Go** | `sr := tracetest.NewSpanRecorder()`; `sdktrace.NewTracerProvider(sdktrace.WithSpanProcessor(sr))`; `sr.Ended()` |
| **Java** | `InMemorySpanExporter.create()` (`opentelemetry-sdk-testing`) + `SimpleSpanProcessor` |
| **.NET** | `AddInMemoryExporter(list)` on the `TracerProviderBuilder` |

Drive **HTTP → enqueue → consume** (or HTTP → outbound call, or the async hop the class is about)
and assert: one traceId across every span of the flow, each child's parent is the span that caused
it (or the consumer span carries a link to the producer's context); no span is left unfinished; on
the failure path `status=ERROR` plus an `exception` event; span names come from a closed set
(route templates, not ids); the resource's `service.name` is set. **SIGTERM flush (V196):** spawn
the real process with its OTLP endpoint pointed at a local sink (a Weaver live-check or a
throw-away HTTP receiver), serve one request, send SIGTERM, and assert the sink received the last
span and the last log line. **Sampling (V197):** read the resolved sampler (its description names
`ParentBased`), then send N error traces through the configured ratio and the collector config, and
count the retained ones against the stated requirement.

### Registry scrape

prom-client `await register.metrics()`; Python `generate_latest(REGISTRY)`; Go
`testutil.CollectAndCount(c, "name")` and `testutil.ToFloat64`; Micrometer `SimpleMeterRegistry`.
Hit the entry point with 100 random ids and paths, then assert the metric's series count stays at
the number of route templates × the bounded label values (`THR-OBS-CARDINALITY`), and that no label
value is a raw path, id or error string. Pipe a scrape through `promtool check metrics` (exit 3 is a
naming lint, exit 1 an error). **Units and buckets (V199):** observe one known duration and assert
it lands in the finite bucket its seconds value belongs in (a ms value lands in `+Inf`), and that
`x_bucket{le="T"}` exists for each SLO threshold T. **Coverage (V200):** run each job, consumer and
cron handler once and assert its counter (with an outcome label) and duration moved. **Health
(V201):** stop the dependency; `/readyz` answers 503 while `/livez` stays 200; restore it and
readiness recovers; 100 probe hits leave span, log-line and RED-series counts unchanged.

### Tracker test transport

Initialise the SDK with a `beforeSend` / `before_send` hook that records the event and drops it
(returns `null` / `None`), or the SDK's own test transport. Assert the recorded event carries
`release` and `environment` (V202), that an unhandled rejection raised in a spawned child of the
real process type (API, worker, cron) reaches it, and that a boundary handler mapping to 500 sends
one. Symbolication (ET-03) is L-tier: one event in the backend shows resolved frames; without a
backend the row is `NO-DATA(tracker)` with the upload written out (`sentry-cli sourcemaps inject
<dist> && sentry-cli sourcemaps upload --release <release> <dist>`, sentry-cli 3.x — `sourcemaps
explain` no longer exists, precedents § 49).

### promtool rule test

Copy the rule files to `${TMPDIR}` and write one test file per page-tier rule. Each needs a test
that **must fire** at the failure point and one that **must stay silent** at a blip; a ratio rule
also needs a total-outage test, where its traffic-absent sibling must fire.

```yaml
rule_files: [rules/api.yml]
evaluation_interval: 1m
tests:
  - interval: 1m                       # sustained failure: must fire
    input_series:
      - series: 'http_requests_total{job="api",code="500"}'
        values: '0+10x30'
      - series: 'http_requests_total{job="api",code="200"}'
        values: '0+90x30'
    alert_rule_test:
      - eval_time: 20m
        alertname: ApiHighErrorRate
        exp_alerts:
          - exp_labels: { severity: page, job: api }
  - interval: 1m                       # one bad minute: must stay silent
    input_series:
      - series: 'http_requests_total{job="api",code="500"}'
        values: '0 0 0 40 40 40 40 40 40 40'
      - series: 'http_requests_total{job="api",code="200"}'
        values: '0+90x9'
    alert_rule_test:
      - eval_time: 9m
        alertname: ApiHighErrorRate
        exp_alerts: []
```

This is the shape only: take the series, `eval_time` and windows from the rule itself, and keep the blip shorter than the rule's `for`. `promtool test rules <file>` exits non-zero on any mismatch. Add `exp_annotations` to prove the
annotations render with the labels the expression keeps (AL-05). Run it with the binary of the
server's major: Prometheus 3 makes ranges left-open and normalizes `le`, so a test that passes on
2.x can fail on 3.x (precedents § 45). The input series are mocked, so a passing test never proves
the metric exists (precedents § 16): pair it with the selector grounding below.

### pint and the rule inventory

`pint --offline lint <copy-of-rules>` in `${TMPDIR}`; online checks (`promql/series`) only with a
Prometheus URL the user gave. Without pint, `rule-inventory.py` (stdlib, shipped with
`alert-rule-lint`) emits one JSON row per rule — name, file:line, group, `for`, `keep_firing_for`,
labels (group labels version-gated, precedents § 41), annotation keys, metric tokens, range windows
and functions — and checks them with `--check=annotations,for,windows,selectors,prom3,value-in-labels,nan,absent,watchdog`;
`--self-test` proves the parser. `--check=selectors` diffs every selector against the inventory: a
selector that resolves nowhere is a never-fire candidate (HIGH Unconfirmed until a live
`count(<selector>)`), and a rule file matched by no `rule_files` glob, or a PrometheusRule whose
labels miss the Prometheus CR `ruleSelector`, is never loaded.

### Routes matrix

`amtool check-config am.yml`, then one case per {severity × team} label set the rules actually emit:
`amtool config routes test --config.file=am.yml --verify.receivers=<expected> severity=page team=payments`.
Without `--verify.receivers` amtool exits 0 whatever it resolves, so that is not a test. Inhibition
and mute timing cannot be proven from the route tree: they need a containerised Alertmanager with
`amtool alert add` and `amtool alert query` (L).

### Regenerate, validate and diff

- SLOs: `sloth generate -i <spec> -o "$TMPDIR/out.yml"` (or `pyrra generate --config-files='<specs>' --prometheus-folder="$TMPDIR/pyrra/"`), then `diff -u <committed> <generated>`: empty, or the drift is the finding. `burn-check.py` (shipped with `slo-rule-scan`) checks `factor = budget_fraction × period / long_window` and the short window = long/12 against the accepted sets in `THR-OBS-BURN` (Workbook 30d: 2 % × 720h / 1h = 14.4; 5 % × 720h / 6h = 6; 10 % × 720h / 72h = 1; the 4th tier 10 % × 720h / 24h = 3; Pyrra 14/7/2/1 on 28d-scaled windows).
- Collector: `otelcol-contrib validate --config=file:<copy>` (exit code), plus the two checks it skips: components defined under `receivers` / `processors` / `exporters` / `connectors` but referenced by no `service.pipelines.*`, and processor order (`memory_limiter` first, `batch` last).
- Shippers and stores: `alloy validate <cfg>`, `vector validate --no-environment <cfg>`, `fluent-bit -c <cfg> --dry-run`, `loki -config.file=<cfg> -verify-config -config.expand-env=true`, `refinery -c <cfg> -r <rules> --validate`.
- Dashboards: `dashboard-linter lint --strict <dashboard.json>` (non-strict exit behaviour is [K?]).
- Semconv: start `weaver registry live-check --format json -o <out> --fail-on violation`, point the app's OTLP exporter at it, drive the test traffic, send SIGHUP, read the exit code.

### Class variants (observability)

#### V189. Error object or stack lost — captured log (`log-signal-scan` §2)
- pino `error(msg, err)`, `{ error: err }` with no `error` serializer, `err.message`, `String(err)`, `` `${err}` ``, `` `${(err as Error).message}` ``; winston with no `format.errors`; Nest `error(err)` vs `error(msg, err.stack)` (precedents § 38 is the control)
- Python `logger.error(str(e))`, `logger.warning(e)`, structlog `error=str(e)`, a loguru f-string; Go `%v`, `errors.New(err.Error())`, `zap.String("err", err.Error())`, `slog.String`, logrus `WithField`
- Java concatenation, `getMessage()`, `printStackTrace`, a cause-less rethrow; C# `ex.Message`, `$"{ex}"`, `throw ex;`; Ruby `e.message`, stdlib `logger.error(e)`; PHP `getMessage()`, `['error' => …]` instead of `['exception' => $e]`
- every logger factory and wrapper the repo has, not the one call site
- pass: the captured line carries the error type and a stack frame at error level on every variant; the healthy path logs nothing at error

#### V190. Handled failure invisible — fault injection (`log-signal-scan` §1)
- a default or empty return, a retry, a fallback to a cache; a debug- or trace-only log; `contextlib.suppress`; `.catch(() => fallback)`; a Go `if err != nil { return def }`
- payment, auth and consumer paths first; CQ's V74 owns the *dropped* variant
- pass: the injected fault yields a log at ≥ warn, a counter +1 or a span exception event; the degrade stays the documented behaviour

#### V191. Unstructured or stdout logging in production — linter + stable template (`log-signal-scan` §3)
- every interpolation form per stack (template literal, f-string, `%` format, concatenation, `fmt.Sprintf` into the message); `console.*`, `print`, `puts`, `var_dump`, `System.out`, `Console.Write`, `fmt.Print` in server roots; an odd key-value count; zerolog with no `Msg` / `Send`
- a Nest bootstrap with no `useLogger` / `bufferLogs`; `pino-pretty` with no environment guard
- pass: the linter rule at error is clean, and two calls with different data emit the same message template with the data in fields

#### V192. Level misuse and volume — captured log (`log-signal-scan` §4–§5)
- an error logged at info or debug inside a catch; a 4xx or validation failure at error; log-and-rethrow at every layer; pino-http / nestjs-pino with no `customLogLevel`
- debug in every production-loaded config (`level`, `root`, `LOG_LEVEL`, `"Default"`, `DEBUG=True`, `log_level`) — read which file production loads (precedents § 30)
- a full payload serialized into a log call; a log call inside a request-path loop
- pass: 404 and validation at ≤ warn, 500 at error, one log per error per request, bytes per request within budget

#### V193. Correlation — two concurrent requests + one async hop (`log-signal-scan` §6–§8)
- request-id middleware present **and** unique across replicas (no per-process counter: pino-http's default, precedents § 52); an upstream id honoured
- every logger bound to context: handlers, services, background jobs, queue consumers, cron; MDC cleared after the request and propagated to `@Async` and executors; `threading.local` under asyncio
- `trace_id` / `span_id` injected under the snake_case names (`instrumentation-pino` / `-winston`, `OTEL_PYTHON_LOG_CORRELATION`, the otelslog bridge, the Java agent)
- pass: every captured line carries its own request id, the job's lines carry the originating id, and the log `trace_id` equals the exporter's traceId

#### V194. Async, queue and outbound propagation — in-memory exporter (`trace-propagation-scan` §1–§3, §7–§8)
- every hop kind the repo has: goroutine, executor, thread pool, `run_in_executor`, coroutine, `setInterval` / emitter
- each queue client (Kafka, RabbitMQ, SQS, BullMQ, Celery, Sidekiq, NATS): producer inject **and** consumer extract
- each outbound client (fetch, axios, `requests` / `httpx`, `net/http`, OkHttp, `HttpClient`) and every wrapper that rebuilds headers from an allow-list
- span names from a closed set; deprecated semconv names (Weaver live-check)
- pass: one traceId end to end (or a link) with correct parentage on every hop

#### V195. Span lifecycle — in-memory exporter (`trace-propagation-scan` §4)
- end on every exit path: early return, throw, `defer`, `finally`; `recordException` + `setStatus(ERROR)` in every catch that owns a span (precedents § 25 is the Python control)
- pass: the exporter shows every span finished, and the failing path's span with ERROR and an exception event

#### V196. SDK init, identity and flush — first-request spans + SIGTERM (`trace-propagation-scan` §5–§6)
- CJS `--require`, ESM `--import` + the loader hook, `NODE_OPTIONS` in the Dockerfile, Procfile and compose; Gunicorn `post_fork` with a batch processor; the SDK imported before `@nestjs/core` / `fastify`
- `service.name` per service; one propagator set across services (`OTEL_PROPAGATORS`)
- `sdk.shutdown()` / `tp.Shutdown` / `logger.Sync()` / `forceFlush` on SIGTERM, in serverless and on crash paths; `process.exit` right after a log (precedents § 44 is the CLI control)
- pass: the first request yields server spans, the resource names the service, and the last span and log line reach the sink after SIGTERM

#### V197. Sampling — resolved sampler + retained count (`trace-propagation-scan` §9–§10)
- every service's sampler in code and in env; parent-based everywhere; a tail policy on `status_code` where errors are required (or tracker capture beside the sampled trace); `probabilistic_sampler` placed after `spanmetrics` / `servicegraph`; `OTEL_TRACES_SAMPLER(_ARG)` equal across services
- pass: the resolved sampler is parent-based and N error traces at the configured ratio are all retained where the requirement says so

#### V198. Cardinality — registry scrape, live series (`metric-hygiene-scan` §1, §4; `telemetry-config-scan` §4)
- every `.labels` / `WithLabelValues` / `.With` / meter attribute site; relabel and `metric_relabel_configs`; collector `transform` / `attributes`; SDK Views; every Loki label map (Promtail, Alloy, Fluent Bit); DogStatsD tags; span names
- type misuse: a gauge used as a counter; a summary aggregated across instances
- pass: after randomized ids and paths the series count is bounded by `THR-OBS-CARDINALITY`; `trace_id` appears only as an exemplar (precedents § 20)

#### V199. Units and buckets — registry scrape (`metric-hygiene-scan` §3; `slo-rule-scan` §5)
- every `observe(` with a duration (`Date.now() - t` into `_seconds`); every `_ms` name; every histogram bucket list against each SLO threshold in seconds; each SLI `le` on the running Prometheus version (integer `le` on 3.x)
- pass: samples land in finite buckets and `count(x_bucket{le="T"}) > 0` for every T

#### V200. RED/USE coverage — per-entry-point scrape (`metric-hygiene-scan` §2)
- every handler family, consumer, cron and job, and every pool
- pass: running each entry point once moves its counter (with an outcome label) and its duration

#### V201. Health — dependency kill + probe hits (`metric-hygiene-scan` §7–§8)
- readiness reflects each dependency one pod can lose on its own, and no fleet-wide fact (precedents § 54); liveness stays constant (a liveness that checks a shared dependency is performance `request-path-scan` §15, V47)
- probe paths excluded from tracing and access logs at the source, and from SLI metrics at the source or in every consuming selector (precedents § 55)
- pass: stopping the dependency flips `/readyz` to 503 only; 100 probe hits add 0 spans, 0 log lines and no SLI series

#### V202. Error tracking — tracker test transport (`error-tracking-scan` §1–§4)
- every SDK init (server, worker, browser, mobile) has `release` and `environment`, in code or in the deploy env; the build's release name equals the SDK's
- source maps uploaded with debug IDs and not served publicly (`hidden` + delete after upload; serving them is security `xss-scan` § 13)
- process hooks in every process type; every boundary handler that maps to 500 captures or logs
- pass: the transport receives an event carrying both fields, the unhandled rejection reaches it, and one backend event shows resolved frames (L, else `NO-DATA(tracker)`)

#### V203. Rule annotations, labels and `for` — pint / rule inventory + promtool (`alert-rule-lint` §1–§2, §4)
- every surface: rule files from every `rule_files` glob, PrometheusRule CRDs (Helm templates and `additionalPrometheusRules*`), jsonnet mixins (fix the source, regenerate, diff), Mimir / Thanos / VictoriaMetrics / Loki rulers, Grafana-managed alerts (provisioning and `grafana_rule_group`), Datadog `message`, New Relic `runbook_url`, Honeycomb `description`, and the recording rules feeding them
- AL-01 / AL-02 a page with no `for` or a `for` past `THR-OBS-ALERT.page_for_max`; AL-09 `keep_firing_for` longer than `for` or past 30m on a page; AL-03 / AL-04 severity outside the vocabulary, a page with no `runbook_url`, any alert with no `summary`; AL-05 an annotation reading a label the aggregation dropped
- AL-22 a rule file matched by no `rule_files` glob; a PrometheusRule whose labels miss the `ruleSelector`
- pass: pint or `rule-inventory.py` prints nothing for the page tiers; promtool `exp_annotations` render; every rule file is loaded

#### V204. Never fires, or fires on a blip — promtool fire/blip pair + grounding (`alert-rule-lint` §2–§6)
- AL-06 `$value` in labels; AL-07 no comparison; AL-08 a raw counter compared; AL-13 `rate` on a gauge or `rate(sum(…))`; AL-10 a selector that resolves in no inventory; AL-11 impossible PromQL; AL-12 a window under 2× the job's scrape interval; AL-16 a ratio with no traffic-absent sibling; AL-17 `absent` with no `for` or with a regex; AL-21 Prometheus 3 breakage (integer `le`, `[Xm:Xm]`, `holt_winters`, `.` in a regex)
- the **never-loaded** variant: the rule is correct but no `rule_files` glob or `ruleSelector` picks it up
- pass: for each page rule a promtool test fires at the failure point and one stays silent at a blip, on the server's major; every selector is grounded (live `count(<selector>) > 0` when a backend is given); one traffic-absent companion per ratio; the rule is loaded

#### V205. Missing-data story — vendor no-data check (`alert-rule-lint` §9)
- one no-data mechanism per signal across every tool that alerts on it: `absent` / `absent_over_time`, Grafana `noDataState` / `execErrState`, Datadog `notify_no_data` / `on_missing_data`, New Relic `expiration_duration`, Honeycomb COUNT triggers (precedents § 10 is the error-count control)
- pass: a traffic or heartbeat signal that stops produces an alert in every tool that watches it

#### V206. Routing — routes matrix (`alert-rule-lint` §7–§8)
- every Alertmanager (root, per-tenant, `AlertmanagerConfig` CRDs) and Grafana notification policy; a `severity=warning` set that reaches the pager (SY-02); deprecated keys; timers after inheritance; receivers no route reaches
- pass: `routes test --verify.receivers` passes for every emitted {severity × team}; `check-config` is clean; inhibition is proven in a containerised Alertmanager (L)

#### V207. SLO burn — regenerate and diff + burn arithmetic (`slo-rule-scan` §1–§4, §6)
- every SLO spec; generated rules regenerated, never hand-edited (precedents § 42); vendor SLO objects with burn alerts; every environment's objective; a 100 % objective (precedents § 14); TSDB retention ≥ the SLO window or a long-term store
- an SLI that counts 4xx as bad or only `code="500"` (precedents § 13): replay 404s and the SLI does not move
- pass: regenerate-and-diff is empty, `burn-check.py` passes against `THR-OBS-BURN`, the fast-burn promtool test fires and the slow leak tickets

#### V208. Pipeline — validate + key diff + staged config (`telemetry-config-scan` §1–§3, §7; shippers §5, Loki §4 and §6, dashboards §8)
- every collector config (agent and gateway): `memory_limiter` first, `batch` last, no unused component, `retry_on_failure` and `sending_queue` on every exporter, tail sampling behind a `loadbalancing` exporter keyed on `traceID`, no `debug` exporter at `verbosity: detailed` in production
- pass: `otelcol-contrib validate` exits 0 and the key diff and order check print nothing
- **shippers** (§5): every Alloy, Promtail, Vector and Fluent Bit config the deploy mounts, Helm-embedded River extracted from the chart values first. `alloy validate` exits 1 with the `file:line` of an undefined component, and `--config.format=promtail` validates a Promtail file by converting it; `vector validate --no-environment` checks config and VRL only, so a label map stays a key read; `fluent-bit -c <file> --dry-run` parses the config where a binary exists (none for macOS: the cell prints `blocked`). A Promtail image or chart in the production deploy is the end-of-life row whatever it validates to (precedents § 51)
- **Loki** (§4, §6): the rendered config, never the values file. `loki -verify-config` exits 1 on `${VAR}` without `-config.expand-env=true` (pass the flag only when the deploy does) and exits 0 on `retention_period` with compactor retention off, so retention is a key check: `retention_enabled: true` with a `delete_request_store`. Stream labels come from every label map (Promtail, Alloy `stage.labels`, Fluent Bit, Vector); their live cardinality is `logcli series --analyze-labels` (L, V198)
- **dashboards (DB-01..DB-05, §8):** every loaded board (a provisioning path, a ConfigMap with the sidecar label, rendered grafonnet). dashboard-linter runs on a copy with the scoped config; count its error rows, because it exits 0 without `--strict` while printing errors and `--strict` also exits 1 on a label warning. `dash.py` covers what the linter misses: a counter graphed raw behind a label selector, a literal window on a board with no datasource variable, a fixed datasource uid. Every panel selector is grounded in the metric inventory (precedents § 37), and an integer `le` is read on the server's major (§ 45)
- pass, shippers and Loki: every validator exits 0 on the deployed version, both retention keys are present, and no stream label holds a per-request id. Pass, dashboards: each loaded board has 0 error rows under the scoped rules and 0 `dash.py` flags, and every selector resolves

### Sources (observability)

The observability research catalog and its batch eval (2026-10-10), which cite: the Prometheus
docs (promtool, unit testing for rules, migration to v3, naming, alerting practices, Alertmanager
configuration) and `cmd/promtool/main.go`; cloudflare/pint 0.89.2 docs; Alertmanager 0.34.1 amtool;
the OpenTelemetry Collector 0.162.0 source and processor READMEs, Weaver 0.27.0, the OTel in-memory
exporters (JS 2.12, Python 1.45.1, Go 1.47, Java 1.67, .NET 1.19.1) and the OTel sampling and
semantic-conventions pages; sloth 0.16.0 and pyrra 0.10.2 sources; the Google SRE Workbook
*Alerting on SLOs* (re-fetched 2026-10-10; CC BY-NC-ND, paraphrased); Grafana Alloy 1.20.1, Loki
3.7.8 and dashboard-linter 0.3.0; sentry-cli 3.8.0's changelog; local runs of pino 10.4.0,
pino-http 11.0.0 and winston 3.19.0. Rows marked [K?] are to be settled on the `obs-defects` fixture
or a real repo before a skill asserts them. Paraphrased; no text reproduced.

## DevOps

A delivery-integrity claim says the pipeline's own semantics, with no attacker involved, let a red
build merge, ship an artifact that was not tested, cancel or race a mutating deploy, drop in-flight
work at shutdown, or leave no rollback target. Reading a workflow does not settle any of these:
what a platform does with a pipe, a skipped job or a second push is a platform fact
([`ci-platform-semantics.md`](ci-platform-semantics.md)), and what ships is a digest. The oracle
drives the event (a seeded failure, a second push, a re-run, a SIGTERM, a cold start of N replicas)
through the real pipeline, image or compose file and asserts on what happened. Every oracle names a
**tier**: T (`ci-graph.py` or a tool's exit code), R (a sandbox run: a scratch repo, `act`, docker),
B (a built image or a registry read), A (a settings API read), S (a static trace), L (a live
rollout). Settled questions are in [`precedents/devops.md`](precedents/devops.md). Users:
`pipeline-integrity-scan`, `pipeline-cache-scan`, `release-integrity-scan`, `deploy-safety-scan`,
`container-build-scan`, `compose-scan`, the rewritten `progressive-delivery` and `gitops-audit` (devops pack),
judged by `@ci-reviewer` and `@deployment-engineer`, and `/devops-fix`. Attacker-path classes in CI
(injection, privileged triggers, pinning × privilege, cache poisoning, secret exposure) are
security's and are proven with [`exploit-payloads.md`](exploit-payloads.md), not here.

**Scope of use.** Sandbox repositories, scratch builds and `${TMPDIR}` only — never the user's
branches, registries, environments or clusters. A seeded failure, a two-push race or a release
re-run happens in a sandbox repo the user names. Every `kubectl` / `helm` command passes an isolated
`--kubeconfig=<scratch file>` pointing at a throwaway cluster (kind) or none; the default context is
never relied on. A settings read (`gh api`) is read-only; a fix that needs a settings change prints
the exact call and the user applies it. Three rules hold for every variant below:

- **Read the platform row first.** A verdict about a pipe, a skip, a cancel or a timeout names its row in `ci-platform-semantics.md`; a `[K?]` row is settled on a sandbox run before a fix relies on it.
- **Graph before grep.** A cross-job fact (who needs whom, what a concurrency group covers, what is required) comes from `ci-graph.py`, which parses each workflow with a real YAML loader and remaps the `on:` key YAML 1.1 reads as `true` (precedents § 44). Exit 2 is NOT-RUN, never clean.
- **A fix stays inside its job.** `ci-graph.py --diff-guard="$FIX_BASE" --allow-job=<file>:<job>` rejects a fix that changes `on:`, `if:`, `needs:`, `concurrency:`, `permissions:`, `environment:`, `runs-on:` or `secrets:` anywhere else. Only the `=` forms take a value: `--diff-guard "$FIX_BASE"` with a space expects two files and exits 2, and a bare `--allow-job` is refused. A finding on a workflow-level key adds `--allow-workflow=<file>:<key>` (`on`, `concurrency` or `permissions`), which lets that one key through and nothing in any job.

### Oracle taxonomy (DevOps)

| Oracle | Asserts | Tier | V |
|---|---|---|---|
| **Seeded failure** | One failing command per gate on a sandbox branch → every required context and every deploy ancestor concludes `failure`; the deploy job is `skipped`; the published digest is unchanged (extends testing's V63 CI canary to non-test gates) | R | V209, V212 |
| **Shell-semantics probe** | The four-line bash probe per platform row | T | V210 |
| **Required-check join** | `ci-graph.py --required --online` + a docs-only PR and a merge-queue entry report real conclusions | A + R | V211 |
| **Graph assertion** | `ci-graph.py --check=<code>` exits 0 on the tree after the fix, 1 before | T | V213, V214, V228 |
| **Settings read** | The `gh api` line shows the protection | A | V215, V216, V220, V229 |
| **Cache probe** | A lockfile change misses the exact key; a deleted cache stays green | R | V217 |
| **Affected probe** | One-package PR → only it; shared-lib PR → its dependents | R | V218 |
| **Run timing** | p50/p95 from `gh api`, labelled measured | A | V219 |
| **Release dry run** | One version string across all outputs | T | V221 |
| **Re-run idempotence** | A second release run on a sandbox registry is a no-op, same digests | R | V222 |
| **Digest continuity** | Build = scanned = pushed = staging = prod digest | B | V223 |
| **Verify negative test** | An image signed by another workflow or ref is rejected | B | V224 |
| **Release PR checks** | `gh pr checks` shows the required checks ran | A | V225 |
| **Rollback resolve** | `crane manifest <repo>@<N-1 digest>` resolves | B | V226 |
| **Scale cold start** | `compose up --scale app=3` from an empty DB: one row per migration, 0 crash-loops; a kill mid-run recovers | R | V227 |
| **Rollout red** | A crash-looping image fails the pipeline inside the timeout | R | V230 |
| **Stop timing** | `time docker stop -t 10` < 10 s, exit ≠ 137; an in-flight request completes | B | V231 |
| **Canary checks** | The AnalysisTemplate can fail (static), its selectors ground (observability), a 20 %-error canary aborts (L) | S + L | V232 |
| **Provider-error default** | The flag client with a failing provider returns the safe default | R (unit) | V233 |
| **Declared-keys boot** | The artifact boots with only the declared prod keys | B | V234 |
| **Image-config user** | `docker image inspect` user + container-structure-test `metadataTest.user`; a `runAsNonRoot` dry run admits | B | V235 |
| **Layer and lock probes** | Touch a source file → the install layer is `CACHED`; a mutated lockfile → the build fails | B | V236 |
| **Build-check lane** | `docker build --check` (`check=error=true`) + hadolint at its threshold: 0 kept rule ids | T | V237 |
| **Health status** | `.State.Health.Status` = `healthy` within the start period | B | V238 |
| **Per-platform smoke** | `docker run --platform linux/<arch> <img> <smoke>` per published architecture | B | V239 |
| **Structure test** | container-structure-test file and command tests on the runtime image | B | V240 |
| **Compose config / wait** | `docker compose config` clean; `up --wait` exits 0 on the prod invocation | R | V241 |
| **Rebuild diff** | Build twice → `diffoci diff --semantic` empty | B | V242 |
| **Size vs baseline** | `dive` / image size against the recorded baseline within `THR-IMAGE-GROWTH` | B | V243 |
| **Controller diff** | The imperative verb against a controller-owned namespace leaves the CD target OutOfSync or reverted on a scratch cluster; after the fix the change arrives by commit and the diff is empty | S + L | V290 |

### Seeded failure, per platform

Seed **one** deterministic failing command in each gate the finding names (`exit 1` as the first
line of the scan, smoke, build or migration-check step; a failing assertion in a test job when
testing's V63 is co-run) on a sandbox branch, push, and read the conclusions. Revert the seed.

| Platform | Read | Fails first when |
|---|---|---|
| GitHub Actions | `gh run view <id> --json jobs --jq '.jobs[]\|[.name,.conclusion]'`; `gh pr view <n> --json mergeStateStatus`; `crane digest <repo>:<tag>` before and after | the masked job concludes `success`, the PR is not `BLOCKED`, or the deploy job ran and the digest moved |
| GitLab CI | `glab ci view` / `glab api projects/:id/pipelines/:pid/jobs` (`status`, `allow_failure`); the MR's merge status [K?: field name on the installed GitLab] | the seeded job is `failed` with `allow_failure: true` and the pipeline `success`, or the deploy job ran |
| CircleCI | the workflow's job statuses from the API or UI | the seeded step is red and the job green, or a `requires:`-less deploy ran |
| Bitbucket | the pipeline's step results | the step after a masked pipe is green (S5: `set -e`, no pipefail) |
| Azure | the run's task results | a multi-line `script:` whose seeded first line failed ends green (S6 [K?]) |
| Jenkins | the build result and the stage view | a `catchError(buildResult: 'SUCCESS')`, `returnStatus: true` or `propagate: false` turns the seeded stage green |

**Green after the fix:** the same seed makes every required context and every deploy ancestor
conclude `failure`, the deploy is `skipped`, and the digest (`crane digest`) or published version
(`npm view <pkg> versions`) is unchanged. Locally, `act -j <job>` exiting non-zero is a smoke check,
never the proof (precedents § 45, § 46).

### Graph assertion (`ci-graph.py`)

`ci-graph.py` ships in the repo baseline (`.claude/scripts/ci-graph.py`; fallback
`$HOME/.claude/templates/repo-baseline/.claude/scripts/ci-graph.py`). It parses
`.github/workflows/*.y{a,}ml` with PyYAML, else Ruby psych, else `uv run --with pyyaml`, and exits 2
(`NOT-RUN (no YAML loader)`) when none is present. Rows print as `file:line: CODE key=value…`;
exit 0 is clean, 1 is at least one finding row, 2 is NOT-RUN (no loader, a parse error, no
workflow found, an unreadable settings API).

```bash
python3 .claude/scripts/ci-graph.py --self-test
python3 .claude/scripts/ci-graph.py . --all                                   # every structural check
python3 .claude/scripts/ci-graph.py . --check=deploy-concurrency,deploy-gate,timeout
python3 .claude/scripts/ci-graph.py . --required --deploy-ancestors           # needs gh + a token
python3 .claude/scripts/ci-graph.py . --job-of=.github/workflows/ci.yml:42 --shell-of=.github/workflows/ci.yml:42
python3 .claude/scripts/ci-graph.py . --diff-guard="$FIX_BASE" --allow-job=.github/workflows/deploy.yml:deploy-prod
python3 .claude/scripts/ci-graph.py . --diff-guard="$FIX_BASE" --allow-workflow=.github/workflows/ci.yml:concurrency   # a workflow-level finding
```

The rows, by check: `pin-priv` → `PIN×PRIV` (security's class; devops supplies the join) ·
`deploy-concurrency` → `DEPLOY-CANCEL`, `DEPLOY-NOGROUP`, `GROUP-NOT-ENV`, `ENV-SPLIT-GROUPS` ·
`deploy-gate` → `DEPLOY-UNGATED`, `DEPLOY-ALWAYS`, `WORKFLOW_RUN-NO-CONCLUSION` · `timeout` →
`NO-TIMEOUT`, `WAIT-NO-TIMEOUT` · `matrix` → `MATRIX-EXCLUDES-RUNTIME`, `MATRIX-DYNAMIC-UNGUARDED` ·
`cache-keys` → `CACHE-KEY-NO-HASH`, `CACHE-NODE-MODULES`, `CACHE-PREFIX-SKIP-INSTALL` ·
`--required` → `REQUIRED-UNMATCHED`, `REQUIRED-PATH-FILTERED`, `REQUIRED-IF-SKIP`,
`REQUIRED-NEEDS-SKIP`, `NO-MERGE-GROUP`, `DUP-NAME`, `AGGREGATOR-WEAK`, `UNREADABLE` ·
`--deploy-ancestors` → one `JOB job= deploys= publishes= env= deploy-via= ancestor-of= required=` row
per job. A job deploys when it has an `environment:` (`deploy-via=environment`), runs a deploy or
publish verb (`verb`), uses a deploy action — any action whose name says deploy, a local
`./…/deploy` composite, or a hosting action such as `appleboy/ssh-action`, `pulumi/actions` with
`command: up`, `cloudflare/wrangler-action` with its default command (`action:<name>`) — or passes a
deploy verb in an action's `script:` / `command:` / `args:` input (`action-input:<name>`). A
`docker/build-push-action` publishes on a non-false `push:` or, with no `push:` input, on
`outputs: …push=true` / `type=registry`.
**Fails first:** the row prints for the cited job before the fix and is gone after it, with
`--diff-guard` clean outside the finding's job. GitLab, CircleCI and Azure are not modelled yet:
their rows are grep + read, and say so.

### Stop timing

```bash
docker run -d --name t <img>; sleep 3; docker exec t cat /proc/1/cmdline | tr '\0' ' '
s=$(date +%s); docker stop -t 10 t; e=$(( $(date +%s) - s )); docker inspect -f '{{.State.ExitCode}}' t
```

PASS iff `e` < 10 and the exit code is not 137. Measured on node:22 (devops research B § 5): exec
form with a handler stops in 0.1–0.2 s; exec form with no handler, a dash `sh -c`, `npm start` on
bookworm-slim and an entrypoint script without `exec` all take ~10–12.7 s and exit 137; alpine's ash
tail-execs a single command (precedents § 35). The in-flight half: start a slow request, send
`docker stop`, and assert it returns 2xx.

### Class variants (DevOps)

#### V209. Failure swallowed on a non-domain gate — seeded failure (`pipeline-integrity-scan` §1)
- `continue-on-error: true` on a job or a step, and an expression that evaluates true; `|| true`, `|| :`, `|| exit 0`, `|| echo`, `; true` at the end; `set +e` never re-enabled; a wrapper script ending in `exit 0` or `trap 'exit 0' ERR`; `make -k`
- GitLab `allow_failure: true` / `allow_failure: exit_codes` and the `when: manual` default (R8); Azure `continueOnError: true`; Jenkins `catchError(buildResult: 'SUCCESS')`, unchecked `returnStatus: true`, `propagate: false`; CircleCI `when: always` on a gate step
- scanner flags that zero the exit: `exit-code: 0`, `--exit-code 0`, `--soft-fail`, `--no-fail`, `--no-exit-codes`, zizmor `--format=sarif`, poutine without `--fail-on-violation`
- every non-domain gate: deploy, publish, image scan, security scanner, smoke, migration check, build, the aggregator, the observability rules-gate job (test, lint and a11y jobs are testing V63, code-quality and frontend V104)
- pass: the seeded failure turns every required context and every deploy ancestor `failure`; the cleanup step's `|| true` (precedents § 13) stays

#### V210. Exit status lost by the shell — shell-semantics probe (§2)
- a pipe into `tee`, `grep`, `head`, `tail`, `sed`, `awk`, `jq`, `sort`, `uniq`, `cut` or `xargs` under GitHub's default `bash -e` (S1), Bitbucket's `set -e` (S5), Jenkins' `sh -xe` (S7); a multi-line Azure `script:` with no `set -e` (S6 [K?])
- the effective shell from step, job and workflow `defaults.run.shell` (S2); a `shell: sh` override
- pass: the probe for that platform row exits non-zero on the seeded producer, and the step runs under `set -o pipefail` (or `shell: bash`, or a `PIPESTATUS` check)

#### V211. Required check never reported, or satisfied by a skip — required-check join (§3)
- workflow `paths`, `paths-ignore`, `branches` on a required workflow (R3); a job `if:` on actor, label, event or draft (R1); a needs-skip (R2); no `merge_group` with the queue on (R5); a name collision or a renamed job (R6, R7 [K?]); a matrix leg named as the context; a `workflow_dispatch` re-run (R4)
- GitLab `rules:changes` without `compare_to` (R10) plus "skipped pipelines are considered successful"; `needs:optional` (R11); an Azure path-filtered build-validation policy
- pass: a docs-only PR, a bot PR and a merge-queue entry each get a conclusion from a real run on every required context — never Pending-forever, never `skipped` on a non-aggregator context

#### V212. Deploy or publish not gated on tests — seeded failure + digest unchanged (§4)
- a missing `needs:` chain; `if: always()`, `!cancelled()`, `success() || failure()` on the deploy or an ancestor; a separate `on: push` deploy workflow; `workflow_run` with no `conclusion == 'success'` check
- GitLab `needs: []`, `optional: true`, `when: always`; Azure `dependsOn: []`, `condition: always()`; CircleCI no `requires:`; Jenkins `post { always { deploy } }`; a dispatch from any ref
- pass: the seeded failure leaves the deploy and publish jobs `skipped`, `crane digest` and `npm view <pkg> versions` unchanged

#### V213. Timeouts unset, unbounded waits — graph assertion (§6)
- every job with no `timeout-minutes` (C4: 360 min), except `uses:` callers (precedents § 11); `kubectl rollout status`, `argo rollouts status`, `helm … --wait` with no `--timeout`
- pass: `ci-graph.py --check=timeout` prints nothing; every deploy wait carries a bound under `THR-CI-JOB-TIMEOUT`

#### V214. Matrix hides signal — graph vs declared runtimes (§7)
- an `exclude:` that removes a runtime the project declares (`engines`, `.nvmrc`, `.node-version`, `requires-python`); a dynamic `fromJSON(needs.x.outputs.m)` with no non-empty guard; a required context named after one leg
- pass: `ci-graph.py --check=matrix` prints nothing, and every declared runtime runs on a required leg

#### V215. Unvalidated ref built or deployed — settings read + dispatch refusal (§5)
- `ref: ${{ inputs.* }}` / `github.event.inputs.*` into checkout or deploy; free-text dispatch inputs named `ref`, `branch`, `sha`, `tag`, `version`, `image`; `push: branches: ['**']` on a deploy workflow; GitLab deploy jobs with no `$CI_DEFAULT_BRANCH` rule
- pass: the environment's `deployment_branch_policy` (A) restricts the refs, and a dispatch from a feature branch is refused (R)

#### V216. Scheduled jobs dead or racing — settings read (§8)
- a `schedule:` on a public repo with no activity (C5); a workflow in `disabled_inactivity`; two schedules writing one target
- pass: `gh api repos/{o}/{r}/actions/workflows` shows `active` and the last run (`gh run list -w <file> -L 1`) is inside its period

#### V217. Cache key wrong or stale; Docker layer cache misuse — cache probe (`pipeline-cache-scan` §1, §2)
- `actions/cache` keys without `hashFiles(`; `node_modules` cached; `restore-keys` with an install skipped on a prefix hit; no `runner.arch` on mixed runners; setup-* `cache:`; GitLab `cache:key` without `files:`; CircleCI `restore_cache` without `{{ checksum`
- buildx `type=gha` without `mode=max`, several images without `scope=`, a release build reading a PR-populated scope (the poisoning half is security's)
- pass: a lockfile change misses the exact key and reinstalls; with the cache deleted the build is still green

#### V218. Affected detection broken — affected probe (§3)
- `nx affected`, `turbo --filter=…[`, `--affected`, `git diff … origin/` joined with a shallow `fetch-depth` (default 1); PR workflows with no concurrency (superseded runs)
- pass: a PR touching one package runs only it; a PR touching a shared library runs its dependents; the empty set never skips a required test

#### V219. Slow structure — run timing (§4)
- serial `needs:` chains with no data dependency; no sharding; queue time per job
- pass: p50/p95 per workflow from `gh api …/actions/runs?per_page=100`, labelled measured, against the project's declared budget (no default threshold; L, report-only)

#### V220. Release ref movable — settings read (`release-integrity-scan` §1)
- tag-push and `release: published` workflows with no tag ruleset; releases not immutable; no `merge-base --is-ancestor` check of the tagged commit; bypass actors beyond the release bot
- pass: `gh api repos/{o}/{r}/rulesets` shows a tag rule and `…/releases/tags/<latest> --jq .immutable` is `true`

#### V221. Version source split — release dry run (§2)
- `git describe --tags` vs `package.json` `.version` vs `Chart.yaml` `version` / `appVersion` vs the image tag vs `-ldflags -X …version`; `.changeset/pre.json`; a release-please manifest
- pass: `semantic-release --dry-run`, `changeset status`, `goreleaser check` or the project's release dry run prints one version across every output (declared independent versioning is precedents § 17)

#### V222. Non-idempotent release — re-run idempotence (§3)
- publish verbs with no existence guard (`npm view <pkg>@<v>`, `--skip-existing`, `--skip-duplicate`, goreleaser `keep-existing`); `docker push :<semver>` to a mutable tag; a half-published multi-registry release
- pass: a second run against a sandbox registry (Verdaccio, `registry:2`, TestPyPI) is a no-op with the same digests

#### V223. What ships is not what was tested — digest continuity (§4)
- a rebuild in the deploy or publish job; per-env build args (`--build-arg …ENV…=`); `NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`, `EXPO_PUBLIC_` values per environment in a server image; per-env tags from one SHA; a checkout of a different ref in deploy
- **a scanned `load: true` image that is not the pushed image** (a second `push: true` build after the scan; `load: true` also drops attestations)
- pass: the digest recorded at build equals the scanned, pushed, staging and prod digests (`crane digest`; `kubectl get deploy -o jsonpath='{..image}'` with an isolated kubeconfig, or the platform API)

#### V224. Verification verifies nothing — verify negative test (§5)
- `--certificate-identity-regexp '.*'`; an org-wide identity; a missing issuer; `--insecure-ignore-tlog`; verify by tag, not digest; `|| true` or audit-mode admission; `gh attestation verify --owner` with no `--signer-workflow`; cosign < 3.1.3 (`THR-SCANNER-FLOOR`); `sign` without `--recursive` on a multi-arch index; release assets with no checksums
- pass: an image signed by another workflow or ref is **rejected**, and every platform of the index verifies

#### V225. Release automation misconfigured — release PR checks (§6)
- release-please, changesets or semantic-release opening the release PR with `secrets.GITHUB_TOKEN` (its PR triggers no workflow runs)
- pass: `gh pr checks <release PR>` shows the required checks ran on it

#### V226. Rollback target not addressable — rollback resolve (§7)
- a registry lifecycle that keeps 1–3 images (`countMoreThan`); `delete-package-versions` / `delete-untagged`; `--history-max 0|1`; release-bundle `retention-days: 1`; rollback by a mutable tag (`revisionHistoryLimit` is infrastructure's)
- pass: `crane manifest <repo>@<N-1 digest>` resolves and `/rollback-deploy` R2 names that digest

#### V227. Migration topology — scale cold start (`deploy-safety-scan` §1)
- migrate in the entrypoint, CMD or `main.ts` boot (`getMigrator().up()`, `migrationsRun: true`); an initContainer; Spring Flyway/Liquibase auto-run; a Helm hook with no `hook-delete-policy`; migrate after the deploy verb; the lock disabled (`PRISMA_SCHEMA_DISABLE_ADVISORY_LOCK`); a lockless runner (Django, Alembic, TypeORM; MikroORM measured lockless: 6.6.16 on 2026-10-10, three concurrent `getMigrator().up()` applied a data migration 3 times, applied a DDL migration once with 2 boots exiting 1, and on a first-ever run 2 of 3 failed creating the migrations table itself); `--rollback-on-failure` / `--atomic` over a contract migration
- pass: `docker compose up --scale app=3` from an empty database writes exactly one row per migration with 0 crash-loops, and a kill mid-run is recovered by the next start

#### V228. Deploy concurrency — graph assertion + two-push race (§2)
- `cancel-in-progress: true` at workflow or job scope covering a deploy; a deploy with no group; a group keyed on the ref, not the environment; two workflows deploying one environment under different groups; GitLab `interruptible: true` on deploy or no `resource_group` (C2); Jenkins with no `disableConcurrentBuilds()` / `lock(`
- pass: `ci-graph.py --check=deploy-concurrency` prints nothing; two pushes 10 s apart in a sandbox repo → the first deploy completes, the final SHA is the latest, no `pending-upgrade` or Terraform lock is left (L); the PR workflow still cancels superseded runs (the control)

#### V229. Environment unprotected — settings read + dispatch refusal (§3)
- a deploy job with no `environment:`; an environment with no required reviewers, no branch policy, or `can_admins_bypass` on prod
- pass: `gh api repos/{o}/{r}/environments` shows reviewers and a branch policy on prod, and a dispatch from a feature branch is refused

#### V230. Rollout not gated — rollout red (§4)
- a deploy verb with no `rollout status`, `--wait`, `services-stable`, `argocd app wait` or `argo rollouts status` in the same job; a smoke test with no version assertion (`curl …/version | grep "$SHA"`)
- pass: deploying a crash-looping image to a throwaway cluster turns the pipeline red inside the timeout (isolated kubeconfig)

#### V231. Shutdown chain, code and image — stop timing (`deploy-safety-scan` §5; `container-build-scan` §2; `compose-scan` §7)
- shell-form CMD or ENTRYPOINT on a dash/bash base; `["sh","-c",…]` without `exec`; npm, yarn, pnpm or bun as PID 1; an entrypoint script whose exit paths do not `exec "$@"`; `su` / `sudo` privilege drop; no handler while PID 1 and no `tini` / `--init` / `init: true`; NestJS without `enableShutdownHooks()`; a drain longer than `THR-SHUTDOWN-GRACE`; compose `stop_grace_period` under the drain
- pass: `docker stop -t 10` returns in under 10 s with an exit other than 137 on the real base, and an in-flight request completes (manifest timing, `preStop` and grace are infrastructure's)

#### V232. Canary without a real gate — canary checks (`progressive-delivery` §5)
- a `successCondition` / `failureCondition` that can never fail (`result[0] >= 0`); `failureLimit` ≥ the measurement count; no `inconclusiveLimit`; `dryRun:` metrics; a query without the canary selector; Flagger `metrics: []`; `autoPromotionEnabled: true` with no `prePromotionAnalysis`
- a query with a zero fallback (`or vector(0)`, `scalar(`: an empty series reads as 0 and passes — `ZERO-FALLBACK`); a metric with neither `successCondition` nor `failureCondition` outside a `job` provider (`NO-CONDITION`); Flagger `skipAnalysis: true` (`SKIP-ANALYSIS`); a blue-green Rollout whose `autoPromotionEnabled` is left at its default `true` with no `prePromotionAnalysis` (`BG-AUTO-PROMOTE`); a **render-only** weakening — an overlay or values patch that raises `failureLimit` or drops the analysis on the prod render while the base stays sound (read the render row, not the source)
- pass: the template can fail on a static read, every selector grounds (observability `rule-inventory.py --check=selectors` when installed), and a 20 %-error canary aborts (L, else `NO-DATA(rollout)`)

#### V233. Flag safety — provider-error default (`progressive-delivery` §4, §8, §9)
- an unsafe default on provider outage (`getBooleanValue(…, true)` on a risky path); a build-time flag (`NEXT_PUBLIC_FLAG_*`) that cannot be flipped; no kill switch on a risky path
- an undeclared key: the SDK reads a key no registry declares (`progressive-delivery` §1 orphan), so every evaluation returns the code default forever — the provider-error path is the only path
- pass: a unit test with a failing provider gets the safe default, and the kill switch flips without a deploy

#### V234. Config read but not declared; per-env runtime drift — declared-keys boot (`deploy-safety-scan` §6)
- `process.env.X`, `import.meta.env`, `os.environ`, `os.Getenv`, `ENV.fetch`, `System.getenv`, `env::var` read at request time with no default and absent from prod's declared set (`.env.example`, compose, the **rendered** `env:` / `envFrom` / `configMapGenerator`, Helm values per env); `.nvmrc` / `engines` / `FROM node:` differing per environment
- pass: the artifact boots with only the declared prod keys (`env -i <keys> node dist/main.js`) and readiness passes, or the config validator names the missing variable; the runtime version is equal across environments

#### V235. Effective user wrong — image-config user (`container-build-scan` §1)
- no USER; `root`, `0`, `root:root` and **`0:0`** in the final stage; USER only in a builder stage; `USER ${ARG}` defaulting to root or empty; a base that sets non-root followed by `USER root` never switched back
- **inheritance:** `FROM base AS final` inherits the `USER 10001` of stage `base` (not root), and inherits root from a root stage; an external base with no USER (`INHERIT-EXTERNAL`, settled by `crane config`)
- `--target` or compose `build.target` selecting a non-final stage; a named USER under `runAsNonRoot: true` without `runAsUser` (the kubelet refuses the pod)
- pass: `docker image inspect -f '{{.Config.User}}'` is non-empty, not `root`/`0`/`0:*`, numeric where `runAsNonRoot` applies; container-structure-test `metadataTest.user` passes; a `runAsNonRoot` server dry run admits the pod (isolated kubeconfig)

#### V236. Layer order and lockfile — layer and lock probes (§3, §4)
- `COPY . .` before the dependency install; `npm install`; `pnpm install` without `--frozen-lockfile`; yarn without `--frozen-lockfile` / `--immutable`; `pip install` without hashes or constraints; `uv sync` without `--locked` / `--frozen`; cargo without `--locked`; `bundle install` without frozen — CI auto-freeze does not reach inside `docker build`
- pass: touching one source file leaves the install layer `CACHED`; a lockfile mutated by one version makes the build fail

#### V237. RUN correctness and the build-check lane — build-check lane (§5, §9)
- a `RUN <<` heredoc without `set -e`; `RUN cd`; a relative `WORKDIR`; an `ARG` used after `FROM` without redeclaration; a pipe in `RUN` without `SHELL ["/bin/bash","-o","pipefail","-c"]`; duplicate CMD; package hygiene
- pass: `docker build --check` with `# check=error=true` and hadolint v2.15.1 `--failure-threshold warning` report 0 kept rule ids, and a seeded failing line inside the heredoc fails the build

#### V238. HEALTHCHECK broken — health status (§6; `compose-scan` §2)
- `curl` or `wget` absent from the final base; a wrong port or path against `$PORT` / the app's `listen(`; no `--start-period`; compose `healthcheck.test` with a missing binary or `CMD` vs `CMD-SHELL` confusion
- pass: `docker inspect -f '{{.State.Health.Status}}'` is `healthy` within start-period + interval × retries (a k8s-only image is precedents § 29)

#### V239. Base, platform and libc — per-platform smoke (§7)
- an EOL base; `FROM --platform=<constant>`; Go without `TARGETOS` / `TARGETARCH`; a `$BUILDPLATFORM` builder producing native artefacts; musl builder → glibc runtime with native or generated code; a single-arch publish to a mixed cluster
- pass: `docker run --platform linux/<arch> <img> <smoke>` succeeds per published platform, and `docker buildx imagetools inspect` lists them

#### V240. Builder residue and runtime content — structure test (§8)
- `COPY --from=<builder> … node_modules` without a prod prune; dev tooling in the final stage; a writable root; ownership without `--chown` (a `VOLUME` followed by a write is not a variant: BuildKit keeps the write, measured 2026-10-10, precedents § 54)
- pass: container-structure-test file and command tests (`--platform` set) show no dev dependency or build tool in the runtime image

#### V241. Compose reliability — compose config / wait (`compose-scan` §1, §3–§7)
- `depends_on` short form or `condition: service_started` on a service with no healthcheck; `${VAR}` without `:-` / `:?` in `image:`, `ports:` or credentials; an override file auto-merged on a prod host; `image:` untagged or `:latest`; top-level `version:`, `links:`, `container_name:` on a scaled service; `restart: always` on a one-shot migrator
- pass: `docker compose config` on the prod invocation prints no warning and `docker compose up -d --wait` exits 0 on the **long-running** services of the host set. `--wait` exits 1 when any selected service exits, even a one-shot (a migrator) exiting 0, so select the long-running services by name, or make the one-shot a `service_completed_successfully` dependency of them, which `--wait` then passes (measured 2026-10-10, Compose v5.1.4)

#### V242. Claimed-reproducible build differs — rebuild diff (§10)
- no `SOURCE_DATE_EPOCH` / `rewrite-timestamp=true`; an unpinned BuildKit; no snapshot repositories; a base by tag — only when the repo claims reproducible builds or SLSA L3
- pass: two builds of one commit give an empty `diffoci diff --semantic`

#### V243. Image bloat regression — size vs baseline (§10)
- growth with no dependency change; builder residue (V240) as the usual cause
- pass: `dive` / the image size stays within `THR-IMAGE-GROWTH` of the baseline `/dockerize` Phase 7 recorded

#### V290. Out-of-band apply into a controller-owned namespace — controller diff (`gitops-audit` §1)
Numbered after the last variant in the file (V289), not after V243; the numbers are never reused.
- an imperative write (`kubectl` / `oc` `apply`, `create`, `edit`, `scale`, `set image`, `set env`, `patch`, `replace`, `delete`, `annotate`, `label`, `rollout restart|undo`; `helm install|upgrade|rollback|uninstall`) in CI, a script or a Makefile against a namespace an Argo `Application` or a Flux `Kustomization` / `HelmRelease` deploys; `argocd app set|unset|patch`, or `argocd app sync --local|--revision|--prune|--force` (an override that lives in the Application, not git); `flux suspend` with no `resume` on every exit path
- the two outcomes the sync policy decides: `selfHeal: false` (the change persists and git stops describing prod) and `selfHeal: true` (the change is reverted on the next reconcile, silently)
- not variants: the controller's own install into `argocd` / `flux-system` (precedents § 52); a GitOps CI that only commits manifests (§ 23); a `--dry-run=client` render piped nowhere; a one-off `kubectl create job --from=cronjob/…` or `kubectl debug` (an untracked object: Hardening)
- tier S: the verb's line and the CD target's line (namespace, sync policy); tier L: on a scratch kind cluster with the controller installed, through an isolated `--kubeconfig=<scratch>` (never the default context), run the verb, then `argocd app diff <app>` / `flux diff kustomization <name> --path <dir>`
- pass: after the fix the change arrives through a commit, the same scratch run shows the CD target `Synced` with an empty controller diff, and the imperative line is gone from CI and scripts (or targets a namespace no CD target owns); without a scratch controller the row stays `[report-flagged]` with `NO-DATA(controller)`

### Sources (DevOps)

The devops research catalog and its notes A–D (2026-10-10) and the batch-4 devops eval (2026-10-10),
which cite: GitHub Docs (*Workflow syntax*, *Troubleshooting required status checks*, *Secure use
reference*, *Disabling and enabling workflows*, *Dependency caching reference*, fetched 2026-10-10);
GitLab Docs (*CI/CD YAML syntax reference*, *CI/CD variables*); the CircleCI and Atlassian support
pages on default shells; the GitHub changelog (immutable releases 2025-10-28, workflow execution
protections 2026-09-17); actions/checkout releases (2026-06-18, 2026-07-20); the Prisma migrate
docs (advisory lock); and local runs on 2026-10-10 of the `docker stop` matrix (node:22 alpine and
bookworm-slim), the stage-chain user resolution on six Dockerfiles and the YAML `on:` remap
(PyYAML, Ruby psych). Later the same day, by the detectors that cite them: MikroORM 6.6.16 with umzug
3.8.2 (three concurrent boots on postgres:16, `deploy-safety-scan`), Compose v5.1.4 `--wait` with a
one-shot (`compose-scan`), the BuildKit `VOLUME` write (buildx 0.37.1, `container-build-scan`), and
the `ci-graph.py` deploy-action, `outputs: …push=true` and key-scoped `--allow-workflow` cases (its
`--self-test`, PyYAML and Ruby psych). Rows marked [K?] are settled on the `ci-defects` fixture or a
sandbox repo before a skill asserts them. Paraphrased; no text reproduced.

## Infrastructure

An infrastructure claim says that, with no attacker involved, a declared or rendered configuration
takes the system down, loses its data, executes a request twice or bills without bound. Reading a
manifest or a `.tf` file does not settle any of these: what the API server rejects, what a drain
does to a PDB, what the provider fills in for an unset attribute and what a proxy does with a slow
upstream are runtime and provider facts. The oracle drives the disruption (a drain, a forced
replacement, a `destroy`, a config edit, a poison message, a slow or killed upstream, a second
schedule tick) against a copy, an offline plan or a scratch cluster, and asserts on what happened.
Every oracle names a **tier**: T (a tool on files: kubeconform, pluto, conftest, `terraform test`,
cfn-lint, `nginx -t`, `caddy adapt`), P (the offline plan JSON), K (a scratch kind cluster), H (the
edge harness), L (live, read-only) or S (a static two-ended trace that includes the provider or
chart default). Settled questions are in [`precedents/infrastructure.md`](precedents/infrastructure.md).
Users: `iac-state-scan`, `iac-lifecycle-scan`, `dr-audit`, `serverless-reliability-scan`,
`iac-cost-scan`, `k8s-render-scan`, `k8s-availability-scan`, `k8s-wiring-scan`,
`k8s-api-version-scan`, `edge-reliability-scan`, `dns-tls-lifecycle-scan` and
`network-exposure-audit` (infrastructure pack), judged by `@k8s-reviewer` (the four Kubernetes
detectors) and `@infra-reviewer` (the rest), and `/infra-fix`. Exposure, privilege, RBAC breadth, the
shared-cache leak (E4), dangling DNS (D1), D8/D9, DATA-06 and secret values in state are security's
and are proven with [`exploit-payloads.md`](exploit-payloads.md) and
[`finding-verification.md`](finding-verification.md); their variant lists are cited there, not
restated here.

**Scope of use.** Copies under `$SCAN`, offline plans and scratch clusters only — never the user's
state backend, cloud account or cluster. No `apply`, `destroy`, `import`, `state mv/rm`,
`helm install/upgrade`, `kubectl apply/delete/patch` or cloud mutation outside a scratch kind
cluster, ever. Five rules hold for every variant below:

- **Read the version first** (gate 3): TF/Tofu from `required_version` and the lockfile, the target Kubernetes minor, the Helm major, the controller image tag or chart pin. A version-gated variant with no version read is Unconfirmed with the probe written out.
- **Every Kubernetes oracle carries an explicit kubeconfig.** `KUBECONFIG="$SCAN/kind.kubeconfig"` (or `--kubeconfig`) on the same command line as every `kubectl` / `helm` / `kind` call, pointing at a scratch kind cluster the run created itself (§ Scratch cluster: `kind-harness.sh` is planned, **not built yet**); an unset `KUBECONFIG`, or one that resolves to the user's default file, is refused, and `~/.kube/config` is never read. `helm template --dry-run=server` and bare `kubent` reach for the current context (precedents § 55, § 56).
- **Terraform is offline.** `init -backend=false` on a copy, fake credentials with the provider's skip flags, `plan -refresh=false` and `test` with `mock_provider` + `command = plan`. Provider download is network but credential-free; a backend is never configured.
- **Tools run on copies.** Never `gixy --fix`, `helm dependency update` in-tree, `checkov --download-external-modules` in-tree or `terraform init` in-tree.
- **The ledger counts objects, not exit codes.** A tool that read fewer objects or files than were rendered is NOT-RUN for the difference; the two canaries (a removed-API PDB and a `name: n` ConfigMap) ride every run (precedents § 53). An L-tier variant with no target the user confirmed in this session prints `NO-DATA(<target>)`, never PASS.

### Oracle taxonomy (infrastructure)

| Oracle | Asserts | Tier | V | Detector § |
|---|---|---|---|---|
| **State lock** | Two parallel `plan -lock-timeout=0s` on a copy: one fails on the lock; the state bucket is versioned; `terraform test` fails "Output refers to sensitive values" before the fix; `plan -refresh-only -detailed-exitcode` runs on a schedule | T + P | V244 | `iac-state-scan` §1, §2, §4–§6 |
| **Pinning** | `init -lockfile=readonly` passes on every CI platform; `.terraform/modules/modules.json` resolves to immutable refs; a chart's resolved version is fixed across two dates | T | V245 | `iac-state-scan` §3 |
| **Identity** | Churn plan: removing item 0 of a `count` collection plans delete/create on every later index before the fix, only the intended key after | P | V246 | `iac-lifecycle-scan` §1 |
| **Lifecycle / refactor blocks** | Two consecutive plans; `action_reason`; Tofu's forgotten count; the side-effect shows no plan diff | P | V247 | `iac-lifecycle-scan` §2, §3, §5, §6 |
| **Stateful replace** | `replace_paths` on a stateful type; a conftest deny over the plan JSON fails before the fix | P + T | V248 | `iac-lifecycle-scan` §4 |
| **Deletion safety** | `terraform test` asserts `== true` (unset reads null); a forced replacement fails `plan` with the guard; cfn-lint `I3011`; a staging destroy drill leaves backups | T + P | V249 | `iac-lifecycle-scan` §7; `dr-audit` §12 corroborates |
| **Backups / PITR** | `terraform test` on retention and PITR; the live describe on a confirmed profile | T + L | V250 | `dr-audit` §1–§7 |
| **Immutability & writer-can-delete** | `simulate-principal-policy` (or the provider's key-scope listing) **denies** delete and re-policy for the app and backup identities; the vault lock is compliance mode | L + S | V251 | `dr-audit` §8 |
| **RPO arithmetic** | Schedule × retention × discovery lag against the declared RPO/RTO table, written out | S | V252 | `dr-audit` §9 |
| **Restore evidence** | A restore to a **new** target with a row or checksum diff, a measured duration vs RTO and a date within `THR-BACKUP-DRILL-AGE` | L / recorded | V253 | `dr-audit` §11, §12 |
| **Operator backups** | `pgbackrest check`, `pg_stat_archiver.failed_count`, `velero backup describe --details`, `kubectl cnpg status` on a scratch cluster, `etcdutl snapshot status` | K + L | V254 | `dr-audit` §10 |
| **Queue timing** | `vis.jq` over the plan: `visibility < 6 × (timeout + window)` prints before the fix, nothing after | P | V255 | `serverless-reliability-scan` §2 |
| **DLQ path** | The plan has a redrive or destination on the source, with DLQ retention > source retention | P | V256 | `serverless-reliability-scan` §3 |
| **Partial batch** | A unit test with one failing record returns exactly that id in `batchItemFailures` | T (unit) | V257 | `serverless-reliability-scan` §4 |
| **Concurrency ceiling** | The plan value of reserved / maximum concurrency × per-instance connections ≤ the downstream's limit; `reserved = 0` flagged separately | P + S | V258 | `serverless-reliability-scan` §5, §7–§9 |
| **Retry storm** | One poison record injected on a sandbox stack → retries bounded, `IteratorAge` recovers | L (sandbox) | V259 | `serverless-reliability-scan` §6 |
| **Log retention** | Plan JSON `retention_in_days`, read against the HCL (they disagree on unset, precedents § 52) | P | V260 | `iac-cost-scan` §3 |
| **Scale ceilings** | Every autoscaler has a max; `max × unit` written out against the quota | P + S | V261 | `iac-cost-scan` (COST-08, K-HPA-COST); `serverless-reliability-scan` §5 corroborates |
| **Render matrix** | Every values file × env and every overlay renders, at the oldest and newest target minor; Helm values cross-reference clean | T | V262 | `k8s-render-scan` §0–§2 |
| **Patch no-op / phantom** | The render with and without the patch differs only where intended | T | V263 | `k8s-render-scan` §3 |
| **SSA / upgrade twice** | `helm upgrade` twice on kind (Helm 4 server-side) exits 0 with the HPA owning replicas | K | V264 | `k8s-render-scan` §2 |
| **Selector mutation** | Apply the base-branch render, then the head render, on kind → `field is immutable` before the fix | K | V265 | `k8s-render-scan` §5 |
| **GitOps spec** | `argocd app diff` / `flux diff` on scratch; else the static two-ended trace | K / S | V266 | `k8s-render-scan` §4 |
| **Pod-template classes** | `availability.sh` class rows over every pod template; `apply --dry-run=server` on kind | T + K | V267 | `k8s-availability-scan` §1, §2, §8 |
| **PDB drain** | `drain --dry-run=server` / an Eviction with `dryRun: ["All"]` on kind → 429 before the fix | K | V268 | `k8s-availability-scan` §3 |
| **Scaling (HPA / KEDA)** | HPA `ScalingActive` True; the KEDA floor read from the render; replicas untouched by an apply | K | V269 | `k8s-availability-scan` §4 |
| **Spread** | Multi-node kind placement under the declared constraint | K | V270 | `k8s-availability-scan` §5 |
| **Rollout shape** | `apply --dry-run=server`; an RWO volume across a surge on two nodes | K | V271 | `k8s-availability-scan` §6 |
| **Shutdown timing** | Load during `rollout restart` → 0 errors; a pod deleted mid-request exits 0/143, not 137 | K | V272 | `k8s-availability-scan` §7 |
| **Platform SPOF** | Kill the single controller pod during load on kind → 5xx before the fix | K | V273 | `k8s-availability-scan` §9 |
| **Config propagation** | A ConfigMap edit leaves `generation` and pod UIDs unchanged before the fix; subPath stale | K | V274 | `k8s-wiring-scan` §1 |
| **Service / endpoints** | The EndpointSlice has ≥ 1 ready endpoint on the named port | K | V275 | `k8s-wiring-scan` §2, §4 |
| **NP DNS and paths** | `nslookup` 1 → 0 → 1 on kind with a policy-enforcing CNI | K | V276 | `k8s-wiring-scan` §3 |
| **Jobs / CronJobs** | A `*/1` schedule with a 90 s job → two active Jobs before the fix | K | V277 | `k8s-wiring-scan` §5 |
| **RBAC wiring** | `kubectl auth can-i --as=system:serviceaccount:<ns>:<sa>` on kind with the rendered RBAC | K | V278 | `k8s-wiring-scan` §6 |
| **Target minor** | Render + kubeconform + dry-run on kind node images of the oldest and newest minor; pluto `--target-versions` | T + K | V279 | `k8s-api-version-scan` §1, §4 |
| **Schema + CRDs** | `kubeconform -strict` with the CRDs catalog, objects read = objects rendered, canaries reported | T | V280 | `k8s-api-version-scan` §2 |
| **Admission rejection** | Dry-run on kind with the namespace PSA labels and the repo's policies; `kyverno apply` offline | T + K | V281 | `k8s-api-version-scan` §3 |
| **Timeout chain** | The hop table; `curl -w '%{http_code} %{time_total}'` through the chain → 504 at the shortest hop while the upstream finishes | S + H | V282 | `edge-reliability-scan` §1, §8; `serverless-reliability-scan` §1 |
| **Keep-alive** | Idle-gap probe at LB-idle ± 1 s; one request id across every hop's log line | H | V283 | `edge-reliability-scan` §2, §7, §11, §15 |
| **Non-idempotent retries** | `edge-harness.py` hit counter: N POSTs through a failing upstream → N executions | H | V284 | `edge-reliability-scan` §3, §9, §10 |
| **Re-resolution** | The upstream IP changes; the proxy follows within the TTL | H | V285 | `edge-reliability-scan` §5 |
| **Streaming** | SSE arrival spacing; `Upgrade` → 101; a reload during an open stream | H | V286 | `edge-reliability-scan` §6, §12 |
| **Silent rejection** | Static typo, dynamic typo, unknown middleware, missing service, missing cert each **fail the deploy step** | T + H | V287 | `edge-reliability-scan` §13, §14 |
| **DNS/TLS lifecycle** | `dig` from 2 resolvers; CAA vs the issuer; `promtool test rules` with a T-21 d series; a renewal on kind | T + K + L | V288 | `dns-tls-lifecycle-scan` §1–§6 |
| **Network correctness** | `cidr-overlap.py` over every CIDR source; Reachability Analyzer when live | T + L | V289 | `network-exposure-audit` §1–§4 |

### Scratch cluster (`kind-harness.sh`)

**Not built yet (2026-10-10).** `k8s-render-scan/scripts/kind-harness.sh` does not ship: only
`render.sh` is in that directory. It is planned to create and delete a throwaway kind cluster at the
target minor with its own kubeconfig. Until it lands, run the raw commands below by hand, in one
shell, with the explicit kubeconfig on every line; a K-tier oracle whose run did not print their
output stays Unconfirmed. The contract the harness will wrap:

```bash
export SCAN="${TMPDIR:-/tmp}/infra-scan"; mkdir -p "$SCAN"; : > "$SCAN/kind.kubeconfig"
kind create cluster --name infra-oracle --image "kindest/node:v${TARGET_MINOR}" --kubeconfig "$SCAN/kind.kubeconfig"
KUBECONFIG="$SCAN/kind.kubeconfig" kubectl -n default get sa default        # wait for it before creating pods
KUBECONFIG="$SCAN/kind.kubeconfig" kubectl apply --dry-run=server -f "$SCAN/render-prod.yaml"
kind delete cluster --name infra-oracle --kubeconfig "$SCAN/kind.kubeconfig"
```

Use a multi-node config (`nodes: [control-plane, worker, worker]`) for spread, RWO and drain
variants; add metrics-server (`--kubelet-insecure-tls`) for HPA variants. kindnet enforces
NetworkPolicy, so the DNS oracle runs as is. Starting docker or a VM for kind is a side effect the
run reports, and stops when it started it.

### Offline Terraform (`terraform test` + plan JSON)

```hcl
# tests/ops_invariants.tftest.hcl, beside a COPY of the module under test
mock_provider "aws" {}
run "data_stores_survive_destroy" {
  command = plan
  assert {
    condition     = aws_db_instance.orders.deletion_protection == true
    error_message = "deletion_protection not true (unset reads null)"
  }
  assert {
    condition     = aws_db_instance.orders.skip_final_snapshot == false
    error_message = "skip_final_snapshot"
  }
}
```

```bash
terraform -chdir="$SCAN/mod" init -backend=false && terraform -chdir="$SCAN/mod" test -json
terraform -chdir="$SCAN/stack" plan -refresh=false -out=tfplan && terraform -chdir="$SCAN/stack" show -json tfplan > "$SCAN/plan.json"
jq -r '.resource_changes[]|select(.change.actions|index("delete"))|"\(.address) \(.change.actions|join(",")) \(.change.replace_paths//[])"' "$SCAN/plan.json"
```

The plan needs fake credentials with the provider's skip flags (`skip_credentials_validation`,
`skip_requesting_account_id`, `skip_metadata_api_check`) and no data source that calls an API.
Tofu needs valid-looking ARNs in `mock_resource` defaults. A root output that references a sensitive
attribute aborts the test run first: test a child module, or that output is the TF-11 finding.
Module-nested resources live under `.configuration.root_module.module_calls.<m>.module.resources`;
walk them recursively. `plan-joins.jq` (`iac-lifecycle-scan/scripts/`) holds the stateful-replace,
`vis.jq`, API-Gateway ↔ Lambda and bucket ↔ versioning joins.

### Render ledger

```bash
bash k8s-render-scan/scripts/render.sh . --out="$SCAN" --kube-version="$TARGET_MINOR"
kubeconform -strict -summary -output json -kubernetes-version "$TARGET_MINOR" \
  -schema-location default -schema-location '<CRDs-catalog URL>' "$SCAN/render-prod.yaml" "$SCAN/canary.yaml"
pluto detect-files -d "$SCAN" -o json --target-versions "k8s=v$TARGET_MINOR"
bash k8s-availability-scan/scripts/availability.sh "$SCAN" --repo=.      # § 1–§ 9 class rows, every env
bash k8s-wiring-scan/scripts/wiring.sh "$SCAN" --repo=.                  # § 1–§ 6
bash k8s-api-version-scan/scripts/apiversion.sh "$SCAN" --target="$TARGET_MINOR"
```

**Fails first** means the class row prints for the cited object before the fix and is gone after it,
in every environment's render. Never `-ignore-missing-schemas` for core groups: it turns a removed
API into `skipped`, exit 0.

### Edge harness (`edge-harness.py`)

`edge-reliability-scan/scripts/edge-harness.py` (stdlib, `python3 -I`) is an upstream that counts
hits per method and path, can stall, close mid-body, return 502/503/504 or stream SSE, and probes an
idle gap. It runs behind the project's **own** proxy image or config (a stock `caddy` cannot load an
`xcaddy` build, precedents § 49), never in front of a real service. `curl -w '%{http_code}
%{time_total}\n'` drives the timing variants; `curl --http3-only` the protocol variant.

### Cost candidates (no V of their own)

COST-01…07, 09–13 and N4 are candidates, not findings. Their proof is the plan value (P) plus the
quantity expression `quantity × unit (price key) = per-hour or per-month expression`, written out
under the `/cost-audit` arithmetic halts. A `$` appears only with a cited bill line or a dated
pricing page; finops prices the candidates when installed. Log retention (V260) and scale ceilings
(V261) have class oracles because their failure is a behaviour, not a price.

### Class variants (infrastructure)

#### V244. State lock, hygiene and plan discipline — parallel plan + test (`iac-state-scan` §1, §2, §4–§6)
- backend `s3` with `dynamodb_table` only (deprecated), no `use_lockfile = true`, no `encrypt`; local state or no backend in a team repo (CODEOWNERS, a CI apply job); a committed `*.tfstate*`; Terragrunt `remote_state {}`; Pulumi `backend.url` / `PULUMI_BACKEND_URL`; Tofu `encryption {}` absent where policy needs it
- TF-11: a secret-shaped `variable` without `sensitive = true`, outputs referencing it, `random_password` / `tls_private_key` outputs; a write-only `*_wo` argument or ephemeral resource available at the locked provider version and unused (TF-02 values → security `secret-scan`)
- TF-09 no scheduled `plan -refresh-only -detailed-exitcode`; TF-14 `-target=` / `-exclude=` outside a break-glass runbook; an apply of a fresh plan instead of the saved file; CFN `detect-stack-drift` never run
- TF-12 `terraform.workspace ==` branching on prod; one backend key for every environment; prod and non-prod sharing credentials; TF-15 `default_tags` absent (plan `tags_all == {}`); TF-16 no `*.tftest.hcl`, `precondition` or `check` (low)
- pass: one of two parallel `plan -lock-timeout=0s` fails on the lock; the state bucket is versioned; `terraform test` is clean of "Output refers to sensitive values"; a scheduled drift job exits 0 or 2, never unread

#### V245. Pinning (IV-3) — readonly init (`iac-state-scan` §3)
- `required_version` absent or open-ended; each `required_providers` entry without a constraint; `.terraform.lock.hcl` missing or missing a CI platform (`runs-on`); a git module without a SHA (a tag pin is precedents § 27); a registry module without `version`; nested module sources inside fetched modules; TF 1.15 dynamic sources resolved; Terragrunt `source = "…?ref="`; Pulumi and CDK package lockfiles
- PIN-HELM: `helm (upgrade --install|install) <rel> <repo>/<chart>` without `--version` in a runbook, Makefile or CI file; Argo `targetRevision: HEAD`, `*` or a range; Flux `HelmRelease.spec.chart.spec.version` with a semver range
- pass: `init -lockfile=readonly` succeeds on every CI platform, `modules.json` resolves to immutable refs, and every platform-component install names a `--version`

#### V246. Identity (IV-4) — churn plan (`iac-lifecycle-scan` §1)
- `count = length(<collection>)` → `for_each` keyed by a stable id + a `moved` block per address, module renames included; a `for_each` key derived from a mutable value
- CDK construct-id churn in loops (`` new X(this, `…${i}`) ``), `overrideLogicalId`, `cdk refactor`; Pulumi rename or re-parent without `aliases`; CFN logical-id rename base → head
- Kubernetes selectors changed through a label helper or `commonLabels` (V265 owns the apply proof)
- pass: the churn plan after the fix destroys only the intended key; `cdk diff` / `pulumi preview` show no replace of a stateful resource

#### V247. Lifecycle and refactor blocks — two plans (`iac-lifecycle-scan` §2, §3, §5, §6)
- TF-06 `ignore_changes = all` (autoscaler-mutated fields are precedents § 25); `create_before_destroy` on a fixed-name resource
- TF-07 `removed {}` or `lifecycle { destroy = false }` (TF 1.16 / Tofu 1.12) or Tofu `enabled =` where destroy was meant: an orphan that keeps billing (precedents § 28)
- TF-10 `provisioner "local-exec"`, `null_resource` / `terraform_data` migrations, `data "external"`
- TF-13 perpetual diff: `timestamp()`, `uuid()`, `most_recent = true` feeding an `ami`
- pass: a second consecutive plan is empty; `action_reason` and Tofu's forgotten count match the documented hand-off (ADR); no side effect lives only in a provisioner

#### V248. Stateful replace — plan + conftest (`iac-lifecycle-scan` §4)
- `.change.actions == ["delete","create"]` or `["create","delete"]` on a stateful type (DB instance or cluster, volume, bucket, file system, KMS key, queue with messages, DNS zone, StatefulSet PVC) with its `replace_paths`; a ForceNew attribute edited (engine, AZ, `storage_encrypted`, `identifier`, Azure geo-redundant backup)
- CFN replacement in a change set; `cdk diff` `[-/+]`; Pulumi `replace`
- pass: the conftest deny over the plan fails before the fix; after it the plan shows an in-place update, or the replacement carries a snapshot → restore → cut-over plan with an ADR (`/infra-fix` stops before it)

#### V249. Deletion safety (IV-1) — test + guard proof (`iac-lifecycle-scan` §7; `dr-audit` §12 corroborates)
- TF `prevent_destroy` (+ Tofu `= var.x`); provider `deletion_protection` / `deletion_protection_enabled` / `enable_deletion_protection`; Cloud SQL TF flag **and** `settings.deletion_protection_enabled`
- CFN `DeletionPolicy` + `UpdateReplacePolicy` + stack termination protection; CDK `RemovalPolicy.DESTROY`, `autoDeleteObjects: true`; Pulumi `protect: false` / `retainOnDelete`; a rendered StorageClass `reclaimPolicy: Delete` under system-of-record PVCs
- `force_destroy` / `force_delete` / azurerm purge features; `skip_final_snapshot` / `final_snapshot_identifier` / `final_backup_config` / EBS `final_snapshot`; `delete_automated_backups = true`; KMS `deletion_window_in_days` < `THR-KMS-WINDOW` on a data key
- the module default that reaches prod (precedents § 18 flip); DigitalOcean / Hetzner / other provider equivalents only where the provider has the attribute at the locked version [K?]
- backups inside the destroyable state (R11)
- pass: `terraform test` asserts `== true` per spelling; a forced replacement fails `plan` with the guard; cfn-lint `--include-checks I` reports no `I3011`; a staging destroy drill leaves the backups and final snapshot in place

#### V250. Backups and PITR (IV-2) — test + describe (`dr-audit` §1–§7)
- RDS instance (`backup_retention_period` doc default 0 — assert on the plan value [K?]), Aurora cluster (default 1 day), DocDB, Neptune, Redshift, ElastiCache / MemoryDB, DynamoDB PITR (+ global-table replicas), Cloud SQL backup + PITR + `transaction_log_retention_days`, Azure PG / MySQL flexible (`backup_retention_days`; geo-redundant **at create**), Cosmos continuous, EBS (DLM / AWS Backup selection), EFS backup policy, S3 versioning + noncurrent expiry + multipart abort (DATA-09)
- retention ≥ `THR-BACKUP-RETENTION` (discovery lag; Velero default TTL 720 h); DATA-03 single-AZ prod store; DATA-04 storage growth uncapped (`max_allocated_storage` unset); DATA-07 `apply_immediately = true`, an EOL major on Extended Support; DATA-08 a cache used as a store (precedents § 29)
- the managed provider's own window vs the repo's logical dumps, per store
- pass: `terraform test` holds retention and PITR for every store type present; the live describe on a confirmed profile agrees (else `NO-DATA(<profile>)`)

#### V251. Immutability and writer-can-delete — deny simulation (`dr-audit` §8)
- R3 backups in the app's own bucket, account or project (the backup Job's `s3://` / `gs://` / `az://` URI or `BACKUP_*_URI` equals the app's upload bucket); DATA-10 copies inside the prod blast radius
- R4 no Object Lock, or **governance** mode (precedents § 38); no vault lock; R5 the writer or the app key can delete, overwrite or re-policy backups
- every identity that touches the backups: the app role, the backup role, a CI deploy role
- pass: `iam simulate-principal-policy` (or the provider's key-scope listing) **denies** delete and policy changes for each identity; `get-backup-vault-lock-configuration` shows compliance mode (the exposure chain over the backup prefix is security's)

#### V252. RPO arithmetic (R1) — written-out table (`dr-audit` §9)
- each store's schedule × retention × discovery lag × replication delay against the declared RPO and RTO (`ai/runbooks/*restore*`, ADRs, the multi-region block)
- no declared table → `blocked (no declared objectives)`, which forces GO-UNVERIFIED; an objective is never invented
- pass: every store's worst-case loss window and restore time fit its declared objective, with the arithmetic written out

#### V253. Restore evidence (R10) and off-host backups (C7) — restore record (`dr-audit` §11, §12)
- a drill record with a job id, a **new** target, a row-count or checksum diff, a measured duration against RTO and a date within `THR-BACKUP-DRILL-AGE`; each stateful store type (managed DB, operator Postgres, PV, object store, Redis with persistence, etcd)
- R11 backups that survive `terraform destroy` of the stack; C7 a single host with no off-host copy
- pass: the record carries every evidence field of `THR-BACKUP-DRILL-AGE`, or a restore to scratch produces them; a store with no drill is a BLOCK finding, not an unchecked row

#### V254. Operator backups — tool checks (`dr-audit` §10)
- R6 Velero `snapshotVolumes: false` or no file-system backup on a namespace with PVCs (precedents § 37); R7 WAL archiving that lies (`archive_command` that always succeeds, `pgbackrest` stanza unchecked, `repo1-retention-full` unset); R8 CNPG / zalando cluster with no backup stanza (CNPG in-tree `barmanObjectStore` deprecated since 1.26; zalando `logical_backup_s3_retention_time` empty keeps everything); R9 self-managed etcd without snapshots (managed control planes are precedents § 37)
- pass: `pgbackrest --stanza=<s> check` passes and `pg_stat_archiver.failed_count` stays 0; `velero backup describe <b> --details` lists PV data; `kubectl cnpg status` on a scratch cluster shows a completed backup; `etcdutl snapshot status` reads the snapshot

#### V255. Queue timing (IV-5) — `vis.jq` (`serverless-reliability-scan` §2)
- Lambda + SQS standard and FIFO; a batching window added; Lambda Managed Instances (90 min, precedents § 24); ECS or Kubernetes workers polling SQS (visibility vs the worst-case job); SNS → SQS → Lambda; EventBridge Pipes; Cloud Run + Pub/Sub push (ack deadline); Azure Functions + Service Bus (lock duration)
- pass: `vis.jq` prints nothing: every `visibility ≥ 6 × (timeout + batching window)` per `THR-QUEUE-VISIBILITY` (AWS itself rejects only below 1×)

#### V256. DLQ path (IV-6) — plan join (`serverless-reliability-scan` §3)
- SQS redrive with DLQ retention > source retention; Lambda async destination / DLQ (precedents § 19 for SQS-polled functions); stream event-source `destination_config` + `maximum_retry_attempts` (default -1, forever) + `bisect_batch_on_function_error`; EventBridge target DLQ; SNS subscription redrive; Step Functions `Catch`; Pub/Sub `dead_letter_policy`; Service Bus `max_delivery_count`
- pass: every source in the plan has a dead-letter path whose retention outlives the source's

#### V257. Partial batch — one-bad-record unit test (`serverless-reliability-scan` §4)
- `function_response_types` missing `ReportBatchItemFailures`; set while the handler never returns `batchItemFailures` on some catch path; CDK `SqsEventSource({ reportBatchItemFailures })`; SAM `FunctionResponseTypes`; Serverless Framework `functionResponseType`
- pass: a unit test with one failing record in a batch of N returns exactly that record's id, and the other N-1 are not redelivered

#### V258. Concurrency ceiling and cold-start cost — plan + arithmetic (`serverless-reliability-scan` §5, §7–§9)
- SLS-05 reserved or ESM maximum concurrency unbounded toward a finite downstream (DB `max_connections`, a rate-limited API); `reserved_concurrent_executions = 0` disables the function (a separate finding); SLS-08 provisioned concurrency or min instances on a non-latency path; SLS-09 memory at the extremes (low); SLS-10 Cloud Run / Functions / Azure Functions max instances, concurrency and timeout shape
- pass: `max concurrency × connections per instance ≤ downstream limit`, written out with both values cited; a cold-start control names its latency requirement

#### V259. Retry storm — one poison record (`serverless-reliability-scan` §6)
- stream sources with `maximum_retry_attempts = -1`; no `maximum_record_age_in_seconds`; no bisect; SDK retries × platform retries × queue redelivery multiplying; async invoke retries on a non-idempotent handler
- pass: one bad record injected on a sandbox stack is retried a bounded number of times, lands in the dead-letter path, and `IteratorAge` recovers (L on a sandbox the user names, else the static product of retry counts)

#### V260. Log retention (IV-8) — plan vs HCL (`iac-cost-scan` §3)
- explicit log groups with `retention_in_days` unset (0 = never expire, so a plan-based check passes, precedents § 52); Lambda auto-created `/aws/lambda/*`; API Gateway execution and access logs; VPC flow logs; RDS `enabled_cloudwatch_logs_exports`; ECS `awslogs-create-group`; GCP log bucket `retention_days`; Azure Log Analytics `retention_in_days`; proxy access logs with health and static paths not excluded (E6)
- self-hosted Loki / Prometheus retention is observability's; audit-log retention too short for compliance is security's
- pass: every log sink in the plan has a finite retention, and each auto-created group is declared in IaC with one

#### V261. Scale ceilings (IV-9) — quantity arithmetic (`iac-cost-scan`; `serverless-reliability-scan` §5)
- ASG max; ECS service autoscaling max; Lambda reserved + ESM maximum concurrency; Cloud Run max instances (default 100); DynamoDB autoscaling max and static `PROVISIONED`; Aurora Serverless v2 `max_capacity`; Azure `app_scale_limit`; HPA `maxReplicas` and KEDA `maxReplicaCount` × requests vs the namespace quota (K-HPA-COST)
- pass: every autoscaler has a max (`THR-SCALE-CEILING`), and `max × unit` is written out against the quota; a capacity increase is the user's decision

#### V262. Render matrix (+ Helm values xref) — render + validate (`k8s-render-scan` §0–§2)
- every `values-<env>.yaml` and CI `--set`; subchart values; `Capabilities` branches at the oldest and newest target `--kube-version` (precedents § 12); hooks; `crds/`; library charts; `tpl` strings
- every overlay over its base; Argo `valueFiles` / `parameters` / in-Application patches; Flux `postBuild.substitute`, `HelmRelease.spec.values`
- K-HELM-VALUE-UNUSED / -UNDEFINED (`helm-values-xref.sh`); K-HELM-LOOKUP (empty offline and under Argo); -CRDS; -HOOK-DELETE; -REQUIRED
- pass: every env renders with exit 0 and an empty `render.err` for the class, kubeconform reads every object, and a `values.schema.json` with `additionalProperties: false` makes `helm lint --strict` fail on a typo key

#### V263. Patch no-op and phantom — render diff (`k8s-render-scan` §3)
- K-KZ-PATCH-NOOP: a strategic-merge or JSON6902 patch whose `target` (name, label, kind) or path matches nothing; K-KZ-PHANTOM: an SMP naming a container that does not exist (K-IMAGE-MISSING corroborates); -NAMEPREFIX references not rewritten; -HASH generators referenced by a literal name; -COMMONLABELS (deprecated, rewrites selectors); `components`; a remote base by an unpinned ref
- pass: `kz-patch-noop.sh` shows the render with and without each patch differs exactly where the patch intends

#### V264. SSA / upgrade twice — kind (`k8s-render-scan` §2)
- K-HELM-REPLICAS: a chart that renders `replicas` for an HPA or KEDA target; K-HELM-SSA under Helm 4 server-side apply; K-HELM-FLAGS: `--atomic` / `--force` in CI under Helm 4 (`--rollback-on-failure`, `--force-replace`, `--wait` strategies)
- pass: `helm upgrade` twice on kind (Helm major as CI runs it) exits 0, and the HPA-set replica count survives both

#### V265. Selector mutation — base then head on kind (`k8s-render-scan` §5)
- `spec.selector` changed base → head on a Deployment, StatefulSet, DaemonSet or Job, through a label helper, `commonLabels`, a chart `fullname` change or a rename; a Service selector changed in the same apply (non-atomic: the Service moves, the workload is rejected)
- pass: apply the base render, then the head render, on kind: no `field is immutable` error, and the Service's EndpointSlice stays non-empty throughout

#### V266. GitOps spec — diff on scratch (`k8s-render-scan` §4)
- K-GITOPS-REPLICAS (`selfHeal` × an HPA or KEDA target with `replicas`; precedents § 14); -PRUNE (prune off with deleted objects, or on with shared objects); -WAVES (a dependency synced before its CRD or namespace); -IGNORE-WIDE (`ignoreDifferences` over a whole kind or `/spec`)
- live reconciliation drift is devops `gitops-audit`
- pass: `argocd app diff` / `flux diff` on a scratch cluster show no reset of autoscaler-owned fields and the intended prune and order; with no scratch controller, the static two-ended trace (the Application spec and the controller's default at its pinned version)

#### V267. Pod-template classes (+ StatefulSet) — class rows + dry-run (`k8s-availability-scan` §1, §2, §8)
- every template: Deployment, StatefulSet, DaemonSet, Job, CronJob `jobTemplate.spec.template`, Argo Rollout (`template` or `workloadRef`), bare Pod; every container, not `[0]`; initContainers and native sidecars (`restartPolicy: Always`); ephemeral containers excluded
- K-RES-MISSING (CPU request, memory request, memory limit — no CPU-limit row, precedents § 1), K-MEM-OVERCOMMIT, K-QUOTA-SHAPE, K-PRIORITY; K-PROBE-SAME, -READINESS-MISSING, -STARTUP, -EXEC-TIMEOUT (default timeout 1 s), -GRPC, -JOB (precedents § 3); a liveness path on a dependency prints `route → performance request-path-scan §15`
- StatefulSet: K-STS-SVC (`serviceName` without a headless Service), -VCT [K?: mutability on 1.35+], -PVC-RETENTION
- a fleet-wide shape (memory limit = 2–4 × request on every workload) is one finding with N sites, fixed at the base or chart helper
- pass: `k8s-availability-scan/scripts/availability.sh` prints no row for the class on any env's render, and `apply --dry-run=server` on kind admits every template

#### V268. PDB drain — eviction dry-run (`k8s-availability-scan` §3)
- K-PDB-BLOCK: `minAvailable` ≥ the floor or `maxUnavailable: 0`, where the floor is HPA `minReplicas`, KEDA `minReplicaCount` (default 0), Rollout `spec.replicas` or `spec.replicas` (default 1) — precedents § 42; a PDB on 1 replica; percentage PDBs against the HPA floor; -MISSING on a served prod workload at ≥ 2 replicas; -ORPHAN (selector matches nothing); -UNHEALTHY (`unhealthyPodEvictionPolicy` not `AlwaysAllow`); K-PDB-API (`policy/v1beta1`); K-HPA-PDB; `matchExpressions` selectors; same namespace only
- pass: on kind, `drain --dry-run=server --ignore-daemonsets` (or an Eviction with `dryRun: ["All"]`) allows ≥ 1 eviction with every pod healthy, per `THR-K8S-PROD-FLOOR`

#### V269. Scaling (HPA / KEDA) — conditions on kind (`k8s-availability-scan` §4)
- K-HPA-NOREQ (a resource metric on a container with no request → `ScalingActive False`); -REPLICAS (`replicas` rendered on an HPA target, fought on every client-side apply); -MINMAX (`min == max`, `min` 1 on a served prod workload); -VPA (VPA `Auto` on the HPA's metric); -BEHAVIOR; KEDA `minReplicaCount: 0` on a served workload; HPA → StatefulSet / Rollout targets
- pass: HPA `ScalingActive` is True on kind with metrics-server; an apply leaves `.spec.replicas` to the autoscaler; the floor read from the render meets `THR-K8S-PROD-FLOOR`

#### V270. Spread — multi-node placement (`k8s-availability-scan` §5)
- K-SPREAD (no constraint where a PDB, SLO or zone-loss requirement needs a guarantee; precedents § 44), -HARD (`DoNotSchedule` that strands a rollout), -ROLLOUT (`matchLabelKeys` missing so old and new ReplicaSets count together); zone constraints on a single-zone cluster are precedents § 8
- pass: on a 3-node kind cluster the replicas place per the declared constraint, and a rollout completes under it

#### V271. Rollout shape — dry-run + RWO surge (`k8s-availability-scan` §6)
- K-ROLLOUT-SHAPE (`maxSurge: 0` with `maxUnavailable: 0`, or `maxUnavailable` taking a 2-replica service to 0), -DEADLINE (`progressDeadlineSeconds` shorter than a cold start), K-HISTORY (`revisionHistoryLimit: 0`), K-RWO-ROLLING (an RWO PVC under `RollingUpdate`), K-STATEFUL-RECREATE, K-DS-UPDATE, K-STS-PODMGMT, K-SELECTOR-TEMPLATE (selector ≠ template labels), K-PULLPOLICY (citing security 4j; precedents § 9, § 50)
- pass: `apply --dry-run=server` on kind admits the shape; a two-node rollout with an RWO volume completes (`Recreate` or RWX) instead of `Multi-Attach` until the deadline

#### V272. Shutdown timing — rollout under load (`k8s-availability-scan` §7)
- K-SHUTDOWN-PRESTOP (no `preStop` delay on a served workload behind an endpoint-propagating LB); K-SHUTDOWN-GRACE (`preStop + app drain + 5 s > terminationGracePeriodSeconds`, `THR-SHUTDOWN-GRACE`; the drain from devops `deploy-safety-scan` §5 or a code constant, precedents § 46); `exec: [sleep, N]` (unvalidated) vs native `sleep` (GA 1.34, validated, precedents § 61); K-SIDECAR-ORDER (a sidecar that exits before the app drains); workers judged on checkpointing, not `preStop`
- pass: load through the Service during `rollout restart` gives 0 errors (3 runs, within the noise band); a pod deleted mid-request ends with exit 0 or 143, never 137, and the request completes

#### V273. Platform SPOF — controller kill on kind (`k8s-availability-scan` §9)
- K-PLATFORM-SPOF: a request-path component installed by a runbook, Makefile or Argo `Application` (precedents § 45) — ingress or Gateway controller, CoreDNS customisation, cert-manager webhook, KEDA operator, metrics-server under an HPA — with no replica count or PDB, so it inherits the chart default at the pinned version (unpinned → Unconfirmed, V245); K-INGRESS-RETIRED corroborates (V279)
- pass: with the chart's values at its pinned version on kind, killing one controller pod during load gives 0 5xx; the install sets ≥ 2 replicas and a non-blocking PDB

#### V274. Config propagation — edit on kind (`k8s-wiring-scan` §1)
- K-CONFIG-ROLL: a ConfigMap or Secret consumed with no checksum annotation, Reloader, hash suffix or `immutable` + versioned name (precedents § 13); a hand-bumped `*-revision` annotation is partial (precedents § 43); K-SUBPATH (a `subPath` mount never updates); K-ENV-SECRET-ROTATE (env from a rotated Secret); an embedded proxy config without `--watch` or a reload hook
- pass: on kind, editing the source and re-applying the render rolls the pods (template hash changes); a directory mount shows the new value; no subPath mount holds config that changes

#### V275. Service and endpoints — EndpointSlice (`k8s-wiring-scan` §2, §4)
- K-SVC-SELECTOR (matches no pod; `matchExpressions`), -PORT (named `targetPort` absent on the container, numeric mismatch), K-IMAGE-MISSING, K-INGRESS-BACKEND (Service or port absent), HTTPRoute `parentRefs` / `allowedRoutes` / `ResolvedRefs`; selector-less Services; same namespace only (absent = the release or kustomize namespace)
- K-NS-MISSING (an object in a namespace nothing creates and the platform does not own); K-CM-SIZE (a ConfigMap over 1 MiB)
- pass: every Service's EndpointSlice has ≥ 1 ready endpoint on the named port on kind; every namespace exists before its objects; HTTPRoute status shows `Accepted` and `ResolvedRefs` True

#### V276. NP DNS and paths (N5) — nslookup on kind (`k8s-wiring-scan` §3)
- K-NP-DNS: an egress policy with no UDP **and** TCP 53 allow to kube-dns (label as the cluster names it); NodeLocal DNSCache at `169.254.20.10` needing an ipBlock; CoreDNS in another namespace; Cilium / Calico / VPC CNI semantics
- an egress policy that omits a dependency the app's config names (DB / Redis host:port from the deploy config, the OTLP endpoint, IMDS / STS for a pod that needs them) — read, not grep
- policy width is security 4k
- pass: on kind with a policy-enforcing CNI, `nslookup kubernetes.default` answers under the policy, and a connection to each configured dependency succeeds

#### V277. Jobs and CronJobs — schedule overlap (`k8s-wiring-scan` §5)
- K-CRON (`concurrencyPolicy: Allow` default on a non-idempotent job; `startingDeadlineSeconds` unset; no `activeDeadlineSeconds`), K-JOB (`backoffLimit` default 6 on a side-effect job), K-CRON-TZ (`CRON_TZ=` in `schedule` is rejected; `timeZone` GA 1.27), K-JOB-RESTART; CronJob-owned Job TTL is precedents § 10
- pass: on kind, a `*/1` schedule with a 90 s job never has two active Jobs (`Forbid`), and a failing Job stops within its deadline

#### V278. RBAC wiring — can-i on kind (`k8s-wiring-scan` §6)
- `serviceAccountName` with no rendered ServiceAccount and no platform owner; a RoleBinding or ClusterRoleBinding whose `roleRef` or subject is absent; a binding to a Role in another namespace; `automountServiceAccountToken: false` on a workload whose code or image calls the API (client-go, `@kubernetes/client-node`, the `kubernetes` Python client, a controller image); a controller or collector Role missing a verb its docs require at its pinned version
- privilege breadth (wildcards, `cluster-admin`, `escalate` / `bind` / `impersonate`, cluster-wide `secrets`, `pods/exec`, `nodes/proxy`, token automount on a non-API workload, default-SA use) is security's
- pass: `kubectl auth can-i <verb> <resource> --as=system:serviceaccount:<ns>:<sa>` on kind with the rendered RBAC answers `yes` for every verb the workload needs

#### V279. Target minor — render + dry-run at both ends (`k8s-api-version-scan` §1, §4)
- K-API-REMOVED at the oldest and newest target minor (`policy/v1beta1` PDB and `batch/v1beta1` CronJob 1.25, `autoscaling/v2beta2` HPA 1.26, `networking.k8s.io/v1beta1` Ingress 1.22); a `Capabilities` guard (precedents § 12); Helm `--api-versions` in CI
- support status: the target minor outside the supported window (1.34 EOL 2026-10-27, precedents § 62); K-INGRESS-RETIRED (an ingress-nginx image or chart in the platform inventory); cert-manager, KEDA, Argo CD and Flux minors past their support
- pass: render + kubeconform + `apply --dry-run=server` on kind node images of the oldest and newest minor are clean, and pluto `--target-versions` reports 0 with the canary flagged

#### V280. Schema + CRDs — strict validation (`k8s-api-version-scan` §2)
- core kinds and CRDs: PrometheusRule, ServiceMonitor, PodMonitor, KEDA ScaledObject, cert-manager Certificate / ClusterIssuer, Gateway API HTTPRoute, Argo Application / Rollout, Flux kinds; YAML-1.1 coercion (`name: n` → `"false"`, `on`, `yes`); a CRD missing from the catalog (NOT-RUN for that kind, never skipped)
- PromQL content is observability `alert-rule-lint`
- pass: `kubeconform -strict` with the CRDs catalog reads every rendered object (count matches the render ledger), reports the canaries, and finds 0 invalid

#### V281. Admission rejection — dry-run with policies (`k8s-api-version-scan` §3)
- K-PSA-LABELS: a namespace `enforce: restricted` (or `baseline`) whose own workloads violate it; the repo's Kyverno / ValidatingAdmissionPolicy / Gatekeeper policies applied offline (`kyverno apply --resource`; one unmappable GVK aborts the run → NOT-RUN); a weak enforce level is security's
- pass: `apply --dry-run=server` on kind with the namespace labels and the repo's policies installed admits every workload, and `kyverno apply` reports 0 failures on a run that read every resource

#### V282. Timeout chain (IV-7) — hop table + curl (`edge-reliability-scan` §1, §8; `serverless-reliability-scan` §1)
- every hop of each public route: CDN (CloudFront `origin_read_timeout`, Cloudflare proxied [K?]), LB idle (ALB 60 s, GCP backend service 30 s, DO LB annotations), API Gateway (REST regional / private / edge, HTTP API; precedents § 24), ingress (annotations, Gateway `HTTPRoute.timeouts`), proxy (nginx `proxy_read_timeout`, Caddy `response_header_timeout`, Traefik `serversTransport`, HAProxy `timeout server` — unset is infinite, Envoy route 15 s), sidecar, app server (Node `requestTimeout`, Fastify, gunicorn `--timeout`, uvicorn, Go `http.Server`, Puma), **the app's own HTTP client**, DB `statement_timeout`; Lambda ↔ API Gateway integration (SLS-01)
- E12 upload and body: `client_max_body_size`, `proxy-body-size`, Traefik `readTimeout` against the slowest legitimate upload (`0` = unlimited is security's)
- HTTP/1.1 and HTTP/2; a cold start after deploy; the slowest legitimate route class (exports, reports, uploads, webhooks; SSE and WS exempt → V286)
- pass: the hop table holds `each request timeout ≥ the slowest legitimate request behind it` with every value cited; `curl -w '%{http_code} %{time_total}'` through the chain completes the slowest route, and a 5 MB slow upload completes

#### V283. Keep-alive (+ hop headers and access logs) — idle-gap probe (`edge-reliability-scan` §2, §7, §11, §15)
- E2 idle inversion: each hop's idle timeout must exceed the idle timeout of the hop in front of it (ALB 60 s → Node `keepAliveTimeout` 5 s is the canonical 502; GCP needs > 600 s); E10 upstream keepalive unused (version-gated, precedents § 33)
- E11 forwarding headers, redirect-loop half (`X-Forwarded-Proto` not trusted behind TLS termination → an http → https loop; client-IP trust is security 7e); E15 compression (`gzip_types`, `gzip_proxied`; the CDN compresses or not)
- E6 access-log volume (health and static not excluded); E21 format: a request id minted (`$request_id`, `{http.request.uuid}`, ingress-nginx `generate-request-id` [K?]) and forwarded (`X-Request-Id`), upstream timing fields present; log **content** is security `data-exposure-scan` §6
- pass: an idle-gap probe at LB-idle − 1 s and + 1 s gives no 502; an http request redirects once; one request through every hop carries one id in every hop's log line with upstream timing

#### V284. Non-idempotent retries (E3) — hit counter (`edge-reliability-scan` §3, §9, §10)
- POST, PUT, PATCH, DELETE × connect-refused (safe), timeout-after-send, 502/503/504 from upstream, reset mid-body × every layer: nginx `proxy_next_upstream` with `non_idempotent` (default is precedents § 35), Caddy `lb_retry_match` with a write method (precedents § 48), Envoy `retry_policy` with no method gate, Traefik `retryNonIdempotentMethod: true`, HAProxy `retry-on`, mesh retries, client SDK retries, queue redelivery; with and without an idempotency key the app enforces **and** the client sends
- E13 rate-limit shape, ops half: `limit_req` without `burst`; `$binary_remote_addr` behind a CDN; 503 vs 429; E14 health checks: passive only, a deep check that ejects the whole pool, HAProxy `server` without `check`
- pass: `edge-harness.py` counts exactly N executions for N POSTs through a failing upstream; 10 parallel requests get 429, not 503; killing one upstream sheds only its share

#### V285. Re-resolution (E7) — upstream IP change (`edge-reliability-scan` §5)
- a variable `proxy_pass` with no `resolver`; a literal ELB, RDS or SaaS hostname in an `upstream` block resolved once at start; `resolve` on upstream servers; IPv6 answers (`ipv6=off`); resolver timeout; TTL-0 records; a headless or ExternalName Service (ClusterIP is precedents § 32)
- pass: the harness changes the upstream's address and the proxy follows within the record's TTL, with no 502 window beyond it

#### V286. Streaming (E8/E9) and drain (E16) — SSE spacing + reload (`edge-reliability-scan` §6, §12)
- SSE, long-poll, chunked download, gRPC-web, WebSocket, HTTP/2 streams; idle longer than every read timeout; buffering (version-gated: precedents § 30); `Upgrade` / `Connection` headers forwarded
- E16 drain on reload or rollout: nginx `worker_shutdown_timeout`, Traefik `graceTimeOut`, HAProxy `hard-stop-after`, Caddy `grace_period` / `stream_close_delay`; a reload during an open stream
- pass: SSE events arrive at the upstream's spacing, not batched; an `Upgrade` request gets 101; a reload or rolling restart under load closes no open stream before its drain window

#### V287. Silent rejection (E17) and protocol support (E18–E20) — the deploy step fails (`edge-reliability-scan` §13, §14)
- a static typo, a dynamic typo (Traefik drops the whole file and keeps running), an unknown middleware reference, a route to a missing service, a missing cert file: each must **fail the deploy step**, not log (precedents § 40)
- validation lanes: `nginx -t -p $SCAN`, `caddy adapt` / `caddy validate` **with the project's own image when plugins exist**, else NOT-RUN (precedents § 49); Traefik booted against an empty provider then grep `ERR`; `haproxy -c`; `envoy --mode validate`
- E18 HTTP/3 advertised (Caddy `protocols` unset) behind a TCP-only LB; E19 on-demand TLS `ask` endpoint returning 200 for an unknown domain (Caddy 2.8+ fails closed with no `ask`); E20 ingress-nginx still deployed (one finding per site with K-INGRESS-RETIRED)
- pass: each seeded typo makes the deploy step exit non-zero; `curl --http3-only` either succeeds or h3 is not advertised; the `ask` probe refuses an unknown domain

#### V288. DNS/TLS lifecycle (D2–D7, K-CERT) — dig + promtool + renewal (`dns-tls-lifecycle-scan` §1–§6)
- D2 TTL above `THR-DNS-CUTOVER-TTL` on a record a failover or cutover changes; D3 CAA vs the ACME CA in use (apex, wildcard `issuewild`, each zone cut, a second CA; a missing CAA is LOW, precedents § 36); D4 DNSSEC with a deletable KSK key; D5 no expiry signal for an inventoried cert (cert-manager `Certificate`, Caddy managed domains, LB certs) — the rule's quality is observability's; D6 non-prod issuing from the production ACME endpoint, K-CERT-ISSUER (prod on staging, duplicate `secretName`); D7 OCSP residue, client-auth EKU removal breaking mTLS; K-CERT-ROTATION (`rotationPolicy: Always` from cert-manager 1.18 vs pinned trust); K-CERT-RENEW (`renewBefore ≥ duration`); ARI vs non-ARI renewal
- **record target lifecycle** (§1): a record whose address belongs to an object something can delete — a LoadBalancer Service, a cluster teardown, an EIP or reserved IP with no deletion guard — while others hold a copy (customers' registrars, partners' allowlists). A static trace (S): the record value, the object that owns the address, and the guard or its absence. Read the configured TTL at the authoritative NS (`dig +noall +answer <name> @<NS>`); a recursive resolver prints the remaining TTL (precedents § 64)
- **CDN-terminated probe** (§4): an expiry probe through a proxied name reads the CDN's edge certificate, so the origin and on-demand certificates have no signal (precedents § 65); the variant probes the origin directly, or lists the certificates the probe cannot see
- CAA against Caddy's default issuer chain (Let's Encrypt, then ZeroSSL): a CAA naming only one CA blocks the fallback only (precedents § 66)
- D1 dangling DNS is security's (`finding-verification.md`); infra runs it only as the tagged fallback
- pass: `dig` from 2 resolvers agrees with the declared records and CAA names the issuer; `promtool test rules` fires the expiry alert at T-21 d (`THR-CERT-EXPIRY-ALERT`); a renewal on kind with cert-manager at the pinned version issues from the right issuer

#### V289. Network correctness (N3, N7, N8, N-PEER-ROUTE, N-PRIVDNS) — overlap script (`network-exposure-audit` §1–§4)
- N3 NACL asymmetry (stateless: the return path's ephemeral ports); N7 overlapping CIDRs across VPCs, peerings, TGW, VPN and pod / service ranges; N8 IPv6 parity, connectivity half (v6 routed and allowed where v4 is); declared vs running drift (§4, live)
- **peer routes** (N-PEER-ROUTE, §1): a peering or TGW attachment the app uses with no route to the other side's CIDR on one side; a route made by `count`/`for_each` over every table covers every side — read the expansion first
- **NAT zone affinity** (§1): a prod private route table in zone B whose default route uses zone A's NAT, so one zone's loss takes every zone's egress (NAT per AZ in prod is precedents § 23, intended)
- **path MTU and ICMP** (§1): a path across a VPN, an internet gateway or inter-region peering (1500 / 8500 bytes, the vendor's dated MTU page) where a NACL or firewall drops the ICMP that path MTU discovery needs; live: `ping -M do -s <mtu−28>` / `tracepath` across the hop, on a confirmed context
- **private resolution** (N-PRIVDNS, §3): an interface endpoint with `private_dns_enabled` unset (the provider default is `false`, read from the provider docs) or a private zone not linked to the VPC, so the app resolves the public name and leaves the private path; a private zone linked in another root clears it. Live: `getent hosts <name>` from a pod or instance, never a laptop resolver
- SG `cidr_blocks` and NetworkPolicy `ipBlock` are references, never allocations, and are not compared (precedents § 67)
- `0.0.0.0/0` / `::/0` ingress, egress-all (N2), ipBlock width and IMDS-v6 exceptions are security's; §5's live-exposure rows carry `owner: security`
- pass: `python3 -I network-exposure-audit/scripts/cidr-overlap.py` reports 0 overlaps and 0 `N-PEER-ROUTE` rows across every CIDR source, every NACL pair admits the return path, every prod private route table uses its own zone's NAT (or a regional NAT), the reduced-MTU hop passes ICMP, private names resolve to the endpoint from inside the network, and Reachability Analyzer (live, confirmed profile) finds the path on v4 and v6

### Sources (infrastructure)

The infrastructure research catalog and its notes A–C (2026-10-10) and the batch-4 infrastructure
eval (2026-10-10), which cite: the Terraform 1.16 / OpenTofu 1.13 docs and changelogs (`test`,
`mock_provider`, `removed`, `lifecycle destroy`), the AWS provider docs (main branch, defaults
table), the Kubernetes docs (releases, deprecation guide, disruptions, probes, topology spread —
the built-in default constraints re-checked on 2026-10-10), the Helm 4 and kustomize 5.8 release
notes, the nginx, ingress-nginx, Caddy, Traefik, HAProxy and Envoy documentation, cert-manager 1.18
release notes, CA/B Forum SC-081, and local measured runs on 2026-10-10: `terraform test` /
`tofu test` with mock providers, offline plan JSON with checkov / trivy / kics / conftest, kind
v0.33.0 (node v1.37.0, isolated kubeconfig) for drain, eviction, HPA, ConfigMap, NetworkPolicy and
preStop oracles, nginx and Caddy harness runs, and a read-only real-repo run (kustomize 5.8.3,
kubeconform 0.8.0, pluto 5.24.4, kube-score 1.20.0, kube-linter 0.8.3, caddy 2.11.7). Rows marked
[K?] are settled on the `infra-ops` fixture before a skill asserts them. Paraphrased; no text
reproduced.

## Distributed

A distributed-systems claim says that a redelivery, a crash between two writes, a paused lock
holder, a retry, a rebalance, a deploy or a skewed clock turns into a lost, duplicated, reordered
or stale effect. Reading the handler does not settle any of these: what the broker does with a
nack, whether a library acks before the handler returns, whether a lock outlives its holder and
how many layers retry one call are runtime and library facts — the rows of
[`broker-semantics.md`](broker-semantics.md). The oracle drives the failure (a duplicate delivery,
a kill between two writes, a paused holder, a stepped clock, a poison message, a rebalance, a
replay of recorded histories, a schema diff) against the real broker or store in a container and
counts the effects where they land. Every oracle names a **tier**: C (a container oracle:
Testcontainers or `docker run` with the real broker or store, Toxiproxy for faults), T (a tool's
exit: `workflowcheck`, a DURABLE analyzer, `buf breaking`, `asyncapi diff`, `json-schema-diff`,
`no-floating-promises`), S (a static fact with both ends cited) or L (a live, read-only broker
read under `--live`). Settled questions are in
[`precedents/distributed.md`](precedents/distributed.md). Users: `messaging-scan`,
`dual-write-scan`, `retry-deadline-scan`, `coordination-scan`, `workflow-scan` and
`event-contract-scan` (distributed-systems pack), run by `/ds-audit`, judged by
`@resilience-reviewer` (with `@system-architect` on leader rows), `@workflow-orchestrator` and
`@event-sourcing-architect`, and `/ds-fix`; `/add-event-handler` and `/add-saga` run the same
oracles in their Phase 6 gate. Money, stock and credit effects are security's
(`logic-race-scan` §4–§5) and are proven with [`exploit-payloads.md`](exploit-payloads.md) and
[`finding-verification.md`](finding-verification.md); publish inside a transaction is § Data (V8);
the fencing half of a lease is § Performance (V38); once-per-fleet schedulers and migrations are
V40; Lambda event sources are § Infrastructure (V255–V259).

**Scope of use.** Scratch containers and `${TMPDIR}` only — never the user's brokers, caches,
databases, clusters or cloud accounts. A broker CLI runs only against a target named in `--live`,
read-only. Six rules hold for every variant below:

- **Read the default row first** (gate 3). A variant that depends on a default — a nack that does or does not count, a void handler that does or does not delete, a library that does or does not retry POST — names its `broker-semantics.md` row at the installed version, and the container runs **that** version of the client and the broker. A managed broker's server setting that is not in the repo is `UNREAD`, and the variant runs with the self-hosted default only as a labelled assumption.
- **The real broker, never a mock.** `Queue::fake()`, eager Celery, an in-memory MassTransit harness or a stubbed client prove nothing about delivery semantics (`precedents/distributed.md` § 33); `@EmbeddedKafka` is acceptable for ordering and poison only.
- **Small real durations for broker-side timers.** Fake timers are valid for client-side backoff, jitter and clock skew, and **never** for Redis TTL, BullMQ lock expiry, SQS visibility or a JetStream `AckWait`: set those low in the test config (a 1–2 s `lockDuration`, a 2 s visibility) and wait for real.
- **Count effects where they land** — rows in the effect table, calls on the provider mock, messages on the output topic — never log lines or handler invocations.
- **Fail first, pass after, keep the control.** The oracle fails on its assertion (not on setup) before the fix and passes after, and the benign control — one clean delivery — still yields exactly one effect. A fix that turns a duplicate into a loss (`attempts: 1`, `maxStalledCount: 0`, at-most-once ack, `removeOnFail: true`) fails the variant list unless a written precedent-6 decision covers it.
- **No cluster, no cloud.** The first line of every Bash call that may run `kubectl`, `helm` or a cluster tool is `export KUBECONFIG="$SCAN/empty-kubeconfig"; : > "$KUBECONFIG"`; a leader-election variant runs on a throwaway kind cluster with its own kubeconfig in `$SCAN`, or on client-go's fake clientset. No default cloud profile: SQS and SNS run on LocalStack, Pub/Sub on its emulator (DLQ and exactly-once support there [K?]).

### Oracle taxonomy (distributed)

| Oracle | Asserts | Tier | V | Detector § |
|---|---|---|---|---|
| **Crash mid-handler** | Killed after the effect, before the ack → redelivered, 1 effect; killed before the effect → done once after restart; the auto-ack variant loses it before the fix | C | V291 | `messaging-scan` §1 |
| **Duplicate replay** | The same logical message twice, sequential and behind a barrier → 1 effect; the reserve key is a business or publisher-set id | C | V292 | `messaging-scan` §2; `dual-write-scan` §4 |
| **Poison among good** | 1 bad + 100 good → 100 effects; the bad one dead-lettered after N bounded attempts, with an alert-able count | C | V293 | `messaging-scan` §3 |
| **Ordered replay** | v1…v100 for one key with a transient failure on v3 → final state v100, handled in order | C | V294 | `messaging-scan` §4 |
| **Rebalance during processing** | A slow handler past the poll interval plus a joining member → 1 effect per message, no committed offset past an unprocessed one | C | V295 | `messaging-scan` §5 |
| **Run past the lock** | A job running 1.5 × the lock, visibility or ack-wait → exactly 1 effect (§ Performance V44 probe 1) | C | V296 | `messaging-scan` §6 |
| **Broker down / stalled producer** | Broker stopped or stalled → the use case fails visibly or persists to an outbox, never "success" with the message gone | C | V297 | `messaging-scan` §7 |
| **Expiry, trim, eviction** | Memory pressure, a `MAXLEN` trim, a TTL → every unprocessed message processed or dead-lettered | C | V298 | `messaging-scan` §8 |
| **Flood** | 100 000 published → RSS flat, unacked ≤ prefetch | C | V299 | `messaging-scan` §9 |
| **Kill between commit and publish** | A crash after commit, before publish → published exactly once after restart; the reverse probe → no event for a rolled-back row | C | V300 | `dual-write-scan` §1–§2 |
| **Relay kill and gap** | The relay killed between send and mark → 1 effect per event, per-aggregate order kept; tx A holds sequence 10 while B commits 11 → event 10 still delivered | C | V301 | `dual-write-scan` §3, §6 |
| **CDC replay** | A connector restart, a re-snapshot and a tombstone → consumer state unchanged, tombstones handled, order per aggregate kept | C | V302 | `dual-write-scan` §5 |
| **Crash between reserve and effect** | A crash after the reserve, before the effect (and the reverse) → redelivery completes the effect exactly once | C | V303 | `dual-write-scan` §4 |
| **Fault-injected retry** | Permanent error → 1 attempt; persistent transient error → attempts ≤ the stated cap, then surfaced or dead-lettered | C (unit + container) | V304 | `retry-deadline-scan` §1–§2 |
| **Backoff under a fake clock** | Gaps grow, are capped, and two clients' schedules differ | C (unit, fake clock) | V305 | `retry-deadline-scan` §3 |
| **Downstream call count** | One failing user action → downstream calls ≤ the stated budget (one retrying layer) | C (unit + mock server) | V306 | `retry-deadline-scan` §4 |
| **Succeed-then-lose-the-response** | The provider applies the call, the response is lost, the retry carries the same idempotency key → 1 provider effect | C (unit + mock server) | V307 | `retry-deadline-scan` §5 |
| **Partial work on attempt 1** | Attempt 1 fails after partial work → attempt 2 leaves exactly one result | C | V308 | `retry-deadline-scan` §6 |
| **Deadline budget** | The outbound call carries ≤ the remaining budget; the callee stops within a margin of cancel; an expired command is dropped or dead-lettered; inner × attempts < outer | C + S | V309 | `retry-deadline-scan` §7–§8 |
| **TTL expiry, then release** | The old holder's release after expiry leaves the new holder's lock in place | C | V310 | `coordination-scan` §1 |
| **Holder killed** | The holder killed → a second acquirer succeeds within the TTL, never "never" | C | V311 | `coordination-scan` §2 |
| **Pre-held lock** | The lock held by another → the job performs 0 effects | C | V312 | `coordination-scan` §3 |
| **Paused holder** | The holder paused past the TTL → it stops before its next write, or the resource rejects the stale write (the fencing half is § Performance V38) | C | V313 | `coordination-scan` §4 |
| **Advisory lock through a pool** | Pool max 2: after "unlock", `pg_locks` holds no orphan; a transaction pooler hands no session lock to another client | C | V314 | `coordination-scan` §5 |
| **Leader renewals blocked** | A's renewals blocked → A stops acting before B starts | C (kind or fake clientset) | V315 | `coordination-scan` §6 |
| **Wall clock stepped** | The wall clock stepped back 10 s → the timeout or lease fires on monotonic time | C (unit, fake clock) | V316 | `coordination-scan` §7 |
| **Two clocks** | App clock = DB clock + 5 s → no early expiry, no overlapping holders, no skipped event | C | V317 | `coordination-scan` §8 |
| **Skewed writers** | Two writers with skewed clocks → the later write wins by version, not by timestamp | C | V318 | `coordination-scan` §9 |
| **DST-day fire count** | A schedule across a DST transition → the documented number of fires (not 0, not 2) | C (unit, fake clock) | V319 | `coordination-scan` §11 |
| **Replay recorded histories** | The previous release's histories replay against the new code with no non-determinism error; `workflowcheck` / DURABLE analyzers exit 0 | T + C | V320 | `workflow-scan` §1–§2 |
| **Time-skipping activity env** | Activity configuration under the time-skipping test environment: bounded retries on a non-idempotent activity, heartbeats arrive, no history-limit loop | C | V321 | `workflow-scan` §3 |
| **Saga failure matrix** | Step k failing (clean and ambiguous) → C(k-1)…C1 exactly once each, in reverse; replaying the failure path changes nothing | C | V322 | `workflow-scan` §4–§6 |
| **Compatibility tool exit** | base → head: the format's tool exits non-zero before the fix, 0 after | T | V323 | `event-contract-scan` §1 |
| **Tolerant reader and old events** | Malformed, extra-field and unknown-type fixtures are acked or parked by policy, never a crash loop; the replay-old-events corpus deserialises with 0 failures | C (unit) | V324 | `event-contract-scan` §2–§5 |
| **Concurrent decide-append** | Two deciders behind a barrier → one append, one `WrongExpectedVersion` (or a unique violation) | C | V325 | `event-contract-scan` §6–§7 |
| **Projection redelivery** | Redelivery, or a crash between the projection write and the checkpoint → the read model unchanged; a replay sends nothing | C | V326 | `event-contract-scan` §8–§9 |
| **Write, then read through the flow** | Write → redirect or trigger → read returns the new value, or waits on a position | C | V327 | `event-contract-scan` §10 |

Static-fact classes with no V of their own: broker durability configuration (`messaging-scan` §10:
the config value and the code that depends on it), version traps (§11: the version read from the
lockfile against its `broker-semantics.md` row), time used as an identifier (`coordination-scan`
§10), and the arithmetic halves of §5, §6 and `retry-deadline-scan` §8 (both terms cited).
Scheduler-explorer shapes and migration runners without a lock are variants of § Performance V40,
not slots here.

### Container harness

One harness shape covers most slots: start the broker and the store, put Toxiproxy between the
service and each when a fault needs injecting, drive the failure, count the effects in the store.
The container images and client versions are the ones the repo pins (gate 3).

```ts
// vitest + testcontainers (Node); the same shape exists for Java, Go, .NET and Python
import { GenericContainer, Network } from "testcontainers";
const net = await new Network().start();
const redis = await new GenericContainer("redis:7-alpine").withNetwork(net).withExposedPorts(6379).start();
const pg = await new GenericContainer("postgres:16").withNetwork(net)
  .withEnvironment({ POSTGRES_PASSWORD: "x" }).withExposedPorts(5432).start();
// V292: deliver the same logical message twice, then twice behind a barrier
await handler(msg); await handler(msg);
await Promise.all([handler(msg2), handler(msg2)]);
expect(await countEffects(pg, msg.businessId)).toBe(1);
expect(await countEffects(pg, msg2.businessId)).toBe(1);
```

- **BullMQ** (V291, V296): a 1–2 s `lockDuration` in the test worker, a processor that blocks the event loop (`Atomics.wait` on a `SharedArrayBuffer`, or a busy loop) past it; count rows. Run the processor class the module registers (the base class and its subclass), not a copy.
- **Kafka** (V294, V295): Redpanda or `apache/kafka` in a container; two consumers in one group; a handler that sleeps past `max.poll.interval.ms` set low; read committed offsets with the admin client.
- **RabbitMQ** (V293): `rabbitmq:<the repo's 4.x tag>` with the repo's `definitions.json` loaded; publish 1 poison + 100 good; count the dead-letter queue and the redelivery counter (`x-delivery-count`, `x-acquired-count` on ≥ 4.3).
- **SQS** (V292, V296): LocalStack with the queue and redrive policy the IaC declares; a visibility of 2 s; the sqs-consumer version the lockfile pins.
- **Kill points** (V291, V300, V303, V308): a spy that throws, or `process.kill(process.pid, "SIGKILL")` in a child process, placed exactly between the two writes; the restart runs the real relay or consumer.
- **Clocks** (V316–V319): `@sinonjs/fake-timers` / vitest fake timers, `time-machine`, an injected `Clock` or `TimeProvider`, Go `testing/synctest`; the database clock is moved with a session `SET` of a shifted timestamp source or by writing the app clock ahead, never by changing the host clock.
- **Temporal** (V320, V321): `Worker.runReplayHistories`, `WorkflowReplayer`, `Replayer`; `TestWorkflowEnvironment.createTimeSkipping()` (TS) or the SDK's equivalent; histories fetched from a dev server (`temporal server start-dev`) or committed under `test/histories/`.

### Class variants (distributed)

#### V291. Ack, commit or delete before the effect — crash mid-handler (`messaging-scan` §1)
- BullMQ un-awaited processor body or `handle()` in a subclass of a base processor; Bull `done()` first; kafkajs un-awaited `eachMessage`, `resolveOffset` before the effect; confluent-js periodic commit with an early return (KJ7); Spring `acknowledge()` first under `MANUAL_IMMEDIATE`, a raw poll handing records to an executor
- RabbitMQ `noAck: true`, ack first; SQS delete first, Spring Cloud AWS `ALWAYS`, sqs-consumer `alwaysAcknowledge`; NATS `AckNone`, `AckAll` with concurrent handlers, core NATS; Redis Streams `NOACK`, pub/sub
- Celery early ack (CY1), `acks_late` without `reject_on_worker_lost` (a signal-killed child is still acked); OSS Sidekiq `kill -9` (RB1); librdkafka `enable.auto.offset.store=true` (LD1); Azure Service Bus `ReceiveAndDelete`; kafka-go `ReadMessage` with a `GroupID`; franz-go `GreedyAutoCommit`
- pass: `kill -9` after the effect and before the ack → redelivered, effect count 1; kill before the effect → completed once after restart

#### V292. At-least-once with no idempotent consumer — duplicate replay (`messaging-scan` §2; `dual-write-scan` §4 corroborates)
- the same message twice sequentially; twice concurrently behind a barrier (read-then-insert dedupe fails here); redelivery after a visibility or lock expiry; a producer retry after a timeout (a new broker id, the same business id); an SNS duplicate arriving as a new SQS message (AW6)
- BullMQ re-add after `removeOnComplete` (BQ4); a reserve keyed on `job.id` (auto), `deliveryTag`, `ReceiptHandle`, an SNS-fed SQS `MessageId`, a Sidekiq `jid` (ID1–ID9); sqs-consumer ≥ 14 handler returning void (AW4); a random `MessageDeduplicationId`
- Kafka EOS consumer with an external DB or HTTP effect (KJ8); Celery `autoretry_for=(Exception,)` on an effect
- pass: 1 effect row or provider call in every variant; the reserve key is a business or publisher-set id

#### V293. Poison: requeue loop, no DLQ, swallow-and-ack, whole-batch retry — poison among good (`messaging-scan` §3)
- kafkajs `restartOnFailure` loop (KJ4); Spring `new DefaultErrorHandler()` — the record is skipped, which fails the variant (KA7); a batch listener without `BatchListenerFailedException` (KA8)
- RabbitMQ `nack(msg)` (requeue defaults true, RQ4) on a classic queue and on a quorum queue ≥ 4.3 (RQ2, RQ3); a quorum queue at its limit with no DLX (a silent drop, RQ1); Spring AMQP default requeue (RQ6)
- SQS whole-batch retry, a batch `Failed` list ignored, no redrive, `maxReceiveCount` 1; NATS `Nak()` with `MaxDeliver` -1 (NA1); Redis Streams with no reclaim cap; Watermill nack resend (GL4); MassTransit `DiscardFaultedMessages`; Sidekiq `retry: false` / `dead: false`
- BullMQ swallowed `catch` in the processor; `removeOnFail: true` (BQ3)
- pass: the 100 good drain; the poison lands in a dead-letter queue or failed set **with an alert-able count** after N bounded attempts; nothing is redelivered without bound

#### V294. Ordering assumption broken — ordered replay (`messaging-scan` §4)
- kafkajs `Promise.all(batch.messages.map(…))`; a produce with no key; mixed partitioners on one topic (librdkafka CRC32 vs murmur2, LD4; kafkajs `LegacyPartitioner`, KJ6)
- `@RetryableTopic` on an ordered stream (KA11); retry by re-publishing to the tail; RabbitMQ prefetch > 1 with several consumers and no single active consumer
- an SQS FIFO constant or random `MessageGroupId`; BullMQ `concurrency > 1` on a queue whose handler overwrites per-entity state; Java producer idempotence off with `max.in.flight > 5` (KA4); a relay without `ORDER BY` or with parallel publish (V301 owns the relay)
- pass: final state v100 and per-key handler order v1…v100

#### V295. Consumer-group rebalance — rebalance during processing (`messaging-scan` §5)
- kafkajs `eachBatch` without `heartbeat()` / `isStale()` (KJ3); `max.poll.records × p99 > max.poll.interval.ms` (both terms cited, KA2); manual commits with no `ConsumerRebalanceListener`; a confluent-js handler longer than `rebalanceTimeout` (KJ7)
- pass: per-message effect 1; no committed offset past an unprocessed message; no rebalance storm at the stated load

#### V296. Visibility, lock or ack-wait shorter than processing, non-serverless — run past the lock (`messaging-scan` §6; = § Performance V44 probe 1; Lambda → V255)
- a BullMQ CPU-bound inline processor at the default `lockDuration` (BQ2), `skipLockRenewal`, `skipStalledCheck`, `maxStalledCount ≥ 2`; a stalled job re-run once at `attempts: 1` (BQ2, [K?] on the installed 6.x)
- sqs-consumer `handleMessageTimeout` without `heartbeatInterval` (AW4); NATS with no `InProgress()`; Celery ETA or countdown > `visibility_timeout` (CY4); Laravel `--timeout ≥ retry_after` (LV2); RabbitMQ `consumer_timeout` (RQ8)
- pass: a job running 1.5 × the timeout produces exactly 1 effect. A fix that only raises the number fails unless the effect is idempotent or a heartbeat holds the lock

#### V297. Producer side: fire-and-forget, no confirms, weak acks — broker down or stalled (`messaging-scan` §7)
- an un-awaited `send` / `add` / `publish` (BullMQ, kafkajs, amqplib); a non-confirm channel, no `mandatory`, `persistent: false` (RQ4); `acks` 0 or 1; idempotence disabled explicitly or silently (`retries=0`, `max.in.flight > 5`, `acks` ≠ all: KA4; librdkafka LD2); a batch `Failed` list ignored (AW7)
- **stall-then-recover**: an enqueue bounded by a race timer that answers "refused" while the losing `add` sits in the client's offline queue and lands when the broker returns; a client that retries the refusal without a dedupe key enqueues twice
- pass: with the broker stopped the use case fails visibly or persists to an outbox — never "success" with the message gone; after a stall, one logical enqueue produces one job

#### V298. Retention, TTL, eviction drops unprocessed work — expiry, trim, eviction (`messaging-scan` §8)
- `maxmemory-policy` ≠ `noeviction` on the job Redis under memory pressure (BQ6; managed: RD5); Streams `MAXLEN` / `MINID` without `ACKED` on Redis ≥ 8.2 (RD1); RabbitMQ `x-message-ttl` / `x-max-length` with no DLX; an SQS DLQ whose retention ≤ the source's (AW3); JetStream `MaxAge` with `DiscardOld`; quorum dead-lettering at-most-once (RQ7)
- pass: every unprocessed message is processed or dead-lettered — none silently gone

#### V299. Unbounded consumer buffering — flood (`messaging-scan` §9; sizing → § Performance V43)
- no `prefetch()` or `prefetch(0)` (RQ4); `XREADGROUP` without `COUNT` (RD3); `Promise.all` over a receive batch; a goroutine per message with no semaphore
- pass: 100 000 published, RSS flat, unacked ≤ prefetch

#### V300. Dual write — kill between commit and publish (`dual-write-scan` §1–§2; inside a transaction → § Data V8)
- commit → publish (a crash between; the broker down); publish → commit (a rollback after publish)
- after-commit helpers — Celery `delay_on_commit`, Rails after-commit enqueue, Laravel `afterCommit`, Sidekiq `after_commit` — keep the loss window (OX5); `@nestjs/cqrs` `EventBus.publish` after `save` (OX6); MassTransit publish after the last `SaveChangesAsync` (NT2, [K?]); Spring `ChainedKafkaTransactionManager` (KA10); Solid Queue on a separate database (RB4)
- pass: the event is delivered exactly once after restart; no event for a rolled-back row

#### V301. Outbox relay and gap-blind cursor — relay kill and gap (`dual-write-scan` §3, §6; claim without `SKIP LOCKED` → § Data)
- the relay killed between send and mark (a duplicate the consumer's reserve must absorb); mark before the publish is confirmed; parallel publish (`Promise.all(rows.map(publish))`); a relay read with no `ORDER BY`; an outbox with no relay or no pruning; a relay leader lease whose `extend()` result is dropped
- `WHERE id > $last` over a sequence written by concurrent transactions; a time-ordered id (UUIDv7, ULID, Snowflake) minted on several hosts compared to a floor with no lag and no rescan
- pass: 1 effect per event; per-aggregate order kept; with tx A holding sequence 10 uncommitted while B commits 11, event 10 is delivered after A commits

#### V302. CDC consumer gaps — snapshot replay and tombstone (`dual-write-scan` §5)
- a tombstone (`value == null`) reaching a consumer with no null branch (OX3); the initial snapshot re-emitting rows as reads (OX2); a connector restart replay; an UPDATE on an outbox row with `table.op.invalid.behavior=warn` (OX1); the key overridden away from `aggregateid`
- pass: consumer state unchanged by replays; tombstones handled; per-aggregate order kept

#### V303. Inbox absent or not atomic with the effect — crash between reserve and effect (`dual-write-scan` §4)
- the reserve written after the effect; a Redis `SET NX` reserve with the effect in SQL; `SELECT exists` then `INSERT`; a claims ledger in its own transaction beside the effect with no reserve on the effect table (`precedents/distributed.md` § 2); a reserve "released" after a partially applied effect; inbox retention shorter than the redelivery window (broker retention + DLQ retention + the replay window)
- pass: a crash after the reserve and before the effect, then redelivery → the effect exactly once; a crash after the effect and before the ack → no second effect; the concurrent variant of V292 also passes

#### V304. Retry IF and cap — fault-injected retry (`retry-deadline-scan` §1–§2; money → security)
- a permanent error (validation, 4xx, deserialisation) retried: tenacity `@retry` without `retry=` (RY1), Polly default `ShouldHandle` (RY6), Resilience4j default predicate (RY8), Spring 7 `@Retryable` without `includes` (RY9), BullMQ with no `UnrecoverableError` and no classification before the throw, Temporal activities with no non-retryable types (WK6)
- no cap: bare tenacity; p-retry `forever` / `retries: Infinity`; Celery `max_retries=None` (CY3); redlock `retryCount: -1` (LO2); the Temporal default activity policy; `while (true) { try … catch { continue } }` with retry vocabulary; a negative configured cap read as infinite
- pass: permanent → 1 attempt; persistent transient → attempts ≤ the stated cap, then surfaced or dead-lettered

#### V305. Backoff and jitter — fake clock (`retry-deadline-scan` §3; `THR-RES-RETRY`)
- zero delay: axios-retry default (RY3), Spring Kafka `DefaultErrorHandler()` (KA7), MassTransit `r.Immediate(n)`; constant: Polly (RY6), Resilience4j (RY8); unjittered exponential: p-retry (RY2), go-retryablehttp (RY5); BullMQ `attempts` with no `backoff` (BQ2); Polly `UseJitter = false`
- pass: under a fake clock the gaps grow, are capped, and two clients' schedules differ

#### V306. Retries multiplied across layers — downstream call count (`retry-deadline-scan` §4)
- an AWS SDK call (3 attempts, RY10) inside a p-retry / tenacity / Polly loop; `ConfigureHttpClientDefaults(…AddStandardResilienceHandler())` plus a per-client handler (RY7); `@Retryable` around a `@KafkaListener` with its own error handler; job `attempts` × a client's `retry.attempts` × broker redelivery × activity retry
- pass: one failing user action produces ≤ the stated budget of downstream calls, counted on the mock; exactly one layer retries

#### V307. Retry of a non-idempotent call — succeed-then-lose-the-response (`retry-deadline-scan` §5; proxy retries → V284; money → security)
- POST through go-retryablehttp (RY5); the .NET standard handler without `DisableForUnsafeHttpMethods()` (RY7); `axiosRetry(client)` on a network error, or a `retryCondition` admitting POST (RY3); an idempotency key minted inside the retry callback; job or activity retry around a provider call with no key from the business id; Celery autoretry on a charge
- pass: the response lost after success → the retry carries the same idempotency key, and the provider records 1 effect

#### V308. State not reset, or a retry repeats an earlier step — partial work on attempt 1 (`retry-deadline-scan` §6)
- a retry wrapper outside the unit of work it retries; a reused request stream; an ORM session reused after a failed flush; a double-incremented attempt counter; a handler with two external effects and no per-step checkpoint; a zombie original and its retry writing one key (a deadline that does not abort, `precedents/distributed.md` § 36)
- pass: attempt 2 succeeds and leaves exactly one result; the first effect is not repeated

#### V309. Deadline propagation and timeout order — deadline budget (`retry-deadline-scan` §7–§8; the platform chain → V282)
- gRPC Node or Python outbound without the inbound deadline (RY11); a user-facing command enqueued with no `expiresAt`, consumed hours later; a worker that ignores a deadline header; a per-attempt deadline that rejects without aborting
- inner timeout × attempts + backoff ≥ the outer budget across queue → worker → downstream; Temporal Start-To-Close ≥ the workflow's business deadline
- pass: the outbound budget ≤ the remaining budget; the callee stops within a margin of cancel; expired commands are dropped or dead-lettered; the arithmetic, both terms cited, leaves margin

#### V310. Release without an owner check — TTL expiry, then release (`coordination-scan` §1)
- `DEL` / `unlink` of a lock key with no check; `GET` → compare in the app → `DEL`, with a pause injected between the read and the delete (`precedents/distributed.md` § 21); a hand-written `DEL` beside a library-managed release
- pass: A's lock expires, B acquires, A releases → B's key survives

#### V311. No TTL, or a TTL set non-atomically — holder killed (`coordination-scan` §2)
- `SET k v NX` with no `PX` / `EX`; `setnx` then `expire` in two round trips; Go `SetNX(…, 0)`; Spring `setIfAbsent(k, v)` (2 arguments); redis-py `r.lock(name)` with no `timeout=` (LO3)
- pass: the holder killed → a second acquirer succeeds within the TTL

#### V312. Acquire result ignored — pre-held lock (`coordination-scan` §3)
- Redisson `tryLock(…)` as a statement (LO4); `acquire(blocking=False)` unchecked; a redsync `Lock()` error dropped (LO6); `TryAcquire*` null unchecked (LO7); `pg_try_advisory_lock` result discarded
- pass: with the lock pre-held by another holder, the job performs 0 effects

#### V313. Lease shorter than the work; renewal missing or unchecked — paused holder (`coordination-scan` §4; fencing → V38)
- redlock `using(…, async (signal) => …)` never reading `signal.aborted` (LO2); `await lock.extend();` with the result dropped and no later check; Redisson `lock(leaseTime)` (watchdog off, LO4); ShedLock `lockAtMostFor` below the job's bound (LO5); redsync `ErrLockAlreadyExpired` dropped (LO6); a fixed-TTL lock around an unbounded loop with no renewal
- pass: the holder paused past the TTL (`SIGSTOP`, a latch, a busy loop — small real TTLs) stops before its next write, or the resource rejects the stale write; for a correctness lock, the fencing token is checked at the write (V38)

#### V314. Session advisory lock through a pool or a transaction pooler — pool max 2 (`coordination-scan` §5; pooler config → database `connection-config-scan` §3)
- a session `pg_advisory_lock` through `pool.query`; the same behind `?pgbouncer=true`, port 6432 or `pool_mode = transaction`; a migration wrapper doing the same (LO10)
- pass: with a pool of 2, after "unlock" `pg_locks` shows no orphaned advisory lock, and a second client cannot inherit it

#### V315. Leader keeps acting after losing leadership — renewals blocked (`coordination-scan` §6; once-per-fleet → V40)
- client-go `OnStartedLeading` running work under `context.Background()`; `OnStoppedLeading` that only logs; `LeaseDuration > RenewDeadline > 1.2 × RetryPeriod` violated (LO8); a Redis leader key whose holder never re-checks before a side effect
- pass: with A's renewals blocked, A stops acting (or exits) before B starts; on a scratch kind cluster with its own kubeconfig, or client-go's fake clientset

#### V316. Wall-clock duration guarding a timeout or lease — wall clock stepped (`coordination-scan` §7)
- `Date.now() - start > limit`; `time.time() - start`; `System.currentTimeMillis() - start`; `DateTime.UtcNow - started`; a Go start time stripped of its monotonic reading (`Round(0)`, `Truncate`, `.UTC()`, a marshalled time — TM1)
- pass: the wall clock stepped back 10 s → the timeout or lease fires on monotonic time (TM2)

#### V317. Expiry written on one clock, compared on another — two clocks (`coordination-scan` §8)
- the app writes `expiresAt = now + ttl` and SQL compares `< now()`; a time-ordered id minted on several hosts compared to a floor computed on one host
- pass: app clock = DB clock + 5 s → no early takeover, no overlapping holders, no event skipped past the floor

#### V318. Last-write-wins or ordering on wall-clock timestamps — skewed writers (`coordination-scan` §9; client LWW → mobile)
- `incoming.updatedAt > row.updatedAt` from two services; client-supplied `USING TIMESTAMP`; `ORDER BY created_at` across event streams in a projector
- pass: with skewed writers the later write by version wins, and the projection order follows the stream position

#### V319. DST and local-time schedules — DST-day fire count (`coordination-scan` §11; CronJob `concurrencyPolicy` → V40)
- a process `TZ` set to a DST zone (`ENV TZ`, a manifest `env: TZ`, a JVM `-Duser.timezone`) with `@Cron` / `cron.schedule` at a time inside the transition hour; an explicit DST `timeZone`; Laravel `->timezone(`; a CronJob without `timeZone` on a cluster whose controller runs in a DST zone (SD6); Laravel timezone schedules (SD3)
- pass: on the DST transition day the job fires the documented number of times (once), under a fake clock in the job's zone

#### V320. Workflow non-determinism and unversioned change — replay recorded histories (`workflow-scan` §1–§2)
- the per-SDK token lists: TS Node or I/O imports in the bundle, `process.env`, `crypto.randomUUID`, activity value-imports, branching on `unsafe.isReplaying` — never `Date.now()` / `Math.random()` in TS (WK1, `precedents/distributed.md` § 25); Go via `workflowcheck` (WK2); Java (WK3); Python with the sandbox off (WK4); .NET (WK5); Durable JS / Python orchestrators that are not generators, DURABLE0001–0011 (WK8); Inngest or Restate time, random or reads outside `step.run` / `ctx.run` (WK10)
- a workflow file changed with no `patched()` / `deprecatePatch` / `GetVersion` / `getVersion` / `workflow.patched` and no worker-versioning change; workflows with no replay test in CI; a DURABLE0011 loop without ContinueAsNew
- pass: `workflowcheck -show-pos ./...` and the DURABLE analyzers exit 0; replaying the previous release's committed histories raises no non-determinism error

#### V321. Activity configuration — time-skipping environment (`workflow-scan` §3)
- the default unlimited retry on a non-idempotent activity, no non-retryable error types (WK6); a long activity with no heartbeat, or `heartbeatTimeout` with no `heartbeat()` call ([K?] on the dev server); an unbounded loop without continue-as-new against the history limit (WK7); payloads over 2 MB; signal-then-poll where an Update belongs; Step Functions `TimeoutSeconds` absent (WK9; infrastructure when in IaC)
- pass: under the time-skipping environment the non-idempotent activity runs at most its stated attempts, heartbeats arrive within the timeout, and the loop continues-as-new before the limit

#### V322. Saga compensation — step-k failure matrix, clean and ambiguous (`workflow-scan` §4–§6; isolation → § Data V5)
- a side-effecting step with no compensation (not the pivot, `precedents/distributed.md` § 26); Eventuate `.invokeParticipant(..)` without `.withCompensation`; compensations run in forward order (`push` + `for…of`); a swallowed compensation error; a Go `defer ExecuteActivity(ctx, …)` without `NewDisconnectedContext` (WK11); a compensation registered after a limited-retry activity returns (the ambiguous failure: a timeout after the effect)
- a non-idempotent compensation with no `(sagaId, step)` reserve; an irreversible step before a fallible one; no persisted saga state for a choreographed saga; NestJS `@Saga()` holding compensation in memory (OX6)
- pass: for each step k, clean and ambiguous, C(k-1)…C1 run exactly once each in reverse; replaying the failure path changes nothing; the final status is FAILED or COMPENSATED with the original error surfaced

#### V323. Breaking schema change — compatibility tool exit (`event-contract-scan` §1; HTTP API drift → backend)
- a field removed, renamed or retyped; a required field added; a proto tag reused; an enum symbol added for closed readers (SZ2); `BACKWARD` (latest only) where `_TRANSITIVE` is needed (SZ3); a TS-only event type changed
- tools: `buf breaking --against '.git#branch=<base>'` at WIRE_JSON minimum (SZ1), with `,subdir=<module>` when the module is not the repo root — without it an additive change exits 100 (SZ8); `asyncapi diff base head -t breaking` with metrics off, reading the `unclassified` payload changes too (SZ4, SZ10); `json-schema-diff` both directions, enum/const/pattern read by hand (SZ5, SZ9); `oasdiff breaking --fail-on WARN` on webhook payloads (SZ7, SZ11); the `avsc` resolver both ways or Avro `SchemaCompatibility` offline (SZ12); TS: compile the old consumer against the new type; `--contract-base=<dir>` where the repo has no base branch
- pass: the tool exits non-zero **at its breaking code** on base → head before the fix and 0 after, having parsed both sides (an exit that is not the tool's breaking code is NOT-RUN, never a pass: SZ8–SZ11); a fix that passes `--no-error` or sets the registry to `NONE` fails the variant

#### V324. Unvalidated payload, intolerant reader, semantic change, name drift — tolerant-reader fixtures and the replay-old-events corpus (`event-contract-scan` §2–§5)
- `JSON.parse(msg.value…)` / `json.loads(body)` used as a typed event with no schema parse; `assertNever(evt.type)` or a throw on an unknown type in a consumer; zod `.strict()`, pydantic `extra="forbid"`, STJ `UnmappedMemberHandling.Disallow`, plain `new ObjectMapper()` on the consumer side (SZ6)
- a unit change with the same type (minor ↔ major units, s ↔ ms); a topic literal spelled differently across files; an event produced but never consumed, or subscribed but never produced
- pass: the malformed fixture is parked, not a crash loop; the extra-field and unknown-type fixtures are acked or parked by policy without a throw; the replay-old-events corpus deserialises with 0 failures and the same meaning

#### V325. Append without expected version; no stream uniqueness — concurrent decide-append (`event-contract-scan` §6–§7)
- KurrentDB `appendToStream(s, events)` after a read-decide with the default `streamState: ANY` (EV1), `StreamState.Any` (EV2); Marten `Append` after `AggregateStreamAsync` instead of `FetchForWriting` (EV3); a custom event table without UNIQUE(stream, version); a Prisma `model *Event` without `@@unique`
- pass: two deciders released together by a barrier → one append succeeds and one gets `WrongExpectedVersion` (or a unique violation at the SQL layer)

#### V326. Projection not idempotent; side effects on replay — projection redelivery (`event-contract-scan` §8–§9; per-replica daemon → V40)
- `SET n = n + 1` with the checkpoint saved separately; the checkpoint saved before the projection write; side effects in `apply` / `when`; a snapshot with no version column (events ordered by `ORDER BY created_at` across streams are `coordination-scan` §9's single owner, V318 — not a V326 variant)
- pass: redelivery, or a crash between the projection write and the checkpoint, leaves the read model unchanged; a full replay sends nothing

#### V327. Eventual consistency assumed in a flow — write, then read through the flow (`event-contract-scan` §10; replica read-your-writes → database `connection-config-scan` §8)
- a command handler returns and the UI immediately redirects to a list read from an asynchronously fed projection, with no version or position wait; the same in a route loader
- pass: write → redirect → read returns the new value, or the read waits on the returned position

### Sources (distributed)

The distributed-systems research catalog (2026-10-14) § 5 and its notes A (per-broker delivery
semantics and the stable-id table), B (locks, leaders, workflow SDKs, sagas, contracts, event
stores, clocks) and C (the AWS Builders' Library, Google SRE ch. 21–22, WASABI SOSP '24, Jepsen
NATS 2.12.1, and the dynamic-proof toolbox: Testcontainers, Toxiproxy 2.12.0, fast-check
`fc.scheduler`, Go `testing/synctest`); the batch-5 distributed-systems eval (2026-10-14) § 3.5,
which fixed the slot order DS-V1…DS-V37, merged here as V291–V327 in that order (the research's
draft numbering differs from V303 on and is superseded); and the defaults in
[`broker-semantics.md`](broker-semantics.md), fifteen of them re-read at their sources on
2026-10-14. Rows marked [K?] are settled on the `ds-defects` fixture or in a container before a
detector asserts them. Paraphrased; no text reproduced.

## Backend

A backend claim says that the wiring between the HTTP framework and the domain answers a request,
a job run or an event with a status, body, value, run count or state the contract does not allow:
the validation pipe never saw the body, the transform changed a value before validation, a
catch-all turned a 400 into a 500, the serializer dropped scale from a Decimal, a schedule ran
twice at once, an illegal event returned success. Reading the handler does not settle any of
these: which pipe, filter, adapter and serializer run, and what their defaults do on the installed
version, are facts of the project's own bootstrap. The oracle builds the app **from the project's
own factory** and drives the request, the job or the event through it, then reads the rendered
response, the stored row and the effect counters. Every oracle names a **tier**: U (a request or
job run through the real bootstrap: the e2e harness when it imports the real app module, else the
app factory under supertest, `fastify.inject`, the Django/DRF test client, FastAPI `TestClient`,
MockMvc on the full context, `httptest`, a request spec or a Laravel HTTP test), T (a tool's exit:
oasdiff with `--fail-on ERR`, Schemathesis with ≥ 1 stateful link, a linter rule that parsed the
file), S (a static fact with both ends cited: the setting and the code that depends on it) or L (a
non-production base URL named in `--live`). Settled questions are in
[`precedents/backend.md`](precedents/backend.md). Users: `http-contract-scan`,
`validation-boundary-scan`, `edge-error-scan`, `wire-format-scan`, `job-lifecycle-scan` and
`state-transition-scan` (backend pack), run by `/backend-audit`, judged by `@api-reviewer` in
refute mode (with `@verifier` mode `refute` on every BLOCKER and HIGH it keeps), and `/backend-fix`;
`/fix-bug` reads a variant list here when its bug is one of these classes, and `/add-endpoint`'s
production-readiness gate cites V340, V342 and V345 for the endpoint it generates. In-transaction
enqueue and model-callback side effects are § Data (V7, V8); a transition persisted without a
status predicate or version is § Data (V5); retry eligibility and a key minted per attempt are
§ Distributed (V304, V307); a job that repeats its effect on redelivery is V292; arithmetic, minor
units and the clock in code are § Code quality (V83); an unchecked outbound status and an outbound
cast are V76 and V80; config read lazily and boot validation are § DevOps (V234); migrate-on-boot
is V227 and V40; upload caps, repeated-key caps and money idempotency are security's
(`logic-race-scan`, `file-access-scan`) and are proven with [`exploit-payloads.md`](exploit-payloads.md).

**Scope of use.** A scratch database in a container and `${TMPDIR}` only — never the user's
production database, queue or API. A runtime variant runs against `localhost` or a base URL the
user named in `--live` as non-production, with the `endpoint-test` safety invariants (no writes to
shared data without a scratch tenant, no load). Six rules hold for every variant below:

- **The real bootstrap, never a hand-built one.** The app comes from the project's factory: its
  `main.ts`/`configure-app` function or the module that registers `APP_PIPE`, `APP_FILTER` and the
  interceptors; Django settings; `create_app()`; the Spring context. A test that builds its own
  `new ValidationPipe()`, `Fastify()`, `express()` or filter proves nothing about what ships
  (`precedents/backend.md` P4, B-D7). The e2e harness counts when it imports the real app module.
- **The adapter and the version that ship.** Run on the adapter `main.ts` uses and the versions the
  lockfile pins; a variant that depends on a default names the version it read (V357). No lockfile
  → the version-gated variant is `Unconfirmed (version UNREAD)`, never assumed.
- **The production engine for database-dependent rows.** Unique violations, not-found errors from
  the ORM, `select_for_update` and ordering run on the engine production uses, in a container;
  SQLite standing in for Postgres hides them (`precedents/backend.md` B-R16).
- **Read the rendered bytes.** Wire variants assert on the response body as text (or the raw broker
  payload), parsed by the client's parser — never on the object the handler returned.
- **Count effects where they land** — rows, enqueued jobs, provider-stub hits, emails — never log
  lines or handler invocations; time through an injected clock or fake timers, never the host clock.
- **Fail first, pass after, keep the control.** The oracle fails on its assertion before the fix and
  passes after, and the benign control still behaves: the documented tolerant reader still ignores
  unknown keys, the action endpoint still answers its documented status, the read-only cron still
  runs on time. A tool exit that did not run is `NOT-RUN`, never PASS: oasdiff without `--fail-on
  ERR` exits 0 on a breaking diff, and Schemathesis with 0 links on response objects never runs its
  stateful phase.

### Oracle taxonomy (backend)

| Oracle | Tier | Asserts | V |
|---|---|---|---|
| **Real-bootstrap request** | U | the app built from the project's own factory answers the request with the documented status, content type and body | V328–V349 |
| **Failure-class matrix** | U | ten failure classes (unknown route, wrong method, malformed JSON, wrong content type, validation, not-found, conflict, unique violation, uncaught, panic or thrown non-Error) each answer the declared status class, content type and envelope; the next request is served | V330, V345 |
| **Rendered-body round trip** | U | parse(rendered) equals the seeded value: digits, scale, offset, precision, id width | V339, V347–V349 |
| **Schemathesis run** | T | `st run <spec> --url <base> --checks all` exits 0 and the stateful phase covered ≥ 1 link | V328–V338, V340–V344 |
| **Spec diff** | T | `oasdiff breaking <committed> <generated> --fail-on ERR` exits 0 | V337, V338 |
| **Side-effect counter** | U | rows written, jobs enqueued, emails, provider-stub hits equal the expected count | V332, V334, V336, V350–V356 |
| **Cross-commit replay** | U | payloads from the previous commit (a git worktree) are consumed by the new code, and the reverse | V351 |
| **Fire-time iterator + concurrency counter** | U | the scheduler library's own iterator gives one run per business day at the intended local time; max concurrency on one process is 1 | V352 |

| V | Oracle | Asserts | Tier | Detector § |
|---|---|---|---|---|
| V328 | Create and action status | create → 201 + a `Location` that GETs 200; action POST → 200; 204 bodies empty | U, T | `http-contract-scan` §1 |
| V329 | Missing resource | an unknown id → 404 in the envelope, never 200 `null` | U, T | `http-contract-scan` §2 |
| V330 | Domain and DB error mapping | ORM not-found, unique, FK, stale `If-Match`, illegal state → the documented 4xx; nothing reaches 500 | U | `edge-error-scan` §2 |
| V331 | Method and media negotiation | wrong method → 405 + `Allow` where documented; wrong body type → 415 | U, T | `http-contract-scan` §3 |
| V332 | Two GETs, no effect | two GETs leave the row snapshot and the effect counters unchanged | U | `http-contract-scan` §4 |
| V333 | PUT and PATCH semantics | PUT replaces or 400s; PATCH clears only on `null`, never 500; omitted fields keep their value | U | `http-contract-scan` §5 |
| V334 | Repeated key, one effect | same key + body → one effect and the stored response; other principal → never the first response; concurrent → one 2xx + one 409 | U (S1) | `http-contract-scan` §6 |
| V335 | Walk every page | rows with identical sort keys, inserts between pages → every pre-existing id once; `limit` clamped; a bad cursor → 400 | U (S3) | `http-contract-scan` §7 |
| V336 | Batch outcome | all-or-nothing with zero rows, or 207 with `results[i]` aligned — whichever the contract states | U | `http-contract-scan` §8 |
| V337 | Deprecation headers | `Deprecation: @<epoch>`; `Sunset` ≥ `Deprecation`; the spec marks the same operations | U, T | `http-contract-scan` §9 |
| V338 | Spec and output drift | the spec diff and Schemathesis clean; the response equals the domain object projected to the documented fields, no value changed | T, U | `http-contract-scan` §10; `wire-format-scan` §3 |
| V339 | Numbers on the wire | Decimal digits and scale, and ids above 2^53, survive the rendered body | U | `wire-format-scan` §1–§2 |
| V340 | Validation reachability | a wrong-typed required field and an unknown key are rejected through every transport the app exposes | U | `validation-boundary-scan` §1, §2, §7, §8 |
| V341 | Coercion table | each value of the table is rejected or becomes the documented typed value | U | `validation-boundary-scan` §3–§4 |
| V342 | Null and defaults | no `null` reaches a NOT NULL write (no 500); no omitted field is reset | U | `validation-boundary-scan` §5; `http-contract-scan` §5 (BV-14) |
| V343 | Unknown-key policy | the documented policy holds identically at every depth and transport | U | `validation-boundary-scan` §6 |
| V344 | Arrays and groups | one and many values behave alike; over-max rejected; every group validates | U | `validation-boundary-scan` §9 |
| V345 | Failure-class matrix | the ten classes answer the declared envelope; no `FST_ERR_REP_ALREADY_SENT` / `ERR_HTTP_HEADERS_SENT`; the server survives | U | `edge-error-scan` §1, §3–§7 |
| V346 | Version and adapter pair | the same e2e requests give the same status and body on both sides of the pair, or each difference is documented | U | `http-contract-scan` §11; `edge-error-scan` §3 |
| V347 | Time binding | one stored instant per input whatever the server `TZ`, or 422 for naive input; date-only strings unchanged | U | `wire-format-scan` §6 |
| V348 | Rendering and carriers | rendered == charged at ties; carriers hold strings or integer minor units | U | `wire-format-scan` §4–§5 |
| V349 | Time serialization | the same instant, offset and precision out; identical responses under two server zones | U | `wire-format-scan` §7 |
| V350 | State × event | an illegal pair → 409/422 and zero side effects; terminal states never change | U (S4) | `state-transition-scan` §1–§2 |
| V351 | Job payload replay | the job acts on current data, discards a missing record once, and both consumer directions across a deploy succeed | U | `job-lifecycle-scan` §1–§3 |
| V352 | Fire times and overlap | max concurrency 1 on one process; the documented misfire count; one run per business day in the business zone | U | `job-lifecycle-scan` §4–§6 |
| V353 | Job failure recorded | a failing job leaves an observable failure record | U | `job-lifecycle-scan` §7 |
| V354 | Outbound response handling | bodies closed (FD count stable); a provider error mapped to our own 502/503/424 | U | `http-contract-scan` §12; `edge-error-scan` §8 |
| V355 | POST redirect | a 301/302/303 on POST never silently becomes a GET that "succeeds" | U | `http-contract-scan` §12 |
| V356 | Multipart order and abort | file-first and file-last give one outcome; an abort leaves no object and no row | U | `http-contract-scan` §13 |
| V357 | The version pair rule | the oracle ran on the installed version and the finding states it | U | every framework-trap row (HC §11, VB, EE, WF, JL lanes) |

Static-fact classes with no V of their own: the clock seam (`wire-format-scan` §8 — reported only
as `blocked (no clock seam)` on the proof it blocks), and a pipe, filter or serializer setting
whose effect is self-proving from the config line (S tier, both ends cited).

### Real-bootstrap harness

One harness shape covers most slots: build the app from the project's own module and configure
function, on the adapter `main.ts` uses, against a scratch database in a container; send the
request; read the rendered bytes and the stores.

```ts
// vitest + @nestjs/testing on the adapter main.ts uses (Fastify here); the same shape exists for
// Express (supertest over the app factory), Django/DRF (APIClient), FastAPI (TestClient(create_app())),
// Spring (@SpringBootTest + MockMvc, not a @WebMvcTest slice), Go (httptest over the real router
// constructor), Rails request specs and Laravel HTTP tests.
import { Test } from "@nestjs/testing";
import { FastifyAdapter, NestFastifyApplication } from "@nestjs/platform-fastify";
import { AppModule } from "../src/app.module";           // the real module: APP_PIPE, APP_FILTER, interceptors
import { configureApp } from "../src/configure-app";      // whatever main.ts calls — never a copy
const mod = await Test.createTestingModule({ imports: [AppModule] }).compile();
const app = mod.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
configureApp(app); await app.init(); await app.getHttpAdapter().getInstance().ready();
// V342: null on an optional, NOT NULL field must be a 400, never a 500
const res = await app.inject({ method: "PATCH", url: `/products/${id}`, payload: { name: null } });
expect(res.statusCode).toBe(400);
expect(res.headers["content-type"]).toMatch(/application\/json/);
```

- **Failure-class matrix** (V330, V345): one request per class through the same app — `GET /__nope`,
  `DELETE` on a GET-only path, a body of `{`, `Content-Type: text/plain`, a validation failure, a
  random id, a duplicate insert (sequential **and** after a passing pre-check), a route that throws
  `new Error()`, one that throws a string, a framework `HttpException` (400, 404, 413, 415, 429) —
  then one healthy request to prove the process survived. Assert status class, content type and the
  declared envelope for each; capture the logger and assert no `FST_ERR_REP_ALREADY_SENT` /
  `ERR_HTTP_HEADERS_SENT`.
- **Coercion table** (V341): `""`, `" "`, `"false"`, `"FALSE"`, `"0"`, `"no"`, `null`, missing,
  `"12abc"`, `"1e3"`, `"0x10"`, `"Infinity"`, `"-0"`, `3.7` into an integer, `2^53+1`, the enum
  **key** — each in body, query, params, headers and form fields; for env loaders, the same strings
  into the project's config loader at boot.
- **Rendered-body round trip** (V339, V347–V349): seed `10.10`, `0.10`, `1000.00`, `-0.00`,
  `9007199254740993.00`, an id above 2^53, `…10:00:00.123456+03:00`; GET the list, the detail, the
  export and the webhook payload; parse the **text** with the client's parser and compare digits,
  scale, offset and precision. Run twice, under `TZ=UTC` and `TZ=Pacific/Kiritimati` in the test
  process environment.
- **Tool lane** (V328–V338, V340–V344): oasdiff as the Go binary or its Docker image at a pinned
  version — never `npm i oasdiff` (a placeholder package) or `npx @tufin/oasdiff` (not on npm);
  `oasdiff breaking <committed> <generated> --fail-on ERR`, where `<generated>` comes from the code
  in the same run. Schemathesis: `st run <spec> --url <base> --checks all --max-examples 50 --seed 1
  --max-time 300 --report junit`, `ran` only when the stateful phase covered ≥ 1 link (links come
  from response objects or `Location` headers) — 0 links is `NOT-RUN (no links on response objects)`.
- **Jobs and schedules** (V351–V353): the processor class the module registers, on the real queue
  in a container (an eager or in-process queue proves nothing); the scheduler library's own
  iterator (`cron`'s `sendAt`, APScheduler `get_next_fire_time`, Quartz `getFireTimeAfter`, robfig
  `Next`) for fire times; a 1 s schedule running a 2.5 s job for 6 s with a concurrency counter for
  overlap; fake timers for misfire windows.
- **Cross-commit replay** (V351): `git worktree add $SCRATCH/prev <base>`; enqueue with the old
  producer, consume with the new processor, then the reverse.

### Property shapes (backend)

Fuzzers find 5xx and schema violations; none checks one effect per key, completeness under
inserts or legal transitions. Each shape below is written per fix and **shown to fail on the
pre-fix code first** — a property that never fails proves nothing. Engines: fast-check
(`fc.commands` + `fc.asyncModelRun`, `fc.scheduler()` to reorder promise resolution), Hypothesis
`RuleBasedStateMachine`, jqwik `ActionChain`, Schemathesis stateful (learns links from `Location`).

| Shape | Closes | Property |
|---|---|---|
| **S1** repeated key → one effect | V334 | POST twice with one key and body → equal status, id and body; effect count 1 (where AIP-155 "current state" applies, assert the same id) |
| **S3** pagination completeness | V335 | walk the tokens while the scheduler interleaves inserts between pages → no duplicate ids, every pre-existing id present, order by (sort key, id) |
| **S4** (state × event) model | V350 | command sequences over {create, pay, ship, cancel, refund, …} against a transition-table model → `(ok, state)` matches the model after every step; terminal states accept nothing; effect counts match |

### Class variants (backend)

A fix passes the class only when every variant the repo has passes the oracle and the benign
control still succeeds unchanged.

#### V328. Create status, `Location`, non-creating POST, 204 body — create and action status (`http-contract-scan` §1)
- POST create; PUT-to-create (201) vs PUT-update (200); bulk create (207 or 201 + per-item ids); async create (202 + `Location` of a status resource); nested create; upsert; `Location` absolute vs relative
- action POSTs (search, login, verify, calculate, preview, export) → 200 (the Nest default is 201); `@HttpCode(204)` handlers that return a value
- pass: the documented status on every variant; `Location` GETs 200 with the same id; 204 bodies are empty and undocumented

#### V329. Missing resource answered as success — missing resource (`http-contract-scan` §2)
- GET by id, by slug or natural key; nested parent-missing vs child-missing; soft-deleted rows; tenant-scoped miss (identical to absent); HEAD; both Nest adapters (empty body vs `"null"`); a GraphQL nullable field (a documented null is the control)
- pass: 404 + the error envelope; Schemathesis `use_after_free` clean

#### V330. Domain and DB errors mapped to the right status — domain and DB error mapping (`edge-error-scan` §2)
- unique violation (sequential duplicate **and** the race-time violation after a passing pre-check); FK violation; NOT NULL and CHECK violations; not-found from the ORM (MikroORM `NotFoundError` from `findOneOrFail` unless `findOneOrFailHandler` is set, Prisma `P2025`, TypeORM `EntityNotFoundError`, `RecordNotFound`, `ObjectDoesNotExist`, GORM `ErrRecordNotFound`); a domain class sharing the ORM class's name; stale `If-Match` → 412; illegal state → 409
- pass: each maps to its documented 4xx with the envelope; nothing reaches 500

#### V331. Method and media negotiation — wrong method, wrong type (`http-contract-scan` §3)
- wrong method on an existing path; OPTIONS; `text/plain`, `application/xml`, form-urlencoded to a JSON route; `Accept: application/xml`; Go ServeMux patterns under `GODEBUG=httpmuxgo121`
- pass: 405 + `Allow` where the spec documents it; 415 for an unsupported body type; 406 or the documented default representation

#### V332. Unsafe GET — two GETs, no effect (`http-contract-scan` §4)
- `@Get` handlers that write; GET that enqueues, emails or calls a webhook; a `get*` service method that lazily creates; `@All()` / `app.all()`; HEAD auto-routes that run the GET handler
- pass: two GETs leave the row snapshot and the effect counters unchanged (an audit row or analytics counter is the control, `precedents/backend.md` B-A6)

#### V333. PUT and PATCH semantics (`http-contract-scan` §5)
- PUT omitting an optional field, a nested object, an array (replace vs append); PATCH `null` on nullable, non-nullable and nested fields; PATCH with an unknown field; merge-patch array replacement; a JSON Patch `test` failure mid-sequence; DRF `partial=True` forced on PUT
- pass: PUT replaces or 400s; PATCH clears only on `null`, never 500; a failing JSON Patch leaves state unchanged; omitted fields keep their stored value

#### V334. Idempotency-key semantics, routes outside security's money set — repeated key, one effect (`http-contract-scan` §6; money, credit, order, paid-send, webhook routes → security `logic-race-scan` §4)
- same key + body sequential; same key + different body; N concurrent with one key; same key from another principal or tenant; same key on another path or method; first attempt 5xx then retry; first attempt validation 4xx then retry; key after expiry; missing key on a required route; key above the length limit
- pass: one effect; the replay returns the original status and body; a different body → the documented 4xx (`precedents/backend.md` B-G7); concurrent → one 2xx + one 409; another principal never receives the first principal's response (property S1)

#### V335. Pagination correctness — walk every page (`http-contract-scan` §7)
- offset; page/size; keyset on a unique id; keyset on a non-unique key + tiebreak; descending; filters changed between pages; insert and delete between pages; last page exactly `limit`; `limit` = 0, negative, huge, non-numeric; a garbage or tampered cursor; `total` under filters; cursor timestamps truncated by the encoder; DRF on an unordered queryset; an unpaged query cut at a cap on a non-unique key
- pass: walking all pages over rows with **identical** sort keys returns every pre-existing id exactly once; `limit` is clamped or 400; a bad cursor is 400, not 500 (property S3)

#### V336. Batch partial failure — batch outcome (`http-contract-scan` §8)
- all valid; all invalid; mixed; duplicates inside the batch; empty; over the max size; order preserved; a DB failure mid-batch; an idempotency key on the batch
- pass: either a 4xx and **zero** rows written, or 207/200 with `results[i]` aligned to the input index and exactly the valid rows written — whichever the contract states

#### V337. Deprecation signalling — deprecation headers (`http-contract-scan` §9)
- a deprecated operation; a whole version prefix deprecated by middleware; Sunset already passed; the `Link rel="deprecation"` target; the draft-syntax `Deprecation: true`
- pass: `Deprecation` matches `^@\d+$`; `Sunset` is an HTTP-date not earlier than `Deprecation`; the generated spec marks the same operations

#### V338. Spec and output drift (`http-contract-scan` §10; `wire-format-scan` §3)
- required vs optional (a decorator that says optional over a validator that requires, and the reverse); nullable vs optional; an enum added or removed (request and response side); statuses added or removed; a response field added in code that Fastify response schemas or FastAPI `response_model` drop; defaults; `date` vs `date-time`; `int64`; tRPC procedures without `.output()`; Fastify response coercions (`12.7` → `12`, `"no"` → `true`, `null` → `""`)
- pass: Schemathesis and the spec diff are clean, and the response equals the domain object projected to the documented fields with no value changed

#### V339. Numbers on the wire (`wire-format-scan` §1–§2)
- ids above 2^53; BigInt in a response; Decimal `10.10`, `0.10`, `1000.00`, `-0.00`, `9007199254740993.00`; `stripTrailingZeros` paths; DRF `COERCE_DECIMAL_TO_STRING = False`; pydantic v1 → v2 Decimal; list, detail, CSV export, webhook payload and cached response; money nested in arrays; `null` money; Go decode through `any` without `UseNumber()`
- pass: the rendered digits and scale equal the seed on every variant (a `bigint` read only through a guarded mapper is the control, `precedents/backend.md` B-D5)

#### V340. Validation reachability (`validation-boundary-scan` §1, §2, §7, §8)
- interface, `type` alias, `Dto[]`, `Partial<>`/`Pick<>`/`Omit<>`/`Record<>`, `any`/`object`/`unknown`, generic wrappers, **unions including `X | null`** (TypeScript emits `Object`), untyped `@Body()`; the same on `@Query`, `@Param`, `@Headers`, `@MessageBody`, `@Payload`, `@Args`
- nested object, array of nested, optional and nullable nested, 3 levels deep, nested in `PartialType`/`PickType`/`IntersectionType`, discriminated nested; `@ValidateNested` without `@Type` **and** `@Type` without `@ValidateNested`; Spring nested fields and `List<T>` without `@Valid`
- hybrid microservices without `inheritAppConfig`, gateways without `UsePipes`, custom param decorators without `validateCustomDecorators`, Nest 12 `@Body({ schema })` without the Standard Schema pipe, raw adapter routes, Fastify plugins outside Nest, queue consumers receiving external payloads; named primitive params given an object
- pass: a wrong-typed required field and an unknown key are rejected through **every** transport the app exposes (a deliberate `unknown` body with a bounding parser is the control, B-D1)

#### V341. Coercion table (`validation-boundary-scan` §3–§4; the env-loader rows absorb the parse half of BC-02)
- boolean `"false"`, `"0"`, `""`, `"FALSE"`, `"no"`, missing; number `""`, `" "`, `null`, `"1e3"`, `"0x10"`, `"12abc"`, `"Infinity"`, `"-0"`, `3.7` into an integer, `2^53+1`; date `"2026-02-30"`, date-only, date-time with no offset, `null`, an epoch number; a string from a number or an object; arrays from a scalar and from repeated params; the enum **key** of a numeric enum
- `enableImplicitConversion` (`"false"` → `true`); `@Type(() => Boolean)`; `z.coerce.*`; Fastify ajv `coerceTypes`; Jackson `ACCEPT_FLOAT_AS_INT` and missing primitives → 0; .NET case-insensitive numbers from strings; gin zero values (`0`, `false`) on `binding:"required"`; each in body, query, params, headers, form fields and multipart fields
- env loaders at boot: `false`, `0`, `no`, `off`, `FALSE`, `""`, `" true"`, `10s`, `1e3` through `bool(os.getenv(…))`, `!!process.env.X`, `=== 'true'`, `parseInt(process.env.X)`
- pass: each value is rejected or becomes the documented typed value; the handler receives the validated type; an env value is typed or fails the boot

#### V342. Null and default handling (`validation-boundary-scan` §5; `http-contract-scan` §5 for PATCH defaults)
- `null` on required, optional, nullable, nested, array item (`[null]`), enum and boolean fields; `@IsOptional()` (skips `null` as well as absent) over a NOT NULL column with a `!== undefined` guard downstream; absent vs `undefined` vs `null` in PATCH; zod `.optional()` / `.nullable()` / `.nullish()`; pydantic v2 `Optional[int]` required; Spring `@RequestBody(required=false)`; Fastify `null → 0` coercion and `useDefaults` mutation; class-field initialisers in PATCH DTOs
- pass: no NOT NULL write reaches the database (no 500); no omitted field is reset

#### V343. Unknown-key policy (`validation-boundary-scan` §6)
- top-level, nested, inside array items; `__proto__` / `constructor`; a misspelled optional field with a default; unknown query params; `whitelist` without `forbidNonWhitelisted` (silent strip); Fastify `additionalProperties:false` (stripped by ajv's default `removeAdditional`) vs absent (kept); Go case-insensitive and duplicate keys, trailing data, no `DisallowUnknownFields`; echo `c.Bind` letting a body `id` override the path `id`; Jackson ignore-unknown; System.Text.Json case-insensitive matching; Laravel `$request->all()` after a Form Request
- pass: the documented policy holds (400, or ignored with the documented default), identically across all variants (`precedents/backend.md` B-A11, B-G17)

#### V344. Arrays and validation groups (`validation-boundary-scan` §9)
- `[]`, one item, many, over `ArrayMaxSize`/`maxItems`; `?ids=1` vs `?ids=1&ids=2`; `@IsX()` on `T[]` without `each: true`; every validation group, a group with no validators, `groups` without `always: true`
- pass: valid input accepted, invalid rejected, the same semantics for one and many query values

#### V345. Failure-class matrix (`edge-error-scan` §1, §3–§7)
- unknown route; wrong method; malformed JSON; wrong content type; validation error; domain not-found; conflict and unique violation; uncaught exception; thrown non-Error; panic; the framework's own `HttpException`s (pipe 400, 404, 413, 415, throttler 429) through a catch-all
- errors from guards, interceptors, pipes and middleware; an error after headers sent; async throw (Express 4 crashes Node 22); rejected promise; error in a timer callback; double send; Koa un-awaited `next` at each middleware position; `@Res()` without `passthrough` returning a value; an Express-API filter on the Fastify adapter; both Nest adapters
- non-Node defaults: DRF `IntegrityError` → HTML 500; FastAPI unhandled → `text/plain` 500; Flask `errorhandler(Exception)` turning 404/405 into 500; ASP.NET `[ApiController]` auto-400 outside the envelope; gin `New()` with no recovery; Go `http.Error` with no `return`; axum rejections in plain text and panics without `CatchPanicLayer`; the proxy's 413 page
- pass: each class answers its documented status with the declared content type and envelope; the server answers the next request; no `FST_ERR_REP_ALREADY_SENT` / `ERR_HTTP_HEADERS_SENT` in captured logs (a documented v1 door shape is the control, B-D6)

#### V346. Framework-migration and adapter deltas — version and adapter pair (`http-contract-scan` §11; `edge-error-scan` §3)
- Express 5 route syntax (`:id?`, `/*`, `:id(\d+)`), bracket query filters under the `simple` parser, `req.query` writes, `req.body` undefined with no parser, `res.send(404)`; Nest Express → Fastify (body limit, empty JSON body, `text/plain`, XML, `__proto__`, a `null` return, filters, `@Res()` typed from `express`); pydantic v1 → v2 `Optional`; Rails 7.1 → 7.2 transaction exit; Jackson 2 → 3; Go `httpmuxgo121`; axum 0.7 → 0.8 paths; Apollo 4 → 5 variable errors; Fastify hooks reading `request.body` in `onRequest`, plugins without `fp()`; DataLoader at module scope
- pass: the same e2e requests give the same status and body on both sides of the version or adapter pair, or each difference is documented

#### V347. Time binding (`wire-format-scan` §6)
- no offset, `Z`, `+03:00`, `+0300`, date-only, epoch int, µs and ns precision; pydantic `datetime` vs `AwareDatetime`; `LocalDateTime` in a request body for an instant; .NET `DateTime` vs `DateTimeOffset`; `@Type(() => Date)` / `z.coerce.date()` with no strict ISO check; calendar fields (`dob`, `due`, `valid_until`) typed as instants; Go `time.Parse` with no zone; server under `TZ=UTC`, `Pacific/Kiritimati`, `Asia/Kathmandu`
- pass: one stored instant per input regardless of server `TZ`, or 422 for naive input; `2026-02-30` → 400; date-only strings unchanged (dates kept as strings with a strict validator are the control, B-D12)

#### V348. Rounding and money in carriers — rendering and carriers (`wire-format-scan` §4–§5; minor units, mixed currencies and the rounding point in code → § Code quality V83)
- a serializer or field setting that rounds differently from the compute (`DecimalField` places, `quantize` with no rounding argument, `setScale(n)` with no mode); ties `x.xx5` positive and negative; the rendered amount vs the amount sent to the PSP stub
- `float(`, `Number(`, `.toNumber()`, `doubleValue()` of an amount inside `queue.add(`, `.delay(`, `apply_async(`, `publish(`, `emit(`, a cache `set(` or an outbound body; `double` amounts in Avro, Protobuf or JSON Schema; payloads already in the queue
- pass: rendered == charged at every tie; the raw broker payload, cache value and outbound body hold a string decimal or integer minor units

#### V349. Time serialization and zone configuration — time serialization (`wire-format-scan` §7)
- the configured mapper bean **and** hand-built `new ObjectMapper()`; `ADJUST_DATES_TO_CONTEXT_TIME_ZONE`; `LocalDateTime`, `OffsetDateTime`, `Instant`, `java.util.Date`; cursor fields; `DjangoJSONEncoder` on cursor keys; `USE_TZ = False`; `TimeZone.setDefault(`; Rails `Time.now` vs `Time.current`; US and EU DST gap and overlap dates
- pass: the same instant and the contracted offset and precision out; identical responses under two server zones

#### V350. Illegal events and terminal states — state × event (`state-transition-scan` §1–§2; a transition persisted without a status predicate → § Data V5)
- every (state × event) pair from the state graph, entered via HTTP, job, webhook, admin action and a replayed provider event; `ignore_invalid_triggers=True`, `allow_event_without_transition=True`, AASM `whiny_transitions: false`, an XState `actor.send` with no `can()`, a looplab/fsm error dropped, a Spring Statemachine `sendEvent` result ignored; wildcard sources and events with no `from:`; terminal states × every event
- pass: an illegal pair yields a typed error (409/422) and **zero** side effects (effects counted, not the state); terminal states never change (property S4; UI statecharts and handlers that check the result are the control, B-R5)

#### V351. Job payloads across time and deploys — job payload replay (`job-lifecycle-scan` §1–§3)
- a model object or entity in the payload, pickle serialization, a Quartz `JobDataMap` entity; update after enqueue; delete and soft-delete after enqueue (ActiveJob without `discard_on ActiveJob::DeserializationError`, Laravel `SerializesModels` without `$deleteWhenMissingModels`, an id-based `findOneOrFail` with no not-found branch); a relation changed after enqueue; old → new and new → old consumer; scheduled and delayed jobs; retries of failed jobs
- pass: the job acts on current data (or a documented snapshot), discards a missing record once with a log line and 0 retries, and both consumer directions succeed (cross-commit replay; drained-by-runbook queues and versioned payloads are the control, B-R7)

#### V352. Schedules — fire times and overlap (`job-lifecycle-scan` §4–§6; once-per-fleet → V40; the DST-day count of a coordinated schedule → V319)
- a run longer than the period × 1 and × 2 on one process: npm `cron` without `waitForCompletion`, node-cron without `noOverlap`, `@nestjs/schedule` `@Cron` without `waitForCompletion: true` (6.1.3 and 12.0.2 build it with `CronJob.from` on `cron` 4.4.0 and pass the option only when set; `@Interval` is a plain `setInterval`, which overlaps an async body; every scheduled method is wrapped in a log-only try/catch, so a throw neither stops the schedule nor surfaces — source read 2026-10-14), Laravel without `withoutOverlapping`, Spring `fixedRate` on virtual threads, Quartz without `@DisallowConcurrentExecution`, robfig without `SkipIfStillRunning`; after a restart
- downtime across 1 and N fire times on a must-run job (billing, settlement, payout, month-end) with no misfire instruction, grace or coalesce (APScheduler's default grace is 1 s); a schedule with no `timeZone` / `zone=` / `->timezone(` / `spec.timeZone`; an hour field 0–3 in a DST zone; month-end (`L`, the 31st)
- pass: max concurrency 1 on one process; executions after downtime equal the documented misfire policy; exactly one run per business day at the intended local time (idempotent, read-only, cheap jobs are the control, B-R8)

#### V353. Job result or failure discarded — job failure recorded (`job-lifecycle-scan` §7; retry classification and partial effects → V304, V308)
- a BullMQ `Worker` with no `failed` listener and `attempts` ≤ 1 or `removeOnFail: true`; Celery `ignore_result=True` with a later `AsyncResult`; Spring `@Async` `void` business methods; FastAPI `BackgroundTasks` on a money path (they raise after the 200); Laravel money jobs with no `failed()`
- pass: making the job throw leaves an observable failure record (a failed-jobs row, a DLQ entry, a counter an alert reads)

#### V354. Outbound response handling — body closed, status mapped (`http-contract-scan` §12; `edge-error-scan` §8; status unchecked → V76; shape trusted → V80)
- Go `resp.Body` never closed or drained (golangci `bodyclose`); Python `stream=True` outside `with`; 2 × pool size + 1 calls; a provider 401/404/429 passed through as our status (`res.status(err.response.status)`, `HTTPException(status_code=e.status_code)`)
- pass: the FD count stays stable at 2 × pool + 1 calls; a provider error becomes our own 502/503/424 with our code (a documented proxy or BFF is the control)

#### V355. POST redirected to GET — POST redirect (`http-contract-scan` §12; retries and per-attempt keys → V307; a redirect to an internal host → security `ssrf-scan` §4)
- 301/302/303/307/308 on an outbound POST through `fetch`/axios/`requests` with default redirect settings to a configurable base URL
- pass: a POST is never silently turned into a GET that "succeeds"; 307/308 keep the method and body or the redirect is refused

#### V356. Multipart order and partial uploads — multipart order and abort (`http-contract-scan` §13; caps → security `file-access-scan` §2; temp-file cleanup → V79)
- file-first and file-last part order (busboy/multer `fileFilter` or `destination` reading `req.body`, `@fastify/multipart` `request.parts()` loops reading a field after a file); abort at 1 %, 50 %, 99 %; streaming to object storage with no byte-count check; `CompleteMultipartUpload` in a `finally`
- pass: the same outcome for either part order; no object and no row after an abort

#### V357. The version pair rule — every framework-trap row (HC §11 and the lane rows of VB, EE, WF and JL)
- for each framework trap, the two most recent majors where behaviour differs (Express 4/5, Nest 11/12, Fastify 4/5, pydantic 1/2, Jackson 2/3, Rails 7.1/7.2, axum 0.7/0.8, Apollo 4/5, Spring Boot 3/4)
- pass: the oracle is run on the installed version, and the finding states that version; a row whose version is `UNREAD` is Unconfirmed

### Sources (backend)

The backend research catalog (2026-10-14) § 5 (the oracle taxonomy, the variant lists and the
property shapes) and its notes A (API contract and validation on Node, with oasdiff 1.33 and
Schemathesis 4.31 runs in its lab), B (runtime correctness per framework, defaults read from
installed source) and C (public API guidelines, incidents, fast-check 4.10.2 property runs); and the
batch-5 backend eval (2026-10-14) § 4.2 and § 5.10, which fixed the slot order B-V1…B-V30 — the
research's V291–V313, V317–V321, V323 and V324 in that order, with V311, V319, V320, V321 and V323
narrowed to the backend-owned classes and V304 absorbing V322's env-loader rows — merged here as
V328–V357 after § Distributed (the research's draft numbers collide with § Distributed and are
superseded). Rows the research left [K]/[K?] (Spring Boot 4 and Jackson 3 defaults, the
Nest 11 `ValidationPipe` rows (the `@nestjs/schedule` overlap default is settled from its 6.1.3 and 12.0.2 source on `cron` 4.4.0, V352), .NET, Rails, Laravel and Rust
rows) are settled on the `backend-defects` fixture before a detector asserts them. Paraphrased; no
text reproduced.

---

## Implementation notes for the test writer

- **Mock at the boundary, not the unit.** Query and plan oracles need the real ORM and engine; timing oracles mock the downstream at its client or network edge, never the code under test.
- **Pair every proof with its control.** The same entry point on its legitimate path, with its count, plan or latency asserted unchanged after the fix.
- **One finding, one test file,** named after the class; it stays in the suite as the regression guard and is cited in the fix's closure row (`fail→green`).
- **Keep production numbers out of tests.** Budgets and caps come from configuration the test reads, so the test proves the wiring and survives a re-tune.
- **No harness at all?** Run a scripted probe, paste its output verbatim, and label it `Probe (recorded)`, never `Test`; the finding stays Unconfirmed until a test exists.
- **No shortcuts that fool the oracle.** No input special-casing, no caching across test runs, no detecting the harness; the workload in the variant list differs from the one the fix was tuned on.

**Evidence block** — one per finding and per fix; a performance claim without it is not reported:

```text
oracle:     <run-invariant metric> before→after   e.g. queries/request 41→3 at N=40 (3→3 at N=2)
claim:      <metric> <direction> by Δ=<x%> [95% CI lo..hi], p=<p> (<test>), n=<a>/<b>, CV_base=<c%>   (cost claims only)
harness:    <tool@version> <exact command>; interleaved=<how>; warm-up=<…>
env:        <runner or device, CPU>, dataset=<name + size>, cache=<warm|cold>, build=<release>
guardrails: <metric before→after, each within the noise band>
verdict:    proven (oracle) | improvement | regression | within noise ±<band> | Unconfirmed (probe: <exact command>)
```

## Sources

Fetched or read 2026-10-02 unless dated: MikroORM 6.6.16 typings and source (`Logger`,
`DefaultLogger`, `Connection.logQuery`, driver exception classes, CLI `migration:check`); Prisma ORM
v7 docs, *Logging*; pytest-django docs, *Helpers* (`django_assert_num_queries`,
`django_assert_max_num_queries`); Django 5.2 docs, *Testing tools* (`assertNumQueries`); Rails
7-2-stable `activerecord/CHANGELOG.md` (7.2.0, 2024-08-09: query assertions made public) and
`activerecord/lib/active_record/testing/query_assertions.rb`; Laravel 10.x and 13.x docs, *Database
Testing*, and `Illuminate/Foundation/Testing/Concerns/InteractsWithDatabase.php` (12.x);
Hibernate ORM 6.6 javadoc, `org.hibernate.stat.Statistics`; pgx v5 docs (`QueryTracer`, v5.11.0,
2026-09-07); Node.js docs, `perf_hooks.monitorEventLoopDelay` (nanoseconds; added v11.10.0);
PostgreSQL 18.6 docs, *Using EXPLAIN*; eugene README (MIT); MikroORM master `upgrading-v6-to-v7.md`
(`getMigrator()` removed) and `Connection.ts`. The data oracle taxonomy and the V1–V24 variant
lists come from the database research catalog for this pack (Hermitage, Jepsen, PostgreSQL, MySQL
and SQLite documentation, paraphrased), which also dates the Laravel (9.51.0), django-zeal,
n_plus_one_control and hypersistence-utils facts. The core rule, the statistics thresholds, the
runner-noise figure, the tool notes, the evidence block and the V25–V35 variants come from the
performance research catalog (benchstat and golang.org/x/perf; CodSpeed; Grafana k6 docs and
licence, AGPL-3.0; Lighthouse CI 0.15.1 configuration docs; PEP and runtime docs as cited there).
The two-replica, queue-age, redelivery, server-limit, admission and probe oracles and the V36–V47
variants come from the same catalog's horizontal-scale (SC) and resilience (RS) rows, which cite
the Socket.IO *Using multiple nodes* guide, the APScheduler FAQ, the Quartz clustering docs, the
Kubernetes CronJob and probe docs, the AWS Builders' Library and Google SRE *Handling Overload*.
The frontend oracles and V48–V53 come from its frontend notes: web-vitals 6.2.2 (2026-09-14),
`@lhci/cli` 0.15.1 (2025-06-25) bundling Lighthouse 12.6.1, Chrome DevTools MCP 1.10.1
(2026-09-23), memlab 2.0.5 (2026-08-29, MIT), the Vite manifest docs and the Next.js 16.1 release
notes. V147–V151 and the Lighthouse 13 id table come from the frontend research catalog § 1.9 (P-01–P-04, P-06) and its notes on Lighthouse 13.5.0 (2026-09-18) and `@lhci/cli` 0.15.1, and MDN *PerformanceResourceTiming.renderBlockingStatus* and *PerformanceScriptTiming* (fetched 2026-10-05: both exist, neither is Baseline); merged 2026-10-10.
