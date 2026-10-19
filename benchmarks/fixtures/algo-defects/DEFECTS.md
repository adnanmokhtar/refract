# Seeded defects — `algo-defects`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the agent scans. If you stage
the fixture by hand, delete this file from the copy first — an agent that reads it will score 100% and the number will
mean nothing.

Fixture shape: `Kestrelway` — a grocery-and-courier marketplace serving New Zealand, Fiji and Samoa: a NestJS 11 / Fastify / MikroORM 6 API over Postgres 17 + PostGIS with raw-SQL repositories and SQL migrations, a React 19 merchant-console utility folder, a Python analytics worker (numpy, pandas, numba, redis, pyprobables, one C extension), a Go courier-routing package and a Java 21 ranking module; 54 algorithms seeds over 27 classes, 8 routed, 12 decoys.

The API reads with MikroORM `find` and raw SQL through `em.getConnection().execute` (knex `?` placeholders); Fastify
`bodyLimit: 1_048_576` is set in `api/src/main.ts`. `stores.location` is `geometry(Point, 4326)`
(`api/migrations/0002_stores_geo.sql`); `categories.parent_id` references `categories(id)` with no cycle check; `order_lines`
has no unique key on `order_id`; `customers` is unique on `(tenant_id, phone_key)`. The README states the markets whose
service areas cross the antimeridian (GE-3). The project has its own seeded, shrinking fuzzer under `api/test/fuzz/` and
no `fast-check` or Hypothesis.

Invocation: /analyze-complexity
Invocation[/quality-audit]: /quality-audit --whole-repo
Invocation[/security-audit]: /security-audit
Invocation[/perf-audit]: /perf-audit
Invocation[/db-audit]: /db-audit
Stage with: --git — /analyze-complexity proves the tree untouched with git diff --exit-code, and a whole-repo run on a copy with no base branch has no diff to scope to.

Eval source: Track A batch 8, `eval-batch8-algorithms.md` § 2 (the 27-class map), § 3.2 (the correct shapes, used as
decoys), § 5.11 (fixture design). Classes are the research catalog's ids, shipped as `ALG-<id>`; precedents are
`templates/snippets/precedents/algorithms.md` § n; proofs are `proof-oracles.md` § Algorithms (V590–V609). Roots (name
them all in `ROOTS`):
- `api/src` — NestJS 11 on Fastify: orders export, catalog (price index, category paths, the seen-products filter), delivery
  (zone graph, radius, service area, plan counter), pricing, reports, Q&A threads, the order sync job, the pick board,
  promotions, QA sampling, stores (PostGIS), insights statistics, billing; `api/migrations/*.sql` holds the schema (read by
  complexity 8 and contract 0b, which search `.`);
- `web/src` — React 19 merchant console: the variant matrix and the chart-of-accounts table;
- `analytics` — the Python worker: basket affinity, the day planner, promo bundles, reports, sampling, experiments, GeoJSON
  export, metrics (GMV, ETA variance, JIT kernels, heavy hitters), forecasts, billing, payouts; `setup.py` builds the C
  extension;
- `geo` — Go 1.23: dispatch, assignment, the zone tree, the leaderboard, the live-map query;
- `ranking/src/main` — Java 21: the partner feed, the score backfill, the shelf, the heap, sponsored rotation, experiments.

Departures from the eval, stated so a reader can audit them:
- **AL-RC2-b's recursive CTE is a repository's raw SQL under `api/src`, not a migration view; AL-RC4-a exits on
  `const last = rows.at(-1); if (!last) break;`; AL-RC3-b recurses on `i - 1` / `i - 2`.** The fixture build found three
  detector gaps (complexity 7a searched `ROOTS` only; `algo-sites.py` hinted a `$gte` cursor with an empty-page exit
  `keyset`; its RC-3 test read only decreasing arguments). All three were fixed the same day — grep 7c reads recursive CTEs
  in migrations, a `>=` cursor is never `keyset`, and `i + 1` / `i + 2` counts as moving — and a one-file probe of each
  original shape now prints (7c rc 0, `read`, `RC-3?`). The seeds keep the shapes they were built with; each is the same
  defect.
- **AL-GE1-b uses knex `?` placeholders** (`ST_MakePoint(?, ?)`, radius `?` = 5,000) rather than `$n`; the shape is the same.
- **AL-CX5-a prints as a CX-1 row** (`members.filter` inside `teams.map`): the script files a `filter` in a `map` as CX-1 on
  the inner receiver, as complexity-scan § 5 says.
- **Decoy 01 filters database rows against the carrier's reference list**, both read with `limit: OPEN_MAX`; decoy 07's
  comment is trailing, so 6b prints the line; decoys 09, 10 and 11 are printed by no algorithms line (stated in the table).

Ownership and scoring. Five runs, five results rows, each staged in its own copy. **`/analyze-complexity`** scores the 54
algorithms rows. The 8 routed rows score **only under their owner** — `/quality-audit` (float `===`, a numeric sort with no
comparator, `+ 24 h` across DST, float money), `/security-audit` (a ReDoS on a public route, an OTP from `Math.random()`),
`/perf-audit` (a `Pattern.compile` per call, outside any loop) and `/db-audit` (deep `OFFSET` on a non-unique key) — and
`/analyze-complexity` must list each as `→ <owner pack> <skill> §n` (or `(owner pack <x> not installed)`), never grade it;
an `/analyze-complexity` finding on them is UNMATCHED, not credited. `bucket:` is the row's expected disposition:
`report-with-fix` (the counting, differential, chi-square, reference or static two-ended oracle can fail first and the fix
is local), `report-flagged` (one link is unproven or a person decides: a browser-only path with no component harness, a
deploy-side hash seed, a sketch tolerance nobody stated), `routed` (owner line only).

Secrets. None. The PSP, carrier and warehouse URLs are read from the environment with `*.example` / `*.internal`
fallbacks; no key, token or DSN value is present.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which also
fails if a decoy sits within 12 lines of a defect in the same file. Every line was computed from its anchor.

## Summary

