# Reports

Monthly totals per currency come from `GET /reports/monthly`, as JSON or as CSV with
`format=csv`. The nightly job builds the previous day's totals at 02:15 UTC.

## Backfilling totals

After a data fix, recompute the totals of the affected days:

```bash
node scripts/backfill-totals.mjs --since 2026-01-01
```

Run it with the dry-run flag first on a large range: it prints what it would rewrite.
