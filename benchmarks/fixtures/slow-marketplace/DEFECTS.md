# Seeded defects — `slow-marketplace`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `stallwise`, a multi-store marketplace — NestJS 11 on Fastify + MikroORM 6 / Postgres 16 API and worker, a Django 5 + DRF reports service on the same database, React 19 + Vite storefront, PgBouncer, Kubernetes HPA.
55 database and performance defects — the database + performance counterpart of
`vuln-fullstack` — seeded across N+1 (five ORM shapes, a serializer and a per-row authorization
check among them), query shape, index coverage, schema integrity, migration safety, transactions,
connections and replicas, the request path, horizontal scale, memory and caching, and the browser —
plus **32 decoys**: known-safe siblings that look like a seeded defect and must NOT be reported.
Two target commands, scored as two results rows: **`/db-audit`** (36 defects, 17 decoys) and
**`/perf-audit`** (19 defects, 15 decoys).

Stage with: --git — `migration-safety` lists migration files with `git ls-files`, so an
un-initialised copy reports every migration class `N/A` (measured: "no migration files in scope").
`run.sh` reads this line and git-initialises both staged copies.

What makes the fixture measure more than keyword recall: most defects have a correct sibling in
the same tree, and several are only defects once two files are read together. `Migration20250918120000`
writes `CREATE INDEX CONCURRENTLY` exactly like the correct `Migration20250402090000` — only the
missing `isTransactional()` override separates them. `payout-ledger.service.ts` writes through the
transaction's own `em` and still escapes it. The atomic `orders_today + 1` that fixes a lost update is
the hot-row defect. The connection budget is arithmetic across `deploy/k8s/api.yaml`,
`worker.yaml`, `pgbouncer.ini` and `postgresql.conf`. The cron, the login limiter and the product
cache are correct on one pod and wrong on twelve. The product cache key is a tenant leak only once
`Product`'s `@Unique({ properties: ['store', 'slug'] })` is read. Reporting the safe half of a pair is
scored too — see **Decoys** below.

Ownership. Every row names the detector that owns its class. Database round trips belong to the
database pack's detectors, which `/db-audit` dispatches and `/perf-audit` also dispatches when the
database pack is installed; network, CPU, memory, cache and scale classes belong to the performance
pack; the four browser rows are `/bundle-perf`'s (frontend pack detectors) and are scored under
`/perf-audit` because that is the command this fixture runs. `SM-CM-05` is a cross-tenant cache read:
`/perf-audit` routes it to security's `@tenant-isolation-reviewer` when that pack is installed, and a
report of it in either place counts.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| SM-N1-01 | `api/src/orders/order-history.service.ts:57` | high | `/db-audit` | db/n-plus-one-relation-load |
| SM-N1-02 | `reports/refunds/serializers.py:16` | high | `/db-audit` | db/n-plus-one-serializer |
| SM-N1-03 | `api/src/invoices/invoice-list.service.ts:47` | high | `/db-audit` | db/n-plus-one-authorization-load |
| SM-N1-04 | `api/src/wishlist/wishlist.service.ts:28` | high | `/db-audit` | db/n-plus-one-parallel |
| SM-N1-05 | `api/src/catalog/product.resolver.ts:49` | high | `/db-audit` | db/n-plus-one-resolver |
| SM-N1-06 | `api/src/catalog/product-import.service.ts:65` | high | `/db-audit` | db/row-by-row-write |
| SM-QS-01 | `api/src/orders/seller-orders.service.ts:38` | high | `/db-audit` | db/unbounded-result |
| SM-QS-02 | `reports/refunds/views.py:19` | high | `/db-audit` | db/unbounded-result |
| SM-QS-03 | `api/src/catalog/catalog.service.ts:35` | high | `/db-audit` | db/deep-offset |
| SM-QS-04 | `api/src/customers/customer-lookup.service.ts:17` | high | `/db-audit` | db/non-sargable-function |
| SM-QS-05 | `api/src/catalog/catalog.service.ts:48` | high | `/db-audit` | db/non-sargable-wildcard |
| SM-QS-06 | `api/src/staff/staff.service.ts:12` | medium | `/db-audit` | db/over-fetch |
| SM-IDX-01 | `api/src/orders/order-item.entity.ts:10` | high | `/db-audit` | db/fk-without-index |
| SM-IDX-02 | `api/db/migrations/2025-09-22_reviews.sql:8` | high | `/db-audit` | db/fk-without-index |
| SM-SCH-01 | `api/src/stores/store.entity.ts:22` | high | `/db-audit` | schema/missing-unique |
| SM-SCH-02 | `api/src/migrations/Migration20240115093000.ts:109` | high | `/db-audit` | schema/missing-check |
| SM-SCH-03 | `api/src/shipping/shipment.entity.ts:14` | medium | `/db-audit` | schema/missing-fk |
| SM-SCH-04 | `api/src/catalog/product.entity.ts:35` | high | `/db-audit` | schema/money-float |
| SM-SCH-05 | `reports/refunds/models.py:59` | critical | `/db-audit` | schema/money-float |
| SM-SCH-06 | `api/src/migrations/Migration20240115093000.ts:144` | medium | `/db-audit` | schema/timestamp-without-tz |
| SM-MIG-01 | `api/db/migrations/2025-09-22_reviews.sql:44` | high | `/db-audit` | migration/blocking-index-build |
| SM-MIG-02 | `api/src/migrations/Migration20250918120000.ts:7` | high | `/db-audit` | migration/concurrently-in-transaction |
| SM-MIG-03 | `api/src/migrations/Migration20250925080000.ts:7` | high | `/db-audit` | migration/not-null-no-backfill |
| SM-MIG-04 | `reports/refunds/migrations/0004_widen_psp_refund_number.py:14` | critical | `/db-audit` | migration/table-rewrite |
| SM-TX-01 | `api/src/checkout/checkout.service.ts:72` | high | `/db-audit` | tx/external-io-in-transaction |
| SM-TX-02 | `api/src/payouts/payout-ledger.service.ts:33` | high | `/db-audit` | tx/wrong-handle |
| SM-TX-03 | `api/src/stores/store-settings.service.ts:19` | medium | `/db-audit` | tx/lost-update |
| SM-TX-04 | `api/src/stores/store-members.service.ts:21` | high | `/db-audit` | tx/write-skew |
| SM-TX-05 | `api/src/pickup/pickup-slots.service.ts:36` | medium | `/db-audit` | tx/serializable-no-retry |
| SM-TX-06 | `api/src/outbox/outbox-relay.ts:29` | high | `/db-audit` | tx/claim-without-skip-locked |
| SM-TX-07 | `reports/refunds/importers.py:32` | medium | `/db-audit` | tx/savepoint-per-item |
| SM-TX-08 | `api/src/checkout/checkout.service.ts:34` | medium | `/db-audit` | tx/hot-row |
| SM-CONN-01 | `deploy/k8s/api.yaml:40` | high | `/db-audit` | conn/connection-budget |
| SM-CONN-02 | `api/src/config/mikro-orm.config.ts:27` | medium | `/db-audit` | conn/no-statement-timeout |
| SM-CONN-03 | `deploy/pgbouncer/pgbouncer.ini:22` | medium | `/db-audit` | conn/no-idle-in-transaction-timeout |
| SM-CONN-04 | `api/src/stores/store-onboarding.service.ts:36` | medium | `/db-audit` | conn/read-after-write-replica |
| SM-RT-01 | `api/src/catalog/feed-upload.controller.ts:33` | high | `/perf-audit` | perf/event-loop-blocking-zlib |
| SM-RT-02 | `api/src/auth/password.service.ts:36` | high | `/perf-audit` | perf/event-loop-blocking-crypto |
| SM-RT-03 | `api/src/catalog/catalog-snapshot.controller.ts:29` | high | `/perf-audit` | perf/event-loop-blocking-json |
| SM-RT-04 | `api/src/orders/order-detail.service.ts:27` | medium | `/perf-audit` | perf/sequential-awaits |
| SM-RT-05 | `api/src/dashboard/seller-dashboard.service.ts:19` | medium | `/perf-audit` | perf/sequential-awaits |
| SM-RT-06 | `api/src/checkout/shipping-quotes.service.ts:26` | high | `/perf-audit` | perf/unbounded-fan-out |
| SM-RS-01 | `api/src/payments/psp.client.ts:23` | critical | `/perf-audit` | perf/missing-outbound-timeout |
| SM-RS-02 | `reports/refunds/fx.py:34` | high | `/perf-audit` | perf/missing-outbound-timeout |
| SM-SC-01 | `api/src/auth/login-rate-limiter.ts:10` | high | `/perf-audit` | scale/per-replica-rate-limiter |
| SM-SC-02 | `api/src/payouts/payout-reminder.cron.ts:18` | medium | `/perf-audit` | scale/cron-on-every-replica |
| SM-CM-01 | `api/src/catalog/product-snapshot.cache.ts:19` | high | `/perf-audit` | memory/unbounded-map |
| SM-CM-02 | `api/src/worker/search-indexer.worker.ts:19` | high | `/perf-audit` | memory/orm-identity-map-growth |
| SM-CM-03 | `api/src/realtime/price.gateway.ts:35` | medium | `/perf-audit` | memory/listener-leak |
| SM-CM-04 | `api/src/storefront/home-feed.service.ts:37` | high | `/perf-audit` | cache/stampede |
| SM-CM-05 | `api/src/catalog/product-cache.service.ts:45` | critical | `/perf-audit` | cache/key-missing-tenant (security-routed) |
| SM-FE-01 | `web/src/routes.tsx:8` | medium | `/perf-audit` | frontend/initial-bundle |
| SM-FE-02 | `web/src/App.tsx:48` | medium | `/perf-audit` | frontend/re-render-storm |
| SM-FE-03 | `web/src/pages/HomePage.tsx:24` | medium | `/perf-audit` | frontend/lcp-lazy-hero |
| SM-FE-04 | `web/src/pages/CatalogPage.tsx:75` | medium | `/perf-audit` | frontend/inp-long-task |

Severity split: 4 critical · 33 high · 18 medium. By command: `/db-audit` 36 · `/perf-audit` 19.

### Coverage by class

Grouped by the owner each class has in the database and performance packs, so a miss can be read
as "this detector did not fire" rather than as a number.