| id | file:line | severity | command | class | bucket |
|----|-----------|----------|---------|-------|--------|
| AL-CX1-a | `api/src/orders/order-export.service.ts:25` | high | `/analyze-complexity` | ALG-CX-1 | report-with-fix |
| AL-CX1-b | `analytics/basket/affinity.py:23` | medium | `/analyze-complexity` | ALG-CX-1 | report-with-fix |
| AL-CX2-a | `api/src/catalog/price-index.service.ts:16` | medium | `/analyze-complexity` | ALG-CX-2 | report-with-fix |
| AL-CX2-b | `ranking/src/main/java/com/kestrelway/ranking/feed/FeedExporter.java:20` | medium | `/analyze-complexity` | ALG-CX-2 | report-with-fix |
| AL-CX3-a | `api/src/delivery/zone-graph.service.ts:31` | medium | `/analyze-complexity` | ALG-CX-3 | report-with-fix |
| AL-CX3-b | `analytics/routing/worklist.py:27` | medium | `/analyze-complexity` | ALG-CX-3 | report-with-fix |
| AL-CX4-a | `api/src/pricing/rate-card.service.ts:31` | medium | `/analyze-complexity` | ALG-CX-4 | report-with-fix |
| AL-CX4-b | `geo/address_normalize.go:13` | low | `/analyze-complexity` | ALG-CX-4 | report-with-fix |
| AL-CX5-a | `api/src/reports/team-report.service.ts:28` | medium | `/analyze-complexity` | ALG-CX-5 | report-with-fix |
| AL-CX5-b | `geo/assign.go:11` | medium | `/analyze-complexity` | ALG-CX-5 | report-with-fix |
| AL-CX6-a | `web/src/products/variant-matrix.ts:12` | low | `/analyze-complexity` | ALG-CX-6 | report-flagged |
| AL-CX6-b | `analytics/promo/bundles.py:19` | medium | `/analyze-complexity` | ALG-CX-6 | report-with-fix |
| AL-RC1-a | `api/src/comments/comment-thread.renderer.ts:22` | medium | `/analyze-complexity` | ALG-RC-1 | report-with-fix |
| AL-RC1-b | `geo/zone_tree.go:13` | high | `/analyze-complexity` | ALG-RC-1 | report-with-fix |
| AL-RC2-a | `api/src/catalog/category-path.ts:7` | high | `/analyze-complexity` | ALG-RC-2 | report-with-fix |
| AL-RC2-b | `api/src/catalog/category-paths.repository.ts:11` | high | `/analyze-complexity` | ALG-RC-2 | report-with-fix |
| AL-RC3-a | `api/src/delivery/route-count.ts:7` | medium | `/analyze-complexity` | ALG-RC-3 | report-with-fix |
| AL-RC3-b | `analytics/promo/split_cost.py:12` | medium | `/analyze-complexity` | ALG-RC-3 | report-with-fix |
| AL-RC4-a | `api/src/sync/order-sync.job.ts:24` | high | `/analyze-complexity` | ALG-RC-4 | report-with-fix |
| AL-RC4-b | `ranking/src/main/java/com/kestrelway/ranking/backfill/ScoreBackfill.java:22` | high | `/analyze-complexity` | ALG-RC-4 | report-with-fix |
| AL-OC1-a | `api/src/pricing/weight-band.ts:19` | medium | `/analyze-complexity` | ALG-OC-1 | report-with-fix |
| AL-OC1-b | `analytics/reports/daily_sales.py:26` | medium | `/analyze-complexity` | ALG-OC-1 | report-with-fix |
| AL-OC2-a | `geo/dispatch_rank.go:18` | medium | `/analyze-complexity` | ALG-OC-2 | report-with-fix |
| AL-OC2-b | `geo/leaderboard.go:18` | medium | `/analyze-complexity` | ALG-OC-2 | report-with-fix |
| AL-OC3-a | `api/src/fulfilment/pick-board.service.ts:42` | high | `/analyze-complexity` | ALG-OC-3 | report-with-fix |
| AL-OC3-b | `ranking/src/main/java/com/kestrelway/ranking/shelf/ShelfRanker.java:15` | high | `/analyze-complexity` | ALG-OC-3 | report-with-fix |
| AL-OC4-a | `api/src/pricing/tier-lookup.ts:15` | medium | `/analyze-complexity` | ALG-OC-4 | report-with-fix |
| AL-OC4-b | `ranking/src/main/java/com/kestrelway/ranking/heap/MinHeap.java:14` | medium | `/analyze-complexity` | ALG-OC-4 | report-with-fix |
| AL-RD1-a | `api/src/promotions/raffle.service.ts:18` | high | `/analyze-complexity` | ALG-RD-1 | report-with-fix |
| AL-RD1-b | `analytics/sampling/shuffle_entrants.py:7` | high | `/analyze-complexity` | ALG-RD-1 | report-with-fix |
| AL-RD2-a | `api/src/quality/audit-sampler.ts:15` | medium | `/analyze-complexity` | ALG-RD-2 | report-with-fix |
| AL-RD2-b | `ranking/src/main/java/com/kestrelway/ranking/sponsored/WeightedPicker.java:18` | medium | `/analyze-complexity` | ALG-RD-2 | report-with-fix |
| AL-RD3-a | `ranking/src/main/java/com/kestrelway/ranking/experiments/ExperimentBucket.java:13` | medium | `/analyze-complexity` | ALG-RD-3 | report-with-fix |
| AL-RD3-b | `analytics/experiments/assign.py:7` | medium | `/analyze-complexity` | ALG-RD-3 | report-flagged |
| AL-GE1-a | `api/src/delivery/delivery-radius.ts:10` | high | `/analyze-complexity` | ALG-GE-1 | report-with-fix |
| AL-GE1-b | `api/src/stores/nearby-stores.repository.ts:20` | high | `/analyze-complexity` | ALG-GE-1 | report-with-fix |
| AL-GE2-a | `api/src/stores/store-location.repository.ts:18` | high | `/analyze-complexity` | ALG-GE-2 | report-with-fix |
| AL-GE2-b | `analytics/exports/geojson_export.py:30` | high | `/analyze-complexity` | ALG-GE-2 | report-with-fix |
| AL-GE3-a | `api/src/delivery/service-area.ts:16` | medium | `/analyze-complexity` | ALG-GE-3 | report-with-fix |
| AL-GE3-b | `geo/bbox_query.go:17` | medium | `/analyze-complexity` | ALG-GE-3 | report-with-fix |
| AL-NS1-a | `analytics/metrics/gmv_rollup.py:27` | medium | `/analyze-complexity` | ALG-NS-1 | report-with-fix |
| AL-NS1-b | `api/src/analytics/stats.ts:10` | medium | `/analyze-complexity` | ALG-NS-1 | report-with-fix |
| AL-NS2-a | `analytics/metrics/delivery_variance.py:20` | medium | `/analyze-complexity` | ALG-NS-2 | report-with-fix |
| AL-NS2-b | `api/src/analytics/stats.ts:30` | low | `/analyze-complexity` | ALG-NS-2 | report-with-fix |
| AL-NS3-a | `analytics/ranking/softmax.py:7` | medium | `/analyze-complexity` | ALG-NS-3 | report-with-fix |
| AL-NS3-b | `api/src/analytics/stats.ts:40` | medium | `/analyze-complexity` | ALG-NS-3 | report-with-fix |
| AL-NS4-a | `analytics/forecast/demand_fit.py:12` | medium | `/analyze-complexity` | ALG-NS-4 | report-with-fix |
| AL-NS4-b | `analytics/forecast/eta_solver.py:12` | medium | `/analyze-complexity` | ALG-NS-4 | report-with-fix |
| AL-NS5-a | `analytics/setup.py:7` | medium | `/analyze-complexity` | ALG-NS-5 | report-with-fix |
| AL-NS5-b | `analytics/metrics/fast_kernels.py:6` | medium | `/analyze-complexity` | ALG-NS-5 | report-with-fix |
| AL-SL1-a | `api/src/catalog/seen-products.ts:19` | low | `/analyze-complexity` | ALG-SL-1 | report-flagged |
| AL-SL1-b | `analytics/metrics/heavy_hitters.py:8` | low | `/analyze-complexity` | ALG-SL-1 | report-flagged |
| AL-SL2-a | `api/src/billing/charge-dedupe.service.ts:20` | high | `/analyze-complexity` | ALG-SL-2 | report-with-fix |
| AL-SL2-b | `analytics/billing/unique_seats.py:13` | high | `/analyze-complexity` | ALG-SL-2 | report-with-fix |
| AL-HO-CQ-a | `api/src/pricing/fee-compare.ts:9` | medium | `/quality-audit` | CQ §2 float equality | routed |
| AL-HO-CQ-b | `api/src/orders/id-sort.ts:12` | medium | `/quality-audit` | CQ §4 sort without comparator | routed |
| AL-HO-CQ-c | `api/src/schedules/next-slot.ts:8` | medium | `/quality-audit` | CQ §6 calendar arithmetic | routed |
| AL-HO-CQ-d | `analytics/payouts/commission.py:16` | medium | `/quality-audit` | CQ §4 float money | routed |
| AL-HO-SEC-a | `api/src/search/sku-filter.ts:10` | high | `/security-audit` | SEC injection-scan §13 ReDoS | routed |
| AL-HO-SEC-b | `api/src/auth/otp.service.ts:11` | high | `/security-audit` | SEC sast-scan CWE-338 | routed |
| AL-HO-PF-a | `ranking/src/main/java/com/kestrelway/ranking/validation/SkuValidator.java:11` | low | `/perf-audit` | PERF request-path-scan §8 per-call construction | routed |
| AL-HO-DB-a | `api/src/orders/order-history.repository.ts:22` | medium | `/db-audit` | DB query-shape-scan deep OFFSET | routed |

54 algorithms seeds (two per class over the 27 classes, spread over TypeScript, Python, Go, Java and SQL), 8 routed, 12 decoys.

## AL-CX1-a — The order export scans the request's id list once per order

```defect
id:       AL-CX1-a
file:     api/src/orders/order-export.service.ts
line:     25
severity: high
command:  /analyze-complexity
class:    ALG-CX-1
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §1
anchor:   return orders.filter((o) => ids.includes(o.id));
match:    orderIds|ids\.includes|filter|selectOrders|export
match:    linear|O\(n\s*[·*x×]\s*m\)|O\(n\^?2\)|quadratic|includes|Set|scan|per (order|element)|uncapped|no (cap|limit|max)
```

`orders` is every order of the store (no `limit`), `ids` is `dto.orderIds` from the POST body (`@IsArray()` with no `@ArrayMaxSize`), and `ids.includes` scans the list once per order: n·m on a merchant request with both sides tenant-sized. Proof V590 (lookup count 16× from N to 4N). Fix: `const wanted = new Set(ids)` once, then `wanted.has(o.id)` (and query by id when ids are given).

## AL-CX1-b — Distinct SKUs are collected by membership tests against a list

```defect
id:       AL-CX1-b
file:     analytics/basket/affinity.py
line:     23
severity: medium
command:  /analyze-complexity
class:    ALG-CX-1
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §1
anchor:   if row.sku in seen_skus:
match:    seen_skus|distinct_skus|affinity|in seen
match:    linear|list|O\(n\^?2\)|quadratic|set\(\)|\bset\b|membership|scan
```

`seen_skus = []` grows by `.append`, and `row.sku in seen_skus` scans it for each of the 90-day order lines the nightly job reads (no limit): O(lines × distinct SKUs). Proof V590. Fix: `seen = set()` (or `dict.fromkeys` to keep first-seen order).

## AL-CX2-a — The SKU price index copies the accumulator on every product

```defect
id:       AL-CX2-a
file:     api/src/catalog/price-index.service.ts
line:     16
severity: medium
command:  /analyze-complexity
class:    ALG-CX-2
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §2
anchor:   return products.reduce((acc, p) => ({ ...acc, [p.sku]: p.priceMinor }), {} as Record<string, number>);
match:    priceBySku|reduce|\.\.\.acc|spread|price.?index
match:    cop(y|ies)|spread|O\(n\^?2\)|quadratic|accumulat|per iteration|Map|mutat
```

`{ ...acc, [p.sku]: … }` copies every key so far for each product of the catalog: O(n²) key copies for a tenant's whole catalog, rebuilt on every price change. Proof V591 (copy count). Fix: one object or `Map`, assigned in a loop.

## AL-CX2-b — The partner feed line is built with `+` inside the loop

```defect
id:       AL-CX2-b
file:     ranking/src/main/java/com/kestrelway/ranking/feed/FeedExporter.java
line:     20
severity: medium
command:  /analyze-complexity
class:    ALG-CX-2
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §2
anchor:   csv = csv + "," + item.getSku();
match:    csv|skuLine|FeedExporter|getSku
match:    StringBuilder|String(Joiner)?\b.*(concat|join)|concaten|O\(n\^?2\)|quadratic|cop(y|ies)|per iteration|allocat
```

Each `csv + "," + sku` copies the whole line so far; a store lists 40,000+ SKUs, so the nightly feed copies O(n²) characters per store (JEP 280 does not help inside a loop, precedent § 6). Proof V591. Fix: `StringBuilder` or `String.join(",", …)`.

## AL-CX3-a — The zone BFS dequeues with `Array.shift()`

```defect
id:       AL-CX3-a
file:     api/src/delivery/zone-graph.service.ts
line:     31
severity: medium
command:  /analyze-complexity
class:    ALG-CX-3
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §3
anchor:   const zone = queue.shift()!;
match:    queue|shift|reachableZones|BFS|zone
match:    shift|O\(n\)|front|dequeue|head index|deque|re-?index|quadratic|O\(n\^?2\)
```

Every `shift()` re-indexes the remaining frontier; merchants draw thousands of zones, so the walk is O(V²) element moves. Proof V592 (per-operation cost across 1e3 → 1e5). Fix: a head index over the array (`for (let h = 0; h < queue.length; h++)`).

## AL-CX3-b — The day planner pops jobs from the front of a list

```defect
id:       AL-CX3-b
file:     analytics/routing/worklist.py
line:     27
severity: medium
command:  /analyze-complexity
class:    ALG-CX-3
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §3
anchor:   job = pending.pop(0)
match:    pending|pop\(0\)|plan_day|worklist
match:    pop\(0\)|O\(n\)|deque|popleft|front|shift|quadratic|O\(n\^?2\)
```

`list.pop(0)` shifts every remaining job; a day holds every delivery job of the region, re-queued jobs included. Proof V592. Fix: `collections.deque` and `popleft()`.

## AL-CX4-a — The rate card is copied and sorted again for every order

```defect
id:       AL-CX4-a
file:     api/src/pricing/rate-card.service.ts
line:     31
severity: medium
command:  /analyze-complexity
class:    ALG-CX-4
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §4
anchor:   const sorted = rates.slice().sort((a, b) => a.minKg - b.minKg);
match:    rates|sort|requoteOpenOrders|rate.?card
match:    invariant|hoist|once|outside the loop|per (order|iteration)|re-?sort|every order
```

