# @tallyhook/api

The NestJS service behind the Tallyhook HTTP API, and the `tallyhook` operator CLI.

The entry point is `src/main.ts`; every area is a module under `src/<area>/`.
Copy `.env.example` to `.env` before the first run; the [configuration reference](../../docs/config.md) lists every variable.

## Modules

- `src/orders` - orders, listing and cancellation.
- `src/invoices` - invoices and their PDFs.
- `src/webhooks` - endpoints and the delivery worker.
- `src/reports` - the monthly report and the nightly job.
- `src/accounting` - ledger entries for paid invoices.
- `src/cli` - the `tallyhook` operator CLI.

## Running locally

```bash
cd apps/api
yarn start:dev
```

The worker runs from the same build with `pnpm --filter @tallyhook/api start:worker`.

## Importing orders

```bash
tallyhook import orders.csv --dry-run
tallyhook import orders.csv --legacy-import
```

The first command validates the file; the second imports a file exported by the previous billing
system, mapping its column names.

## Cancelling in bulk

Bulk cancellation goes through `ordersService.cancelAll()`, which cancels every unpaid order of a
merchant in one transaction.