| group | owner | command | seeded | ids |
|-------|-------|---------|--------|-----|
| N+1 and per-element round trips | `n-plus-one-scan` | `/db-audit` | 6 | N1-01, N1-02, N1-03, N1-04, N1-05, N1-06 |
| query shape (unbounded, OFFSET, non-sargable, over-fetch) | `query-shape-scan` | `/db-audit` | 6 | QS-01, QS-02, QS-03, QS-04, QS-05, QS-06 |
| index coverage (FK without index) | `index-coverage-scan` | `/db-audit` | 2 | IDX-01, IDX-02 |
| schema integrity (unique, CHECK, FK, money, time zone) | `schema-integrity-scan` | `/db-audit` | 6 | SCH-01, SCH-02, SCH-03, SCH-04, SCH-05, SCH-06 |
| migration safety (lock-taking DDL, NOT NULL, index builds) | `migration-safety` | `/db-audit` | 4 | MIG-01, MIG-02, MIG-03, MIG-04 |
| transactions and concurrency | `transaction-scan` | `/db-audit` | 8 | TX-01, TX-02, TX-03, TX-04, TX-05, TX-06, TX-07, TX-08 |
| connections, timeouts, replicas | `connection-config-scan` | `/db-audit` | 4 | CONN-01, CONN-02, CONN-03, CONN-04 |
| request path (event loop, sequential awaits, fan-out) | `request-path-scan` §1–§6 | `/perf-audit` | 6 | RT-01, RT-02, RT-03, RT-04, RT-05, RT-06 |
| overload: outbound calls with no deadline | `request-path-scan` §12 | `/perf-audit` | 2 | RS-01, RS-02 |
| horizontal scale (per-replica limiter, cron on every replica) | `request-path-scan` §18, §20 | `/perf-audit` | 2 | SC-01, SC-02 |
| memory growth (unbounded map, unit of work, listeners) | `memory-growth-scan` §1, §2, §7 | `/perf-audit` | 3 | CM-01, CM-02, CM-03 |
| browser (bundle, re-render, LCP, INP) | frontend `bundle-analyze` / `lcp-audit`, `/bundle-perf` (when installed) | `/perf-audit` | 4 | FE-01, FE-02, FE-03, FE-04 |
| caching (stampede, tenant-unsafe key) | `caching-scan` §2, §3 (identity leg → security) | `/perf-audit` | 2 | CM-04, CM-05 |
| **decoys (must not be reported)** | — | both | **32** | DECOY-01 … DECOY-32 |

---

## SM-N1-01 — Order lines loaded one order at a time

```defect
id:       SM-N1-01
file:     api/src/orders/order-history.service.ts
line:     57
severity: high
command:  /db-audit
class:    db/n-plus-one-relation-load
anchor:   await order.items.load();
match:    n\s*\+\s*1|n\+1|per.?(order|row|element|iteration|parent)|each order|every order|in(side)? (a|the|each)? ?loop|items\.load|\.load\(\)|populate|round.?trip|quer(y|ies) per
```

`recentLinesForStore` reads the latest 50 paid orders, then calls `order.items.load()` once per
order: 1 + 50 statements for one dashboard widget, each `select … from order_item where order_id = ?`
against a 186 M-row table whose `order_id` has no index (SM-IDX-01), so every one of the 50 is a
scan. MikroORM never lazy-loads a collection silently, which is why the load is explicit and why a
grep for an awaited relation call in a loop finds it. `listForCustomer` above it is the project's own
correct shape: `populate: ['items']` on the list query (SM-DECOY-01). Fix: `populate: ['items']` (or
`em.populate(orders, ['items'])`) on the `em.find`, and delete the loop's load. Proof: the scaling
test — 2 orders → 3 statements, 20 orders → 21. CWE-1073. Owner: n-plus-one-scan §1.

## SM-N1-02 — DRF serializer walks two foreign keys per refund

```defect
id:       SM-N1-02
file:     reports/refunds/serializers.py
line:     16
severity: high
command:  /db-audit
class:    db/n-plus-one-serializer
anchor:   return obj.order.store.name
match:    n\s*\+\s*1|n\+1|per.?(row|refund|object|item|instance|record)|each (refund|row)|every (refund|row)|select_related|prefetch_related|quer(y|ies) per|extra quer|lazy
```

`RefundSerializer.get_store_name` walks `obj.order.store` and `order_number` reads
`source="order.number"`: two foreign-key hops per refund, rendered by `RefundListView`, whose queryset
(`refunds/views.py`) has no `select_related`. DRF does not optimise querysets, so a page of refunds
costs 1 + 2N statements, and that view is also unpaginated (SM-QS-02): the finance list issues two
queries for each of 3.1 M rows. The seller-dashboard view further down the views file uses the same
serializer with `.select_related("order__store")` (SM-DECOY-32): the hops are the same, only one
queryset was optimised. Fix: `select_related("order__store")` on `RefundListView.get_queryset`.
Proof: `django_assert_num_queries` at 2 and 20 refunds. CWE-1073. Owner: n-plus-one-scan §1 (serializer).

## SM-N1-03 — Per-row authorization check loads a membership row per invoice

```defect
id:       SM-N1-03
file:     api/src/invoices/invoice-list.service.ts
line:     47
severity: high
command:  /db-audit
class:    db/n-plus-one-authorization-load
anchor:   if (await this.canView(user, invoice)) visible.push(invoice);
match:    n\s*\+\s*1|n\+1|per.?(invoice|row|element|item|record)|each invoice|every invoice|in(side)? (a|the|each)? ?loop|quer(y|ies) per|round.?trip
```

`InvoiceListService.list` loads up to 100 invoices, then runs `canView` on each one, and for
store staff `canView` issues `em.findOne(StoreMember, { store, user })` — a query per invoice. The
lookup is not by primary key, so MikroORM's identity map cannot answer it from memory even when every
invoice belongs to the same store. A per-row authorization check that loads its owner per row is an
N+1 (`n-plus-one-scan` § Boundaries); whether the check itself is right is security's question.
Fix: resolve the caller's store memberships once (`em.find(StoreMember, { user })`), then filter in
memory or push the membership into the `where`. Proof: the scaling test as a store member at 2 and
20 invoices. CWE-1073. Owner: n-plus-one-scan §2.

## SM-N1-04 — Wishlist reads every product with its own findOne, all at once

```defect
id:       SM-N1-04
file:     api/src/wishlist/wishlist.service.ts
line:     28
severity: high
command:  /db-audit
class:    db/n-plus-one-parallel
anchor:   ids.map((id) => this.em.findOne(Product, { id }, { populate: ['store'] }))
match:    n\s*\+\s*1|n\+1|per.?(id|item|product|element|entry)|Promise\.all|parallel|fan.?out|\$in|one query (per|for each)|quer(y|ies) per|pool
```

`WishlistService.list` reads every saved id from Redis (power users keep hundreds) and fans
out one `em.findOne(Product, …, { populate: ['store'] })` per id through `Promise.all`. Parallelism
does not remove the N statements: it runs them at once, so one wishlist page can try to check out
hundreds of pool connections (the pool is 25) and starve every other request on the pod. Prisma's
same-tick batching is the precedent that makes this shape safe there; MikroORM has no such batching
by default (`dataloader: NONE`). Fix: `em.find(Product, { id: { $in: ids } }, { populate: ['store'] })`
and re-order by the Redis order. Proof: scaling test plus pool-wait count. CWE-1050. Owner: n-plus-one-scan §3.

## SM-N1-05 — GraphQL `store` field resolved with a query per product

```defect
id:       SM-N1-05
file:     api/src/catalog/product.resolver.ts
line:     49
severity: high
command:  /db-audit
class:    db/n-plus-one-resolver
anchor:   return this.em.findOneOrFail(Store, { id: product.store.id });
match:    n\s*\+\s*1|n\+1|per.?(parent|product|row|item|element)|each product|every product|dataloader|data.?loader|batch(ed)?.?load|quer(y|ies) per
```

The public GraphQL `Product.store` field resolves with `em.findOneOrFail(Store, …)` per parent
product: `products(category, first: 100) { store { name } }` issues up to 100 extra statements (one
per distinct store on the page; the identity map only saves repeats). The `brand` field in the same
resolver class goes through a request-scoped DataLoader built per request in the GraphQL context
(SM-DECOY-02) — the project already has the right tool and did not use it here. Fix: a
`storeById` loader beside `brandById` in `product-loaders.ts`. Proof: one GraphQL operation at 2 vs
20 products from distinct stores. CWE-1073. Owner: n-plus-one-scan §4.

## SM-N1-06 — CSV import flushes once per row

```defect
id:       SM-N1-06
file:     api/src/catalog/product-import.service.ts
line:     65
severity: high
command:  /db-audit
class:    db/row-by-row-write
anchor:   await this.em.persistAndFlush(product);
match:    row.?by.?row|per.?(row|line|item|product|record)|each (row|line|product)|every (row|line|product)|persistAndFlush|flush.{0,30}(loop|each|every|per)|(loop|each|every).{0,30}flush|bulk|batch|n\s*\+\s*1|n\+1|round.?trip
```

The seller CSV import (up to 20 000 rows, synchronous: the seller waits on the response) calls
`persistAndFlush` once per row. Each flush is a round trip and its own transaction, and MikroORM
computes change sets over every managed entity at each flush, so the CPU cost grows with the rows
already imported. `loadExisting` below it is the correct batched read (SM-DECOY-03: one `IN` query
per 500-SKU chunk). Fix: `em.persist` in the loop and one `em.flush()` per chunk (or `upsertMany`,
as `FeedImportService` already does). Proof: count INSERT/UPDATE statements and transactions at 2
and 20 rows. CWE-1050. Owner: n-plus-one-scan §5.

## SM-QS-01 — CSV export loads a store's entire order history in one read

```defect
id:       SM-QS-01
file:     api/src/orders/seller-orders.service.ts
line:     38
severity: high
command:  /db-audit
class:    db/unbounded-result
anchor:   { store: storeId }, { populate: ['items'], orderBy: { createdAt: QueryOrder.ASC } }
match:    unbounded|no (limit|cap|pagination|page)|without (a )?(limit|cap|pagination|page)|missing (limit|cap|pagination)|\blimit\b|paginat|stream|cursor|all (of the |the )?(orders|rows)|every order|entire|whole (table|history)|memory|\boom\b
```

`exportCsv` loads a store's whole order history with its lines — no `limit`, no cursor — into
memory, builds the CSV as one string and sends it in one buffer. The largest store has 2.4 M orders
(`.claude/codebase-profile.md`), and the dashboard's "Download all orders" button is one click.
`recentForStore` in the same file (SM-DECOY-05) is capped at 50 and served by
`order(store_id, created_at desc)`. Fix: stream keyset pages (`created_at, id`) of 1 000 to the
response, or generate the export in the worker to object storage. Proof: seed more rows than the
cap, call the export, assert the captured SQL carries `LIMIT` and memory stays flat. CWE-770. Owner: query-shape-scan §1.

## SM-QS-02 — Refund list view has no paginator and no default

```defect
id:       SM-QS-02
file:     reports/refunds/views.py
line:     19
severity: high
command:  /db-audit
class:    db/unbounded-result
anchor:   class RefundListView(generics.ListAPIView):
match:    paginat|unbounded|no (limit|cap|page)|without (a )?(limit|cap|page)|all (of the |the )?(refunds|rows)|every refund|pagination_class|DEFAULT_PAGINATION_CLASS
```

`RefundListView` has no `pagination_class`, and `REST_FRAMEWORK` in `reportsvc/settings.py` sets
no `DEFAULT_PAGINATION_CLASS`, so `GET /refunds/` serialises every refund — 3.1 M rows, two N+1
hops each (SM-N1-02) — in one response; the docstring says the CSV export "saves exactly what the
list returned". `StoreRefundListView` below sets `RefundCursorPagination` (SM-DECOY-32). Fix: a
cursor paginator on the view (and a default in settings); stream the export separately. Proof: seed
cap + 1 refunds, assert the response holds at most one page. CWE-770. Owner: query-shape-scan §1 (DRF).