`rates` is read once above the loop and never changes, yet each open order copies and sorts it: n_orders × m log m work in the nightly re-quote. Proof V593 (a spy on `sort` counts one call per order). Fix: sort once before the loop.

## AL-CX4-b — The import separator regex is compiled once per address

```defect
id:       AL-CX4-b
file:     geo/address_normalize.go
line:     13
severity: low
command:  /analyze-complexity
class:    ALG-CX-4
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §4
anchor:   re := regexp.MustCompile(pattern)
match:    MustCompile|pattern|NormalizeAll|regexp
match:    invariant|hoist|once|outside the loop|per (address|iteration)|compil
```

`pattern` is a parameter fixed for the batch; `regexp.MustCompile` runs for every address of the import. Linear in Go, but invariant work × n (staticcheck has no rule for `MustCompile` of a variable in a loop). Proof V593. Fix: compile once before the loop.

## AL-CX5-a — Members are joined to teams by filtering the full member list per team

```defect
id:       AL-CX5-a
file:     api/src/reports/team-report.service.ts
line:     28
severity: medium
command:  /analyze-complexity
class:    ALG-CX-5
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §5
anchor:   return teams.map((t) => ({ ...t, members: members.filter((m) => m.teamId === t.id) }));
match:    teams|members|teamId|filter|teamsWithMembers
match:    nested|join|group|Map\.groupBy|Map|O\(n\s*[·*x×]\s*m\)|quadratic|per team
```

Both queries are unbounded per tenant; `members.filter` per team is a nested-loop join, teams × members compares. Proof V590. Fix: group members by `teamId` once (`Map.groupBy`), then look up per team.

## AL-CX5-b — Dispatch joins couriers to pending orders with two nested loops

```defect
id:       AL-CX5-b
file:     geo/assign.go
line:     11
severity: medium
command:  /analyze-complexity
class:    ALG-CX-5
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §5
anchor:   if c.ZoneID == o.ZoneID && o.CourierID == "" && load < capacity {
match:    AssignByZone|ZoneID|couriers|orders
match:    nested|join|map\[|group|index|O\(n\s*[·*x×]\s*m\)|quadratic|per courier
```

Every on-shift courier scans every pending order of the region on every dispatch tick: couriers × orders compares. Proof V590. Fix: index pending orders by `ZoneID` once (`map[string][]*PendingOrder`).

## AL-CX6-a — The variant matrix is generated in full before the 500 cap is checked

```defect
id:       AL-CX6-a
file:     web/src/products/variant-matrix.ts
line:     12
severity: low
command:  /analyze-complexity
class:    ALG-CX-6
owner:    algorithms
bucket:   report-flagged
detector: complexity-scan §6
anchor:   export function generateCombinations(attrs: AttributeInput[]): Combination[] {
match:    generateCombinations|MAX_VARIANTS|variant|combination
match:    cartesian|combinat|product|cap|before|after generation|MAX_VARIANTS|lazily|stop at|refuse
```

`buildVariantMatrix` builds every combination, then compares `rows.length > MAX_VARIANTS`; nothing caps attribute or value counts, so 6 attributes × 10 values build a million objects in the browser tab first. Browser only, hence low. Settling test V594 (cap + 1). Fix: refuse when the product of the value counts exceeds `MAX_VARIANTS`, before generating.

## AL-CX6-b — Bundle candidates are materialised in full, then cut to 200

```defect
id:       AL-CX6-b
file:     analytics/promo/bundles.py
line:     19
severity: medium
command:  /analyze-complexity
class:    ALG-CX-6
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §6
anchor:   combos = list(itertools.product(*[a.options for a in request_attrs]))
match:    itertools\.product|combos|candidate_bundles|MAX_BUNDLES
match:    cartesian|combinat|product|materiali|list\(|cap|before|islice|lazily|stop at
```

`list(itertools.product(…))` builds every combination the request names before `[:MAX_BUNDLES]`; the request's attribute count is not capped. Proof V594. Fix: iterate the product lazily and stop at `MAX_BUNDLES` sellable ones (`itertools.islice` over a filter), or refuse an oversized request.

## AL-RC1-a — The Q&A thread renderer recurses as deep as shoppers nest replies

```defect
id:       AL-RC1-a
file:     api/src/comments/comment-thread.renderer.ts
line:     22
severity: medium
command:  /analyze-complexity
class:    ALG-RC-1
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §7
anchor:   return [self, ...node.replies.flatMap(renderThread)];
match:    renderThread|replies|flatMap|thread
match:    recurs|depth|stack|RangeError|overflow|iterative|explicit stack|MAX_DEPTH|cap
```

Replies are stored rows (`comments.reply_to`), not parsed JSON, so the body limit does not bound depth, and nothing caps nesting; a reply chain thousands deep throws `RangeError` on every page view of that product. Proof V595 (depth bomb). Fix: an explicit stack, or a depth cap at write time.

## AL-RC1-b — The zone walk recurses as deep as merchants nest zones, in Go

```defect
id:       AL-RC1-b
file:     geo/zone_tree.go
line:     13
severity: high
command:  /analyze-complexity
class:    ALG-RC-1
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §7
anchor:   walkZone(c, out)
match:    walkZone|Children|zone_tree|ZoneCodes
match:    recurs|depth|stack|overflow|fatal|goroutine stack|iterative|explicit stack|cycle|visited
```

Zones are merchant-built and nothing caps nesting (nor a cycle: no visited set); Go grows the stack to 1 GB and then dies fatally, taking the dispatcher down, not one request. Proof V595. Fix: an explicit stack with a depth cap and a visited set.

## AL-RC2-a — `rootOf` follows `parent` with no visited set; an admin PATCH can make a cycle

```defect
id:       AL-RC2-a
file:     api/src/catalog/category-path.ts
line:     7
severity: high
command:  /analyze-complexity
class:    ALG-RC-2
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §8
anchor:   const rootOf = (c: Category): Category => (c.parent ? rootOf(c.parent) : c);
match:    rootOf|parent|category
match:    cycle|loop|visited|infinite|parentId|PATCH|stack|RangeError|hang
```

`PATCH /stores/:storeId/categories/:id` sets `parentId` with no cycle check (`UpdateCategoryDto`, `CategoryPathService.update`), and `categories.parent_id REFERENCES categories(id)` allows A→B→A; `rootOf` then recurses until `RangeError`. Proof V596 (cycle injection). Fix: refuse a parent that is a descendant at write time, and a visited set in the walk.

## AL-RC2-b — The subtree CTE descends `parent_id` with no CYCLE clause or depth bound

```defect
id:       AL-RC2-b
file:     api/src/catalog/category-paths.repository.ts
line:     11
severity: high
command:  /analyze-complexity
class:    ALG-RC-2
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §8
anchor:   WITH RECURSIVE t AS (
match:    WITH RECURSIVE|subtree|category_?paths|parent_id
match:    cycle|CYCLE|depth|infinite|loop|hang|path array|visited|never (ends|terminates)
```

The anchor member starts at an arbitrary category, so a parent cycle written through the same PATCH puts the walk into the cycle; the `UNION ALL` never ends and the query runs until `statement_timeout`. Postgres 17 supports `CYCLE id SET is_cycle USING path`. Proof V596. Fix: the `CYCLE` clause (or a depth column bounded in the recursive member).

## AL-RC3-a — The plan counter is Fibonacci-shaped recursion with no memo, on the request's stop count

```defect
id:       AL-RC3-a
file:     api/src/delivery/route-count.ts
line:     7
severity: medium
command:  /analyze-complexity
class:    ALG-RC-3
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §9
anchor:   const legPlans = (n: number): number => (n < 2 ? 1 : legPlans(n - 1) + legPlans(n - 2));
match:    legPlans|summarisePlan|possiblePlans|route
match:    exponential|fib|memo|overlap|2\^n|O\(φ|dynamic programming|DP|iterative
```

`legPlans(n)` calls itself twice on overlapping subproblems; `n` is the batch's stop count from the request, 40 stops already take about a second of event-loop time and 50 take minutes. Proof V597 (self-call count × ~11 per +5). Fix: an iterative two-variable DP (the count passes 2^53 after 78 stops anyway).

## AL-RC3-b — `best_split` recomputes overlapping prefixes with no memo

```defect
id:       AL-RC3-b
file:     analytics/promo/split_cost.py
line:     12
severity: medium
command:  /analyze-complexity
class:    ALG-RC-3
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §9
anchor:   single = best_split(i - 1) + prices[i - 1]
match:    best_split|cheapest_split|split_cost
match:    exponential|memo|cache|lru_cache|overlap|dynamic programming|DP|iterative
```

Two self-calls per level on `i - 1` and `i - 2`: exponential in basket length, and promo baskets reach 60+ items. Proof V597. Fix: `functools.cache` on the inner function (keyed on `i`; `prices` and `pack_price` are closed over and fixed) or a bottom-up table.

## AL-RC4-a — The order sync pages on a non-unique `updatedAt` with `$gte` and exits only on an empty page

```defect
id:       AL-RC4-a
file:     api/src/sync/order-sync.job.ts
line:     24
severity: high
command:  /analyze-complexity
class:    ALG-RC-4
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §10
anchor:   const rows = await this.em.fork().find(Order, { updatedAt: { $gte: after } }, { limit: BATCH, orderBy: { updatedAt: 'asc' } });
match:    updatedAt|\$gte|after|order-?sync|for ?\(;;\)
match:    non-?unique|\$gte|>=|strict|tie|stall|never (ends|exits)|infinite|empty page|short page|keyset|composite
```

With `$gte`, the last row of a page is always returned again, so the page is never empty and the loop never exits; with more than 500 rows sharing one `updatedAt` (a bulk status update) the cursor cannot advance at all. Proof V598 (stalled progress). Fix: a composite cursor `(updatedAt, id)` with strict `>` and a short-page exit (`rows.length < BATCH`).

## AL-RC4-b — The score backfill pages on a non-unique double with `>=`

```defect
id:       AL-RC4-b
file:     ranking/src/main/java/com/kestrelway/ranking/backfill/ScoreBackfill.java
line:     22
severity: high
command:  /analyze-complexity
class:    ALG-RC-4
owner:    algorithms
bucket:   report-with-fix
detector: complexity-scan §10
anchor:   List<ScoreRow> page = repo.findByScoreGreaterThanEqual(cursor, PAGE_SIZE);
match:    findByScoreGreaterThanEqual|cursor|ScoreBackfill|getScore
match:    non-?unique|>=|GreaterThanEqual|strict|tie|stall|never (ends|exits)|infinite|empty|keyset|composite
```

