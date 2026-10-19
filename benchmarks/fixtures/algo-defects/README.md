# Kestrelway

Grocery-and-courier marketplace. Merchants list their catalog, shoppers order, couriers deliver from
the nearest store inside the store's delivery radius.

| Path | What | Stack |
|---|---|---|
| `api/` | Public and merchant API | NestJS 11 on Fastify, MikroORM 6, Postgres 17 + PostGIS |
| `api/migrations/` | Schema, applied in order by the deploy job | SQL |
| `web/` | Merchant console utilities (variant matrix, chart of accounts) | React 19 |
| `analytics/` | Nightly and hourly analytics worker (GMV, delivery KPIs, forecasts, experiments) | Python 3.12, numpy, pandas, numba, redis |
| `geo/` | Courier routing and dispatch package, linked into the dispatcher binary | Go 1.23 |
| `ranking/` | Shelf and feed ranking module | Java 21, Maven |

## Markets

Kestrelway runs in New Zealand, Fiji and Samoa. Several merchants serve island groups whose service
area crosses the antimeridian (the Lau group and Taveuni in Fiji, the Chatham Islands for NZ
merchants), so a service area's west edge can be numerically greater than its east edge.

## Running

```
pnpm install
pnpm --filter api migrate && pnpm --filter api start:dev
cd analytics && pip install -e . && python -m analytics.worker
cd geo && go test ./...
cd ranking && mvn -q verify
```

The API body limit is 1 MiB (`api/src/main.ts`). Coordinates are stored as `geometry(Point, 4326)`
(lon, lat) in `stores.location`.

Property tests use the project's own shrinking fuzzer (`api/test/fuzz/`), not a third-party harness.