## SM-QS-03 — Public category pages paged by unbounded OFFSET

```defect
id:       SM-QS-03
file:     api/src/catalog/catalog.service.ts
line:     35
severity: high
command:  /db-audit
class:    db/deep-offset
anchor:   offset: (page - 1) * PAGE_SIZE,
match:    offset|\bskip\b|keyset|seek|cursor|deep pag|page number|deep page
```

Public, crawlable category pages compute `offset: (page - 1) * PAGE_SIZE` from an unbounded
`?page=`. Postgres computes and discards every skipped row, so page 2 000 of a 100 000-product
category reads 96 000 rows through the `(category, status, created_at)` index before returning 48 —
and crawlers walk every "next" link. Fix: keyset pagination on `(created_at, id)` with a cursor in
the URL, or cap the page depth. Proof: `EXPLAIN (ANALYZE, BUFFERS)` of page 1 vs page 2 000 on
production-shaped data — buffers grow with the offset. CWE-400. Owner: query-shape-scan §2.

## SM-QS-04 — Email lookup wraps the column in lower(); only a plain index exists

```defect
id:       SM-QS-04
file:     api/src/customers/customer-lookup.service.ts
line:     17
severity: high
command:  /db-audit
class:    db/non-sargable-function
anchor:   .where('lower(c.email) = ?', [email.trim().toLowerCase()])
match:    lower\(|non.?sargable|sargab|expression index|functional index|function (on|around|wrapping|applied to) (the )?column|citext|case.?insensitive|seq(uential)? scan|full (table )?scan|index (can.?not|cannot|can't|won't|will not|isn't|is not|not) (be )?used|bypass(es)? the index
```

Guest order lookup and the support console search customers with `lower(c.email) = ?`.
The only index on the column is the plain `customer_email_index` (initial migration), which a
function on the column cannot use, so every lookup scans 6.1 M customers. Credentials elsewhere do
it the sargable way — `user_credential.email` is stored lower-cased and queried as `email = lower(?)`
(`auth/auth.service.ts`). Fix: an expression index on `lower(email)` (via `/add-migration`, built
concurrently), or store a normalised column. Proof: plan shape — `Seq Scan … Filter: (lower(email) =
…)` before, an index scan after. CWE-1067. Owner: query-shape-scan §4 / index-coverage-scan §6.

## SM-QS-05 — Product search is an infix ILIKE with no trigram index

```defect
id:       SM-QS-05
file:     api/src/catalog/catalog.service.ts
line:     48
severity: high
command:  /db-audit
class:    db/non-sargable-wildcard
anchor:   ilike '%' || ? || '%'
match:    ilike|\blike\s+['\"%]|wildcard|trigram|pg_trgm|gin index|full.?text|tsvector|non.?sargable|sargab|leading %|infix|%q%
```

The storefront search box (the typeahead calls it from the second keystroke) runs
`title ilike '%' || ? || '%'` over 2.3 M products. A leading wildcard cannot use a B-tree, and no
migration creates a `pg_trgm` index, so each keystroke is a sequential scan of `product`. Fix: a GIN
`gin_trgm_ops` index on `title` (with a 3-character minimum), or the search cluster the API already
feeds (`SearchIndexClient`). Proof: `EXPLAIN (ANALYZE, BUFFERS)` with a 3+-character term — Seq Scan
with a large `Rows Removed by Filter` before, a bitmap index scan after. CWE-1067. Owner: query-shape-scan §4.

## SM-QS-06 — Assignee dropdown hydrates whole users, avatar blob included

```defect
id:       SM-QS-06
file:     api/src/staff/staff.service.ts
line:     12
severity: medium
command:  /db-audit
class:    db/over-fetch
anchor:   const users = await this.em.find(User, { memberships: { store: storeId } });
match:    over.?fetch|wide|blob|bytea|avatar|json|preferences|fields\b|projection|select \*|whole (row|entity|user)|full (row|entity|user|object)|entire (row|entity|user)|unneeded|unused columns|only (the )?(id|name)|hydrat|lazy
```

The "assign to" dropdown needs an id and a name per staff member, but `em.find(User, …)`
hydrates the whole entity, including `avatar` (inline `bytea`, up to 512 KB, not lazy) and the
`preferences` JSON. A 200-person store ships ~100 MB from Postgres per dropdown open. The entity file
says why the blob is inline; `Product.descriptionHtml` shows the project knows `lazy: true`. Fix:
`fields: ['id', 'displayName']` (and `lazy: true` on `avatar`). Proof: bytes and rows per call before
and after on the same seed; the captured SQL lists two columns. Owner: query-shape-scan §3.

## SM-IDX-01 — `order_item.order_id` has an FK and no index

```defect
id:       SM-IDX-01
file:     api/src/orders/order-item.entity.ts
line:     10
severity: high
command:  /db-audit
class:    db/fk-without-index
anchor:   @ManyToOne(() => Order)
match:    \bindex|indexed|seq(uential)? scan|full (table )?scan
```

`OrderItem.order` is a `@ManyToOne` with an FK (`order_item_order_id_foreign`, initial migration)
and no index — the `product` relation just below it carries `@Index()`, this one does not.
MikroORM's Postgres schema generator does not index FK columns, so every `items.load()` (SM-N1-01),
every `populate: ['items']`, and every cascaded order delete reads `order_item` (186 M rows) without
an index on `order_id`. Fix: `@Index()` on the property and `CREATE INDEX CONCURRENTLY` in a
non-transactional migration. Proof: `EXPLAIN SELECT … FROM order_item WHERE order_id = $1` — Seq Scan
before, Index Scan after. CWE-1067. Owner: index-coverage-scan §1.

## SM-IDX-02 — `review.product_id` has an FK and no index

```defect
id:       SM-IDX-02
file:     api/db/migrations/2025-09-22_reviews.sql
line:     8
severity: high
command:  /db-audit
class:    db/fk-without-index
anchor:   references product (id) on delete cascade
match:    \bindex|indexed|seq(uential)? scan|full (table )?scan
match:    product_id|product \(id\)|foreign key|\bfk\b|references|reviews?\b
```