The last row of every page comes back on the next page, so `page.isEmpty()` never holds; and more than 500 items at one score pin the cursor. The backfill runs forever after every model release. Proof V598. Fix: page on `(score, itemId)` with strict `>` and stop on a short page.

## AL-OC1-a — `_.sortedIndex` runs over bands in insertion order

```defect
id:       AL-OC1-a
file:     api/src/pricing/weight-band.ts
line:     19
severity: medium
command:  /analyze-complexity
class:    ALG-OC-1
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §1
anchor:   const i = _.sortedIndex(bands.map((b) => b.maxKg), weightKg);
match:    sortedIndex|bandFor|maxKg|Object\.values|bandsById
match:    sort(ed)?|precondition|insertion order|unsorted|binary search|order
```

`Object.values(bandsById)` returns bands in the order the rows were read (string keys keep insertion order); nothing sorts by `maxKg`, so a band added later (lighter) sits at the end and parcels get the wrong fee band. Proof V599 (differential against a linear scan). Fix: sort by `maxKg` on this path (or keep the cache sorted).

## AL-OC1-b — `itertools.groupby` over rows ordered by id, not by day

```defect
id:       AL-OC1-b
file:     analytics/reports/daily_sales.py
line:     26
severity: medium
command:  /analyze-complexity
class:    ALG-OC-1
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §1
anchor:   for day, group in itertools.groupby(rows, key=lambda r: r.day):
match:    groupby|daily_totals|ORDER BY id|day
match:    sort(ed)?|precondition|ORDER BY|consecutive|adjacent|same day (twice|split)|duplicate
```

`month_rows` reads `ORDER BY id`; a late-booked sale with a higher id for an earlier business day starts a second group for that day, so the merchant e-mail lists the day twice with split totals. Proof V599. Fix: `ORDER BY business_day, id` or `sorted(rows, key=…)` before grouping.

## AL-OC2-a — `sort.Slice` is not stable and `cands[0]` wins ties on whole-minute ETAs

```defect
id:       AL-OC2-a
file:     geo/dispatch_rank.go
line:     18
severity: medium
command:  /analyze-complexity
class:    ALG-OC-2
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §2
anchor:   sort.Slice(cands, func(i, j int) bool { return cands[i].ETA < cands[j].ETA })
match:    sort\.Slice|PickCourier|ETA|winner
match:    stab(le|ility)|tie|SliceStable|equal|first wins|tie-?break|non-?determin
```

ETAs are rounded to minutes, so ties are common; `sort.Slice` gives no order among them, and which courier gets the job changes between runs on the same input. Proof V600 (tie order across shuffles). Fix: a total tie-break (`Rating`, then `CourierID`) or `sort.SliceStable` over a defined input order.

## AL-OC2-b — The leaderboard sorts unstably and then pages in memory

```defect
id:       AL-OC2-b
file:     geo/leaderboard.go
line:     18
severity: medium
command:  /analyze-complexity
class:    ALG-OC-2
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §2
anchor:   slices.SortFunc(rows, func(a, b Row) int { return cmp.Compare(b.Points, a.Points) })
match:    SortFunc|LeaderboardPage|Points|offset
match:    stab(le|ility)|tie|SortStableFunc|equal|pag(e|ing)|duplicate|skip|tie-?break
```

Couriers with equal points can swap between two requests, so `?offset=` pages repeat one courier and skip another. Proof V600. Fix: `slices.SortStableFunc` over a fixed order, or tie-break on `CourierID`.

## AL-OC3-a — The pick board keys order lines by `orderId`; every order but the last line loses its picks

```defect
id:       AL-OC3-a
file:     api/src/fulfilment/pick-board.service.ts
line:     42
severity: high
command:  /analyze-complexity
class:    ALG-OC-3
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §3
anchor:   const byOrder = new Map(lines.map((l) => [l.orderId, l]));
match:    byOrder|orderId|lines|pick.?board
match:    collaps|overwrit|lost|drop|duplicate|unique|groupBy|one line|last (one|line) wins
```

`order_lines` has no unique constraint on `order_id` (`0001_init.sql`, an index only) and orders have several lines, so the `Map` keeps the last line per order and pickers never see the others. Proof V601 (2 lines in, 1 out). Fix: `Map.groupBy(lines, (l) => l.orderId)` and a card per line.

## AL-OC3-b — A `TreeSet` ordered by price drops every item that ties on price

```defect
id:       AL-OC3-b
file:     ranking/src/main/java/com/kestrelway/ranking/shelf/ShelfRanker.java
line:     15
severity: high
command:  /analyze-complexity
class:    ALG-OC-3
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §3
anchor:   TreeSet<Item> byPrice = new TreeSet<>(Comparator.comparing(Item::getPrice));
match:    TreeSet|byPrice|getPrice|cheapestFirst
match:    collaps|drop|duplicate|equal price|comparator|equals|thenComparing|consistent|lost
```

A `TreeSet` treats comparator-equal elements as the same element: the second item at 4.99 is silently not added, and products vanish from the category shelf (BigDecimal 2.0 vs 2.00 compare equal too). Proof V601. Fix: `thenComparing(Item::getId)`, or sort a list.

## AL-OC4-a — The hand-rolled binary search sets `lo = mid` and stops shrinking

```defect
id:       AL-OC4-a
file:     api/src/pricing/tier-lookup.ts
line:     15
severity: medium
command:  /analyze-complexity
class:    ALG-OC-4
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §4
anchor:   if (tiers[mid].min < qty) lo = mid;
match:    tierIndexFor|lo = mid|while \(lo < hi\)|tiers
match:    shrink|infinite|hang|never (ends|terminates)|mid \+ 1|off.?by.?one|binary search|interval
```

When `hi = lo + 1` and `tiers[lo].min < qty`, `mid = lo` and `lo = mid` leaves the interval unchanged: the request spins forever on the event loop. Proof V602 (differential vs a linear scan, with a step counter). Fix: `lo = mid + 1` with a defined post-condition, or lodash `sortedLastIndexBy` (already a dependency).

## AL-OC4-b — The heap uses 1-based child indexes on a 0-based list

```defect
id:       AL-OC4-b
file:     ranking/src/main/java/com/kestrelway/ranking/heap/MinHeap.java
line:     14
severity: medium
command:  /analyze-complexity
class:    ALG-OC-4
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §4
anchor:   int left = 2 * i;
match:    MinHeap|siftDown|2 \* i|left|child
match:    2 ?\* ?i ?\+ ?1|2 ?\* ?i ?\+ ?2|0-based|index|child|off.?by.?one|PriorityQueue
```

For `i = 0`, `left = 0` is the node itself, so `poll()` never sifts the new root down and the top-K merge returns items out of order. Proof V602 (differential vs `java.util.PriorityQueue`). Fix: children at `2i + 1` and `2i + 2`, or `PriorityQueue`.

## AL-RD1-a — Giveaway winners are drawn with a random comparator

```defect
id:       AL-RD1-a
file:     api/src/promotions/raffle.service.ts
line:     18
severity: high
command:  /analyze-complexity
class:    ALG-RD-1
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §5
anchor:   const order = entrants.sort(() => Math.random() - 0.5);
match:    Math\.random\(\) - 0\.5|sort|drawWinners|raffle|entrants
match:    bias|shuffle|Fisher.?Yates|uniform|comparator|permutation|unfair
```

`sort(() => Math.random() - 0.5)` is not a uniform shuffle (it depends on the engine's sort algorithm and favours early entrants), and it decides prizes. Proof V603 (chi-square, n = 4). Fix: Fisher–Yates with `crypto.randomInt` (the generator choice is security's line, CWE-338).

## AL-RD1-b — The tasting sign-up shuffle swaps each slot with any slot

```defect
id:       AL-RD1-b
file:     analytics/sampling/shuffle_entrants.py
line:     7
severity: high
command:  /analyze-complexity
class:    ALG-RD-1
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §5
anchor:   j = random.randrange(len(xs))
match:    shuffle_entrants|randrange|swap|seat_list
match:    bias|naive|Fisher.?Yates|random\.shuffle|uniform|n\^n|permutation|range\(i
```

Drawing `j` from the whole list for every `i` gives n^n equally likely paths over n! permutations, so some seat orders are more likely than others. Proof V603. Fix: `random.shuffle` (or `j` from `[0, i]`).

## AL-RD2-a — The QA inspection pick never draws the last packed order

```defect
id:       AL-RD2-a
file:     api/src/quality/audit-sampler.ts
line:     15
severity: medium
command:  /analyze-complexity
class:    ALG-RD-2
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §6
anchor:   const pick = Math.floor(Math.random() * (max - min)) + min;
match:    inspectionPosition|Math\.floor|max - min|pick
match:    max (is )?never|exclusive|inclusive|\+ ?1|off.?by.?one|range|unreachable|last
```

The range is documented inclusive of both ends, but `Math.random() * (max - min)` floors to at most `max - 1`: the last order of every picker's shift is never inspected. Proof V604 (RNG stubs at 0 and 1 − 2^-53). Fix: `* (max - min + 1)`.

## AL-RD2-b — The sponsored-slot rotation draws `nextInt() % totalWeight`

```defect
id:       AL-RD2-b
file:     ranking/src/main/java/com/kestrelway/ranking/sponsored/WeightedPicker.java
line:     18
severity: medium
command:  /analyze-complexity
class:    ALG-RD-2
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §6
anchor:   int r = rng.nextInt() % totalWeight;
match:    nextInt|totalWeight|WeightedPicker|pick
match:    negative|modulo|bias|nextInt\(totalWeight\)|floorMod|weight|range
```

`nextInt()` is signed, so half the draws are negative and fall to the first advertiser (`r -= w; r < 0`), and `%` adds modulo bias; advertisers do not get the share they paid for. Proof V604. Fix: `rng.nextInt(totalWeight)`.

## AL-RD3-a — Experiment arms come from `Math.abs(hashCode()) % 100`

```defect
id:       AL-RD3-a
file:     ranking/src/main/java/com/kestrelway/ranking/experiments/ExperimentBucket.java
line:     13
severity: medium
command:  /analyze-complexity
class:    ALG-RD-3
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §7
anchor:   int bucket = Math.abs(userId.hashCode()) % 100;
match:    hashCode|Math\.abs|armFor|bucket
match:    MIN_VALUE|negative|abs|floorMod|signed|hash|bucket
```

`Math.abs(Integer.MIN_VALUE)` is negative, so those users get a negative bucket and always land in treatment. Proof V604 (a `MIN_VALUE` hash lands outside [0, 100)). Fix: `Math.floorMod` on a stable unsigned hash (murmur/SHA-256 prefix) of the id.

