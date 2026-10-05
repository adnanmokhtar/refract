# Proof oracles — the failing-first proof for each detector class

Used by [`refute-before-report.md`](refute-before-report.md) gate 6, by `/db-fix`, `/perf-fix`, `/test-fix` and
`/quality-fix` (reproduce failing-first, then validate the fix), and by every detector whose PROOF line names an
oracle. Security's counterpart is [`exploit-payloads.md`](exploit-payloads.md). Each class has one
**oracle** — a deterministic, no-human pass/fail signal — a failing-first test shape per stack, and
a **whole-class variant list** the fix must survive. Sections are per domain (`## Data`,
`## Performance`, `## Frontend`, `## Testing`, `## Code quality`); later domains append their own.

## Scope of use (read first)

- Run against a local, CI, branch or restored copy — never the production primary without the user's explicit go. `EXPLAIN ANALYZE` executes the statement: wrap data-changing statements in `BEGIN; … ROLLBACK;`.
- Query counting needs the **real ORM against a real database** (a container, a CI service), not a mocked repository. Concurrency and lock oracles need the project's real engine: an in-memory fake, or SQLite standing in for Postgres, hides the race and the lock.
- Seed generated data at the production **growth class** (row estimate, tenants, fan-out), not three rows. Copy production data only when anonymised.

## A fix passes the whole class, not the one query

A fix tested against the reported list endpoint is a fix for that endpoint. The regression test runs
**every** variant of the class (§ Class variants (data), (performance) and (frontend)) against the
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
count, a heap-leak cluster. **Cost** is Lighthouse medians under the noise rules (lab) and field
p75 (truth). **INP is field-only**: lab INP and Total Blocking Time are proxies. Every variant runs
on **mobile** (Lighthouse's default throttling: 4× CPU, slow 4G) **and desktop**, against a
production build (`vite preview`, `next start`, the deployed site) — never a dev server.

### Oracle taxonomy (frontend)

| Oracle | Asserts | Classes |
|---|---|---|
| **Bytes per route** | Brotli bytes per route are equal across two builds of one commit; base → head is an exact delta under the budget | V48 |
| **Lighthouse median** | A Lighthouse 12 audit id passes on the median of 5 runs, mobile and desktop | V48–V51 |
| **Trace insight** | A DevTools performance insight no longer names the element, request or script | V49–V51 |
| **Field attribution** | The web-vitals attribution build no longer attributes the metric to the element or sub-part | V49–V51 |
| **Render count** | A subtree's commits are unchanged by an unrelated update | V52 |
| **Yield count** | A chunked handler yields at least once per chunk | V51 |
| **Heap leak (memlab)** | An action repeated and reverted leaves no leak cluster; retained size stays flat | V53 |

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
`aggregationMethod: "median-run"`, mobile and desktop. `@lhci/cli` 0.15.1 bundles Lighthouse 12.6.1,
so assertions use the Lighthouse 12 ids — `lcp-lazy-loaded`, `largest-contentful-paint-element`,
`render-blocking-resources`, `duplicated-javascript`, `legacy-javascript`, `third-party-summary`,
`total-blocking-time`, `cumulative-layout-shift`; the Lighthouse 13 `*-insight` ids may not
resolve there.

```json
{ "ci": { "collect": { "numberOfRuns": 5, "startServerCommand": "npm run start", "url": ["http://localhost:3000/"] },
  "assert": { "assertions": {
    "lcp-lazy-loaded": ["error", { "minScore": 1 }],
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
`a11y-code-scan`, `a11y-scan`, and every later UI-state, rendering, client-data and i18n detector and
fix command.

### Oracle taxonomy (accessibility and UI states)

| Oracle | Asserts | Classes |
|---|---|---|
| **Axe at route-state** | One axe rule id has no violation node at the route-state, with the WCAG 2.2 tag set; `incomplete` nodes are listed, never dropped | V88, V94, V97, V98, V101–V103 |
| **Keyboard path** | Tab reaches the control, Enter / Space activate it, Escape closes what it opened, focus returns to the trigger, nothing traps focus outside a modal | V87, V90, V92, V95, V96, V99, V100 |
| **Role and label query** | `getByRole(role, { name })` or `getByLabel(text)` resolves exactly one element | V88 |
| **Aria snapshot diff** | `toMatchAriaSnapshot` before and after the interaction shows the state change (`[expanded]`, `[selected]`, `[checked]`, `[pressed]`) | V94, V95 |
| **Focus-visible delta** | The keyboard-focused element differs from its blurred render, in normal and forced-colours modes | V89 |
| **Obscured rect** | No focused element is entirely covered by a `fixed` / `sticky` element | V91 |
| **Live-region presence** | The status region exists and is empty before the action and holds the message after it; a field error is the input's accessible description or error message | V92, V93 |
| **Geometry** | Each target's box is ≥ 24×24 CSS px or meets the spacing exception | V102 |
| **Reflow probe** | At 320 CSS px wide nothing scrolls horizontally outside a 2-D container; injected 1.4.12 spacing clips nothing | V103 |
| **Media emulation** | Under `reducedMotion: 'reduce'` no long animation runs; under `forcedColors: 'active'` the focus ring is still drawn | V89, V98 |
| **Paste probe** | A value pasted into a credential or OTP field arrives intact | V97 |
| **Clock fast-forward** | A session-timeout warning with an extend action appears before sign-out | V100 |
| **Injected violation** | A known violation added to the page turns the project's a11y gate red | V104 |
| **State matrix** | The surface renders the specified state for each network answer (pending, `[]`, 500, network error, 403, 404, partial, offline, failed refetch) | V105 |
| **Request count** | One user intent sends exactly the specified number of requests | V106 |
| **Console hydration** | A production SSR load logs no framework hydration message and throws no `pageerror` | V107 |
| **Mount/unmount balance** | After unmount, timers, listeners, observers and subscriptions are back at their starting count | V108 |
| **Reorder identity** | Local state (typed text, focus, expansion) follows its item when the list reorders | V109 |
| **Request order** | When responses arrive out of order, the UI shows the latest request's data | V110 |
| **Pseudo-locale** | Every visible string carries the pseudo-locale marks, and +40 % text clips nothing | V111 |
| **RTL mirror** | Under `dir="rtl"` the layout mirrors and `lang` / `dir` follow the locale | V112 |

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

### Sources (accessibility and UI states)

The taxonomy and V87–V112 come from the frontend research notes for this batch (2026-10-05): the
accessibility pass (axe-core 4.13.0 and `@axe-core/playwright` 4.13.0 source, Playwright 1.63.0
types, Lighthouse 13.5.0, `@guidepup/virtual-screen-reader` 0.33.0, the WCAG 2.2 understanding
documents as summarised there), the UX-states pass (MSW 3.0.2 exports, TanStack Query 5.104 option
signatures, Playwright route and offline APIs) and the i18n / SSR pass (hydration message strings read
from React 19.3.0, Vue 3.5.43, Svelte 5.57.1 and Angular 22.2.1 shipped sources; the
`pseudoLocalizeString` vs `PseudoLocalizeDom` distinction). The keyboard-path, live-region and
geometry shapes follow the research's ranked techniques. Paraphrased; no text reproduced.

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
notes.