`review.product_id … references product (id) on delete cascade` gets no index, while
`author_id` and `created_at` both do. Postgres does not index the referencing column for you. The
product page's review list (`ReviewsService.forProduct`) filters by it, the rating trigger in the
same file re-aggregates `where product_id = …` on every review write, and every product delete
cascades by that column — all reads of a 9.4 M-row table with no index leading with `product_id`. Fix: `create index concurrently review_product_id_idx on review
(product_id)` in its own file. Proof: plan shape on the trigger's aggregate and on `DELETE FROM
product` inside a rolled-back transaction. CWE-1067. Owner: index-coverage-scan §1.

## SM-SCH-01 — Store slug is looked up as unique but has no unique constraint

```defect
id:       SM-SCH-01
file:     api/src/stores/store.entity.ts
line:     22
severity: high
command:  /db-audit
class:    schema/missing-unique
anchor:   slug!: string;
match:    unique|duplicate|race|constraint
```

The store slug is the public URL and is looked up as unique on every storefront request, but
the entity declares only `@Index()` and the initial migration creates a plain `store_slug_index`.
Uniqueness is enforced by `StoreOnboardingService.create` counting first and inserting second; two
sellers claiming the same address at once both pass the count at READ COMMITTED, and one storefront
URL then resolves to two stores. `Product` shows the project's own pattern: `@Unique({ properties:
['store', 'slug'] })` (SM-DECOY-29). Fix: a unique index on `slug` (concurrently), then catch the
`23505`. Proof: N concurrent creates with one slug leave exactly one row. CWE-362. Owner: schema-integrity-scan §3.

## SM-SCH-02 — `order.status` is nullable free text with no CHECK

```defect
id:       SM-SCH-02
file:     api/src/migrations/Migration20240115093000.ts
line:     109
severity: high
command:  /db-audit
class:    schema/missing-check
anchor:   "status" varchar(20) null,
match:    status
match:    \bcheck\b|enum|nullable|\bnull\b|constraint|free.?text|any (string|value)|unconstrained|validat
```

`"status" varchar(20) null` on `order` accepts NULL and any string, while the other lifecycle
columns in the same migration (`store.status`, `product.status`, `payout.status`, `store_member.role`)
carry a `check (… in (…))` and `not null`. Code branches on order status everywhere (`'paid'` filters, the
open-orders partial index, cancellation), and the reports service and raw SQL write paths bypass the
TypeScript union. Fix: backfill NULLs, then `CHECK (status IN (…)) NOT VALID` → `VALIDATE` →
`SET NOT NULL`. Proof: a raw insert of `status = 'payed'` or NULL as the app role must fail with
`23514` / `23502`. Owner: schema-integrity-scan §6.

## SM-SCH-03 — Shipment → order relation created without a database FK

```defect
id:       SM-SCH-03
file:     api/src/shipping/shipment.entity.ts
line:     14
severity: medium
command:  /db-audit
class:    schema/missing-fk
anchor:   createForeignKeyConstraint: false
match:    foreign key|\bfk\b|constraint|orphan|referential|createForeignKeyConstraint
```

`Shipment.order` is declared with `createForeignKeyConstraint: false`, so the database never
checks that a shipment belongs to an existing order. The comment's premise (carrier webhooks can
arrive before the order commits) is a reason to retry or park the webhook, not to drop referential
integrity: orphans accumulate from webhook typos, deleted test orders and replays, and tracking
pages join on them. Fix: restore the FK (`NOT VALID`, clean orphans, `VALIDATE`) and queue early
webhooks. Proof: a raw insert of a shipment for a random order id as the app role must fail with
`23503`. Owner: schema-integrity-scan §1.

## SM-SCH-04 — Product price stored as `double precision`

```defect
id:       SM-SCH-04
file:     api/src/catalog/product.entity.ts
line:     35
severity: high
command:  /db-audit
class:    schema/money-float
anchor:   price!: number;
match:    float|double|\breal\b|binary floating|decimal|numeric|money|rounding|precision|minor units|cents
```

`price` is `type: 'double'` (`double precision` in the initial migration). Checkout turns it
into cents with `Math.round(product.price * 100)` and multiplies by the quantity, CSV and feed
imports write it from decimal strings, and the GraphQL API serves it as a `Float` — binary floating
point cannot represent most decimal prices, so totals drift by a cent and ledger reconciliation
fails. `weightKg` a few
lines below is also a `double` and is correct: a measurement (SM-DECOY-09). Fix: `numeric(12,2)` or
integer minor units (`price_cents bigint`) end to end. Proof: value vectors — 3 × 19.99, 0.1 + 0.2,
and a 3-decimal currency round-trip exactly. CWE-1339. Owner: schema-integrity-scan §4.

## SM-SCH-05 — Refund amount stored as a Django `FloatField`

```defect
id:       SM-SCH-05
file:     reports/refunds/models.py
line:     59
severity: critical
command:  /db-audit
class:    schema/money-float
anchor:   amount = models.FloatField()
match:    float|double|decimal|numeric|money|rounding|precision|DecimalField
```

`Refund.amount = models.FloatField()` stores refunded money as `double precision`, and the
finance summary sums it with `Sum("amount")` before converting to `Decimal` — after the error is in.
Settlement reconciliation against the provider's totals is exactly where this fails. The `order`
foreign key at the top of the model is fine as it is (SM-DECOY-04). Fix: `DecimalField(max_digits=14,
decimal_places=2)` (or integer minor units) via an expand-contract migration; the column is
populated. Proof: value vectors — a three-way split of 100.00 sums back exactly. CWE-1339. Owner: schema-integrity-scan §4.

## SM-SCH-06 — Coupon expiry stored as `timestamp` without time zone

```defect
id:       SM-SCH-06
file:     api/src/migrations/Migration20240115093000.ts
line:     144
severity: medium
command:  /db-audit
class:    schema/timestamp-without-tz
anchor:   "expires_at" timestamp(0) not null,
match:    time.?zone|timestamptz|\btz\b|\butc\b|naive|wall.?clock|\bdst\b
```

`coupon.expires_at` is `timestamp(0)` — no time zone — while every other instant in the schema
is `timestamptz` (the entity overrides MikroORM's `timestamptz` default with `columnType`). An expiry
is an instant: stored as the seller typed it, its meaning depends on the session `TimeZone` of
whoever writes and compares it, so coupons expire hours early or late across zones and DST. `store_hours.opens_at` is a `time` plus
an IANA zone and is correct: a wall-clock value, not an instant (SM-DECOY-10). Fix: `timestamptz`,
converting existing rows with the seller's zone. Proof: run the expiry check under two session time
zones. Owner: schema-integrity-scan §5.

## SM-MIG-01 — Non-concurrent index build on the 41 M-row `order` table

```defect
id:       SM-MIG-01
file:     api/db/migrations/2025-09-22_reviews.sql
line:     44
severity: high
command:  /db-audit
class:    migration/blocking-index-build
anchor:   create index order_customer_id_idx on "order" (customer_id);
match:    concurrent|\block|block|writes? (are |is )?(blocked|wait|queue|stall)|share lock
```

`create index order_customer_id_idx on "order" (customer_id)` is not `CONCURRENTLY`, on a
41 M-row table under checkout traffic. A plain `CREATE INDEX` holds a SHARE lock for the whole
build, which blocks every INSERT and UPDATE on `order` — checkout stops for minutes. The
migrator role's `lock_timeout = '5s'` (`deploy/postgres/roles.sql`) bounds the wait to acquire the
lock, not the build. The index on `review` in the same file is fine: that table is created a few
statements earlier and is empty (SM-DECOY-07). Fix: `create index concurrently …` in a file of its own
(psql runs each statement in autocommit here, so it is allowed). Proof: lock-budget oracle — writes
must not queue during the build. Owner: migration-safety §1.

## SM-MIG-02 — `CREATE INDEX CONCURRENTLY` inside MikroORM's migration transaction

```defect
id:       SM-MIG-02
file:     api/src/migrations/Migration20250918120000.ts
line:     7
severity: high
command:  /db-audit
class:    migration/concurrently-in-transaction
anchor:   create index concurrently if not exists "order_item_product_id_index"
match:    transaction|isTransactional|allOrNothing|wrapp|cannot run inside|transaction block
```

The migration does the right thing in SQL — `create index concurrently` — but MikroORM runs
every migration inside a transaction unless the class overrides `isTransactional()` (the config sets
`transactional: true`), and Postgres refuses `CREATE INDEX CONCURRENTLY` inside a transaction block,
so the release Job fails on deploy. `Migration20250402090000` is the
correct sibling (SM-DECOY-06): same statement, `isTransactional() { return false; }`. Only reading
the runner's wrapping finds this; a linter sees a correct statement. Fix: add the override. Proof:
run the migration through the real migrator on a scratch database and check `pg_index.indisvalid`. Owner: migration-safety §1.

## SM-MIG-03 — `ADD COLUMN … NOT NULL` with no default on a populated table

```defect
id:       SM-MIG-03
file:     api/src/migrations/Migration20250925080000.ts
line:     7
severity: high
command:  /db-audit
class:    migration/not-null-no-backfill
anchor:   add column "fulfillment_channel" varchar(16) not null;
match:    not null|default|backfill|existing rows|populated|23502|nullable|fail
```

`alter table "order" add column "fulfillment_channel" varchar(16) not null;` with no default
and no backfill fails on any table that has rows (`23502`), so this release cannot deploy against
the 41 M-row `order` — and if it is "fixed" by adding a volatile default it becomes a full rewrite.
The entity already declares the field non-null. Fix: add it nullable (or with a constant default,
metadata-only on PG ≥ 11), backfill in batches, then `CHECK (… IS NOT NULL) NOT VALID` → `VALIDATE`
→ `SET NOT NULL`. Proof: run the migration against a copy holding rows. Owner: migration-safety §3.

## SM-MIG-04 — `int → bigint` AlterField rewrites the refunds table under an exclusive lock

```defect
id:       SM-MIG-04
file:     reports/refunds/migrations/0004_widen_psp_refund_number.py
line:     14
severity: critical
command:  /db-audit
class:    migration/table-rewrite
anchor:   field=models.BigIntegerField(unique=True),
match:    rewrite|alter.{0,20}type|type change|bigint|access exclusive|\block|block|copy|expand.?contract
```

`AlterField` from `IntegerField` to `BigIntegerField(unique=True)` makes Django emit `ALTER
TABLE … ALTER COLUMN … TYPE bigint`: `int → bigint` is not binary-coercible, so Postgres rewrites
the 3.1 M-row `refunds_refund` and rebuilds its unique index under ACCESS EXCLUSIVE, blocking every
read and write of refunds (and the nightly settlement import) for the duration. The trigger — ids
past 2³¹ — is real; the shape is the defect. Fix: expand-contract — add a `bigint` column, dual-write,
backfill in batches, build the unique index concurrently, swap. Proof: `migration-rehearsal`'s
rewrite probe (`pg_relation_filenode` changes) plus the lock-budget oracle. Owner: migration-safety §2.

## SM-TX-01 — Payment capture called inside the checkout transaction

```defect
id:       SM-TX-01
file:     api/src/checkout/checkout.service.ts
line:     72
severity: high
command:  /db-audit
class:    tx/external-io-in-transaction
anchor:   const capture = await this.psp.capture(order.paymentIntentId, order.totalCents);
match:    transaction|transactional|\btx\b|\block|idle in transaction|outbox|after.?commit|commit
match:    psp|payment|capture|http|external|outbound|network|i/o|\bio\b|remote|provider
```

`placeOrder` locks the counter row (SM-TX-08) and the product rows `FOR UPDATE`, flushes the
order, and then calls the payment provider's capture inside the same `em.transactional` — over an
HTTP client with no timeout (SM-RS-01). Every lock and the pooled connection are held for the
provider's latency; if the provider hangs, so does checkout, and if the commit then fails the card
has been charged for an order that does not exist. `cancel` below shows the project's own pattern:
the side effect leaves as an outbox row (SM-DECOY-11). Fix: commit the pending order, capture after
commit (or via the outbox), then mark it paid. Proof: stub the capture with a 2 s delay; the session
shows `idle in transaction` and a concurrent stock update waits. Owner: transaction-scan §1.

## SM-TX-02 — Raw `getConnection().execute` escapes the payout transaction

```defect
id:       SM-TX-02
file:     api/src/payouts/payout-ledger.service.ts
line:     33
severity: high
command:  /db-audit
class:    tx/wrong-handle
anchor:   await em.getConnection().execute(
match:    getTransactionContext|transaction context|another (pooled )?connection|other connection|separate connection|different connection|outside (the|its|of the) transaction|(?:not|n.t) (in|part of|inside) the transaction|its own connection|(?:does(?: not|n.t)|never) uses? the transaction|escape|wrong handle|atomic|partial|rolled? back|rollback
```

`markPaid` opens `em.transactional` and then writes the payout status through
`em.getConnection().execute(…)` with no `em.getTransactionContext()` argument. In MikroORM that call
runs on another pooled connection, outside the transaction: the UPDATE commits on its own, and if the
fee ledger entry that follows fails, the payout stays `paid` with no fee booked — the opposite of
"all or nothing". It looks like it is inside the transaction because it uses the callback's `em`.
`schedulePayout` above it writes everything through the fork (SM-DECOY-12). Fix: `em.execute(…)`, or
pass `em.getTransactionContext()` as the fourth argument. Proof: throw after the raw update; the
payout row must not change. Owner: transaction-scan §2.

## SM-TX-03 — Settings JSON merged in memory and written back whole

```defect
id:       SM-TX-03
file:     api/src/stores/store-settings.service.ts
line:     19
severity: medium
command:  /db-audit
class:    tx/lost-update
anchor:   store.settings = { ...store.settings, ...patch };
match:    lost update|last.?writer|overwrit|clobber|concurren|race|read.?modify.?write|jsonb_set|version|optimistic|\block
```

`update` reads the store, merges the patch into `settings` in memory, and flushes — MikroORM
writes the whole JSON column. Two staff members saving different screens at once (the comment says
this is common) each write back their own copy, and the second silently drops the first's section.
`setFeature` in the same file is the atomic form (SM-DECOY-14): one `UPDATE … jsonb_set(…)`. Fix:
merge in SQL (`settings || ?::jsonb` per section), or a version column with compare-and-set and a
retry. Proof: two concurrent PATCHes of different sections — both survive. CWE-362. Owner: transaction-scan §8.

## SM-TX-04 — "At least one owner" checked by a count, enforced by nothing

```defect
id:       SM-TX-04
file:     api/src/stores/store-members.service.ts
line:     21
severity: high
command:  /db-audit
class:    tx/write-skew
anchor:   if (owners <= 1) {
match:    write skew|race|concurren|both|two (requests|admins|owners|transactions|demotions)|zero owners|no owners?|last owner|invariant|serializable|for update|\block|check.?then
```

"A store always has at least one owner" is checked by counting owners and enforced by nothing:
`changeRole` runs at the default READ COMMITTED, so two owners demoting each other at the same time
both count 2, both pass, and the store is left with no owner (nobody can manage payouts). Write skew
— a transaction alone does not prevent it. Fix: lock the store row (`FOR UPDATE`) before counting,
or SERIALIZABLE with a retry. Proof: barrier test — two transactions count, wait on a latch, then
demote; at least one owner must remain. CWE-362. Owner: transaction-scan §7.

## SM-TX-05 — SERIALIZABLE booking transaction with no retry on 40001

```defect
id:       SM-TX-05
file:     api/src/pickup/pickup-slots.service.ts
line:     36
severity: medium
command:  /db-audit
class:    tx/serializable-no-retry
anchor:   { isolationLevel: IsolationLevel.SERIALIZABLE }
match:    retry|retries|40001|serializ(ation|able) (failure|error|conflict)|could not serialize|\b500\b
```

The booking uses SERIALIZABLE — the correct isolation for "count then insert" against slot
capacity — but nothing catches `40001`. When a popular Saturday window opens, concurrent bookings
abort with serialization failures that reach buyers as 500s, exactly when demand peaks. Fix: retry
the whole transaction closure on `40001` / `40P01` with bounded, jittered backoff (no side effects
inside the closure). Proof: force the conflict with two concurrent bookings, or a stubbed driver
error carrying SQLSTATE `40001`; the booking completes exactly once. CWE-755. Owner: transaction-scan §4.

## SM-TX-06 — Outbox claim uses `FOR UPDATE` without `SKIP LOCKED` across four relays

```defect
id:       SM-TX-06
file:     api/src/outbox/outbox-relay.ts
line:     29
severity: high
command:  /db-audit
class:    tx/claim-without-skip-locked
anchor:   limit ? for update)
match:    skip locked|skip_locked|block|serializ|queue (up )?behind|wait|contention|concurren|workers|replicas|relays
```

Four worker pods run the relay every 200 ms, and the claim's subquery takes `FOR UPDATE`
without `SKIP LOCKED`: while one relay holds the oldest 100 rows, the other three block on those same
rows instead of taking the next batch, so throughput stays at one relay's worth and lock waits pile up
behind any slow batch. The webhook retry poller uses the same shape safely because it has exactly one
consumer (SM-DECOY-13). Fix: `… order by id limit ? for update skip locked`. Proof: N workers on M
rows — every row published exactly once and no worker waits on another's locks. CWE-362. Owner: transaction-scan §5.

## SM-TX-07 — A savepoint per settlement row

```defect
id:       SM-TX-07
file:     reports/refunds/importers.py
line:     32
severity: medium
command:  /db-audit
class:    tx/savepoint-per-item
anchor:   with transaction.atomic():  # one bad row must not abort the batch
match:    savepoint|subtransaction|nested (atomic|transaction)|get_or_create|per.?(row|item|line)|SubtransSLRU|SubtransControlLock|pg_subtrans
```

Each settlement row runs in its own nested `transaction.atomic()` — a SAVEPOINT — inside a
1 000-row outer transaction, and `get_or_create` adds savepoint traffic of its own. That is 20 000 to
90 000 savepoints per nightly file. Past 64 open subtransactions per backend Postgres spills to
`pg_subtrans`, and combined with any long-running transaction it stalls the replica on
`SubtransSLRU` (GitLab, 2021). Fix: one `INSERT … ON CONFLICT` per chunk (`bulk_create(…,
update_conflicts=True)`), validating rows before the write instead of catching per row. Proof: count
`SAVEPOINT` statements per import at 2 and 20 rows — constant after the fix. Owner: transaction-scan §10.

## SM-TX-08 — Every checkout locks the same counter row first

```defect
id:       SM-TX-08
file:     api/src/checkout/checkout.service.ts
line:     34
severity: medium
command:  /db-audit
class:    tx/hot-row
anchor:   update platform_counters set orders_today = orders_today + 1 where id = 1
match:    hot|counter|platform_counters|single row|one row|same row|contention|serializ|queue|orders_today|bottleneck
```

The first statement of every checkout transaction increments `platform_counters` row 1, and the
row lock is then held until commit — through the stock locks, the flush and the payment capture
(SM-TX-01). Every checkout on the platform serialises on that one row: throughput is capped at one
order per capture latency. The statement is the textbook fix for a lost update, which is what makes
it look right. Fix: count orders asynchronously (from `order` or the outbox), or shard the counter
and update it last, after the capture. Proof: K concurrent checkouts — `wait_event_type = 'Lock'` on
`platform_counters` before, near zero after. Owner: transaction-scan §9.

## SM-CONN-01 — 25 connections × 12 API pods (plus the worker) against `max_connections = 200`

```defect
id:       SM-CONN-01
file:     deploy/k8s/api.yaml
line:     40
severity: high
command:  /db-audit
class:    conn/connection-budget
anchor:   - name: DB_POOL_MAX
match:    max_connections|connection (budget|limit|count|ceiling|exhaust)|too many (clients|connections)|53300|pool.{0,60}(replica|pod|hpa|×|\bx\b|\*|times)|(replica|pod|hpa|maxReplicas).{0,80}pool|pgbouncer|exceed
```

Connection budget at maximum scale, every term cited: API `DB_POOL_MAX = 25` × HPA `maxReplicas:
12` (same file) = 300, plus `maxSurge: 25%` during a rollout (3 pods, 75); worker 10 × 4 pods = 40
(`deploy/k8s/worker.yaml`) plus the indexer's own pool of 2 per pod; PgBouncer's server pool 40 + 10
reserve for reports (`deploy/pgbouncer/pgbouncer.ini`). Σ ≈ 400–475 against `max_connections =
200` with 3 reserved (`deploy/postgres/postgresql.conf`). The API connects to Postgres directly, not
through PgBouncer, so the pooler does not absorb it, and the replica pool is the same size on a
server with the same ceiling. The HPA scales on CPU under load — exactly when `53300 too many
clients` starts. Fix: size the per-pod pool from the arithmetic (about 6 at 12 pods plus surge) or route
the API through a transaction pooler. Proof: the table, then a load test at 12 pods. CWE-770. Owner: connection-config-scan §2.

## SM-CONN-02 — API sessions run with no statement timeout

```defect
id:       SM-CONN-02
file:     api/src/config/mikro-orm.config.ts
line:     27
severity: medium
command:  /db-audit
class:    conn/no-statement-timeout
anchor:   driverOptions: {
match:    statement.?timeout|query.?timeout|statement_timeout|57014|runaway|no timeout|unbounded (query|statement)|statementTimeoutMs
```

`driverOptions.connection` sets `idle_in_transaction_session_timeout` but no
`statement_timeout`, and the `stallwise_api` role sets none either (`deploy/postgres/roles.sql`
says "the API sets its own session limits from its config"). `database.ts` does define
`statementTimeoutMs` (15 s) — it is simply never passed to the driver. A runaway query (an export,
a scan from SM-QS-05) holds its connection and locks without bound, on a pool of 25. Fix: pass
`statement_timeout: db.statementTimeoutMs` beside the idle timeout, or `ALTER ROLE stallwise_api SET
statement_timeout`. Proof: `SELECT pg_sleep(16)` through the app's pool is cancelled with `57014`.
CWE-400. Owner: connection-config-scan §5.

## SM-CONN-03 — Reports sessions have no idle-in-transaction timeout (and PgBouncer's is 0)

```defect
id:       SM-CONN-03
file:     deploy/pgbouncer/pgbouncer.ini
line:     22
severity: medium
command:  /db-audit
class:    conn/no-idle-in-transaction-timeout
anchor:   idle_transaction_timeout = 0
match:    idle.?in.?transaction|idle_in_transaction|idle_transaction_timeout|transaction_timeout|lock_timeout|idle in tx
```

The reports service sets `statement_timeout` on its role but nothing bounds a transaction left
open: no `idle_in_transaction_session_timeout` on the role, and PgBouncer's
`idle_transaction_timeout = 0` disables the pooler's own guard. In transaction mode a client that
stalls inside an `atomic` block — the settlement import run from finance's "re-import" button, a
thread wedged on I/O, a crashed client that never sends `COMMIT` — keeps its server connection out
of a pool of 40, holding its row locks and the xmin horizon, with nothing to end it. Fix: `idle_transaction_timeout` in PgBouncer and `ALTER ROLE stallwise_reports SET
idle_in_transaction_session_timeout = '30s'`. Proof: open a transaction through the pooler, idle past
the timeout, and the server ends it. Owner: connection-config-scan §6.

## SM-CONN-04 — Store re-read from a replica right after it was published

```defect
id:       SM-CONN-04
file:     api/src/stores/store-onboarding.service.ts
line:     36
severity: medium
command:  /db-audit
class:    conn/read-after-write-replica
anchor:   const published = await this.em.findOneOrFail(Store, { id: storeId, status: 'published' }, { populate: ['owner'] });
match:    replica|preferReadReplicas|read.?after.?write|read.?your.?writes|stale|\blag\b|replication|primary|connectionType
```

`publish` flips the store to `published` with `nativeUpdate` (primary) and immediately re-reads
it with `findOneOrFail(…, { status: 'published' })` outside a transaction. With `replicas`
configured and `preferReadReplicas` left at its default (`true`), that read goes to the asynchronous
replica: under any lag the seller gets a 404 right after a successful publish, or search indexes the
stale draft. `suspend` below pins its read-after-write to the primary with
`{ connectionType: 'write' }` (SM-DECOY-15). Fix: the same option here, or do the update and read in
one transaction. Proof: pause replay on the replica (`pg_wal_replay_pause()`), publish, and the read
must still see `published`. Owner: connection-config-scan §8.

## SM-RT-01 — 50 MB feed decompressed with `gunzipSync` on the event loop

```defect
id:       SM-RT-01
file:     api/src/catalog/feed-upload.controller.ts
line:     33
severity: high
command:  /perf-audit
class:    perf/event-loop-blocking-zlib
anchor:   const xml = gunzipSync(body).toString('utf8');
match:    sync|event.?loop|block|main thread|cpu
```

The feed upload decompresses up to 50 MB of gzip (several hundred MB of XML) with
`gunzipSync`, then parses it synchronously — on the event loop, inside a request handler. While it
runs, the pod serves nothing else: every other request's latency grows by seconds, and the larger
sellers push every 15 minutes. The pull route in the same controller streams through
`createGunzip()` into a batching parser (SM-DECOY-30). Fix: stream the request body through
`createGunzip()` the same way (or hand the file to the worker). Proof: `monitorEventLoopDelay` p99
while uploading a 50 MB feed under concurrent traffic. CWE-400. Owner: request-path-scan §4, §6.

## SM-RT-02 — 600 k-iteration `pbkdf2Sync` on every login

```defect
id:       SM-RT-02
file:     api/src/auth/password.service.ts
line:     36
severity: high
command:  /perf-audit
class:    perf/event-loop-blocking-crypto
anchor:   pbkdf2Sync(password, salt, rounds, KEY_LENGTH, DIGEST)
match:    sync|event.?loop|block|main thread|cpu|libuv|thread.?pool
```

`verify` runs `pbkdf2Sync` at 600 000 iterations on every login — about half a second of CPU
on the event loop per attempt, and failed attempts cost the same because unknown emails verify
against a dummy hash. Twenty concurrent logins freeze the pod for ten seconds. `hash` in the same
class uses the promisified `pbkdf2`, which runs on the libuv thread pool (SM-DECOY-31). Fix:
`await pbkdf2Async(…)` in `verify` too (and size `UV_THREADPOOL_SIZE`). Proof: event-loop delay p99
with 20 concurrent logins. CWE-400. Owner: request-path-scan §4, §5.

## SM-RT-03 — 30 MB snapshot read and parsed synchronously on every request

```defect
id:       SM-RT-03
file:     api/src/catalog/catalog-snapshot.controller.ts
line:     29
severity: high
command:  /perf-audit
class:    perf/event-loop-blocking-json
anchor:   JSON.parse(readFileSync(SNAPSHOT_PATH, 'utf8'))
match:    sync|event.?loop|block|readFileSync|JSON\.parse|per request|every request|each request|buffer|stream
```

Every request to `/catalog/snapshot/:category` reads the ~30 MB snapshot file with
`readFileSync` and parses all of it with `JSON.parse` to return one category — both synchronous, on
the event loop, per request. The CDN re-pulls each category every 60 s, and the storefront's catalog
page requests it on every visit (`web/src/pages/CatalogPage.tsx`). `receipt-template.ts` shows the
acceptable use of `readFileSync`: once, at module load (SM-DECOY-17). Fix: load and index the snapshot
once per file change (watch / mtime check), or split it per category. Proof: event-loop delay and
p99 under 20 concurrent snapshot requests. CWE-400. Owner: request-path-scan §4, §6.

## SM-RT-04 — Order detail awaits four independent lookups one after another

```defect
id:       SM-RT-04
file:     api/src/orders/order-detail.service.ts
line:     27
severity: medium
command:  /perf-audit
class:    perf/sequential-awaits
anchor:   const tracking = await this.carrier.tracking(order.shipmentRef);
match:    sequential|serial|one after (another|the other)|independent|Promise\.all|parallel|concurren|waterfall|back.?to.?back
```

`getDetail` awaits carrier tracking, the invoice summary, the review prompts and the
recommendations one after another, though each depends only on `order`, not on the others: the page
pays the sum of four latencies (carrier ~150 ms, recommendations up to 800 ms) instead of the
largest. `invoiceLink` below has two sequential awaits that are correct — the second needs the first
one's `pdfKey` (SM-DECOY-18). Fix: `Promise.all` over the four after loading the order (backend's
`parallelize-independent-ops`). Proof: mock each dependency at latency L; wall-clock must drop from
~4L to ~L. Owner: request-path-scan §1.

## SM-RT-05 — Seller dashboard awaits four independent widgets in sequence

```defect
id:       SM-RT-05
file:     api/src/dashboard/seller-dashboard.service.ts
line:     19
severity: medium
command:  /perf-audit
class:    perf/sequential-awaits
anchor:   const sales = await this.stats.salesSummary(storeId, range);
match:    sequential|serial|one after (another|the other)|independent|Promise\.all|parallel|concurren|waterfall|back.?to.?back
```

`overview` awaits four independent widgets in sequence — sales stats, the open-order count, the
payout list and the inbox service — on the first screen every seller sees, re-polled every 30 s
while the dashboard is open. None of the four reads another's result. Fix: `Promise.all` (the four
use different resources: two indexed queries, one more query, one HTTP call with a 1 s timeout).
Proof: mocked latency L per dependency; wall-clock < 2L. Owner: request-path-scan §1.

## SM-RT-06 — One carrier request per cart line, all in flight at once

```defect
id:       SM-RT-06
file:     api/src/checkout/shipping-quotes.service.ts
line:     26
severity: high
command:  /perf-audit
class:    perf/unbounded-fan-out
anchor:   cart.items.map((item) => this.carrier.quote(item, destination))
match:    unbounded|fan.?out|concurren|Promise\.all|p-limit|plimit|semaphore|throttl|burst|in.?flight|all at once|every (item|line)|each (item|line)
```

`quoteCart` issues one carrier request per cart line, all at once, and wholesale carts have
several hundred lines: one checkout step opens hundreds of concurrent sockets to the aggregator and
trips its rate limit for every other buyer. `pickupWindows` in the same service caps its fan-out with
`p-limit(8)` (SM-DECOY-16). Fix: the aggregator's multi-parcel endpoint, or `p-limit` with a small
cap, plus a maximum cart size on the DTO. Proof: N = 1 000 lines, assert max in-flight ≤ the cap.
CWE-770. Owner: request-path-scan §2.

## SM-RS-01 — Payment-provider client has no timeout

```defect
id:       SM-RS-01
file:     api/src/payments/psp.client.ts
line:     23
severity: critical
command:  /perf-audit
class:    perf/missing-outbound-timeout
anchor:   this.http = axios.create({
match:    timeout|deadline|hang|AbortSignal|abort
```

The payment client is `axios.create` with no `timeout` (axios's default is 0: wait forever) and
the capture call passes no `signal`. It is called inside the checkout transaction (SM-TX-01), so a
provider stall holds row locks, a pooled connection and the request indefinitely. `CarrierClient`
sets both a client timeout and a per-call `AbortSignal.timeout` (SM-DECOY-19). Fix: a timeout below
the request budget on the client and per call, with an idempotent retry on the capture (it is keyed
by the intent id). Proof: a black-holed provider (Toxiproxy) — the call fails within the deadline.
CWE-400. Owner: request-path-scan §12.

## SM-RS-02 — FX-rate fetch in a request path has no timeout

```defect
id:       SM-RS-02
file:     reports/refunds/fx.py
line:     34
severity: high
command:  /perf-audit
class:    perf/missing-outbound-timeout
anchor:   resp = requests.get(FX_RATES_URL, params={"base": base, "date": day.isoformat()})
match:    timeout|deadline|hang|block
```

`fx.rate` calls `requests.get` with no `timeout`; requests waits forever by default. It runs
inside `RefundSummaryView`, on gunicorn `gthread` workers whose request threads gunicorn's own
`timeout` does not reclaim, so a stalled treasury service ties up threads one by one until the
reports service stops answering. The `lru_cache` helps only after a success. Fix:
`requests.get(…, timeout=(3, 10))` and a fallback for the tile. Proof: point `FX_RATES_URL` at a
black hole; the view returns within the deadline. CWE-400. Owner: request-path-scan §12.

## SM-SC-01 — Login attempt limiter counts in process memory, per pod

```defect
id:       SM-SC-01
file:     api/src/auth/login-rate-limiter.ts
line:     10
severity: high
command:  /perf-audit
class:    scale/per-replica-rate-limiter
anchor:   private readonly attempts = new Map<string, number[]>();
match:    replica|\bpods?\b|instance|process|in.?memory|\blocal\b|redis|shared|distributed|horizontal
```

The brute-force guard counts failed logins in a `Map` inside the process. The API runs 3–12 pods
behind a load balancer, so "10 attempts per email per 15 minutes" is really 10 × the pod count, and
every rollout resets it. The public throttler in `app.module.ts` keeps its counters in Redis, shared
by every pod (SM-DECOY-20) — this one does not. Fix: the same Redis-backed storage (an atomic
`INCR` + `EXPIRE` per email). Proof: run two replicas and send 10 failures through each; the 11th
attempt overall must be refused. CWE-307. Owner: request-path-scan §18 (an authentication limit: security corroborates).

## SM-SC-02 — Hourly payout reminder runs on every API pod

```defect
id:       SM-SC-02
file:     api/src/payouts/payout-reminder.cron.ts
line:     18
severity: medium
command:  /perf-audit
class:    scale/cron-on-every-replica
anchor:   @Cron('0 * * * *')
match:    replica|\bpods?\b|instance|every (node|process)|duplicate|twice|each (replica|pod|instance)|leader|\block|once
```

`@nestjs/schedule` runs `@Cron` in every process that loads the module, and `PayoutsModule` is
part of the API, which runs 3 to 12 pods: every seller with a failed payout gets the hourly reminder
3–12 times an hour. `nightlySummary` in the same class guards itself by claiming `(job, run_date)`
with a unique insert first (SM-DECOY-21). Fix: the same claim (keyed by the hour), a leader lock, or
move the schedule to a single-replica CronJob. Proof: two instances on a short schedule — five ticks
send five batches, not ten. Owner: request-path-scan §20.

## SM-CM-01 — Module-level product snapshot map that is never evicted

```defect
id:       SM-CM-01
file:     api/src/catalog/product-snapshot.cache.ts
line:     19
severity: high
command:  /perf-audit
class:    memory/unbounded-map
anchor:   const snapshots = new Map<string, ProductSnapshot>();
match:    unbounded|never evict|no evict|without evict|grow|leak|memory|heap|\boom\b|\bmax\b|\bttl\b|\blru\b|size
```

`snapshots` is a module-level `Map` keyed by product id with no size bound and no eviction:
the freshness check only decides whether to refresh an entry, never whether to drop it, and
`invalidate` runs only on product updates. Every product any cart ever touched (2.3 M products)
stays in every pod's heap until it restarts, and each pod's copy can be up to the TTL stale.
`ProductPageCache.cards` is the bounded form the project already uses (SM-DECOY-22: `max` + `ttl`).
Fix: an `LRUCache` with `max` and `ttl`. Proof: heap growth after N distinct product reads, forced
GC, stays under ε. CWE-401. Owner: memory-growth-scan §1.

## SM-CM-02 — Indexer loops forever on MikroORM's global EntityManager

```defect
id:       SM-CM-02
file:     api/src/worker/search-indexer.worker.ts
line:     19
severity: high
command:  /perf-audit
class:    memory/orm-identity-map-growth
anchor:   allowGlobalContext: true,
match:    identity map|unit of work|fork|clear|global context|allowGlobalContext|memory|heap|grow|leak|managed entit
```

The search indexer initialises its own `MikroORM` with `allowGlobalContext: true` and loops for
the life of the pod on the global `orm.em`, never forking or clearing it. Every product and store it
ever loads stays in the identity map (feed imports touch hundreds of thousands of products a day),
and each `flush()` computes change sets over all of them, so memory and CPU grow until the pod is
OOM-killed. Fix: `const em = orm.em.fork()` per batch (or `em.clear()` after each flush) and drop
`allowGlobalContext`. Proof: heap after 100 batches vs after 10 — flat after the fix. CWE-401. Owner: memory-growth-scan §7.

## SM-CM-03 — A price listener per socket, never removed

```defect
id:       SM-CM-03
file:     api/src/realtime/price.gateway.ts
line:     35
severity: medium
command:  /perf-audit
class:    memory/listener-leak
anchor:   this.priceFeed.on('price', listener);
match:    listener|leak|off\(|removeListener|remove|unsubscribe|disconnect|MaxListeners|memory|heap|grow
```

Each WebSocket connection adds a `price` listener to the shared `PriceFeed` emitter and nothing
removes it: `handleDisconnect` removes the stock listener only. The listener closes over the socket,
so every closed socket stays reachable, and every price event walks every listener ever added —
~40 k open sockets at peak, plus each mobile reconnect adds another. `setMaxListeners(0)` on the feed
hid the warning Node would have printed. The stock listener in the same gateway is removed on
disconnect (SM-DECOY-24). Fix: keep the price listener in the subscription record and `off` it too.
Proof: connect and disconnect N clients; `priceFeed.listenerCount('price')` returns to 0. CWE-401. Owner: memory-growth-scan §2.

## SM-CM-04 — Home feed rebuilt by every request that misses at once

```defect
id:       SM-CM-04
file:     api/src/storefront/home-feed.service.ts
line:     37
severity: high
command:  /perf-audit
class:    cache/stampede
anchor:   const feed = await this.buildFeed();
match:    stampede|thundering herd|dog.?pile|single.?flight|coalesc|\block|concurrent miss|simultaneous|many requests|cache miss|expir
```

`feed()` is the busiest endpoint (~1 400 rps at peak) and its single cache key expires every 60
s. On each expiry every concurrent request misses, and each calls `buildFeed()` — the
recommendations service's ranking job (~1.2 s, sized for a few calls a minute): roughly 1 400 × 1.2 ≈
1 700 concurrent origin calls per expiry. `categoryTree()` below coalesces misses through an
in-flight promise map (SM-DECOY-23). Fix: the same single-flight (plus a short Redis `SET NX` lock
across pods), or refresh ahead of expiry and serve stale. Proof: 100 concurrent misses → 1 origin
call. Owner: caching-scan §2.

## SM-CM-05 — Product cache key omits the store; slugs are only unique per store

```defect
id:       SM-CM-05
file:     api/src/catalog/product-cache.service.ts
line:     45
severity: critical
command:  /perf-audit
class:    cache/key-missing-tenant (security-routed)
anchor:   const key = `product:${slug}`;
match:    tenant|store.?id|per.?store|cross.?(store|tenant)|other store|another store|wrong store|different store|two stores|without the store|each other.s|collid|collision|isolation|scop|leak
```

The product page cache keys entries by `product:${slug}`, but product slugs are unique only per
store (`@Unique({ properties: ['store', 'slug'] })` on `Product`). Two stores selling a
`classic-tee` share one cache entry: buyers of store A see store B's product, price and stock for
five minutes, and `evictPage` on one store's edit clears the other's. That is cross-tenant data
exposure, so it routes to security's `@tenant-isolation-reviewer` when that pack is installed and is
reported here otherwise. `card()` in the same class keys by `store:${storeId}` (SM-DECOY-22). Fix:
include the store slug (or id) in the key and in `evictPage`. Proof: populate as store A, read store
B's same slug — a miss. CWE-524. Owner: caching-scan §3 (identity leg → security @tenant-isolation-reviewer, when installed).

## SM-FE-01 — Seller analytics (echarts + xlsx) imported eagerly into the storefront entry

```defect
id:       SM-FE-01
file:     web/src/routes.tsx
line:     8
severity: medium
command:  /perf-audit
class:    frontend/initial-bundle
anchor:   import SellerAnalyticsPage from './pages/seller/SellerAnalyticsPage';
match:    lazy|code.?split|\bsplit|initial (bundle|chunk|load|route|js)|main (bundle|chunk)|bundle|chunk|eager|static(ally)? import|echarts|xlsx|dynamic import
```

The router's own comment says the seller area loads on demand, and every other seller page is
`lazy()` (SM-DECOY-27) — but `SellerAnalyticsPage` is imported statically, and it imports the full
`echarts` build and `xlsx`. Both land in the entry chunk that every storefront visitor downloads and
parses before Home renders: roughly 1 MB of minified JavaScript for a page only sellers open. Fix:
`const SellerAnalyticsPage = lazy(() => import('./pages/seller/SellerAnalyticsPage'))`. Proof: the
entry chunk's size before and after (`vite build` + bundle report). Owner: frontend bundle-analyze (Browser load row; /bundle-perf).

## SM-FE-02 — Cart context value rebuilt every second at the app root

```defect
id:       SM-FE-02
file:     web/src/App.tsx
line:     48
severity: medium
command:  /perf-audit
class:    frontend/re-render-storm
anchor:   <CartContext.Provider value={{ cart, addItem, removeItem, clear }}>
match:    re.?render|render|memo|new object|identity|context value|value=\{\{|consumer
```

`App` re-renders every second (the promo countdown's `setNow`), and each render passes a new
`{ cart, addItem, removeItem, clear }` object to `CartContext.Provider`. Every `useCart()` consumer —
the header and each `ProductCard` in a 96-card grid — re-renders every second whether or not the
cart changed. `SessionProvider` memoizes its value with `useMemo` (SM-DECOY-26). Fix: `useMemo` the
value on `[cart, addItem, removeItem, clear]`, and move the countdown state into `PromoBar`. Proof:
React Profiler render counts over 10 s on the catalog page. Owner: /bundle-perf (Browser interaction row: render waste).

## SM-FE-03 — Hero image (the LCP element) is lazy-loaded

```defect
id:       SM-FE-03
file:     web/src/pages/HomePage.tsx
line:     24
severity: medium
command:  /perf-audit
class:    frontend/lcp-lazy-hero
anchor:   className="hero__image"
match:    \blcp\b|largest contentful|lazy|fetchpriority|priority|preload|above.?the.?fold|hero
```

The home page hero is the largest above-the-fold element — the LCP candidate — and it carries
`loading="lazy"`, so the browser defers its fetch until layout confirms it is in the viewport, after
the JavaScript has run. The URL is static, so it could have been preloaded and fetched at high
priority. The review photos further down are lazy correctly: they are below the fold
(SM-DECOY-25). Fix: `loading="eager"` and `fetchpriority="high"` on the hero (and a preload in
`index.html`). Proof: Lighthouse `lcp-lazy-loaded` and LCP from the field before and after. Owner: frontend lcp-audit (Browser load row; /bundle-perf).

## SM-FE-04 — Search box sorts and filters 20 k products synchronously per keystroke

```defect
id:       SM-FE-04
file:     web/src/pages/CatalogPage.tsx
line:     75
severity: medium
command:  /perf-audit
class:    frontend/inp-long-task
anchor:   setVisible(sortAndFilter(products, value, sort));
match:    \binp\b|interaction|long task|main thread|block|keystroke|every (key|input|change|character)|debounce|defer|useDeferredValue|startTransition|worker|jank|responsive|sort
```

`onSearchInput` sorts and filters the whole category (~20 000 products) synchronously inside the
input's change handler, on every keystroke, before React can paint the typed character: a long task
per key and a poor INP on the most-used control of the page. The facet slider beside it renders from
`useDeferredValue` (SM-DECOY-28), off the urgent path. Fix: keep the input state urgent and derive
the results from `useDeferredValue(query)` / `startTransition` (or a worker), with the sort memoized.
Proof: INP attribution from `web-vitals` (or a Performance-panel long task) while typing. Owner: /bundle-perf, web-vitals-field (Browser interaction row: long task in an input handler).

---

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded defect — same file or same feature, same vocabulary,
no defect — and most were written so that only reading the code tells them apart. A run that reports
one has produced a false positive **by construction**.

How they score (`score.py`, § DECOYS in its header): a finding that names the decoy's file,
cites a line within the tolerance window of the decoy's line, and matches every one of the decoy's
`match:` patterns is **pinned** to it. A pinned finding is removed before defect assignment — it can
never be credited as a detection — and is reported as `DECOYS FLAGGED k/N`, where N counts the
decoys of the command being scored (17 for `/db-audit`, 15 for `/perf-audit`). A finding
with no line is never pinned, and a finding a seeded defect could claim at EXACT strength is never
pinned. Every decoy sits more than 12 lines from any defect in its file, which `--verify` enforces, so
the two windows never overlap.

| id | file:line | command | looks like | why it is safe |
|----|-----------|---------|-----------|----------------|
| SM-DECOY-01 | `api/src/orders/order-history.service.ts:39` | `/db-audit` | SM-N1-01 | items populated on the list query, keyset-paged at 20 |
| SM-DECOY-02 | `api/src/catalog/product.resolver.ts:65` | `/db-audit` | SM-N1-05 | request-scoped DataLoader batches the field into one `IN` query |
| SM-DECOY-03 | `api/src/catalog/product-import.service.ts:79` | `/db-audit` | SM-N1-06 | one `IN` query per 500-SKU chunk: a bounded batch, not a per-row query |
| SM-DECOY-04 | `reports/refunds/models.py:45` | `/db-audit` | SM-IDX-01 | Django creates an index for every `ForeignKey` (`db_index=True` by default) |
| SM-DECOY-05 | `api/src/orders/seller-orders.service.ts:22` | `/db-audit` | SM-QS-01 | capped at 50 and served by `order(store_id, created_at desc)` |
| SM-DECOY-06 | `api/src/migrations/Migration20250402090000.ts:13` | `/db-audit` | SM-MIG-02 | `isTransactional()` returns false and the migrator runs with `allOrNothing: false` |
| SM-DECOY-07 | `api/db/migrations/2025-09-22_reviews.sql:23` | `/db-audit` | SM-MIG-01 | `review` is created earlier in the same file: the table is empty |
| SM-DECOY-08 | `api/src/geo/countries.service.ts:17` | `/db-audit` | SM-QS-01 | 250-row lookup table, fixed by the domain, cached for a day |
| SM-DECOY-09 | `api/src/catalog/product.entity.ts:51` | `/db-audit` | SM-SCH-04 | a measurement, not money: binary float is correct |
| SM-DECOY-10 | `api/src/stores/store-hours.entity.ts:20` | `/db-audit` | SM-SCH-06 | a wall-clock `time` beside an IANA zone column: not an instant |
| SM-DECOY-11 | `api/src/checkout/checkout.service.ts:89` | `/db-audit` | SM-TX-01 | an outbox row in the same transaction is the correct side-effect pattern |
| SM-DECOY-12 | `api/src/payouts/payout-ledger.service.ts:17` | `/db-audit` | SM-TX-01 | the job is a row in the same database, written through the transaction's EntityManager |
| SM-DECOY-13 | `api/src/webhooks/webhook-retry.poller.ts:54` | `/db-audit` | SM-TX-06 | one consumer by construction: a session advisory lock on a dedicated, unpooled connection |
| SM-DECOY-14 | `api/src/stores/store-settings.service.ts:33` | `/db-audit` | SM-TX-03 | one `UPDATE … jsonb_set(…)` statement: atomic, no read-modify-write |
| SM-DECOY-15 | `api/src/stores/store-onboarding.service.ts:50` | `/db-audit` | SM-CONN-04 | the read after the write is pinned to the primary |
| SM-DECOY-16 | `api/src/checkout/shipping-quotes.service.ts:40` | `/perf-audit` | SM-RT-06 | `p-limit(8)` caps in-flight calls |
| SM-DECOY-17 | `api/src/mail/receipt-template.ts:5` | `/perf-audit` | SM-RT-03 | read once at module load, not per request |
| SM-DECOY-18 | `api/src/orders/order-detail.service.ts:55` | `/perf-audit` | SM-RT-04 | the second await needs the first one's result |
| SM-DECOY-19 | `api/src/shipping/carrier.client.ts:41` | `/perf-audit` | SM-RS-01 | timeout set on the client and a per-call `AbortSignal.timeout` |
| SM-DECOY-20 | `api/src/app.module.ts:40` | `/perf-audit` | SM-SC-01 | throttler counters live in Redis, shared by every pod |
| SM-DECOY-21 | `api/src/payouts/payout-reminder.cron.ts:34` | `/perf-audit` | SM-SC-02 | each run first claims `(job, run_date)` with a unique insert; only one pod wins |
| SM-DECOY-22 | `api/src/catalog/product-cache.service.ts:20` | `/perf-audit` | SM-CM-01 / SM-CM-05 | `max` + `ttl`, and the key carries the store id |
| SM-DECOY-23 | `api/src/storefront/home-feed.service.ts:51` | `/perf-audit` | SM-CM-04 | concurrent misses share one in-flight promise per key |
| SM-DECOY-24 | `api/src/realtime/price.gateway.ts:49` | `/perf-audit` | SM-CM-03 | the stock listener is removed in `handleDisconnect` |
| SM-DECOY-25 | `web/src/pages/HomePage.tsx:51` | `/perf-audit` | SM-FE-03 | review photos sit below the fold: lazy is correct there |
| SM-DECOY-26 | `web/src/context/SessionContext.tsx:35` | `/perf-audit` | SM-FE-02 | the provider value is memoized on its inputs |
| SM-DECOY-27 | `web/src/routes.tsx:22` | `/perf-audit` | SM-FE-01 | route split with `React.lazy` |
| SM-DECOY-28 | `web/src/pages/CatalogPage.tsx:58` | `/perf-audit` | SM-FE-04 | the facet filter renders from a deferred value, off the input's urgent path |
| SM-DECOY-29 | `api/src/catalog/product.entity.ts:7` | `/db-audit` | SM-SCH-01 | product slugs are unique per store, by constraint |
| SM-DECOY-30 | `api/src/catalog/feed-upload.controller.ts:50` | `/perf-audit` | SM-RT-01 | remote feeds decompress through a stream pipeline, off the event loop's critical path |
| SM-DECOY-31 | `api/src/auth/password.service.ts:18` | `/perf-audit` | SM-RT-02 | the promisified KDF runs on the libuv thread pool |
| SM-DECOY-32 | `reports/refunds/views.py:47` | `/db-audit` | SM-N1-02 / SM-QS-02 | `select_related` covers the serializer's hops and a cursor paginator caps the page |

```decoy
id:       SM-DECOY-01
file:     api/src/orders/order-history.service.ts
line:     39
command:  /db-audit
class:    decoy/populated-list
anchor:   populate: ['items'],
match:    n\s*\+\s*1|n\+1|per.?(order|row|element)|in(side)? (a|the) loop|quer(y|ies) per|lazy
```

```decoy
id:       SM-DECOY-02
file:     api/src/catalog/product.resolver.ts
line:     65
command:  /db-audit
class:    decoy/dataloader-resolver
anchor:   return loaders.brandById.load(product.brandId);
match:    n\s*\+\s*1|n\+1|per.?(parent|product|row)|quer(y|ies) per|dataloader|batch
```

```decoy
id:       SM-DECOY-03
file:     api/src/catalog/product-import.service.ts
line:     79
command:  /db-audit
class:    decoy/chunked-in-lookup
anchor:   sku: { $in: chunk }
match:    n\s*\+\s*1|n\+1|per.?(chunk|row|batch|sku)|in(side)? (a|the) loop|quer(y|ies) per|chunk
```

```decoy
id:       SM-DECOY-04
file:     reports/refunds/models.py
line:     45
command:  /db-audit
class:    decoy/django-fk-auto-index
anchor:   order = models.ForeignKey(
match:    \bindex|indexed|seq(uential)? scan|full (table )?scan
```

```decoy
id:       SM-DECOY-05
file:     api/src/orders/seller-orders.service.ts
line:     22
command:  /db-audit
class:    decoy/bounded-indexed-read
anchor:   limit: RECENT_LIMIT,
match:    \bindex|unbounded|no limit|paginat|seq(uential)? scan|full (table )?scan
```

```decoy
id:       SM-DECOY-06
file:     api/src/migrations/Migration20250402090000.ts
line:     13
command:  /db-audit
class:    decoy/concurrent-index-outside-tx
anchor:   create index concurrently if not exists "order_store_id_created_at_index"
match:    concurrent|transaction|\block|block
```

```decoy
id:       SM-DECOY-07
file:     api/db/migrations/2025-09-22_reviews.sql
line:     23
command:  /db-audit
class:    decoy/index-on-new-table
anchor:   create index review_created_at_idx on review (created_at);
match:    concurrent|\block|block|writes?
```

```decoy
id:       SM-DECOY-08
file:     api/src/geo/countries.service.ts
line:     17
command:  /db-audit
class:    decoy/bounded-lookup
anchor:   this.em.find(Country, {}, { orderBy: { name: QueryOrder.ASC } })
match:    unbounded|no (limit|cap|pagination)|without (a )?(limit|pagination)|paginat|all (rows|countries)|\blimit\b
```

```decoy
id:       SM-DECOY-09
file:     api/src/catalog/product.entity.ts
line:     51
command:  /db-audit
class:    decoy/float-measurement
anchor:   weightKg?: number;
match:    float|double|\breal\b|decimal|numeric|money|precision
```

```decoy
id:       SM-DECOY-10
file:     api/src/stores/store-hours.entity.ts
line:     20
command:  /db-audit
class:    decoy/wall-clock-with-zone
anchor:   opensAt!: string;
match:    time.?zone|timestamptz|\btz\b|\butc\b|naive|wall.?clock
```

```decoy
id:       SM-DECOY-11
file:     api/src/checkout/checkout.service.ts
line:     89
command:  /db-audit
class:    decoy/outbox-in-transaction
anchor:   em.persist(new OutboxEvent('order.cancelled'
match:    transaction|outbox|i/o|external|publish|after.?commit
```

```decoy
id:       SM-DECOY-12
file:     api/src/payouts/payout-ledger.service.ts
line:     17
command:  /db-audit
class:    decoy/db-table-enqueue
anchor:   em.persist(new PayoutJob(
match:    transaction|enqueue|queue|job|i/o|external|outside
```

```decoy
id:       SM-DECOY-13
file:     api/src/webhooks/webhook-retry.poller.ts
line:     54
command:  /db-audit
class:    decoy/single-consumer-claim
anchor:   limit 50 for update)
match:    skip locked|skip_locked|block|contention|concurren|workers|queue (up )?behind
```

```decoy
id:       SM-DECOY-14
file:     api/src/stores/store-settings.service.ts
line:     33
command:  /db-audit
class:    decoy/atomic-json-update
anchor:   jsonb_set(settings
match:    lost update|race|concurren|overwrit|read.?modify|clobber
```

```decoy
id:       SM-DECOY-15
file:     api/src/stores/store-onboarding.service.ts
line:     50
command:  /db-audit
class:    decoy/primary-read-after-write
anchor:   { connectionType: 'write' }
match:    replica|read.?after.?write|stale|\blag\b|primary
```

```decoy
id:       SM-DECOY-16
file:     api/src/checkout/shipping-quotes.service.ts
line:     40
command:  /perf-audit
class:    decoy/bounded-fan-out
anchor:   limit(() => this.carrier.pickupWindow(
match:    fan.?out|concurren|Promise\.all|unbounded|parallel|in.?flight
```

```decoy
id:       SM-DECOY-17
file:     api/src/mail/receipt-template.ts
line:     5
command:  /perf-audit
class:    decoy/sync-read-at-boot
anchor:   const RECEIPT_SOURCE = readFileSync(
match:    sync|event.?loop|block|readFileSync
```

```decoy
id:       SM-DECOY-18
file:     api/src/orders/order-detail.service.ts
line:     55
command:  /perf-audit
class:    decoy/dependent-awaits
anchor:   const signedUrl = await this.storage.signedUrl(invoice.pdfKey
match:    sequential|serial|independent|Promise\.all|parallel|concurren|waterfall
```

```decoy
id:       SM-DECOY-19
file:     api/src/shipping/carrier.client.ts
line:     41
command:  /perf-audit
class:    decoy/client-with-timeout
anchor:   timeout: CARRIER_TIMEOUT_MS,
match:    timeout|deadline|hang|AbortSignal
```

```decoy
id:       SM-DECOY-20
file:     api/src/app.module.ts
line:     40
command:  /perf-audit
class:    decoy/shared-rate-limit-store
anchor:   storage: new ThrottlerStorageRedisService(
match:    replica|in.?memory|memory|\blocal\b|per.?(pod|instance|process)
```

```decoy
id:       SM-DECOY-21
file:     api/src/payouts/payout-reminder.cron.ts
line:     34
command:  /perf-audit
class:    decoy/claimed-cron
anchor:   @Cron('15 2 * * *')
match:    replica|\bpods?\b|duplicate|every (replica|pod|instance)|each (replica|pod|instance)|twice|leader
```

```decoy
id:       SM-DECOY-22
file:     api/src/catalog/product-cache.service.ts
line:     20
command:  /perf-audit
class:    decoy/bounded-tenant-keyed-lru
anchor:   new LRUCache<string, ProductCard>({
match:    unbounded|tenant|store.?id|evict|\bttl\b|grow|leak|memory|collision
```

```decoy
id:       SM-DECOY-23
file:     api/src/storefront/home-feed.service.ts
line:     51
command:  /perf-audit
class:    decoy/single-flight
anchor:   const pending = this.inflight.get(key);
match:    stampede|thundering|dog.?pile|single.?flight|coalesc|concurrent miss
```

```decoy
id:       SM-DECOY-24
file:     api/src/realtime/price.gateway.ts
line:     49
command:  /perf-audit
class:    decoy/listener-removed
anchor:   this.stockFeed.off('stock', entry.onStock);
match:    listener|leak|removeListener|unsubscribe|off\(
```

```decoy
id:       SM-DECOY-25
file:     web/src/pages/HomePage.tsx
line:     51
command:  /perf-audit
class:    decoy/below-fold-lazy-images
anchor:   className="review-card__photo"
match:    \blcp\b|largest contentful|lazy|fetchpriority|priority|preload
```

```decoy
id:       SM-DECOY-26
file:     web/src/context/SessionContext.tsx
line:     35
command:  /perf-audit
class:    decoy/memoized-provider-value
anchor:   const value = useMemo(
match:    re.?render|render|memo|context value|new object
```

```decoy
id:       SM-DECOY-27
file:     web/src/routes.tsx
line:     22
command:  /perf-audit
class:    decoy/lazy-route
anchor:   const OrdersPage = lazy(
match:    lazy|code.?split|bundle|chunk|eager|initial
```

```decoy
id:       SM-DECOY-28
file:     web/src/pages/CatalogPage.tsx
line:     58
command:  /perf-audit
class:    decoy/deferred-facet-filter
anchor:   const deferredFacet = useDeferredValue(facets);
match:    \binp\b|long task|main thread|block|keystroke|defer|jank|responsive
```

```decoy
id:       SM-DECOY-29
file:     api/src/catalog/product.entity.ts
line:     7
command:  /db-audit
class:    decoy/tenant-scoped-unique
anchor:   @Unique({ properties: ['store', 'slug'] })
match:    unique|duplicate|constraint
```

```decoy
id:       SM-DECOY-30
file:     api/src/catalog/feed-upload.controller.ts
line:     50
command:  /perf-audit
class:    decoy/streaming-gunzip
anchor:   createGunzip(),
match:    sync|event.?loop|block|main thread
```

```decoy
id:       SM-DECOY-31
file:     api/src/auth/password.service.ts
line:     18
command:  /perf-audit
class:    decoy/async-kdf
anchor:   await pbkdf2Async(
match:    sync|event.?loop|block|main thread|cpu
```

```decoy
id:       SM-DECOY-32
file:     reports/refunds/views.py
line:     47
command:  /db-audit
class:    decoy/optimized-paginated-list
anchor:   .select_related("order__store")
match:    n\s*\+\s*1|n\+1|paginat|unbounded|select_related|per.?(row|refund)
```