## AL-RD3-b — Experiment arms use Python's salted `hash()`

```defect
id:       AL-RD3-b
file:     analytics/experiments/assign.py
line:     7
severity: medium
command:  /analyze-complexity
class:    ALG-RD-3
owner:    algorithms
bucket:   report-flagged
detector: algorithm-contract-scan §7
anchor:   return VARIANTS[hash(user_id) % len(VARIANTS)]
match:    hash\(user_id\)|arm_for|VARIANTS
match:    salt|PYTHONHASHSEED|per process|restart|sticky|stable hash|hashlib|move
```

`str` hashes are salted per process (`PYTHONHASHSEED`), so a shopper changes arm whenever a worker restarts, and adding a variant reshuffles everyone. Flagged: whether the worker pins `PYTHONHASHSEED` is a deploy fact not in the repo. Proof V604. Fix: a `hashlib` digest of the user id, mod n.

## AL-GE1-a — The delivery radius uses planar degrees × 111

```defect
id:       AL-GE1-a
file:     api/src/delivery/delivery-radius.ts
line:     10
severity: high
command:  /analyze-complexity
class:    ALG-GE-1
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §8
anchor:   const km = Math.sqrt((lat2 - lat1) ** 2 + (lng2 - lng1) ** 2) * 111;
match:    isWithinDeliveryRadius|Math\.sqrt|\* ?111|lat|lng
match:    planar|Euclid|haversine|cos\(lat|longitude (shrinks|degree)|great.?circle|geodesic|spherical
```

A degree of longitude is 111 km only at the equator (about 106 km at Fiji's 17° S and 89 km at Auckland's 37° S), so checkout offers delivery outside the radius. Proof V605 (geodesic vectors). Fix: haversine in radians with one earth radius, or PostGIS `ST_DWithin(…::geography)`.

## AL-GE1-b — `ST_DWithin` on a `geometry(Point, 4326)` column with a radius in metres

```defect
id:       AL-GE1-b
file:     api/src/stores/nearby-stores.repository.ts
line:     20
severity: high
command:  /analyze-complexity
class:    ALG-GE-1
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §8
anchor:   WHERE ST_DWithin(s.location, ST_SetSRID(ST_MakePoint(?, ?), 4326), ?)
match:    ST_DWithin|radiusM|near|DEFAULT_RADIUS_M|4326
match:    degree|geometry|geography|metre|meter|unit|SRID|cast
```

On SRID 4326 geometry the distance is in degrees, so `5000` is 5,000 degrees: every store matches every shopper. `stores.location` is `geometry(Point, 4326)` (`0002_stores_geo.sql`). Proof V605. Fix: cast both sides `::geography` (metres), keeping the GiST index on a geography expression.

## AL-GE2-a — The store pin is written as `ST_MakePoint(lat, lng)`

```defect
id:       AL-GE2-a
file:     api/src/stores/store-location.repository.ts
line:     18
severity: high
command:  /analyze-complexity
class:    ALG-GE-2
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §9
anchor:   ST_MakePoint(${lat}, ${lng})
match:    ST_MakePoint|setLocation|lat|lng
match:    axis|order|swap|lon(gitude)?.?first|x.*y|lng, lat|transpos
```

`ST_MakePoint` takes (x, y) = (lon, lat); every stored point is transposed, and every distance query on `stores.location` is wrong for the store. Proof V606 (a known point round-trips). Fix: `ST_MakePoint(${lng}, ${lat})` and a boundary check |lat| ≤ 90.

## AL-GE2-b — The GeoJSON export writes `[lat, lng]`

```defect
id:       AL-GE2-b
file:     analytics/exports/geojson_export.py
line:     30
severity: high
command:  /analyze-complexity
class:    ALG-GE-2
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §9
anchor:   "coordinates": [row.lat, row.lng]
match:    coordinates|row\.lat|geojson|store_features
match:    axis|order|swap|lon(gitude)?.?first|RFC ?7946|\[lng, lat\]|transpos
```

RFC 7946 § 3.1.1 positions are `[longitude, latitude]`; every store gets its latitude as longitude and vice versa, so a Fiji store at 178° E arrives with a latitude of 178°, which the partner map rejects or clamps. Proof V606. Fix: `[row.lng, row.lat]`.

## AL-GE3-a — The service-area test fails for boxes that cross ±180°

```defect
id:       AL-GE3-a
file:     api/src/delivery/service-area.ts
line:     16
severity: medium
command:  /analyze-complexity
class:    ALG-GE-3
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §10
anchor:   const inLng = p.lng >= box.minLng && p.lng <= box.maxLng;
match:    insideServiceArea|minLng|maxLng|inLng
match:    antimeridian|180|wrap|dateline|west.*east|east < west|split
```

The product serves Fiji and the Chatham Islands (README § Markets), where a service area runs from 177° E to −178° (west > east); `minLng ≤ lng ≤ maxLng` then matches nothing and those merchants get no orders. Proof V607. Fix: when `minLng > maxLng`, test `lng >= minLng || lng <= maxLng`.

## AL-GE3-b — The dispatcher's live map filters couriers with `lng BETWEEN west AND east`

```defect
id:       AL-GE3-b
file:     geo/bbox_query.go
line:     17
severity: medium
command:  /analyze-complexity
class:    ALG-GE-3
owner:    algorithms
bucket:   report-with-fix
detector: algorithm-contract-scan §10
anchor:   WHERE lng BETWEEN $1 AND $2 AND lat BETWEEN $3 AND $4
match:    BETWEEN|couriersInView|BBox|West|East
match:    antimeridian|180|wrap|dateline|west.*east|east < west|split
```

A viewport over Fiji's Lau group crosses the antimeridian (West > East), and `BETWEEN` then returns no couriers. Proof V607. Fix: split the query into two ranges when `West > East`.

## AL-NS1-a — Group GMV is summed with a naive running float total

```defect
id:       AL-NS1-a
file:     analytics/metrics/gmv_rollup.py
line:     27
severity: medium
command:  /analyze-complexity
class:    ALG-NS-1
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §1
anchor:   total += x
match:    total|group_gmv_nzd|amounts_fx|gmv
match:    fsum|Kahan|Neumaier|pairwise|accumulat|rounding|precision|mixed.?magnitude|np\.sum
```

About 10^7 FX-converted values a month, from cents to hundreds of thousands, are added one by one; the docstring and the test state the finance reconciliation tolerance, 1e-9 relative, which a naive sum of that count and range can exceed. Proof V608 (against `math.fsum`). Fix: `math.fsum(amounts_fx)` (or `np.sum` on the array the module already builds).

## AL-NS1-b — Monthly event weights accumulate in a `Float32Array`

```defect
id:       AL-NS1-b
file:     api/src/analytics/stats.ts
line:     10
severity: medium
command:  /analyze-complexity
class:    ALG-NS-1
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §1
anchor:   const acc = new Float32Array(buckets);
match:    Float32Array|monthlyBucketWeights|acc
match:    float32|single.?precision|24.?bit|accumulat|precision|Float64Array|absorb
```

float32 has a 24-bit significand: once a bucket passes 2^24 (16.7M) units of weight, small event weights stop changing it; a busy store's month passes that. Proof V608. Fix: accumulate in `Float64Array` (store float32 afterwards if needed).

## AL-NS2-a — ETA variance uses the textbook sum-of-squares formula on epoch seconds

```defect
id:       AL-NS2-a
file:     analytics/metrics/delivery_variance.py
line:     20
severity: medium
command:  /analyze-complexity
class:    ALG-NS-2
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §2
anchor:   var = (sumsq - s * s / n) / n
match:    sumsq|eta_variance|variance
match:    cancel|Welford|two.?pass|pvariance|np\.var|catastroph|negative|precision
```

With a mean near 1.7e9 and a spread of a few hundred seconds, `sumsq` and `s*s/n` agree in their leading 13 digits and the subtraction keeps the noise (it can go negative, which `max(…, 0.0)` hides); the 10-minute alert fires or stays silent at random. Proof V608 (mean 1e9, spread 1). Fix: `statistics.pvariance` / `np.var`, or Welford.

## AL-NS2-b — `1 - Math.cos(dTheta)` for sub-degree heading changes

```defect
id:       AL-NS2-b
file:     api/src/analytics/stats.ts
line:     30
severity: low
command:  /analyze-complexity
class:    ALG-NS-2
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §2
anchor:   total += 1 - Math.cos(dTheta);
match:    Math\.cos|headingChangeScore|dTheta
match:    cancel|sin|small angle|2 \* Math\.sin|catastroph|precision
```

For sub-degree angles `cos` is within 4e-5 of 1, so `1 - cos` keeps only the digits the rounding of `cos` left (below about 1e-8 rad it is exactly 0); the smoothness score is reported per courier. Proof V608. Fix: `2 * Math.sin(dTheta / 2) ** 2`.

## AL-NS3-a — Softmax without the max shift on logits up to 1,000

```defect
id:       AL-NS3-a
file:     analytics/ranking/softmax.py
line:     7
severity: medium
command:  /analyze-complexity
class:    ALG-NS-3
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §3
anchor:   e = np.exp(scores)
match:    np\.exp|display_probabilities|softmax
match:    overflow|inf|NaN|max|shift|logsumexp|stable softmax
```

`np.exp(800)` is `inf`, so `e / e.sum()` returns NaN for every product in the panel. Proof V608 (logits of 1,000). Fix: `np.exp(scores - scores.max())` or `scipy.special.softmax`.

## AL-NS3-b — The route on-time probability multiplies up to 600 per-step probabilities

```defect
id:       AL-NS3-b
file:     api/src/analytics/stats.ts
line:     40
severity: medium
command:  /analyze-complexity
class:    ALG-NS-3
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §3
anchor:   return probs.reduce((acc, p) => acc * p, 1);
match:    routeOnTimeProbability|probs|reduce
match:    underflow|log|sum of logs|zero|denormal|log.?space
```

600 factors around 0.3 underflow to exactly 0, so every long route reports 0% and the ranking between routes is lost. Proof V608 (400 factors of 1e-3). Fix: sum `Math.log(p)` and compare in log space.

## AL-NS4-a — Demand is fitted with an explicit inverse of the normal equations

```defect
id:       AL-NS4-a
file:     analytics/forecast/demand_fit.py
line:     12
severity: medium
command:  /analyze-complexity
class:    ALG-NS-4
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §4
anchor:   beta = np.linalg.inv(X.T @ X) @ X.T @ y
match:    linalg\.inv|fit_demand|X\.T @ X|beta
match:    condition|ill.?cond|lstsq|QR|normal equation|collinear|inverse
```

