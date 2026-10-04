# orders-service

Orders API (Express + Postgres via `src/db.ts`) and the back-office web screens (`web/src/`).

- Money is integer cents everywhere (`*_cents` columns, `number` cents in TypeScript).
- Every route handler is wrapped in `metrics.timer('<route>')` and logs through `src/lib/logger.ts`
  with ids only — never request bodies (they carry customer email and address).
- List endpoints paginate: `page` is 1-based, `pageSize` is clamped to 100.
- Migrations run on deploy against a populated database (orders: ~40M rows).
