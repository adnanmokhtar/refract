# Proof oracles — the failing-first proof for each detector class

Used by [`refute-before-report.md`](refute-before-report.md) gate 6, by `/db-fix`, `/perf-fix`, `/test-fix`,
`/quality-fix`, `/frontend-fix`, `/mobile-fix`, `/obs-fix`, `/devops-fix`, `/infra-fix`, `/ds-fix`, `/backend-fix`, `/product-fix`, `/doc-refresh --from-audit`, `/refresh-knowledge --from-audit` and `/find-and-fix --from-audit`, `/data-fix`, `/design-algorithm --from-audit`, `/cost-guardrails --from-audit` (reproduce failing-first, then validate the fix), and by every
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
| `## Migration` | V358–V388 | — (new section; V388 is PP-5, V1-gated suites) |
| `## Align` | V389–V408 | — (new section; proof classes EQ / VC / FN) |
| `## Product` | V409–V429 | — (new section; proof families S / T / U / L) |
| `## Documentation` | V430–V449 | — (new section; proof families S / T / X / M) |
| `## Business` | V450–V489 | — (new section; proof families S / P / G / D / T / R / L; V485–V489 reserved) |
| `## Learning` | V490–V509 | — (new section; proof tiers S / T / U) |
| `## AI engineering` | V510–V539 | — (new section; proof families S / T / U / L; V510–V525 are the security pack's LLM trust rows) |
| `## Data engineering` | V540–V569 | — (new section; proof families R / L / C / M / T / S / D) |
| `## FinOps` | V570–V589 | — (new section; proof families P / L / S / E / R / T) |
| `## Algorithms` | V590–V609 | — (new section; proof families O / A / P / D / R / S) |

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
`jscpd --baseline-from-ref "$BASE" --fail-on-new-clones src` (installed tools only). Then prove nothing was gamed:
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
- TF-11: a secret-shaped `variable` without `sensitive = true`, outputs referencing it, `random_password` / `tls_private_key` outputs; a write-only `*_wo` argument or ephemeral resource available at the locked provider version and unused (TF-02 values → security `secret-scan-method`)
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
user named in `--live` as non-production, with the `endpoint-test-method` safety invariants (no writes to
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

## Migration

A migration claim says that V2, the port meant to keep V1's behaviour, answers the same input with a
different status, body, guard decision, stored value, side effect, schedule or row than V1 does: a
route V1 serves 404s, a guard V1 enforced is gone, an empty string V1 nulled is stored, a negative
half rounds the other way, an observer's email is never sent, a backfill overwrites a newer row, a
parity suite never ran. Reading both trees does not settle these. The difference lives in defaults,
global wiring and data the reader does not see, and "it is the same code in TypeScript" is the
claim, not the proof. The oracle runs **V1 as the oracle**: the same input through both, then a
comparison under a declared normaliser. It runs failing first on the **pre-fix V2**. Every oracle
names a **family**:
- **D**: differential replay, the same request or call on V1 and V2.
- **J**: a side-effect journal, the multiset of outbound effects per request.
- **M**: a permission matrix of (role × route × owner/tenant) cells.
- **R**: a reconciler that must report seeded drift.
- **P**: a property test with V1 as the model.
- **S**: a static fact with both ends cited, the V1 line and the V2 line.

Settled questions are in [`precedents/migration.md`](precedents/migration.md).

Users:
- the detectors `surface-parity-scan` (SP), `semantics-parity-scan` (SM), `side-effect-parity-scan` (SE), `data-cutover-orchestrate` (DC), `cutover-routing-scan` (CR) and `parity-proof-scan` (PF), over `paired-inventory`'s lanes (migration pack);
- `/compare-v1`, which runs them, judged by `@parity-auditor` in refute mode with `@verifier` mode `refute` on every BLOCKER and HIGH it keeps;
- `/find-and-fix --from-audit`, which writes each finding's failing-first test from its V-number;
- `parity-test-generate`, which builds the corpus V358 and V387 grade.

**Owned elsewhere.** These classes keep their own sections:
- decimal digits, scale and ids above 2^53 on the wire → § Backend V339 (V363 routes the V1 cast lane there);
- null and default handling in one codebase → V342; the coercion table → V341;
- transaction and isolation in one codebase → § Data V5, V7 (V370 routes the V1 transaction inventory);
- i18n rendering in one codebase → § Accessibility and UI states (i18n) (V369 routes the V1 catalog rows);
- a skipped or never-collected suite → § Testing V61–V62 (V388 is the V1-gated case);
- dual-write mechanics → § Distributed;
- authz widening and tenant leaks → security, proven with [`exploit-payloads.md`](exploit-payloads.md) (V359's matrix supplies the cells).

**Scope of use.** Scratch databases in containers and `${TMPDIR}` only. Never the production
primary, never a live V1 that sends real mail, never a shadow that reaches real downstreams. Eight
rules hold for every variant below:

- **V1 is the pinned snapshot, never a moving checkout.** Extract V1 with `GIT_OPTIONAL_LOCKS=0 git -C "$V1" archive "$PIN" | tar -x -C "$RUN/v1"` at the ledger's `v1_commit_pinned`, and boot it there. Print `find -newer <stamp>` on both audited roots at the end; it must be empty.
- **Both sides on their real bootstrap.** V2 is built from its own factory and module (§ Backend, real-bootstrap harness). V1 runs from the snapshot with its own vendor tree, kernel and middleware; a Laravel V1 is booted with `php artisan serve` or exercised by a Laravel HTTP test on the snapshot copy [K?: whether booting writes `bootstrap/cache/*` is unmeasured; it only ever touches the copy]. A V1 that cannot boot makes every D/J/M/P row `Unconfirmed (V1 not bootable: <reason>)`, never PASS.
- **Same data on both sides.** Seed both from one fixture set, or restore one anonymised snapshot into two containers. Compare rows and effects on **business keys**, never surrogate ids.
- **Normalise, then declare what the normaliser hides.** Run the comparator, `behavior-diff.py`, with its five tolerance keys (`exact`, `structural`, `numeric_tolerance`, `order_insensitive`, `ignore`), one key per path. An `ignore` entry is legal only for a path that differs between **two V1 runs** (calibration, `precedents/migration.md` § 10). `structural` never hides presence (§ 8), and status-only comparison is not a comparison (V385).
- **Calibrate before reading V1-vs-V2.** Run V1 against V1 first: one run must show 0 mismatches after normalisation, or the noise floor is unknown and the comparison is `blocked (no control-vs-control run)`. The static lanes have their own calibration pair (`precedents/migration.md` § 22).
- **Effects are counted where they land:** a Mailpit message, a WireMock journal entry, a queue message, an audit row, a search-index call. Log lines and handler invocations do not count.
- **Fail first on the pre-fix V2, pass after, keep the control.** The variant fails before the fix and passes after, and the benign control (a route both sides agree on, an ADR-declared break with its `changes_baseline`) stays as it was.
- **Paired vs solo.** In paired mode the oracle compares V1 to V2. In solo mode (no V1 tree, a recorded inventory) only guarantee classes are provable, by a V2-only invariant plus the recorded V1 line. Every other row is `Unconfirmed-solo` with "re-run with `--v1=<path>`" (`precedents/migration.md` § 21). A tool or suite that did not run is `NOT-RUN`, never PASS.

### Oracle taxonomy (migration)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Differential replay** | D | the V1 corpus (route list, error paths, omitted optionals, boundary values) through V1 and V2 gives equal status class, `code`, field keys and body under the declared tolerance | V358, V361, V362, V366, V367, V376, V377, V378, V380, V383, V384 |
| **Permission matrix** | M | for every (role × route × owner/tenant) cell, V2's decision ⊆ V1's (widening) and V1's ⊆ V2's (narrowing), status class equal | V359 |
| **Property with V1 as model** | P | `normalise(V2(x)) == normalise(V1(x))` over generated inputs at the class's boundaries; shrinking hands back a minimal diverging input | V360, V363, V364, V365, V368 |
| **Side-effect journal** | J | the multiset of (kind, target, normalised payload) per request is equal; in shadow mode the candidate emits 0 external effects | V371 |
| **Seeded-drift reconciler** | R | the reconciler reports every seeded drift; a masked class is `Unconfirmed` | V374, V375, V379, V385 |
| **Fault and flip drill** | D | kill, restart and flip under write load, then lost = 0, duplicated = 0; rollback after N V2 writes serves them on V1 | V370, V374, V381, V382 |
| **Inventory equality** | S | the V1 inventory (consumers, schedules) maps 1:1 to V2 or to an ADR row | V372, V373 |
| **Integrity gate** | D, S | the V1-pinned tests and goldens run unmodified, coverage holds, V1 branches are reached, the V1-gated suites executed k > 0 | V386, V387, V388 |
| **Catalog render** | D | each key × locale × count renders the same form on both sides | V369 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V358 | Route-list replay | every live V1 route × method answers on V2 with the same status class; shapes, defaults and omitted optionals agree | D | `surface-parity-scan` §1, §2, §9; `parity-proof-scan` §3 |
| V359 | Permission matrix | V2 ⊆ V1 per cell (widening → security), V1 ⊆ V2 (narrowing); the cross-tenant cell is refused on both | M | `surface-parity-scan` §3–§5 |
| V360 | Enum round trip | every V1 value survives parse → store → serialise on V2; every V2 value is read by V1's consumers | P, D | `surface-parity-scan` §6 |
| V361 | Boundary corpus | accept/reject **and** the stored value agree per field, including the global trim and empty→null | D | `surface-parity-scan` §7 |
| V362 | Error corpus | status, `code` and field keys agree on every contract error path (message text tolerated) | D | `surface-parity-scan` §8; `parity-proof-scan` §3 |
| V363 | Money property | V2(x) == V1(x) exactly at .5 ties, negatives, many-line sums and allocation remainders | P | `semantics-parity-scan` §1–§3 |
| V364 | Integer property | division and modulo agree on negative operands and at the overflow bounds | P | `semantics-parity-scan` §4 |
| V365 | String property | length, case, slicing and regex agree on multibyte, combining, emoji, Turkish İ/ı and RTL input | P | `semantics-parity-scan` §5 |
| V366 | Order-sensitive list diff | the full order agrees on data with ties, mixed case and nulls, and pagination neither duplicates nor skips | D | `semantics-parity-scan` §6 |
| V367 | Presence diff | `[]`, `{}`, `null`, absent, `"0"`, `false` and `0` render the same per field | D | `semantics-parity-scan` §7 |
| V368 | Clock property | instants and dates agree across DST, month end, Feb 29 and server `TZ` ≠ UTC | P | `semantics-parity-scan` §8 |
| V369 | Plural render | each key × locale × count {0,1,2,3,11,100} renders the same form | D | `semantics-parity-scan` §9 → frontend `i18n-scan` |
| V370 | Crash and race probe | a crash mid-write and two concurrent writers leave the same state on both sides | D | `semantics-parity-scan` §10 → database `transaction-scan` |
| V371 | Effect journal | the (entity, verb) effect multiset is equal; shadow emits 0 | J | `side-effect-parity-scan` §1, §2, §5; `cutover-routing-scan` §3 |
| V372 | Consumer inventory | every non-app DB user, view, export and report maps to a V2 contract or a dated retirement | S | `side-effect-parity-scan` §3 |
| V373 | Schedule equality | each V1 cron and consumer has a V2 entry with the same expression, zone and overlap rule, plus one dry run | S, D | `side-effect-parity-scan` §4 |
| V374 | Backfill kill-resume | kill at 50% then resume: no duplicates, no gaps, no newer row overwritten | R | `data-cutover-orchestrate` §1–§2 |
| V375 | Seeded drift | the reconciler reports every seeded drift class | R | `data-cutover-orchestrate` §3, §6 |
| V376 | Two-path equality | one row through the backfill and the dual-write path is structurally equal, also after a mid-window mapping change | D | `data-cutover-orchestrate` §4, §12 |
| V377 | Old-id resolution | every V1 id form resolves through V2 | D | `data-cutover-orchestrate` §5 |
| V378 | Soft-delete probe | lists, counts, unique checks and exports exclude soft-deleted rows as V1 did | D | `data-cutover-orchestrate` §7 |
| V379 | Pre-load anomalies | orphans per FK and duplicates per natural key are counted and each class has a decision | R | `data-cutover-orchestrate` §8 |
| V380 | First insert after load | the first V2 insert per table succeeds | D | `data-cutover-orchestrate` §9 |
| V381 | Flip under load | a write flip under write load: lost = 0, duplicated = 0 | D | `data-cutover-orchestrate` §10 |
| V382 | Rollback rehearsal | after N V2 writes, V1 serves them after the flip back, in one step | D | `data-cutover-orchestrate` §11; `cutover-routing-scan` §4 |
| V383 | Façade route probe | every ledger route, per method, reaches the declared side | D | `cutover-routing-scan` §1 |
| V384 | Session crossing | a session from either side is valid on the other; CSRF and logout hold | D | `cutover-routing-scan` §2 |
| V385 | Comparator self-check | one seeded mismatch per tolerance key is reported; both-raise with different errors is a mismatch | R | `parity-proof-scan` §5 |
| V386 | V1-pinned integrity | the V1-pinned tests and goldens run unmodified, with no new skips and a coverage drop ≤ 5 points | D, S | `parity-proof-scan` §1 |
| V387 | V1 branch floor | V1 branch coverage under the parity corpus ≥ the declared floor; unreached branches listed | D | `parity-proof-scan` §2 |
| V388 | V1-gated suites ran | in the CI run that backs the claim, the V1-gated suites executed k > 0 tests, with the variable set by the job | D, S | `parity-proof-scan` §4 → testing `suite-execution-scan` §2c |

Static-fact classes with no V of their own: a lane that failed calibration (`blocked`, never a
row), a stale or re-hashed recorded inventory (`precedents/migration.md` § 24) and a `pair-map` row
without a reason (`precedents/migration.md` § 26). Each is a precondition the coverage block prints, not a finding.

### Harnesses (migration)

- **Differential replay** (V358, V361, V362, V366, V367):
  - Generate the corpus from the lanes: every live V1 route key from `paired-inventory`, each V1 FormRequest rule's boundaries, each error path in the contract.
  - Send it to both bases with the same seeded data, recording status, headers and body.
  - Compare with `behavior-diff.py` and a tolerance file whose every `ignore` path came from the V1-vs-V1 run.
  - Record replay (GoReplay's middleware, Keploy record and replay with downstream mocks) is optional; it is never the only proof of a write route. GoReplay OSS has been frozen since 1.3.3 (2021-10-06); Keploy 3.6.141 (2026-10-18) mocks downstreams, which also isolates effects.
  - oasdiff compares declared specs only; a lenient server passes it.
- **Permission matrix** (V359):
  - Take the cells from the I-AUTHZ lane: each role (anonymous, owner, non-owner, other tenant, suspended, API token, session), × each route of the feature, × HEAD and OPTIONS.
  - Generate one test per cell and run it on both sides.
  - The V1 ability table can come from spatie's `permission:show` (8.3.0), which reads the database, so run it on the restored copy. Without one, the matrix stays static.
- **Property with V1 as the model** (V360, V363–V365, V368):
  - fast-check 4.10.2: `fc.assert(fc.property(gen, async x => expect(norm(await v2(x))).toEqual(norm(await v1(x)))))`, with V1 called over HTTP or as a subprocess (`php -r`) of the snapshot.
  - Hypothesis 6.170.1: `@given(...)`; for stateful flows, `RuleBasedStateMachine` with V1 as the model.
  - Generators must hit the class boundaries in the variant list. Default strategies rarely reach `-2.5`, `0.285` or `İ`.
  - A property that never fails on the pre-fix V2 proves nothing.
- **Side-effect journal** (V371):
  - Point both sides' SMTP at Mailpit (v1.31.6; REST under `/api/v1/`) and their outbound HTTP at WireMock (3.13.2; `GET /__admin/requests`, `/__admin/requests/unmatched`).
  - Tap the queue: a recording consumer on a Testcontainers broker, or a snapshot of the outbox table.
  - Diff the audit and activity tables on business keys, `EXCEPT` both directions.
  - Normalise ids and times with identity-preserving tokens: the same input gives the same token.
  - A Laravel V1 inside its own test suite can capture with `Mail::fake()` / `Http::fake()` [K?: unmeasured here].
- **Seeded-drift reconciler** (V374, V375, V379, V385):
  - Copy a sample into scratch V1 and V2 stores.
  - Seed one row per drift class: a trailing space, case, sub-second, the last float digit, `''`/NULL, a zero date, `tinyint` 2, a NUL byte, double-encoded UTF-8.
  - Run the project's reconciler exactly as configured. Each class it does not report is a mask (`precedents/migration.md` § 15).
  - Tools: DVT 8.10.0 `data-validation validate row … --hash '*'` (RTRIM inside the hash; use `--comparison-fields` for exact values); pt-table-checksum for MySQL → MySQL only; Vitess VDiff; reladiff 0.6.0 (the archived `data-diff`, 2024-05-17, is not recommended).
- **Fault and flip drill** (V370, V374, V381, V382): run the backfill against a scratch copy, kill it at 50%, and resume. Run the flip under a write generator, then roll back after N V2 writes that include a new enum value and a new required field. Assert the counts on both stores.
- **Integrity gate** (V386–V388):
  - `test-integrity.py` on the port diff: `new-skip` and `undeclared-baseline-rewrite` rows fail it.
  - Run the V1-pinned test and golden set from the snapshot against V2.
  - Line coverage comes from the project's tool on both sides (FreshBrew used JaCoCo 0.8.9 for Java).
  - V1 branch coverage under the parity corpus comes from the V1 language's coverage driver. A PHP driver has not been measured here [K?].
  - Mutation testing on V1 (testing `mutation-probe` when installed: Stryker, PIT, mutmut) grades the corpus.
  - The CI log, as JUnit XML or the runner's summary, counts the executed V1-gated tests. A summary from the agent is not a log (`precedents/migration.md` § 20).

### Class variants (migration)

A fix passes the class only when every variant the pair has passes the oracle and the benign
control still agrees.

#### V358. Route, shape and silent-default parity — route-list replay (`surface-parity-scan` §1, §2, §9)
- every live V1 route × method, resource routes expanded per action; `Route::fallback` and catch-alls; HTML-form method spoofing (`_method=PUT`); HEAD and OPTIONS derived from GET
- trailing slash on and off; array query in both syntaxes (`a[]=1&a[]=2` and `a=1&a=2`); mixed-case paths; a lost param constraint (`whereNumber`); `page` 0, 1 and last+1; every optional param and body field omitted (page size, sort, currency, locale, boolean and ORM attribute defaults)
- pass: no V1 route 404s on V2; the status class, the default page size and sort and the omitted-field values agree, or each difference is an ADR row with `changes_baseline` (a dead V1 route with an ADR is the control, `precedents/migration.md` § 2)

#### V359. Guard parity — permission matrix (`surface-parity-scan` §3–§5; widening and tenant scope → security)
- each role including anonymous; owner vs non-owner; another tenant; a suspended user; API token vs session; HEAD and OPTIONS; class-level and global guards (`APP_GUARD` with `@Public()`); FormRequest `authorize()`; policies; global scopes and soft-delete scopes on read paths
- pass: V2 ⊆ V1 on every cell (no widening), V1 ⊆ V2 or an ADR (no undeclared narrowing), and the cross-tenant cell is refused on both sides (a guard moved to the gateway, read and cited, is the control)

#### V360. Vocabulary parity — enum round trip (`surface-parity-scan` §6)
- every V1 value through parse → store → serialise on V2, on the **wire**, **stored** and **label** forms separately; an unknown value from V1 consumers; integer-mapped Rails enums; ordinal JPA enums; MySQL `ENUM` `''` (the invalid-value index); `dto-types.py --routes` ENUM `member=value` against the V1 `case X = 'x'`
- pass: every V1 value round-trips unchanged, every V2-only value is tolerated by V1's consumers, and a label-only change is low (a V2-only value with tolerant consumers is the control)

#### V361. Rule parity — boundary corpus (`surface-parity-scan` §7; coercion in one codebase → V341)
- empty, whitespace-only, leading and trailing spaces (V1's global `TrimStrings`), `""` vs `null` (V1's `ConvertEmptyStringsToNull`), max ±1 in bytes **and** characters, multibyte, `null`, wrong type, an unknown key (`whitelist` / `forbidNonWhitelisted` vs `$request->validated()`), a duplicate under a unique rule including a soft-deleted row, `sometimes` vs `required`, date formats
- pass: accept/reject agrees **and** the stored value agrees per field; a global V1 pipe missing in V2 is one finding with N fields (`precedents/migration.md` § 27, § 29)

#### V362. Error parity — error corpus (`surface-parity-scan` §8; `parity-proof-scan` §3; envelope correctness → backend V345)
- every contract error path: validation (422 vs 400, all errors vs first, `errors.<field>` vs `message[]`), not-found (404 vs 200 `null`), conflict, auth (401 vs 403), throttling, a V1 bug that V2 "fixed"
- pass: status, `code` and field keys agree (message text tolerated), or the difference is an ADR plus `changes_baseline` and a "Known V1 bugs" row (`precedents/migration.md` § 3, § 31)

#### V363. Money parity — money property (`semantics-parity-scan` §1–§3; precision on the wire → V339)
- x.5 at each scale, positive and negative (PHP `round(-2.5)` −3 vs JS `Math.round(-2.5)` −2); `0.285` under PHP 8.4 vs earlier; `1.005` through `toFixed`; per-line vs per-total tax on many-line carts; allocation remainders (100.00 three ways); 1e15 + cents; ids above 2^53; MySQL DECIMAL vs DOUBLE and Postgres `round(numeric)` vs `round(double)` when the arithmetic moved into SQL
- pass: V2(x) == V1(x) exactly on every stored, charged or reported amount, and parts sum to the total (display-only rounding is the control, `precedents/migration.md` § 11, § 33)

#### V364. Integer parity — integer property (`semantics-parity-scan` §4)
- negative dividend and divisor; zero; Python `//` and `%` (floor) vs JS, Java and Go (truncate); PHP `intdiv` vs `/` (float); overflow bounds where V1 promoted to big integers
- pass: quotient and remainder agree on every sign combination, and overflow fails the same way

#### V365. String parity — string property (`semantics-parity-scan` §5)
- ASCII, Latin-1, combining marks (NFC vs NFD), emoji (surrogate pairs at a length limit), Turkish İ/ı, RTL, Arabic-Indic digits in numeric fields; `strlen` (bytes) vs `.length` (UTF-16 units); `strtolower` vs `toLowerCase`; regex flavour (`\d` Unicode vs ASCII, `$` before a trailing newline, lookbehind under RE2); `array_search` 0 vs `false`; `substr` with negative arguments; `explode` with a limit
- pass: length checks, case folds, slices, splits and matches agree on every input (an ASCII-only field by validated contract is the control)

#### V366. Order parity — order-sensitive list diff (`semantics-parity-scan` §6)
- data with ties on the sort key; mixed case under MySQL `_ci` vs Postgres deterministic collations; nulls first vs last; pagination across ties; a V1 query with no `ORDER BY` that relied on InnoDB PK order; `->first()` without an order
- pass: the full order agrees wherever a consumer depends on it, and pagination returns every row once (an order the contract declares unspecified with no consumer is the control, `precedents/migration.md` § 7)

#### V367. Presence parity — presence diff (`semantics-parity-scan` §7)
- an empty list, an empty map (`json_encode([])` gives `[]`), a non-sequential array after `unset`, a null relation, an absent optional, `"0"`, `false`, `0`, `12.0` vs `12`
- pass: each field renders with the same presence and shape on both sides, or every consumer is proven presence-tolerant

#### V368. Time parity — clock property (`semantics-parity-scan` §8; time binding in one codebase → V347)
- DST forward and back; end of month (`addMonth` on the 31st); Feb 29; server `TZ` ≠ UTC on either side; a non-UTC user zone; ISO week 53; `Carbon::parse` / `strtotime` leniency vs `new Date` / Day.js strict parsing; JS months 0-indexed
- pass: the same instant and the same calendar date on both sides at every point (UTC end to end on both is the control)

#### V369. Catalog parity — plural render (`semantics-parity-scan` §9 → frontend `i18n-scan`; `catalog-parity.py --v1` supplies the rows)
- each key × locale × count {0, 1, 2, 3, 11, 100}; Laravel pipe forms and `{0}` / `[1,19]` / `[20,*]` ranges vs CLDR categories (Arabic: zero one two few many other); `:name` vs `{{name}}`; a missing key (Laravel returns the key); the fallback locale; RTL
- pass: every count renders the form V1 rendered, or the form CLDR requires where V1 was wrong (an ADR row); placeholders match

#### V370. Transaction parity — crash and race probe (`semantics-parity-scan` §10 → database `transaction-scan`)
- a crash mid-write on a path V1 wrapped in a base-service `DB::transaction`; two concurrent writers on one row; a `lockForUpdate` dropped in the port; MySQL REPEATABLE READ → Postgres READ COMMITTED on a read-modify-write
- pass: no partial write and no lost update on V2 where V1 had none

#### V371. Effect parity — effect journal (`side-effect-parity-scan` §1, §2, §5; `cutover-routing-scan` §3)
- create, update, delete and restore per entity; bulk paths; queued vs sync; effects declared by observers, `$dispatchesEvents`, `booted()` closures, traits (`LogsActivity`, `Searchable`, `Notifiable`) and DB triggers, procedures, generated columns and cascades; shadow and dual-run modes
- pass: the (entity, verb) effect multiset is equal; in shadow mode the candidate emits **zero** external effects; no effect fires before commit where V1 waited for it (an effect moved to a V2 subscriber in another module, read and cited, is the control)

#### V372. Hidden consumers — consumer inventory (`side-effect-parity-scan` §3)
- every non-app DB user and grant; views; scheduled exports; report SQL; BI extracts; partner file drops; queries in other repositories against V1 table names; reads seen in `pg_stat_statements` or the general log over a window
- pass: each consumer maps to a V2 contract or a compatibility view, or has a dated retirement with its owner's sign-off

#### V373. Schedule parity — schedule equality (`side-effect-parity-scan` §4)
- each V1 `schedule:list` entry and queue consumer; cron expression, time zone, overlap guard (`withoutOverlapping`), one-server rule (`onOneServer`); a job moved to a k8s `CronJob`; BullMQ `repeat`; `@Cron` / `@Interval`
- pass: a V2 entry with the same expression, zone and overlap rule for every V1 entry, plus one dry run each on a snapshot

#### V374. Backfill safety — backfill kill-resume (`data-cutover-orchestrate` §1–§2)
- kill at 50% then resume; a double run; a live update between the snapshot and the backfill; a tail range that stalls; throttling under load
- pass: no duplicates, no gaps, no newer row overwritten (a version or `updated_at` guard on the upsert), and the run resumes from its checkpoint

#### V375. Reconciler strength — seeded drift (`data-cutover-orchestrate` §3, §6)
- a trailing space, case, sub-second, the last float digit, `''` vs NULL, a zero date, `tinyint(1)` holding 2, a NUL byte, double-encoded UTF-8, `_ci` duplicates, pgloader's default casts
- pass: the reconciler as configured reports every seeded row; each class it misses is listed as masked and Unconfirmed

#### V376. Mapper agreement — two-path equality (`data-cutover-orchestrate` §4, §12)
- one row through the backfill mapper and through the dual-write mapper; a mapping change after the checkpoint started
- pass: both rows are structurally equal, and a mid-window mapping change triggers a re-backfill of the affected ranges

#### V377. Old-id resolution (`data-cutover-orchestrate` §5)
- an old integer id in a URL, an API call, a webhook payload, an email link and payment-provider metadata, after an int → UUID change
- pass: every old form resolves (a unique `legacy_id` and a redirect or lookup)

#### V378. Soft-delete semantics — soft-delete probe (`data-cutover-orchestrate` §7)
- soft-deleted rows present in a list, a count, a unique check (V1's partial unique index) and an export; restore
- pass: V2 excludes them exactly where V1 did (soft-deleted rows filtered at backfill with a reason is the control)

#### V379. Load anomalies — pre-load anomaly counts (`data-cutover-orchestrate` §8)
- orphans per FK (`LEFT JOIN … WHERE parent.id IS NULL`); duplicates per natural key (`GROUP BY … HAVING count(*) > 1`, also under `lower()`)
- pass: each class is counted before load and has a recorded decision; nothing is dropped silently by `ON CONFLICT DO NOTHING`

#### V380. Sequence reset — first insert after load (`data-cutover-orchestrate` §9)
- every table loaded with explicit ids
- pass: the first V2 insert per table succeeds (`setval` / `RESTART` ran; pgloader resets by default, a hand-written COPY does not)

#### V381. Fenced flip — flip under load (`data-cutover-orchestrate` §10)
- the read flip gated on checkpoint-complete **and** reconcile-green; the write flip under write load with version-token fencing or a pool pause plus revoke
- pass: lost = 0 and duplicated = 0 across the flip

#### V382. Reversibility — rollback rehearsal (`data-cutover-orchestrate` §11; `cutover-routing-scan` §4)
- roll back after N V2 writes, including a new enum value and a new required column; V1 workers, caches and crons kept warm until the soak ends; the flag reversible in one step; the point of no return named and signed
- pass: V1 serves the V2-written rows after one flag change, and no V1 object is dropped in the release that flips writes

#### V383. Façade routing — façade route probe (`cutover-routing-scan` §1)
- each ledger route on the declared side; per method; prefix vs exact match; a sub-path under a migrated prefix that V2 does not serve
- pass: every probe lands on the declared side

#### V384. Session crossing (`cutover-routing-scan` §2)
- a V1 session used on V2 and the reverse; the cookie name, domain, path and `SameSite`; the session serialisation format; JWT keys and claims; the CSRF token source; logout on one side
- pass: identity carries across both halves on every route both serve during the window (`precedents/migration.md` § 19)

#### V385. Comparator blind spots — comparator self-check (`parity-proof-scan` §5)
- one seeded mismatch per tolerance key in the tolerance file; both sides raising different errors; a status-only comparison; a presence change under `structural`; an `ignore` wider than the V1-vs-V1 noise; a loosening committed without an ADR
- pass: `behavior-diff.py` reports every seed, and both-raise with different errors is a mismatch

#### V386. Tests kept — V1-pinned integrity (`parity-proof-scan` §1)
- the port diff against the V1-pinned set: edited tests, added `skip` / `xit` / `@Disabled` / `pytest.mark.skip` / `t.Skip`, re-recorded goldens (`-u`, `--update-snapshots`, `UPDATE_GOLDEN`), build-config excludes (a Surefire exclusion, a conditional skip on the runtime), removed assertions
- pass: the V1-pinned set runs unmodified against V2, `test-integrity.py` reports no `new-skip` or `undeclared-baseline-rewrite`, and line coverage drops ≤ 5 points (a test moved 1:1 with a mapping is the control)

#### V387. Corpus reach — V1 branch floor (`parity-proof-scan` §2)
- V1 branch coverage under the parity corpus; the unreached branches; surviving V1 mutants under the corpus
- pass: coverage meets the declared floor, every unreached branch is listed with a witness input or a reason, and an input count alone (halt 2's floor of 30) is never the floor

#### V388. Parity suites ran — V1-gated execution (`parity-proof-scan` §4 → testing `suite-execution-scan` §2c)
- each `v1` row of `gated-suites.tsv` (`HAS_V1 ? describe : describe.skip`, `process.env.V1_REPO_PATH`, `skipif(not os.environ…V1…)`); the CI job that runs the file and its `env:`; a second job that sets the variable for another suite (the decoy)
- pass: the CI run backing the parity claim executed k > 0 tests from every gated suite the claim rests on, with the variable set by that job; otherwise each dependent claim is `NOT-RUN` and the verdict is at most GO-UNVERIFIED (`precedents/migration.md` § 25)

### Sources (migration)

The migration research catalog (2026-10-18) gives § 5's oracle families and V358–V387. Its notes A
(parity-proof tooling and LLM-port evidence) give the tool rows: GitHub Scientist 1.6.5, Diffy (CC
BY-NC-ND 4.0, design reference only), GoReplay 1.3.3, Keploy 3.6.141, Mailpit 1.31.6, WireMock 3.13.2,
fast-check 4.10.2, Hypothesis 6.170.1 and oasdiff. They also give FreshBrew (arXiv 2510.04852;
JaCoCo 0.8.9, the 5-point gate) and MigrationBench (arXiv 2505.09569 v3). Its notes B (data
cutover, drift classes and upgrade tooling) give DVT 8.10.0, pt-table-checksum, AWS DMS validation,
Vitess VDiff, reladiff 0.6.0, pgloader's casts, the PHP, JS, MySQL and Postgres rounding and
ordering facts, the Laravel 12.x request, validation and localization docs, and NestJS validation.
The batch-6 migration eval (2026-10-18) § 4.3–§ 4.8 maps each V to its detector §. It adds V388
(PP-5: V1-gated suites, from the testing pack's measured `describeV1 = HAS_V1 ? describe :
describe.skip` shape) and appends the section after § Backend with no V reused. Rows tagged [K?] are
settled on the `port-pair` fixture before a detector asserts them. Paraphrased; no text reproduced.

## Align

An align claim says a live site does not follow a convention the project **declares**: a literal
where a token of the same value exists, a raw import where a wrapper exists, a name against a
declared case rule, a file outside the declared skeleton, a reasonless suppression of a convention
rule, a baseline that grew. An align fix says the rewrite applied that convention and changed
nothing else. Reading settles neither. The quoted rule may exist nowhere (AL-01). A token "match"
may belong to another property family. One pattern may be resolved two ways across files. An
over-edit, a snapshot update or a weakened assertion may ride inside the commit. So the oracles
here are deterministic, and they run cheapest first, the `find-and-align` ladder L0–L13. An LLM
judge is advisory: it can move a PASS to `pending-review`, never a FAIL to PASS. Every fix row
carries a **proof class**:
- **EQ**, exact equivalence: the value round-trips per theme within one property family, with exactly one semantic candidate; or the wrapper's defaults reproduce the raw call's props; or the literal equals an existing catalog value. Proven by a zero diff (V394 or V396).
- **VC**, visible change: a snap to the nearest token, or a wrapper with different defaults. Proven only by an approved visual diff (V407).
- **FN**, a functional verb that adds an owned idiom (`add-gate` with the declared `<Can>`). Proven by a behaviour test (V401).

Settled questions are in [`precedents/align.md`](precedents/align.md).

Users:
- the detectors `convention-oracle` (AL-01–04, `oracle-map.py`), `wrapper-adoption-scan` (AL-11, 13, 14, 15, 22), `naming-layout-scan` (AL-16–19, `name-check.py`) and `convention-ratchet-scan` (AL-29–32) (align pack), dispatched by `align-detect`;
- `/align-scan`, the read-only audit, which runs every candidate through `refute-before-report.md` § 10;
- `find-and-align` under `/align`, `/align-phase` and `/align-fast`, which runs the ladder per row, with `align-sweep-gate.py` (AL-33, AL-34) for the run-level gates.

**Owned elsewhere.** These classes keep their own sections, and align closes only their EQ rows:
- token drift and a re-implemented DS component → § Accessibility and UI states V141 (token conformance) and V142 (behavioural diff); V394, V396 and V397 prove align's swap of an EQ row;
- hard-coded copy and catalog defects → V132 and V133 (frontend `i18n-scan`); V405 is the EQ-key closure only;
- a suppression hiding a correctness diagnostic → § Code quality V84; a copy that diverged from the named helper → V85 (`/quality-fix`);
- layering and cycles → code-quality `architectural-diagnosis`, re-proved after an align re-route by V404;
- envelope, casing and pagination → § Backend (`edge-error-scan`, `api-consistency-audit`).

**Scope of use.** Scratch copies, the run folder (`$RUN`) and `${TMPDIR}` only. Eight rules hold for every variant below:

- **Never write into the audited repo.** Run project-local binaries only (`node_modules/.bin/eslint`, `ls-lint`, `sg`, `stylelint`, `depcruise`, `ruff`, `lint-imports`, `spectral`). Never `npx -y`, which fetches from the network and fills a `$HOME` cache. Run ESLint and stylelint without `--cache`, Ruff with `--no-cache`, and `tsc --noEmit --incremental false` (the default cache locations of Ruff and of incremental `tsc` are [K?] and are settled at build). Playwright writes to `--output=$RUN/pw`. Git reads use `GIT_OPTIONAL_LOCKS=0` from the first call. Print `find -newer <stamp>` on the audited root at the end; it must be empty.
- **Offline by default.** A missing binary prints the class `blocked (<tool> not installed)` and falls back to the static greps. `--online` opts in, and installs go only into `$RUN/tools`. Before any CLI, set the telemetry opt-outs: `DO_NOT_TRACK=1 CI=true` plus each tool's own variable (the Nx, Turbo, Storybook and Next names are [K?] until checked against each tool's docs). Never Omlet or Chromatic: their data leaves the machine.
- **Versions from lockfiles.** On ESLint ≥ 10 only flat config counts. On a TypeScript-7-only repo (no `@typescript/typescript6` alias), typed rules and ts-morph are `NOT RUN`, never zero. After an eslint-plugin-boundaries v7 or unicorn v65 bump, a count jump is a rebaseline (`precedents/align.md` § 3).
- **Rule first where expressible.** Write or extend a `no-restricted-imports` / `no-restricted-syntax` rule, or an ast-grep rule with `fix`. Give it BAD and GOOD tests (`RuleTester`, or `sg test`, which reports **Noisy** and **Missing**). Run it from the run folder on a 5–10% sample, read every diff, then sweep. The rule is committed only when the row's closure is "enable the rule".
- **Tests are read-only.** An align commit edits no test, snapshot, fixture or class lint config (V408). Agents tamper with the oracle when they can: in ImpossibleBench (arXiv 2510.20270), "modify the tests" was over 79% of one model's cheating, and read-only tests closed that path.
- **Same host for every before/after.** Playwright screenshot names carry the browser and OS, and its docs say to compare only in the environment that made the baseline. Fonts must be ready and transitions off.
- **Exclusions are root-relative.** X-lists match `-g` globs relative to each root, and scripts test `relpath`. An `rg` exit code 2 makes the class `blocked (rg exit 2)`. Generated pattern lists go through `-f` files of ≤ 300 alternations each (`precedents/align.md` § 20).
- **Licences.** Semgrep registry rules, Trail of Bits rules, Moderne-licensed OpenRewrite modules and the GPL-3.0 golangci-lint and depguard may be run by the user; none is vendored. Generate our own rules. Optic, Lost Pixel, `@storybook/test-runner`, i18next-parser and betterer are never proposed as new installs.

### Oracle taxonomy (align)

| Oracle | Kind | Asserts | V |
|---|---|---|---|
| **Quote and config resolution** | static | the cited oracle exists (a quote found by `rg -F`, a rule id at `error` in the resolved config) and the cited reason resolves | V389, V390, V406 |
| **Sweep gate** | diff | over `git diff -U0 <base>` and the ledger, `align-sweep-gate.py` re-detects, scopes, groups and checks names, rules and tests | V391, V392, V393, V398, V399, V408 |
| **Value equivalence** | value | the swapped value is identical before and after, per theme | V394, V396, V397 |
| **Whole-repo tool run** | tool | the class tool at `error` over the whole repo, not the touched files only | V395, V400, V402, V404 |
| **Behaviour test** | test | the site behaves as before, or as the idiom requires | V401, V403, V405 |
| **Recorded approval** | human | a visible change has a visual diff and a named approver | V407 |

| V | Oracle | Asserts | Ladder | Detector § |
|---|---|---|---|---|
| V389 | Oracle quote resolves | the quote is found in the cited file, or the rule id is at `error` in the resolved config of the site | L0 | `convention-oracle` §1 (AL-01, on every row) |
| V390 | Rule at error count | the T2 rule, run at `error` from a scratch config over its declared scope, counts the violations; CI lints that scope | — | `convention-oracle` §3 (AL-03); `convention-ratchet-scan` §3 (AL-31) |
| V391 | Re-detect zero | the ledger's `detector_cmd` returns 0 at ledger sites and 0 new sites in touched files | L5 | every align detector (V-00) |
| V392 | Hunk scope | every changed line is a ledger hit line ± the verb footprint; every hit line changed; no whitespace-only or AST-unchanged file | L3, L4 | `align-sweep-gate.py scope`, `diffkind` (AL-34) |
| V393 | One way per pattern | each normalised before-value maps to one after-value across the run | L6 | `align-sweep-gate.py consistency` (AL-33) |
| V394 | Computed-style zero diff | `getComputedStyle` of the changed elements is equal base vs head per route × theme | L10a | EQ token and wrapper rows (V-03a) |
| V395 | Ratchet shrink-only | per (file, rule) counts at head ≤ base for every baseline file; no rule downgraded | L11 | `convention-ratchet-scan` §2, §4 (AL-30, AL-32) |
| V396 | Compiled-CSS zero diff | base and head built and minified by one tool, `var()` resolved per theme, equal | L10a | EQ token rows without a browser harness |
| V397 | Value round-trip | the new token resolves to the old literal byte-for-byte after normalisation, per theme and family | L8 | EQ token rows (V-07, via ui-ux `token-map.py`) |
| V398 | Emitted names | every token, import path, export and prop the diff introduced exists in the declared set | L7 | `align-sweep-gate.py names` (V-08) |
| V399 | Non-vacuous | each class rule matched N > 0 files in scope, or a canary in a scratch copy turned it red | L13 | `align-sweep-gate.py vacuous` (V-09) |
| V400 | Import count to zero | the raw or banned import count outside the wrapper and its exempt files is 0 | L5, L9 | `wrapper-adoption-scan` §1, §5 (AL-11, AL-22) |
| V401 | Wrapper render / gate test | the site renders through the wrapper with the required prop; the gated action is absent for a role without the ability | L9 | `wrapper-adoption-scan` §4 (AL-15; AL-28 as an AL-15 form) |
| V402 | Rename with serialised names unchanged | the rename resolves every reference; types and build pass; no wire, DB, env or generated name changed | L9 | `naming-layout-scan` §1–§3 (AL-16, 17, 18) |
| V403 | Dedupe differential | the copy and the named helper agree on the copy's call-site inputs; after deletion nothing is orphaned | L9 | `wrapper-adoption-scan` §2 (AL-13) |
| V404 | Boundary whole-repo | the import resolves through the public entry; the repo's boundary tool is green on every module | L9 | `wrapper-adoption-scan` §3 (AL-14); `naming-layout-scan` §4 (AL-19); AL-20/21 re-routes |
| V405 | i18n EQ-key render | the replaced literal renders the same source-locale text, and the key resolves in every locale and under the pseudo-locale | L9 | AL-26 EQ-key rows (owner frontend `i18n-scan` §1) |
| V406 | Suppression reason resolves | the ADR or ticket id in the reason resolves; with the disable removed the rule fires, or the disable is stale | — | `convention-ratchet-scan` §1 (AL-29) |
| V407 | Visible-change approval | a visual diff per route × theme against a baseline from the pre-rewrite commit, with `approval: <name>@<iso>` in the ledger | L10b | VC rows (AL-06 snaps, wrappers with other defaults) |
| V408 | Test-count and coverage floor | no test, snapshot, fixture or class lint config in the diff; test-method count and coverage at head ≥ base | L3, L12 | `align-sweep-gate.py lock` (V-06, AL-34) |

Classes with no V of their own: AL-02 (a split) and AL-04 (a stale doc) are reports. They produce
`proposed canonical`, `undetermined` or `doc stale` lines and 0 ledger rows, so there is nothing to
prove failing first. A T2g rule is a precondition the coverage block prints: one ratification probe
per rule (`precedents/align.md` § 28).

### Harnesses (align)

- **Quote and config** (V389, V390, V406):
  - `rg -n -F -- "<quote>" <oracle file>` must return ≥ 1. A quote with no hit drops the row and counts it as `AL-01: k dropped`.
  - For a config oracle, run the project's own ESLint as `eslint --print-config <one file per package>`, compared with `oracle-map.py`'s static parse; a mismatch prints `static≠resolved`. How `--print-config` behaves on an ignored file is [K?].
  - V390 runs the rule at `error` from a scratch flat config under `$RUN`. An ESLint 10 config outside the repo resolving the repo's plugins by bare name is [K?]; the build settles it (for example with `createRequire(<repo>/package.json)`).
- **Sweep gate** (V391–V393, V398, V399, V408): `align-sweep-gate.py <scope|consistency|lock|diffkind|names|roundtrip|redetect|vacuous>` reads the ledger (the indented `- id:` form), `git diff -U0 <base>` and the run folder. It prints a TSV verdict per row and per run, exits 1 on any FAIL, and writes nothing outside `$RUN`.
  - `diffkind` rejects whitespace-only files (`git diff -w --ignore-blank-lines` empty) and AST-unchanged files (`difft --exit-code` when installed; its exit codes on 0.71 are [K?]; else a token-stream compare).
  - `names` uses `token-map.py --names`, package `exports` and the wrapper's prop types. For CSS, `stylelint-value-no-unknown-custom-properties` with `importFrom` the token file is the deterministic check when installed.
  - `vacuous` reads `matched N files` lines, or plants a canary in `mktemp -d` under `$TMPDIR`. dependency-cruiser and eslint-plugin-boundaries pass silently on patterns that match nothing.
- **Value equivalence** (V394, V396, V397):
  - V397 is static: `token-map.py --lookup <value> --family <f>` per theme, when the ui-ux pack is installed. Colour normalisation covers hex 3/4/6/8, `rgb()`, `hsl()`, named colours and `oklch()`. The oklch → sRGB precision is [K?]. raystack's migration (PR #757, 2026-04-30) accepted a value only at CIEDE2000 ΔE < 0.5 **and** a byte-identical 8-bit sRGB round trip. Without ui-ux, token rows are `N/A (owner pack ui-ux not installed)`.
  - V394: Playwright `page.evaluate` dumps the changed properties per route × theme, base vs head, on one host, after `document.fonts.ready`, with transitions off and colours canvas-normalised. `design-token-audit`'s `offToken` helper already normalises.
  - V396 is the no-browser path. With neither harness, V397 passing gives `[report-with-fix] (static EQ)`, and the runtime check stays Unconfirmed with its probe.
- **Visible change** (V407): Playwright `toHaveScreenshot` with `maxDiffPixels: 0`; the default `threshold` of 0.2 hides a 1-px snap. Take the baseline on the pre-rewrite commit and keep the diff images in `$RUN`. Never auto-approved, never under `--safe-only`.
- **Whole-repo tools** (V395, V400, V402, V404):
  - V395 ratchets: ESLint bulk suppressions (core since 9.24.0, 2025-04-04; `error` rules only; per file per rule; unpruned entries fail the run unless `--pass-on-unpruned-suppressions`), `eslint.seatbelt.tsv`, the dependency-cruiser known-violations file (`--baseline-mode shrink-only` on 18.6.0 is [K?]), the ArchUnit store, `package_todo.yml`, `.importlinter` `ignore_imports`, and the PHPStan, Psalm and detekt baselines. Where no history exists, the comparison base is a `--base-dir` copy.
  - V400 and V404 use `rank-source-files.py`'s per-app alias and workspace-`exports` resolution. They are not re-derived.
  - V402: `tsc --noEmit`, plus `oasdiff breaking base.yaml head.yaml` or a schema snapshot when an API sits near the rename.
- **Behaviour** (V401, V403, V405): a render test of the site, with the role that must not see a gated action. A differential test of copy vs helper on the copy's call-site inputs, then knip (or `dead-code-scan`) for orphans. A pseudo-locale render (`xx-XA`) of the route, with the key checked in every catalog by `catalog-parity.py`.

### Class variants (align)

A fix passes the class only when every variant the class takes in scope passes the oracle, and the
benign control (a decoy the precedents exempt) is untouched.

#### V389. Invented convention — oracle quote resolves (`convention-oracle` §1, AL-01)
- a row citing a doc line that does not exist; a quote paraphrased instead of copied; a rule id at `warn` cited as enforced; a quote found only inside `refine-enriched` markers (T2g, not T2); a rule from another package's config
- pass: every kept row's quote is found verbatim in its cited file, or its rule id is at `error` for that file; every other row is dropped and counted (a config-only rule with no prose is the control, `precedents/align.md` § 2)

#### V390. Declared but unenforced — rule at error count (`convention-oracle` §3, AL-03; `convention-ratchet-scan` §3, AL-31)
- the rule absent, `off`, or at `warn`; a package missing from every CI lint job (read with `rg --hidden`); a package config that does not spread the shared config; `extend-ignore` of a banned-api code; a stale `.eslintrc*` beside a flat config on ESLint ≥ 10
- pass: the rule is at `error` over the declared scope and CI lints it; the scratch count at `error` is recorded (a semantic rule no tool can express is the control: it is marked agent-checked, not unenforced)

#### V391. Partial sweep — re-detect zero (V-00, every detector)
- every carrier the class takes: AL-05 values in a ternary, `??` or `||` branch, in `cn()` / `clsx()` / `cva()` arguments and in template literals (the `web-dashboard` hex sat in a ternary and a `prop: '#hex'` match missed it); AL-11 named, default, namespace, aliased, re-export, dynamic `import()` and `require()`; AL-29 line, next-line, block and file-level disables
- pass: the exact `detector_cmd` returns 0 at ledger sites and 0 new sites in the touched files

#### V392. Out-of-scope edit — hunk scope (AL-34)
- churn in an untouched function; reordered imports; a formatting pass; a comment rewritten; a second hunk next to the hit line; an unchanged ledger hit line
- pass: every `-` line is a ledger hit ± the verb footprint (`replace-with-shared`: one import line; `rename`: the declaration plus the references the language server reported), every hit line changed, and no file is whitespace-only or AST-unchanged

#### V393. Inconsistent resolution — one way per pattern (AL-33)
- one literal to two tokens across files (`#d92d20` → `--color-danger` and `--color-error`); one value to two tokens of one family (`8px` → `--space-2` and `--gap-sm`); one raw prop to two wrapper props
- pass: each before-key has one after-value across the run, unless `token-map.py` declares the map context-keyed, and then only by role (text, background, border, graphic, shadow, padding, margin, gap)

#### V394. Exact swap — computed-style zero diff (EQ token and wrapper rows)
- every shipped theme (light, dark, high-contrast); hover, focus and disabled states of the changed element; a shorthand holding the value (`border`, `box-shadow`, gradient stops); logical properties
- pass: each changed property's computed value is equal, base vs head, per route × theme

#### V395. Ratchet regression — shrink-only (`convention-ratchet-scan` §2, §4; AL-30, AL-32)
- a count per (file, rule) that rose; a new known-violation entry; an `ignore_imports` line added; a rule downgraded in a static-parse diff; old-shape sites in files added after the migration ADR's date (counted double)
- pass: every count at head ≤ base and no rule loosened (a rebaseline in the same commit as a boundaries v7 or unicorn v65 bump, with an ADR line, is the control)

#### V396. Exact swap without a browser — compiled-CSS zero diff
- CSS modules, global CSS, Tailwind 4 `@theme` output, and CSS-in-JS extracted at build
- pass: minified base and head CSS are equal after per-theme `var()` resolution (a token whose value differs is AL-06, not a pass)

#### V397. Token value — round-trip (EQ token rows)
- hex 3/4/6/8, `rgb()` / `rgba()`, `hsl()`, `oklch()`, named colours; px vs rem; a token aliased through `{alias}` in DTCG; a value defined only under `[data-theme=dark]`
- pass: every pair round-trips in every theme and family; a cross-family or nearest-only pair is reclassified AL-06 (`precedents/align.md` § 27)

#### V398. Hallucinated name — emitted names
- a token that is not in the token source (`var(--color-dangerous)`); an import subpath not in `exports`; a prop the wrapper's types do not declare; a hook name not exported
- pass: every name the diff introduced exists in the declared set

#### V399. Vacuous rule — non-vacuous
- a boundaries element pattern that matches 0 files (`src/featurez/*`); an `.ls-lint.yml` directory key that loosens its subtree; a stylelint `ignoreFiles` glob that covers the scope
- pass: the rule matched N > 0 files, or the canary turned it red; otherwise the class is `NOT RUN`, not clean

#### V400. Raw or banned import — import count to zero (`wrapper-adoption-scan` §1, §5; AL-11, AL-22)
- each import form in V391; Vue `app.component(` global registration; Python `from x import y`, `import x` and the Ruff `TID251` lane; Go import blocks; .NET `using`
- pass: the count outside the wrapper, its stories, tests and adapters, and the integration layer is 0 (`precedents/align.md` § 8, § 12)

#### V401. Required or forbidden prop — render and gate test (`wrapper-adoption-scan` §4; AL-15)
- the prop omitted; the prop passed through `{...props}` (read the spread source); the Vue kebab form; a destructive action outside the declared `<Can>` gate
- pass: the render test shows the wrapper with the required prop, and the role without the ability does not see the action (High when a gate dropped)

#### V402. Naming — rename with serialised names unchanged (`naming-layout-scan` §1–§3; AL-16–18)
- a file and a directory (`git mv`, case-only renames on a case-insensitive file system); an exported symbol; a hook; a boolean prop; a route string and an i18n **key** against the glossary
- pass: references resolve, types and build pass, and no wire, DB, env or generated name changed (`precedents/align.md` § 15); framework-mandated names untouched (§ 13)

#### V403. Hand-rolled copy — dedupe differential (`wrapper-adoption-scan` §2; AL-13)
- the same name; a renamed copy; a copy with a gap; an inline lambda copy; a test-utils copy
- pass: copy and helper agree on the copy's call-site inputs, then the copy is deleted and nothing is orphaned; a disagreement reclassifies to code-quality (V85)

#### V404. Boundary — whole-repo run (`wrapper-adoption-scan` §3; `naming-layout-scan` §4; AL-14, AL-19, AL-20/21 re-routes)
- a deep path past `exports` (`@scope/pkg/src/internal/…`); a relative `../../packages/x/src/…`; a per-app tsconfig alias; a barrel re-export chain; a module catalog written with paths relative to its section heading in `ai/modules.md`
- pass: the import resolves through the public entry, and the repo's boundary tool is green on every module

#### V405. i18n literal — EQ-key render (AL-26 EQ rows)
- JSX text; `placeholder`, `title`, `aria-label` and `alt`; a constant-prefix template key; a namespace other than the one the convention names
- pass: the source-locale render is the same text, the key resolves in every shipped catalog, and nothing un-transformed shows under the pseudo-locale (new copy is the owner's, `precedents/align.md` § 31)

#### V406. Suppression — reason resolves (`convention-ratchet-scan` §1; AL-29)
- a line, next-line, block and file-level disable of a convention rule; `# noqa: TID251`; `// nolint`; `ast-grep-ignore`; the same reason on more than 5 disables of one rule
- pass: the ADR or ticket id resolves, or the disable is removed and the site fixed; a reasonless or boilerplate cluster stays a row (`precedents/align.md` § 3, § 26)

#### V407. Visible change — recorded approval (VC rows)
- a snap to the nearest token; a wrapper whose defaults differ from the raw call's props; every route × theme that renders the site
- pass: the visual diff exists from a pre-rewrite baseline, and the ledger row carries `approval: <name>@<iso>`; without it the row stops at `pending-approval`

#### V408. Oracle tampering — test-count and coverage floor (V-06, AL-34)
- a snapshot updated in the align commit; a weakened or removed assertion; an added skip; a lint config change for the class's rule; a test file excluded from collection
- pass: no such path is in the diff; test-method count and coverage at head ≥ base, and a coverage drop above 5 points is a hard fail (FreshBrew, arXiv 2510.04852)

### Sources (align)

The align research catalog (2026-10-18) gives the 34 classes, § 5's run-level gates V-00…V-09 and
the per-class variants. Its tool notes give: ESLint 10.13.0 and 10.0.0's removal of eslintrc
(2026-02-06); TypeScript 7.0 (2026-07-08) with no programmatic API; ESLint bulk suppressions
(9.24.0, 2025-04-04); ast-grep 0.51.0 (`sg test` Noisy / Missing); dependency-cruiser 18.6.0;
eslint-plugin-boundaries 7.2.0; unicorn 78.0.0; `stylelint-value-no-unknown-custom-properties`
6.1.1; Playwright 1.64.1 (default threshold 0.2; compare on one environment); difftastic 0.71.0;
oasdiff 1.33.0; knip 6.41.0; and the licence notes. Its evidence notes give raystack/apsara PR #757
(2026-04-30), FreshBrew (arXiv 2510.04852), ImpossibleBench (arXiv 2510.20270) and the Spotify,
Google and Airbnb sweep practices. The batch-6 align eval (2026-10-18) § 3.2–§ 3.4 gives the
EQ/VC/FN split, the L0–L13 ladder and the tool-lane rules, and § 4.11 assigns V389–V408 after
§ Migration with no V reused. Rows tagged [K?] are settled on the `convention-drift` fixture before
a detector asserts them. Paraphrased; no text reproduced.

## Product

A product claim says a shipped feature is half-built, unjudgeable or inconsistent with what was
promised: a client call to a route nobody serves, a link to a page that does not exist, fake rows on
a reachable route, a control that does nothing, an analytics event that is missing from its plan or
fires before its outcome, a plan limit that the pricing copy and the gate state differently, a
launch with no typed success definition or no live metric, an acceptance criterion no test names.
Reading one side settles none of these. Each class is a **join** of two inventories (served routes
× references, plan × call sites, catalog × gates × pricing copy, rule × evidence, criterion ids ×
tests), and the oracle runs the join or the behaviour, failing first. Every oracle names a
**family**:
- **S**: a static fact with both ends cited, the reference line and the counterpart line (or "none
  after the written search").
- **T**: a tool exit recorded in this run: `surface-map.py`, `event-inventory.py --plan`,
  `readiness-score.py --rule`, `ears-lint.py`, `trace-matrix.py`, a Gherkin dry run, `tsc` over a
  typed route, event or key union.
- **U**: a unit or integration test that fails first: a route-parity test, a render test, a
  fake-sink analytics test, a catalog-driven gate matrix.
- **L**: a live probe: a request returns 404, a browser visit lands on the not-found boundary, an
  analytics query returns rows, NO-DATA or STALE.

Settled questions are in [`precedents/product.md`](precedents/product.md). This section is
self-contained: its V-numbers (V409–V429) are cited by the product detectors and by `/product-fix`
only, and no V outside this range is reused for a product class.

Users:
- the detectors `feature-surface-scan` (FS §1–§5, `surface-map.py`), `tracking-plan-scan`
  (AN §1–§7, `event-inventory.py`), `entitlement-consistency-scan` (EN §1–§6), `launch-readiness`
  (LR and the scorecard SC, `rules.json` + `readiness-score.py`) and `acceptance-criteria-check`
  (TR §1–§4) (product pack);
- `/audit-requirements --repo`, which runs them, with `@verifier` mode `refute` on every BLOCKER and
  HIGH it keeps;
- `/product-fix`, which writes each finding's failing-first test from its V-number.

**Owned elsewhere.** These classes keep their own sections; product cites them as scorecard
evidence and never re-proves them:
- stale, dead and unsafe-default flags and kill switches → § DevOps (`progressive-delivery`);
- error, empty, loading and permission states → § Accessibility and UI states (`ui-state-scan`);
- hard-coded copy, missing keys and catalog parity → § Accessibility and UI states (i18n, V132, V133);
- SLO definitions, burn alerts, alert runbook links and readiness truthfulness → § Observability;
- spec ↔ implementation drift of a generated API client → § Backend (`http-contract-scan` §10);
- PII in event properties, tracking before consent, server-side entitlement enforcement and
  limit-counter races → security, proven with [`exploit-payloads.md`](exploit-payloads.md);
- money, rounding, tax and proration → the business pack's own oracles.

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Seven rules hold for every
variant below:

- **Never write into the audited repo** outside the fix's own test and source files. Scripts write
  under `--out` (default `${TMPDIR}`) and refuse an `--out` inside the repo. Print `find -newer
  <stamp>` on the audited root at the end of an audit; it must be empty.
- **The project's own control is the first oracle.** A two-sided route-parity test, typed routes
  (Next `typedRoutes`, React Router typegen), an OpenAPI-generated client under `tsc`, a codegen
  tracking plan (Ampli, Avo) or a typed event union, a gate key typed as the catalog union. Run it
  before writing a new one; when it already covers the class, the class prints `controlled
  (<control>)` and the fix extends the control instead of adding a second one
  (`precedents/product.md` § 7).
- **Offline, installed binaries only, telemetry off.** Never `npx -y` or a global install. Set
  `DO_NOT_TRACK=1 CI=true NEXT_TELEMETRY_DISABLED=1` before any CLI. A vendor CLI that needs a login
  or an API key (Ampli, Avo, Segment, Stripe) is `NOT-RUN (auth)`; `ampli status` never runs with
  `-u` in an audit (it uploads status).
- **Dry runs are parsed, never trusted by exit code.** `cucumber-js --dry-run` exits 0 with undefined
  steps (13.3.0 docs, 2026-10-05): parse `usage-json`. `behave --dry-run -f steps.missing` lists
  undefined steps in its output.
- **Dynamic names are unresolved, never mismatches.** An event name, route or gate key built at run
  time prints `unresolved (k sites)`; no variant below is proven against it.
- **A rule that did not run is NOT-RUN, a rule outside the repo is UNVERIFIED.** No PASS from a
  file's existence for load-test results, restore drills, on-call or rollback drills
  (`precedents/product.md` § 23).
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix code for the
  stated reason, passes after, and the benign control (a decoy the precedents exempt: a webhook route,
  an intent event, a grandfathered plan) is unchanged.

### Oracle taxonomy (product)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Inventory join** | S, T, U | every reference resolves to a counterpart after normalisation (params, global prefix, version, base URL), and every counterpart has a reference or a reason | V409, V410, V413, V419, V427 |
| **Absence render** | U, L | the shipped surface renders no placeholder copy, no fixture rows and no no-op control | V411, V412 |
| **Fake sink** | U | the analytics sink receives exactly the specified events, at the outcome, once per specified trigger | V415, V416 |
| **Compile-time union** | T | a name, key or route outside the declared union fails `tsc` / the codegen check | V414, V417 |
| **Two-ended fact** | S, U | two sources of one plan fact hold one value; a plan added to the catalog changes access only through the catalog | V418, V420, V421 |
| **Typed record** | T | `readiness-score.py` reads the field typed (future date, named person, number with unit, no placeholder) and the cited evidence exists | V422, V423, V424, V425, V426 |
| **Spec trace** | T | criterion ids, Gherkin steps and EARS shapes resolve mechanically | V427, V428, V429 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V409 | Route-parity join | every client call (method, normalised path) has a served route after prefix resolution; every served route has a caller or a reasons-file line | S, U, L | `feature-surface-scan` §1, §2 (PR-FS-1, PR-FS-2) |
| V410 | Page-route table | every link, form action, redirect and `navigate()` target resolves to a page route or a server-handled path | S, U, L | `feature-surface-scan` §3 (PR-FS-3) |
| V411 | Placeholder absence | the reachable route renders data from the store and no placeholder copy, 501 or fixture row | U, L | `feature-surface-scan` §4 (PR-FS-4) |
| V412 | Interaction effect | each control's activation produces an observable effect (request, navigation, state change) | U, L | `feature-surface-scan` §5 (PR-FS-5) |
| V413 | Plan diff | `event-inventory.py --plan=<plan>` exits 0: no unplanned event, no planned event unfired, no required property missing | T | `tracking-plan-scan` §1, §2, §4 (PR-AN-1, PR-AN-2, PR-AN-4) |
| V414 | Name cluster | after case, separator and tense normalisation each cluster holds one spelling, or the plan declares the variants distinct | T | `tracking-plan-scan` §3 (PR-AN-3) |
| V415 | Outcome firing | with a fake sink, a failed write emits 0 outcome events and a confirmed write emits exactly 1 | U | `tracking-plan-scan` §5 (PR-AN-5) |
| V416 | Firing count | with a fake sink, one trigger emits the specified count under StrictMode, re-render, re-open and client + server legs | U | `tracking-plan-scan` §6 (PR-AN-6) |
| V417 | Typed event channel | the tracking entry point accepts only the declared names and property types; a misspelt name fails `tsc` or the codegen check | T | `tracking-plan-scan` §7, §4 literal types (PR-AN-7) |
| V418 | Two-ended plan fact | for every plan × feature, the pricing copy, the billing config and the entitlement source hold one value | S, U | `entitlement-consistency-scan` §1 (PR-EN-1) |
| V419 | Catalog-driven gate matrix | for every plan × catalog key, the server gate and the UI gate return the catalog's decision, and every gate key is a catalog key | U | `entitlement-consistency-scan` §2, §4, §5 (PR-EN-2, PR-EN-4, PR-EN-5) |
| V420 | Plan-name independence | adding a plan to the catalog with an entitlement grants it through the catalog; no feature check names a plan | U | `entitlement-consistency-scan` §3 (PR-EN-3) |
| V421 | Billing wiring | runtime source resolves prices by `lookup_key` or per-mode config; the entitlement sync pages past the summary's 10 items and revokes | S, U, L | `entitlement-consistency-scan` §6 (PR-EN-6) |
| V422 | Typed success fields | `readiness-score.py --rule=PRR-LR-1` (and PRR-LR-5, PRR-LR-6) exits 0: metric, counter-metric, baseline with a date, threshold, named owner, future review date, decided fatal assumptions | T | `launch-readiness` (PR-LR-1, PR-LR-5, PR-LR-6) |
| V423 | Metric live | the metric's events are fired (AN §2 quiet for them) and, where a query lane exists, the query returns rows inside the freshness window: NO-DATA and STALE are FAIL | T, L | `launch-readiness` PRR-AN-2 (PR-LR-2) |
| V424 | Rollback record | the success file holds a rollback record (environment, ISO time, result) and lists every irreversible emission, or `none` | T | `launch-readiness` PRR-RB-1 (PR-LR-4) |
| V425 | Scorecard level | `readiness-score.py` exits 0 at the target level: every rule at or below it PASS or N/A with a reason, every ledger row citing an existing, fresh report | T | `launch-readiness` (PR-SC-1) |
| V426 | Owner coverage | a CODEOWNERS or catalog owner entry covers every path of the feature, and is not bot-only | T | `launch-readiness` PRR-OWN-1 (PR-SC-2) |
| V427 | Id-anchored trace | every criterion id appears in a test that asserts it; every id a test cites exists in a spec | T, U | `acceptance-criteria-check` §1, §2 (PR-TR-1, PR-TR-2) |
| V428 | Gherkin glue | the dry-run usage output lists 0 undefined and 0 ambiguous steps and 0 unused step definitions outside tagged-out features | T | `acceptance-criteria-check` §3 (PR-TR-3) |
| V429 | EARS shape | `ears-lint.py <requirements.md>` exits 0 for run-ledger specs; a prose spec passes the four manual tests (falsifiable, observable, bounded, singular) | T | `acceptance-criteria-check` §4 (PR-TR-4) |

### Harnesses (product)

- **Route and page joins** (V409, V410): when the project has a route-parity test, extend it; else
  generate one from `surface-map.py`'s two tables (served routes; references) under the project's
  test runner, asserting each reference resolves and each uncalled route is in a reasons file
  (`<method> <path> — <reason>`). The live tier sends each unserved call to a running non-production
  build and expects 404 or 405 before the fix. Page targets: a route-table test over the router
  config (React Router objects or JSX, file routes) or a Playwright visit that must not land on the
  not-found boundary.
- **Absence render and interaction** (V411, V412): a render test of the reachable route with the
  store or API stubbed at its client edge, asserting the fixture rows and the placeholder copy are
  absent and the data comes from the stub; a catalog value is checked in every shipped locale. An
  interaction test (Testing Library `user-event`, Playwright) clicks each control and asserts one
  observable effect.
- **Plan diff and names** (V413, V414): `python3 -I event-inventory.py --plan=<plan>` (tracking-plan-scan
  pack script) writes the inventory and the diff under `${TMPDIR}`; exit 2 is the failing state.
  Where a codegen plan is installed, its offline status check is the stronger oracle (Ampli `ampli
  status` without `-u`; `avo status` after `avo pull`) and is `NOT-RUN (auth)` without credentials.
- **Fake sink** (V415, V416): replace the analytics client at its module edge with a recorder; drive
  the real component or handler; assert the recorded events per trigger. Variants run the failure
  path (the write rejects), StrictMode double effects, a re-render, a dialog opened twice, and both
  the client and the server leg with and without a shared `event_id`.
- **Compile-time unions** (V417, and the T tier of V409/V410/V419): type the event name, the route
  and the gate key as the declared union; a scratch file with one wrong literal must fail `tsc
  --noEmit --incremental false`.
- **Catalog matrix** (V418–V420): one parametrised test over the catalog's plans × keys, calling the
  real server gate (guard, policy, middleware) and the UI gate with a user on each plan; the pricing
  source and the billing config are loaded from their files and compared per plan × feature. EN §6
  live checks (Stripe CLI trigger with more than 10 features) need a test key and are `NOT-RUN
  (auth)` without one.
- **Typed records** (V422–V426): `python3 -I readiness-score.py --repo=<repo> --feature=<slug>
  [--evidence=<tsv>] --rule=<id>`; exit 2 is the failing state, 0 the closed one. Its `--self-test`
  covers every LR/SC variant below. The script evaluates `file` and `doc-field` rules itself and
  accepts `ledger`, `tool` and `runtime` results only from the evidence TSV written in this run.
- **Spec trace** (V427–V429): the id join is `rg -o` over the spec roots and the test globs
  (acceptance-criteria-check pre-flight); inside a delivery run, `python3 -I
  .claude/scripts/trace-matrix.py <run_id>` instead. Gherkin: `npx --no-install cucumber-js
  --dry-run --format usage-json:${TMPDIR}/usage.json`, `behave --dry-run -f steps.usage` and `-f
  steps.missing`. EARS: `python3 -I .claude/scripts/ears-lint.py <requirements.md>`.

### Class variants (product)

A fix passes the class only when every variant the class takes in the stacks present passes the
oracle, and the benign control is untouched.

#### V409. Unserved call / uncalled route — route-parity join (`feature-surface-scan` §1, §2)
- a literal path; a template path with params (`/orders/${id}`); a wrapper call without a leading slash (`http.get('stores')`); a method mismatch (served for GET, called with POST); a global prefix or version missing on one side; a trailing slash; a tRPC procedure renamed; the permissions or entitlement fetch whose failure path fails open; for the reverse half, a route under a controller prefix, a nested router mount, Rails `resources` expansion and a Django `include()` prefix
- pass: every call resolves and every uncalled route is called or listed with a reason (a webhook route and a documented public route are the control, `precedents/product.md` § 1)

#### V410. Link to a missing page — page-route table (`feature-surface-scan` §3)
- `<Link to>`; `href`; `navigate()`; `router.push`; `redirect()`; `<form action>`; a route-constant map; a dynamic segment (`/orders/:id`)
- pass: every target resolves to a page route or a server-handled path (`/logout`, a download: `precedents/product.md` § 8)

#### V411. Shipped placeholder — absence render (`feature-surface-scan` §4)
- a catalog value; inline JSX text; template text; 501 / NotImplemented on a mounted route; mock rows in a handler, a hook and a service; a mock module import (`@faker-js/faker`, an ungated `msw` `worker.start()`, `__mocks__/`); `USE_MOCKS=true`
- pass: none renders or returns on the reachable route in a production build (a demo build that the production bundle excludes is the control, `precedents/product.md` § 5)

#### V412. Dead affordance — interaction effect (`feature-surface-scan` §5)
- `onClick={() => {}}`; `onSubmit={() => undefined}`; `href="#"` with no handler; a literal `disabled`; Flutter `onPressed: null` as a constant; Vue `@click=""`
- pass: each control produces one observable effect (a no-op submit beside a confirming footer button is the control, `precedents/product.md` § 3)

#### V413. Plan drift — plan diff (`tracking-plan-scan` §1, §2, §4)
- an SDK call; a wrapper call; a generated-function call; a direct SDK call bypassing codegen; a server-side SDK call; a plan filtered by source; a missing required key; an extra key; a nested object key; a `/define-success` metric event
- pass: `event-inventory.py --plan` exits 0 (auto-tracked page views are the control, `precedents/product.md` § 10)

#### V414. Name drift — name cluster (`tracking-plan-scan` §3)
- case (`SignUp` vs `signup`); separator (`signup_completed` vs `Signup Completed`); tense (`Complete` vs `Completed`)
- pass: one spelling per cluster (two declared-distinct events are the control, `precedents/product.md` § 12)

#### V415. Fires before the outcome — fake sink (`tracking-plan-scan` §5)
- `onClick`; before the `await` of the write; in both `then` and `catch`; a `useEffect` on submit state; server-side before commit; a revenue conversion with `value` sent to an ad platform on checkout creation
- pass: a failed write emits 0 outcome events, a confirmed one exactly 1 (a `…Started` event on click is the control, `precedents/product.md` § 14)

#### V416. Duplicate firing — fake sink count (`tracking-plan-scan` §6)
- effect dependencies on an unstable callback; an impression in the render body; a StrictMode double effect; client and server legs without a shared event id
- pass: the specified count per trigger (once per open, repeated across two opens, is the control, `precedents/product.md` § 15)

#### V417. Untyped channel — compile-time union (`tracking-plan-scan` §7)
- a wrapper typed `name: string`; properties typed `Record<string, unknown>`; a direct SDK call beside the typed wrapper
- pass: a misspelt name and a wrong property type each fail `tsc` or the codegen check

#### V418. One plan fact, two values — two-ended fact (`entitlement-consistency-scan` §1)
- a limit (seats, projects); a price; an included feature; "unlimited" vs a cap; per-locale pricing copy
- pass: one value per plan × feature across every source (a grandfathered plan and a documented fair-use cap are the control, `precedents/product.md` § 20)

#### V419. Gate key outside the catalog, or entitlement with no gate — catalog matrix (`entitlement-consistency-scan` §2, §4, §5)
- a typo failing open; a typo failing closed; a key from another key family under split guards; a catalog key with no gate; a gate only in the UI; a gate on one of the two routes serving the feature
- pass: every cell returns the catalog's decision on the server and in the UI (split guards admitting each other's keys are the control, `precedents/product.md` § 18)

#### V420. Plan name in a feature check — plan-name independence (`entitlement-consistency-scan` §3)
- `===`; `in [...]`; `switch (plan)`; Python, Ruby, Go and Dart forms; an enum member (`Plan.pro`)
- pass: a plan added to the catalog gets access through the catalog alone (a literal inside the central plan map, a migration or a seed is the control, `precedents/product.md` § 19)

#### V421. Billing wiring — per-mode resolution and sync (`entitlement-consistency-scan` §6)
- a `price_…` / `prod_…` literal in checkout code; a summary-webhook handler with no paging; a sync with no revoke path
- pass: ids resolve per mode, and the sync handles more than 10 entitlements and a removal (ids in seeds and tests are the control, `precedents/product.md` § 21)

#### V422. Success definition incomplete — typed success fields (`launch-readiness` PRR-LR-1, PRR-LR-5, PRR-LR-6)
- a field missing; a field holding the template placeholder; a review date in the past; an owner named as a group or a team handle; a baseline with no date; a threshold with no number; a fatal × high assumption past expiry with no decision
- pass: `readiness-score.py --rule=<id>` exits 0 for each rule (a rule N/A with a stated reason is the control, `precedents/product.md` § 24)

#### V423. Metric not live — static and runtime (`launch-readiness` PRR-AN-2)
- the metric's event never fired; the counter-metric's event never fired; the query returns NO-DATA; the newest row is older than the freshness window (STALE); no query access (UNVERIFIED, never PASS)
- pass: AN §2 quiet for the metric events, and a recorded query run (timestamp, row count) where a query lane exists

#### V424. Rollback unexercised — rollback record (`launch-readiness` PRR-RB-1)
- no record; a record with no environment, time or result; a template record; emissions not listed
- pass: the record is typed and the emissions are listed or `none` (the drill itself stays external, `precedents/product.md` § 23)

#### V425. Scorecard below target — scorecard level (`launch-readiness`, PR-SC-1)
- a FAIL at the target level; an UNVERIFIED rule counted as PASS; a ledger row citing a missing or stale report; a tool row with no exit code; a rule removed from the table; N/A with no reason; a beta graded against gold
- pass: every rule at or below the stage's target is PASS or N/A with a reason, and the verdict is READY (`precedents/product.md` § 25, § 28, § 29)

#### V426. Ownerless feature — owner coverage (`launch-readiness` PRR-OWN-1, PR-SC-2)
- no CODEOWNERS; a CODEOWNERS under `.github/` or `.gitlab/` (dot-directories a shell `**` does not enter); a pattern that misses one of the feature's paths; a `*` rule naming a bot only; `catalog-info.yaml` with no `spec.owner`
- pass: every feature path is covered by a human or team owner

#### V427. Untested or stale criterion — id-anchored trace (`acceptance-criteria-check` §1, §2)
- an id in a test title; an id in a tag (`@AC-12`, Playwright `tag`); an id in a comment only; an id prefix from an external tracker; a spec id format the project defines (`FR-012`, `REQ-7`)
- pass: every criterion id is in a test that asserts it, and every id a test cites exists in a spec (a tracker-prefixed id resolved by prefix is the control, `precedents/product.md` § 35)

#### V428. Gherkin glue — dry-run usage (`acceptance-criteria-check` §3)
- an undefined step; an unused step definition; an ambiguous step; a step used only under a tagged-out feature
- pass: the parsed usage output lists 0 undefined, 0 ambiguous and 0 unused outside tagged-out features (`precedents/product.md` § 32)

#### V429. Unverifiable criterion — EARS shape (`acceptance-criteria-check` §4)
- no EARS keyword; a vague word in the SHALL clause; a story with no IF-THEN criterion; a compound criterion; a numeric bound with no unit, percentile, measurement point or load condition
- pass: `ears-lint.py` exits 0 on a run-ledger spec; every prose criterion names its refuting observation (a bounded adjective is the control, `precedents/product.md` § 33)

### Sources (product)

The product research catalog (2026-10-19) `precedents/product.md` § 1–5 gives the classes, tools, techniques, precedents and
the per-class variants above; its notes give the cucumber-js 13.3.0 dry-run behaviour (2026-10-05),
behave 1.3.3 formatters (2025-09-04), Ampli 1.36.6 and Avo 3.7.0 CLI behaviour and telemetry, Stripe's
entitlement summary limit of 10 (docs read 2026-10-19), Next `typedRoutes` (docs 2026-08-25), React
Router typegen (v8.4.0) and openapi-typescript 7.13.0. The batch-7 product eval (2026-10-19) `precedents/product.md` § 3–4
gives the joins, the scorecard schema and the 21 v1 rules; the integrator assigned V409–V429.
Paraphrased; no text reproduced.

## Documentation

A documentation claim says a human doc does not tell the reader the truth, or cannot be followed: it
names a path, symbol, script, flag, env var, endpoint or k8s resource the repo no longer has; it
states a version, default, package manager or method the code contradicts; a link or anchor goes
nowhere; a sample does not compile or prints something else; a setup step fails in a clean
container; the ADR graph, the changelog grammar, a translation or the site nav has rotted; or the
docs gate that should catch all this cannot fail. Reading one side settles none of these. Each class
is a **two-ended fact** (the doc line and the oracle line) or an **execution** (the project's own
toolchain in a scratch copy), and every fix is closed by the same resolution failing before and
passing after, then by the whole class re-scanned for that root cause at zero. Every oracle names a
**family**:
- **S**: a static fact with both ends cited, re-resolved by `doc-claims.py --recheck=<id>` (the
  candidate still exists) and `--claim=<value>` (every doc naming that value).
- **T**: a tool exit recorded in this run, read through the tool's own exit map
  ([`precedents/documentation.md`](precedents/documentation.md) § 32): lychee, markdownlint-cli2,
  rumdl, `kacl-cli`, oasdiff, Redocly or Spectral, TypeDoc, pydoclint, `mkdocs build --strict`,
  `sphinx-build -W`.
- **X**: an execution in a scratch copy: a clean container for the setup, the project's compiler or
  doctest runner for a fence.
- **M**: a mutation proof: a defect planted in a `$TMPDIR` copy turns the gate red.

Settled questions are in [`precedents/documentation.md`](precedents/documentation.md). This section
is self-contained: its V-numbers (V430–V449) are cited by the documentation detectors and by
`/doc-refresh` only, and no V outside this range is reused for a documentation class.

Users:
- the detectors `doc-drift-scan` (§1–§14, docs against code and config; engine
  `doc-drift-scan/scripts/doc-claims.py`), `doc-structure-scan` (§1–§14, docs against docs) and
  `doc-sample-scan` (§1–§5, samples and spec examples), plus `quickstart-verify` (DS-1),
  `docstring-coverage` (DD-1/2/3) and `diagram-sync` (DF-3) (documentation pack);
- `/doc-refresh`, which runs them and closes their findings failing first, editing docs only unless
  the doc is the contract (`precedents/documentation.md` § 16).

**Owned elsewhere.** These classes keep their own sections; documentation cites them as
corroboration and never re-proves them:
- the committed spec against code or runtime → § Backend (`http-contract-scan` §10);
- `.env.example` against the env schema → § Backend (`env-diff`);
- the changelog version against the released version → § DevOps (`release-integrity-scan` RL-2);
- an alert with no `runbook_url` → § Observability (`alert-rule-lint`);
- accepted ADRs and convention docs against code → § Align (`convention-oracle` AL-03/04);
- dead references inside agent-facing knowledge (`ai/`, `CLAUDE.md`, `AGENTS.md`) → the learning
  pack's own section.

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Seven rules hold for every
variant below:

- **Never write into the audited repo.** `doc-claims.py` refuses an `--out` or `--fences` inside the
  repo (exit 2). Execution lanes run in `git archive HEAD | tar -x -C "$TMPDIR/…"` or a detached
  worktree under `$TMPDIR`, with `GIT_OPTIONAL_LOCKS=0`. Print `find -newer <stamp>` on the audited
  root at the end; it must be empty.
- **Offline, pinned, telemetry off.** Installed binaries only (`node_modules/.bin`, the project's
  venv), never `npx -y` or a global install. Set `CI=true DO_NOT_TRACK=1` plus
  `REDOCLY_TELEMETRY=off`, `NEXT_TELEMETRY_DISABLED=1` and the other opt-outs before any CLI. The
  AsyncAPI CLI reports usage unless `CI=true`; Runme's telemetry is unverified, so it is not a lane.
  External links (DL-3) run only under `--network`.
- **Exit codes are mapped per tool** (`precedents/documentation.md` § 32). lychee exits 2 on broken
  links and 1 on its own error, the reverse of markdownlint-cli2, rumdl, Vale and Schemathesis;
  `kacl-cli verify` exits with the error count. A gate that cannot fail (`remark` without `--frail`,
  `oasdiff breaking` without `--fail-on ERR`, `openapi-diff` without `--fail-on-incompatible`,
  TypeDoc without `treatValidationWarningsAsErrors`, Docusaurus `onBrokenAnchors: warn`) proves
  nothing until V432 turns it red.
- **NOT-RUN is never PASS.** pytest exit 5 (nothing collected), `--doctest-glob='*.md'` over fences
  with no `>>>` (0 tests), a Spectral run with no ruleset, a container lane with no daemon: the
  variant is `blocked`, never green.
- **Both ends after the fix.** A fix that edits the doc re-resolves the new claim (it must resolve);
  a fix that restores the code re-runs the recheck (the candidate must be gone). Whichever end
  moved, `doc-claims.py --claim=<value>` must print no row in any doc, translations included.
- **Generated docs are fixed at the source** (`precedents/documentation.md` § 17): the commit
  message, the generator config or the annotation changes, and the regenerated output is diffed;
  the generated file is never hand-edited.
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix tree for the
  stated reason, passes after, and the decoy the precedents exempt (a dated record, a gitignored
  path, an outdated-banner translation, a third-party flag) is unchanged.

### Oracle taxonomy (documentation)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Claim resolution** | S | the doc's claim resolves to the oracle's value after the resolution ladder (root, doc dir, package roots, unique suffix, gitignore, rename) | V430, V433, V434, V435, V436, V438, V439, V446, V447, V449 |
| **Link checker** | T | lychee `--offline --include-fragments` (or the renderer's strict build) exits 0 | V430, V431 |
| **Execution** | X | the project's toolchain runs the step or the fence in a scratch copy and exits 0 with the stated output | V437, V441, V442 |
| **Spec and docstring tools** | T | Redocly or Spectral example rules, TypeDoc / pydoclint / rustdoc rules exit 0 | V440, V444 |
| **Structural diff** | S | the embedded snippet, the translation's code and links, the ADR graph and the changelog grammar match their source | V443, V445, V447, V448 |
| **Mutation** | M | a planted defect in a scratch copy turns the gate red | V432 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V430 | Link and anchor resolution | every relative link resolves to a file, and every fragment to a heading slug of the renderer in use; every link into the docs from code, alerts or config resolves | S, T | `doc-structure-scan` §1, §2, §5 (DL-1, DL-2, DK-3) |
| V431 | External link | the URL answers 2xx twice, with a token for GitHub; 403, 429 and 999 are not dead | T | `doc-structure-scan` §3 (DL-3) |
| V432 | Gate mutation | a planted broken link and a planted broken anchor (or a broken example) in a scratch copy make the docs gate exit non-zero on the PR path | M | `doc-structure-scan` §4 (DL-4); `doc-sample-scan` §4 (DC-4) |
| V433 | Path and symbol resolution | the path resolves under the ladder, or the symbol is defined in the source | S | `doc-drift-scan` §1, §2 (DR-1, DR-2) |
| V434 | Task and flag resolution | the script, make or just target, task or tox env exists where the doc runs it; the flag is declared by the CLI's parser | S | `doc-drift-scan` §3, §4, §13 (DR-3, DR-4, DK-1) |
| V435 | Deprecation marker | the symbol or operation the doc presents as current carries no deprecation marker, or the doc says it is deprecated | S | `doc-drift-scan` §5 (DR-5) |
| V436 | Version and tool pins | the stated runtime or service version is admitted by a pin; the stated package manager is the one the lockfile and `packageManager` name | S | `doc-drift-scan` §6, §7 (DS-2, DS-3) |
| V437 | Clean-container setup | the setup section, run step by step in a fresh container pinned to the repo's versions, reaches its smoke check | X | `quickstart-verify` (DS-1) |
| V438 | Env claim | the documented variable is read by the app; a required variable is documented; the documented default and values equal the schema's | S | `doc-drift-scan` §8, §9, §10 (DE-1, DE-2, DE-3) |
| V439 | Prose endpoint | method and path resolve against the committed spec or the router after prefix normalisation | S | `doc-drift-scan` §11 (DA-1) |
| V440 | Spec example validation | every `example` and `examples` value validates against its schema, and none is a placeholder | T, S | `doc-sample-scan` §5 (DA-2) |
| V441 | Fence compile | every candidate fence compiles or imports through the project's compiler and config | X | `doc-sample-scan` §1 (DC-1) |
| V442 | Doctest output | every `>>>`, `// Output:` or doctest block prints what the doc states | X | `doc-sample-scan` §2 (DC-2) |
| V443 | Embedded snippet sync | the committed snippet equals its source region, and the region still exists | S | `doc-sample-scan` §3 (DC-3) |
| V444 | Docstring rule and ratchet | the docstring tool rule exits 0 over the public surface and the coverage does not decline | T | `docstring-coverage` (DD-1, DD-2, DD-3) |
| V445 | Release notes | every breaking commit since the last tag appears in the section that covers it; the changelog parses under its grammar | S, T | `doc-drift-scan` §12 (DH-1); `doc-structure-scan` §9 (DH-2) |
| V446 | Runbook resource | every k8s, compose, alert or queue name a runbook acts on is declared in the repo's manifests | S | `doc-drift-scan` §14 (DK-2) |
| V447 | ADR graph | every supersession is reciprocal and its target exists; every status is in the vocabulary and agrees with the index; every number is unique | S | `doc-structure-scan` §6, §7, §8 (DX-1, DX-2, DX-3) |
| V448 | Translation parity and freshness | every declared locale has the page; the translation's code, commands and links equal the source's; its freshness marker is current | S | `doc-structure-scan` §10, §11, §12 (DI-1, DI-2, DI-3) |
| V449 | Hygiene, nav and diagram | no placeholder in published prose; every nav entry resolves and every page is reachable; every diagram box names a live module | S | `doc-structure-scan` §13, §14 (DF-1, DF-2); `diagram-sync` (DF-3) |

### Harnesses (documentation)

- **Recheck** (every S variant): `python3 -I .claude/skills/doc-drift-scan/scripts/doc-claims.py
  <repo> --recheck=<row-id>` exits 1 while the candidate exists and 0 once it is gone (2 when a lane
  is blocked); `--claim=<value>` lists every doc still naming the value; `--class=<id>` re-runs one
  class. The engine's `--self-test` covers each lane's seed and decoy.
- **Link checker** (V430, V431): `lychee --offline --include-fragments --no-progress --format json
  './**/*.md'` (exit 2 = broken links, 1 = lychee failed); with a site renderer, its strict build in
  a scratch copy (`mkdocs build --strict` with `validation.links.anchors: warn`, `sphinx-build -W
  --keep-going -b dummy`, `docusaurus build` with `onBrokenAnchors: 'throw'`). V431 runs online with
  `GITHUB_TOKEN`, `--accept 200..=299,403,429` and a second run; `--cache` only from a scratch copy,
  because lychee writes `.lycheecache` into the working directory.
- **Mutation** (V432): copy the docs and the gate config to `$TMPDIR`, plant one link to a missing
  file and one link to a missing anchor (for DC-4: one example that does not compile), run the gate
  command CI runs, assert a non-zero exit with the gate's own exit map, delete the copy.
- **Container** (V437): `quickstart-verify`'s lane: the image from the repo's pins (`.nvmrc`,
  `engines`, `.python-version`, `go.mod`, `devcontainer.json`), package registries only for install
  steps, `--network none` after, `.env` from `.env.example` only, a time budget per step;
  `blocked (no container runtime)` when no daemon runs.
- **Fence lanes** (V441, V442): `doc-claims.py <repo> --fences=$TMPDIR/fences` writes each fence and
  `fences.tsv` (kind `candidate`, `doctest`, `fragment`, `excerpt`, `shell`, …). TS: a scratch
  `tsconfig` that `extends` the package's own, `tsc --noEmit --incremental false`. Python: `python3
  -I -m py_compile`, then the import in the project venv. Doctest: `python -m pytest
  --doctest-glob='*.md' -p no:cacheprovider` in a scratch copy (exit 5 = NOT-RUN). Rust: `cargo test
  --doc`. Go: `go vet` and `go test -run Example`.
- **Spec tools** (V440): `REDOCLY_TELEMETRY=off redocly lint` with `no-invalid-media-type-examples`
  and `no-invalid-schema-examples`, or Spectral with `oas3-valid-media-example` and
  `oas3-valid-schema-example` from an explicit ruleset; the engine's `specex` lane validates JSON
  specs without either tool.
- **Release notes** (V445): `git log --format='%h %s%n%b' <last-tag>..HEAD` filtered to `!:` and
  `BREAKING CHANGE:`, each matched in the section that covers it; `kacl-cli verify --json` (exit =
  error count) or the engine's `changelog` lane; for a spec, `oasdiff breaking --fail-on ERR
  <tag>:openapi.json HEAD:openapi.json`.

### Class variants (documentation)

A fix passes the class only when every variant the class takes in the docs present passes the
oracle, and the decoy the precedents exempt is untouched.

#### V430. Link and anchor resolution (`doc-structure-scan` §1, §2, §5)
- the same target linked from every doc; reference-style definitions; images; HTML `href` / `src`; the translated copies; site-root links (`/docs/x`) under the renderer's root; duplicate headings (`-1` on GitHub, `_1` on MkDocs); headings with code, emoji or punctuation; non-Latin headings; custom ids (`{#id}`); inbound links from code strings, alert `runbook_url` and package `homepage`
- pass: lychee offline with fragments exits 0, and `doc-claims.py --class=DL-1,DL-2,DK-3` prints no row for the target (a `#L42` line anchor and a gitignored output are the control, `precedents/documentation.md` § 4, § 10)

#### V431. External link (`doc-structure-scan` §3)
- 404; 410; DNS failure; a redirect chain to a 404; a GitHub URL behind rate limits
- pass: two runs with a token answer 2xx or an accepted code (403 behind an auth wall, 429 and 999 are the control, § 15)

#### V432. Gate mutation (`doc-structure-scan` §4; `doc-sample-scan` §4)
- a broken relative link; a broken anchor; a broken nav entry; a broken example fence; the gate on the PR workflow, not only on `main`; a matrix job that skips docs
- pass: each planted defect exits non-zero through the gate's own exit map (lychee 2, markdownlint-cli2 1, `remark --frail` 1, `mkdocs build --strict` non-zero); the unplanted copy exits 0

#### V433. Path and symbol resolution (`doc-drift-scan` §1, §2)
- every doc naming the old path or symbol, translations included; a directory and a file form; a package-root-relative form; a `file:line` suffix; the renamed path's new name in every doc; a code comment that cites the doc
- pass: `doc-claims.py --claim=<value>` prints no row (a dated record and a per-module layout name are the control, § 1, § 3)

#### V434. Task and flag resolution (`doc-drift-scan` §3, §4, §13)
- `pnpm x`; `pnpm run x`; `pnpm -F pkg x`; `npm run x`; `yarn x`; `bun run x`; `turbo run x`; `make x`; `make -C dir x`; `just x`; `task x`; `poe x`; `tox -e x`; a script run after `cd pkg`; `--flag` and `--flag=value`; `--no-flag`; the env-var equivalent; a CI file that calls the same script
- pass: each form resolves in the manifest or parser the doc runs it against (a third-party CLI flag and a package-local script run from its directory are the control, § 19, § 31)

#### V435. Deprecation marker (`doc-drift-scan` §5)
- JSDoc `@deprecated`; `#[deprecated]`; Go `// Deprecated:`; Java `@Deprecated`; Python `warnings.deprecated` / `DeprecationWarning`; OpenAPI `deprecated: true`
- pass: no doc presents the marked symbol as current (a migration guide naming the old API on purpose is the control)

#### V436. Version and tool pins (`doc-drift-scan` §6, §7)
- README, CONTRIBUTING, docs/setup and translations; `.nvmrc`, `engines`, `.tool-versions`, `.python-version`, `requires-python`, `go.mod`, `rust-toolchain`, Dockerfile `FROM`, compose `image:`, the CI matrix, `packageManager`; `npm install` / `npm ci` / `yarn` against `pnpm-lock.yaml`; `pip install -r` against `uv.lock` or `poetry.lock`
- pass: every stated version is admitted by a pin and every install or run command uses the pinned tool (installing the published package with `npm install <name>` is the control)

#### V437. Clean-container setup (`quickstart-verify`)
- the full sequence to the smoke check; both platform branches when the doc has them; the pinned runtime; a fresh volume
- pass: every step exits 0 within its budget and the smoke check answers (a step needing a real key is `PREREQUISITE (secret)`, § 21)

#### V438. Env claim (`doc-drift-scan` §8, §9, §10)
- every env table; `.env.example` comments; deploy READMEs; translations; required **and** default **and** enum values; a pydantic `env_prefix`; a k6 `__ENV` read
- pass: every documented variable is read, every required one is documented, and every stated default and value set equals the schema's (a platform- or SDK-read variable is the control, § 8)

#### V439. Prose endpoint (`doc-drift-scan` §11)
- method + path + global prefix and version; `{id}` and `:id`; a `curl` to the app's own port; an `http` fence; a table row; every doc naming the old path
- pass: each resolves in the spec or the router (an infra route excluded from the spec and a curl to a third-party port are the control, § 7, § 19)

#### V440. Spec example validation (`doc-sample-scan` §5)
- request and response examples; `components.examples`; `examples` maps; nested objects; enum values; required keys
- pass: the example rules exit 0 and no example is a placeholder (`"string"`, `0`, `"example"`) (an `externalValue` example is the control)

#### V441. Fence compile (`doc-sample-scan` §1)
- every fence of the same API across docs; the README the registry renders; docstring examples; a removed export; an old arity
- pass: every candidate fence compiles in the scratch config (an excerpt with `// ...` is the control, § 14)

#### V442. Doctest output (`doc-sample-scan` §2)
- `>>>` blocks in Markdown and docstrings; Go `// Output:`; rustdoc; Elixir `iex>`
- pass: the stated output equals the printed one under the project's runner (non-deterministic output patched or marked is the control)

#### V443. Embedded snippet sync (`doc-sample-scan` §3)
- embedme `// path#L10-L20`; `file=` imports; `--8<--` snippets; `!!raw-loader`; Sphinx `literalinclude` with `:lines:`
- pass: the committed snippet equals its source region and every embedded path and range exists

#### V444. Docstring rule and ratchet (`docstring-coverage`)
- the whole public surface of the package (`exports`, `__all__`, `pub`); `@param` names and order; returns; `@throws` against real throws; intra-doc links
- pass: the tool rule exits 0 and coverage ≥ the recorded baseline (an unpublished app's internal symbol is advisory, § 23)

#### V445. Release notes (`doc-drift-scan` §12; `doc-structure-scan` §9)
- each `!:` and `BREAKING CHANGE:` commit since the last tag, in every changelog that covers it (root and per-package); a removed CLI flag; a removed export; `oasdiff breaking` between tags; version order; duplicate versions; ISO dates; compare links; `[Unreleased]` first
- pass: every breaking item appears in its section and the changelog parses (an unreleased commit under a generator is the control, § 17; an omission is retro-fixable, § 25)

#### V446. Runbook resource (`doc-drift-scan` §14)
- `kubectl -n <ns> <verb> <kind>/<name>`; a CronJob; a compose service; an alert name; a queue name; a resource a KEDA ScaledObject derives (`keda-hpa-<name>`)
- pass: every name resolves in the manifests (a third-party chart's Service and a Secret created out of band are the control, § 19)

#### V447. ADR graph (`doc-structure-scan` §6, §7, §8)
- both ends of every supersession; the index table; the status vocabulary from the project's template; duplicate numbers; title number ≠ file number; a date mistaken for an id
- pass: the graph is reciprocal, every status is in the vocabulary and agrees with the index, every number is unique (a partial supersession is the control, § 30)

#### V448. Translation parity and freshness (`doc-structure-scan` §10, §11, §12)
- every declared locale (Docusaurus `i18n.locales`, mkdocs-static-i18n languages, `docs/<lc>/`, `README.<lc>.md`); fenced commands; inline commands; link targets; the source-commit marker
- pass: every page exists per declared locale, code and links equal the source's, and the marker is current (a page with an outdated banner under a declared lag policy is the control, § 11)

#### V449. Hygiene, nav and diagram (`doc-structure-scan` §13, §14; `diagram-sync`)
- `TBD`, `TODO`, `FIXME`, `lorem ipsum`, `<insert …>` in prose; MkDocs `nav` and `not_in_nav`; Docusaurus `sidebars.*`; mdBook `SUMMARY.md`; Sphinx toctree; a diagram box naming a deleted module
- pass: no placeholder outside fences, every nav entry resolves, every page is in the nav or linked, every diagram box resolves (a placeholder in a config fence is the control, § 6)

### Sources (documentation)

The documentation research catalog (2026-10-19) `precedents/documentation.md` § 1–5 gives the
classes, tools, techniques, precedents and the per-class variants above; its notes give the tool
versions and exit codes as fetched on 2026-10-19 (lychee 0.24.2, markdownlint-cli2 0.23.3, rumdl
0.3.0, remark-validate-links 13, MkDocs 1.6, Docusaurus 3.10.2, Sphinx 9.1, oasdiff 1.34.0,
openapi-diff 2.1.7, Spectral 6.17.0, Redocly CLI 2.64.1 telemetry, AsyncAPI CLI 6.2.1 telemetry,
python-kacl 0.7.7, TypeDoc 0.28.20, pytest 9 doctest behaviour, pydoclint 0.11.1, and the archived
Optic, Dredd and darglint). The batch-7 documentation eval (2026-10-19) gives the engine design,
the scope rules and the severity matrix; the integrator assigned V430–V449. Paraphrased; no text
reproduced.

---

## Business

A business claim says the code breaks **a rule the business or an authority set**, not a shape: two
paths round one charged amount differently, a discount stack depends on the request's order, a refund
returns more than the paid share, a billing period drifts at month end, a tax rate is read at render
time, an issued invoice can be edited, an unbalanced posting can commit, an account deletion erases
invoices inside their retention period, a dashboard sums each order once per line, a "day" depends on
which query computed it, an entity can enter a state it never leaves, a user can subscribe and never
cancel. Reading the code rarely settles one: the rule has to be read first (the money policy, the tax
policy, the ledger inventory, the metric definition, the lifecycle graph, the route pairs), and the
oracle runs the real path against it, failing first. Every oracle names a **family**:
- **S**: a static fact with both ends cited — the policy row and the call that breaks it, the writer
  and the reader of a unit, the posting function and the absent constraint, the forward route and the
  inverse "none after the written search".
- **P**: a property battery in the project's own runner (fast-check, Hypothesis, jqwik, rapid) —
  conservation, a bound, idempotence, permutation, tiling, a model-based state machine.
- **G**: a golden file written before the fix — a golden ledger, a golden invoice per jurisdiction, a
  golden report day, a golden provider export — compared to the minor unit, never with a tolerance.
- **D**: a database probe on a scratch database or inside a rolled-back transaction — a direct-SQL
  write that bypasses the code, a replay, a reconciliation query.
- **T**: a tool exit recorded in this run — the authority's validator, `status-graph.py`, the
  route-pair diff.
- **R**: a provider replay — a test clock, duplicated and reordered webhook deliveries, the provider's
  test mode or sandbox.
- **L**: a live walk through a non-production environment (`/audit-business --live`).

Settled questions are in [`precedents/business.md`](precedents/business.md). This section is
self-contained: its V-numbers (V450–V489) are cited by the business detectors, the three business
judges and `/business-fix` only, and no V outside this range is reused for a business class.

Users:
- the detectors `pricing-rule-scan` (MP §1–§3, PR §4–§9, BL §10–§13), `tax-invoice-scan` (TX §1–§6,
  IV §7–§11), `ledger-scan` (LG §1–§7, FR §8–§10, DM §11–§12), `report-scan` (RP §1–§7, BT §8–§9),
  `lifecycle-scan` (LC §1–§6, `status-graph.py`) and `check-business-coverage` (CY §1–§6) (business
  pack);
- the judges `@domain-model-auditor`, `@workflow-integrity` and `@business-auditor`, and
  `/audit-business`, which runs them all, with `@verifier` mode `refute` on every BLOCKER and HIGH it
  keeps;
- `/business-fix`, which writes each finding's failing-first test from its V-number.

**Owned elsewhere.** These classes keep their own sections; business reads them as corroboration and
never re-proves them:
- float money in code, the rounding *call*, allocation that does not re-sum, overflow, calendar
  arithmetic and DST → § Code quality (`correctness-smell-scan` §4 / §6), which reads this section's
  V450 policy row for the mode and the point;
- Decimal on the wire, output rounding, FSM library semantics, a cron's zone → § Backend;
- float columns, CASCADE into records of fact, PII mechanics, gapless numbering, lost updates → the
  data sections (`schema-integrity-scan`, `transaction-scan`);
- client-chosen prices, check-then-act on balances and coupons, money-route idempotency, late provider
  events re-opening a settled record → security, proven with [`exploit-payloads.md`](exploit-payloads.md);
- consumer dedupe, outbox and saga compensation → § Distributed; analytics events against a tracking
  plan → § Product.

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Eight rules hold for every
variant below:

- **Read the rule before the code.** Every variant starts from the policy row it tests (money policy,
  tax policy, ledger inventory, metric register, graph, route pairs) and its source. A rule with no
  source is `UNDECLARED`: the variant is written for the decision the owner makes, never for a guess
  (`/business-fix` STOPs).
- **Never write into the audited repo** outside the fix's own test and source files. Registers and
  scripts write under the run folder; `status-graph.py` refuses an `--out` inside a scanned root.
- **The real path, the real engine.** Drive the checkout, refund, invoice builder, posting function,
  report query or webhook handler against a database of the project's engine. A trigger, a `numeric`,
  a zone or a deferred constraint does not exist in a mocked repository or in SQLite standing in for
  Postgres.
- **Database probes are isolated.** Direct-SQL writes run on a scratch database or inside `BEGIN; …
  ROLLBACK;`; a probe that cannot be isolated is `NOT-RUN`. Never a shared or production database.
- **Exact money, no tolerance.** Assertions compare minor units exactly. `toBeCloseTo`, `approx`,
  `assertAlmostEqual` or `abs(a - b) < 0.01` on money is the defect the oracle exists to catch.
- **Golden files are written before the fix** and never regenerated in the change that fixes the
  code they judge.
- **Authorities and providers through their own tools, offline or in test mode.** The authority's
  validator vendored by the project (KoSIT, Peppol Schematron, the ZATCA SDK) runs offline; an
  authority's preprod or a provider's test mode needs credentials the run does not invent
  (`NOT-RUN (auth)`); live keys are never used. Telemetry off before any CLI (`CI=true`,
  `DO_NOT_TRACK=1`).
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix code for the
  stated reason, passes after, and the benign control a precedent names (a declared half-up mode, a
  draft invoice edit, a `reconciled_at` update, a pre-aggregated CTE, a declared reversal edge, an
  irrevocable action) is unchanged.

### Oracle taxonomy (business)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Policy corpus** | P, S | every path that computes an amount agrees with the declared rule on the inputs where rules differ (ties, exponents 0/2/3, month ends, rate-change dates) | V450, V451, V452, V456, V458 |
| **Property battery** | P | a bound, a conservation or an independence holds over generated inputs (permutation of coupons, partial refunds, period tiling, eligibility after every mutation) | V453, V455, V456, V461, V477 |
| **Golden file** | G | the real path reproduces the golden ledger, invoice, report or export to the minor unit | V454, V457, V459, V467, V469, V470, V472, V473 |
| **Database probe** | D | the database refuses the violating write, or the replay posts once, whoever the writer | V460, V463, V464, V465, V466, V468, V481 |
| **Authority validator** | T | the authority's tool accepts the generated document (exit 0) | V462, V480 |
| **Graph diff** | T, P | the extracted lifecycle graph has no unreachable live state, no trap, no undeclared edge on a money entity; a model-based run keeps a cross-aggregate invariant | V474, V475, V482 |
| **Replay** | R | duplicated, reordered or late provider events and a test clock leave the same final state and money | V455, V476 |
| **Zone and calendar table** | P, G | a rule's "day" and "business day" are the same in every query and region | V471, V479 |
| **Cycle pair** | T, L | each forward action has its inverse, resend, status and exit, reachable by the forward's role | V478, V483, V484 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V450 | Tie corpus | `0.005, 1.005, 2.675, 0.125, -2.5` at exponents 0, 2 and 3 through every path that rounds the amount kind (API, worker, renderer, report) — all agree with the declared mode and point | P, S | `pricing-rule-scan` §1 (BIZ-MP-1) |
| V451 | Unit round trip | each unit written through the real writer reads back equal through every reader (services, raw SQL, the export, the PSP call) | P, S | `pricing-rule-scan` §2 (BIZ-MP-2) |
| V452 | Pinned rate | convert at t1, change the rate, re-read at t2: the booked amount is unchanged; A→B→A never gains | P | `pricing-rule-scan` §3 (BIZ-MP-3) |
| V453 | Composition and eligibility | permuting the same coupons does not change the total under an order-independent policy; `0 ≤ total ≤ undiscounted`; the threshold holds after every cart mutation; a fixed amount is never applied across currencies; the window holds at 23:59 and 00:01 business-zone time and at placement | P | `pricing-rule-scan` §4, §6, §7, §8 (BIZ-PR-1, PR-3, PR-4, PR-5) |
| V454 | Snapshot after a catalog change | place an order, change the catalog price, refund and re-render: amounts unchanged | G | `pricing-rule-scan` §5 (BIZ-PR-2) |
| V455 | Proration and usage window | a provider test clock across a plan change, or the formula golden at period day 1, 15 and the last day; a metering golden with a late event and one at 23:59 business-zone time | R, G | `pricing-rule-scan` §10, §13 (BIZ-BL-1, BL-4) |
| V456 | Anchor sequence and tiling | from a day-31 anchor over 13 months across a leap February, every period starts on the clamped anchor day; generated periods tile the timeline (half-open, no gap, no overlap) | P | `pricing-rule-scan` §11, §12 (BIZ-BL-2, BL-3) |
| V457 | Golden invoices | per jurisdiction (domestic, exempt, reverse-charge), the real builder reproduces the golden document's lines, category totals and document totals; re-rendering after a settings and clock change is identical | G | `tax-invoice-scan` §4, §5, §11 (BIZ-TX-4, TX-5, IV-5) |
| V458 | Rate change at the tax point | a golden invoice dated the day before and the day after a rate change keeps its own rate after re-render | G, P | `tax-invoice-scan` §1 (BIZ-TX-1) |
| V459 | Base matrix | discount × shipping × inclusive / exclusive × exempt through the real tax function equals the golden matrix | G | `tax-invoice-scan` §2, §3 (BIZ-TX-2, TX-3) |
| V460 | Issued immutability | an edit of an issued document's financial content through each writer (service, admin, bulk, raw SQL) is rejected; the only path is a credit note; a draft stays editable | D | `tax-invoice-scan` §7 (BIZ-IV-1) |
| V461 | Credit-note bound | a credit note carries its original's id; crediting 60 % twice is rejected on the second | P, D | `tax-invoice-scan` §8 (BIZ-IV-2) |
| V462 | Validator exit | a document generated by the real builder passes the authority's validator offline (exit 0), including a foreign-currency document's national-currency tax | T | `tax-invoice-scan` §4, §6, §9, §10 (BIZ-TX-4, TX-6, IV-3) |
| V463 | Balanced posting | the balance property per (entry, currency) over generated postings; a direct-SQL unbalanced insert is rejected at COMMIT; per-currency sums are zero after an FX scenario | P, D | `ledger-scan` §1, §5 (BIZ-LG-1, LG-5) |
| V464 | Append-only | with a trigger or a revoked UPDATE / DELETE on the line table, the suite stays green; a correction scenario's golden diff adds rows only | D, G | `ledger-scan` §2 (BIZ-LG-2) |
| V465 | Idempotent posting | the same cause delivered N times, sequentially and concurrently, posts one entry set | D, R | `ledger-scan` §3 (BIZ-LG-3) |
| V466 | Cache equals the fold | for generated sequences, the cached balance equals Σ entries per account and currency; a crash between the two writes is found by the sweep | P, D | `ledger-scan` §4 (BIZ-LG-4) |
| V467 | Provider reconciliation | a golden provider export for a day matches the ledger row for row; clearing nets to zero | G | `ledger-scan` §6 (BIZ-LG-6); `report-scan` §6 when the books are the provider's |
| V468 | Records survive deletion | deleting a seeded user and a seeded tenant keeps orders, invoices and ledger rows (pseudonymised); seeded aged rows per record kind survive the purge until their cited period; erasing a subject removes PII from mutable tables and keeps the invoice snapshot | D | `ledger-scan` §8, §9, §10 (BIZ-FR-1, FR-2, FR-3) |
| V469 | Golden report dataset | two child rows per parent, an odd count, a zero-denominator group and unequal group sizes: the real query returns the hand totals and rates | G | `report-scan` §1, §5 (BIZ-RP-1, RP-5) |
| V470 | One figure, stable history | every site that computes a named metric returns the same figure on the golden day; a closed period's figure does not move when a row's status changes later; the figure equals the books' total for the day | G | `report-scan` §2, §6, §7 (BIZ-RP-2, RP-6, RP-7) |
| V471 | Business day | rows at 23:30 and 00:30 local time and on a DST change date land on the business day in every bucket, cutoff and daily limit | P, G | `report-scan` §8 (BIZ-BT-1) |
| V472 | Currency sums | a golden set with two currencies returns per-currency totals, or a converted total equal to the hand conversion at the stored rates | G | `report-scan` §4 (BIZ-RP-4) |
| V473 | Exclusions | a golden day with one cancelled, refunded, test, sandbox and soft-deleted row each: the figure does not move | G | `report-scan` §3 (BIZ-RP-3) |
| V474 | Graph diff | `status-graph.py` before and after: declared states minus reachable states is the documented legacy list; every non-terminal state reaches a terminal one; declared and built edges agree on money entities | T, P | `lifecycle-scan` §1, §2, §3 (BIZ-LC-1, LC-2, LC-3) |
| V475 | Model-based cross-aggregate | a model-based run (`fc.commands`, `RuleBasedStateMachine`) over the real handlers keeps the pair invariant after every step, including a crash between the two writes | P | `lifecycle-scan` §4 (BIZ-LC-4) |
| V476 | Provider replay | a recorded event sequence, duplicated and shuffled, through the real handler: the same final state, every intermediate edge in the graph | R | `lifecycle-scan` §5 (BIZ-LC-5) |
| V477 | Conservation | charge → partial refunds → full refund → dispute won / lost: Σ refunds ≤ captured, every account nets as expected to the minor unit, a re-fired reversal moves nothing | P, D | `pricing-rule-scan` §9 (BIZ-PR-6); `ledger-scan` §7 (BIZ-LG-7) |
| V478 | Cycle pair | the route-pair diff for the resource, then forward → inverse end to end restores the state; resend after non-delivery; a status surface reaches the job's end; a recovery action completes after an expired token or a declined card | T, L | `check-business-coverage` §1, §2, §3, §6 (BIZ-CY-1, CY-2, CY-3, CY-6) |
| V479 | Business-day table | a decision table per region across a weekend and a public holiday yields the declared due date, settlement day or SLA end | P, G | `report-scan` §9 (BIZ-BT-2) |
| V480 | Chain continuity | over N issues from one issuer: one chain, no reused previous hash or UUID, a contiguous counter, the previous value read from the persisted last document; a retry does not regenerate it | P, T | `tax-invoice-scan` §10 (BIZ-IV-4) |
| V481 | Invariant per writer | the violating write through every writer (service, bulk update, raw SQL, second service, admin) is rejected; an account meant to go negative is the control | D | `ledger-scan` §11, §12 (BIZ-DM-1, DM-2) |
| V482 | Transition history | each transition through its real entry point writes exactly one history row (actor, from, to, at) in the same transaction; a rolled-back transition writes none | D | `lifecycle-scan` §6 (BIZ-LC-6) |
| V483 | One-click unsubscribe | a raw message captured from the real marketing sender carries `List-Unsubscribe` and `List-Unsubscribe-Post: List-Unsubscribe=One-Click`; a POST to the URL without a session unsubscribes | T, L | `check-business-coverage` §4 (BIZ-CY-4) |
| V484 | Export and erasure | as the user: an export returns a machine-readable file with the user's data; a deletion request ends with login refused, PII gone from mutable tables and records of fact kept | L, D | `check-business-coverage` §5 (BIZ-CY-5) |

V485–V489 are reserved for business classes added later.

### Harnesses (business)

- **Policy corpus and properties** (V450–V453, V456, V458, V461, V463, V466, V475, V477): the
  property library already in the lockfile (fast-check 4.10.2 `fc.property` / `fc.commands`,
  Hypothesis 6.170.1 `@given` / `RuleBasedStateMachine`, jqwik, rapid 1.3.0); never added without
  asking (jqwik ≥ 1.10 mentions an "Anti-AI Usage Clause" — read it before generating jqwik code).
  The tie corpus and the exponent list are fixed inputs, not generated ones. Money generators produce
  integer minor units with the currency's exponent from ISO 4217 (0 for JPY / KRW, 3 for KWD / BHD /
  OMR).
- **Golden files** (V454, V457–V459, V464, V467, V469–V473, V479): JSON, CSV or XML under the test
  directory, written from the rule (the policy row, the authority's worked example, a hand
  computation), committed with the failing test, compared exactly. A golden report day seeds the
  edge rows each variant names; a golden ledger lists `(entry, account, currency, amount)` tuples per
  scenario.
- **Database probes** (V460, V463–V466, V468, V481, V482): a testcontainer or the CI database service
  of the project's engine, migrated to head; each probe in a transaction rolled back after the
  assertion, or a throwaway schema. A deferred constraint is proven by a `COMMIT` that fails, not by
  the insert.
- **Authority validators** (V462, V480): the validator the project vendors — KoSIT validator 1.6.3
  with the XRechnung configuration 3.0.2 (`java -jar validator-<v>-standalone.jar -s scenarios.xml -r
  <repo> -o <out> <invoice.xml>`, non-zero exit on reject; read `--help`), Peppol BIS 3.0.21
  Schematron through Saxon-HE, the ZATCA SDK (flags `[K?]`, proprietary terms: `NOT-RUN` unless
  vendored), an authority preprod (`NOT-RUN (auth)` offline). Output under `${TMPDIR}`.
- **Graph** (V474, V482): `python3 -I -B .claude/skills/lifecycle-scan/scripts/status-graph.py
  <roots> --out=<run folder>/graph [--declared=<flows file>]` before and after the fix; the diff of
  `edges.tsv` and the report's LC lines is the oracle. Its `--self-test` covers the TS, Python, Ruby
  and SQL lanes and every exit.
- **Replays and clocks** (V455, V465, V476): recorded webhook payloads replayed through the real
  handler duplicated and shuffled; `stripe events resend` and Stripe test clocks only in a test-mode
  sandbox with the project's test key (`NOT-RUN (auth)` without one; never a live key).
- **Cycle pairs and walks** (V478, V483, V484): the route inventory from product's `surface-map.py`
  or backend's `dto-types.py --routes` when installed, paired by `check-business-coverage` 0b; end to
  end through the project's own runner (Playwright, Cypress, a request suite) against a
  non-production URL, output under `${TMPDIR}`; a raw-message capture through the mail library's test
  transport.

### Class variants (business)

A fix passes the class only when every variant the class takes in the stacks present passes the
oracle, and the benign control is untouched.

#### V450. Money policy — tie corpus (`pricing-rule-scan` §1)
- every rounding call and library global (`Decimal.set`, `Big.RM`, `getcontext().rounding`, `Money.rounding_mode`); every service that rounds the amount kind (API, worker, invoice renderer, report, CSV / XLSX export, the web client); a money-library upgrade across a default change (Ruby `money` 6 → 7, 2026-07-31)
- pass: every path agrees with the declared mode and point on the corpus (one module with a declared half-up or half-away mode is the control, `precedents/business.md` § 2)

#### V451. Unit drift — round trip (`pricing-rule-scan` §2)
- every writer and reader of a unit-bearing column; percent vs basis points vs fraction; major vs minor at a PSP boundary; a column whose unit depends on a type column; a hard-coded exponent for a 0- or 3-digit currency
- pass: each unit reads back equal through every reader (integer minor units with the exponent from the currency table are the control, § 6)

#### V452. FX — pinned rate (`pricing-rule-scan` §3)
- every conversion site; a stored converted amount with its rate, time and source; a report that totals converted values; a refund of a converted charge
- pass: amounts unchanged after a rate change; A→B→A never gains (a documented single-currency product is the control, § 6)

#### V453. Composition, eligibility, promotion currency, validity window (`pricing-rule-scan` §4, §6–§8)
- cart add / update / merge, quote, checkout, place-order revalidation, order edit, re-order, auto-applied promotions, referral codes, gift-card and loyalty burn, guest checkout, old API versions; expiry from a date-only input; the window checked at apply and at commit
- pass: the properties hold after every mutation and at both clock edges (a documented sequential policy with golden tests is the control)

#### V454. Snapshot — catalog change (`pricing-rule-scan` §5)
- refund, credit note, invoice re-render, recalculation, re-order, partial return of a bundle
- pass: historical documents unchanged (analytics that intend current prices are the control, § 19)

#### V455. Proration and usage window (`pricing-rule-scan` §10, §13)
- upgrade, downgrade, quantity change, trial end, pause / resume, anchor change, renewal; metered usage at period close, late events, a period in another zone
- pass: the test clock or the formula golden agrees at day 1, mid-period and the last day; late events land per the declared rule (proration delegated to the platform is the control, § 9)

#### V456. Anchor and periods (`pricing-rule-scan` §11, §12)
- `setMonth`, `AddDate(0, 1, 0)`, `replace(month=)`, adding months from the previous period's end; inclusive end-of-month bounds; `<=` on both ends of a filter
- pass: the anchor sequence clamps from the anchor and periods tile the timeline (date-fns `addMonths(anchor, n)`, `java.time`, Stripe `billing_cycle_anchor_config` are the control, § 9)

#### V457. Golden invoices (`tax-invoice-scan` §4, §5, §11)
- cart, checkout, invoice, credit note, PDF, e-invoice builder, refund, report — tax is often computed in four places; domestic, exempt and reverse-charge buyers; a re-render after a settings change
- pass: every path reproduces the golden document (per-line rounding the national rule allows and the policy declares is the control, § 3)

#### V458. Rate change (`tax-invoice-scan` §1)
- a rate table edited in place; a rate resolved at render; the rate not stored on the line; the admin edit path of the rate table
- pass: each document keeps its tax-point rate (a single-jurisdiction dated config with the rate on each line is the control, § 7)

#### V459. Base matrix (`tax-invoice-scan` §2, §3)
- discount before / after tax; shipping in / out of the base; inclusive applied twice; back-out as `price × rate`; the inclusive flag missing on one path
- pass: the matrix equals the golden (a tax engine called with the address and the tax code is the control, § 8)

#### V460. Issued immutability (`tax-invoice-scan` §7)
- service update, admin panel, bulk update, raw SQL, a delete route, a PDF regeneration that rewrites amounts
- pass: every financial edit of an issued document is rejected (a draft edit and a `sent_at` / `pdf_url` update are the control, § 15)

#### V461. Credit-note bound (`tax-invoice-scan` §8)
- a credit note without its original's id; two concurrent credits; a return receipt; a partial credit after a partial refund
- pass: Σ credits ≤ original, enforced in the credit's transaction

#### V462. Validator exit (`tax-invoice-scan` §4, §6, §9, §10)
- each standard the builders emit; a foreign-currency document; a zero-rated line with its exemption reason; a credit note; the first and the N-th document of a chain
- pass: the authority's validator exits 0 on each (`NOT-RUN` offline for a preprod-only authority, never PASS)

#### V463. Balanced posting (`ledger-scan` §1, §5)
- the posting function; admin adjustments; backfills; imports with historical dates; FX legs; fees; payouts; disputes; a raw insert from a second service
- pass: per (entry, currency) Σ debits = Σ credits, and the direct-SQL unbalanced insert fails at COMMIT (a deferred balance trigger or a ledger engine is the control, § 10)

#### V464. Append-only (`ledger-scan` §2)
- update or delete of amount, account, currency, direction or posting date; soft delete on entries; `updated_at` on entries
- pass: the suite is green with UPDATE / DELETE refused (an update of `memo`, `reconciled_at`, `exported_at` is the control, § 11)

#### V465. Idempotent posting (`ledger-scan` §3)
- a webhook redelivered; a consumer retried; a cron re-run; two workers on one cause; a key generated at retry time
- pass: one entry set per cause (a unique source key with `ON CONFLICT DO NOTHING` is the control, § 12)

#### V466. Cache equals the fold (`ledger-scan` §4)
- every cache writer, including another service; a crash between the ledger insert and the cache write
- pass: cache = Σ entries; the sweep reports an injected drift (a cache written in the posting transaction with a sweep is the control, § 13)

#### V467. Provider reconciliation (`ledger-scan` §6)
- payments, refunds, fees, payouts, disputes, carrier cash-on-delivery; a missing and a duplicated provider row
- pass: every provider row matched; clearing nets to zero (reconciliation in a documented external tool is the control)

#### V468. Records of fact (`ledger-scan` §8, §9, §10)
- delete-account, tenant offboarding (`DROP SCHEMA` per tenant), purge crons, the anonymiser, backups and exports
- pass: records kept for their cited period, PII gone from mutable tables, invoice snapshots intact (unissued drafts deleted is the control, § 15, § 17)

#### V469. Golden report dataset (`report-scan` §1, §5)
- every dashboard and report query, ORM aggregate, export, scheduled report, dbt model; integer division; `NULL` sums; average of averages
- pass: hand totals and rates reproduced (a pre-aggregated CTE, `distinct on` or a primary-key join is the control, § 18)

#### V470. One figure, stable history, books (`report-scan` §2, §6, §7)
- every site that names the metric (dashboard, export, email digest, admin report); a status change after the period closes; the books for the day
- pass: one figure everywhere, closed periods stable, equal to the books (two differently named metrics, and a snapshot metric that says so, are the control, § 19)

#### V471. Business day (`report-scan` §8)
- report buckets, cutoffs, daily limits, coupon expiry, billing day, payout day; a tenant off UTC; a DST date
- pass: each row lands on its business day everywhere (a documented UTC day for a single-zone business is the control, § 20)

#### V472. Currency sums (`report-scan` §4)
- revenue, payouts, balances, commissions, refunds; a converted total
- pass: per-currency totals or a correct conversion (single currency, documented, is the control, § 6)

#### V473. Exclusions (`report-scan` §3)
- cancelled, refunded, test, sandbox (`livemode = false`), soft-deleted, internal accounts
- pass: the figure ignores what its definition excludes (a definition that includes them on purpose is the control)

#### V474. Graph diff (`lifecycle-scan` §1, §2, §3)
- services, controllers, jobs, webhooks, admin panels, seeds, raw SQL, bulk updates, a provider sync; a state missing from the transition table; a declared lifecycle document
- pass: no unreachable live state, no trap, declared and built edges agree on money entities (a declared reversal table and a locked legacy state are the control, § 29, § 30)

#### V475. Cross-aggregate (`lifecycle-scan` §4)
- order and payment; shipment and order; subscription and invoice; return and refund; a crash or a retry between the two writes
- pass: the pair invariant holds after every step ("refund without return" as a written policy is the control, § 27)

#### V476. Provider replay (`lifecycle-scan` §5)
- duplicated, reordered and late events; a subscribed type with no handler; a provider-status map applied without the graph
- pass: the same final state, every edge in the graph (an explicit ignore list and a re-fetch before deciding are the control, § 22)

#### V477. Conservation (`pricing-rule-scan` §9, `ledger-scan` §7)
- line and order refunds; partial returns of a bundle; store-credit and wallet refunds; voids; chargebacks won and lost; partial capture; a re-fired reversal
- pass: net zero to the minor unit; Σ refunds ≤ captured (the provider bounding its own refunds is the control, § 26)

#### V478. Cycle pair (`check-business-coverage` §1, §2, §3, §6)
- every resource with a create, subscribe, invite, connect, share or start route; every send; every user-started job; every token kind; account and tenant lifecycle
- pass: the inverse, resend, status and recovery exist for the forward's role (irrevocable actions, admin inverses for admin forwards and command POSTs are the control, § 23, § 40, § 41)

#### V479. Business-day table (`report-scan` §9)
- SLA, settlement T+n, due dates, payout day; a Friday–Saturday weekend; a public holiday; a year boundary
- pass: the table matches per region (a maintained calendar is the control, § 37)

#### V480. Chain continuity (`tax-invoice-scan` §10)
- issue, retry, resubmission, parallel issuers, the first document of a device or certificate
- pass: one chain, no reuse, contiguous counter (an authority without chaining is the control — cite its spec)

#### V481. Invariant per writer (`ledger-scan` §11, §12)
- services, bulk updates (`update_all`, `QuerySet.update`, `updateMany`), raw SQL, imports, admin panels, a second service
- pass: every writer rejected at the boundary (a clearing, liquidity or provider-receivable account going negative is the control, § 14)

#### V482. Transition history (`lifecycle-scan` §6)
- every setter, webhook and admin repair on order, payment, subscription, invoice, role and consent machines
- pass: one history row per transition, in its transaction (a low-stakes toggle is the control, § 31)

#### V483. One-click unsubscribe (`check-business-coverage` §4)
- every marketing sender, campaign, newsletter and digest; the one-click endpoint without a session
- pass: both headers present and the POST unsubscribes (an ESP that injects the headers, read from a captured message, is the control, § 38)

#### V484. Export and erasure (`check-business-coverage` §5)
- the account page, the settings page, an API-only path, an asynchronous request with an SLA
- pass: export and deletion complete as the user, records of fact kept (mobile in-app deletion is mobile G7's, § 42)

### Sources (business)

The business research catalog (2026-10-19) § 1–5 and its two notes (money, tax, compliance and
reporting; ledger, state, pricing, time and proofs) give the classes, the tools and their versions
(fast-check 4.10.2, Hypothesis 6.170.1, rapid 1.3.0, KoSIT validator 1.6.3 with XRechnung
configuration 3.0.2, Peppol BIS 3.0.21, dbt-utils 1.4.1, Stripe test clocks), the precedents and the
per-class variants above; Ruby `money` 7.0's default-rounding change is from its UPGRADING notes
(2026-07-31). The batch-7 business eval (2026-10-19) gives the detectors and the oracle list; the
integrator assigned V450–V489 (eval V409–V438 remapped). Paraphrased; no text reproduced.

---

## Learning

A learning claim says the AI knowledge layer tells an agent something this repository no longer
makes true. The layer is `CLAUDE.md` and its `@import` closure, `AGENTS.md`, `ai/**`,
`.claude/codebase-profile.md`, the extraction oracle, `.claude/rules/**` and the live anchor block
of every installed agent, command, skill and pack pattern. The claim fails when:
- a path, symbol, command, pattern or ADR id it names resolves to nothing;
- an engine, driver, id scheme or framework major contradicts the lockfile;
- a count, an index or an anchor was derived from a source that has since changed;
- a cited line no longer says what the claim says;
- a memory entry's evidence moved, or a consumer cannot read the format the sink declares;
- an ADR's supersede link runs one way, or its chosen option is absent;
- the file never loads, or loads past its budget.

Reading one side settles none of these. Every oracle names a **tier**
([`precedents/learning.md`](precedents/learning.md) § The claim, restated):
- **S**: two-ended static. The knowledge `file:line` quoted, and the truth beside it: a
  `git ls-files` miss with the commit that renamed or deleted the target, the lockfile line, the
  cited line at HEAD, the ADR's status line, the loader's rule.
- **T**: an engine exit. The owning engine re-run on that site (`--only=<file>:<line>`) prints the
  row before the edit and nothing after it.
- **U**: regenerate twice. A derived file (anchor blocks, the decision index, the cheatsheet, the
  digest) is regenerated from its source twice; the second run is byte-identical (`cmp`, never
  mtime) and the engine is quiet.

Settled questions are in [`precedents/learning.md`](precedents/learning.md). This section is
self-contained: its V-numbers (V490–V509) are cited by the learning detectors, `/audit-knowledge` and
`/refresh-knowledge --from-audit` only, and no V outside this range is reused for a learning class.

Users:
- the detectors `knowledge-ref-scan` (§1–§6, engine `knowledge-refs.py` with the shared reader
  `kn_common.py`), `knowledge-fact-scan` (§1–§7, `knowledge-facts.py`), `memory-hygiene-scan`
  (§1–§9, `sink-audit.py`), `decision-record-scan` (§0–§4, `adr-index.py`) and `context-load-scan`
  (§1–§5, `load-budget.py`) (learning pack);
- `/audit-knowledge`, which runs all five read-only, with `@knowledge-curator` as judge and
  `@verifier` mode `refute` on every HIGH it keeps;
- `/refresh-knowledge --from-audit`, which closes each row failing first with the engine re-run as
  the probe.

**Owned elsewhere.** These classes keep their own sections or checks; learning reads them as
corroboration and never re-proves them:
- a convention claim the code majority contradicts (KN-10) → § Align (`convention-oracle`
  AL-03/04);
- human docs (README, `docs/**`, runbooks written for people, diagrams) → § Documentation
  (`doc-drift-scan` V433). An ADR supersede pair in a human-docs ADR home is also V447
  (`doc-structure-scan` §6); the same pair is one finding, deduped by `file:line`, and V504 and
  V447 assert the same two links;
- a secret in a context or memory file (KN-34) → security `secret-scan-method`; hidden Unicode or
  injection-shaped content (KN-35) → security `sast-scan` (trojan-source lane), proven with
  [`exploit-payloads.md`](exploit-payloads.md);
- unmarked claims, a sampled oracle, a stale approval stamp and a missing ADR for a dependency
  (KN-16, 17, 18, 30) → `/setup-project-health` checks 11, 7, 9 and 2 and `audit-setup.sh` C2v,
  whose own pass lines are the record.

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Seven rules hold for every
variant below:

- **Never write into the audited repo outside the fix.** The engines read, run read-only git with
  `GIT_OPTIONAL_LOCKS=0` and write nothing under the scanned root. A regenerate-twice run happens
  first in `git archive HEAD | tar -x -C "$TMPDIR/…"`; only the second, byte-identical output is
  applied. Print `find -newer <stamp>` on the audited root at the end of an audit; it must be
  empty.
- **Source wins, and the source is named.** The lockfile, `git ls-files`, the cited line at HEAD,
  the ADR file and the loader's documented rule decide. A claim is never "fixed" by editing the
  source to match it. The one exception is a decision: an Accepted ADR whose chosen option is
  absent from the code is put to the user (a superseding ADR, or the code change), never rewritten
  to bless the code.
- **Content, never mtime** ([`precedents/learning.md`](precedents/learning.md) § 13). Freshness is
  the recomputed projection of the source, or the commits since a declared derivation sha. A write
  that changes nothing still moves the mtime.
- **One root cause, one fix** (§ 17). N anchor copies of one stale bullet are regenerated from the
  generator (`apply-anchors.sh`) and counted as one finding with N sites. A derived file is never
  hand-edited.
- **Records are kept.** A memory entry is marked `RESOLVED → <sha>` or `SUPERSEDED` with a reason,
  never deleted. A pending decision promoted to an ADR is marked `PROMOTED → ADR-NNNN`. An ADR is
  superseded or amended, never deleted.
- **NOT-RUN is never PASS.** Engine exit 2, a census with no git (`census=find`, so RENAMED and
  DELETED cannot be told apart), a fact key with no lockfile (`UNREAD`), and a sink the engine could
  not parse: each variant is `blocked`, never green.
- **Fail first, pass after, keep the decoys.** Every variant fires on the pre-fix tree for the
  stated reason and is quiet after. A row that is quiet before the edit is `not reproduced`, and no
  edit is made. The precedent decoys (history files, abbreviations, history-marked facts, imported
  `AGENTS.md`, HTML-comment lines) stay quiet.

### Oracle taxonomy (learning)

| Oracle | Tier | Asserts | V |
|---|---|---|---|
| **Re-resolve** | S, T | the reference resolves under the ladder (exact, relative, alias, workspace package, unique suffix), or the line is gone | V490, V491, V492, V505 |
| **Typed-fact diff** | S, T | the claim's engine, driver, id scheme, framework or runtime major and package manager equal what the lockfile and manifests resolve | V494, V495, V498, V506 |
| **Regenerate twice** | U | the derived file regenerated from its source twice is byte-identical, and the engine is quiet | V493, V496 |
| **Citation window** | S | the cited `path:line` exists and its ±3-line window carries the claim's typed facts | V497 |
| **Entry re-check** | S, T | each open sink entry re-resolves, or carries a terminal state with a reason; pairs are judged with both quotes | V499, V500, V501 |
| **Enforcement** | T | a checkable lesson or promoted rule has a lint rule, hook, test or eval case that fails on a violating sample | V502 |
| **Consumer contract** | T | each consumer's pattern matches at least half the entries of the sink it reads | V503 |
| **ADR graph** | S | supersede links run both ways; superseded ids are not cited as current; the home is the one every consumer reads | V504, V505, V506 |
| **Loader truth** | T | what the host loads (effective lines, import closure, always-on rules, MEMORY.md head) is under its sourced budget; `AGENTS.md` loads where it is meant to | V507, V508 |
| **Oracle age** | S | the extraction oracle's census sha equals HEAD, or no commit since touches a cited path | V509 |

| V | Oracle | Asserts | Tier | Detector § |
|---|---|---|---|---|
| V490 | Re-resolve a path or xref | the path or pattern or ADR id resolves; a framework-only path is gone from the installed artifact | S, T | `knowledge-ref-scan` §1, §4, §5 (KN-01, KN-04, KN-05) |
| V491 | Symbol with successor | the RENAMED symbol is repointed to the successor `git log -S` names, or the DELETED symbol's line is gone | S, T | `knowledge-ref-scan` §2 (KN-02) |
| V492 | Command resolves and runs | the package script, make or just target, slash command, skill or agent resolves in a command set, and the documented invocation exits 0 in a scratch copy (or is a dry run the tool supports) | S, T | `knowledge-ref-scan` §3 (KN-03) |
| V493 | Marker and generator repair | one live `project-specific` pair per file after the generator re-runs, no framework path in the header, and a second run changes no byte | U | `knowledge-ref-scan` §5, §6 (KN-05, KN-15) |
| V494 | Typed fact | the typed-fact diff for the site is empty against the lockfile; across loaded files one value remains per key | S, T | `knowledge-fact-scan` §1, §4 (KN-07, KN-11) |
| V495 | Count recomputed | the count or range of the named set equals the tree's | S, T | `knowledge-fact-scan` §2 (KN-08) |
| V496 | Derived file regenerated | the index, cheatsheet, digest or anchor set regenerated from its source twice is byte-identical; N copies close with one regeneration | U | `knowledge-fact-scan` §5, §7 (KN-13, KN-12) |
| V497 | Citation window | the cited line exists and its ±3 window carries the claim's typed facts | S | `knowledge-fact-scan` §6 (KN-14) |
| V498 | Module map | every member directory with ≥ 5 tracked files is named in the map, and no listed module is gone | S, T | `knowledge-fact-scan` §3 (KN-09) |
| V499 | Sink entry re-resolves | the open entry's citations resolve (path tracked, line ≤ EOF, symbol within ±3), or the entry carries a terminal state and a reason | S, T | `memory-hygiene-scan` §1 (KN-20) |
| V500 | Duplicate merged, contradiction resolved | one entry remains with both citations; a contradiction is resolved by a newer explicit statement or a superseded mark, both quotes on record | S | `memory-hygiene-scan` §2, §3 (KN-21, KN-22) |
| V501 | Provenance and lifecycle | every open entry has a date, a source and a citation (or "user, <date>"); no entry sits past its promotion threshold without a state and a reason; a universal lesson has ≥ 2 cases or a safety reason | S, T | `memory-hygiene-scan` §4, §5, §6 (KN-23, KN-24, KN-25) |
| V502 | Lesson becomes enforcement | the checkable lesson's lint rule, hook or test fails on a violating snippet and passes on the fixed one; a promoted rule has an eval case whose MUST fails on a violating answer | T | `memory-hygiene-scan` §7, §9 (KN-26, KN-36); `/eval --coverage` |
| V503 | Consumer reads the format | each consumer contract matches ≥ 0.5 of the sink's entries, or the consumer reads the sink's declared `## Format per entry` | T | `memory-hygiene-scan` §8 (KN-27) |
| V504 | ADR reciprocity | the superseding ADR names what it supersedes and the superseded one names its successor; a partial supersede is `Amended by` | S | `decision-record-scan` §1, §2 (KN-28) |
| V505 | ADR home and citations | every consumer reads and writes the detected home; a superseded or retired id cited as current is repointed to its successor | S, T | `decision-record-scan` §0, §3 (KN-29, KN-28) |
| V506 | Chosen option present | the Accepted ADR's chosen package is in a manifest or the lockfile; a rejected option is never checked | S | `decision-record-scan` §4 (KN-28) |
| V507 | Load budget | effective `CLAUDE.md` lines, the import closure, always-on rule tokens, MEMORY.md head and per-tool limits are under their sourced budgets, re-measured after the change | T | `context-load-scan` §1 (KN-31) |
| V508 | `AGENTS.md` loads | `CLAUDE.md` imports `@AGENTS.md`, or one is a symlink to the other; `/memory` lists the file in a session | S, T | `context-load-scan` §2 (KN-32) |
| V509 | Oracle at HEAD | the extraction oracle exists and its census sha equals HEAD after the refresh, with its approval stamp carried over unchanged | S | `context-load-scan` §4 (KN-19) |

KN-33 (vague rule text) has no V of its own: it is advisory and never a finding.

### Harnesses (learning)

- **Re-run one site** (every S and T variant):
  `python3 -I .claude/skills/<skill>/scripts/<engine>.py . --only=<file>:<line>`. It exits 1 with
  the row while the site fails, 0 once it is quiet, 2 when a lane is blocked. The engines are
  `knowledge-refs.py`, `knowledge-facts.py`, `sink-audit.py` and `adr-index.py`. `load-budget.py`
  re-measures the whole repo with `--classes=<n>`. Every engine's `--self-test` covers each class's
  seed and decoy. `--expand` lists every site of a grouped row, and that list is the whole-class
  check after a fix.
- **Regenerate twice** (V493, V496): regenerate in a scratch copy, then run the generator again and
  `cmp` the two outputs. Anchors: `bash ~/.claude/scripts/apply-anchors.sh "$COPY" --apply`. It
  re-anchors the five profile facets when `codebase-profile.md` changed, rewrites the legacy header
  and reports a corrupt marker set without touching it. Index, cheatsheet and digest:
  `@knowledge-curator` § 8. A second run that changes a byte is a non-idempotent generator: the
  variant fails.
- **Lockfile truth** (V494, V495, V506): the ledger's `truth` lines from `knowledge-facts.py`, read
  from the lockfile on disk (pnpm 9, npm 7+, yarn, poetry, uv, go.mod, Gemfile.lock,
  composer.lock). No lockfile → `UNREAD`, never consistent.
- **Reconcile on write** (V500, V501): `sink-audit.py . --entry=<sink>:<line>` checks a new entry
  against every other entry (duplicate, contradiction) and its own provenance before
  `/learn-from-task` appends it.
- **Eval coverage** (V502): `sink-audit.py . --eval-coverage` prints cases, guards, units and the
  unguarded list as JSON; `/eval --coverage` grades from it.
- **ADR table** (V504, V505): `adr-index.py . --list` prints id, file, status, superseded-by and
  supersedes, before and after the fix.
- **Loader** (V507, V508): `load-budget.py .` with the budgets it prints (CLAUDE.md 200 effective
  lines and 4 import hops, from the memory docs; rule tokens 12,000 from `audit-setup.sh` C2u;
  MEMORY.md 200 lines or 25,600 bytes, only with `--memory-dir`). In a live session, `/memory`
  lists what loaded.

### Class variants (learning)

A fix passes the class only when every variant the class takes in the layer present passes the
oracle, and the decoy the precedents exempt is untouched.

#### V490. Re-resolve a path or cross-reference (`knowledge-ref-scan` §1, §4, §5)
- the change: `git mv` rename, directory move, delete, case-only rename (fails on macOS through `test -e`, so resolve through `git ls-files`)
- the reference: a markdown link, an inline backtick, a fence token, a reference-style definition, an HTML `href`, an `@import`
- the path: relative `../`, root-relative, bare `x/`, an alias `@/lib/x` (live and dead), `path#anchor`, `path:12`, `path:12-20`
- the xref: `ai/patterns/x.md` cited but never installed; `ADR-0042` in a live anchor (a row) and in a pack-generic body (no row); `scripts/apply-anchors.sh` in an installed artifact where the project has no such file (a row) and where it has one (no row)
- pass: `--only` quiet on every site `--expand` listed; an abbreviation that resolves by unique suffix, a gitignored output, a placeholder and a history file stay quiet (precedents § 1, § 3, § 4, § 6)

#### V491. Symbol with successor (`knowledge-ref-scan` §2)
- a deleted function; a renamed function (the successor is named); a function moved to another file (no row); `Class.method`; a symbol that survives only in a comment (a row, § 12)
- pass: the repointed name resolves in tracked non-doc source, or the line is gone (an external symbol never in history is the control, § 5)

#### V492. Command resolves and runs (`knowledge-ref-scan` §3)
- a package script renamed; a script present in one workspace manifest and not another; a slash command uninstalled; a skill renamed
- pass: the command resolves in the project, global or plugin set and the invocation runs in a scratch copy (a global command, a `/api` route segment and `pnpm install` are the controls, § 23, § 33)

#### V493. Marker and generator repair (`knowledge-ref-scan` §5, §6)
- a doubled start marker; a start without an end; an end without a start; six live blocks in one file; the generator's framework path in every anchor header
- pass: after `apply-anchors.sh --apply` one live pair per file and no framework path in the header; a second run prints no REPAIR, RELEV, REANCHOR or HEADER row and `cmp` finds no byte changed (a marker inside a fenced example is the control)

#### V494. Typed fact (`knowledge-fact-scan` §1, §4)
- the lockfile resolves `@mikro-orm/postgresql` and an anchor says MySQL (a row); a `uuidv7` dependency and "ULID PKs" (a row); "React 18" with 19 locked (a row); Node 20 in `CLAUDE.md` and 22 in `AGENTS.md` (a row)
- pass: `--only` quiet on every site and one value per key across loaded files (`engines.node >=18` with "Node 22", a multi-engine capability line in a generic body, a disabled `mysql` MCP stub, env-named ports and "was MySQL, now Postgres" are the controls, § 9, § 10, § 14)

#### V495. Count recomputed (`knowledge-fact-scan` §2)
- "every file 0001–0033 has a row" with 0001–0040 on disk; "12 modules" with 14 member directories; a stale artifact-count table
- pass: the count equals the tree's ("about 30 modules", "as of <date>" and a count whose set is not named are the controls, § 28)

#### V496. Derived file regenerated (`knowledge-fact-scan` §5, §7)
- an ADR added and the index not regenerated; a convention changed and the cheatsheet not regenerated; the profile corrected and the anchors not regenerated (177 copies, one finding); a digest naming a removed phase
- pass: the regenerate-twice harness, then the engine quiet on every site (an mtime bump with no content change is the control, § 13)

#### V497. Citation window (`knowledge-fact-scan` §6)
- the cited line deleted; the cited line rewritten to a different fact; the cited file shortened past the line
- pass: the window carries the claim (a 2-line shift with the same text is the control; an aggregate claim stays Unconfirmed, § 27)

#### V498. Module map (`knowledge-fact-scan` §3)
- a deleted module still listed; a module with ≥ 5 tracked files unlisted
- pass: the map names every such directory (a summary row `features/*` and a directory under 5 files are the controls)

#### V499. Sink entry re-resolves (`memory-hygiene-scan` §1)
- an entry citing a deleted path; an entry citing line 205 of a 120-line file; a learning citing a removed rule
- pass: the entry re-resolves, or carries `RESOLVED → <sha>` or `SUPERSEDED` with a reason (a RESOLVED entry citing a deleted path and a preference entry are the controls, § 19)

#### V500. Duplicate merged, contradiction resolved (`memory-hygiene-scan` §2, §3)
- the same correction recorded twice; the same failure twice; two learnings with opposite rules on one subject; a feedback entry contradicting `CLAUDE.md`
- pass: one entry with both citations; the contradiction resolved by the newer explicit statement and the other marked, both quotes in the run ledger (an index line plus its topic file and a superseded pair are the controls, § 18, § 14)

#### V501. Provenance and lifecycle (`memory-hygiene-scan` §4, §5, §6)
- an undated entry; an entry with no `Where` or `Source`; a READY pattern past its threshold, unpromoted; a `Repeated: 3` feedback unpromoted; "never use transactions" from one incident
- pass: date, source and citation present; the entry promoted or its state recorded with a reason; the universal lesson narrowed or given a second case (a "user, <date>" entry and a one-incident safety lesson are the controls, § 19, § 20)

#### V502. Lesson becomes enforcement (`memory-hygiene-scan` §7, §9; `/eval --coverage`)
- "never import axios directly" with no lint rule; "run migrations with lock_timeout" with no check; a promoted rule with no eval case; a case with no MUST assertion
- pass: the new lint rule, hook or test fails on a violating snippet before it is wired and passes on the fixed one; the eval case's MUST fails on a violating answer (a judgment rule and a convention routed to align are the controls)

#### V503. Consumer reads the format (`memory-hygiene-scan` §8)
- the drift log redefined and `session-start.sh` greps `^Severity:`; learned patterns written without `Status:`; the curator's `status OPEN` against a sink with no Status field
- pass: the ratio is ≥ 0.5, or the consumer reads the declared `## Format per entry` (a sink declaring its own format, read correctly, is the control, § 24)

#### V504. ADR reciprocity (`decision-record-scan` §1, §2)
- a supersede with no back link; a Superseded status naming no successor; a status that is not a lifecycle word
- pass: both links present and `--list` shows the pair (a partial supersede marked `Amended by` and a correct reciprocal pair are the controls, § 29)

#### V505. ADR home and citations (`decision-record-scan` §0, §3)
- ADRs in `docs/decisions` while `/promote-decision` writes and health check 2 reads `ai/decisions`; a superseded ADR cited as current in `CLAUDE.md`
- pass: every consumer reads the home `adr-index.py --list` resolves; the citation repointed (a history-marked citation and a dated file name are the controls, § 14, § 30)

#### V506. Chosen option present (`decision-record-scan` §4)
- an Accepted "Express" ADR with only Fastify in manifests; a chosen package removed in an upgrade
- pass: the chosen package is present, or the user has written a superseding ADR (a rejected option in "Considered options" is the control, § 2)

#### V507. Load budget (`context-load-scan` §1)
- `CLAUDE.md` at 205 effective lines; always-on rules over the token budget; a `globs:`-only rule counted as path-scoped; MEMORY.md at 26 KB; a Copilot file past 4,000 characters
- pass: re-measured under every budget after the move (a 260-line `CLAUDE.md` whose 80 lines are an HTML block comment and `paths:`-scoped rules are the controls, § 21, § 22)

#### V508. `AGENTS.md` loads (`context-load-scan` §2)
- `AGENTS.md` beside `CLAUDE.md` with no import and no symlink
- pass: `@AGENTS.md` in `CLAUDE.md`, or a symlink; the row stays Unconfirmed when the user setting may load it (a symlinked pair is the control, § 16)

#### V509. Oracle at HEAD (`context-load-scan` §4)
- the census sha behind HEAD with commits touching cited paths; the oracle absent in a member that has a profile
- pass: after `/refresh-knowledge` the census sha equals HEAD and the approval stamp is byte-identical to before (a repo with no commit since the census is the control)

### Sources (learning)

The learning research catalog (2026-10-19) § 1, § 4 and § 5 give the classes KN-01…KN-36, the
precedents and the per-class variants above. Its notes cite DOCER (Tan, Wagner, Treude, EMSE 2024),
ReCite (ASE 2026), dos Santos (SCAM 2026), the Claude Code memory docs (fetched 2026-10-19: 200-line
guidance, 4-hop imports, MEMORY.md 200 lines or 25 KB, `AGENTS.md` selection), the GitHub Copilot
code review docs (fetched 2026-10-19: 4,000 characters), MADR 4.0.0 and Nygard (2011). The batch-7
learning eval (2026-10-19) gives the detectors, the engines and the oracle list; the integrator
assigned V490–V509. Paraphrased; no text reproduced.

---

## AI engineering

An AI engineering claim says the code **around** a model call breaks under a condition the provider
documents: a truncated, refused or malformed answer is stored as complete, a loop never stops, a
retry stack outlives the caller's deadline, a failed turn is charged, a model id is past its
retirement date, a parameter is a 400 on the model the call reaches, a prompt change merges with no
eval, a filtered retrieval loses its recall, an injected instruction reaches a tool. None of these
is proved by asking the model. Every oracle here asserts the **deterministic shell** around the
model, and every oracle names a **family**:
- **S**: a two-ended static fact — the inventory row and the line that lacks the control, the index
  definition and the ingest write, the eval job and the line that masks its exit.
- **T**: a tool exit recorded in this run — `llm-sites.py` (`--models --strict`, `--evals`), a
  promptfoo exit code (100 = test failures), a built-bundle grep.
- **U**: a scripted-model test, written before the fix and failing on the current code. The provider
  transport is replaced by a stub that returns a scripted completion, tool call, stop reason, error,
  delay or stream (V510), and the test asserts the gate, the counter, the ledger, the abort or the
  stored record.
- **L**: a live eval or red-team run against a non-production key and model, pinned and with
  telemetry off, only on the user's word.

Settled questions are in [`precedents/ai-engineering.md`](precedents/ai-engineering.md). This
section is self-contained: its V-numbers (V510–V539) are cited by the ai-engineering detectors, the
security pack's LLM trust-boundary detectors and judges, and the fix commands that close them; no V
outside this range is reused for an AI class. OWASP ids are labelled OWASP LLM Top 10 2026 v1.0
(2026-08-03).

Users:
- the detectors `llm-gateway-audit` (§1 seam, §B1–B5 budgets, §L1–L2 loops, §M1–M2 metering),
  `prompt-audit` (§S1–S5 structured output, §V1–V3 model lifecycle and parameters, §P prompts),
  `eval-run` (§C1–C8 coverage lane, run lane), `retrieval-eval` (§1–§5) and `vector-index-audit`
  (§1–§5) (ai-engineering pack), all reading `llm-sites.py`'s inventory first;
- the security pack's LLM trust-boundary detectors (`llm-trust-scan` §1 prompt roles, §2 tools and
  agency, §3 output, §4 secrets and data, §5 tracing content, §6 retrieval and caches;
  `mcp-server-scan` §1–§7), judged by `@llm-security-reviewer`, when the security pack ships them;
- `@ai-feature-reviewer` (refute mode) and `/ai-audit`, with `@verifier` mode `refute` on every
  BLOCKER and HIGH it keeps; `/add-ai-feature`, which writes each engineering finding's
  failing-first test from its V-number; `/security-fix` for V510–V525.

**Owned elsewhere.** These classes keep their own sections; AI reads them as corroboration and never
re-proves them:
- model output reaching SQL, a shell, `eval`, HTML, a path or a URL → the sink owners' payloads in
  [`exploit-payloads.md`](exploit-payloads.md) (the trust detectors supply the completion source);
- a check-then-debit race on AI credits, a double charge on redelivery, a missing generation rate
  limit (CO-1, CO-12, CO-9) → `exploit-payloads.md` § 19 and the `logic-race-scan` oracles;
- prompt and completion text in application logs (LG-1) is asserted by V519 but owned by security
  `data-exposure-scan` §6; batch LLM work on a request path and `retry-after` loops → § Performance
  and § Distributed; spend, budgets and anomaly alerts → the finops section.

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Seven rules hold for every
variant below:

- **Stub the transport, never the code under test.** The scripted model replaces the provider client
  or the HTTP call at its edge (an injected transport, `nock` / `msw` / `respx`, a fake client
  passed to the seam); the seam, the loop, the meter, the parser and the gate run for real.
- **Never ask the model whether the code is right.** A live model's answer is not an oracle; a
  classifier or guardrail library is not a gate (`precedents/ai-engineering.md` § 29).
- **Dated facts only.** A model id, a retirement date, a parameter rule, an SDK default or a
  framework loop cap comes from `model-lifecycle.tsv` (with its `checked_on`), the lockfile, or a
  provider page fetched and dated in the run. A STALE table makes V532 `blocked`.
- **Read-only on the audited repo.** `llm-sites.py` refuses an `--out` inside a scanned root; eval
  tools write under `$RUN/eval/` with `HOME` pointed into it.
- **Telemetry off, pinned, the user's word.** promptfoo `PROMPTFOO_DISABLE_TELEMETRY=1
  PROMPTFOO_DISABLE_UPDATE=1 PROMPTFOO_DISABLE_REDTEAM_REMOTE_GENERATION=1`, DeepEval
  `DEEPEVAL_TELEMETRY_OPT_OUT=1 DEEPEVAL_DISABLE_DOTENV=1`, Ragas `RAGAS_DO_NOT_TRACK=true`, plus
  `CI=true DO_NOT_TRACK=1`; the project's installed binary or the lockfile's version; a
  non-production key and model. Snyk Agent Scan sends tool descriptions to its vendor and can launch
  configured MCP servers: never without consent. Family L is `NOT-RUN` unless the user names it.
- **Money and state are asserted exactly.** A ledger row count, a balance in minor units, a stored
  status: never "roughly once".
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix code for the
  stated reason, passes after, and the benign control a precedent names (a fenced tool result, a
  turn-keyed debit, an aggregate deadline, a one-step `generateText`, a namespace per tenant, a
  migration-seeded read-only knowledge base) is unchanged.

### Oracle taxonomy (AI engineering)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Scripted-model harness** | U | the shell around a stubbed model refuses, stops, counts, aborts, settles or rejects as the policy says | V510 (base), V511–V516, V526–V531, V534, V535 |
| **Two-tenant / two-user canary** | U, S | a value seeded for tenant A never reaches tenant B through a tool, a query, a cache or an MCP handler | V512, V520 |
| **Capture assertion** | U | the prompt builder, the log sink, the span exporter or the built bundle holds no secret, no unminimised personal data, no content attribute | V517, V518, V519 |
| **Protocol request** | U | the MCP server answers a hostile audience, origin, URL scheme, scope or session as the spec requires | V521–V525 |
| **Inventory tool exit** | T | `llm-sites.py --models --strict` exits 0; every id resolves; the table is not stale | V532 |
| **Recorded request** | U, L | the request built for each configured model id carries only the parameters that model accepts | V533 |
| **Eval gate** | T, L | a prompt edit on a branch runs the eval in CI and a planted failing case turns the job red | V536, V537 |
| **Static join** | S | the version reaches log, cache key and usage row; no provider import outside the seam | V538 |
| **Retrieval run** | U, L | filtered and unfiltered recall at the target; a deleted document absent; a re-index after a model change | V539 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V510 | Scripted-model harness (base) | the transport stub returns a scripted completion, tool call, stop reason, error, delay or stream; the code under test is unchanged; the assertion is on the deterministic shell | U | every U row |
| V511 | Injection corpus | indirect instructions in a retrieved document, a tool result, an email, a file name and a memory write: the tool spy records zero calls to the protected tool and a planted canary never leaves | U, L | `llm-trust-scan` §1, §2, §6 (PI-*, AG-5, RG-5); `eval-run` §C8 (EV-8) |
| V512 | Two-tenant canary | a tool, a vector query or an MCP handler called by tenant B with tenant A's id in the model's arguments returns nothing of A's; the query parameter equals the session's | U, S | `llm-trust-scan` §2, §4, §6 (AG-1, AG-2, SD-3, RG-1…3); `mcp-server-scan` §6 (MC-6) |
| V513 | Approval cannot be forged | an approval token minted in turn N is refused in turn N, for another tool, other arguments or another actor; the catalogue in a read-only mode holds no write tool | U | `llm-trust-scan` §2 (AG-3, AG-6, AG-7) |
| V514 | Tool-argument fuzz | `file://`, a metadata IP, `../`, `; id` and an over-long value in each tool argument are rejected by the server-side schema before the sink | U | `llm-trust-scan` §2 (AG-4) |
| V515 | Render and request spy | rendering a model answer with a markdown image, a link and a Mermaid block issues no network request; images render as links | U | `llm-trust-scan` §3 (OH-2) |
| V516 | Re-derived field | a model-chosen price, quantity, status or role is recomputed or re-checked server-side; a scripted over-posted value never persists | U | `llm-trust-scan` §3 (OH-6) |
| V517 | Prompt-builder snapshot | the assembled prompt for a seeded user holds no secret, connection string or internal URL, and only the fields the transfer register lists | U | `llm-trust-scan` §4 (SD-2, SD-4) |
| V518 | Bundle grep | the built client bundle (web, mobile, desktop) holds no provider key prefix and no server-only env name | T, S | `llm-trust-scan` §4 (SD-1) |
| V519 | Capture exporter | an in-memory span exporter and a captured log sink hold no prompt, completion or tool-argument content under the production config | U | `llm-trust-scan` §5 (LG-2…4); `data-exposure-scan` §6 (LG-1) |
| V520 | Semantic-cache paraphrase | a paraphrase of tenant A's cached question asked by tenant B misses the cache | U | `llm-trust-scan` §6 (RG-4) |
| V521 | Audience | a token minted for another resource is refused 401; the server never forwards the caller's token upstream | U | `mcp-server-scan` §1 (MC-1) |
| V522 | Origin and bind | a request with a hostile `Origin` is refused 403; a local server binds 127.0.0.1 | U | `mcp-server-scan` §2 (MC-2) |
| V523 | URL scheme | a `javascript:`, `file:` or shell-metacharacter authorisation URL is refused before anything opens it | U | `mcp-server-scan` §3 (MC-3) |
| V524 | Tool-list pin | CI fails when the hash of the tool names, descriptions and schemas changes without a reviewed update; hidden Unicode in a description fails it | T | `mcp-server-scan` §4 (MC-4) |
| V525 | Scope and session | a tool outside the token's scope answers the scope challenge; a replayed or guessed session id is refused | U | `mcp-server-scan` §5, §7 (MC-5, MC-7) |
| V526 | Loop cap and context trim | an always-tool-call stub stops at the configured cap with a recorded terminal reason; a conversation of twice the window takes the trim path, never a 400 or a silent truncation | U | `llm-gateway-audit` §L1, §B2 (CO-5, CO-6) |
| V527 | Upstream-call counter | under a permanent 500 and a permanent timeout, upstream calls per logical request and the wall time stay within the stated budget, counting SDK, app and queue layers | U | `llm-gateway-audit` §B1 (CO-7, TF-1) |
| V528 | Metering timeline | provider error, timeout, abort, refusal and truncation each leave the ledger the stated policy names; a recorded usage fixture with cache and reasoning tokens bills the provider's total; an unknown model id raises; two identical requests read the prompt cache | U | `llm-gateway-audit` §M1, §M2, §B5 (CO-2…4, CO-10, CO-11) |
| V529 | One side effect | a tool that succeeds and then has its step fail and re-run produces one email, order or charge | U | `llm-gateway-audit` §L2 (CO-8) |
| V530 | Deadline and disconnect | a stub that sleeps past the caller's deadline is aborted upstream; a client disconnect after one chunk closes the upstream stream | U | `llm-gateway-audit` §B1, §B4 (TF-1, TF-4) |
| V531 | Fallback and mid-stream error | a 529 on the primary uses the fallback, logs it and passes the same schema, while a 400 is not retried elsewhere; an SSE error after two deltas marks the record failed | U | `llm-gateway-audit` §B3, §B4 (TF-3, TF-5) |
| V532 | Model ids resolve | every model id in code, `.env*`, IaC, eval configs and fallback lists resolves against the dated table or the provider's model list; boot fails on a bad env id; `llm-sites.py --models --strict` exits 0 | T, U | `prompt-audit` §V1, §V2 (MV-1…3, MV-5); `eval-run` §C7 (EV-7) |
| V533 | Parameter contract | the request recorded for each configured model id carries only the parameters that model accepts (sampling, `thinking`, prefill, forced `tool_choice`, `max_tokens` vs `max_completion_tokens`, a large non-streaming `max_tokens`) | U, L | `prompt-audit` §V3 (MV-4, TF-2, PM-3) |
| V534 | Output handling | truncated, refused, incomplete, malformed and over-posted fixtures through the real consumer: handled, never persisted, executed or charged as complete; validation retries bounded | U | `prompt-audit` §S1–§S4 (SO-1…5) |
| V535 | Strict schema | the request carries `strict: true` (or the provider's equivalent) and a schema-violating stub answer is rejected | U | `prompt-audit` §S5 (SO-6) |
| V536 | Eval gate fires | a prompt edit on a branch triggers the eval job; a planted failing case turns it red through the tool's own exit map (promptfoo 100) | T, L | `eval-run` §C1, §C2, §C3, §C6 (EV-1…3, EV-6); `prompt-audit` §V1 aliases (MV-2) |
| V537 | Judge and leakage | pairwise judge cases run in both orders with the same verdict; judge agreement on a human-labelled calibration set is stated; dataset × prompt overlap is 0 | T, L | `eval-run` §C4, §C5 (EV-4, EV-5) |
| V538 | Attribution and seam | the prompt version reaches the log line, the cache key and the usage row; no provider import or wire call exists outside the seam | S, U | `prompt-audit` §P (PM-1, PM-2); `llm-gateway-audit` §1 (CS-1) |
| V539 | Retrieval and index | recall@k with the filter applied is within tolerance of unfiltered and at the target; a deleted document is absent; an empty retrieval takes the no-source path; a model change re-indexes | U, L | `retrieval-eval` §1–§5, `vector-index-audit` §1–§5 (RG-6…10) |

### Harnesses (AI engineering)

- **Inventory** (every row): `python3 -I -B .claude/skills/llm-gateway-audit/scripts/llm-sites.py .
  --out="$RUN/inv" --models --evals` (exit 0 ran, 2 blocked, 4 `--strict` gate); `--self-test` covers
  each lane's seed and decoy. The fix's re-check is the same command on the patched tree: the
  candidate row's column changes (a timeout, a stop-reason read, a model id) or disappears.
- **Scripted model** (V510 and every U row), per stack:
  - TS / Node: inject the transport the seam takes, or intercept the HTTP call (`nock`, `msw`,
    `undici` `MockAgent`); for the AI SDK, `MockLanguageModelV2` / the version's mock model from
    `ai/test` (read the lockfile's major); Vitest or Jest fake timers for deadlines.
  - Python: a fake client passed to the seam, or `respx` / `pytest-httpx` at the HTTP edge;
    LangChain `FakeListChatModel` / `GenericFakeChatModel` for chains and graphs.
  - Go: an `httptest.Server` behind `option.WithBaseURL`; `context.WithTimeout` for deadlines.
  - Streams: the stub writes SSE frames (`data: …`) with a scripted error event or stalls between
    frames; the test closes the client side to model a disconnect.
- **Counters and ledgers** (V527, V528, V529): count stub invocations per logical request; read the
  ledger and balance rows from the project's real persistence on a scratch database.
- **Capture** (V517, V519): an in-memory span exporter (OpenTelemetry `InMemorySpanExporter`) and the
  logger's test transport; assert on attribute keys and message text.
- **Protocol** (V521–V525): the MCP server started in-process, called over its transport with a
  crafted token, `Origin`, URL or session; the OAuth rows read `@auth-reviewer`'s corroboration.
- **Models** (V532, V533): `llm-sites.py --models --strict --today=<release date>`; a recorded request
  per configured id through the real request builder, compared with the parameter contract the run
  read from the provider page (dated).
- **Evals** (V536, V537): the project's harness in a scratch branch with a planted failing case; the
  CI job run locally where the platform allows (`act` for GitHub Actions is NOT-RUN unless named).
- **Retrieval** (V539): the project's retriever over the labelled set, filter on and off, on a
  non-production index.

### Class variants (AI engineering)

A fix passes the class only when every variant the code presents passes the oracle, and the control
the precedents exempt is unchanged.

#### V510. Scripted-model harness (base)
- a completion; a tool call; each stop reason (`stop`, `length`, `max_tokens`, `tool_use`, `refusal`, `content_filter`, `incomplete`); a 4xx, a 429, a 5xx, a 529, a timeout; a stream with a mid-stream error; a stream stalled between frames
- pass: the test fails on the pre-fix code for the stated reason and passes after, with no change to the code under test other than the fix

#### V511. Injection corpus (`llm-trust-scan` §1, §2, §6; `eval-run` §C8)
- every untrusted origin: a retrieved document, a tool result, an email body, a PR or issue body, a file name and OCR text, a CSV cell, a marketplace title, a tool error that echoes input, a memory write, an agent-to-agent handoff, hidden Unicode tag characters
- pass: the protected tool's spy records zero calls and the canary appears in no egress (HTTP, email, rendered link) (a fenced, labelled tool result with write tools withdrawn is the control, `precedents/ai-engineering.md` § 2, § 3)

#### V512. Two-tenant canary (`llm-trust-scan` §2, §4, §6; `mcp-server-scan` §6)
- every tool, every resource handler, every vector query and every cache read; ids in the model's arguments; filter values from the request body
- pass: tenant B never receives A's canary and the query parameter equals the session's (a namespace derived from the session is the control, § 19)

#### V513. Approval cannot be forged (`llm-trust-scan` §2)
- same turn; another tool; changed arguments; another actor; a replayed token; a tool added by MCP or a plugin; a read-only mode
- pass: each is refused and the catalogue is narrowed in code (a token bound to tool, argument hash, actor and an earlier turn is the control, § 3)

#### V514. Tool-argument fuzz (`llm-trust-scan` §2)
- URL, path, SQL fragment, shell metacharacter, over-long string, extra property
- pass: the server-side schema rejects each before the sink (the sink's own payloads stay with its owner)

#### V515. Render and request spy (`llm-trust-scan` §3)
- every renderer of model text: chat bubble, email, Slack post, PDF or export, Mermaid, SVG, link unfurl
- pass: no request leaves during render (an image rendered as a link is the control, § 8)

#### V516. Re-derived field (`llm-trust-scan` §3)
- price, discount, quantity, status, role, owner id in a parsed answer
- pass: the persisted value is the server's (a typed draft the user confirms is the control, § 9)

#### V517. Prompt-builder snapshot (`llm-trust-scan` §4)
- every prompt builder; every personal-data field the user record carries; env interpolation
- pass: no secret and only the register's fields (a transfer-register entry is the control, § 16)

#### V518. Bundle grep (`llm-trust-scan` §4)
- web, mobile and desktop bundles; `.env` files a mobile build ships; `NEXT_PUBLIC_` / `VITE_` / `EXPO_PUBLIC_` names
- pass: no key prefix and no provider key name in any shipped artifact (a bring-your-own-key local tool is the control, § 17)

#### V519. Capture exporter (`llm-trust-scan` §5; `data-exposure-scan` §6)
- app logs, spans (OTel GenAI capture flags), error trackers (`sendDefaultPii`), AI SDK telemetry `recordInputs` / `recordOutputs`, tracing SaaS masking
- pass: no content attribute under the production config (an error line that never carries upstream text is the control, § 10)

#### V520. Semantic-cache paraphrase (`llm-trust-scan` §6)
- exact cache, semantic cache, response cache; tenant and permission in the key
- pass: B's paraphrase misses A's entry

#### V521. Audience (`mcp-server-scan` §1)
- a JWT with another `aud`; an opaque token from another resource; a passthrough of the caller's token upstream
- pass: 401 and no upstream call carries the caller's token (authorisation and resource server as one app with DB-stored tokens is the control, § 11)

#### V522. Origin and bind (`mcp-server-scan` §2)
- a hostile `Origin`; a DNS-rebinding host; the bind address in every start script and container
- pass: 403 and 127.0.0.1 for a local server

#### V523. URL scheme (`mcp-server-scan` §3)
- `javascript:`, `file:`, `data:`, a URL with shell metacharacters, a metadata IP in discovery
- pass: refused before any open or fetch

#### V524. Tool-list pin (`mcp-server-scan` §4)
- names, descriptions, schemas; hidden Unicode; an unpinned `npx -y pkg@latest` server in a committed client config
- pass: CI fails on an unreviewed change

#### V525. Scope and session (`mcp-server-scan` §5, §7)
- each tool against each scope; a replayed, guessed or cross-user session id
- pass: the scope challenge and the refusal (a read-only catalogue with one scope is the control, § 12)

#### V526. Loop cap and context trim (`llm-gateway-audit` §L1, §B2)
- every loop entry point: agent, sub-agent, handoff, background job; caps on model turns, tool calls and wall clock; framework defaults by lockfile version
- pass: the run stops at the cap with a terminal reason; the overlong conversation is trimmed (a one-step `generateText` is the control, § 24)

#### V527. Upstream-call counter (`llm-gateway-audit` §B1)
- SDK retries, app retries, framework middleware, queue attempts, all counted together, per entry point
- pass: calls and wall time within the budget (retries on idempotent cheap calls are the control, § 23)

#### V528. Metering timeline (`llm-gateway-audit` §M1, §M2, §B5)
- success, provider error, timeout, abort, client disconnect, mid-stream error, refusal, truncation, schema failure, process shutdown; every billed feature in the product under one policy; streaming usage with and without the usage flag; cumulative deltas; cache and reasoning tokens; an unknown model id
- pass: each outcome leaves the ledger the policy states, the provider total is billed, the unknown id raises (a turn-keyed debit with a unique index is the control for double charge, § 14)

#### V529. One side effect (`llm-gateway-audit` §L2)
- framework tool retry; agent re-plan; queue redelivery; an approval-gated tool
- pass: one effect, keyed by the tool-call id

#### V530. Deadline and disconnect (`llm-gateway-audit` §B1, §B4)
- every streaming route (SSE and WebSocket); route `maxDuration`; proxy read timeout; worker job budget
- pass: the upstream call is aborted (an aggregate request deadline that aborts outbound calls is the control, § 10)

#### V531. Fallback and mid-stream error (`llm-gateway-audit` §B3, §B4)
- 529, 429, 5xx on the primary; a 400; an SSE `error` after HTTP 200
- pass: fallback used, logged and schema-valid; the 400 surfaces; the record is failed

#### V532. Model ids resolve (`prompt-audit` §V1, §V2; `eval-run` §C7)
- code, `.env.example`, IaC (Azure `versionUpgradeOption`, Bedrock ids), YAML configs, eval configs, fallback lists, price tables; aliases; the env value unset and garbage; Evals platform and `v1/prompts` calls
- pass: `llm-sites.py --models --strict` exits 0 and boot fails on a bad id (a retired id in a changelog, migration or 404 test is the control, § 28)

#### V533. Parameter contract (`prompt-audit` §V3)
- each configured model id (literal, env default, deployed value); sampling, `thinking`, prefill, forced `tool_choice`, `max_tokens` vs `max_completion_tokens`, `budget_tokens`, a large non-streaming `max_tokens`
- pass: the recorded request matches the dated contract for that id (no temperature on a model that rejects it is the control, § 27)

#### V534. Output handling (`prompt-audit` §S1–§S4)
- every consumer of model output (parser, tool executor, persister, biller) for every provider's truncation signal; phrasing drift for a scraped field; an always-invalid answer
- pass: handled, never persisted or charged as complete; retries bounded (field-by-field coercion into a confirmed draft is the control, § 9)

#### V535. Strict schema (`prompt-audit` §S5)
- every tool and response schema the code relies on
- pass: `strict` sent and a violating answer rejected

#### V536. Eval gate fires (`eval-run` §C1, §C2, §C3, §C6; `prompt-audit` §V1)
- the prompt, model and retrieval paths in the CI filter; `|| true`; `continue-on-error`; threshold 0; exit 100 mapped to 0; the merge requirement
- pass: the planted failing case turns the job red (recorded cassettes replayed are the control for EV-3, § 26)

#### V537. Judge and leakage (`eval-run` §C4, §C5)
- judge family vs generator family; order swap; calibration set; judge id pinned; dataset strings in few-shot examples
- pass: verdict stable under swap, agreement stated, overlap 0

#### V538. Attribution and seam (`prompt-audit` §P; `llm-gateway-audit` §1)
- log line, cache key, usage row, eval run; every provider import and wire call
- pass: the version is present in all four; no call outside the seam (a one-off script that still carries a budget is the control)

#### V539. Retrieval and index (`retrieval-eval` §1–§5; `vector-index-audit` §1–§5)
- filtered and unfiltered recall at k; an unanswerable question; a deleted and a revoked document; an embedding-model change; a metric or dimension change
- pass: recall at target with the filter applied, deleted and revoked content absent, the no-source path taken, the index rebuilt (a namespace per tenant and a migration-seeded read-only knowledge base are the controls, § 19, § 20)

### Sources (AI engineering)

The AI engineering research catalog (2026-10-19) § 1–5 and its two notes (injection, agency, output,
MCP and data; cost, reliability, pinning and evals) give the classes, the techniques (the
scripted-model harness, the wire-shape inventory, the metering timeline, the dated lifecycle join),
the precedents and the per-class variants above. Provider facts were read 2026-10-19: Anthropic
model deprecations, API errors, streaming, stop reasons and prompt caching; OpenAI deprecations,
structured outputs and the SDK READMEs; Gemini API deprecations; AI SDK loop control; LangGraph and
LangChain middleware; promptfoo telemetry and CI docs; the MCP specification 2025-11-25. OWASP ids
per OWASP LLM Top 10 2026 v1.0 (2026-08-03). The batch-8 ai-engineering eval (2026-10-19) gives the
detectors and the oracle list; the integrator assigned V510–V539. Paraphrased; no text reproduced.

## Data engineering

A data-engineering claim says a **derived copy** stops matching its source under a source row that
production delivers: a tie on the watermark, a row two days late, an update after the window, a hard
delete, a retry, a backfill of a range already loaded, a write during an export, a day with 23 hours,
a subject who asks for erasure — or that a data test cannot go red on the row it names. None of these
is proved by reading the SQL. Every oracle here runs the real model, loader, job or query on a
**scratch target** (duckdb built from committed seeds, a throwaway Postgres or MySQL container, a
rolled-back transaction) or cites a fact at both ends, and every oracle names a **family**:
- **R**: replay — the same batch, range, task or rollup pass run twice (or killed and rerun); the
  target's `count(*)` and a row checksum do not move.
- **L**: late and edge data — a tie row, a late row, an update after the window, a delete, an empty
  batch, a DST or local-midnight row inserted into the source between two runs.
- **C**: concurrency during a read — rows inserted, updated or deleted while a paged extract, a
  multi-table dump or a materialized-view refresh runs.
- **M**: mutation of a data test — a violating row planted in a scratch copy of the model's output;
  the test must go red.
- **T**: a build or tool exit recorded in this run — `dbt build` / `dbt parse` on a duckdb profile,
  `datacontract breaking`, `DagBag().import_errors`, `ruff --select AIR`, a CI job run on a branch.
- **S**: a two-ended static fact — the effective config value and its source plus the source's
  behaviour; the trigger's column list and the derived row's source columns; the erasure list and the
  derived table.
- **D**: dry-run bytes — `bq query --dry_run` or `EXPLAIN` before and after the predicate fix; never
  a measured warehouse query without the user's word.

Settled questions are in [`precedents/data-engineering.md`](precedents/data-engineering.md). This
section is self-contained: its V-numbers (V540–V569) are cited by the data-engineering detectors, its
judges and `/data-fix`; no V outside this range is reused for a data-engineering class.

Users:
- the detectors `incremental-load-scan` (IN §1–§10, with `scripts/model-graph.py`),
  `orchestration-scan` (OR §1–§9), `data-test-scan` (DQ §1–§8), `derived-data-scan` (MV §1–§6,
  TB §7–§10), `extract-scan` (EX §1–§4), `pii-copy-scan` (PC §1–§6), `contract-diff` (SC §1–§6),
  `lineage-trace` (LN §1–§4), `warehouse-scan-audit` (CO §1–§5) and `grain-probe` (GR §1–§4);
- `@data-quality-auditor`, `@dag-reviewer` and `@warehouse-modeler` in refute
  mode, and `/audit-data-quality`, with `@verifier` mode `refute` on every BLOCKER and HIGH it keeps;
  `/data-fix`, which writes each finding's failing-first test from its V-number; `/backfill-plan`
  (V540, V550 on the shadow target) and `/add-data-model` (V553 on the new model).

**Owned elsewhere.** These keep their own sections and are corroboration here: a reported number,
its definition and zone policy → § Business; deep-OFFSET cost and a paged API's sort key → § Data
(V3, V4); consumer dedup, outbox and gap-blind cursors → § Distributed; an application scheduler's
overlap and misfire → § Backend; PII storage and erasure in OLTP tables → § Data (V23); budgets and
guardrails → finops.

**Scope of use.** Scratch targets, `${TMPDIR}` and the run folder only. Six rules hold for every
variant below:

- **Never a shared or production target.** dbt runs with `--profiles-dir "$OUT"` and a duckdb profile
  written there (`path: ':memory:'` or `$OUT/scratch.duckdb`), `DO_NOT_TRACK=1`,
  `DBT_SEND_ANONYMOUS_USAGE_STATS=False`, `DBT_ENGINE_SEND_ANONYMOUS_USAGE_STATS=false`, duckdb
  `SET autoinstall_known_extensions=false`; Airflow with `AIRFLOW_HOME="$OUT/airflow"`,
  `AIRFLOW__CORE__LOAD_EXAMPLES=False`; containers named and removed by the run. A target the user
  names is used only after they say it is not production.
- **The real model, loader or query.** The test runs the project's own SQL, task callable, job or
  mapper; a hand-copied query that "does the same" is not the oracle.
- **Seed the edge, not the happy path.** A tie at the watermark's precision, a late row, an update
  after the window, a delete, a NULL key, an empty batch, a DST day: each is a row in the seed.
- **Counts and checksums, exactly.** `count(*)`, `count(distinct key)`, a row checksum
  (`md5(string_agg(... order by key))` or `bit_xor(hash(...))`), an id set compared with a snapshot —
  never "roughly the same".
- **Warehouse bytes need a dry run first.** A probe on a per-byte warehouse states its dry-run bytes
  and runs only below the bound the user gave; above it the row is `NOT-RUN (bound)`.
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix code for the
  stated reason, passes after, and the benign control a precedent names (an append-only event table, a
  whole-day replacement, keyset paging inside a snapshot, a closed-period snapshot labelled as such)
  is unchanged.

### Oracle taxonomy (Data engineering)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Replay twice** | R | the same batch, range, task or rollup pass twice leaves the target's count and checksum unchanged; every other partition untouched | V540, V546, V547, V550 |
| **Edge-row insert** | L | a tie, late, updated, deleted or empty-batch row between two runs lands as the declared policy says | V541, V542, V543, V545, V548, V555, V556 |
| **Shuffle** | R | the same input in ten seeded orders yields one output checksum | V544 |
| **Interval replay** | T, L | a task run for a past interval reads that interval only; the rendered interval is non-zero; the DagBag imports | V549, V551 |
| **DST corpus** | L | the real bucket SQL on Berlin, New York and Riyadh boundary rows assigns each row to the declared local day | V552 |
| **Test mutation** | M | a planted violating row turns the data test red; CI turns red on it | V553, V554 |
| **Contract build** | T | dropping or renaming a contracted column fails `dbt build` / `datacontract breaking`; a migration fails every reader of the column | V557, V558 |
| **Graph equality** | S | the model graph's edges equal the relation mentions in each model | V559 |
| **Concurrent read** | C | writes during a paged extract, a dump or a refresh leave no duplicate, no skip, no FK hole, no blocked reader | V560, V561, V563 |
| **Round trip** | L | an exported value read back equals the source value exactly | V562 |
| **Recompute equality** | R | a derived table equals a recompute from source over a golden history | V564 |
| **Erase and scan** | L, S | an erased subject's values are absent from every derived table, snapshot and stored export | V565 |
| **Classification join** | S | every PII column in an analytical copy carries a classification; a low-privilege role reads masked values | V566, V567 |
| **Dry-run bytes** | D | bytes before and after the predicate fix | V568 |
| **Offline grain probe** | R, T | rows, distinct keys, NULL keys and Type 2 range integrity on the duckdb build | V569 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V540 | Replay twice | the same batch (or retry) run twice: target `count(*)` and checksum unchanged; a NULL-key row yields no duplicate | R | `incremental-load-scan` §2, §7, §10 (IN-2, IN-7, IN-10); `orchestration-scan` §5 (OR-5) |
| V541 | Late row | a row older than the watermark, inside the declared lookback, is present after the next run; one outside it is documented as missed | L | `incremental-load-scan` §1, §3, §9 (IN-1, IN-3, IN-9) |
| V542 | Tie row | a row carrying the watermark's exact timestamp, committed after the run, is present after the next | L | `incremental-load-scan` §1 (IN-1) |
| V543 | Delete reaches the target | a source delete (or a CDC delete + tombstone) is absent or flagged (`dbt_valid_to` set) after the next run; a connector restart mid-snapshot leaves no duplicate key | L | `incremental-load-scan` §4, §10 (IN-4, IN-10) |
| V544 | Shuffle | ten seeded input orders give one dedup output checksum; a composite key with a separator-less concatenation collides on a crafted pair | R | `incremental-load-scan` §5 (IN-5); `grain-probe` §4 (GR-4) |
| V545 | Added column | a column added to the source is carried, or the run fails, per the declared `on_schema_change` | L | `incremental-load-scan` §6 (IN-6) |
| V546 | Partition scope | write two partitions, overwrite one: the other's checksum is unchanged; no reader sees an empty table | R | `incremental-load-scan` §7 (IN-7) |
| V547 | Rollup replay | the rollup job run twice, and killed mid-batch then rerun: the rollup equals a recompute from source | R | `derived-data-scan` §1 (MV-1) |
| V548 | Change after the window | a refund or status change dated D+3 for a row of day D: rollup(D) is restated, or the snapshot is labelled point-in-time where it is read | L | `derived-data-scan` §2 (MV-2) |
| V549 | Interval replay | the task run for a past interval reads only that interval (output independent of the wall clock); the rendered `data_interval_end > data_interval_start`; `DagBag(include_examples=False).import_errors == {}` on the locked Airflow | T, L | `orchestration-scan` §1, §2, §7, §8 (OR-1, OR-2, OR-7, OR-8); `incremental-load-scan` §8 (IN-8) |
| V550 | Overlap and range backfill | two overlapping runs, or one range backfill twice, on one partition: no duplicate, every partition written once | R | `orchestration-scan` §3, §9 (OR-3, OR-9); `incremental-load-scan` §8 (IN-8) |
| V551 | Upstream gate | an upstream task failed: the publish does not run; a sensor whose upstream never arrives times out and alerts | T | `orchestration-scan` §4, §6 (OR-4, OR-6) |
| V552 | DST and midnight corpus | the real bucket SQL in a scratch DB with session zone UTC: Berlin 2026-03-29 / 2026-10-25, New York 2026-03-08 / 2026-11-01, a Riyadh control, a row at local midnight, 2026-06-01T22:30Z (→ Berlin and Riyadh 2026-06-02, New York 2026-06-01); each row in one local day; 23/25 hourly buckets on DST days | L | `derived-data-scan` §7–§10 (TB-1…TB-4); `contract-diff` §6 (SC-6) |
| V553 | Test mutation | a planted duplicate, NULL key, orphan FK or out-of-set enum in a scratch copy of the model turns the test red (exit ≠ 0) | M | `data-test-scan` §1, §2, §5, §8 (DQ-1, DQ-2, DQ-5, DQ-8); `orchestration-scan` §9 (OR-9 checks); `contract-diff` §5 (SC-5) |
| V554 | CI executes the tests | on a branch, a failing test makes the CI command exit non-zero and the job red | T | `data-test-scan` §3 (DQ-3) |
| V555 | Freshness fires | a source `loaded_at` older than the SLA makes `dbt source freshness` error, not warn | L | `data-test-scan` §4 (DQ-4) |
| V556 | Empty batch fails | an empty source batch makes the run or the row-count check fail | L | `data-test-scan` §7 (DQ-7) |
| V557 | Contract build | dropping, renaming or narrowing a contracted column fails `dbt build` (contract preflight) or `datacontract breaking` exits 1; a `SELECT *` model fails the contract on an upstream additive change | T | `contract-diff` §1, §2, §3 (SC-1, SC-2, SC-3) |
| V558 | Migration vs readers | the migration applied to a scratch DB: every extract, dbt source, CDC include list and export mapper naming the column fails before the fix and passes after | T | `contract-diff` §4 (SC-4) |
| V559 | Graph equality | the graph's edges per model equal the relation mentions in its compiled SQL (no hard-coded edge left; sqlglot `exp.Table` walk or `dbt ls`) | S | `lineage-trace` §1, §2 (LN-1, LN-2) |
| V560 | Paged extract under writes | rows inserted and deleted between pages: the exported id set equals a snapshot taken at the start, with no duplicate | C | `extract-scan` §1 (EX-1) |
| V561 | Dump under writes | concurrent parent/child inserts during the dump: the restore into a scratch DB with FKs on succeeds | C | `extract-scan` §2 (EX-2) |
| V562 | Export round trip | instants keep their offset, decimals stay exact (`0.1 + 0.2`-style values, 17 digits), ids and phones keep leading zeros and every digit; a failed run publishes no file and a capped run says so | L | `extract-scan` §3, §4 (EX-3, EX-4) |
| V563 | Refresh under reads | a reader during `REFRESH MATERIALIZED VIEW CONCURRENTLY` is not blocked; the refresh succeeds (a unique index on plain columns exists) | C | `derived-data-scan` §5 (MV-5) |
| V564 | Recompute equality | derived vs a recompute from source over a golden history (including late changes, deletes and a tenant-zone day): zero diff, or the reconciliation marks the day stale and fails | R | `derived-data-scan` §3, §4, §6 (MV-3, MV-4, MV-6); `data-test-scan` §6 (DQ-6) |
| V565 | Erase and scan | erase a seeded subject: no derived table, refreshed view, snapshot, stored export or landing table holds its values | L, S | `pii-copy-scan` §2, §5 (PC-2, PC-5) |
| V566 | Classification join | every PII column in an analytical model, rollup, snapshot or export mapper carries a classification; a low-privilege role reads masked values | S | `pii-copy-scan` §1, §6 (PC-1, PC-6) |
| V567 | Lower-env scan | 10k common emails hashed with the repo's function find zero join hits in a shared copy; a lower-environment sample holds no production identifier | S, L | `pii-copy-scan` §3, §4 (PC-3, PC-4) |
| V568 | Dry-run bytes | `bq query --dry_run` / `EXPLAIN` bytes before and after the predicate, `incremental_predicates` or materialization fix; `require_partition_filter=true` makes an unfiltered reader fail | D | `warehouse-scan-audit` §1–§4 (CO-1…CO-4) |
| V569 | Offline grain probe | on the duckdb build: rows, distinct key, NULL key; per join key the right side's duplicates; Type 2 overlaps, gaps and current rows per natural key — on the warehouse only after a dry-run bound | R, T | `grain-probe` §1–§3 (GR-1…GR-3) |

### Harnesses (Data engineering)

- **The graph** (every dbt row): `python3 -I -B .claude/skills/incremental-load-scan/scripts/model-graph.py
  <root> --out="$RUN/graph" --configs --tests --edges` (exit 0 built, 2 blocked, 4 no dbt project);
  `--self-test` covers the parser. The fix's re-check is the same command on the patched tree: the
  candidate row disappears or its effective value's source changes.
- **Offline dbt** (V540–V547, V553, V555–V557, V569): `dbt-duckdb` with a profile in `$OUT`, the
  committed seeds (`dbt seed`), then `dbt build --target scratch`; incremental replays run the model
  twice with `--vars` naming the batch; mutations insert into a copy (`create table x as select *
  from {{ ref }}`, then the planted row) and run `dbt test -s <model>`; unit tests override
  `is_incremental` and mock `this`. Without dbt installed, the compiled SQL from `target/` or the
  model SQL with `ref()` replaced runs in `python3 -c 'import duckdb'`; without duckdb the row is
  `NOT-RUN`.
- **Containers** (V547, V548, V552, V558, V560, V561, V563–V565): a throwaway Postgres or MySQL
  (`--rm`, a name the run owns, a port on 127.0.0.1), the project's migrations applied, the job or
  query under test run from its module; MySQL TB-3 runs once before and once after
  `mysql_tzinfo_to_sql`. State in the report that a container was started and that it was removed.
- **Airflow** (V549–V551): `AIRFLOW_HOME="$OUT/airflow"`; `DagBag` in pytest; `task.execute(context)`
  with a constructed context for a past interval; `airflow dags test <id> <date>` only where the
  metadata DB is the run's own SQLite.
- **Exports and dumps** (V560–V562): the runner against the container with a writer goroutine/thread
  inserting and deleting between pages; the file parsed back with the project's own reader; ids
  compared as sets.
- **Dry run** (V568): `bq query --use_legacy_sql=false --dry_run` with the user's project, or
  `EXPLAIN` on Snowflake/Postgres; with no credentials the row is `NOT-RUN (no dry-run access)` and
  the static fact stands as `[report-flagged]`.

### Class variants (Data engineering)

A fix passes the class only when every variant the code presents passes the oracle, and the control
the precedents exempt is unchanged.

#### V540. Replay twice (`incremental-load-scan` §2, §7, §10; `orchestration-scan` §5)
- the same batch twice; the same range backfilled twice; killed between the delete and the insert, then rerun; an Airflow `task.execute(context)` twice for one interval; a NULL in each key column
- pass: count and checksum unchanged, no NULL-key duplicate (an append-only event table deduplicated downstream is the control, `precedents/data-engineering.md` § 1)

#### V541. Late row (`incremental-load-scan` §1, §3, §9)
- inside the lookback; outside it (documented as missed); a DST fall-back local 01:30 row; a row whose load stamp is newer than its event stamp; the empty target bootstrapping once
- pass: present after the next run (a `>` with a lookback and a merge is the control, § 2)

#### V542. Tie row (`incremental-load-scan` §1)
- two rows sharing the watermark's value across a run boundary; second-precision clocks; a batch insert
- pass: both loaded once

#### V543. Delete reaches the target (`incremental-load-scan` §4, §10)
- hard delete; delete then re-insert of the same key; a CDC delete with and without tombstone; a PK-less table under the default replica identity; a connector restart mid-snapshot; an unchanged TOASTed column
- pass: absent or flagged, no duplicate, the TOASTed value kept (a source that never deletes is the control, § 16)

#### V544. Shuffle (`incremental-load-scan` §5; `grain-probe` §4)
- ten seeded orders; tied order keys with different payloads; a composite key `'ab'||'1'` vs `'a'||'b1'`
- pass: one checksum; no collision (full-row duplicates are the control, § 15)

#### V545. Added column (`incremental-load-scan` §6)
- an added column; a removed column; a type widening
- pass: carried or failed per the declared policy, never silently dropped

#### V546. Partition scope (`incremental-load-scan` §7)
- static overwrite with `partitionBy`; `insert_overwrite` with and without `partitions`; truncate-and-reload under a reader
- pass: untouched partitions keep their checksum; no empty read (Delta `replaceWhere` is the control, § 28)

#### V547. Rollup replay (`derived-data-scan` §1)
- the job twice; killed mid-batch and rerun; two workers at once; a consumer redelivery
- pass: rollup = recompute (a whole-day replacement or a guarded increment is the control, § 20, § 22)

#### V548. Change after the window (`derived-data-scan` §2)
- a refund at D+3; a status change at D+10; an edit to an amount; a delete
- pass: rollup(D) restated, or the snapshot labelled point-in-time where read (a closed-period snapshot is the control, § 38)

#### V549. Interval replay (`orchestration-scan` §1, §2, §7, §8; `incremental-load-scan` §8)
- a past interval; two reserializations of the DAG (same hash); AF3 DagBag import; a cron schedule rendering `data_interval_*`
- pass: output independent of the wall clock; interval non-zero; imports clean (a `datetime.now()` in a log line is the control, § 13)

#### V550. Overlap and range backfill (`orchestration-scan` §3, §9; `incremental-load-scan` §8)
- two runs at once on one partition; a range backfill twice; Dagster single-run backfill over three partitions
- pass: no duplicate, every partition written once

#### V551. Upstream gate (`orchestration-scan` §4, §6)
- the load fails; the sensor's upstream never lands; the sensor's poke holds a slot
- pass: publish skipped; the sensor times out and alerts (a cleanup task with `all_done` is the control)

#### V552. DST and midnight corpus (`derived-data-scan` §7–§10; `contract-diff` §6)
- naive and aware columns; one and two `AT TIME ZONE`; `BETWEEN` vs half-open windows; MySQL `CONVERT_TZ` before and after zone tables; numeric offsets on a DST zone; Kolkata and Kathmandu half-hour zones
- pass: every row in exactly one declared local day; 23/25 hours on DST days (the double conversion on a UTC-holding naive column is the control, § 27)

#### V553. Test mutation (`data-test-scan` §1, §2, §5, §8)
- a duplicate key; a NULL key; an orphan FK; an out-of-set enum; a row outside the `where:` slice; an empty table; a warn-level key test
- pass: red with exit ≠ 0 (an advisory warn test is the control, § 3)

#### V554. CI executes the tests (`data-test-scan` §3)
- `dbt run` only; a selector excluding tests or sources; `|| true`; `continue-on-error`; a GX checkpoint never called
- pass: the job is red on the planted failure

#### V555. Freshness fires (`data-test-scan` §4)
- `warn_after` only; no `loaded_at_field`; an inherited config
- pass: error, not warn (`freshness: null` on a static seed is the control)

#### V556. Empty batch fails (`data-test-scan` §7)
- empty source; empty partition; a loader that ignores affected rows
- pass: the run or check fails

#### V557. Contract build (`contract-diff` §1–§3)
- drop; rename; type narrow; nullability tighten; an additive upstream column under `SELECT *`
- pass: the build or `datacontract breaking` fails before the fix; versioned after (a pre-release model is the control)

#### V558. Migration vs readers (`contract-diff` §4)
- every reader kind: dbt `sources:`, CDC include list, export mapper, raw SQL in app code
- pass: zero references to the old name after the fix (sqlglot walk)

#### V559. Graph equality (`lineage-trace` §1, §2)
- raw `schema.table` in `from`/`join`; a macro-resolved relation; a CTE name
- pass: edges = mentions (a CTE and `{{ this }}` are the controls, § 24)

#### V560. Paged extract under writes (`extract-scan` §1)
- inserts at the head (newest-first); deletes behind the cursor; ties on the sort column
- pass: id set = snapshot, no duplicate (keyset on `(created_at, id)` compared in SQL is the control, § 30)

#### V561. Dump under writes (`extract-scan` §2)
- parent then child inserted after the parent table was dumped; deletes during the dump
- pass: restore with FKs on succeeds (a quiescent source is the control)

#### V562. Export round trip (`extract-scan` §3, §4)
- an instant near midnight in a non-UTC zone; `0.1 + 0.2`; a 17-digit id; a leading-zero phone; a failure mid-file; a row count above the cap
- pass: exact values, no partial file published, the cap refuses (§ 39)

#### V563. Refresh under reads (`derived-data-scan` §5)
- plain refresh on a request path; `CONCURRENTLY` without a qualifying unique index; `now()` in the definition
- pass: no blocked reader, the refresh succeeds (an off-hours refresh of a small view is the control, § 25)

#### V564. Recompute equality (`derived-data-scan` §3, §4, §6; `data-test-scan` §6)
- late change; delete; a column the trigger does not cover; `TRUNCATE` or a bulk path; a tenant-zone day read from UTC-day facts
- pass: zero diff, or the reconcile marks stale and fails (a full recompute is the control, § 22)

#### V565. Erase and scan (`pii-copy-scan` §2, §5)
- rollups with identifiers; dbt snapshots (SCD2 history); refreshed materialized views; stored export files; landing tables
- pass: no value of the subject remains (backups beyond use are the control, § 32)

#### V566. Classification join (`pii-copy-scan` §1, §6)
- dbt `meta`, `policy_tags`, Snowflake tags, masking policies; `persist_docs`; a policy whose return type differs from the column
- pass: every PII column classified; the low-privilege role reads masked values

#### V567. Lower-env scan (`pii-copy-scan` §3, §4)
- unsalted `sha256(email)`; `md5(lower(email))`; a restore of a production dump into staging
- pass: zero dictionary hits; no production identifier in the sample (a keyed HMAC is the control, § 31)

#### V568. Dry-run bytes (`warehouse-scan-audit` §1–§4)
- a function-wrapped partition column; a merge with no target bound; a `table` fact rebuilt daily; a view chain read three times
- pass: bytes drop by the predicate's share; `require_partition_filter` makes the unfiltered reader fail (a small table is the control, § 35)

#### V569. Offline grain probe (`grain-probe` §1–§3)
- the declared key; each join key's right side; NULL keys; Type 2 overlaps, gaps and current rows
- pass: zero duplicates, zero NULL keys, zero overlaps and gaps (a calendar spine cross join is the control)

### Sources (Data engineering)

The data-engineering research catalog (2026-10-19) § 1–5 and its two notes (pipelines, increments,
quality and contracts; in-app analytics, PII, time buckets, cost) give the classes, the techniques
(effective-config reading, replay-twice in duckdb, tie and late rows as fixtures, test mutation, the
DST corpus, erase-then-scan, dry-run first), the precedents and the per-class variants above. Tool
facts were read 2026-10-19: dbt docs (incremental models and strategies, microbatch, snapshots,
constraints, data tests and `where`, freshness, parse, usage stats), dbt-duckdb 1.11.0 and DuckDB
1.5.6, Airflow "Upgrading to Airflow 3" (3.3.2), Spark 4.2.0 configuration, Debezium 3.7 Postgres
connector and 3.2.0.Final notes, PostgreSQL 18 `REFRESH MATERIALIZED VIEW` and date/time functions,
MySQL 8.4 date/time functions, BigQuery dry run, datacontract-cli 1.2.7, sqlglot 30.23.0. The batch-8
data-engineering eval (2026-10-19) § 5.11 gives the oracle list and the range V540–V569. Paraphrased;
no text reproduced.

---

## Algorithms

An algorithms claim says a **procedure** breaks its own contract on input production delivers: the
work grows faster than the budget as a collection grows, the recursion goes as deep as the input or
around a cycle, a loop stops making progress, a search runs on unsorted data, a tie reorders, a key
collapses two records, a draw is not uniform, a distance is measured in degrees, a sum loses its
digits, a sketch's false positive decides a charge. None of these is proved by reading the code or by
asking a model for its complexity class. Every oracle here runs the real function on generated or
adversarial input, or cites a fact at both ends, and every oracle names a **family**:
- **O**: operation count — a counting spy on the inner lookup, comparator, copy, constructor or
  self-call, at N and 4N (or n, n+5, n+10); deterministic, no clock. V35's time ratio is the
  fallback when nothing can be counted.
- **A**: adversarial input — a depth bomb, a cycle, a stalled page, tied keys, a cap + 1 input.
- **P**: property or differential — the fast path against a brute-force oracle (linear scan, full
  sort, the stdlib primitive) on generated inputs including empty, one, duplicates, unsorted and
  extremes; seed pinned, shrinking on.
- **D**: distribution — permutation or bucket frequencies under a chi-square with a fixed seed, and
  an RNG stub at the ends of its range.
- **R**: reference vectors — known geodesic distances, an asymmetric point round-tripped, a
  high-precision reference (`math.fsum`, `Decimal`, `mpmath`, `BigInt`) for numeric code.
- **S**: a two-ended static fact — the cap and its source, or its absence at every entry point; the
  precondition and the path that breaks it; the library's axis order and the caller's; a build flag
  and the code it compiles.

Settled questions are in [`precedents/algorithms.md`](precedents/algorithms.md). This section is
self-contained: its V-numbers (V590–V609) are cited by the algorithms detectors, their judge and
`/design-algorithm --from-audit`; no V outside this range is reused for an algorithms class.

Users:
- the detectors `complexity-scan` (CX §1–§6, RC §7–§10, with `scripts/algo-sites.py`),
  `algorithm-contract-scan` (OC §1–§4, RD §5–§7, GE §8–§10) and `numeric-stability-scan` (NS §1–§5,
  SL §6–§7) in the algorithms pack;
- `@algorithm-designer` in refute mode and `/analyze-complexity`, with `@verifier` mode `refute` on
  every BLOCKER and HIGH it keeps; `/design-algorithm --from-audit`, which writes each finding's
  failing-first test from its V-number and runs the detector's grep over the whole class afterwards.

**Owned elsewhere.** These keep their own sections and are corroboration here: a comparator, parse,
float `==` or date expression wrong for one input → § Code quality (V83); a query per element →
§ Data (V1); ReDoS → security's `exploit-payloads.md`; a predictable token or prize → security
(CWE-338); a per-call regex or validator build → § Performance (V31); wall-clock speed-ups and their
noise band → § Performance (V35, the evidence block below); generated property tests for pure
functions → § Testing.

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Six rules hold for every
variant below:

- **Count, do not time.** A counter in the comparator, the inner lookup, the copy or the self-call
  decides; wall-clock time is the fallback (V35's median-of-5 and factor rule), never a single run.
- **The real function, the real cap.** The test calls the project's own function through its module,
  with the cap read from the configuration or schema the code reads, so the test proves the wiring.
- **The project's harness first.** Its property library (fast-check, Hypothesis, jqwik, proptest,
  rapid, FsCheck/CsCheck) or its own shrinking fuzzer (`precedents/algorithms.md` § 27); a new
  dependency only when the repo has none, and then pinned.
- **Seed pinned, shrinking on.** A property or distribution test prints its seed and replays it; a
  failure is reported with its shrunk input.
- **Measure stack depth, never quote it.** Frames per stack depend on the runtime, its flags and the
  frame size (Node 23.8 at its default 864 KB: about 9,155 frames for a no-argument function and
  6,866 with three arguments, measured 2026-10-19; Python's default limit is 1,000). The depth bomb
  settles it on the project's runtime.
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix code for the
  stated reason, passes after, and the control a precedent names (a capped side, a memoised call, a
  root-down walk, a unique keyset cursor, a Leaflet `[lat, lng]` call) is unchanged.

### Oracle taxonomy (Algorithms)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Operation count at N and 4N** | O | the inner work grows linearly (or as the budget allows) after the fix, as the product before | V590, V591, V592, V593, V597 |
| **Cap + 1** | A | generation stops at the downstream cap, or the input above it is refused | V594 |
| **Depth bomb** | A | input 10^4–10^5 deep gets a typed refusal or an iterative success, the process survives | V595 |
| **Cycle injection** | A | a self-loop, a 2-cycle and a cycle off the root end within K steps | V596 |
| **Stalled progress** | A | a stalled page, tied keys or a float step: the loop ends and reads each row once | V598 |
| **Differential** | P | the fast path equals the brute-force or stdlib result on generated inputs | V599, V602 |
| **Tie order** | P | equal keys keep input order, or one total order across shuffles | V600 |
| **No collapse** | P, S | distinct elements stay distinct under the key or comparator, or the uniqueness constraint is cited | V601 |
| **Chi-square, fixed seed** | D | permutations or buckets are uniform; the range ends are reachable | V603, V604 |
| **Geodesic vectors** | R | distances, axis order and wrap-around match references | V605, V606, V607 |
| **High-precision reference** | R | the numeric result is within the stated relative tolerance of an exact reference | V608 |
| **Static flag / measured sketch error** | S, D | no IEEE-voiding flag; a sketch's measured error is within its stated bound and positives are confirmed | V609 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V590 | Lookup count | a counter on the inner lookup or compare at N and 4N: N×M before, N+M after (16× vs 4× from N to 4N on both sides) | O | `complexity-scan` §1, §5 (CX-1, CX-5) |
| V591 | Copy count | elements copied (a counter, or bytes allocated) at N and 4N: ~16× before, ~4× after; V35 as fallback | O | `complexity-scan` §2 (CX-2) |
| V592 | Per-operation cost | operations per element flat across container sizes 1e3 → 1e5 (≤ 2×) after; ≥ 50× before | O | `complexity-scan` §3 (CX-3) |
| V593 | Invariant spy | the invariant work (sort, clone, parse, `Set` build, `RegExp`) runs once per call, not once per iteration | O | `complexity-scan` §4 (CX-4) |
| V594 | Cap + 1 | an input that would generate cap + 1 elements is refused, or generation stops at the downstream cap; generated count ≤ cap | A | `complexity-scan` §6 (CX-6) |
| V595 | Depth bomb | nesting 10^4, 10^5 and the parser's maximum: a typed refusal (400 / validation error) or an iterative success; no `RangeError`, `RecursionError`, `StackOverflowError` or fatal stack overflow; the process is alive | A | `complexity-scan` §7 (RC-1) |
| V596 | Cycle injection | a self-loop, a 2-cycle and a cycle off the root: the walk ends within K steps with a cycle error or a visited skip; a recursive CTE with `CYCLE` or a depth bound ends | A | `complexity-scan` §8 (RC-2) |
| V597 | Self-call count | calls at n, n+5, n+10 grow about linearly after the memo; × ~11 per +5 before (fib-shaped) | O | `complexity-scan` §9 (RC-3) |
| V598 | Stalled progress | an iteration counter with a stalled page, tied cursor keys or a float step: ends in ≤ K iterations, every row read exactly once | A | `complexity-scan` §10 (RC-4) |
| V599 | Differential search | the fast path (binary search, `bisect`, `groupby`, a merge) equals a linear scan or a full sort on generated inputs that include unsorted, reverse-sorted, duplicate and collation-sensitive keys | P | `algorithm-contract-scan` §1 (OC-1) |
| V600 | Tie order | records with equal keys keep their input order (stable), or the tie-break yields one total order across 100 shuffles of the input | P | `algorithm-contract-scan` §2 (OC-2) |
| V601 | No collapse | distinct elements with an equal key or comparator: container size equals the distinct count, or the build refuses duplicates; or the unique constraint in the same scope is cited (S) | P, S | `algorithm-contract-scan` §3 (OC-3) |
| V602 | Differential primitive | the hand-rolled search, sort, heap, LRU or geometry predicate equals the stdlib or library primitive on 10k generated inputs including empty, one, duplicates and extremes | P | `algorithm-contract-scan` §4 (OC-4) |
| V603 | Permutation frequency | n = 4, 240k shuffles with a fixed seed: the chi-square over the 24 permutations is below the p = 0.001 critical value for 23 degrees of freedom (49.73) | D | `algorithm-contract-scan` §5 (RD-1) |
| V604 | Range and bucket coverage | an RNG stub at 0 and 1 − 2^-53 reaches exactly the specified min and max; a bucket chi-square; negative and `MIN_VALUE` hashes land in [0, n); adding a bucket moves ≤ 1/(n+1) of sticky keys when assignment must stick; Python `hash()` buckets are equal across two processes with different `PYTHONHASHSEED` | D | `algorithm-contract-scan` §6, §7 (RD-2, RD-3) |
| V605 | Geodesic vectors | 1° of longitude at the equator (≈ 111.3 km), 1° of longitude at 60° N (≈ half of it) and a long-haul pair, each within the design tolerance (0.5 % by default) of a haversine or geographiclib reference; a SQL distance returned in metres | R | `algorithm-contract-scan` §8 (GE-1) |
| V606 | Axis round trip | the asymmetric point (−33.87, 151.21) crosses every boundary (API, DB, GeoJSON, map) unchanged; a swapped latitude fails `|lat| ≤ 90` at the boundary | R | `algorithm-contract-scan` §9 (GE-2) |
| V607 | Wrap-around | a radius or bbox search centred at lon 179.9 finds a point at −179.9; a polar bbox; bearings normalised to [0, 360) and longitudes to [−180, 180) | R | `algorithm-contract-scan` §10 (GE-3) |
| V608 | High-precision reference | on adversarial data (1e16, 1, −1e16; a mean of 1e9 with a spread of 1; probabilities of 1e-300; a Hilbert matrix) the result is within the stated relative tolerance of `math.fsum`, `Decimal`, `mpmath` or `BigInt`; `cond` is computed before a solve is trusted; an iterative method stops at its max-iteration bound | R | `numeric-stability-scan` §1–§4 (NS-1…NS-4) |
| V609 | Flag and sketch error | the build or JIT flag is absent from every build that ships (S); a sketch's false-positive or relative error measured at its stated n with a fixed seed is ≤ its stated bound, and a spy proves the exact check runs on every positive that decides money, a send or a quota | S, D | `numeric-stability-scan` §5, §6, §7 (NS-5, SL-1, SL-2) |

### Harnesses (Algorithms)

- **The candidate table** (CX and RC rows): `python3 -I -B .claude/skills/complexity-scan/scripts/algo-sites.py
  --repo=. --roots=<roots> --tsv` (exit 0 scanned, 1 usage, 2 blocked) prints each site with its
  caps and `n_max × m_max`; `--recursion` adds the self-call and loop-progress rows; `--self-test`
  covers the scanner. The fix's re-check is the same command on the patched tree: the row disappears,
  or its hint becomes `set`, `const-small` or `below-budget` with the new cap cited.
- **Operation counters** (V590–V593, V597): wrap the inner primitive for the test only — a `Proxy`
  or a subclass whose `includes`/`indexOf`/`find`/`has` increments a counter (JS), a list subclass
  with `__contains__`/`index` counting (Python), a comparator that counts, a spy on `sort` or on the
  constructor (`vi.spyOn`, `jest.spyOn`, `unittest.mock.patch(wraps=…)`), a memo-wrapped self-call
  counter. Assert the ratio at N and 4N (`≤ 5×` linear, `≥ 12×` quadratic), never an absolute count.
- **Depth and cycle builders** (V595, V596): a string builder for JSON (`'['.repeat(d) + ']'.repeat(d)`),
  Hypothesis `st.recursive`, fast-check `fc.letrec`; a cycle built by assigning a parent pointer
  after construction; for SQL, a scratch database with the migration applied and a cycle inserted.
  Run the bomb in a child process (`node --stack-size` at the default, `subprocess` with
  `sys.getrecursionlimit()` unchanged) so a fatal overflow fails the test instead of the runner.
- **Property and differential** (V599–V602): the project's library or fuzzer; generated inputs
  include the empty input, one element, all-equal keys, sorted, reverse-sorted and collation-sensitive
  strings (`'a' < 'B'` under code-point order, `'B' < 'a'`… under a locale), and the cap's maximum.
- **Distribution** (V603, V604): a seeded PRNG injected where the code draws (`Math.random` stubbed
  through an injected `rng`, `random.Random(seed)`, `new Random(seed)`), counts per cell, and the
  chi-square against the critical value stated in the test; an RNG stub returning 0 and
  `1 - 2 ** -53` for the range ends.
- **Geodesy** (V605–V607): the reference from geographiclib or turf in the test, or haversine on the
  WGS-84 mean radius 6,371,008.8 m stated as the reference; PostGIS vectors in a scratch container
  with the project's migrations (a container is started only on the user's word, and the report says
  it was removed).
- **Numeric** (V608): `math.fsum`, `fractions.Fraction`, `decimal` with a raised context precision,
  `mpmath` when installed, `BigInt` scaled integers in JS; `numpy.linalg.cond` before a solve.
- **Flags and sketches** (V609): `rg` over every build file the release uses (CMake, `setup.py`,
  `pyproject.toml`, `.csproj`, `numba.jit` decorators) for the flag; a sketch filled with its stated n
  distinct seeded keys and queried with n non-members to measure the false-positive rate.

### Class variants (Algorithms)

A fix passes the class only when every variant the code presents passes the oracle, and the control
the precedents exempt is unchanged.

#### V590. Lookup count (`complexity-scan` §1, §5)
- `.includes` / `.indexOf(x) !== -1` / `.find` / `.findIndex` / `.some` / `.filter(…).length` / `.filter(…)[0]` inside a loop or a per-element callback; `[...set].includes`, `Array.from(set).includes`, `Object.values(o).includes`; lodash `_.includes` / `_.find` / `_.differenceWith` / `_.intersectionWith` / `_.uniqWith`; Python `x in list`, `.index`, `.count`, `any(y == x for y in L)`, `x in d.values()`; Java/Kotlin `contains` / `indexOf` / `anyMatch`; C# `Contains` / `Any` / `FirstOrDefault` on `List<>`; Go `slices.Contains` / `Index`; Ruby `include?` / `find`; PHP `in_array` / `array_search`; Rust `.contains` / `.iter().any`; a `filter` inside a `map` over a second collection (a group-by by scan); two nested loops joining on keys
- pass: the lookup count grows ~4× from N to 4N with both sides scaled; a side capped at ≤ 50 is the control (`precedents/algorithms.md` § 29)

#### V591. Copy count (`complexity-scan` §2)
- `{...acc}` / `[...acc, x]` in `reduce`; `acc = [...acc, x]` in a loop; **`acc.concat(x)`** (the non-fix neither lint rule flags); `Object.assign({}, acc, …)`; Python `acc + [x]`, `{**acc}`, `sum(lists, [])`, tuple `+=`; Ruby `acc + [x]`, non-bang `merge` in `inject`; Kotlin `fold` with `+`; C# `Concat().ToList()`; string `+=` / prepend in Java, C#, Go and on a Python attribute
- pass: copies grow ~4× from N to 4N; an append-only JS string (V8 ropes) and a local CPython `str +=` are the controls (§ 4, § 5)

#### V592. Per-operation cost (`complexity-scan` §3)
- `shift` / `unshift` / `splice(0, …)` / `splice(i, 1)` in a loop; Python `pop(0)`, `insert(0, …)`, `del L[0]`, `list.remove(x)`; Java `remove(0)` / `add(0, …)` on `ArrayList`; C# `RemoveAt(0)` / `Insert(0, …)`; Go `append([]T{x}, s...)`
- pass: cost per element flat from 1e3 to 1e5 elements (a deque, a ring buffer, a head index); a FIFO capped by `maxWaiting` is the control (§ 8)

#### V593. Invariant spy (`complexity-scan` §4)
- `sort` / `sorted` / `toSorted` / `Collections.sort` / `OrderBy` of an outer collection inside the loop; `sort()[0]` for a min; `JSON.parse(JSON.stringify(x))` / `structuredClone` / `deepcopy` of an outer value; `new Set(arr)` / `Object.keys(o)` / `Array.from(set)` rebuilt per iteration or in a loop condition; `new RegExp(str)` / `Pattern.compile` / `regexp.MustCompile` / `Regex::new` / `DateTimeFormatter.ofPattern` / `new SimpleDateFormat` / `Intl.*Format` per iteration
- pass: the spy counts one call per invocation; a CPython `re.compile` and a JS regex literal are the controls (§ 9)

#### V594. Cap + 1 (`complexity-scan` §6)
- Cartesian products (nested generators, `itertools.product`, `flatMap` chains), power sets, permutations, all pairs; generation that is filtered after it completes
- pass: the generator stops at the downstream cap + 1 and the caller refuses, or the input that would exceed it is refused at the boundary; the downstream limit and the generator's cap are the same constant

#### V595. Depth bomb (`complexity-scan` §7)
- direct and mutual recursion; recursion through callbacks (`children.map(render)`); recursive generators (`yield*`); revivers and `toJSON`; `deepcopy` / `structuredClone` of a user-depth object; a recursive validator, serializer, sanitizer or comment-thread renderer
- pass: a typed refusal at the boundary that accepts the input, or an explicit stack that survives 10^5 levels; parsed JSON under a body limit with a global error filter is the control (§ 12)

#### V596. Cycle injection (`complexity-scan` §8)
- every walker over `parent` / `children` / `edges` / `refs` / `cause` / `next`; an editable parent pointer (a category tree, an org chart, a referral chain); an imported graph; a recursive CTE with no `CYCLE` clause (PostgreSQL ≥ 14), path array or depth column
- pass: termination within K steps with a cycle error or a skip; a root-down walk of a parent map is the control (§ 14)

#### V597. Self-call count (`complexity-scan` §9)
- every recursive function with ≥ 2 self-calls on overlapping subproblems; backtracking without pruning on a user-sized n; a memo keyed on part of the argument tuple
- pass: calls grow about linearly in n after the memo; a memo keyed on the full argument tuple is the control (§ 16)

#### V598. Stalled progress (`complexity-scan` §10)
- `for (;;)`, `while (true)`, `do … while (changed)` and cursor loops; a cursor on a non-unique column (`created_at`) or compared with `>=`; an exit that waits for an empty page; a float step compared with `!=`; a worklist that re-enqueues without a visited set; a fixpoint with no monotone measure
- pass: ≤ K iterations with every row read exactly once under tied keys and a concurrent insert; a unique cursor with strict `>` and a short-page exit is the control (§ 15); a process-lifetime loop is out of scope (§ 32)

#### V599. Differential search (`algorithm-contract-scan` §1)
- `binarySearch` / `bisect` / `sort.Search` / `slices.BinarySearch` / `_.sortedIndex` / `itertools.groupby` / a hand merge of two cursors / adjacent dedupe; data sorted by a different key, direction or collation (database collation vs code-point compare) on any path that reaches it
- pass: equal to the linear scan on unsorted, reverse-sorted and duplicate inputs, or a sort by the same key added on every path; a constant table asserted sorted is the control (§ 34)

#### V600. Tie order (`algorithm-contract-scan` §2)
- Go `sort.Slice` / `sort.Sort` / `slices.SortFunc`; C# `List.Sort` / `Array.Sort`; Rust `sort_unstable*`; C++ `std::sort`; PHP < 8.0 `usort`; a multi-pass sort, a "first wins" after a sort, in-memory paging of a sorted list
- pass: `sort.SliceStable` / `slices.SortStableFunc` / `OrderBy().ThenBy()` / `sort_by` / `std::stable_sort`, or an explicit total tie-break; unique keys and a stable runtime are the controls (§ 18, § 19)

#### V601. No collapse (`algorithm-contract-scan` §3)
- `new Map(rows.map(r => [r.k, r]))`, `Object.fromEntries`, `keyBy`, `Collectors.toMap` (which throws on duplicates unless given a merge function), dict comprehensions keyed by a field; `TreeSet` / `TreeMap` / `SortedSet` / `SortedDictionary` / `std::set` with a comparator that ties distinct elements (`BigDecimal` 2.0 vs 2.00 under `compareTo`, case-insensitive names)
- pass: size equals the distinct count, or duplicates are grouped or refused; a unique constraint in the same tenant scope is the static control (§ 20)

#### V602. Differential primitive (`algorithm-contract-scan` §4)
- hand-rolled binary search (`lo <= hi`, the midpoint, the shrink step), quicksort or merge sort, a heap's index arithmetic, an LRU's eviction order, a point-in-polygon ray cast on vertices and edges
- pass: equal to the stdlib or library primitive on 10k generated inputs, or replaced by it

#### V603. Permutation frequency (`algorithm-contract-scan` §5)
- `sort(() => Math.random() - 0.5)` and its variants; a swap loop drawing `j` from `[0, n)` on every step (n^n outcomes); `j < i` (Sattolo: no fixed points); `ORDER BY random()` used as a shuffle (its cost is performance's)
- pass: a vetted Fisher–Yates (`lodash.shuffle`, `random.shuffle`, `Collections.shuffle`, `rand.Shuffle`) or a loop drawing `j` from `[0, i]`; demo or seed data is the control (§ 22)

#### V604. Range and bucket coverage (`algorithm-contract-scan` §6, §7)
- `Math.floor(Math.random() * (max - min)) + min` (excludes `max`); `Math.round(Math.random() * n)` (half-weights the ends); `rand() % n`, `bytes[0] % n` (modulo bias); `(int)(r.nextDouble() * n)`; `random.randint` vs `randrange` bounds; cumulative-weight `<` vs `<=`, zero or unnormalised weights; an RNG constructed per call; `hashCode() % n`, `Math.abs(hashCode()) % n` (`MIN_VALUE` stays negative); Python `hash(x) % n` (salted per process); `% n` assignment that must stick when n changes
- pass: both range ends reachable and buckets uniform; `crypto.randomInt`, an unsigned murmur/xxhash/SHA-256 and `Math.floorMod` are the controls (§ 23); rendezvous or consistent hashing when n changes

#### V605. Geodesic vectors (`algorithm-contract-scan` §8)
- Euclid (`Math.sqrt` / `hypot` / `** 2`) on latitude and longitude; degrees passed to `sin` / `cos`; mixed earth-radius units (6371 km vs 6378137 m vs 3958.8 mi); PostGIS `ST_Distance` / `ST_DWithin` / `ST_Buffer` on `geometry(…, 4326)` (degrees); a bounding box used as a radius
- pass: every vector within the tolerance and distances in metres; `::geography`, `ST_DistanceSphere` or a projected metric SRID are the controls (§ 25)

#### V606. Axis round trip (`algorithm-contract-scan` §9)
- `ST_MakePoint(lat, lng)` / `ST_Point(lat, …)`; GeoJSON `coordinates: [lat, lng]`; Mongo `2dsphere` points; Mapbox calls fed `[lat, lng]`; a mapper between a lat-first API (Google, Leaflet) and a lon-first store
- pass: the asymmetric point unchanged through every hop; a boundary validator rejects `|lat| > 90`; a Leaflet `[lat, lng]` call is the control (§ 24)

#### V607. Wrap-around (`algorithm-contract-scan` §10)
- `lng BETWEEN min AND max` / `lng >= minLng && lng <= maxLng` with east < west; longitude arithmetic without normalisation; bearings outside [0, 360); polar boxes
- pass: the ±180 search finds both sides; the box is split at the antimeridian; a service area that cannot cross ±180° is the control (§ 35)

#### V608. High-precision reference (`numeric-stability-scan` §1–§4)
- naive `+=` over many or mixed-magnitude floats, float32 accumulators; Σx² − (Σx)²/n variance, `1 − cos x`, the textbook quadratic, `exp(x) − 1`, `log(1 + x)`; products of probabilities, softmax without the max shift, factorial ratios; an explicit inverse, normal equations, a solve with no `cond`, an iterative method with only an absolute tolerance or no max-iteration
- pass: within the stated relative tolerance of the reference; `math.fsum`, pairwise `np.sum`, Welford, `expm1` / `log1p`, `logsumexp`, `lstsq` / QR / SVD are the fixes; `np.sum` and `statistics` are the controls (§ 36)

#### V609. Flag and sketch error (`numeric-stability-scan` §5, §6, §7)
- `-ffast-math`, `-Ofast`, `-funsafe-math-optimizations`, `numba.jit(fastmath=True)`, `/fp:fast`, `<FloatingPointModel>Fast`; a Bloom filter, HyperLogLog, Count-Min or t-digest with no stated n / p / precision / ε / δ; one that decides a charge, a send, a quota or a bill
- pass: no flag on a build that ships numeric code; the measured error at the stated n is within the stated bound; every positive that decides money, a send or a quota is confirmed against the source of truth (a negative pre-filter is the control, § 39)

### Sources (Algorithms)

The algorithms research catalog (2026-10-19) § 1–§ 5 and its two notes (complexity, recursion,
regex cost, property-based testing; numeric stability, ordering, equality, time, randomness,
geodesy) give the classes, the techniques (operation-count failing-first tests, cap resolution
before reading, depth bombs, cycle injection, progress variables, differential tests against a
brute-force oracle, chi-square with a fixed seed, reference vectors, high-precision references), the
precedents and the per-class variants above. Tool and runtime facts were read 2026-10-19: Node 23.8
stack depth (measured locally), Python's recursion limit, MDN `Array.prototype.sort` (stable since
ES2019), Go `sort.Slice`, .NET `List.Sort`, the Rust 1.81 release notes (sort panics on a non-total
order), RFC 7946 §3.1.1 and §5.2, PostGIS `ST_Distance`, lodash 4.17.21 `_.difference`, Sentry issue
#7910 (`concat` as a non-fix), fast-check 4.10.2, Hypothesis 6.170.1. The batch-8 algorithms eval
(2026-10-19) § 5.10 gives the oracle list and the range V590–V609. Paraphrased; no text reproduced.

## FinOps

A finops claim says one of two things, and the two are never merged: **a guardrail is absent or a knob
is set wastefully** — no budget anyone hears, no allocation key, no aggregate cap on a paid API, a poll
that bills whether or not there is work, a prefix that never expires, bytes that leave by the origin
door, a money figure with no source — or **money was spent**, which only a billing export can show.
The first is proved from files with a failing-first assertion; the second is proved by reconciliation
arithmetic on the user's export. No oracle here prints a `$` from memory, a runbook or an estimator: a
proof asserts a **quantity, a shape or a sum**, and money stays `candidate-pricing`'s. Every oracle runs
offline — a plan or render on a scratch copy, a stub provider, an emulator, a scratch database, a lint,
`bill-lane.py` — and names a **family**:
- **P**: plan or render assertion — an offline `plan.json` (`terraform init -backend=false`, fake
  credentials, `plan -refresh=false`, `show -json`), a `terraform test` / `tofu test` run with
  `command = plan`, or the rendered manifests of every env (kustomize or `helm template` with an empty
  `KUBECONFIG`), walked with `jq`, Conftest or Kyverno.
- **L**: lint over text that acts as configuration — CI workflows, runbook create lines (continuation
  lines joined), Alertmanager config, Markdown money figures.
- **S**: stub or fake — a stub paid provider that counts calls and returns the provider's cap error, fake
  timers, a mocked queue client, a metrics registry scraped after N calls.
- **E**: emulator or scratch read-back — MinIO or LocalStack lifecycle configuration read back, a scratch
  database seeded on both sides of a cutoff, a temp directory written past its cap.
- **R**: reconciliation — `bill-lane.py` on the user's FOCUS export (or the fixture's synthetic sample):
  the parts sum to the total to the minor unit, per currency.
- **T**: two-ended documentary fact — for a control that exists only in a provider console (DigitalOcean
  Spend Alerts, a provider-side API spend cap): the runbook or ADR line naming the control, its value and
  its read-back command. A **T** proof alone never makes a Finding: it is Hardening ("console-only",
  recorded) or Unconfirmed with the console probe named (`precedents/finops.md` § 10, § 15).

Settled questions are in [`precedents/finops.md`](precedents/finops.md). This section is
self-contained: its V-numbers (V570–V589) are cited by the finops detectors, their judge and
`/cost-guardrails --from-audit`; no V outside this range is reused for a finops class.

Users:
- the detectors `guardrail-scan` (BG §1–§7), `allocation-scan` (TG §1–§4), `spend-path-scan` (PS §1–§3,
  FQ §4–§6), `storage-growth-scan` (ST §1–§4), `egress-trace` (EG §1–§4; §5 is the flow-log lane, proved
  by arithmetic) and `candidate-pricing` (PX §4; §0–§3 price other packs' rows), with
  `unit-cost-probe/scripts/bill-lane.py` for the bill lanes (UE-1…4);
- `@cost-reviewer` in refute mode and `/cost-review`, with `@verifier` mode `refute` on every BLOCKER
  and HIGH it keeps; `/cost-guardrails --from-audit`, which writes each finding's failing-first proof from
  its V-number and re-runs the owning detector; `/cost-guardrails` (install lane), whose ledger marks a
  guardrail ARMED only on an offline proof from this section; `/audit-cost-attribution` and `/cost-model`
  (V589's reconciliation).

**Owned elsewhere.** These keep their own sections and are corroboration here (finops prices their rows,
never re-proves them): NAT, cross-AZ, cloud log retention, volume class, idle addresses, IaC bucket
lifecycle, scale ceilings and engine extended support → § Infrastructure (infrastructure `iac-cost-scan`,
whose § 12 budget absence is the fallback when the finops pack is absent); metric cardinality, Loki stream
labels and retention, sampling and log volume → § Observability; cache headers and a paid call per item →
§ Performance; per-call LLM output caps, loops, prompt caching and metering correctness → § AI engineering;
per-user limits on paid actions → security `exploit-payloads.md`; retry caps and layer multiplication →
§ Distributed; an append-only table's retention job correctness (batching, locks) → § Data; PII retention
→ § Data (V23) and security; warehouse bytes scanned → § Data engineering (V568).

**Scope of use.** Scratch copies, `${TMPDIR}` and the run folder only. Six rules hold for every variant
below:

- **No cloud credentials, no live account.** Unset `AWS_PROFILE`, `AWS_ACCESS_KEY_ID`,
  `GOOGLE_APPLICATION_CREDENTIALS`, `AZURE_*`, `DIGITALOCEAN_ACCESS_TOKEN`; every Kubernetes, Helm or
  kustomize command runs with `KUBECONFIG` pointing at an empty scratch file; Terraform plans with fake
  credentials and `-refresh=false`. A live firing ("send a test alert", "create an over-quota resource in
  staging") is an extra `observed` stamp the user may add, never the proof.
- **The project's own configuration, read by the test.** The budget limit, the cap, the schedule, the
  replica count, the prefix table and the required tag keys come from the files the system reads (the
  policy file, the env schema, the render), so the test proves the wiring and survives a re-tune.
- **Quantities, never prices.** A proof asserts counts, shapes, keys, bytes and sums. A `$` appears only
  in V589's reconciliation of the user's own export.
- **Telemetry off.** `CHECKOV_*` with `--skip-download`; Trivy with `--disable-telemetry
  --skip-version-check`; LocalStack with `DISABLE_EVENTS=1`; Infracost never required (key or login and
  network; list price — `precedents/finops.md` § 25, § 26).
- **Containers are the run's own.** MinIO, LocalStack or a scratch Postgres start with `--rm`, a name the
  run owns and a port on 127.0.0.1; the report says that a container was started and that it was removed.
- **Fail first, pass after, keep the control.** Every variant fails on the pre-fix configuration for the
  stated reason, passes after, and the control a precedent names (an org-level budget cited, a prod floor
  bought for availability, a long-poll receive, an operator rule with its read-back, a presigned private
  download) is unchanged.

### Oracle taxonomy (FinOps)

| Oracle | Family | Asserts | V |
|---|---|---|---|
| **Budget plan assertion** | P, T | ≥ 1 budget per billing scope with a FORECASTED rule below 100 % and a live recipient | V570 |
| **Anomaly plan assertion** | P | a per-dimension monitor and a subscription with a relative threshold | V571 |
| **Estimate-step lint** | L, T | the estimate step runs on every IaC path the workflow applies | V572 |
| **Non-prod policy test** | P | a quota or TTL is present in every non-prod render and an over-quota or TTL-less manifest is rejected | V573 |
| **Suppression expiry** | L | every silence, mute or suppression carries an end | V574 |
| **Tag walk** | P | every taggable resource's merged tags carry the policy's keys with allowed values and one spelling | V575 |
| **Label walk** | P | every pod template and namespace in every env render carries the policy's labels | V576 |
| **Runbook create lint** | L | every resource-creating CLI line carries the tag, label or project flag | V577 |
| **Cap stub** | S | at the cap, zero provider calls and one alert event | V578 |
| **Unit counter scrape** | S | N calls show N on the counter, with tenant and feature dimensions | V579 |
| **Provider cap read-back** | T, S | the provider limit is named with its value and read-back; the cap error is not retried | V580 |
| **Fake-timer call budget** | S | billed calls per simulated hour × prod replicas ≤ the declared budget | V581 |
| **Long-poll assertion** | S, E | every receive waits ≥ 1 s; an empty queue costs a bounded number of receives | V582 |
| **Lifecycle read-back** | E, P | the rule covering the app's prefix, read back from an emulator or the plan; or a delete path that keeps the boundary | V583 |
| **Abort-rule assertion** | P, E | every multipart target bucket aborts incomplete uploads | V584 |
| **Retention boundary** | E | the job deletes older rows, keeps younger ones, and is registered | V585 |
| **Disk cap** | E, P | writing past the cap rotates or is refused; `sizeLimit` and rotation in config | V586 |
| **CDN host and redirect** | S | public URLs carry the CDN host; the download route redirects to a signed URL and streams no body | V587 |
| **Region and host parity** | P, L | every client region and endpoint equals the deploy region or an internal name, across env files and renders | V588 |
| **Provenance and reconciliation** | L, R | every money figure has a source or date; the bill's parts sum to its total to the minor unit | V589 |

| V | Oracle | Asserts | Family | Detector § |
|---|---|---|---|---|
| V570 | Budget plan assertion | per billing scope (each account, project or subscription root): ≥ 1 `aws_budgets_budget` / `google_billing_budget` / `azurerm_consumption_budget_*` in the plan, ≥ 1 FORECASTED (or `FORECASTED_SPEND`) rule below 100 % beside the ACTUAL one, and every notification resolving to an address or to a topic with a subscription; on DigitalOcean the runbook line naming the Spend Alert, its threshold and its read-back (`T`) | P, T | `guardrail-scan` §1–§3 (BG-1, BG-2, BG-3) |
| V571 | Anomaly plan assertion | an `aws_ce_anomaly_monitor` of type DIMENSIONAL over SERVICE (or a CUSTOM monitor per cost category) and an `aws_ce_anomaly_subscription` whose `threshold_expression` is relative (`ANOMALY_TOTAL_IMPACT_PERCENTAGE`) or sized below the smallest service's spend; `N/A (no anomaly API)` on a provider without one | P | `guardrail-scan` §4 (BG-4) |
| V572 | Estimate-step lint | every workflow job that runs `terraform`/`tofu`/`pulumi`/`cdk` plan or apply on a path has an estimate step on the same paths and trigger; where the user already holds a key, a throwaway change adding a priced resource shows a non-zero delta (list price, labelled); without a key, documentary (`T`) | L, T | `guardrail-scan` §5 (BG-5) |
| V573 | Non-prod policy test | `kyverno test` / `conftest test` / `kubeconform` plus a quota-present assertion over every non-prod render: a `ResourceQuota` and `LimitRange` per namespace, preview stacks tagged with a TTL and a destroy job, a non-prod floor covered by an off-hours schedule; an over-quota or TTL-less manifest is rejected | P | `guardrail-scan` §6 (BG-6) |
| V574 | Suppression expiry | every silence (`endsAt`), snooze, mute and cost-alert suppression in code ends within the team's maximum window; no cost or budget rule is commented out; an inhibit rule matches on equal labels | L | `guardrail-scan` §7 (BG-7) |
| V575 | Tag walk | every taggable resource in the plan (module-created ones included) carries the policy's required keys in `tags_all` / `effective_labels` / `tags`, values inside the allowed sets, and no key spelled two ways | P | `allocation-scan` §1, §2 (TG-1, TG-2) |
| V576 | Label walk | every pod template (`spec.template.metadata.labels`, a CronJob's job template) and every namespace in every env render carries the policy's label keys | P | `allocation-scan` §3 (TG-3) |
| V577 | Runbook create lint | every `doctl … create`, `gcloud … create`, `az … create`, `hcloud … create`, `aws … create-*` line in runbooks and scripts (continuations joined) carries `--tag-names` / `--tags` / `--labels` / `--project-id` | L | `allocation-scan` §4 (TG-4) |
| V578 | Cap stub | the org or month budget read set at its cap through the project's own budget store: the next request through every entry point (route, job, consumer) makes **zero** calls to the stub provider and emits one alert event; below the cap the call goes through | S | `spend-path-scan` §1 (PS-1) |
| V579 | Unit counter scrape | N calls to the stub (successes and the failures the provider bills) leave the counter at N, labelled with dependency, tenant and feature, read from the registry scrape or the captured log | S | `spend-path-scan` §2 (PS-2) |
| V580 | Provider cap read-back | the runbook or ADR names the provider's spend limit, its value and the read-back step (`T`); a stub answering the provider's cap error (Anthropic 429 `enforced_spend_limit_reached`, OpenAI `project_spend_limit_exceeded`) receives exactly one call and no retry, and the error surfaces as an alert | T, S | `spend-path-scan` §3 (PS-3) |
| V581 | Fake-timer call budget | with fake timers, one simulated hour (and one day) of the scheduler × the prod replica count from the render makes ≤ the declared number of calls to the billed fake; with the webhook configured, the poll makes none; a busy loop around the billed call is bounded by its delay | S | `spend-path-scan` §4, §6 (FQ-1, FQ-3) |
| V582 | Long-poll assertion | a mocked queue client records `WaitTimeSeconds ≥ 1` on every receive; Terraform `receive_wait_time_seconds ≥ 1` in the plan; an empty LocalStack queue costs ≤ 60 ÷ wait receives per consumer per minute | S, E | `spend-path-scan` §5 (FQ-2) |
| V583 | Lifecycle read-back | the bucket's lifecycle configuration read back from MinIO or LocalStack (`get-bucket-lifecycle-configuration`), or the plan's `lifecycle_rule`, has an Expiration rule whose prefix covers the app's area; or the app's delete path removes an object older than the window and keeps a younger one | E, P | `storage-growth-scan` §1 (ST-1) |
| V584 | Abort-rule assertion | every bucket a multipart path writes to carries `AbortIncompleteMultipartUpload` (`abort_incomplete_multipart_upload_days`) for that prefix, in the plan or read back | P, E | `storage-growth-scan` §2 (ST-2) |
| V585 | Retention boundary | a scratch database of the project's engine with rows on both sides of the cutoff: the job deletes the older ones, keeps the younger ones, in bounded batches; the schedule is registered in the module that boots | E | `storage-growth-scan` §3 (ST-3) |
| V586 | Disk cap | a test writes past the logger's or temp writer's cap and asserts rotation or refusal; `emptyDir.sizeLimit` and the rotation settings asserted in the render | E, P | `storage-growth-scan` §4 (ST-4) |
| V587 | CDN host and redirect | the project's URL builder returns the CDN host for every public area; the download route answers a redirect (302/303/307) to a signed URL with a short expiry and streams no body; authorisation still runs before the redirect | S | `egress-trace` §1, §2 (EG-1, EG-2) |
| V588 | Region and host parity | every SDK client region, bucket, database and cache endpoint in every deployed env file and render equals the deploy region; every service-to-service base URL is a cluster or VPC name | P, L | `egress-trace` §3, §4 (EG-3, EG-4) |
| V589 | Provenance and reconciliation | every `$…/period` figure in docs, ADRs and runbooks has a source or an as-of date in its paragraph or table row; `bill-lane.py attribution` reconciles tagged + mis-tagged + untagged + untaggable = total, and every allocation branches + unallocated = bill, to the minor unit per currency | L, R | `candidate-pricing` §4 (PX-1); bill lanes UE-1…4 |

### Harnesses (FinOps)

- **The plan** (V570, V571, V575, V583, V584, V582's IaC half): reuse the offline `plan.json` that
  infrastructure `iac-cost-scan` left under `$SCAN` when that pack ran; otherwise `terraform init
  -backend=false`, fake credentials, `terraform plan -refresh=false -out="$OUT/p"`, `terraform show -json`.
  `guardrail-scan`'s `guard.jq` and `allocation-scan`'s `tags.jq` are the assertions: the fix's re-check is
  the same `jq` on the patched plan, and the row disappears. A repo with Terraform 1.6+ keeps the proof as
  a `.tftest.hcl` with `command = plan` and `assert` blocks over the same values.
- **The render** (V573, V576, V586, V588): `k8s-render-scan` § 0's `render-<env>.json` when the
  infrastructure pack ran; else `kustomize build` / `helm template` per env with `KUBECONFIG` empty,
  converted to JSON and walked with `labels.jq` or a Conftest/Kyverno policy kept in the repo.
- **Stubs and fake timers** (V578–V582, V587): the project's own HTTP client or SDK wrapper pointed at a
  local stub (`nock`, `msw`, `respx`, `responses`, an `httptest.Server`, WireMock) that counts calls and can
  answer the provider's cap error; Jest/Vitest `useFakeTimers`, `freezegun`/`time-machine`, Go's injected
  clock; the replica count read from the prod render, never typed in.
- **Emulators** (V582–V585): MinIO (`mc ilm rule ls`) or LocalStack (`awslocal s3api
  get-bucket-lifecycle-configuration`, `awslocal sqs receive-message`) for the object store and queue; a
  scratch database of the project's engine with its migrations applied for the retention job. DigitalOcean
  Spaces' lifecycle supports Expiration and AbortIncompleteMultipartUpload and nothing else (provider docs,
  verified 2026-07-13 per the research pass): a transition rule is not a fix there.
- **Lints** (V572, V574, V577, V589): the owning detector's own grep, narrowed to the class, is the
  failing-first test; it is committed as a CI step (`rg` over the workflow, runbook or Markdown paths,
  exit non-zero on a hit) so the guardrail cannot silently return.
- **Bill lanes** (V589, UE-1…4): `python3 -I -B .claude/skills/unit-cost-probe/scripts/bill-lane.py
  <subcommand> <export.csv>` — `columns` first (the cost column read: `EffectiveCost` by default, never a
  silent fall-back), then `attribution`, `split` (rate / usage / mix between two periods) or `commitments`;
  `--self-test` covers the arithmetic. Exit 2 on an unreadable file. It never writes beside the input.

### Class variants (FinOps)

A fix passes the class only when every variant the configuration presents passes the oracle, and the
control the precedents exempt is unchanged.

#### V570. Budget plan assertion (`guardrail-scan` §1–§3)
- every billing scope (each account, project, subscription root and each runbook-created account); a budget created by a module (walk `module_calls`); both rule types (FORECASTED below 100 %, ACTUAL at 100 %); every notification's recipient — an e-mail list, a topic with an `aws_sns_topic_subscription`, a GCP channel, `disable_default_iam_recipients = true` with no channel; a shared no-reply alias
- pass: every scope bounded and heard; an org-level budget cited by account id (`precedents/finops.md` § 9) and a DigitalOcean runbook line with its read-back (§ 10, Hardening "console-only") are the controls

#### V571. Anomaly plan assertion (`guardrail-scan` §4)
- no monitor; one monitor over the account total; a DIMENSIONAL monitor over another dimension; a subscription with an absolute threshold above every service's spend; a subscription with no subscriber
- pass: a per-service (or per-category) monitor with a relative threshold and a live subscriber; a provider with no anomaly API prints `N/A`, never a pass

#### V572. Estimate-step lint (`guardrail-scan` §5)
- a workflow applying IaC with no estimate step; an estimate step on other paths or triggers than the apply; a step marked `continue-on-error` that nobody reads; a monorepo with several IaC roots and one step
- pass: the step runs on every applied root and trigger; a DigitalOcean, Helm or Pulumi repo prints `N/A (no supported estimator)` (§ 26)

#### V573. Non-prod policy test (`guardrail-scan` §6)
- a staging or preview namespace with no `ResourceQuota` or `LimitRange`; a preview root with no TTL tag and no destroy job; a non-prod node pool, Cloud Run service or ScaledObject with min > 0 and no off-hours schedule; an over-quota pod; a TTL-less preview manifest
- pass: rejected by the policy test; a prod floor bought for availability (§ 5) and a local `kind` or compose env (§ 12) are the controls

#### V574. Suppression expiry (`guardrail-scan` §7)
- `amtool silence add --duration=8760h` (or an `--end` months out, or a silence re-added on a schedule — the CLI default is 1h); a silence object whose `endsAt` is past the team's maximum window; a cost or budget alert rule commented out; a snooze with no end; an anomaly subscription threshold no service can reach
- pass: every suppression ends within the team's maximum window; an inhibit rule that encodes topology on equal labels is the control (§ 11)

#### V575. Tag walk (`allocation-scan` §1, §2)
- a resource with per-resource tags only; a provider with no `default_tags`; a module-created resource; a key spelled `Team` and `team`; a value `production` where the policy allows `prod`; a GCP resource with `labels` missing a key
- pass: every taggable resource carries the keys and allowed values; untaggable types (§ 14) are counted as such, never as untagged

#### V576. Label walk (`allocation-scan` §3)
- labels on the Deployment's metadata but not its pod template; a CronJob whose job template lacks them; a namespace with only Pod Security labels; one env overlay that drops a label transformer; a kustomize `labels` transformer without `includeTemplates: true`
- pass: every pod template and namespace in every env carries the keys; a single-product cluster is Hardening until a second owner shares it (§ 13)

#### V577. Runbook create lint (`allocation-scan` §4)
- a single-line create; a create split over `\` continuations; a create inside a shell script; a create in a Markdown table row (prose, dropped); a `--project-id` without `--tag-names` where the policy needs the tag
- pass: every create line carries the flag the policy names; which axis the DigitalOcean invoice groups by (tag or project) is read from the policy, never assumed

#### V578. Cap stub (`spend-path-scan` §1)
- every paid dependency (LLM, SMS, WhatsApp/Graph, maps, e-mail, geocoding); every entry point that reaches it (route, job, consumer, cron); the cap read before the call, not after; a call made through a second client that bypasses the wrapper; a retry path after the cap
- pass: zero provider calls at the cap from every entry point and one alert event; per-tenant credit metering alone fails (§ 16); a provider-side hard cap read back clears to Hardening (§ 15)

#### V579. Unit counter scrape (`spend-path-scan` §2)
- a successful call; a provider-billed failure (a 4xx the provider charges, a partial stream); a call from a background job with no request context; a second client instance
- pass: the counter equals N with dependency, tenant and feature labels; a provider dashboard exported and cited is the control

#### V580. Provider cap read-back (`spend-path-scan` §3)
- the cap error at the first call, mid-stream and in a batch job; the generic retry wrapper around the client; a workspace or user limit answering a different status than the org cap
- pass: the limit, its value and its read-back are written down (`T`, never more than Hardening from files); the cap error is surfaced once and never retried

#### V581. Fake-timer call budget (`spend-path-scan` §4, §6)
- every scheduler style in the stack (`@Cron`/`@Interval`, `setInterval`, `node-cron`, BullMQ `every` / `upsertJobScheduler`, Celery beat, APScheduler, `@Scheduled(fixedRate)`, `robfig/cron`, a CronJob `schedule`, a KEDA `pollingInterval` on a billed scaler) × the prod replica count × calls per run; a `while (true)` / `for {}` around a billed call with no delay; the webhook configured and not configured
- pass: ≤ the declared budget; a schedule against a flat-rate store prints contention (§ 1); an outbox relay or lease renewal (§ 17) and a blocking long-poll inside the loop (§ 18) are the controls

#### V582. Long-poll assertion (`spend-path-scan` §5)
- a receive with no `WaitTimeSeconds`; with 0; a queue whose Terraform `receive_wait_time_seconds` is absent (default 0) while the client omits it; boto3, AWS SDK v3, Go and Java clients; `sqs-consumer` options
- pass: every receive waits ≥ 1 s; a busy queue with a documented sub-second latency need is the control

#### V583. Lifecycle read-back (`storage-growth-scan` §1)
- every area or prefix the store wrapper exposes (exports, temp uploads, generated reports, thumbnails); a rule scoped to another prefix; a rule set by an operator and written down with its read-back (Hardening, § 19); a delete path that runs only on success
- pass: the app's prefix expires or is deleted with the boundary kept; a prefix that is the product's record is a business rule — asked, never expired by the fix (§ 20); personal data routes the retention half to security

#### V584. Abort-rule assertion (`storage-growth-scan` §2)
- `@aws-sdk/lib-storage` `Upload`; `CreateMultipartUploadCommand`; boto3 `upload_file` above its multipart threshold; a bucket in another root; a prefix-scoped abort rule that misses the multipart prefix
- pass: every multipart target aborts incomplete uploads; R2 and MinIO differences read from the provider's dated page before reporting

#### V585. Retention boundary (`storage-growth-scan` §3)
- every append-only table with an insert path (events, delivery logs, outbox, idempotency keys, webhook deliveries); a job defined but never registered; a job that deletes without a bound; partitions created and never dropped; a TTL index on the wrong field
- pass: older rows removed, younger kept, the schedule registered; ledgers, invoices and audit trails kept by law are the control (§ 21); the job's locks and batching are § Data's

#### V586. Disk cap (`storage-growth-scan` §4)
- a file logger with no rotation; a per-request temp file never removed; a writer `emptyDir` with no `sizeLimit`; a PVC a job appends to
- pass: rotation or refusal past the cap; an `emptyDir` on a pod that restarts often is the control

#### V587. CDN host and redirect (`egress-trace` §1, §2)
- every public URL builder (media, avatars, attachments rendered in pages and e-mails); a presigned GET handed to browsers for public media; a download route piping `GetObjectCommand` to the reply, `StreamableFile`, `res.pipe`, `sendFile`; a range request
- pass: public areas on the CDN host; downloads redirect to a short-lived signed URL after authorisation; private, low-volume presigned downloads are the control (§ 22)

#### V588. Region and host parity (`egress-trace` §3, §4)
- every deployed env file and render; SDK client `region` literals; bucket, database and cache endpoints; a service calling its sibling through the public hostname; a public origin used to build links (control, § 23); a commented `.env.example` or DR replica region (control, § 24)
- pass: one region per hot path and internal names service to service

#### V589. Provenance and reconciliation (`candidate-pricing` §4; bill lanes)
- every Markdown file with a money figure, `ai/runbooks` and ADRs included; a figure in a table row whose caption carries the date (read by hand); a figure quoted from a bill line with its period (sourced); an export with two currencies; a partial period; mis-tagged rows; untaggable lines
- pass: every figure dated or sourced; the four attribution categories sum to the total and the allocation branches plus unallocated sum to the bill, per currency, to the minor unit; a figure's **value** is never corrected from memory — it gets a date and a re-read

### Sources (FinOps)

The finops research catalog (2026-10-19) § 1–§ 5 and its two notes (tools, IaC, Kubernetes,
DigitalOcean, budget APIs and FOCUS; code and config cost classes, LLM spend, agents, precedents) give the
classes, the techniques (plan-JSON and render walks, runbook-as-IaC lints, schedule × replicas × billing
model, per-prefix object accounting, flat-rate detection first, reconciliation as the oracle when no test
can run), the precedents and the per-class variants above. Provider facts as dated there: the Terraform
AWS provider docs for `aws_budgets_budget` and `aws_ce_anomaly_*` (read 2026-10-19); DigitalOcean Spend
Alerts control-panel only (GA 2026-08-05) and Spaces lifecycle limits (verified 2026-07-13); Amazon SQS
short and long polling; Anthropic and OpenAI spend-limit error codes (read 2026-10-19); Infracost v2.17.0
(2026-09-30) and v0.10.46 (2026-09-25) login, network and provider coverage; Trivy telemetry since v0.63.
The batch-8 finops eval (2026-10-19) § 3.5 gives the oracle list and the range V570–V589. Paraphrased; no
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