`price` and `promo_price` are nearly collinear for SKUs that rarely change price; `inv(X.T @ X)` squares the condition number and the coefficients swing wildly between weeks. Proof V608 (`cond` computed; a near-collinear design). Fix: `np.linalg.lstsq(X, y)` with `np.linalg.cond(X)` checked.

## AL-NS4-b — The Newton solve has an absolute 1e-9 tolerance and no iteration cap

```defect
id:       AL-NS4-b
file:     analytics/forecast/eta_solver.py
line:     12
severity: medium
command:  /analyze-complexity
class:    ALG-NS-4
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §4
anchor:   while abs(err) > 1e-9:
match:    while abs\(err\)|dispatch_offset|Newton|err
match:    max.?iter|iteration (cap|limit|bound)|never (ends|terminates)|infinite|relative tolerance|absolute tolerance|converge
```

The `max(x, 0)` clamp makes the model non-smooth at 0, so an iterate that overshoots below zero can oscillate instead of converging, and nothing bounds the iteration count: the worker hangs on that store's forecast. Proof V608 (the loop stops at max-iteration). Fix: `for _ in range(MAX_ITER)` with a relative + absolute tolerance, raising on non-convergence.

## AL-NS5-a — The rollup C extension is built with `-ffast-math`

```defect
id:       AL-NS5-a
file:     analytics/setup.py
line:     7
severity: medium
command:  /analyze-complexity
class:    ALG-NS-5
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §5
anchor:   extra_compile_args=["-O3", "-ffast-math"],
match:    ffast-math|extra_compile_args|fastsum
match:    fast.?math|NaN|isnan|IEEE|finite.?math|reassoc
```

`-ffast-math` implies `-ffinite-math-only`, so the compiler may delete the `isnan` check in `csrc/fastsum.c` and reorder the sum; missing FX rates (NaN) then poison the total. Proof V609 (the flag in the shipped build, two-ended with the NaN check). Fix: drop the flag (keep `-O3`).

## AL-NS5-b — `fastmath=True` on a kernel that skips NaN

```defect
id:       AL-NS5-b
file:     analytics/metrics/fast_kernels.py
line:     6
severity: medium
command:  /analyze-complexity
class:    ALG-NS-5
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §5
anchor:   @numba.jit(nopython=True, fastmath=True)
match:    fastmath|numba\.jit|mean_skipnan
match:    fast.?math|NaN|isnan|IEEE|nnan|finite
```

`fastmath=True` enables LLVM's `nnan` flag, which lets `np.isnan(v)` fold to false; NaN baskets are then summed and the store's mean becomes NaN. Proof V609. Fix: `fastmath={"reassoc", "contract"}` at most, or no flag.

## AL-SL1-a — `BF.ADD` on per-shopper filters that are never `BF.RESERVE`d

```defect
id:       AL-SL1-a
file:     api/src/catalog/seen-products.ts
line:     19
severity: low
command:  /analyze-complexity
class:    ALG-SL-1
owner:    algorithms
bucket:   report-flagged
detector: numeric-stability-scan §6
anchor:   await this.redis.call('BF.ADD', key, sku);
match:    BF\.ADD|markSeen|seen
match:    BF\.RESERVE|capacity|error rate|false positive|default|size|n and p|sizing
```

`BF.ADD` on a missing key creates a filter with the server's default error rate and capacity, which no one chose or wrote down; the rail's false-positive rate is unknown. Flagged: the module defaults live in the Redis deploy, not the repo. Proof V609 (seeded fill at the stated n). Fix: `BF.RESERVE key 0.01 <n>` on first use, with p and n documented.

## AL-SL1-b — A Count-Min sketch of width 50, depth 2, with no stated ε or δ

```defect
id:       AL-SL1-b
file:     analytics/metrics/heavy_hitters.py
line:     8
severity: low
command:  /analyze-complexity
class:    ALG-SL-1
owner:    algorithms
bucket:   report-flagged
detector: numeric-stability-scan §6
anchor:   sketch = CountMinSketch(width=50, depth=2)
match:    CountMinSketch|width=50|depth=2|search_term_counts
match:    epsilon|ε|delta|δ|error|width|depth|over.?count|sizing|confidence
```

Width 50 means an over-count of up to about e/50 ≈ 5% of all searches per term with probability 1 − e^-2 ≈ 86%; nothing says what error the insights tab accepts. Flagged: the tolerance is a product decision. Proof V609. Fix: size from ε and δ (`CountMinSketch(confidence=…, error_rate=…)`) and document them.

## AL-SL2-a — A Bloom filter decides that an order was already charged

```defect
id:       AL-SL2-a
file:     api/src/billing/charge-dedupe.service.ts
line:     20
severity: high
command:  /analyze-complexity
class:    ALG-SL-2
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §7
anchor:   if (await this.redis.call('BF.EXISTS', 'charged', orderId)) return;
match:    BF\.EXISTS|captureOnce|charged|dedupe
match:    false positive|skip|missed charge|exact|source of truth|Bloom|authority|confirm
```

A Bloom positive can be false, and here it skips `capture` with no exact check: a real order is never charged. Proof V609 (a spy shows no exact check behind a positive). Fix: use the filter only as a negative pre-filter and confirm every positive against the captures table (or rely on the PSP idempotency key alone).

## AL-SL2-b — Seat invoices are computed from a HyperLogLog count

```defect
id:       AL-SL2-b
file:     analytics/billing/unique_seats.py
line:     13
severity: high
command:  /analyze-complexity
class:    ALG-SL-2
owner:    algorithms
bucket:   report-with-fix
detector: numeric-stability-scan §7
anchor:   seats = r.pfcount(f"seats:{tenant}")
match:    pfcount|seats|seat_invoice_line|PRICE_PER_SEAT
match:    HyperLogLog|HLL|approximat|0\.81|error|exact|invoice|bill
```

`PFCOUNT` has a standard error of 0.81%, so a tenant with a few hundred seats is billed for a seat count that can be off by several, in either direction. Proof V609. Fix: an exact distinct count (a `seat_sign_ins` table or a Redis set per month) for anything billed.

## Routed rows — scored only under their owner

Each is listed by `/analyze-complexity` as `→ <owner pack> <skill> §n` (or `(owner pack <x> not installed)`) and never graded there; an `/analyze-complexity` finding on one is UNMATCHED, not credited.

## AL-HO-CQ-a — The standard plan is detected with float `===`

```defect
id:       AL-HO-CQ-a
file:     api/src/pricing/fee-compare.ts
line:     9
severity: medium
command:  /quality-audit
class:    CQ §2 float equality
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §2 (routed from /analyze-complexity)
anchor:   if (fee === 0.3) {
match:    fee === 0\.3|planLabel|baseRate
match:    float|equal|===|epsilon|tolerance|0\.1 ?\+ ?0\.2|basis points
```

`0.25 + 0.05` is not `=== 0.3` in binary floating point, so a standard plan can read as custom. Float equality is code-quality's; `/analyze-complexity` lists it `→ code-quality correctness-smell-scan §2` (numeric-stability-scan § Boundaries) and never grades it.

## AL-HO-CQ-b — Numeric legacy ids are sorted with no comparator

```defect
id:       AL-HO-CQ-b
file:     api/src/orders/id-sort.ts
line:     12
severity: medium
command:  /quality-audit
class:    CQ §4 sort without comparator
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §4 (routed from /analyze-complexity)
anchor:   ids.sort();
match:    ids\.sort|legacyIdRange
match:    comparator|lexicograph|string|code.?point|\(a, b\) => a - b|numeric
```

`[9, 10].sort()` is `[10, 9]`: the import report prints the wrong first and last id. A comparator defect is code-quality's (algorithm-contract-scan § Boundaries); listed `→ code-quality §4`.

## AL-HO-CQ-c — "Same time tomorrow" adds 24 hours in a store's DST zone

```defect
id:       AL-HO-CQ-c
file:     api/src/schedules/next-slot.ts
line:     8
severity: medium
command:  /quality-audit
class:    CQ §6 calendar arithmetic
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §6 (routed from /analyze-complexity)
anchor:   const next = new Date(slot.startsAt.getTime() + 24 * 60 * 60 * 1000);
match:    sameTimeTomorrow|24 \* 60 \* 60|getTime
match:    DST|daylight|time.?zone|calendar|23|25|hour
```

On the New Zealand DST change days the result is an hour off the store's slot. Date arithmetic is code-quality's; listed `→ code-quality §6`.

## AL-HO-CQ-d — Courier commission is computed in floats and truncated

```defect
id:       AL-HO-CQ-d
file:     analytics/payouts/commission.py
line:     16
severity: medium
command:  /quality-audit
class:    CQ §4 float money
owner:    code-quality
bucket:   routed
detector: code-quality correctness-smell-scan §4 (routed from /analyze-complexity)
anchor:   commission = float(order.total) * 0.035
match:    commission|float\(order\.total\)|0\.035
match:    float|Decimal|money|precision|int\(|truncat|rounding
```

Money through `float` and `int()` truncation loses a cent on many orders. Money arithmetic is code-quality's (numeric-stability-scan § Boundaries, precedent § 37); listed `→ code-quality §4`.

## AL-HO-SEC-a — The public SKU search validates `q` with a nested-quantifier regex

```defect
id:       AL-HO-SEC-a
file:     api/src/search/sku-filter.ts
line:     10
severity: high
command:  /security-audit
class:    SEC injection-scan §13 ReDoS
owner:    security
bucket:   routed
detector: security injection-scan §13 (routed from /analyze-complexity)
anchor:   if (!/^(\w+\s?)*$/.test(req.query.q ?? '')) {
match:    \(\\w\+\\s\?\)\*|sku-filter|req\.query\.q|search
match:    ReDoS|backtrack|catastroph|nested quantifier|regex|exponential
```

`(\w+\s?)*` backtracks exponentially on a long word followed by `!`; an unauthenticated request pins the event loop. ReDoS is security's (complexity-scan § Boundaries); listed `→ security injection-scan §13`.

## AL-HO-SEC-b — Login codes come from `Math.random()`

```defect
id:       AL-HO-SEC-b
file:     api/src/auth/otp.service.ts
line:     11
severity: high
command:  /security-audit
class:    SEC sast-scan CWE-338
owner:    security
bucket:   routed
detector: security sast-scan CWE-338 (routed from /analyze-complexity)
anchor:   const code = String(Math.floor(Math.random() * 1e6)).padStart(6, '0');
match:    Math\.random|otp|issue|code
match:    CWE-338|predictable|crypto|randomInt|CSPRNG|secure random
```

