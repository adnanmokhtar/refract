# Seeded defects — `node-api`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: a multi-tenant Express order service (Node 18, CommonJS, Postgres via `pg`).
20 defects seeded across security, database + runtime performance, resilience, architecture,
and capacity. Primary target command: **`/audit`**.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`. If you edit fixture source, re-run that and fix any drift.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| NAPI-SEC-01 | `src/db/queries.js:39` | critical | `/audit` | security/sql-injection |
| NAPI-SEC-02 | `src/middleware/auth.js:15` | critical | `/audit` | security/broken-auth |
| NAPI-SEC-03 | `src/config.js:23` | high | `/audit` | security/hardcoded-credential |
| NAPI-SEC-04 | `src/routes/orders.js:37` | critical | `/audit` | security/broken-access-control |
| NAPI-SEC-05 | `src/routes/orders.js:56` | high | `/audit` | security/mass-assignment |
| NAPI-SEC-06 | `src/routes/admin.js:28` | critical | `/audit` | security/tenant-isolation |
| NAPI-SEC-07 | `src/middleware/request-log.js:17` | high | `/audit` | security/sensitive-data-exposure |
| NAPI-SEC-08 | `src/routes/webhooks.js:10` | critical | `/audit` | security/missing-authn |
| NAPI-PERF-01 | `src/services/order-service.js:15` | high | `/audit` | perf/n-plus-one |
| NAPI-PERF-02 | `src/db/queries.js:29` | high | `/audit` | perf/unbounded-query |
| NAPI-PERF-03 | `src/services/order-service.js:29` | medium | `/audit` | perf/sequential-awaits |
| NAPI-PERF-04 | `src/db/schema.sql:31` | medium | `/audit` | perf/missing-index |
| NAPI-RES-01 | `src/services/payments.js:8` | high | `/audit` | resilience/unhandled-io |
| NAPI-RES-02 | `src/routes/webhooks.js:20` | medium | `/audit` | resilience/silent-catch |
| NAPI-RES-03 | `src/middleware/rate-limit.js:6` | high | `/audit` | scale/statelessness-violation |
| NAPI-RES-04 | `src/routes/orders.js:66` | high | `/audit` | scale/idempotency-gap |
| NAPI-ARCH-01 | `src/routes/orders.js:82` | medium | `/audit` | architecture/layer-violation |
| NAPI-ARCH-02 | `src/db/schema.sql:35` | medium | `/audit` | data/missing-foreign-key |
| NAPI-CAP-01 | `src/config.js:18` | medium | `/audit` | capacity/pool-sizing |
| NAPI-CAP-02 | `src/config.js:19` | medium | `/audit` | capacity/no-query-timeout |

Severity split: 5 critical · 7 high · 8 medium · 0 low.

---

## NAPI-SEC-01 — SQL injection in the order search query

```defect
id:       NAPI-SEC-01
file:     src/db/queries.js
line:     39
severity: critical
command:  /audit
class:    security/sql-injection
anchor:   "SELECT * FROM orders WHERE tenant_id = '" + tenantId
match:    sql.{0,3}inject|injection|string (interpolat|concatenat)|concatenat.{0,20}(sql|quer)|unparameteri|not parameteri|parameteri[sz]ed quer|prepared statement|untrusted input.{0,30}quer
```

`searchOrders()` builds its SQL by string concatenation from `term`, `status` and
`tenantId`, all of which arrive unfiltered from the support console's query string
(`src/routes/orders.js:27`). Every other query in the file uses `$1` placeholders, so the
project's own idiom makes this the outlier. A `status` of `x' OR '1'='1` reads the whole
table across every tenant.

## NAPI-SEC-02 — Bearer token decoded, never verified

```defect
id:       NAPI-SEC-02
file:     src/middleware/auth.js
line:     15
severity: critical
command:  /audit
class:    security/broken-auth
anchor:   const claims = jwt.decode(token);
match:    jwt\.decode|decode.{0,25}(instead of|not|without).{0,15}verif|signature.{0,20}(not|never|un)?.{0,10}verif|unverified|forge|no signature check
```

`requireAuth` calls `jwt.decode`, which parses the token without checking the HMAC
signature or `exp`. `signAccessToken` in the same file signs with a real secret, so the
verification key is available — it is simply not used. Any client can mint a token with
`role: "admin"` and an arbitrary `tid`, which also defeats `requireRole` and every
tenant check downstream.

## NAPI-SEC-03 — Hardcoded fallback signing secret

```defect
id:       NAPI-SEC-03
file:     src/config.js
line:     23
severity: high
command:  /audit
class:    security/hardcoded-credential
anchor:   jwtSecret: process.env.JWT_SECRET
match:    hard.?cod|fallback secret|default secret|dev-secret|committed secret|secret.{0,25}(in|to) (source|code|repo)|weak secret
```

`jwtSecret` falls back to a literal when `JWT_SECRET` is unset. The fallback is in version
control, so any environment that forgets the variable silently signs and accepts tokens
with a publicly known key instead of failing to boot.

## NAPI-SEC-04 — Order detail has no ownership or tenant check

```defect
id:       NAPI-SEC-04
file:     src/routes/orders.js
line:     37
severity: critical
command:  /audit
class:    security/broken-access-control
anchor:   const detail = await orderService.getOrderDetail(req.params.id);
match:    idor|insecure direct object|broken access control|ownership check|authoriz|tenant.{0,15}(check|scope|isolat)|any.{0,15}user.{0,25}(any|other).{0,15}order
```

`GET /orders/:id` resolves the id straight to a record and returns it. `requireAuth`
establishes *who* the caller is but nothing checks that the order belongs to
`req.user.tenantId` or to that customer. The sibling handler `POST /orders/:id/pay`
(line 69) does perform the tenant comparison, which is what makes this an omission
rather than a design choice.

## NAPI-SEC-05 — Mass assignment on the order patch endpoint

```defect
id:       NAPI-SEC-05
file:     src/routes/orders.js
line:     56
severity: high
command:  /audit
class:    security/mass-assignment
anchor:   Object.assign(patch, req.body);
match:    mass assign|over.?post|allow.?list|allowlist|whitelist|unvalidated.{0,20}(body|input|field)|arbitrary (column|field|attribute)|Object\.assign.{0,15}req\.body
```

The whole request body is copied into the update patch and handed to
`updateOrderFields`, which interpolates the caller's key names directly into the `SET`
clause (`src/db/queries.js:58`). A support agent — or anyone past NAPI-SEC-02 — can write
`total_cents`, `tenant_id` or `status` regardless of what the UI exposes. There is no
field allowlist anywhere on the path.

## NAPI-SEC-06 — Admin customer-orders route is not tenant-scoped

```defect
id:       NAPI-SEC-06
file:     src/routes/admin.js
line:     28
severity: critical
command:  /audit
class:    security/tenant-isolation
anchor:   const orders = await queries.findOrdersByCustomer(req.params.id);
match:    tenant|cross.?tenant|multi.?tenan|isolation|other (customer|org|account)s? data|scope.{0,20}tenant
```

`findOrdersByCustomer` filters on `customer_id` only. An admin of tenant A who supplies a
customer id belonging to tenant B receives tenant B's orders. The `requireRole('admin')`
gate is per-tenant authorisation, not cross-tenant, and `codebase-profile.md` states every
table carries `tenant_id` — the filter is simply absent here.

## NAPI-SEC-07 — Full request body written to the request log

```defect
id:       NAPI-SEC-07
file:     src/middleware/request-log.js
line:     17
severity: high
command:  /audit
class:    security/sensitive-data-exposure
match:    log.{0,25}(pii|secret|card|password|token|sensitive|body)|sensitive.{0,20}log|redact|scrub|body.{0,15}log|leak.{0,15}log
anchor:   body: req.body,
```

Every request logs `req.body` verbatim. `POST /orders/:id/pay` carries `body.card`, so
card data lands in stdout and from there in the log pipeline. Nothing redacts or
allowlists fields.

## NAPI-SEC-08 — Payment webhook accepts unauthenticated callers

```defect
id:       NAPI-SEC-08
file:     src/routes/webhooks.js
line:     10
severity: critical
command:  /audit
class:    security/missing-authn
anchor:   router.post('/payments', async (req, res) => {
match:    webhook.{0,30}(unauth|no auth|signature|verif|hmac)|(signature|hmac).{0,25}webhook|unauthenticated|missing auth|forged (event|webhook|callback)|no.{0,15}(signature|shared secret)
```

The webhook router is mounted without `requireAuth` (`src/server.js:21`) and the handler
verifies no provider signature or shared secret. Anyone who can reach the service can post
`charge.settled` for any order id and flip it to a paid state.

## NAPI-PERF-01 — N+1 query hydrating order line items

```defect
id:       NAPI-PERF-01
file:     src/services/order-service.js
line:     15
severity: high
command:  /audit
class:    perf/n-plus-one
anchor:   const items = await queries.findItemsForOrder(order.id);
match:    n\+1|n \+ 1|nplus|query (in|inside) a loop|per.?(row|order|record) quer|loop.{0,25}quer|batch.{0,15}(fetch|load|quer)|single quer.{0,20}instead
```

`listOrdersWithItems` fetches every order, then issues one `findItemsForOrder` call per
order inside a sequential `for` loop. With the unbounded list from NAPI-PERF-02 this is
one query per order in the tenant on every load of the support console's default view.

## NAPI-PERF-02 — Unbounded `SELECT *` with no pagination

```defect
id:       NAPI-PERF-02
file:     src/db/queries.js
line:     29
severity: high
command:  /audit
class:    perf/unbounded-query
anchor:   'SELECT * FROM orders WHERE tenant_id = $1 ORDER BY created_at DESC',
match:    unbounded|no (limit|pagination)|missing (limit|pagination)|paginat|select \*|full table|entire table|all rows
```

`listAllOrders` returns every order row for the tenant with no `LIMIT`, no cursor, and
`SELECT *` rather than the columns the caller uses. It backs both the support console and
the nightly reconciliation job, so result size grows without bound with tenant age.

## NAPI-PERF-03 — Three independent lookups awaited sequentially

```defect
id:       NAPI-PERF-03
file:     src/services/order-service.js
line:     29
severity: medium
command:  /audit
class:    perf/sequential-awaits
anchor:   const customer = await queries.findCustomerById(order.customer_id);
match:    sequential await|await.{0,15}(in )?serial|serial(ly|is|iz)|parallel|Promise\.all|concurrent|waterfall
```

In `getOrderDetail` the items, customer and pricing lookups do not consume each other's
results, but each `await` blocks the next. Latency is the sum of three round trips where
it could be the maximum. `Promise.all` is the project-idiomatic fix.

## NAPI-PERF-04 — No index for the columns the hot queries filter on

```defect
id:       NAPI-PERF-04
file:     src/db/schema.sql
line:     31
severity: medium
command:  /audit
class:    perf/missing-index
anchor:   CREATE INDEX orders_tenant_idx ON orders (tenant_id);
match:    missing index|no index|index on|add.{0,15}index|composite index|sequential scan|seq scan|full scan
```

`orders` is indexed on `tenant_id` alone. The live queries filter on
`customer_id` (`findOrdersByCustomer`), on `customer_email` (`searchOrders`), and sort by
`created_at` — none of which the single-column index serves. `order_items.order_id`, hit
once per order by NAPI-PERF-01, has no index at all.

## NAPI-RES-01 — Card charge has no timeout and no error path

```defect
id:       NAPI-RES-01
file:     src/services/payments.js
line:     8
severity: high
command:  /audit
class:    resilience/unhandled-io
anchor:   const res = await fetch(`${config.payments.baseUrl}/v1/charges`, {
match:    (no|missing|without).{0,20}timeout|timeout.{0,20}(absent|missing|not set)|happy.?path|unhandled|no (error|failure) (path|handling|check)|res\.ok|status code.{0,20}(not|never) check|circuit breaker|retry
```

`chargeCard` awaits `fetch` with no `AbortSignal`, never inspects `res.ok`, and parses the
body regardless of status — a provider 500 becomes a "receipt" and `payOrder` marks the
order paid. `refundCharge`, directly below, sets a 5 s timeout and checks `res.ok`, so the
project's own convention is present and this call site departs from it.

## NAPI-RES-02 — Webhook swallows every write failure

```defect
id:       NAPI-RES-02
file:     src/routes/webhooks.js
line:     20
severity: medium
command:  /audit
class:    resilience/silent-catch
anchor:   // Provider retries anyway.
match:    silent(ly)? (catch|swallow|ignor)|swallow|empty catch|catch.{0,20}(block )?(is )?empty|ignor.{0,15}error|error.{0,20}(discard|drop|not (logged|surfaced|propagat))
```

The `catch` block is empty and the handler returns `200` regardless, so a failed status
update is indistinguishable from a successful one. The comment asserts the provider will
retry, but the 200 is exactly what tells it not to. Failures are unobservable and
unrecoverable.

## NAPI-RES-03 — Rate limiter holds counters in process memory

```defect
id:       NAPI-RES-03
file:     src/middleware/rate-limit.js
line:     6
severity: high
command:  /audit
class:    scale/statelessness-violation
anchor:   const counters = new Map();
match:    in.?memory|in.?process|per.?(replica|instance|process|pod)|stateless|does ?n.t scale|horizontal|shared (store|state)|redis|distributed
```

The counter `Map` is per-process. `codebase-profile.md` records 6 replicas behind a load
balancer, so the effective limit is 6× the configured one and varies with routing;
a rolling deploy resets every window. Enforcing a global limit needs shared state.

## NAPI-RES-04 — Payment endpoint is not idempotent

```defect
id:       NAPI-RES-04
file:     src/routes/orders.js
line:     66
severity: high
command:  /audit
class:    scale/idempotency-gap
anchor:   router.post('/:id/pay', async (req, res, next) => {
match:    idempoten|duplicate (charge|payment|write|request)|double.?(charge|submit|click)|retry.{0,25}(duplicate|twice|again)|exactly.?once|at.?least.?once|dedup
```

`POST /orders/:id/pay` accepts no idempotency key and does not check whether the order is
already `paid` before charging. A client retry, a double-click, or an LB-level retry
charges the card a second time. The order status is only written after the charge
succeeds, so there is no guard on the second attempt either.

## NAPI-ARCH-01 — Route layer queries the database directly

```defect
id:       NAPI-ARCH-01
file:     src/routes/orders.js
line:     82
severity: medium
command:  /audit
class:    architecture/layer-violation
anchor:   const { rows } = await pool.query(
match:    layer violation|layering|bypass.{0,25}(service|business|data).{0,15}layer|route.{0,25}(direct|raw).{0,15}(quer|db|database|pool)|separation of concerns|architectur.{0,20}(violat|boundar)
```

`GET /orders/:id/timeline` imports the connection pool (line 6) and runs raw SQL in the
handler. Both `README.md` and `.claude/codebase-profile.md` state that routes delegate to
services and only `src/db/` issues queries; every other handler in the file obeys that.

## NAPI-ARCH-02 — Referential integrity declared inconsistently

```defect
id:       NAPI-ARCH-02
file:     src/db/schema.sql
line:     35
severity: medium
command:  /audit
class:    data/missing-foreign-key
anchor:   order_id      uuid NOT NULL,
match:    foreign key|\bfk\b|referential integrity|orphan|cascade|references .{0,20}\(id\)|constraint
```

`customers.tenant_id` carries a `REFERENCES` clause, but `orders.tenant_id`,
`orders.customer_id` and `order_items.order_id` do not. Deleting an order leaves its items
orphaned and nothing prevents rows pointing at a tenant that no longer exists.

## NAPI-CAP-01 — Pool size fixed per process, ignoring replica count

```defect
id:       NAPI-CAP-01
file:     src/config.js
line:     18
severity: medium
command:  /audit
class:    capacity/pool-sizing
anchor:   poolSize: 20,
match:    (connection )?pool.{0,25}(siz|max|limit|exhaust|satur)|max_connections|too many connections|replica.{0,25}pool|pool.{0,25}replica
```

`poolSize: 20` is applied identically on every process. At the 6 replicas recorded in
`codebase-profile.md` that is 120 server connections before any migration job or console
session, against a Postgres default `max_connections` of 100. The value is not derived
from replica count or from the server's ceiling.

## NAPI-CAP-02 — No statement timeout on any query

```defect
id:       NAPI-CAP-02
file:     src/config.js
line:     19
severity: medium
command:  /audit
class:    capacity/no-query-timeout
anchor:   statementTimeoutMs: 0,
match:    statement.?timeout|query timeout|statementTimeout|no timeout.{0,25}(quer|statement|db|database)|runaway quer|long.?running quer|cancel.{0,15}quer
```

`statementTimeoutMs: 0` disables the cap and the value is never passed to the pool anyway
(the `Pool` constructor at `src/db/index.js:6` never sets one). One slow scan — for example the unbounded search in NAPI-SEC-01 —
holds a pooled connection indefinitely, and with NAPI-CAP-01 a handful of them exhausts
the pool for every tenant on that replica.