A predictable generator for an authentication secret is CWE-338, security's class (algorithm-contract-scan § Boundaries); the range itself is uniform. Listed `→ security sast-scan`.

## AL-HO-PF-a — The SKU pattern is compiled on every validation call

```defect
id:       AL-HO-PF-a
file:     ranking/src/main/java/com/kestrelway/ranking/validation/SkuValidator.java
line:     11
severity: low
command:  /perf-audit
class:    PERF request-path-scan §8 per-call construction
owner:    performance
bucket:   routed
detector: performance request-path-scan §8 (routed from /analyze-complexity)
anchor:   Pattern pattern = Pattern.compile(SKU);
match:    Pattern\.compile|SkuValidator|validate
match:    per (call|request)|compile once|static final|hoist|construct
```

One compile per request, not per loop iteration: per-call construction is performance's (complexity-scan § Boundaries, CX-4 is the in-loop case). Listed `→ performance request-path-scan §8`.

## AL-HO-DB-a — Order history pages with `LIMIT/OFFSET` on a non-unique sort key

```defect
id:       AL-HO-DB-a
file:     api/src/orders/order-history.repository.ts
line:     22
severity: medium
command:  /db-audit
class:    DB query-shape-scan deep OFFSET
owner:    database
bucket:   routed
detector: database query-shape-scan (routed from /analyze-complexity)
anchor:   ORDER BY created_at DESC LIMIT ? OFFSET ?
match:    OFFSET|order-history|created_at|page
match:    OFFSET|keyset|deep pag|seek|non-unique|tie|cursor
```

Deep `OFFSET` scans and discards every earlier row, and `created_at` ties reorder between pages. Both are database's (algorithm-contract-scan § Boundaries); listed `→ database query-shape-scan`.

## Decoys — must NOT be reported

Each mirrors a precedent in `templates/snippets/precedents/algorithms.md` (the class line names it); each sits in its own file. Reporting one is a false positive in every run its `command:` names.

```decoy
id:       AL-DECOY-01
file:     api/src/couriers/poll-statuses.job.ts
line:     21
command:  /analyze-complexity
class:    decoy/CX-1 (precedents/algorithms.md § 1)
anchor:   const closing = open.filter((s) => finished.includes(s.carrierRef));
match:    finished\.includes|poll|closing|OPEN_MAX
match:    linear|O\(n\s*[·*x×]\s*m\)|quadratic|Set|includes
```

Both lists are read with `limit: OPEN_MAX` (800): ≤ 640,000 comparisons per 30-second tick, below the per-request budget. algo-sites prints it `below-budget` with `limit:OPEN_MAX` on both sides.

```decoy
id:       AL-DECOY-02
file:     api/src/common/bulkhead.ts
line:     38
command:  /analyze-complexity
class:    decoy/CX-3 (§ 8)
anchor:   const next = this.waiting.shift()!;
match:    waiting\.shift|Bulkhead|release
match:    shift|O\(n\)|deque|head index|queue
```

The waiting list is capped by `maxWaiting` (`run` throws `BulkheadFullError` when full), so `shift()` moves at most that many elements: a bounded FIFO.

```decoy
id:       AL-DECOY-03
file:     api/src/webhooks/canonical-json.ts
line:     5
command:  /analyze-complexity
class:    decoy/RC-1 (§ 12)
anchor:   export function canonical(v: unknown): unknown {
match:    canonical|recurs|webhook
match:    depth|recurs|stack|RangeError|cap|cycle
```

Recursion over a `JSON.parse`d webhook body: no cycle is possible, and the 1 MiB Fastify `bodyLimit` (grep 0b) bounds the depth; a `RangeError` fails that one request.

```decoy
id:       AL-DECOY-04
file:     api/src/logging/redact.ts
line:     8
command:  /analyze-complexity
class:    decoy/RC-1 (§ 13)
anchor:   export function redact(value: unknown, depth = 0, ancestors: Set<object> = new Set()): unknown {
match:    redact|MAX_DEPTH|ancestors
match:    depth|cycle|recurs|stack|visited
```

The walker caps depth at `MAX_DEPTH` and tracks ancestors (added on enter, deleted on exit): the RC-1/RC-2 GOOD block.

```decoy
id:       AL-DECOY-05
file:     web/src/accounts/flatten-tree.ts
line:     24
command:  /analyze-complexity
class:    decoy/RC-2 (§ 14)
anchor:   const visit = (parentId: string | null, depth: number): void => {
match:    visit|parentId|flattenAccountTree
match:    cycle|visited|loop|infinite|recurs
```

A root-down walk from `parentId = null` through a children map can never enter a cycle (a node on a cycle is never a child of a reachable node); orphans are simply not shown.

```decoy
id:       AL-DECOY-06
file:     api/src/maintenance/project-every.ts
line:     10
command:  /analyze-complexity
class:    decoy/RC-4 (§ 15)
anchor:   for (;;) {
match:    projectEveryProduct|lastId|\$gt|for ?\(;;\)
match:    stall|never|infinite|strict|unique|keyset
```

Keyset on the unique primary key with strict `$gt` and a short-page exit (`rows.length < PAGE`): terminates and reads each row once.

```decoy
id:       AL-DECOY-07
file:     api/src/referrals/referral-code.ts
line:     11
command:  /analyze-complexity /security-audit
class:    decoy/RD-2 (§ 23)
anchor:   const k = crypto.randomInt(0, ALPHABET.length);
match:    randomInt|ALPHABET|referral
match:    bias|modulo|range|uniform|predictable|Math\.random
```

`crypto.randomInt(0, n)` is uniform over `[0, n)` and unpredictable; `ALPHABET.length` is exactly the index range.

```decoy
id:       AL-DECOY-08
file:     api/src/customers/customer-index.ts
line:     14
command:  /analyze-complexity
class:    decoy/OC-3 (§ 20)
anchor:   return new Map(rows.map((c) => [c.phoneKey, c]));
match:    phoneKey|customerIndex|new Map
match:    collaps|duplicate|unique|overwrit|lost
```

`UNIQUE (tenant_id, phone_key)` (`0003_customers.sql`) and the query filters one tenant: two rows cannot share the key.

```decoy
id:       AL-DECOY-09
file:     api/test/fuzz/stock-sequences.fuzz-spec.ts
line:     24
command:  /analyze-complexity
class:    decoy/RD-1 (§ 27, § 22)
anchor:   const corpus = SEED_CORPUS.slice().sort(() => rng() - 0.5);
match:    SEED_CORPUS|rng\(\) - 0\.5|fuzz
match:    bias|shuffle|Fisher|uniform|fast-check|harness
```

The project's own seeded, shrinking fuzzer reorders its seed corpus; fairness is irrelevant in a test harness (§ 22), and the harness is the property-test home (§ 27) — no third-party harness is proposed beside it.

```decoy
id:       AL-DECOY-10
file:     geo/sku_match.go
line:     6
command:  /analyze-complexity /security-audit
class:    decoy/CX-4 (§ 10)
anchor:   var skuRe = regexp.MustCompile(
match:    skuRe|MustCompile|ValidSKUs
match:    compile|per iteration|ReDoS|backtrack|hoist
```

Compiled once at package level and only matched in the loop; Go's `regexp` is RE2 (linear), so the nested quantifier is not a ReDoS either.

```decoy
id:       AL-DECOY-11
file:     analytics/clean/normalise.py
line:     10
command:  /analyze-complexity /perf-audit
class:    decoy/CX-4 (§ 9)
anchor:   spaces = re.compile(PATTERN)
match:    re\.compile|normalise_names|PATTERN
match:    compile|per iteration|hoist|invariant
```

`PATTERN` is a module constant and CPython's `re` caches compiled patterns: the call in the loop is a cache lookup.

```decoy
id:       AL-DECOY-12
file:     geo/rank_stable.go
line:     14
command:  /analyze-complexity
class:    decoy/OC-2 (§ 19)
anchor:   sort.Slice(rows, func(i, j int) bool {
match:    RankStores|sort\.Slice|Score
match:    stab(le|ility)|tie|SliceStable|equal
```

The comparator falls back to the unique store id on equal scores: a total order, so an unstable sort has no ties to reorder.

## Pre-flight measured (staged copy, ROOTS=(api/src web/src analytics geo ranking/src/main))

Measured 2026-10-19 on a copy staged the way `run.sh` stages it (the tree minus this key), from the copy's root, with each
detector's `## Pre-flight` bash block extracted verbatim from its `SKILL.md` and run under
`ROOTS=(api/src web/src analytics geo ranking/src/main)`, `ALGO_SITES` pointed at
`templates/packs/algorithms/skills/complexity-scan/scripts/algo-sites.py`, and `TMPDIR` outside the copy. Nothing was
written into the copy (`find -newer` on a stamp: 0 files). File counts per lane: ts 57, py 22, go 9, java 11, every other
lane 0. **No `rg` exit 2 in any block; all three blocks exit 0.** These are the detectors' raw rows, not an
`/analyze-complexity` result.

- **`complexity-scan`** — 0.6 s. Hits by grep: 0a 0 (rc 1: no analyzer pins), 0b 1 (the Fastify `bodyLimit`), 1a–1h 0,
  2a 1, 2b 0, 2c 1, 2d–2e 0, 3 0, 4 1, 5 1, 6 2, 7a 1, 7c 0, 7b 0, 8 1, 9a 1, 9b–9c 0, 10 1; `algo-sites.py` exit 0 twice
  (79 JS/TS + Python files scanned; Go 9 and JVM 11 counted, not parsed). `sites.tsv` 11 rows — uncapped 9, below-budget 1,
  set 1 (the `option in out_of_stock` frozenset in `bundles.py:15`); `rec.tsv` 9 rows — RC-1? 1, RC-2? 2, RC-3? 2, read 1,
  guarded 1, json-tree 1, keyset 1. The awk lines print 9 site rows and 6 recursion/loop rows.
- **`algorithm-contract-scan`** — 0.3 s. 0a 0 (rc 1), 0b 2 (PostGIS extension, `geometry(Point, 4326)`), 1a 2, 1b 0, 2 3,
  3a 2, 3b 0 (rc 1: no id-keyed `new Map`), 3c 1, 4 2, 5 2, 6a 2, 6b 5, 7 2, 8a 1, 8b 0, 8c 0, 8d 2, 9 2, 10 2.
- **`numeric-stability-scan`** — 0.1 s. G1 4 manifest lines (numpy, pandas, numba, simple-statistics); **G2 7 numeric
  files** (`stats.ts`, `softmax.py`, `fast_kernels.py`, `gmv_rollup.py`, `delivery_variance.py`, `eta_solver.py`,
  `demand_fit.py`; no file without a numeric seed or kernel passes the gate). 1a 4, 1b 1, 1c 0, 1d 0, 2 4, 3 2, 4 2, 4b 0
  (no file computes `cond`, calls `lstsq` or bounds iterations), 5 2, 6 10, 7a 4 sketch files, 7b 2.

**Every algorithms seed is printed by its owning lane: 54 of 54**, 47 at the anchor line and 7 within six lines of it
(the function head of two recursions, the loop head of two cursor loops and of the binary search, the class line of the
heap, the `def` of the shuffle). Routed rows: `AL-HO-SEC-b` prints in contract 6b (every `Math.random()`); the other seven are other packs' shapes
no algorithms line looks for — the owners' pre-flights were not run in this pass.

Decoys: 6 of 12 print where `/analyze-complexity` reads first — 02 and 05 in the awk lines (`uncapped`, `RC-2?`), 07, 08
and 12 in contract 6b / 3a / 2, and 01 as a `below-budget` row of `sites.tsv`; 03, 04 and 06 are rows of `rec.tsv` the awk
does not print (`json-tree`, `guarded`, `keyset`); 09, 10 and 11 print nowhere (a test path; a method call on a
package-level regex; a Python `re.compile`, which no lane reads). Each printed one is cleared by its precedent at the read.

What the run found in the detectors: the three gaps named under Departures (fixed, probes above), and two blind spots
that stay by design:
- **No Python lane for CX-4 regex construction** (precedent § 9 makes most of them safe, but `re.compile(pattern_param)`
  in a loop is invisible), and **complexity 4 misses a precompiled regex's `MatchString` in a loop** by design (decoy 10).
- Noise rows the read clears: the CX-1 row `rate-card.service.ts:32` (`sorted.find`) sits on AL-CX4-a's per-order copy;
  numeric 1a prints `delivery_variance.py:18` and `fast_kernels.py:14` (running sums inside the NS-2 and NS-5 seeds'
  functions); 6b prints `new Random()` (`WeightedPicker.java:11`) and the OTP; 6 prints the `pyprobables` manifest line and
  the `CountMinSketch` import.

| id | printed by |
|----|------------|
| AL-CX1-a | sites.tsv `order-export.service.ts:25` CX-1 `ids` (array?, `param`) · uncapped — printed |
| AL-CX1-b | sites.tsv `affinity.py:23` CX-1 `seen_skus` (list) · uncapped — printed |
| AL-CX2-a | complexity 2a `price-index.service.ts:16`; sites.tsv CX-2 `acc` (accumulator, grows) · uncapped — printed |
| AL-CX2-b | complexity 2c `FeedExporter.java:20` — printed |
| AL-CX3-a | sites.tsv `zone-graph.service.ts:31` CX-3 `queue` (list, grows) · uncapped — printed |
| AL-CX3-b | sites.tsv `worklist.py:27` CX-3 `pending.pop(0)` (list, grows) · uncapped — printed |
| AL-CX4-a | sites.tsv `rate-card.service.ts:31` CX-4 `rates.slice() · sort` · uncapped — printed (the `sorted.find` on :32 prints as a CX-1 row too) |
| AL-CX4-b | complexity 4 `address_normalize.go:13` — printed |
| AL-CX5-a | sites.tsv `team-report.service.ts:28` CX-1 `members` (array?) · uncapped — printed (the script files a `filter` inside a `map` as CX-1 on the inner receiver, § 5) |
| AL-CX5-b | complexity 5 `assign.go:11` — printed |
| AL-CX6-a | complexity 6 `variant-matrix.ts:12` — printed |
| AL-CX6-b | complexity 6 `bundles.py:19` — printed |
| AL-RC1-a | rec.tsv `comment-thread.renderer.ts:20` RC-1 `renderThread` walks=replies · RC-1? — printed |
| AL-RC1-b | complexity 9a `zone_tree.go:13` — printed |
| AL-RC2-a | rec.tsv `category-path.ts:7` RC-2 `rootOf` walks=parent · RC-2? — printed; complexity 8 `0001_init.sql:13` prints the self-referencing key |
| AL-RC2-b | complexity 7a `category-paths.repository.ts:11`; 7b prints no `CYCLE`/depth bound; 8 `0001_init.sql:13` — printed |
| AL-RC3-a | rec.tsv `route-count.ts:7` RC-3 `legPlans` calls=2 · RC-3? — printed |
| AL-RC3-b | rec.tsv `split_cost.py:7` RC-3 `best_split` calls=2 · RC-3? — printed |
| AL-RC4-a | rec.tsv `order-sync.job.ts:23` RC-4 `for(;;)` progress=last, non-strict, short-page=no · read — printed |
| AL-RC4-b | complexity 10 `ScoreBackfill.java:21` (`while (true)`) — printed |
| AL-OC1-a | contract 1a `weight-band.ts:19` — printed |
| AL-OC1-b | contract 1a `daily_sales.py:26` — printed |
| AL-OC2-a | contract 2 `dispatch_rank.go:18` — printed |
| AL-OC2-b | contract 2 `leaderboard.go:18` — printed |
| AL-OC3-a | contract 3a `pick-board.service.ts:42` — printed |
| AL-OC3-b | contract 3c `ShelfRanker.java:15` — printed |
| AL-OC4-a | contract 4 `tier-lookup.ts:13` (`while (lo < hi)`) — printed |
| AL-OC4-b | contract 4 `MinHeap.java:8` (`class MinHeap`) — printed |
| AL-RD1-a | contract 5 `raffle.service.ts:18`; 6b lists the `Math.random()` — printed |
| AL-RD1-b | contract 5 `shuffle_entrants.py:5` (`def shuffle_entrants`) — printed |
| AL-RD2-a | contract 6a `audit-sampler.ts:15`; 6b — printed |
| AL-RD2-b | contract 6a `WeightedPicker.java:18`; 6b lists `new Random()` (:11) — printed |
| AL-RD3-a | contract 7 `ExperimentBucket.java:13` — printed |
| AL-RD3-b | contract 7 `assign.py:7` — printed |
| AL-GE1-a | contract 8a `delivery-radius.ts:10` — printed |
| AL-GE1-b | contract 8d `nearby-stores.repository.ts:20`; 0b prints `geometry(Point, 4326)` (`0002_stores_geo.sql:3`) — printed |
| AL-GE2-a | contract 9 `store-location.repository.ts:18`; 8d prints the same line — printed |
| AL-GE2-b | contract 9 `geojson_export.py:30` — printed |
| AL-GE3-a | contract 10 `service-area.ts:16` — printed |
| AL-GE3-b | contract 10 `bbox_query.go:17` — printed |
| AL-NS1-a | numeric 1a `gmv_rollup.py:27`; G2 lists the file — printed |
| AL-NS1-b | numeric 1b `stats.ts:10`; 1a prints the `+=` (:12) — printed |
| AL-NS2-a | numeric 2 `delivery_variance.py:20` (and :16, :19) — printed |
| AL-NS2-b | numeric 2 `stats.ts:30` — printed |
| AL-NS3-a | numeric 3 `softmax.py:7` — printed |
| AL-NS3-b | numeric 3 `stats.ts:40` — printed |
| AL-NS4-a | numeric 4 `demand_fit.py:12`; 4b lists no `cond`/`lstsq` — printed |
| AL-NS4-b | numeric 4 `eta_solver.py:12`; 4b lists no max-iteration guard — printed |
| AL-NS5-a | numeric 5 `setup.py:7` — printed |
| AL-NS5-b | numeric 5 `fast_kernels.py:6` — printed |
| AL-SL1-a | numeric 6 `seen-products.ts:19` — printed |
| AL-SL1-b | numeric 6 `heavy_hitters.py:8` (and the import :2) — printed |
| AL-SL2-a | numeric 6 `charge-dedupe.service.ts:20`; 7b prints the same line (`already`) — printed |
| AL-SL2-b | numeric 6 `unique_seats.py:13`; 7b lists the file — printed |
| AL-HO-CQ-a | not printed by an algorithms grep (float `==` is outside NS) |
| AL-HO-CQ-b | not printed by an algorithms grep |
| AL-HO-CQ-c | not printed by an algorithms grep |
| AL-HO-CQ-d | not printed (not a numeric-gate file: no numeric import) |
| AL-HO-SEC-a | not printed by an algorithms grep |
| AL-HO-SEC-b | contract 6b `otp.service.ts:11` (the read routes it; 6a does not print it) |
| AL-HO-PF-a | not printed (complexity 4 needs a loop head within 8 lines; there is none) |
| AL-HO-DB-a | not printed by an algorithms grep |
| AL-DECOY-01 | sites.tsv `poll-statuses.job.ts:21` CX-1 `finished` · below-budget (640000, limit:OPEN_MAX × limit:OPEN_MAX) |
| AL-DECOY-02 | awk-printed sites row `bulkhead.ts:38` CX-3 `this.waiting` · uncapped (the cap is an options field the script cannot resolve) |
| AL-DECOY-03 | rec.tsv `canonical-json.ts:5` RC-1 `canonical` walks=json · json-tree (not in the awk print) |
| AL-DECOY-04 | rec.tsv `redact.ts:8` RC-1 `redact` depth=yes cycle=yes · guarded (not in the awk print) |
| AL-DECOY-05 | awk-printed rec row `flatten-tree.ts:24` RC-2 `visit` walks=parentId · RC-2? |
| AL-DECOY-06 | rec.tsv `project-every.ts:10` RC-4 progress=lastId, strict, short-page=yes · keyset (not in the awk print) |
| AL-DECOY-07 | contract 6b `referral-code.ts:11` (the trailing comment names `Math.random()`) |
| AL-DECOY-08 | contract 3a `customer-index.ts:14` |
| AL-DECOY-09 | not printed (test path and `*.fuzz-spec.*` are excluded by every grep and by algo-sites) |
| AL-DECOY-10 | not printed (complexity 4 matches `regexp.MustCompile|Compile|MatchString(` within 8 lines of a loop head; `skuRe.MatchString` is a method call) |
| AL-DECOY-11 | not printed (algo-sites' Python CX-4 reads `.sort`/`sorted`/`deepcopy`/`set`; grep 4 has no Python lane) |
| AL-DECOY-12 | contract 2 `rank_stable.go:14` |
