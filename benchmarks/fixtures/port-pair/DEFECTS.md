# Seeded defects — `port-pair`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file, `change/` and `clean-overlay/`
from the copy first — an agent that reads them will score 100% and the number will mean nothing.

Fixture shape: `Norrow Supply` — one B2B wholesale portal mid-port, twice: a Laravel 11 V1 (`v1/`: Sanctum, spatie permission and activitylog, FormRequests, PHP enums, observers, global scopes, SoftDeletes, `decimal:2` casts, a MySQL trigger, finance views, `routes/console.php` schedules, `trans_choice`) and a NestJS 11 / Fastify + MikroORM 6 + BullMQ + React + zod-contracts V2 (`v2/`: `APP_GUARD` + `@Public()`, zod param pipes, subscribers, backfill and sync scripts, an nginx façade, Istio mirrors, pgloader loads, cutover flags, CI), with the `ai/migration` ledger, contracts, ADRs, `pair-map.tsv` and a recorded `v1-inventory/`; 92 seeds across all 48 migration classes and 36 decoys.

Invocation: /compare-v1 --whole-repo --v1=v1 --v2=v2 --mig=ai/migration --runs=.refract-fixture/runtime
Invocation[/security-audit]: /security-audit
Invocation[/backend-audit]: /backend-audit --whole-repo
Invocation[/frontend-audit]: /frontend-audit --whole-repo --classes=i18n
Invocation[/db-audit]: /db-audit
Invocation[/test-audit]: /test-audit --whole-repo
Stage with: --git --diff — the fixture root (minus `change/`, `clean-overlay/` and this key) is committed as the base;
`change/` is laid over it as the uncommitted port PR (a new `credit-note.ts`, a skipped V1-pinned case, a re-recorded
golden), so `parity-proof-scan` §1 sees one diff, the way a port PR is reviewed.
Pin: v1=61cb5c927438bcbf4b971b17938abe99c70b70f8

Eval source: Track A batch 6, items 28–29 (`eval-batch6-migration.md` § 4.12, § 2 class map, § 3.4 modes). Classes
follow the eval's 48 ids; detector §s follow the eval's design (SP §1–§9, SM §1–§10, SE §1–§5, DC §1–§12, CR §1–§4,
PF §1–§5) — the migration detectors are being built in parallel, so a § that moves at build time is renumbered here,
never re-seeded.

**Two anchors per seed.** Every ```defect block names the V2 line (`file`/`line`/`anchor`: where the finding is
reported and the fix lands) and the V1 line it differs from (`v1_file`/`v1_line`/`v1_anchor`). `run.sh --verify`
checks both: a seed whose V1 evidence moved is drift exactly like one whose V2 line moved.

**The clean pair.** Every seed is one edit away from a parity-clean twin: `clean:` is the text that replaces the
anchor (`\n` is a newline, `(delete line)` removes the line); `clean_add:` names a file the twin also has, kept under
`clean-overlay/` (two ADRs that record an intentional break). `bash benchmarks/run.sh --fixture=port-pair --clean-pair`
materialises it (base + `change/` + every `clean:` + `clean-overlay/`), and `--verify` derives it in a scratch copy
on every run. With the decoys' `pair-map.tsv` rows, the clean pair is the calibration pair: each static lane must diff
it to 0 rows, or the lane is asymmetric and prints `blocked` (eval § 3.1).

**The pin.** V1 has no history here: the ledger's `v1_commit_pinned` and every recorded inventory header's `sha` are
the git tree hash of `v1/` (`Pin:` above; `--verify` recomputes it, so any V1 edit that is not re-recorded fails).
The deliberate exceptions are the solo key's two faults: `I-ENUM.tsv` carries another `sha` (stale lane) and
`I-SCHED.tsv` an older extractor hash.

Ownership and scoring. Six runs, six results rows, each staged in its own copy. **`/compare-v1`** (the `Invocation:`
line) scores the 88 rows whose `command:` names it: the 42 migration-owned classes plus the two security-owned
classes it finds through the paired lane (MG-AZ-1, MG-AZ-3: those four rows name `/security-audit` too and count in
both runs). The 4 routed rows are scored **only under their owner** — `/backend-audit` (MG-MN-3),
`/frontend-audit` (MG-I18N-1), `/db-audit` (MG-TX-1), `/test-audit` (PP-5) — and `/compare-v1` must list each as routed,
never grade it; a `/compare-v1` finding on them is UNMATCHED. Each owner finds its row in V2 alone (a single-codebase
defect), which is why the owner, not migration, grades it.

No running app, no PHP, no database, no V1 boot. Every dynamic oracle (V358 replay, V359 matrix, V363 property run,
V371 journal, V375 reconciler drift, V386/V387 coverage, V388 CI log) reads the authored transcripts under
`.refract-fixture/runtime/` or prints `Unconfirmed` with the request written out, so the verdict is at best
`GO-UNVERIFIED` — expected, not a failure. The solo key (`port-pair-solo`) stages `v2/` and `ai/` only.

Departures from the eval, stated so a reader can audit them:
- **92 seeds, not 90.** § 4.12's table gives SM §5 two seeds for two classes (MG-STR-1, PP-4); "≥ 2 per class migration
  owns" needs two each, so SM has 16 + 3 routed. Every one of the 42 migration-owned classes has ≥ 2 seeds; each routed
  class (MG-MN-3, MG-I18N-1, MG-TX-1, PP-5) has one.
- **42 migration-owned classes, not 38.** The eval's headline counts 38 owned + 10 routed; its own § 2 rows name an
  owner outside migration for six ids (MG-AZ-1, MG-AZ-3 → security; MG-MN-3 → backend; MG-I18N-1 → frontend; MG-TX-1 →
  database; PP-5 → testing). This key follows the rows: 42 classes carry ≥ 2 `/compare-v1` seeds.
- **The PP-1 diff is an overlay on the fixture root.** The eval asks for `Stage with: --git --diff`; `review-decoys`
  keeps `base/` and `change/`. Here the base *is* the fixture root (so paths stay `v1/…`, `v2/…`, `ai/…`) and only the
  port PR lives under `change/`; `run.sh` gained that variant.
- **PP-3 twins add a file.** The clean twin of an unrecorded V1-bug fix is the same code *with* the record: the contract
  line plus an ADR, which `clean-overlay/` holds (never staged).
- **The routed `/frontend-audit` run is narrowed to `--classes=i18n`**, the only family it is scored on here.
- **`v2/deploy/` is `backend-other` in `_v2-anchors.md` `roots:`** — the per-root extension (eval item 2) is used as
  designed. A root takes one family kind (`frontend-*`, `backend-*`, `data-*`, `mobile-*`); `api-other` is a
  `project_kind` value only, and `validate-migration-artifacts.sh` fails it on a root. `project_kind: mixed` is kept for
  validators that read the single key.
- **The `Invocation:` line passes `--mig=ai/migration --runs=.refract-fixture/runtime`** (`/compare-v1`'s own flags): the
  side-by-side layout keeps `ai/` beside `v1/` and `v2/`, and the recorded oracle transcripts are read as `recorded`,
  never `measured`.

Secrets. None. Hosts are `*.norrow.internal` / `*.norrow.example`; credentials are environment references.

Line numbers are exact against the files in this directory and are re-checked by `benchmarks/run.sh --verify`, which
also fails if a decoy sits close enough to a defect in the same file for their scoring windows to overlap (every decoy
here is at least 13 lines from any seed in its file), if a V1 anchor moved, if the clean pair no longer derives, or if
`v1/` no longer hashes to the pin. If you edit fixture source, re-run it — and re-record `ai/migration/v1-inventory/`
when `v1/` changes.

## Summary

| id | file:line (V2) | V1 evidence | severity | command | class |
|----|----------------|-------------|----------|---------|-------|
| PX-RT1a | `v2/apps/api/src/orders/orders.controller.ts:45` | `v1/routes/api.php:27` | high | `/compare-v1` | MG-RT-1 surface/route-dropped |
| PX-RT1b | `v2/apps/api/src/invoices/invoices.controller.ts:21` | `v1/routes/api.php:33` | high | `/compare-v1` | MG-RT-1 surface/route-dropped |
| PX-RT2a | `v2/apps/api/src/common/pagination.ts:7` | `v1/app/Http/Controllers/OrderController.php:27` | high | `/compare-v1` | MG-RT-2 surface/path-query-shape |
| PX-RT2b | `v2/apps/api/src/fastify-options.ts:10` | `v1/app/Http/Controllers/OrderController.php:22` | high | `/compare-v1` | MG-RT-2 surface/path-query-shape |
| PX-AZ1a | `v2/apps/api/src/wallets/wallets.controller.ts:25` | `v1/routes/api.php:40` | critical | `/compare-v1 /security-audit` | MG-AZ-1 surface/authz-widened |
| PX-AZ1b | `v2/apps/api/src/users/users.controller.ts:22` | `v1/routes/api.php:62` | critical | `/compare-v1 /security-audit` | MG-AZ-1 surface/authz-widened |
| PX-AZ2a | `v2/apps/api/src/orders/orders.controller.ts:27` | `v1/routes/api.php:23` | medium | `/compare-v1` | MG-AZ-2 surface/authz-narrowed |
| PX-AZ2b | `v2/apps/api/src/tickets/tickets.controller.ts:40` | `v1/routes/api.php:54` | medium | `/compare-v1` | MG-AZ-2 surface/authz-narrowed |
| PX-AZ3a | `v2/apps/api/src/tickets/ticket.entity.ts:9` | `v1/app/Models/Ticket.php:16` | critical | `/compare-v1 /security-audit` | MG-AZ-3 surface/tenant-scope-lost |
| PX-AZ3b | `v2/apps/api/src/inventory/stock.repository.ts:21` | `v1/app/Models/StockItem.php:17` | critical | `/compare-v1 /security-audit` | MG-AZ-3 surface/tenant-scope-lost |
| PX-VO1a | `v2/packages/contracts/src/enums.ts:3` | `v1/app/Enums/OrderStatus.php:11` | high | `/compare-v1` | MG-VO-1 surface/enum-drift |
| PX-VO1b | `v2/packages/contracts/src/enums.ts:9` | `v1/app/Enums/TicketPriority.php:8` | high | `/compare-v1` | MG-VO-1 surface/enum-drift |
| PX-VA1a | `v2/apps/api/src/configure-app.ts:5` | `v1/bootstrap/app.php:20` | high | `/compare-v1` | MG-VA-1 surface/validation-drift |
| PX-VA1b | `v2/packages/contracts/src/orders.ts:17` | `v1/app/Http/Requests/StoreOrderRequest.php:17` | high | `/compare-v1` | MG-VA-1 surface/validation-drift |
| PX-ER1a | `v2/apps/api/src/orders/orders.service.ts:34` | `v1/app/Http/Controllers/OrderController.php:60` | high | `/compare-v1` | MG-ER-1 surface/error-contract-drift |
| PX-ER1b | `v2/apps/api/src/common/zod.ts:14` | `v1/tests/Feature/StoreOrderValidationTest.php:17` | medium | `/compare-v1` | MG-ER-1 surface/error-contract-drift |
| PX-SD1a | `v2/packages/contracts/src/common.ts:11` | `v1/app/Http/Controllers/OrderController.php:21` | medium | `/compare-v1` | MG-SD-1 surface/silent-default |
| PX-SD1b | `v2/apps/api/src/orders/order.entity.ts:32` | `v1/app/Models/Order.php:25` | high | `/compare-v1` | MG-SD-1 surface/silent-default |
| PX-MN1a | `change/v2/apps/api/src/invoices/credit-note.ts:5` | `v1/app/Services/PricingService.php:21` | high | `/compare-v1` | MG-MN-1 semantics/rounding-mode |
| PX-MN1b | `v2/apps/api/src/orders/pricing.ts:11` | `v1/app/Services/PricingService.php:16` | high | `/compare-v1` | MG-MN-1 semantics/rounding-mode |
| PX-MN2a | `v2/apps/api/src/invoices/invoice-totals.ts:12` | `v1/app/Services/InvoiceService.php:19` | high | `/compare-v1` | MG-MN-2 semantics/rounding-order |
| PX-MN2b | `v2/apps/api/src/wallets/installments.ts:5` | `v1/app/Support/Money.php:15` | high | `/compare-v1` | MG-MN-2 semantics/rounding-order |
| PX-MN3 | `v2/apps/api/src/invoices/invoice.mapper.ts:10` | `v1/app/Models/Invoice.php:24` | high | `/backend-audit` | MG-MN-3 backend/money-precision |
| PX-NUM1a | `v2/apps/api/src/tickets/sla.ts:8` | `v1/app/Services/SlaService.php:14` | medium | `/compare-v1` | MG-NUM-1 semantics/integer-division |
| PX-NUM1b | `v2/apps/api/src/inventory/stock.service.ts:33` | `v1/app/Services/StockService.php:27` | high | `/compare-v1` | MG-NUM-1 semantics/integer-division |
| PX-STR1a | `v2/apps/api/src/users/accounts.service.ts:11` | `v1/app/Http/Requests/UpdateAccountRequest.php:17` | medium | `/compare-v1` | MG-STR-1 semantics/string-semantics |
| PX-STR1b | `v2/apps/api/src/tickets/ticket-sms.ts:3` | `v1/app/Observers/TicketObserver.php:14` | medium | `/compare-v1` | MG-STR-1 semantics/string-semantics |
| PX-PP4a | `v2/apps/api/src/tickets/sla.ts:21` | `v1/app/Services/SlaService.php:27` | medium | `/compare-v1` | PP-4 semantics/library-lookalike |
| PX-PP4b | `v2/apps/api/src/inventory/csv-import.ts:9` | `v1/app/Services/CsvImportService.php:17` | medium | `/compare-v1` | PP-4 semantics/library-lookalike |
| PX-ORD1a | `v2/apps/api/src/orders/orders.service.ts:19` | `v1/app/Http/Controllers/OrderController.php:24` | high | `/compare-v1` | MG-ORD-1 semantics/ordering |
| PX-ORD1b | `v2/apps/api/src/tickets/ticket-assignment.ts:10` | `v1/app/Http/Controllers/TicketController.php:59` | high | `/compare-v1` | MG-ORD-1 semantics/ordering |
| PX-NULL1a | `v2/apps/api/src/tickets/ticket.mapper.ts:10` | `v1/app/Models/Ticket.php:54` | medium | `/compare-v1` | MG-NULL-1 semantics/null-empty-missing |
| PX-NULL1b | `v2/apps/api/src/orders/order.mapper.ts:13` | `v1/app/Models/Order.php:50` | medium | `/compare-v1` | MG-NULL-1 semantics/null-empty-missing |
| PX-TZ1a | `v2/apps/api/src/config/app.config.ts:4` | `v1/config/app.php:11` | high | `/compare-v1` | MG-TZ-1 semantics/timezone |
| PX-TZ1b | `v2/apps/api/src/reports/reports.service.ts:21` | `v1/app/Http/Controllers/ReportController.php:15` | medium | `/compare-v1` | MG-TZ-1 semantics/timezone |
| PX-I18N | `v2/apps/web/src/locales/ar/orders.json:8` | `v1/lang/ar/orders.php:4` | medium | `/frontend-audit` | MG-I18N-1 frontend/plural-forms |
| PX-TX | `v2/apps/api/src/inventory/stock-reservation.service.ts:11` | `v1/app/Services/StockService.php:13` | high | `/db-audit` | MG-TX-1 database/lock-dropped |
| PX-SE1a | `v2/apps/api/src/orders/order.subscriber.ts:15` | `v1/app/Observers/OrderObserver.php:21` | high | `/compare-v1` | MG-SE-1 effects/side-effect-dropped |
| PX-SE1b | `v2/apps/api/src/wallets/wallet-activity.subscriber.ts:15` | `v1/app/Models/Wallet.php:22` | high | `/compare-v1` | MG-SE-1 effects/side-effect-dropped |
| PX-SE2a | `v2/apps/api/src/orders/order.subscriber.ts:19` | `v1/app/Observers/OrderObserver.php:15` | high | `/compare-v1` | MG-SE-2 effects/side-effect-duplicated |
| PX-SE2b | `v2/apps/api/src/invoices/invoices.service.ts:48` | `v1/app/Services/InvoiceService.php:39` | high | `/compare-v1` | MG-SE-2 effects/side-effect-duplicated |
| PX-HC1a | `v2/apps/api/src/migrations/Migration20261001000000_reporting_views.ts:11` | `v1/database/migrations/2024_03_01_000007_create_finance_views.php:12` | high | `/compare-v1` | MG-HC-1 effects/hidden-consumer |
| PX-HC1b | `v2/apps/api/src/inventory/stock-feed.export.ts:16` | `v1/app/Console/Commands/ExportStockFeed.php:18` | high | `/compare-v1` | MG-HC-1 effects/hidden-consumer |
| PX-JB1a | `v2/apps/api/src/jobs/schedules.ts:13` | `v1/routes/console.php:9` | high | `/compare-v1` | MG-JB-1 effects/job-not-ported |
| PX-JB1b | `v2/apps/api/src/jobs/schedules.ts:11` | `v1/routes/console.php:11` | high | `/compare-v1` | MG-JB-1 effects/job-not-ported |
| PX-DM10a | `v2/apps/api/src/orders/order.entity.ts:43` | `v1/database/migrations/2024_01_01_000002_create_orders_tables.php:43` | high | `/compare-v1` | DM-10 effects/db-logic-not-reproduced |
| PX-DM10b | `v2/apps/api/src/migrations/.snapshot-norrow.json:238` | `v1/database/migrations/2024_01_01_000006_create_tickets_tables.php:29` | high | `/compare-v1` | DM-10 effects/db-logic-not-reproduced |
| PX-DM1a | `v2/scripts/backfill/tickets.backfill.ts:42` | `v1/database/migrations/2024_01_01_000006_create_tickets_tables.php:11` | high | `/compare-v1` | DM-1 cutover-data/backfill-not-resumable |
| PX-DM1b | `v2/scripts/backfill/users.backfill.ts:23` | `v1/database/migrations/2024_01_01_000001_create_accounts_and_users.php:19` | high | `/compare-v1` | DM-1 cutover-data/backfill-not-resumable |
| PX-DM2a | `v2/scripts/backfill/orders.backfill.ts:51` | `v1/app/Http/Controllers/OrderController.php:63` | high | `/compare-v1` | DM-2 cutover-data/backfill-overwrites-newer |
| PX-DM2b | `v2/scripts/backfill/wallets.backfill.ts:20` | `v1/app/Services/WalletService.php:16` | high | `/compare-v1` | DM-2 cutover-data/backfill-overwrites-newer |
| PX-DM3a | `v2/scripts/reconcile/validate.sh:17` | `v1/app/Models/User.php:21` | high | `/compare-v1` | DM-3 cutover-data/reconcile-masking |
| PX-DM3b | `v2/scripts/reconcile/validate.sh:14` | `v1/database/migrations/2024_01_01_000003_create_invoices_tables.php:20` | high | `/compare-v1` | DM-3 cutover-data/reconcile-masking |
| PX-DM4a | `v2/scripts/sync/invoice-sync.ts:7` | `v1/database/migrations/2024_01_01_000003_create_invoices_tables.php:22` | high | `/compare-v1` | DM-4 cutover-data/transform-mismatch |
| PX-DM4b | `v2/scripts/sync/user-sync.ts:6` | `v1/app/Models/User.php:21` | high | `/compare-v1` | DM-4 cutover-data/transform-mismatch |
| PX-DM5a | `v2/scripts/backfill/tickets.backfill.ts:27` | `v1/routes/web.php:13` | high | `/compare-v1` | DM-5 cutover-data/id-mapping-lost |
| PX-DM5b | `v2/scripts/backfill/invoices.backfill.ts:29` | `v1/app/Services/InvoiceService.php:31` | high | `/compare-v1` | DM-5 cutover-data/id-mapping-lost |
| PX-DM6a | `v2/deploy/pgloader/invoicing.load:12` | `v1/database/migrations/2024_01_01_000003_create_invoices_tables.php:35` | high | `/compare-v1` | DM-6 cutover-data/load-cast-drift |
| PX-DM6b | `v2/deploy/pgloader/ledger.load:9` | `v1/database/migrations/2024_01_01_000004_create_wallets_tables.php:28` | high | `/compare-v1` | DM-6 cutover-data/load-cast-drift |
| PX-DM7a | `v2/apps/api/src/orders/order.entity.ts:7` | `v1/app/Models/Order.php:19` | high | `/compare-v1` | DM-7 cutover-data/soft-delete-lost |
| PX-DM7b | `v2/apps/api/src/inventory/stock-item.entity.ts:8` | `v1/app/Services/CsvImportService.php:21` | medium | `/compare-v1` | DM-7 cutover-data/soft-delete-lost |
| PX-DM8a | `v2/scripts/backfill/preflight.ts:7` | `v1/database/migrations/2024_01_01_000002_create_orders_tables.php:32` | high | `/compare-v1` | DM-8 cutover-data/orphans-duplicates |
| PX-DM8b | `v2/scripts/backfill/users.backfill.ts:22` | `v1/database/migrations/2024_01_01_000001_create_accounts_and_users.php:24` | medium | `/compare-v1` | DM-8 cutover-data/orphans-duplicates |
| PX-DM9a | `v2/scripts/backfill/invoices.backfill.ts:46` | `v1/database/migrations/2024_01_01_000003_create_invoices_tables.php:11` | high | `/compare-v1` | DM-9 cutover-data/sequence-not-reset |
| PX-DM9b | `v2/deploy/pgloader/ledger.load:6` | `v1/database/migrations/2024_01_01_000004_create_wallets_tables.php:22` | high | `/compare-v1` | DM-9 cutover-data/sequence-not-reset |
| PX-DM11a | `v2/deploy/flags/cutover.yaml:28` | `v1/routes/api.php:30` | high | `/compare-v1` | DM-11 cutover-data/flip-not-gated |
| PX-DM11b | `v2/scripts/cutover/flip-writes.ts:6` | `v1/routes/api.php:25` | high | `/compare-v1` | DM-11 cutover-data/flip-not-gated |
| PX-DM12a | `ai/runbooks/cutover-wallets.md:10` | `v1/database/migrations/2024_01_01_000004_create_wallets_tables.php:11` | high | `/compare-v1` | DM-12 cutover-data/no-reverse-path |
| PX-DM12b | `v2/deploy/cutover/plan.yaml:6` | `v1/database/migrations/2024_01_01_000002_create_orders_tables.php:12` | high | `/compare-v1` | DM-12 cutover-data/no-reverse-path |
| PX-DM13a | `v2/scripts/backfill/state/orders.checkpoint.json:1` | `v1/database/migrations/2024_01_01_000002_create_orders_tables.php:20` | medium | `/compare-v1` | DM-13 cutover-data/mapping-changed-mid-window |
| PX-DM13b | `v2/scripts/backfill/state/stock.checkpoint.json:1` | `v1/database/migrations/2024_01_01_000005_create_stock_items_table.php:20` | medium | `/compare-v1` | DM-13 cutover-data/mapping-changed-mid-window |
| PX-CO1a | `v2/deploy/nginx/facade.conf:38` | `v1/routes/api.php:53` | high | `/compare-v1` | CO-1 cutover/facade-routing-gap |
| PX-CO1b | `v2/deploy/nginx/facade.conf:43` | `v1/routes/api.php:34` | high | `/compare-v1` | CO-1 cutover/facade-routing-gap |
| PX-CO2a | `v2/apps/api/src/common/session-cookie.ts:7` | `v1/config/session.php:13` | high | `/compare-v1` | CO-2 cutover/session-not-shared |
| PX-CO2b | `v2/apps/api/src/common/csrf.ts:4` | `v1/resources/js/http.js:6` | high | `/compare-v1` | CO-2 cutover/session-not-shared |
| PX-CO3a | `v2/deploy/istio/orders-mirror.yaml:12` | `v1/app/Observers/OrderObserver.php:13` | critical | `/compare-v1` | CO-3 cutover/shadow-not-isolated |
| PX-CO3b | `v2/deploy/shadow/v2-shadow.env:7` | `v1/.env.example:14` | critical | `/compare-v1` | CO-3 cutover/shadow-not-isolated |
| PX-CO5a | `v2/deploy/k8s/v1/queue-worker.yaml:9` | `v1/app/Jobs/ProcessInvoiceIssued.php:14` | high | `/compare-v1` | CO-5 cutover/not-reversible |
| PX-CO5b | `v2/deploy/k8s/v1/scheduler.yaml:10` | `v1/routes/console.php:13` | high | `/compare-v1` | CO-5 cutover/not-reversible |
| PX-PP1a | `change/v2/apps/api/test/parity/invoices.parity.spec.ts:26` | `v1/tests/Feature/InvoiceTotalsTest.php:22` | critical | `/compare-v1` | PP-1 proof/tests-modified |
| PX-PP1b | `change/v2/apps/api/test/parity/__golden__/invoice-totals.json:4` | `v1/tests/Feature/InvoiceTotalsTest.php:19` | critical | `/compare-v1` | PP-1 proof/tests-modified |
| PX-PP2a | `v2/apps/api/test/parity/corpus/pricing.corpus.json:4` | `v1/app/Services/PricingService.php:11` | high | `/compare-v1` | PP-2 proof/corpus-misses-v1-branches |
| PX-PP2b | `v2/apps/api/test/parity/corpus/sla.corpus.json:4` | `v1/app/Services/SlaService.php:16` | high | `/compare-v1` | PP-2 proof/corpus-misses-v1-branches |
| PX-PP3a | `ai/migration/contracts/invoices.md:20` | `v1/app/Models/Invoice.php:45` | medium | `/compare-v1` | PP-3 proof/v1-bug-unrecorded |
| PX-PP3b | `ai/migration/contracts/tickets.md:20` | `v1/app/Http/Controllers/TicketController.php:17` | medium | `/compare-v1` | PP-3 proof/v1-bug-unrecorded |
| PX-CO4a | `v2/apps/api/test/parity/tolerance.json:4` | `v1/app/Services/InvoiceService.php:34` | high | `/compare-v1` | CO-4 proof/comparator-blind-spot |
| PX-CO4b | `v2/apps/api/test/parity/tolerance.json:11` | `v1/app/Http/Controllers/TicketController.php:33` | high | `/compare-v1` | CO-4 proof/comparator-blind-spot |
| PX-PP5 | `v2/.github/workflows/ci.yml:60` | `v1/phpunit.xml:6` | high | `/test-audit` | PP-5 testing/v1-gated-suite-skipped |
| PX-UI1a | `v2/apps/web/src/nav.tsx:8` | `v1/resources/views/layouts/nav.blade.php:6` | medium | `/compare-v1` | MG-UI-1 ui/affordance-dropped |
| PX-UI1b | `v2/apps/web/src/pages/TicketDetailPage.tsx:36` | `v1/resources/views/portal/tickets/show.blade.php:11` | medium | `/compare-v1` | MG-UI-1 ui/affordance-dropped |
| PX-UI2a | `v2/apps/web/src/pages/OrdersPage.tsx:21` | `v1/resources/views/portal/orders.blade.php:7` | medium | `/compare-v1` | MG-UI-2 ui/state-drift |
| PX-UI2b | `v2/apps/web/src/pages/PlaceOrderPage.tsx:29` | `v1/resources/views/portal/orders/create.blade.php:6` | medium | `/compare-v1` | MG-UI-2 ui/state-drift |

Severity split: 8 critical · 61 high · 23 medium · 0 low. Total 92 seeded defects (88 under `/compare-v1`, 4 under `/security-audit`, 1 under `/backend-audit`, 1 under `/frontend-audit`, 1 under `/db-audit`, 1 under `/test-audit`; the four MG-AZ rows count in two runs), 36 decoys.

### Class coverage (the 48 ids)

| class | name | owner (graded by) | detector § | seeded | decoys |
|-------|------|-------------------|------------|--------|--------|
| MG-RT-1 | route / method dropped | migration | SP §1 | 2 (PX-RT1a, PX-RT1b) | PX-DECOY-01, PX-DECOY-02, PX-DECOY-23, PX-DECOY-24 |
| MG-RT-2 | path / query shape drift | migration | SP §2 | 2 (PX-RT2a, PX-RT2b) | — |
| MG-AZ-1 | permission widening | security (paired lane: migration) | SP §3 | 2 (PX-AZ1a, PX-AZ1b) | PX-DECOY-03, PX-DECOY-04, PX-DECOY-26 |
| MG-AZ-2 | permission narrowing | migration | SP §4 | 2 (PX-AZ2a, PX-AZ2b) | — |
| MG-AZ-3 | tenant / ownership scope lost | security (paired lane: migration) | SP §5 | 2 (PX-AZ3a, PX-AZ3b) | PX-DECOY-27, PX-DECOY-28 |
| MG-VO-1 | enum / vocabulary drift | migration | SP §6 | 2 (PX-VO1a, PX-VO1b) | PX-DECOY-06, PX-DECOY-07, PX-DECOY-21, PX-DECOY-29 |
| MG-VA-1 | validation rule drift | migration | SP §7 | 2 (PX-VA1a, PX-VA1b) | PX-DECOY-17, PX-DECOY-30 |
| MG-ER-1 | error status / code / envelope drift | migration | SP §8 | 2 (PX-ER1a, PX-ER1b) | PX-DECOY-05 |
| MG-SD-1 | silent defaults | migration | SP §9 | 2 (PX-SD1a, PX-SD1b) | — |
| MG-MN-1 | rounding mode drift | migration | SM §1 | 2 (PX-MN1a, PX-MN1b) | PX-DECOY-08, PX-DECOY-09, PX-DECOY-31 |
| MG-MN-2 | rounding order / allocation | migration | SM §2 | 2 (PX-MN2a, PX-MN2b) | — |
| MG-MN-3 | precision / type | backend (WF §1) | SM §3 → routed | 1 (PX-MN3) | — |
| MG-NUM-1 | integer division / modulo | migration | SM §4 | 2 (PX-NUM1a, PX-NUM1b) | — |
| MG-STR-1 | string semantics | migration | SM §5 | 2 (PX-STR1a, PX-STR1b) | — |
| PP-4 | library look-alike semantics | migration | SM §5 | 2 (PX-PP4a, PX-PP4b) | — |
| MG-ORD-1 | ordering drift | migration | SM §6 | 2 (PX-ORD1a, PX-ORD1b) | PX-DECOY-10 |
| MG-NULL-1 | null / empty / missing | migration | SM §7 | 2 (PX-NULL1a, PX-NULL1b) | — |
| MG-TZ-1 | time zone / date parse | migration | SM §8 | 2 (PX-TZ1a, PX-TZ1b) | — |
| MG-I18N-1 | plural / format / missing key | frontend (i18n-scan §3) | SM §9 → routed | 1 (PX-I18N) | PX-DECOY-22 |
| MG-TX-1 | transaction / isolation | database (transaction-scan §7) | SM §10 → routed | 1 (PX-TX) | — |
| MG-SE-1 | side effect dropped | migration | SE §1 | 2 (PX-SE1a, PX-SE1b) | PX-DECOY-11, PX-DECOY-12 |
| MG-SE-2 | side effect duplicated / reordered | migration | SE §2 | 2 (PX-SE2a, PX-SE2b) | — |
| MG-HC-1 | hidden consumer broken | migration | SE §3 | 2 (PX-HC1a, PX-HC1b) | — |
| MG-JB-1 | batch / cron / consumer not ported | migration | SE §4 | 2 (PX-JB1a, PX-JB1b) | PX-DECOY-13, PX-DECOY-32 |
| DM-10 | DB-side logic not reproduced | migration | SE §5 | 2 (PX-DM10a, PX-DM10b) | — |
| DM-1 | backfill not resumable / idempotent / throttled | migration | DC §1 | 2 (PX-DM1a, PX-DM1b) | PX-DECOY-14 |
| DM-2 | backfill overwrites newer rows | migration | DC §2 | 2 (PX-DM2a, PX-DM2b) | — |
| DM-3 | no or masking reconciliation | migration | DC §3 | 2 (PX-DM3a, PX-DM3b) | PX-DECOY-15 |
| DM-4 | backfill transform ≠ dual-write transform | migration | DC §4 | 2 (PX-DM4a, PX-DM4b) | — |
| DM-5 | ID mapping lost | migration | DC §5 | 2 (PX-DM5a, PX-DM5b) | — |
| DM-6 | type-cast drift on load | migration | DC §6 | 2 (PX-DM6a, PX-DM6b) | — |
| DM-7 | soft-delete semantics lost | migration | DC §7 | 2 (PX-DM7a, PX-DM7b) | PX-DECOY-16, PX-DECOY-33 |
| DM-8 | orphans / duplicates V1 tolerated | migration | DC §8 | 2 (PX-DM8a, PX-DM8b) | — |
| DM-9 | sequence / identity not reset | migration | DC §9 | 2 (PX-DM9a, PX-DM9b) | — |
| DM-11 | read flip not gated; write flip not fenced | migration | DC §10 | 2 (PX-DM11a, PX-DM11b) | PX-DECOY-35 |
| DM-12 | no reverse path; point of no return undeclared | migration | DC §11 | 2 (PX-DM12a, PX-DM12b) | PX-DECOY-36 |
| DM-13 | mapping changed mid-window | migration | DC §12 | 2 (PX-DM13a, PX-DM13b) | — |
| CO-1 | façade routing gap | migration | CR §1 | 2 (PX-CO1a, PX-CO1b) | — |
| CO-2 | session / auth / cookie not shared | migration | CR §2 | 2 (PX-CO2a, PX-CO2b) | — |
| CO-3 | shadow path not side-effect-isolated | migration | CR §3 | 2 (PX-CO3a, PX-CO3b) | PX-DECOY-18 |
| CO-4 | comparator blind spots | migration | PF §5 | 2 (PX-CO4a, PX-CO4b) | — |
| CO-5 | flag not reversible / V1 cold | migration | CR §4 | 2 (PX-CO5a, PX-CO5b) | — |
| PP-1 | tests modified / skipped / goldens re-recorded | migration | PF §1 | 2 (PX-PP1a, PX-PP1b) | PX-DECOY-19 |
| PP-2 | corpus misses V1 branches | migration | PF §2 | 2 (PX-PP2a, PX-PP2b) | — |
| PP-3 | V1 bug silently fixed / ported unrecorded | migration | PF §3 | 2 (PX-PP3a, PX-PP3b) | PX-DECOY-20 |
| PP-5 | V1-gated parity suite skipped | testing (suite-execution-scan §2c) | PF §4 → routed | 1 (PX-PP5) | PX-DECOY-25 |
| MG-UI-1 | UI affordance / nav leaf dropped | migration | parity-auditor Section 0 | 2 (PX-UI1a, PX-UI1b) | — |
| MG-UI-2 | UI state / lifecycle drift | migration | parity-auditor halt 12 | 2 (PX-UI2a, PX-UI2b) | PX-DECOY-34 |

### Solo expectations

`port-pair-solo` re-keys 29 of these seeds for a run that stages `v2/` + `ai/` only and reads V1 from
`ai/migration/v1-inventory/`: guarantee classes become Findings, drop classes `Unconfirmed-solo`, the stale `I-ENUM` lane
`Unconfirmed stale-v1-inventory`, the old-hash `I-SCHED` lane `blocked`, and the verdict is at most `GO-UNVERIFIED`.

## Surface contract (MG-RT/AZ/VO/VA/ER/SD)

### PX-RT1a — `POST /api/orders/{order}/duplicate` has no V2 route (the service method was ported, the handler was not)

```defect
id:        PX-RT1a
file:      v2/apps/api/src/orders/orders.controller.ts
line:      45
severity:  high
command:   /compare-v1
class:     surface/route-dropped
mg_class:  MG-RT-1
detector:  surface-parity-scan §1
anchor:    @Post(':id/cancel')
v1_file:   v1/routes/api.php
v1_line:   27
v1_anchor: Route::post('/{order}/duplicate', 'duplicate')->middleware('can:orders.create');
clean:     @Post(':id/duplicate')\n  @Permissions('orders:create', 'orders:view')\n  @HttpCode(201)\n  duplicate(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: AuthUser) {\n    return this.orders.duplicate(id, user);\n  }\n\n  @Post(':id/cancel')
match:     duplicat
match:     route|endpoint|handler|404|missing|dropped|not (?:ported|exposed|registered)|absent
```

V1 registers `POST /api/orders/{order}/duplicate` ("order again" in the portal and the mobile app). V2's `OrdersService.duplicate()` exists, but `OrdersController` exposes create, update and cancel only. The façade still sends order writes to V1, so the gap is invisible until the 2.4.0 write flip (`deploy/cutover/plan.yaml`) — after which every call 404s. Fix: the `@Post(':id/duplicate')` handler with `orders:create` and `orders:view` (V1's middleware plus its `authorize('view')`). Proof: V358 — replay the V1 route list against V2: not 404, same status class (`runtime/v358-route-replay.txt`).

### PX-RT1b — `GET /api/invoices/{invoice}/pdf` dropped: invoice reads moved to V2 without the PDF download

```defect
id:        PX-RT1b
file:      v2/apps/api/src/invoices/invoices.controller.ts
line:      21
severity:  high
command:   /compare-v1
class:     surface/route-dropped
mg_class:  MG-RT-1
detector:  surface-parity-scan §1
anchor:    @Post(':id/issue')
v1_file:   v1/routes/api.php
v1_line:   33
v1_anchor: Route::get('/{invoice}/pdf', 'pdf');
clean:     @Get(':id/pdf')\n  @Permissions('invoices:view')\n  pdf(@Param('id', ParseIntPipe) id: number) {\n    return this.invoices.renderPdf(id);\n  }\n\n  @Post(':id/issue')
match:     pdf
match:     route|endpoint|handler|404|missing|dropped|not (?:ported|exposed)|absent
```

V1 serves the invoice PDF at `GET /api/invoices/{invoice}/pdf`. The façade sends invoice GETs to V2 (`location /api/invoices`), and V2's controller has no `pdf` handler although `InvoicesService.renderPdf()` is ported, so every download link 404s since the read flip. Fix: the `@Get(':id/pdf')` handler. Proof: V358.

### PX-RT2a — Page base drift: `page` is 1-based in V1 (Laravel paginator) but V2 computes `offset = page * perPage`

```defect
id:        PX-RT2a
file:      v2/apps/api/src/common/pagination.ts
line:      7
severity:  high
command:   /compare-v1
class:     surface/path-query-shape
mg_class:  MG-RT-2
detector:  surface-parity-scan §2
anchor:    return page * perPage;
v1_file:   v1/app/Http/Controllers/OrderController.php
v1_line:   27
v1_anchor: ->paginate($perPage);
clean:     return (page - 1) * perPage;
match:     page|offset|paginat
match:     1-based|0-based|zero|first page|skip|off.by.one|page \* |base
```

Laravel's paginator is 1-based: `?page=1` is the first page. V2's `toOffset()` multiplies, so `page=1` returns rows 26–50 and the first page is unreachable on every list that uses it (orders, tickets). The contract's default `page` is 1, so even a request with no `page` skips a page. Fix: `(page - 1) * perPage`. Proof: V358 page 0/1/last+1 (`runtime/v358-route-replay.txt`, first row).

### PX-RT2b — Bracket arrays (`status[]=placed`) are no longer parsed: Fastify's default query parser leaves the key as `status[]` and the status filter is dropped

```defect
id:        PX-RT2b
file:      v2/apps/api/src/fastify-options.ts
line:      10
severity:  high
command:   /compare-v1
class:     surface/path-query-shape
mg_class:  MG-RT-2
detector:  surface-parity-scan §2
anchor:    bodyLimit: 2 * 1024 * 1024,
v1_file:   v1/app/Http/Controllers/OrderController.php
v1_line:   22
v1_anchor: $statuses = (array) $request->input('status', []);
clean:     bodyLimit: 2 * 1024 * 1024,\n  querystringParser: parseBracketQuery,
match:     status\[\]|bracket|array|query ?string|querystring|qs
match:     filter|pars|ignored|dropped|strip|every status
```

V1 clients (the mobile app, the partner integrations) send `?status[]=placed&status[]=packed`, which PHP parses into an array. Fastify's default query parser does not: the key arrives as `status[]`, `OrderListQuery` strips it as unknown, and the list returns every status. `parseBracketQuery` exists in the same file and is never registered. Fix: `querystringParser: parseBracketQuery`. Proof: V358, the array query in both syntaxes.

### PX-AZ1a — Wallet adjustment lost its permission: any signed-in user can credit or debit a wallet

```defect
id:        PX-AZ1a
file:      v2/apps/api/src/wallets/wallets.controller.ts
line:      25
severity:  critical
command:   /compare-v1 /security-audit
class:     surface/authz-widened
mg_class:  MG-AZ-1
detector:  surface-parity-scan §3 → security (@api-security-reviewer)
anchor:    @Post(':id/adjust')
v1_file:   v1/routes/api.php
v1_line:   40
v1_anchor: Route::post('/{wallet}/adjust', 'adjust')->middleware('permission:wallets.adjust');
clean:     @Post(':id/adjust')\n  @Permissions('wallets:adjust')
match:     adjust
match:     permission|authori[sz]|guard|wallets?[.:]adjust|any (?:signed|authenticated|logged)|widen
```

V1 gates `POST /wallets/{wallet}/adjust` with spatie `permission:wallets.adjust` (managers and admins). V2's handler carries no `@Permissions`, and the global `PermissionsGuard` allows a handler with no metadata, so a clerk can move money (`runtime/v359-authz-matrix.txt`: clerk 403 → 201). The sibling `credit-limit` handler kept the check. Fix: `@Permissions('wallets:adjust')`. Proof: V359 matrix, V2 ⊆ V1 per cell. Owner: security when installed (guarantee class: a Finding even in solo mode).

### PX-AZ1b — Role assignment moved out of the admin controller without `@Roles('admin')`: a manager can make themselves admin

```defect
id:        PX-AZ1b
file:      v2/apps/api/src/users/users.controller.ts
line:      22
severity:  critical
command:   /compare-v1 /security-audit
class:     surface/authz-widened
mg_class:  MG-AZ-1
detector:  surface-parity-scan §3 → security (@api-security-reviewer)
anchor:    @Put(':id/roles')
v1_file:   v1/routes/api.php
v1_line:   62
v1_anchor: Route::middleware('role:admin')->prefix('admin')->group(function () {
clean:     @Put(':id/roles')\n  @Roles('admin')
match:     roles?
match:     admin|privilege|escalat|authori[sz]|guard|widen|any (?:user|role)
```

In V1 `PUT /api/admin/users/{user}/roles` sits inside the `role:admin` group. The port split it into `UsersController`, which has no class-level `@Roles`; the `GET :id` beside it has `@Roles('admin')`, the `PUT` does not. Any authenticated user can grant any role, including `admin` (`runtime/v359-authz-matrix.txt`: manager 403 → 200). Fix: `@Roles('admin')` on the handler (or on the class). Proof: V359.

### PX-AZ2a — Order export now needs `orders:export`, a permission only managers hold: clerks lose the CSV

```defect
id:        PX-AZ2a
file:      v2/apps/api/src/orders/orders.controller.ts
line:      27
severity:  medium
command:   /compare-v1
class:     surface/authz-narrowed
mg_class:  MG-AZ-2
detector:  surface-parity-scan §4
anchor:    @Permissions('orders:export')
v1_file:   v1/routes/api.php
v1_line:   23
v1_anchor: Route::get('/export', 'export')->middleware('can:orders.view');
clean:     @Permissions('orders:view')
match:     export
match:     orders?[.:](?:export|view)|permission|narrow|locked out|403|clerk
```

V1 lets anyone with `orders.view` export. V2 asks for a new `orders:export`, which `permissions.seed.ts` grants to managers only, so every clerk who exported in V1 gets 403. No ADR names the change. Fix: `orders:view` (or an ADR plus a seed change). Proof: V359, V1 ⊆ V2.

### PX-AZ2b — Ticket update narrowed from `role:agent|admin` to admins only: support agents cannot update tickets

```defect
id:        PX-AZ2b
file:      v2/apps/api/src/tickets/tickets.controller.ts
line:      40
severity:  medium
command:   /compare-v1
class:     surface/authz-narrowed
mg_class:  MG-AZ-2
detector:  surface-parity-scan §4
anchor:    @Roles('admin')
v1_file:   v1/routes/api.php
v1_line:   54
v1_anchor: Route::patch('/tickets/{ticket}', [TicketController::class, 'update'])->middleware('role:agent|admin');
clean:     @Roles('agent', 'admin')
match:     ticket
match:     agent|narrow|role|403|locked out
```

V1 allows agents and admins to `PATCH /api/tickets/{ticket}`. V2's handler says `@Roles('admin')`; the `next` handler two methods above keeps `agent`. Tickets are V2-only, so support agents cannot change status or assignee since the flip. Fix: `@Roles('agent', 'admin')`. Proof: V359.

### PX-AZ3a — `Ticket` lost its account scope: ticket lists and lookups cross tenants

```defect
id:        PX-AZ3a
file:      v2/apps/api/src/tickets/ticket.entity.ts
line:      9
severity:  critical
command:   /compare-v1 /security-audit
class:     surface/tenant-scope-lost
mg_class:  MG-AZ-3
detector:  surface-parity-scan §5 → security (@tenant-isolation-reviewer)
anchor:    @Entity({ tableName: 'tickets' })
v1_file:   v1/app/Models/Ticket.php
v1_line:   16
v1_anchor: #[ScopedBy([AccountScope::class])]
clean:     @scoped.AccountScoped()\n@Entity({ tableName: 'tickets' })
match:     ticket
match:     account|tenant|scope|filter|cross
```

V1's `Ticket` carries `#[ScopedBy([AccountScope::class])]`, so every query adds `account_id = :user's account`. `Order`, `Invoice`, `Wallet` and `StockItem` carry `@scoped.AccountScoped()`; `Ticket` does not, and no repository predicate replaces it, so `GET /api/tickets` lists every account's tickets and `GET /api/tickets/{id}` opens any (`runtime/v359-authz-matrix.txt`). Fix: the `@scoped.AccountScoped()` decorator. Proof: V359 cross-tenant cell.

### PX-AZ3b — Raw `findBySku` query has no account predicate (the ORM filter does not apply to raw SQL): any SKU of any account is readable

```defect
id:        PX-AZ3b
file:      v2/apps/api/src/inventory/stock.repository.ts
line:      21
severity:  critical
command:   /compare-v1 /security-audit
class:     surface/tenant-scope-lost
mg_class:  MG-AZ-3
detector:  surface-parity-scan §5 → security (@tenant-isolation-reviewer)
anchor:    where sku = ? and deleted_at is null limit 1', [sku.trim().toUpperCase()]);
v1_file:   v1/app/Models/StockItem.php
v1_line:   17
v1_anchor: static::addGlobalScope('account', function (Builder $builder) {
clean:     where account_id = ? and sku = ? and deleted_at is null limit 1', [accountId, sku.trim().toUpperCase()]);
match:     findBySku|sku|stock
match:     account|tenant|scope|raw|predicate|cross
```

V1's `StockItem` adds the account in a `booted()` global scope. V2 reads `GET /api/stock/{sku}` through raw SQL in `StockRepository.findBySku`, which the MikroORM `account` filter never sees; the method takes `accountId` and does not use it, while `availability` and `lowStock` beside it do. Fix: `where account_id = ? and sku = ?`. Proof: V359 cross-tenant cell (manager of another account: 404 → 200).

### PX-VO1a — Order status `cancelled` became `canceled` on the wire and in storage

```defect
id:        PX-VO1a
file:      v2/packages/contracts/src/enums.ts
line:      3
severity:  high
command:   /compare-v1
class:     surface/enum-drift
mg_class:  MG-VO-1
detector:  surface-parity-scan §6
anchor:    export const ORDER_STATUSES = ['draft', 'placed', 'packed', 'shipped', 'canceled', 'refunded'] as const;
v1_file:   v1/app/Enums/OrderStatus.php
v1_line:   11
v1_anchor: case Cancelled = 'cancelled';
clean:     export const ORDER_STATUSES = ['draft', 'placed', 'packed', 'shipped', 'cancelled', 'refunded'] as const;
match:     cancell?ed
match:     enum|status|vocabular|spelling|value
```

V1 stores and sends `cancelled`. V2's single source of order statuses spells it `canceled`: V2 writes `canceled` on cancel, backfilled rows keep `cancelled`, filters on one spelling miss the other, and V1 consumers reading the partner webhook see an unknown value. The web labels are keyed `status_cancelled`, so the badge renders the raw key. Fix: `'cancelled'`. Proof: V360, every V1 value parsed, stored and serialised.

### PX-VO1b — Ticket priority integers shifted by one: V1 is 1–4, the V2 TypeScript enum is 0–3

```defect
id:        PX-VO1b
file:      v2/packages/contracts/src/enums.ts
line:      9
severity:  high
command:   /compare-v1
class:     surface/enum-drift
mg_class:  MG-VO-1
detector:  surface-parity-scan §6
anchor:    export enum TicketPriority { Low, Normal, High, Urgent }
v1_file:   v1/app/Enums/TicketPriority.php
v1_line:   8
v1_anchor: case Low = 1;
clean:     export enum TicketPriority { Low = 1, Normal = 2, High = 3, Urgent = 4 }
match:     priorit
match:     enum|0.based|1.based|off.by.one|integer|shift|value
```

V1's `TicketPriority` is backed by 1–4 and travels as the integer. V2's numeric TS enum starts at 0, so a V1 client sending `4` (urgent) is out of range, `3` becomes Urgent, and every backfilled `priority` reads one level higher. Fix: explicit values `Low = 1 … Urgent = 4`. Proof: V360 round trip.

### PX-VA1a — No global trim / empty-to-null: V1's `TrimStrings` + `ConvertEmptyStringsToNull` have no V2 counterpart outside the tickets module (one finding, every string field)

```defect
id:        PX-VA1a
file:      v2/apps/api/src/configure-app.ts
line:      5
severity:  high
command:   /compare-v1
class:     surface/validation-drift
mg_class:  MG-VA-1
detector:  surface-parity-scan §7
anchor:    app.setGlobalPrefix('api', { exclude: ['up'] });
v1_file:   v1/bootstrap/app.php
v1_line:   20
v1_anchor: $middleware->trimStrings(except: ['password', 'password_confirmation', 'current_password']);
clean:     app.setGlobalPrefix('api', { exclude: ['up'] });\n  http.registerInputNormalization(app);
match:     trim|empty.?(?:string)?.?to.?null|ConvertEmptyStringsToNull|TrimStrings|normali[sz]
match:     global|middleware|pipe|every|all
```

Laravel 11 runs `TrimStrings` and `ConvertEmptyStringsToNull` on every request (V1 only exempts the password fields). V2 registers no global equivalent: `registerInputNormalization` in `common/http-setup.ts` is never called and only `TicketsController` opts in with `@UsePipes`. So `"  PO-1 "` is stored with spaces, `""` is stored instead of NULL, and `nullable` fields that V1 saw as null now fail or persist empty strings — on every route but tickets. One finding with N fields. Fix: call `http.registerInputNormalization(app)`. Proof: V361 boundary corpus (empty, whitespace-only) diffing accept/reject and the stored value.

### PX-VA1b — `po_number` on create accepts 64 characters of anything; V1 allowed 30 of `[A-Z0-9-]` (the column is varchar(30))

```defect
id:        PX-VA1b
file:      v2/packages/contracts/src/orders.ts
line:      17
severity:  high
command:   /compare-v1
class:     surface/validation-drift
mg_class:  MG-VA-1
detector:  surface-parity-scan §7
anchor:    po_number: z.string().max(64).nullable().optional(),
v1_file:   v1/app/Http/Requests/StoreOrderRequest.php
v1_line:   17
v1_anchor: 'po_number' => ['nullable', 'string', 'max:30', 'regex:/^[A-Z0-9-]+$/'],
clean:     po_number: z.string().max(30).regex(/^[A-Z0-9-]+$/).nullable().optional(),
match:     po_number|po number|purchase order
match:     max|30|64|regex|length|accepts? more|loos|wider
```

V1's `StoreOrderRequest` limits `po_number` to 30 characters of `[A-Z0-9-]`. V2's `CreateOrderBody` allows 64 characters with no pattern, while the column stays `varchar(30)` and the update body kept the V1 rule — so a 31–64 character PO fails at the database as a 500 instead of a 422, and lowercase or spaced POs that V1 rejected are stored. Fix: `max(30).regex(/^[A-Z0-9-]+$/)`. Proof: V361, max ±1 and the pattern.

### PX-ER1a — Editing a placed order answers 400 with no `code`; V1 answered 409 `order_not_editable`

```defect
id:        PX-ER1a
file:      v2/apps/api/src/orders/orders.service.ts
line:      34
severity:  high
command:   /compare-v1
class:     surface/error-contract-drift
mg_class:  MG-ER-1
detector:  surface-parity-scan §8
anchor:    throw new DomainError(400, 'Order is not editable');
v1_file:   v1/app/Http/Controllers/OrderController.php
v1_line:   60
v1_anchor: throw new OrderNotEditableException('Order is not editable');
clean:     throw new DomainError(409, 'Order is not editable', 'order_not_editable');
match:     editable|409|order_not_editable
match:     400|409|status|code|error
```

V1 renders `OrderNotEditableException` as 409 `{ message, code: "order_not_editable" }` (bootstrap/app.php). The portal and the mobile app branch on that code to offer "duplicate instead". V2 throws `DomainError(400, …)` with no code, so the client shows a generic validation error. No ADR. Fix: `DomainError(409, 'Order is not editable', 'order_not_editable')`. Proof: V362 error corpus on status and `code`.

### PX-ER1b — Validation errors: V1 reports every failing field, V2 reports only the first

```defect
id:        PX-ER1b
file:      v2/apps/api/src/common/zod.ts
line:      14
severity:  medium
command:   /compare-v1
class:     surface/error-contract-drift
mg_class:  MG-ER-1
detector:  surface-parity-scan §8
anchor:    const issues = result.error.issues.slice(0, 1);
v1_file:   v1/tests/Feature/StoreOrderValidationTest.php
v1_line:   17
v1_anchor: ->assertJsonValidationErrors(['po_number', 'lines.0.sku', 'lines.0.quantity', 'lines.0.unit_price']);
clean:     const issues = result.error.issues;
match:     error|validation|issue
match:     first|only one|slice|all (?:fields|errors)|every
```

Laravel's 422 lists every failing field (`errors` has one key per field; V1's own test asserts four). V2's shared `ZodValidationPipe` keeps the 422 envelope but slices the issues to one, so a form with four mistakes shows one at a time. Fix: map every issue. Proof: V362 first-error vs all-errors.

### PX-SD1a — Default page size 20 in V2, 25 in V1

```defect
id:        PX-SD1a
file:      v2/packages/contracts/src/common.ts
line:      11
severity:  medium
command:   /compare-v1
class:     surface/silent-default
mg_class:  MG-SD-1
detector:  surface-parity-scan §9
anchor:    per_page: z.coerce.number().default(20)
v1_file:   v1/app/Http/Controllers/OrderController.php
v1_line:   21
v1_anchor: $perPage = min((int) $request->input('per_page', 25), 100);
clean:     per_page: z.coerce.number().default(25)
match:     per_page|page size|perPage
match:     default|20|25
```

V1 lists default to 25 rows; V2's shared `PageQuery` defaults to 20. Clients that omit `per_page` and compute page counts from V1's size (the mobile app's infinite scroll assumes 25) stop paging early: a 25-row page is how they detect "more". Fix: `.default(25)`. Proof: V358, every optional parameter omitted.

### PX-SD1b — An order placed without `currency` is stored in USD; V1's model default is SAR

```defect
id:        PX-SD1b
file:      v2/apps/api/src/orders/order.entity.ts
line:      32
severity:  high
command:   /compare-v1
class:     surface/silent-default
mg_class:  MG-SD-1
detector:  surface-parity-scan §9
anchor:    currency: string = 'USD';
v1_file:   v1/app/Models/Order.php
v1_line:   25
v1_anchor: 'currency' => 'SAR',
clean:     currency: string = 'SAR';
match:     currency
match:     default|USD|SAR
```

V1's `Order::$attributes` default the currency to SAR (and the column default agrees). V2's entity defaults to USD, and `OrderPlacementService` only sets it when the body names one, so every order the portal places without a currency is stored and invoiced in the wrong currency. Money, so high. Fix: `'SAR'`. Proof: V358 with `currency` omitted.

## Business rules and runtime semantics

### PX-MN1a — Credit notes round negative halves toward +∞ (`Math.round`); V1 `round()` rounds them away from zero

```defect
id:        PX-MN1a
file:      change/v2/apps/api/src/invoices/credit-note.ts
line:      5
severity:  high
command:   /compare-v1
class:     semantics/rounding-mode
mg_class:  MG-MN-1
detector:  semantics-parity-scan §1
anchor:    const refund = Math.round(Number(net) * ratio * -1 * 100) / 100;
v1_file:   v1/app/Services/PricingService.php
v1_line:   21
v1_anchor: $refund = round((float) $net * $ratio * -1, 2);
clean:     const refund = money.roundHalfAway(Number(net) * ratio * -1, 2);
match:     Math\.round|round
match:     negative|half|away from zero|toward|-1\.13|-1\.12|credit
```

PHP `round(-1.125, 2)` is −1.13 (half away from zero); `Math.round(-112.5) / 100` is −1.12 (ties toward +∞). Every credit note on a half-cent boundary is one cent smaller than V1's, so refunds do not cancel the original charge. The port PR adds this file and skips the parity case that would catch it (PX-PP1a). Fix: `money.roundHalfAway(…, 2)`, the helper every other money path uses. Proof: V363 property test at negative halves (`runtime/v363-rounding-property.txt`).

### PX-MN1b — Line nets use `toFixed(2)` on a binary float: 1.005 → 1.00 where V1 `round()` gives 1.01

```defect
id:        PX-MN1b
file:      v2/apps/api/src/orders/pricing.ts
line:      11
severity:  high
command:   /compare-v1
class:     semantics/rounding-mode
mg_class:  MG-MN-1
detector:  semantics-parity-scan §1
anchor:    return Number((unitPrice * quantity * (1 - discount)).toFixed(2));
v1_file:   v1/app/Services/PricingService.php
v1_line:   16
v1_anchor: return (string) round((float) $unitPrice * $quantity * (1 - $discount), 2);
clean:     return roundHalfAway(unitPrice * quantity * (1 - discount), 2);
match:     toFixed|round
match:     binary|float|1\.005|half|line net|lineNet|pre.?round
```

`toFixed` rounds the exact binary value, so 1.005 (stored as 1.00499…) becomes 1.00 and 2.675 becomes 2.67; PHP 8.3's `round()` pre-rounds and gives 1.01 and 2.68. The credit branch above it already uses `roundHalfAway`. Every discounted line on such a value is a cent short on a stored, invoiced amount. Fix: `roundHalfAway(…, 2)`. Proof: V363 with 1.005 and 2.675.

### PX-MN2a — Invoice tax is rounded once on the subtotal; V1 rounds per line and sums

```defect
id:        PX-MN2a
file:      v2/apps/api/src/invoices/invoice-totals.ts
line:      12
severity:  high
command:   /compare-v1
class:     semantics/rounding-order
mg_class:  MG-MN-2
detector:  semantics-parity-scan §2
anchor:    const tax = roundHalfAway(subtotal * taxRate, 2);
v1_file:   v1/app/Services/InvoiceService.php
v1_line:   19
v1_anchor: $tax += round($net * (float) $invoice->tax_rate, 2);
clean:     const tax = roundHalfAway(nets.reduce((s, n) => s + roundHalfAway(n * taxRate, 2), 0), 2);
match:     tax
match:     per.?line|per.?total|subtotal|order|sum|each line
```

V1 rounds each line's tax to the cent, then sums (`InvoiceService::totals`, pinned by V1's own test: 13.08 on the five-line reference). V2 rounds the tax of the subtotal: 13.09 on the same invoice (decimal.js rounds the exact float 13.0949…, with no PHP-style pre-rounding). Every multi-line invoice can differ by a few cents on a stored, charged amount. Fix: per-line rounding, then sum. Proof: V363 sums of many lines (`runtime/v363-rounding-property.txt`).

### PX-MN2b — Installments split the total by naive division: 100.00 / 3 = 3 × 33.33 = 99.99 (V1 allocates the remainder cent)

```defect
id:        PX-MN2b
file:      v2/apps/api/src/wallets/installments.ts
line:      5
severity:  high
command:   /compare-v1
class:     semantics/rounding-order
mg_class:  MG-MN-2
detector:  semantics-parity-scan §2
anchor:    return Array.from({ length: count }, () => money.toMoneyString(money.roundHalfAway(total / count, 2)));
v1_file:   v1/app/Support/Money.php
v1_line:   15
v1_anchor: $remainder = $cents - $base * $count;
clean:     return money.allocateCents(total, count);
match:     installment|allocat|split
match:     remainder|sum|99\.99|cent|allocat|naive|divid
```

V1's `Money::allocate` splits in whole cents and gives the remainder to the first parts, so the parts sum to the total. V2 rounds `total / count` and repeats it: 100.00 in 3 installments is 99.99, a cent the wallet never collects. `allocateCents` (a faithful port) sits unused in `common/money.ts`. Fix: `money.allocateCents(total, count)`. Proof: V363 allocation invariant (sum of parts = total).

### PX-MN3 — Invoice `total` leaves as a JS number (decimal → float, scale lost) while `subtotal` and `tax` stay strings

```defect
id:        PX-MN3
file:      v2/apps/api/src/invoices/invoice.mapper.ts
line:      10
severity:  high
command:   /backend-audit
class:     backend/money-precision
mg_class:  MG-MN-3
detector:  wire-format-scan §1 (backend) ← semantics-parity-scan §3 routes
anchor:    total: Number(invoice.totalAmount),
v1_file:   v1/app/Models/Invoice.php
v1_line:   24
v1_anchor: 'total_amount' => 'decimal:2',
clean:     total: invoice.totalAmount,
match:     total
match:     Number\(|float|number|decimal|scale|string
```

V1's `decimal:2` cast serialises `total` as the string "410.10"; the contract types it `Money` (a 2-decimal string). The V2 mapper wraps it in `Number()`, so `410.10` leaves as `410.1` (the scale is lost; clients that compare strings or format with the server's digits break). Owned by backend `wire-format-scan` §1 (single-codebase class); `/compare-v1` lists it as routed. Fix: pass the string through. Proof: V339/V363 round trip of 0.10, 1e15 + 0.01.

### PX-NUM1a — Overdue SLA hours floor instead of truncating: −90 min is −2 h in V2, −1 h in V1

```defect
id:        PX-NUM1a
file:      v2/apps/api/src/tickets/sla.ts
line:      8
severity:  medium
command:   /compare-v1
class:     semantics/integer-division
mg_class:  MG-NUM-1
detector:  semantics-parity-scan §4
anchor:    const hours = Math.floor(minutesLeft / 60);
v1_file:   v1/app/Services/SlaService.php
v1_line:   14
v1_anchor: $hours = intdiv($minutesLeft, 60);
clean:     const hours = Math.trunc(minutesLeft / 60);
match:     floor|intdiv|trunc
match:     negative|overdue|breach|-90|truncat|toward zero
```

`intdiv` truncates toward zero; `Math.floor` floors. For overdue tickets (negative minutes) the SLA report shows one more hour of breach than V1, which moves tickets across the duty-manager escalation threshold. Fix: `Math.trunc`. Proof: V364 negative dividends.

### PX-NUM1b — Packs available rounds (11 units / 4 per pack = 3 packs) where V1 truncates (2): V2 offers stock it does not have

```defect
id:        PX-NUM1b
file:      v2/apps/api/src/inventory/stock.service.ts
line:      33
severity:  high
command:   /compare-v1
class:     semantics/integer-division
mg_class:  MG-NUM-1
detector:  semantics-parity-scan §4
anchor:    return Math.max(Math.round(free / row.pack_size), 0);
v1_file:   v1/app/Services/StockService.php
v1_line:   27
v1_anchor: $packs = intdiv($free, $item->pack_size);
clean:     return Math.max(Math.trunc(free / row.pack_size), 0);
match:     pack
match:     round|intdiv|trunc|integer division|oversell
```

V1 computes whole packs with `intdiv`. V2 uses `Math.round`, so 11 free units in packs of 4 show 3 packs; the portal lets a buyer order the third pack and the reservation fails later (or the warehouse short-ships). Fix: `Math.trunc`. Proof: V364.

### PX-STR1a — Company name limit counts UTF-8 bytes: an Arabic name is refused at 31 letters (V1 `max:60` counts characters)

```defect
id:        PX-STR1a
file:      v2/apps/api/src/users/accounts.service.ts
line:      11
severity:  medium
command:   /compare-v1
class:     semantics/string-semantics
mg_class:  MG-STR-1
detector:  semantics-parity-scan §5
anchor:    if (Buffer.byteLength(value.company_name, 'utf8') > 60) {
v1_file:   v1/app/Http/Requests/UpdateAccountRequest.php
v1_line:   17
v1_anchor: 'company_name' => ['required', 'string', 'max:60'],
clean:     if (Array.from(value.company_name).length > 60) {
match:     company.?name|byteLength|bytes?
match:     byte|character|utf|arabic|multibyte|length
```

Laravel's `max:60` on a string counts characters (`mb_strlen`). V2 checks `Buffer.byteLength`, and Arabic letters are 2 bytes in UTF-8, so the most common company names on this platform are refused at 31 characters. Fix: count code points. Proof: V365 multibyte corpus at the limit.

### PX-STR1b — SMS preview cuts at 50 UTF-16 units: an emoji at the boundary is split into a lone surrogate

```defect
id:        PX-STR1b
file:      v2/apps/api/src/tickets/ticket-sms.ts
line:      3
severity:  medium
command:   /compare-v1
class:     semantics/string-semantics
mg_class:  MG-STR-1
detector:  semantics-parity-scan §5
anchor:    const preview = subject.substring(0, 50);
v1_file:   v1/app/Observers/TicketObserver.php
v1_line:   14
v1_anchor: $preview = mb_substr($ticket->subject, 0, 50);
clean:     const preview = Array.from(subject).slice(0, 50).join('');
match:     preview|substring|sms
match:     surrogate|utf.?16|emoji|code (?:unit|point)|mb_substr|character
```

V1 cuts with `mb_substr` (characters). `substring(0, 50)` counts UTF-16 code units, so a subject with an emoji across position 50 produces a lone high surrogate that the SMS gateway rejects or renders as `?`. Fix: slice code points. Proof: V365 emoji at the limit.

### PX-PP4a — `array_search(...) === false` ported as `!indexOf(...)`: `tier1` (index 0) counts as not found, so its next tier is `tier1` again instead of `tier2`

```defect
id:        PX-PP4a
file:      v2/apps/api/src/tickets/sla.ts
line:      21
severity:  medium
command:   /compare-v1
class:     semantics/library-lookalike
mg_class:  PP-4
detector:  semantics-parity-scan §5 (look-alike table)
anchor:    if (!pos) {
v1_file:   v1/app/Services/SlaService.php
v1_line:   27
v1_anchor: if ($pos === false) {
clean:     if (pos === -1) {
match:     indexOf|array_search|nextTier|pos
match:     -1|0|false|falsy|not found|index
```

`array_search` returns `false` when absent and `0` for the first element; `indexOf` returns `-1` and `0`. `if (!pos)` treats `tier1` (index 0) as unknown, so `nextTier('tier1')` returns `tier1` where V1 returns `tier2`: breached tickets never escalate past the first tier. (An unknown tier happens to agree: −1 is truthy, and both sides fall through to the same lookup.) Fix: `pos === -1`. Proof: V365 look-alike pair test.

### PX-PP4b — `explode(',', $line, 2)` ported as `split(',', 2)`: JS drops everything after the second comma, PHP keeps it

```defect
id:        PX-PP4b
file:      v2/apps/api/src/inventory/csv-import.ts
line:      9
severity:  medium
command:   /compare-v1
class:     semantics/library-lookalike
mg_class:  PP-4
detector:  semantics-parity-scan §5 (look-alike table)
anchor:    const [sku, description] = raw.split(',', 2);
v1_file:   v1/app/Services/CsvImportService.php
v1_line:   17
v1_anchor: [$sku, $description] = explode(',', $line, 2);
clean:     const cut = raw.indexOf(','); const [sku, description] = cut < 0 ? [raw, undefined] : [raw.slice(0, cut), raw.slice(cut + 1)];
match:     split|explode
match:     limit|comma|description|truncat|rest|remainder
```

PHP's `explode` limit puts the rest of the string in the last element, so `NRW-1,Bolt, M6, zinc` keeps the whole description. JavaScript's `split` limit truncates: the description becomes `Bolt`. Every imported description with a comma loses text. Fix: split at the first comma only. Proof: V365 pair test.

### PX-ORD1a — Paginated order list has no ORDER BY on Postgres (V1 relied on InnoDB primary-key order)

```defect
id:        PX-ORD1a
file:      v2/apps/api/src/orders/orders.service.ts
line:      19
severity:  high
command:   /compare-v1
class:     semantics/ordering
mg_class:  MG-ORD-1
detector:  semantics-parity-scan §6
anchor:    const [items, total] = await this.em.findAndCount(Order, where, { limit: query.per_page, offset, populate: ['lines'] });
v1_file:   v1/app/Http/Controllers/OrderController.php
v1_line:   24
v1_anchor: $orders = Order::query()
clean:     const [items, total] = await this.em.findAndCount(Order, where, { limit: query.per_page, offset, populate: ['lines'], orderBy: { id: 'asc' } });
match:     order ?by|orderBy|ordering|sort
match:     paginat|page|duplicat|skip|unspecified|unstable|primary key|InnoDB
```

V1's query has no `orderBy` either, but MySQL InnoDB returns primary-key order in practice and clients depend on it. Postgres returns heap order, which changes after updates and vacuum: pages duplicate and skip rows. Pagination makes it high (precedent 7). Fix: `orderBy: { id: 'asc' }`. Proof: V366 pagination across ties after updates.

### PX-ORD1b — "Next ticket" picks among equal priorities in no defined order (V1: oldest first by primary key)

```defect
id:        PX-ORD1b
file:      v2/apps/api/src/tickets/ticket-assignment.ts
line:      10
severity:  high
command:   /compare-v1
class:     semantics/ordering
mg_class:  MG-ORD-1
detector:  semantics-parity-scan §6
anchor:    orderBy: { priority: QueryOrder.DESC },
v1_file:   v1/app/Http/Controllers/TicketController.php
v1_line:   59
v1_anchor: ->orderByDesc('priority')
clean:     orderBy: { priority: QueryOrder.DESC, createdAt: QueryOrder.ASC },
match:     next|assign|priorit
match:     tie|order|oldest|first|unspecified|deterministic
```

`POST /api/tickets/next` takes the first open, unassigned ticket by priority. In V1 ties fall back to InnoDB primary-key order — the oldest ticket. V2 ids are UUIDs and there is no tiebreaker, so agents get an arbitrary ticket among equals and old tickets starve. "First match" makes it high. Fix: tie-break on `createdAt`. Proof: V366 ties.

### PX-NULL1a — A ticket with no tags has no `tags` key in V2 (V1 always sends `[]`)

```defect
id:        PX-NULL1a
file:      v2/apps/api/src/tickets/ticket.mapper.ts
line:      10
severity:  medium
command:   /compare-v1
class:     semantics/null-empty-missing
mg_class:  MG-NULL-1
detector:  semantics-parity-scan §7
anchor:    tags: ticket.tags.isInitialized() && ticket.tags.length ? ticket.tags.getItems().map((t) => t.name) : undefined,
v1_file:   v1/app/Models/Ticket.php
v1_line:   54
v1_anchor: 'tags' => $this->tags->pluck('name')->values(),
clean:     tags: ticket.tags.isInitialized() ? ticket.tags.getItems().map((t) => t.name) : [],
match:     tags
match:     undefined|missing|absent|omit|\[\]|empty|presence
```

V1 always serialises `tags` as an array. V2 returns `undefined` when there are none, which `JSON.stringify` drops: the mobile app's typed decoder requires the key and fails on untagged tickets. The contract says "always an array". Fix: `[]`. Proof: V367 empty list vs absent.

### PX-NULL1b — `shipped_at` is omitted until shipping in V2; V1 sends it as `null`

```defect
id:        PX-NULL1b
file:      v2/apps/api/src/orders/order.mapper.ts
line:      13
severity:  medium
command:   /compare-v1
class:     semantics/null-empty-missing
mg_class:  MG-NULL-1
detector:  semantics-parity-scan §7
anchor:    ...(order.shippedAt && { shipped_at: order.shippedAt.toISOString() }),
v1_file:   v1/app/Models/Order.php
v1_line:   50
v1_anchor: 'shipped_at' => $this->shipped_at?->toIso8601String(),
clean:     shipped_at: order.shippedAt ? order.shippedAt.toISOString() : null,
match:     shipped_at|shippedAt
match:     null|missing|absent|omit|presence|undefined
```

V1 always includes `shipped_at` (null before shipping); the zod `OrderDto` declares it `.nullable()`, not optional. The V2 mapper spreads it in only when set, so unshipped orders have no key and the `as OrderDtoT` cast hides it from the type checker. Consumers that test `shipped_at === null` see `undefined`. Fix: always emit the key. Proof: V367.

### PX-TZ1a — Business-day zone defaults to UTC in V2 (V1: Asia/Riyadh), and the API deployment does not set `APP_TIMEZONE`

```defect
id:        PX-TZ1a
file:      v2/apps/api/src/config/app.config.ts
line:      4
severity:  high
command:   /compare-v1
class:     semantics/timezone
mg_class:  MG-TZ-1
detector:  semantics-parity-scan §8
anchor:    timezone: process.env.APP_TIMEZONE ?? 'UTC',
v1_file:   v1/config/app.php
v1_line:   11
v1_anchor: 'timezone' => env('APP_TIMEZONE', 'Asia/Riyadh'),
clean:     timezone: process.env.APP_TIMEZONE ?? 'Asia/Riyadh',
match:     time ?zone|APP_TIMEZONE|UTC|Riyadh
match:     default|config|day|report|boundar|UTC
```

Every V1 date boundary (report days, due dates, the nightly job's "before midnight") is Riyadh time. V2's `appConfig.timezone` falls back to UTC, and `deploy/k8s/api-deployment.yaml` sets `APP_TIMEZONE` on the scheduler only, so the API's sales report groups days three hours off. Fix: default `'Asia/Riyadh'` (and set the env on the API). Proof: V368, server TZ ≠ UTC.

### PX-TZ1b — Sales report `from` is parsed in the host zone; `to` (next line) uses the business zone

```defect
id:        PX-TZ1b
file:      v2/apps/api/src/reports/reports.service.ts
line:      21
severity:  medium
command:   /compare-v1
class:     semantics/timezone
mg_class:  MG-TZ-1
detector:  semantics-parity-scan §8
anchor:    const from = dayjs(fromRaw).startOf('day').toDate();
v1_file:   v1/app/Http/Controllers/ReportController.php
v1_line:   15
v1_anchor: $from = Carbon::parse($request->input('from'))->startOfDay();
clean:     const from = dayjs.tz(fromRaw, appConfig.timezone).startOf('day').toDate();
match:     from|dayjs|startOf
match:     zone|tz|host|UTC|Riyadh|boundar
```

Carbon parses in the app zone (Riyadh). `dayjs(fromRaw)` parses in the container's zone (UTC), while `to` on the next line uses `dayjs.tz(…, appConfig.timezone)`. The first three hours of the first day fall outside the report. Fix: `dayjs.tz(fromRaw, appConfig.timezone)`. Proof: V368.

### PX-I18N — Arabic `items` plural has only `_one` and `_other`: 0, 2, 3–10 and 11–99 render the wrong form

```defect
id:        PX-I18N
file:      v2/apps/web/src/locales/ar/orders.json
line:      8
severity:  medium
command:   /frontend-audit
class:     frontend/plural-forms
mg_class:  MG-I18N-1
detector:  i18n-scan §3 (frontend) ← semantics-parity-scan §9 routes
anchor:    "items_one": "عنصر واحد",
v1_file:   v1/lang/ar/orders.php
v1_line:   4
v1_anchor: 'items' => '{0} لا توجد عناصر|{1} عنصر واحد|{2} عنصران|[3,10] :count عناصر|[11,*] :count عنصرًا',
clean:     "items_zero": "لا توجد عناصر",\n  "items_one": "عنصر واحد",\n  "items_two": "عنصران",\n  "items_few": "{{count}} عناصر",\n  "items_many": "{{count}} عنصرًا",
match:     plural|items
match:     arabic|\bar\b|zero|two|few|many|CLDR|form
```

V1's `trans_choice` string carries five Arabic forms. i18next ≥ 21 selects `_zero/_one/_two/_few/_many/_other` through `Intl.PluralRules('ar')`; the V2 catalog has `_one` and `_other`, so "0 items", "2 items" and "3 items" all render the `_other` form. (For 103–110 CLDR picks `few` where V1's `[11,*]` range wrote عنصرًا; the CLDR form is the correct Arabic, so that residue belongs in Known V1 bugs, not in the fix.) Owned by frontend `i18n-scan` §3; `/compare-v1` lists it as routed. Fix: the four missing categories. Proof: V369, counts {0,1,2,3,11,100}.

### PX-TX — Stock reservation reads, checks and increments with no row lock: two concurrent orders both pass the availability check

```defect
id:        PX-TX
file:      v2/apps/api/src/inventory/stock-reservation.service.ts
line:      11
severity:  high
command:   /db-audit
class:     database/lock-dropped
mg_class:  MG-TX-1
detector:  transaction-scan §7 (database) ← semantics-parity-scan §10 routes
anchor:    const item = await em.findOneOrFail(StockItem, { sku: sku.trim().toUpperCase() });
v1_file:   v1/app/Services/StockService.php
v1_line:   13
v1_anchor: $item = StockItem::lockForUpdate()->where('sku', strtoupper(trim($sku)))->firstOrFail();
clean:     const item = await em.findOneOrFail(StockItem, { sku: sku.trim().toUpperCase() }, { lockMode: LockMode.PESSIMISTIC_WRITE });
match:     reserv|stock
match:     lock|FOR UPDATE|concurren|race|oversell|lost update|write skew
```

V1 reserves inside the placement transaction with `lockForUpdate()`. V2 runs inside a transaction too, but reads the row unlocked at READ COMMITTED, checks `available - reserved >= qty` in memory and writes back: two concurrent placements both pass and oversell (and one increment can be lost). `release()` in the same file locks; `reserve()` does not. Owned by database `transaction-scan` §7; `/compare-v1` lists it as routed with the V1 lock as input. Fix: `lockMode: LockMode.PESSIMISTIC_WRITE`. Proof: V370 two concurrent writers.

## Side effects and hidden consumers

### PX-SE1a — "Your order has shipped" e-mail lost: V1 sends it from an observer (`updated`), V2's subscriber ports `created` only

```defect
id:        PX-SE1a
file:      v2/apps/api/src/orders/order.subscriber.ts
line:      15
severity:  high
command:   /compare-v1
class:     effects/side-effect-dropped
mg_class:  MG-SE-1
detector:  side-effect-parity-scan §1
anchor:    return [Order];
v1_file:   v1/app/Observers/OrderObserver.php
v1_line:   21
v1_anchor: Mail::to($order->customer_email)->queue(new OrderShippedMail($order));
clean:     return [Order];\n  }\n\n  async afterUpdate(args: EventArgs<Order>): Promise<void> {\n    if (args.em.getFilterParams<{ source?: string }>('replication')?.source === 'v1-sync') {\n      return;\n    }\n    if (args.changeSet?.payload.status === 'shipped') {\n      await this.mail.add('order-shipped', { orderId: args.entity.id, to: args.entity.customerEmail });\n    }
match:     ship
match:     mail|e-?mail|notif|observer|subscriber|afterUpdate|side.?effect
```

The shipped e-mail lives in `OrderObserver::updated`, attached by `#[ObservedBy]` — no controller calls it, which is why a controller-by-controller port missed it (observer-only effect). `OrderSubscriber` handles `afterCreate` only; nothing else in V2 enqueues `order-shipped`. Fix: an `afterUpdate` on the status change. Proof: V371 journal, update path (`runtime/v371-effect-journal.txt`).

### PX-SE1b — Wallet updates are no longer audited: V1's `LogsActivity` trait logged them; V2's subscriber ports create and delete only

```defect
id:        PX-SE1b
file:      v2/apps/api/src/wallets/wallet-activity.subscriber.ts
line:      15
severity:  high
command:   /compare-v1
class:     effects/side-effect-dropped
mg_class:  MG-SE-1
detector:  side-effect-parity-scan §1
anchor:    return [Wallet];
v1_file:   v1/app/Models/Wallet.php
v1_line:   22
v1_anchor: ->logOnly(['balance_minor', 'credit_limit_minor'])
clean:     return [Wallet];\n  }\n\n  async afterUpdate(args: EventArgs<Wallet>): Promise<void> {\n    this.activity.log('updated', args.entity, { attributes: pick(args.entity) }, 'wallets');
match:     activity|audit|LogsActivity
match:     wallet|balance|adjust
```

spatie's `LogsActivity` trait on V1's `Wallet` writes an `activity_log` row when a wallet is created, updated or deleted — a trait effect with no call site to port. V2's `WalletActivitySubscriber` ports `afterCreate` and `afterDelete` and has no `afterUpdate`, so every balance adjustment, promo expiry and credit-limit change goes unaudited. Finance loses the trail of every manual credit or debit. Fix: the `afterUpdate` hook. Proof: V371 audit-row delta on the update path.

### PX-SE2a — Order-placed e-mail sent twice during the dual-run: V2's subscriber also fires for rows the V1 → V2 sync inserts

```defect
id:        PX-SE2a
file:      v2/apps/api/src/orders/order.subscriber.ts
line:      19
severity:  high
command:   /compare-v1
class:     effects/side-effect-duplicated
mg_class:  MG-SE-2
detector:  side-effect-parity-scan §2
anchor:    await this.mail.add('order-placed', { orderId: args.entity.id, to: args.entity.customerEmail });
v1_file:   v1/app/Observers/OrderObserver.php
v1_line:   15
v1_anchor: Mail::to($order->customer_email)->queue(new OrderPlacedMail($order));
clean:     if (args.em.getFilterParams<{ source?: string }>('replication')?.source === 'v1-sync') {\n      return;\n    }\n    await this.mail.add('order-placed', { orderId: args.entity.id, to: args.entity.customerEmail });
match:     order.?placed|afterCreate|subscriber
match:     twice|duplicat|dual|sync|replicat|both
```

Writes stay on V1 until the 2.4.0 flip, and V1 mails the customer from `OrderObserver::created`. The dual-write sync inserts each V1 order into V2, which fires `OrderSubscriber.afterCreate`, which mails again. The ticket subscriber skips replicated writes with `isReplicatedWrite`; this one does not. Fix: return early on replicated writes. Proof: V371 during the dual-run (`runtime/v371-effect-journal.txt`: the customer got 2).

### PX-SE2b — Invoice-issued job enqueued inside the transaction (V1: `->afterCommit()`): it runs on rollback and can run before the row is visible

```defect
id:        PX-SE2b
file:      v2/apps/api/src/invoices/invoices.service.ts
line:      48
severity:  high
command:   /compare-v1
class:     effects/side-effect-duplicated
mg_class:  MG-SE-2
detector:  side-effect-parity-scan §2
anchor:    await this.queue.add('invoice-issued', { invoiceId: inv.id });
v1_file:   v1/app/Services/InvoiceService.php
v1_line:   39
v1_anchor: ProcessInvoiceIssued::dispatch($invoice)->afterCommit();
clean:     onCommit(() => this.queue.add('invoice-issued', { invoiceId: inv.id }));
match:     invoice.?issued|queue|enqueue
match:     commit|transaction|rollback|before|onCommit
```

V1 dispatches `ProcessInvoiceIssued` after commit. V2 calls `queue.add` inside `tx.run`, ignoring the `onCommit` callback the runner hands it: a rolled-back issue still enqueues the job (which then fails on an invoice that was never issued), and the worker can read the invoice before the number is committed. The ordering mechanism is the distributed-systems pack's; the V1 ≠ V2 delta is this row. Fix: `onCommit(() => this.queue.add(…))`. Proof: V371 with a fault after the enqueue.

### PX-HC1a — Finance BI view `finance_invoice_totals` has no V2 counterpart: the workbook's `reports_ro` login stops seeing invoices at the write flip

```defect
id:        PX-HC1a
file:      v2/apps/api/src/migrations/Migration20261001000000_reporting_views.ts
line:      11
severity:  high
command:   /compare-v1
class:     effects/hidden-consumer
mg_class:  MG-HC-1
detector:  side-effect-parity-scan §3
anchor:    this.addSql('grant select on finance_wallet_movements to reports_ro;');
v1_file:   v1/database/migrations/2024_03_01_000007_create_finance_views.php
v1_line:   12
v1_anchor: CREATE VIEW finance_invoice_totals AS
clean:     this.addSql(`create view finance_invoice_totals as\n      select i.account_id, (i.issued_at at time zone 'Asia/Riyadh')::date as day, sum(i.subtotal_amount) as subtotal, sum(i.tax_amount) as tax, sum(i.total_amount) as total\n      from invoices i where i.status in ('issued', 'paid') group by 1, 2;`);\n\n    this.addSql('grant select on finance_wallet_movements to reports_ro;');\n    this.addSql('grant select on finance_invoice_totals to reports_ro;');
match:     finance_invoice_totals|view|reports_ro|BI
match:     consumer|missing|not ported|stale|workbook|report
```

Two V1 views are read by the finance workbook through `reports_ro`, not by the app. V2's legacy-mimic migration ports `finance_wallet_movements` and not `finance_invoice_totals`, so after the invoices write flip the V1 view freezes and the V2 database has none. Fix: create the view and its grant. Proof: V372 consumer inventory (every non-app login and view).

### PX-HC1b — Partner stock feed renamed its columns (`qty_available,updated_at` → `available,updatedAt`); the 3PL importer reads by name

```defect
id:        PX-HC1b
file:      v2/apps/api/src/inventory/stock-feed.export.ts
line:      16
severity:  high
command:   /compare-v1
class:     effects/hidden-consumer
mg_class:  MG-HC-1
detector:  side-effect-parity-scan §3
anchor:    const lines = ['sku,available,updatedAt',
v1_file:   v1/app/Console/Commands/ExportStockFeed.php
v1_line:   18
v1_anchor: fputcsv($out, ['sku', 'qty_available', 'updated_at']);
clean:     const lines = ['sku,qty_available,updated_at',
match:     feed|csv|header|column
match:     partner|3pl|warehouse|renam|consumer|qty_available
```

The daily SFTP feed is read by the warehouse partner's importer by column name. V1 writes `sku,qty_available,updated_at`; V2 kept the values and the V1 timestamp shape but renamed two headers, so the partner's import silently reads empty quantities. Fix: V1's header. Proof: V372 (every export job and its consumer).

### PX-JB1a — `wallets:expire-credits` (daily 00:15) is not scheduled in V2: the service method is ported and nothing calls it

```defect
id:        PX-JB1a
file:      v2/apps/api/src/jobs/schedules.ts
line:      13
severity:  high
command:   /compare-v1
class:     effects/job-not-ported
mg_class:  MG-JB-1
detector:  side-effect-parity-scan §4
anchor:    @Cron('0 0 5 * * *', { name: 'stock-export-feed', timeZone: 'Asia/Riyadh' })
v1_file:   v1/routes/console.php
v1_line:   9
v1_anchor: Schedule::command('wallets:expire-credits')->dailyAt('00:15')->timezone('Asia/Riyadh')->onOneServer();
clean:     @Cron('0 15 0 * * *', { name: 'wallets-expire-credits', timeZone: 'Asia/Riyadh' })\n  async expireCredits(): Promise<void> {\n    await this.wallets.expireAllPromos();\n  }\n\n  @Cron('0 0 5 * * *', { name: 'stock-export-feed', timeZone: 'Asia/Riyadh' })
match:     expire|promo|credit
match:     cron|schedul|not ported|never (?:runs|called)|missing
```

V1 expires promotional credit nightly. V2 ported `WalletsService.expireAllPromos()` and injects `WalletsService` into `Schedules`, but no `@Cron`, BullMQ repeat or Kubernetes CronJob runs it, so promotional balances never expire once wallets move. Fix: the `@Cron`. Proof: V373 schedule equality + one dry run (`runtime/v371-effect-journal.txt`, cron rows).

### PX-JB1b — Stale-reservation release (every 5 minutes) is not scheduled: abandoned drafts hold stock forever

```defect
id:        PX-JB1b
file:      v2/apps/api/src/jobs/schedules.ts
line:      11
severity:  high
command:   /compare-v1
class:     effects/job-not-ported
mg_class:  MG-JB-1
detector:  side-effect-parity-scan §4
anchor:    constructor(private readonly stockFeed: StockFeedExport, private readonly wallets: WalletsService, private readonly reservations: StockReservationService) {}
v1_file:   v1/routes/console.php
v1_line:   11
v1_anchor: Schedule::job(new ReleaseStaleReservations)->everyFiveMinutes()->withoutOverlapping();
clean:     constructor(private readonly stockFeed: StockFeedExport, private readonly wallets: WalletsService, private readonly reservations: StockReservationService) {}\n\n  @Cron('0 */5 * * * *', { name: 'release-stale-reservations', waitForCompletion: true })\n  async releaseStale(): Promise<void> {\n    await this.reservations.releaseStale();\n  }
match:     stale|reservation|release
match:     cron|schedul|not ported|never|missing
```

V1 releases stock reserved by drafts idle for 30 minutes, every five minutes. V2 ported the SQL (`StockReservationService.releaseStale`) and injects the service into `Schedules`, but no schedule calls it; reserved quantities only grow and the portal reports items out of stock. Fix: a `@Cron` every five minutes in the single-replica scheduler, with `waitForCompletion` for V1's `withoutOverlapping`. Proof: V373.

### PX-DM10a — `orders.line_count` was maintained by a MySQL trigger; V2 has the column and nothing maintains it

```defect
id:        PX-DM10a
file:      v2/apps/api/src/orders/order.entity.ts
line:      43
severity:  high
command:   /compare-v1
class:     effects/db-logic-not-reproduced
mg_class:  DM-10
detector:  side-effect-parity-scan §5
anchor:    @Property({ fieldName: 'line_count', default: 0 })
v1_file:   v1/database/migrations/2024_01_01_000002_create_orders_tables.php
v1_line:   43
v1_anchor: FOR EACH ROW UPDATE orders SET line_count = line_count + 1 WHERE id = NEW.order_id
clean:     @Property({ fieldName: 'line_count', formula: (alias) => `(select count(*) from order_lines ol where ol.order_id = ${alias}.id)` })
match:     line_count|lineCount|trigger
match:     trigger|maintain|stale|zero|0|not reproduced|DB.side
```

V1's `order_lines_after_insert` trigger increments `orders.line_count`; no PHP code touches it. V2 created the column with default 0 and no trigger, formula or code path, so every V2-placed order reports `line_count: 0` (backfilled ones keep V1's count). Fix: a formula (or the trigger) in V2. Proof: V371 row-delta journal on insert.

### PX-DM10b — The V2 schema lost `ON DELETE CASCADE` on `ticket_messages.ticket_id` (the entity says cascade; the generated snapshot and migration do not)

```defect
id:        PX-DM10b
file:      v2/apps/api/src/migrations/.snapshot-norrow.json
line:      238
severity:  high
command:   /compare-v1
class:     effects/db-logic-not-reproduced
mg_class:  DM-10
detector:  side-effect-parity-scan §5
anchor:    "deleteRule": "no action"
v1_file:   v1/database/migrations/2024_01_01_000006_create_tickets_tables.php
v1_line:   29
v1_anchor: $table->foreignId('ticket_id')->constrained('tickets')->cascadeOnDelete();
clean:     "deleteRule": "cascade"
match:     cascade|ticket_messages|TicketMessage
match:     delete|foreign key|FK|cascade
```

V1's foreign key deletes a ticket's messages with the ticket. V2's `TicketMessage` entity declares `deleteRule: 'cascade'`, but the schema snapshot — and so the migration generated from it, which is what the database runs — still says `no action`: the decorator was changed after the migration was generated and no new one was created. Deleting a ticket with messages fails on the foreign key. A lost FK rule is a guarantee class: a Finding even in solo mode. Fix: a migration (and snapshot) with `on delete cascade`. Proof: V371 delete path.

## Data migration and cutover

### PX-DM1a — Tickets backfill keeps no checkpoint and never pauses: a crash restarts from id 0 and double-inserts; the replica lag is unbounded

```defect
id:        PX-DM1a
file:      v2/scripts/backfill/tickets.backfill.ts
line:      42
severity:  high
command:   /compare-v1
class:     cutover-data/backfill-not-resumable
mg_class:  DM-1
detector:  data-cutover-orchestrate §1
anchor:    { table: 'tickets', where: SOURCE_FILTER, checkpointKey: null, batch: 5000, sleepMs: 0 }
v1_file:   v1/database/migrations/2024_01_01_000006_create_tickets_tables.php
v1_line:   11
v1_anchor: Schema::create('tickets', function (Blueprint $table) {
clean:     { table: 'tickets', where: SOURCE_FILTER, checkpointKey: 'tickets', batch: 1000, sleepMs: 200 }
match:     ticket
match:     checkpoint|resum|restart|throttl|sleep|lag|idempot
```

Every other backfill passes a `checkpointKey` and sleeps 200 ms between batches. The tickets run passes `null` and `0`: a crash halfway restarts at id 0, and because rows get fresh UUIDs and a plain `insert`, the restart duplicates every ticket already loaded; the 5,000-row batches with no pause lag the replica. Fix: a checkpoint key and a throttle (the window between a batch insert and its checkpoint write is closed by PX-DM5a's `legacy_id`, the natural upsert key). Proof: V374 kill at 50%, restart, no duplicates.

### PX-DM1b — Users backfill uses a plain INSERT: a resumed or repeated run fails on the unique email (not idempotent)

```defect
id:        PX-DM1b
file:      v2/scripts/backfill/users.backfill.ts
line:      23
severity:  high
command:   /compare-v1
class:     cutover-data/backfill-not-resumable
mg_class:  DM-1
detector:  data-cutover-orchestrate §1
anchor:    await target.insert('users', rows.map(mapUser));
v1_file:   v1/database/migrations/2024_01_01_000001_create_accounts_and_users.php
v1_line:   19
v1_anchor: Schema::create('users', function (Blueprint $table) {
clean:     await target.upsert('users', rows.map(mapUser), ['legacy_id'], { onlyIfOlder: 'updated_at' });
match:     users?
match:     insert|upsert|idempot|re-?run|resum|conflict
```

The checkpoint resumes after the last committed batch, but a batch that failed after the INSERT and before the checkpoint write is inserted again, and a full re-run (a re-backfill from 0, PX-DM13a) always is: `users.email` is unique in V2 and the run dies. The other tables upsert on `legacy_id`. Fix: upsert on `legacy_id`, guarded by `onlyIfOlder: 'updated_at'` because the user sync writes the same rows (an unguarded upsert is PX-DM2a's defect). Proof: V374 double run.

### PX-DM2a — Orders backfill upserts unconditionally: a snapshot row overwrites the newer version the live sync already wrote

```defect
id:        PX-DM2a
file:      v2/scripts/backfill/orders.backfill.ts
line:      51
severity:  high
command:   /compare-v1
class:     cutover-data/backfill-overwrites-newer
mg_class:  DM-2
detector:  data-cutover-orchestrate §2
anchor:    await target.upsert('orders', rows.map(mapOrder), ['legacy_id']);
v1_file:   v1/app/Http/Controllers/OrderController.php
v1_line:   63
v1_anchor: $order->fill($request->validated())->save();
clean:     await target.upsert('orders', rows.map(mapOrder), ['legacy_id'], { onlyIfOlder: 'updated_at' });
match:     orders?|upsert
match:     newer|overwrit|updated_at|version|onlyIfOlder|stale
```

V1 keeps taking order writes during the backfill and the sync applies them to V2 as they happen. The backfill reads in id order from a replica and upserts every column with no version guard, so an order edited after its batch was read is overwritten by the older snapshot. `Target.upsert` already supports `onlyIfOlder`; the invoice sync uses it. Fix: `{ onlyIfOlder: 'updated_at' }`. Proof: V374, live update between snapshot and backfill.

### PX-DM2b — Wallet backfill `ON CONFLICT DO UPDATE` has no `WHERE updated_at <` guard: a CDC-applied balance is rolled back by the snapshot

```defect
id:        PX-DM2b
file:      v2/scripts/backfill/wallets.backfill.ts
line:      20
severity:  high
command:   /compare-v1
class:     cutover-data/backfill-overwrites-newer
mg_class:  DM-2
detector:  data-cutover-orchestrate §2
anchor:    ON CONFLICT (legacy_id) DO UPDATE SET balance_minor = EXCLUDED.balance_minor, promo_balance_minor = EXCLUDED.promo_balance_minor, credit_limit_minor = EXCLUDED.credit_limit_minor, updated_at = EXCLUDED.updated_at
v1_file:   v1/app/Services/WalletService.php
v1_line:   16
v1_anchor: $wallet->balance_minor += $amountMinor;
clean:     ON CONFLICT (legacy_id) DO UPDATE SET balance_minor = EXCLUDED.balance_minor, promo_balance_minor = EXCLUDED.promo_balance_minor, credit_limit_minor = EXCLUDED.credit_limit_minor, updated_at = EXCLUDED.updated_at WHERE wallets.updated_at < EXCLUDED.updated_at
match:     wallet|balance|ON CONFLICT
match:     newer|overwrit|updated_at|guard|WHERE|stale
```

Wallet balances arrive in V2 through CDC while the backfill runs. The backfill's upsert overwrites the balance with whatever the replica snapshot held, older or not, so a top-up applied by CDC is silently undone on money. Fix: `WHERE wallets.updated_at < EXCLUDED.updated_at`. Proof: V374 variant on a balance.

### PX-DM3a — Users reconciliation masks the drift it exists to find: `-cim` upper-cases both sides and the row hash RTRIMs

```defect
id:        PX-DM3a
file:      v2/scripts/reconcile/validate.sh
line:      17
severity:  high
command:   /compare-v1
class:     cutover-data/reconcile-masking
mg_class:  DM-3
detector:  data-cutover-orchestrate §3
anchor:    -tbls norrow.users=public.users -pk email --hash '*' -cim
v1_file:   v1/app/Models/User.php
v1_line:   21
v1_anchor: return Attribute::make(set: fn (string $value) => strtolower($value));
clean:     -tbls norrow.users=public.users -pk email --comparison-fields email,name
match:     -cim|hash|DVT|data-validation|reconcil
match:     mask|case|trim|RTRIM|UPPER|hide
```

DVT's `-cim` wraps both sides in UPPER() and `--hash` applies RTRIM, so the two drifts this table actually has — e-mail case (PX-DM4b) and trailing spaces (PX-VA1a) — compare equal. A masked class proves nothing about that class (precedent 15). Fix: `--comparison-fields` with no case or trim masking. Proof: V375 seeded drift must be reported (`runtime/v375-reconciler-drift.txt`).

### PX-DM3b — Invoices are reconciled by row count only: no money aggregate at all

```defect
id:        PX-DM3b
file:      v2/scripts/reconcile/validate.sh
line:      14
severity:  high
command:   /compare-v1
class:     cutover-data/reconcile-masking
mg_class:  DM-3
detector:  data-cutover-orchestrate §3
anchor:    -tbls norrow.invoices=public.invoices --count '*'
v1_file:   v1/database/migrations/2024_01_01_000003_create_invoices_tables.php
v1_line:   20
v1_anchor: $table->decimal('total_amount', 12, 2)->default(0);
clean:     -tbls norrow.invoices=public.invoices --count '*' --sum subtotal_amount,tax_amount,total_amount --min total_amount --max total_amount
match:     invoice
match:     count only|count|sum|money|total|aggregate|reconcil
```

The orders check compares counts, money sums and a row-level comparison; the invoices check compares `COUNT(*)` and nothing else, so a wrong total or a rounding change passes as green, and the invoices read flag has no reconcile gate at all (PX-DM11a). Fix: sums, min and max on the money columns (DVT takes one comma-separated `--sum` list). Proof: V375.

### PX-DM4a — The live invoice sync overrides the backfill mapper's `issued_at` with the raw V1 value (Riyadh wall clock, no zone)

```defect
id:        PX-DM4a
file:      v2/scripts/sync/invoice-sync.ts
line:      7
severity:  high
command:   /compare-v1
class:     cutover-data/transform-mismatch
mg_class:  DM-4
detector:  data-cutover-orchestrate §4
anchor:    const doc = { ...mapInvoice(row), issued_at: row.issued_at };
v1_file:   v1/database/migrations/2024_01_01_000003_create_invoices_tables.php
v1_line:   22
v1_anchor: $table->dateTime('issued_at')->nullable();
clean:     const doc = mapInvoice(row);
match:     issued_at|sync|mapInvoice
match:     transform|mapper|backfill|zone|differ|raw|override
```

The backfill maps `issued_at` through `fromV1Local` (Riyadh → UTC). The sync spreads the same mapper and then overrides `issued_at` with the raw string, which Postgres reads as UTC: every invoice touched by the sync is stored three hours late, every backfilled one is right. Two transforms for one field. Fix: use the mapper unchanged. Proof: V376, the same row through both paths.

### PX-DM4b — The live user sync writes the raw e-mail; the backfill lower-cases it

```defect
id:        PX-DM4b
file:      v2/scripts/sync/user-sync.ts
line:      6
severity:  high
command:   /compare-v1
class:     cutover-data/transform-mismatch
mg_class:  DM-4
detector:  data-cutover-orchestrate §4
anchor:    const doc = { ...mapUser(row), email: row.email };
v1_file:   v1/app/Models/User.php
v1_line:   21
v1_anchor: return Attribute::make(set: fn (string $value) => strtolower($value));
clean:     const doc = mapUser(row);
match:     email|sync|mapUser
match:     lower|case|transform|mapper|backfill|differ|raw
```

V1 lower-cases e-mails only when the attribute is set, so accounts imported before the mutator keep mixed case. The backfill lower-cases; the sync overrides that with the raw value, so a profile edit on V1 writes `Sara@Example.com` into V2, where `CredentialsService.verify` looks users up by the lower-cased address: that user can no longer get a token from V2. Fix: use the mapper unchanged. Proof: V376.

### PX-DM5a — Migrated tickets get a new UUID and no `legacy_id`: every e-mailed `/tickets/123` link 404s

```defect
id:        PX-DM5a
file:      v2/scripts/backfill/tickets.backfill.ts
line:      27
severity:  high
command:   /compare-v1
class:     cutover-data/id-mapping-lost
mg_class:  DM-5
detector:  data-cutover-orchestrate §5
anchor:    id: randomUUID(),
v1_file:   v1/routes/web.php
v1_line:   13
v1_anchor: Route::get('/tickets/{ticket}', [PortalController::class, 'ticket'])->name('portal.tickets.show');
clean:     id: randomUUID(),\n    legacy_id: row.id,
match:     legacy_id|legacy id|ticket
match:     id|uuid|link|map|404
```

ADR-0007 keeps old ticket links working through `legacy_id`, and `TicketsService.get` resolves numeric ids through it. The backfill mapper never sets it, so every V1 id in an e-mail, a support macro or the mobile app's cache resolves to nothing. Fix: `legacy_id: row.id`. Proof: V377, the old id in URL and API.

### PX-DM5b — Invoice numbers are regenerated from the row id at backfill: the legal number on every issued invoice changes

```defect
id:        PX-DM5b
file:      v2/scripts/backfill/invoices.backfill.ts
line:      29
severity:  high
command:   /compare-v1
class:     cutover-data/id-mapping-lost
mg_class:  DM-5
detector:  data-cutover-orchestrate §5
anchor:    number: row.number === null ? null : formatInvoiceNumber(row.id, row.issued_at),
v1_file:   v1/app/Services/InvoiceService.php
v1_line:   31
v1_anchor: $invoice->number = sprintf('INV-%d-%06d', now()->year, $sequence);
clean:     number: row.number,
match:     invoice ?number|number|formatInvoiceNumber
match:     regenerat|changed|legacy|mapping|id|sequence|legal
```

V1 numbers come from a per-year sequence; they are printed on PDFs, held by the payment provider and quoted by customers. The backfill keeps the invoice id but rebuilds the number from it, so `INV-2026-000412` becomes `INV-2026-000977`. Fix: copy `row.number`. Proof: V377, provider metadata lookups.

### PX-DM6a — pgloader casts every `tinyint` to boolean, not only `tinyint(1)`: `invoice_lines.tax_category` (1–3) becomes true/false

```defect
id:        PX-DM6a
file:      v2/deploy/pgloader/invoicing.load
line:      12
severity:  high
command:   /compare-v1
class:     cutover-data/load-cast-drift
mg_class:  DM-6
detector:  data-cutover-orchestrate §6
anchor:    CAST type tinyint to boolean using tinyint-to-boolean,
v1_file:   v1/database/migrations/2024_01_01_000003_create_invoices_tables.php
v1_line:   35
v1_anchor: $table->unsignedTinyInteger('tax_category')->default(1);
clean:     CAST type tinyint when (= 1 precision) to boolean using tinyint-to-boolean,
match:     tinyint|boolean|pgloader|cast
match:     tax_category|precision|all|every|1–3|category
```

The cast rule has no `when (= 1 precision)` guard, so the three-valued `tax_category` (standard, zero-rated, exempt; V2's `InvoiceLine.taxCategory` is a smallint) is converted to `t`/`f`: COPY into the smallint column rejects the batch, and on a target pgloader creates itself the column becomes a boolean and 2 and 3 collapse to `true`. Default and custom casts are a finding on every column they touch (precedent 16). Fix: guard the rule. Proof: V375, tinyint 2 seeded.

### PX-DM6b — `datetime → timestamptz` with the session zone UTC: V1's Riyadh wall-clock `posted_at` shifts three hours

```defect
id:        PX-DM6b
file:      v2/deploy/pgloader/ledger.load
line:      9
severity:  high
command:   /compare-v1
class:     cutover-data/load-cast-drift
mg_class:  DM-6
detector:  data-cutover-orchestrate §6
anchor:    SET PostgreSQL PARAMETERS timezone to 'UTC'
v1_file:   v1/database/migrations/2024_01_01_000004_create_wallets_tables.php
v1_line:   28
v1_anchor: $table->dateTime('posted_at');
clean:     SET PostgreSQL PARAMETERS timezone to 'Asia/Riyadh'
match:     posted_at|timezone|timestamptz|datetime
match:     UTC|Riyadh|zone|shift|3 ?h
```

V1 stores naive Riyadh time. pgloader interprets a `datetime` in the Postgres session zone when it casts to `timestamptz`; this load sets UTC (the invoicing load sets Asia/Riyadh), so every wallet transaction lands three hours late and day boundaries in statements and the finance view move. Fix: the V1 zone. Proof: V375, timestamp seeded.

### PX-DM7a — `Order` has `deletedAt` but no soft-delete filter: deleted orders (backfilled with `deleted_at`) reappear in lists, counts and exports

```defect
id:        PX-DM7a
file:      v2/apps/api/src/orders/order.entity.ts
line:      7
severity:  high
command:   /compare-v1
class:     cutover-data/soft-delete-lost
mg_class:  DM-7
detector:  data-cutover-orchestrate §7
anchor:    @scoped.AccountScoped()
v1_file:   v1/app/Models/Order.php
v1_line:   19
v1_anchor: use HasFactory, SoftDeletes;
clean:     @scoped.AccountScoped()\n@scoped.SoftDeletable()
match:     soft.?delet|deleted_?at|SoftDeletable
match:     order|list|resurrect|reappear|filter
```

V1's `SoftDeletes` hides deleted orders from every query. The backfill copies `deleted_at`, the entity maps it, and nothing filters it: `@scoped.SoftDeletable()` is on `StockItem`, not on `Order`. Deleted orders come back in the list, the export and `findAndCount` totals. Soft-delete lost is a guarantee class: a Finding even in solo mode. Fix: the decorator. Proof: V378 list, count and export with soft-deleted rows present.

### PX-DM7b — SKU uniqueness now counts soft-deleted rows: re-creating a deleted SKU fails (V1 checked live rows only)

```defect
id:        PX-DM7b
file:      v2/apps/api/src/inventory/stock-item.entity.ts
line:      8
severity:  medium
command:   /compare-v1
class:     cutover-data/soft-delete-lost
mg_class:  DM-7
detector:  data-cutover-orchestrate §7
anchor:    @Unique({ properties: ['account', 'sku'] })
v1_file:   v1/app/Services/CsvImportService.php
v1_line:   21
v1_anchor: Rule::unique('stock_items', 'sku')->where('account_id', $accountId)->whereNull('deleted_at')
clean:     @Unique({ name: 'stock_items_account_sku_live', expression: 'create unique index stock_items_account_sku_live on stock_items (account_id, sku) where deleted_at is null' })
match:     unique|sku
match:     soft.?delet|deleted_at|partial|live|re-?creat
```

V1 checks SKU uniqueness against live rows (`whereNull('deleted_at')`), so a SKU deleted last year can be imported again. V2 keeps soft-deleted stock rows and puts a full unique index on `(account, sku)`: the import answers "already taken" for every resurrected SKU. Fix: a partial unique index on live rows. Proof: V378 unique check with soft-deleted rows present.

### PX-DM8a — Preflight checks orphans on every child table except `order_lines`, the one V1 left without a foreign key

```defect
id:        PX-DM8a
file:      v2/scripts/backfill/preflight.ts
line:      7
severity:  high
command:   /compare-v1
class:     cutover-data/orphans-duplicates
mg_class:  DM-8
detector:  data-cutover-orchestrate §8
anchor:    await assertNoOrphans(source, 'invoice_lines', 'invoice_id', 'invoices');
v1_file:   v1/database/migrations/2024_01_01_000002_create_orders_tables.php
v1_line:   32
v1_anchor: $table->unsignedBigInteger('order_id')->index();
clean:     await assertNoOrphans(source, 'order_lines', 'order_id', 'orders');\n  await assertNoOrphans(source, 'invoice_lines', 'invoice_id', 'invoices');
match:     orphan|order_lines|preflight
match:     foreign key|FK|orphan|order_lines|dropped|skip
```

V1's `order_lines.order_id` has no FK ("lines of purged orders were never cleaned up"). The line backfill inserts through `SELECT … FROM orders WHERE legacy_id = $7`, so an orphan line silently inserts nothing — the load reports success with rows missing. The preflight checks the three tables that do have FKs. Fix: check `order_lines`. Proof: V379 orphan count per FK.

### PX-DM8b — Duplicate e-mails (allowed in V1) are silently dropped at backfill: the second account's user never reaches V2

```defect
id:        PX-DM8b
file:      v2/scripts/backfill/users.backfill.ts
line:      22
severity:  medium
command:   /compare-v1
class:     cutover-data/orphans-duplicates
mg_class:  DM-8
detector:  data-cutover-orchestrate §8
anchor:    const rows = checks.dedupeBy(batch, (r) => r.email.toLowerCase());
v1_file:   v1/database/migrations/2024_01_01_000001_create_accounts_and_users.php
v1_line:   24
v1_anchor: $table->string('email')->index();
clean:     const rows = checks.failOnDuplicates(batch, (r) => r.email.toLowerCase(), 'users.email');
match:     dedup|duplicat|email
match:     drop|silent|second|lost|unique
```

V1's `users.email` is not unique on purpose (an accountant invited by two accounts). V2 makes it unique and the backfill keeps the first row per e-mail without a word, so the second account loses its user. The stock backfill fails loudly on duplicates with `failOnDuplicates`. Fix: fail and decide per row class. Proof: V379 duplicates per natural key.

### PX-DM9a — Invoices are loaded with explicit ids and the serial sequence is never reset: the first V2 invoice collides

```defect
id:        PX-DM9a
file:      v2/scripts/backfill/invoices.backfill.ts
line:      46
severity:  high
command:   /compare-v1
class:     cutover-data/sequence-not-reset
mg_class:  DM-9
detector:  data-cutover-orchestrate §9
anchor:    report('invoices', loaded);
v1_file:   v1/database/migrations/2024_01_01_000003_create_invoices_tables.php
v1_line:   11
v1_anchor: Schema::create('invoices', function (Blueprint $table) {
clean:     await target.resetSequence('invoices', 'id');\n  report('invoices', loaded);
match:     sequence|setval|serial|resetSequence
match:     invoice|collid|duplicate key|first insert|reset
```

The backfill keeps V1 invoice ids. Postgres' `invoices_id_seq` still starts at 1, so the first invoice V2 creates after the flip fails with a duplicate primary key — an outage at cutover. The orders and wallets loads, which also keep ids, call `target.resetSequence`; this one does not. Fix: reset after the load. Proof: V380, first insert after load.

### PX-DM9b — The ledger load says `reset no sequences`: `wallet_transactions_id_seq` stays at 1 after loading millions of explicit ids

```defect
id:        PX-DM9b
file:      v2/deploy/pgloader/ledger.load
line:      6
severity:  high
command:   /compare-v1
class:     cutover-data/sequence-not-reset
mg_class:  DM-9
detector:  data-cutover-orchestrate §9
anchor:    WITH include no drop, create no tables, data only, reset no sequences,
v1_file:   v1/database/migrations/2024_01_01_000004_create_wallets_tables.php
v1_line:   22
v1_anchor: Schema::create('wallet_transactions', function (Blueprint $table) {
clean:     WITH include no drop, create no tables, data only, reset sequences,
match:     sequence|wallet_transactions|pgloader
match:     reset|collid|duplicate key|first insert
```

pgloader resets sequences by default; this load turns it off and nothing else resets it (the tail verifier only counts). The first wallet adjustment on V2 fails on the primary key. The invoicing load keeps `reset sequences`. Fix: `reset sequences`. Proof: V380.

### PX-DM11a — `invoices.read_from = v2` has no gate: no backfill checkpoint, no reconcile requirement

```defect
id:        PX-DM11a
file:      v2/deploy/flags/cutover.yaml
line:      28
severity:  high
command:   /compare-v1
class:     cutover-data/flip-not-gated
mg_class:  DM-11
detector:  data-cutover-orchestrate §10
anchor:    requires: []
v1_file:   v1/routes/api.php
v1_line:   30
v1_anchor: Route::controller(InvoiceController::class)->prefix('invoices')->group(function () {
clean:     requires:\n      - backfill.invoices.checkpoint_complete\n      - reconcile.invoices.green
match:     invoices?\.read_from|read flag|read flip|flag
match:     gate|requires|reconcil|checkpoint|ungated
```

Orders and tickets may flip reads only when the backfill checkpoint is complete and reconcile is green. Invoices flipped with `requires: []`: nothing proved the invoices backfill complete, and the only invoices reconcile is count-only (PX-DM3b), so users read whatever V2 holds. Fix: the same two requirements. Proof: V381.

### PX-DM11b — The orders write flip is a bare flag set: V1 writers are not paused or revoked, so in-flight V1 writes land after V2 owns the rows

```defect
id:        PX-DM11b
file:      v2/scripts/cutover/flip-writes.ts
line:      6
severity:  high
command:   /compare-v1
class:     cutover-data/flip-not-gated
mg_class:  DM-11
detector:  data-cutover-orchestrate §10
anchor:    await flags.set('orders.writes_owner', 'v2');
v1_file:   v1/routes/api.php
v1_line:   25
v1_anchor: Route::patch('/{order}', 'update')->middleware('can:update,order');
clean:     await flags.setFenced('orders.writes_owner', 'v2', { pauseV1Pool: 'v1-orders-writer', revokeGrants: ['portal@%'] });
match:     writes?_owner|write flip|flip
match:     fenc|pause|revoke|in.?flight|both|split.?brain
```

The runbook (step 5) says the V1 writer pool is paused and its grants revoked before the flag moves; `FlagClient.setFenced` does exactly that. The script calls `set`, so every V1 request already past the façade commits to V1 after V2 started owning orders: writes land in both or in neither side's view. Fix: `setFenced`. Proof: V381 flip under write load, lost = 0, duplicated = 0.

### PX-DM12a — Wallets rollback is "flip the flag back": no reverse path for V2 writes, and no point of no return

```defect
id:        PX-DM12a
file:      ai/runbooks/cutover-wallets.md
line:      10
severity:  high
command:   /compare-v1
class:     cutover-data/no-reverse-path
mg_class:  DM-12
detector:  data-cutover-orchestrate §11
anchor:    5. Rollback: flip `wallets.read_from` and `wallets.writes_owner` back to `v1`.
v1_file:   v1/database/migrations/2024_01_01_000004_create_wallets_tables.php
v1_line:   11
v1_anchor: Schema::create('wallets', function (Blueprint $table) {
clean:     5. Rollback: run `scripts/sync/reverse-sync.ts --table=wallets,wallet_transactions` until it has replayed every V2 write into V1, then flip both flags back to `v1`; point of no return: dropping the V1 wallet tables, signed by the engineering lead and finance, not before 14 days of V2 writes.
match:     rollback|reverse|wallet
match:     reverse|lost|V2 writes|point of no return|replay
```

After the wallets write flip, every adjustment happens in V2 only. Flipping back to V1 then serves balances that miss every V2 movement — money lost on rollback. The orders runbook has a reverse sync and a named, signed point of no return; the wallets runbook has neither. Fix: reverse sync before the flip back, and a named point of no return. Proof: V382 rollback after N V2 writes.

### PX-DM12b — V1 order tables are dropped in the same release that flips writes (2.4.0): rollback is impossible from day one

```defect
id:        PX-DM12b
file:      v2/deploy/cutover/plan.yaml
line:      6
severity:  high
command:   /compare-v1
class:     cutover-data/no-reverse-path
mg_class:  DM-12
detector:  data-cutover-orchestrate §11
anchor:    - { step: drop-v1-order-tables, release: "2.4.0", after: orders-writes-flip }
v1_file:   v1/database/migrations/2024_01_01_000002_create_orders_tables.php
v1_line:   12
v1_anchor: Schema::create('orders', function (Blueprint $table) {
clean:     - { step: drop-v1-order-tables, release: "2.6.0", after: orders-writes-soak-14d, point_of_no_return: true, sign_off: [eng-lead, finance] }
match:     drop|v1.order.tables|plan
match:     same release|2\.4|point of no return|rollback|irreversib
```

The plan ships `orders-writes-flip` and `drop-v1-order-tables` in 2.4.0, the drop right after the flip. The orders runbook says the point of no return comes after 14 days of clean V2 writes with two sign-offs; the plan skips it. Dropping V1 objects in the release that flips writes is a finding (precedent 18). Fix: a later release, after the soak, as the named point of no return. Proof: V382.

### PX-DM13a — Orders mapping moved to v3 (channel `api` → `integration`) after the backfill started at v2; the run resumes at id 48211 without re-backfilling

```defect
id:        PX-DM13a
file:      v2/scripts/backfill/state/orders.checkpoint.json
line:      1
severity:  medium
command:   /compare-v1
class:     cutover-data/mapping-changed-mid-window
mg_class:  DM-13
detector:  data-cutover-orchestrate §12
anchor:    "last_id": 48211, "mapping_version": 2, "started_at": "2026-10-01T00:00:00Z"
v1_file:   v1/database/migrations/2024_01_01_000002_create_orders_tables.php
v1_line:   20
v1_anchor: $table->string('channel', 20)->default('portal');
clean:     "last_id": 0, "mapping_version": 3, "started_at": "2026-10-11T00:00:00Z"
match:     mapping|checkpoint|channel
match:     version|re-?backfill|resum|mid|v2|v3|48211
```

`ORDERS_MAPPING_VERSION` is 3 (2026-10-10); the checkpoint records `mapping_version: 2` from a run started 2026-10-01, and `runChunked` resumes from `last_id` without comparing versions. Orders 1–48211 keep channel `api`, later ones get `integration`. Fix: restart from 0 under v3. Proof: V376, a mapping change mid-window.

### PX-DM13b — Stock mapping moved to v2 (`pc`/`pcs` → `each`) mid-run; the checkpoint at v1 resumes at id 9120

```defect
id:        PX-DM13b
file:      v2/scripts/backfill/state/stock.checkpoint.json
line:      1
severity:  medium
command:   /compare-v1
class:     cutover-data/mapping-changed-mid-window
mg_class:  DM-13
detector:  data-cutover-orchestrate §12
anchor:    "last_id": 9120, "mapping_version": 1, "started_at": "2026-10-02T00:00:00Z"
v1_file:   v1/database/migrations/2024_01_01_000005_create_stock_items_table.php
v1_line:   20
v1_anchor: $table->string('unit', 8)->default('each');
clean:     "last_id": 0, "mapping_version": 2, "started_at": "2026-10-13T00:00:00Z"
match:     mapping|checkpoint|unit
match:     version|re-?backfill|resum|mid|v1|v2|9120
```

`STOCK_MAPPING_VERSION` became 2 on 2026-10-12; the checkpoint from 2026-10-02 is at version 1 and id 9120. Items up to 9120 keep `pc`/`pcs`, which no longer group with `each` in V2's stock list and the partner feed. Fix: restart from 0 under v2. Proof: V376.

## Cutover and strangler mechanics

### PX-CO1a — Façade routes tickets with an exact match: `/api/tickets/41`, `/reopen` and `/next` fall through to V1

```defect
id:        PX-CO1a
file:      v2/deploy/nginx/facade.conf
line:      38
severity:  high
command:   /compare-v1
class:     cutover/facade-routing-gap
mg_class:  CO-1
detector:  cutover-routing-scan §1
anchor:    location = /api/tickets {
v1_file:   v1/routes/api.php
v1_line:   53
v1_anchor: Route::apiResource('tickets', TicketController::class)->only(['index', 'store', 'show']);
clean:     location /api/tickets {
match:     tickets|location
match:     exact|=|prefix|fall.?through|V1|sub.?path
```

The ledger says tickets are V2-only. `location = /api/tickets` matches only the bare path, so every sub-path goes to `location /api/` (V1), whose ticket tables stopped receiving writes at the flip: agents see stale tickets and reopen against V1. Fix: a prefix location. Proof: V383, each ledger route on the declared side.

### PX-CO1b — Invoices are V2 for reads only, but the façade sends every method to V2: issuing runs on V2 before its write flip

```defect
id:        PX-CO1b
file:      v2/deploy/nginx/facade.conf
line:      43
severity:  high
command:   /compare-v1
class:     cutover/facade-routing-gap
mg_class:  CO-1
detector:  cutover-routing-scan §1
anchor:    location /api/invoices { proxy_pass http://v2_api; }
v1_file:   v1/routes/api.php
v1_line:   34
v1_anchor: Route::post('/{invoice}/issue', 'issue')->middleware('can:invoices.issue');
clean:     location /api/invoices { proxy_pass http://$invoices_upstream; }
match:     invoices?
match:     method|POST|issue|write|reads? only|invoices_upstream|map
```

The ledger keeps invoice writes on V1 until the write flip; the `$invoices_upstream` map (GET/HEAD → V2, everything else → V1) is defined and unused. `POST /api/invoices/{id}/issue` now runs on V2, numbering from V2's sequence table while V1 still numbers too. Fix: proxy to `$invoices_upstream`. Proof: V383 methods.

### PX-CO2a — V2 scopes the shared `norrow_session` cookie to `app.norrow.example`; V1 uses `.norrow.example`

```defect
id:        PX-CO2a
file:      v2/apps/api/src/common/session-cookie.ts
line:      7
severity:  high
command:   /compare-v1
class:     cutover/session-not-shared
mg_class:  CO-2
detector:  cutover-routing-scan §2
anchor:    domain: 'app.norrow.example',
v1_file:   v1/config/session.php
v1_line:   13
v1_anchor: 'domain' => env('SESSION_DOMAIN', '.norrow.example'),
clean:     domain: '.norrow.example',
match:     cookie|session|domain
match:     domain|shared|portal|subdomain|logged out
```

The façade serves `portal.norrow.example` and `app.norrow.example`. V1's session cookie is domain-wide; V2 re-issues the same cookie name host-only on `app.`, so a user who refreshed on a V2 route is signed out on the portal host and bounced between the two. Only routes both halves serve matter (precedent 19), and the portal shell is one. Fix: `.norrow.example`. Proof: V384, a session established on V2 valid on V1.

### PX-CO2b — V2's CSRF check expects `csrf_token` / `x-csrf-token`; the V1 portal sends Laravel's `XSRF-TOKEN` / `X-XSRF-TOKEN`

```defect
id:        PX-CO2b
file:      v2/apps/api/src/common/csrf.ts
line:      4
severity:  high
command:   /compare-v1
class:     cutover/session-not-shared
mg_class:  CO-2
detector:  cutover-routing-scan §2
anchor:    export const CSRF = { cookie: 'csrf_token', header: 'x-csrf-token' };
v1_file:   v1/resources/js/http.js
v1_line:   6
v1_anchor: axios.defaults.xsrfHeaderName = 'X-XSRF-TOKEN';
clean:     export const CSRF = { cookie: 'XSRF-TOKEN', header: 'x-xsrf-token' };
match:     csrf|xsrf
match:     cookie|header|419|mismatch|portal|token
```

The portal shell's axios calls (`resources/js/http.js`) send Laravel's XSRF pair, and so does the V2 SPA (`lib/api.ts`). The façade routes ticket writes to V2, whose double-submit check reads a different cookie and header, so every cookie-authenticated ticket write answers 419. Fix: Laravel's names. Proof: V384 CSRF across the halves.

### PX-CO3a — The orders mirror copies POST/PATCH to the V2 shadow, which sends real e-mail (shadow not side-effect-isolated)

```defect
id:        PX-CO3a
file:      v2/deploy/istio/orders-mirror.yaml
line:      12
severity:  critical
command:   /compare-v1
class:     cutover/shadow-not-isolated
mg_class:  CO-3
detector:  cutover-routing-scan §3
anchor:    - uri: { prefix: /api/orders }
v1_file:   v1/app/Observers/OrderObserver.php
v1_line:   13
v1_anchor: public function created(Order $order): void
clean:     - uri: { prefix: /api/orders }\n          method: { exact: GET }
match:     mirror|shadow
match:     POST|write|method|GET only|side.?effect|isolat|real
```

The match has a URI prefix and no method, so 10% of order placements, edits and cancellations are replayed on the shadow, whose environment points at the production SMTP relay (PX-CO3b): customers get a second confirmation for a shadow order. Shadow on a write route without isolation is a blocker even at 1% (precedent 17). The tickets mirror matches GET only. Fix: `method: { exact: GET }`. Proof: V371 with shadow on, candidate external effects = 0.

### PX-CO3b — The shadow deployment mails through the production SMTP relay (its PSP and SMS are stubbed, mail is not)

```defect
id:        PX-CO3b
file:      v2/deploy/shadow/v2-shadow.env
line:      7
severity:  critical
command:   /compare-v1
class:     cutover/shadow-not-isolated
mg_class:  CO-3
detector:  cutover-routing-scan §3
anchor:    MAIL_TRANSPORT=smtp://smtp.norrow.internal:587
v1_file:   v1/.env.example
v1_line:   14
v1_anchor: MAIL_MAILER=smtp
clean:     MAIL_TRANSPORT=smtp://mailpit.shadow.svc:1025
match:     MAIL|smtp|mail
match:     shadow|production|real|isolat|stub|sink
```

Everything else in the shadow environment is a sandbox or a WireMock stub; `MAIL_TRANSPORT` is the production relay, so any effect the shadow computes — order placed, invoice issued, ticket opened — reaches a customer's inbox. Fix: a mail sink (Mailpit). Proof: V371, shadow emits 0 external effects.

### PX-CO5a — V1 queue workers scaled to 0 while V1 still owns invoice issuing and wallet writes

```defect
id:        PX-CO5a
file:      v2/deploy/k8s/v1/queue-worker.yaml
line:      9
severity:  high
command:   /compare-v1
class:     cutover/not-reversible
mg_class:  CO-5
detector:  cutover-routing-scan §4
anchor:    replicas: 0
v1_file:   v1/app/Jobs/ProcessInvoiceIssued.php
v1_line:   14
v1_anchor: class ProcessInvoiceIssued implements ShouldQueue
clean:     replicas: 2
match:     queue.?worker|worker|replicas
match:     0|zero|scaled|cold|V1|soak|rollback
```

Invoice issuing, wallet adjustments and every V1 mail are still V1's (the plan flips them in 2.4.0 and 2.5.0), and their jobs go to this queue. With zero workers, the invoice e-mails pile up in Redis, and a rollback lands on a cold V1. Fix: keep the workers until the soak ends. Proof: V382.

### PX-CO5b — V1's scheduler CronJob is suspended before its jobs exist in V2

```defect
id:        PX-CO5b
file:      v2/deploy/k8s/v1/scheduler.yaml
line:      10
severity:  high
command:   /compare-v1
class:     cutover/not-reversible
mg_class:  CO-5
detector:  cutover-routing-scan §4
anchor:    suspend: true
v1_file:   v1/routes/console.php
v1_line:   13
v1_anchor: Schedule::command('stock:export-feed')->dailyAt('05:00')->timezone('Asia/Riyadh');
clean:     suspend: false
match:     schedul|suspend
match:     V1|cold|suspend|stopped|soak|rollback
```

`schedule:run` drives five V1 jobs: nightly invoices, credit expiry, stale-reservation release, the stock feed and the weekly report. Suspending it stops all five; V2 runs three of them (the stock feed and nightly invoices in `v2-scheduler`, the weekly report as a CronJob), and two exist nowhere in V2 (PX-JB1a, PX-JB1b), so promotional credit stops expiring and reservations stop releasing, and a rollback lands on a cold scheduler. Fix: keep V1's scheduler running until every job it runs has a V2 owner. Proof: V382.

## Proof process

### PX-PP1a — The port PR skips the V1-pinned credit-rounding parity case it would fail

```defect
id:        PX-PP1a
file:      change/v2/apps/api/test/parity/invoices.parity.spec.ts
line:      26
severity:  critical
command:   /compare-v1
class:     proof/tests-modified
mg_class:  PP-1
detector:  parity-proof-scan §1
anchor:    it.skip('matches V1 credit amounts for negative halves', async () => {
v1_file:   v1/tests/Feature/InvoiceTotalsTest.php
v1_line:   22
v1_anchor: public function test_credit_lines_round_half_away_from_zero(): void
clean:     it('matches V1 credit amounts for negative halves', async () => {
match:     skip
match:     parity|V1.?pinned|test|credit|negative
```

The working-tree change ports `creditFor` (PX-MN1a) and, in the same diff, turns the V1-pinned case that compares it with V1 into `it.skip`. ADR-0003 forbids it; a skipped V1-pinned test is evidence of nothing (precedent 20). Fix: revert the skip and fix the rounding. Proof: V386, the V1-pinned set unmodified, no new skips.

### PX-PP1b — The port PR re-records the V1 golden to V2's output (13.08 → 13.09)

```defect
id:        PX-PP1b
file:      change/v2/apps/api/test/parity/__golden__/invoice-totals.json
line:      4
severity:  critical
command:   /compare-v1
class:     proof/tests-modified
mg_class:  PP-1
detector:  parity-proof-scan §1
anchor:    "tax": "13.09"
v1_file:   v1/tests/Feature/InvoiceTotalsTest.php
v1_line:   19
v1_anchor: $this->assertSame('13.08', number_format($totals['tax'], 2, '.', ''));
clean:     "tax": "13.08"
match:     golden|re-?record|13\.(?:08|09)
match:     golden|re-?record|baseline|V1|changed
```

The golden says it was recorded from V1's `test_tax_is_rounded_per_line_then_summed`, which asserts 13.08. The change rewrites it to 13.09 — V2's per-total result (PX-MN2a) — with no ADR and no `changes_baseline`, so the parity suite now certifies the defect. Fix: restore V1's value. Proof: V386 (`runtime/v386-coverage.txt`).

### PX-PP2a — The pricing parity corpus has no negative quantity: V1's credit-line branch is never reached

```defect
id:        PX-PP2a
file:      v2/apps/api/test/parity/corpus/pricing.corpus.json
line:      4
severity:  high
command:   /compare-v1
class:     proof/corpus-misses-v1-branches
mg_class:  PP-2
detector:  parity-proof-scan §2
anchor:    "cases": [
v1_file:   v1/app/Services/PricingService.php
v1_line:   11
v1_anchor: if ($quantity < 0) {
clean:     "cases": [\n    { "unit_price": 2.25, "quantity": -1, "discount_rate": null },\n    { "unit_price": 0.05, "quantity": -3, "discount_rate": 0.1 },
match:     corpus|pricing
match:     branch|negative|credit|coverage|reach
```

Eight cases, all positive. V1's `lineNet` has a separate branch for credit lines (no discount re-applied), which the corpus never enters, so the parity run cannot see a difference there (`runtime/v387-v1-branch-coverage.txt`: 0.50 against a declared floor of 0.80). Fix: cases that reach the branch. Proof: V387, V1 branch coverage ≥ the floor.

### PX-PP2b — The SLA parity corpus has no overdue ticket: the breached branch (and PX-NUM1a) is never exercised

```defect
id:        PX-PP2b
file:      v2/apps/api/test/parity/corpus/sla.corpus.json
line:      4
severity:  high
command:   /compare-v1
class:     proof/corpus-misses-v1-branches
mg_class:  PP-2
detector:  parity-proof-scan §2
anchor:    "cases": [
v1_file:   v1/app/Services/SlaService.php
v1_line:   16
v1_anchor: if ($minutesLeft < 0) {
clean:     "cases": [\n    { "minutes_left": -1 },\n    { "minutes_left": -61 },\n    { "minutes_left": -90 },
match:     corpus|sla
match:     branch|negative|overdue|breach|coverage|reach
```

All six cases are within SLA. V1's breached branch — the one where `intdiv` and `Math.floor` disagree — is never reached, so the suite would pass with PX-NUM1a in place. Fix: negative `minutes_left` cases. Proof: V387.

### PX-PP3a — V2 silently fixes V1's `array_filter` key bug in invoice `lines`; the contract records no known V1 bug, no ADR, no `changes_baseline`

```defect
id:        PX-PP3a
file:      ai/migration/contracts/invoices.md
line:      20
severity:  medium
command:   /compare-v1
class:     proof/v1-bug-unrecorded
mg_class:  PP-3
detector:  parity-proof-scan §3
anchor:    - none recorded
v1_file:   v1/app/Models/Invoice.php
v1_line:   45
v1_anchor: 'lines' => array_filter($lines, fn (array $l) => $l['quantity'] != 0),
clean:     - KB-1 (ADR-0015, `changes_baseline: invoices.lines-shape`): V1's `array_filter` keeps array keys, so an invoice with a zero-quantity line serialises `lines` as an object; V2 returns a list.
clean_add: ai/decisions/ADR-0015-invoice-lines-list-shape.md
match:     array_filter|lines|known V1 bug
match:     object|list|keys|unrecorded|ADR|changes_baseline|silent
```

V1 drops zero-quantity lines with `array_filter` and no `array_values`, so such an invoice's `lines` is a JSON object (`{"0": …, "2": …}`). V2 filters and returns a list. A fixed V1 bug is an intentional break and needs the same record as any other (precedent 3); here the contract says "none recorded" and no ADR exists. Fix: record it (contract KB entry, ADR, baseline). Proof: V362 diff + ledger cross-check.

### PX-PP3b — V2 escapes `%` and `_` in ticket search where V1 did not; unrecorded behaviour change

```defect
id:        PX-PP3b
file:      ai/migration/contracts/tickets.md
line:      20
severity:  medium
command:   /compare-v1
class:     proof/v1-bug-unrecorded
mg_class:  PP-3
detector:  parity-proof-scan §3
anchor:    - none recorded
v1_file:   v1/app/Http/Controllers/TicketController.php
v1_line:   17
v1_anchor: ->when($request->filled('q'), fn ($q) => $q->where('subject', 'like', '%'.$request->input('q').'%'))
clean:     - KB-1 (ADR-0016, `changes_baseline: tickets.search-literal-wildcards`): V1 put the raw term into `LIKE '%…%'`, so `_` and `%` acted as wildcards; V2 escapes them.
clean_add: ai/decisions/ADR-0016-ticket-search-escapes-wildcards.md
match:     search|like|wildcard|escape
match:     unrecorded|known V1 bug|ADR|changes_baseline|silent|differ
```

V1's search treats `_` as "any character" (`INV_12` matches `INV-12`); V2's `escapeLike` makes it literal, so the same query returns different tickets. Probably the better behaviour — and still a V1 ≠ V2 difference on a contract path with "none recorded" in Known V1 bugs and no ADR. Fix: record it. Proof: V362.

### PX-CO4a — The parity comparator ignores every `total` field: the money it exists to compare

```defect
id:        PX-CO4a
file:      v2/apps/api/test/parity/tolerance.json
line:      4
severity:  high
command:   /compare-v1
class:     proof/comparator-blind-spot
mg_class:  CO-4
detector:  parity-proof-scan §5
anchor:    "$..total",
v1_file:   v1/app/Services/InvoiceService.php
v1_line:   34
v1_anchor: $invoice->total_amount = $totals['total'];
clean:     (delete line)
match:     tolerance|ignore|comparator
match:     total|money|wider|mask|blind
```

`$..total` in the ignore list strips `total` from every orders, invoices and wallets body before comparison, so no HTTP parity suite can see a wrong `total` (PX-MN3's float among them). An ignore entry must be noise shown by a control-vs-control run (precedent 10); a total is not. Fix: remove it. Proof: V385, one seeded mismatch per tolerance key must be reported.

### PX-CO4b — Tickets parity compares status codes only

```defect
id:        PX-CO4b
file:      v2/apps/api/test/parity/tolerance.json
line:      11
severity:  high
command:   /compare-v1
class:     proof/comparator-blind-spot
mg_class:  CO-4
detector:  parity-proof-scan §5
anchor:    "tickets": "status"
v1_file:   v1/app/Http/Controllers/TicketController.php
v1_line:   33
v1_anchor: return response()->json(['data' => $ticket->load('tags', 'messages')->toApi()]);
clean:     "tickets": "status+body"
match:     tickets?|compare|tolerance
match:     status.?only|status|body|blind
```

Orders, invoices and wallets compare status and body; tickets compare the status alone, so the missing `tags` key (PX-NULL1a), the shifted priority (PX-VO1b) and cross-tenant results (PX-AZ3a) all pass. Fix: `status+body`. Proof: V385.

### PX-PP5 — The parity job checks V1 out and never sets `V1_REPO_PATH`: every `describeV1` suite is skipped and the job is green

```defect
id:        PX-PP5
file:      v2/.github/workflows/ci.yml
line:      60
severity:  high
command:   /test-audit
class:     testing/v1-gated-suite-skipped
mg_class:  PP-5
detector:  suite-execution-scan §2 (2c) (testing) ← parity-proof-scan §4 consumes
anchor:    - run: pnpm --filter @norrow/api test:parity
v1_file:   v1/phpunit.xml
v1_line:   6
v1_anchor: <testsuite name="Feature">
clean:     - run: pnpm --filter @norrow/api test:parity\n        env:\n          V1_REPO_PATH: ${{ github.workspace }}/v1-snapshot
match:     V1_REPO_PATH|describeV1|HAS_V1|parity
match:     skip|never set|unset|not run|NOT-RUN|green
```

`describeV1 = HAS_V1 ? describe : describe.skip`, and `HAS_V1` is `Boolean(process.env.V1_REPO_PATH)`. The `parity` job clones V1 into `v1-snapshot` but does not export the variable, so all seven parity tests skip and the job passes (`runtime/ci-parity-log.txt`); the `contract` job sets it. Owned by testing `suite-execution-scan` §2 (2c); `parity-proof-scan` §4 marks every parity claim NOT-RUN. Fix: set the variable on the step. Proof: V388, the CI log shows k > 0 V1-gated tests executed.

## UI parity (Section-0 machinery)

### PX-UI1a — "Statements" nav entry dropped: the V2 page exists (`/wallet/statements`) and nothing links to it

```defect
id:        PX-UI1a
file:      v2/apps/web/src/nav.tsx
line:      8
severity:  medium
command:   /compare-v1
class:     ui/affordance-dropped
mg_class:  MG-UI-1
detector:  parity-auditor Section 0 (nav tree)
anchor:    { to: '/wallet', label: 'nav.wallet' },
v1_file:   v1/resources/views/layouts/nav.blade.php
v1_line:   6
v1_anchor: <li><a href="{{ route('portal.wallet.statements') }}">{{ __('nav.statements') }}</a></li>
clean:     { to: '/wallet', label: 'nav.wallet' },\n  { to: '/wallet/statements', label: 'nav.statements' },
match:     statement|nav
match:     nav|menu|link|missing|dropped|orphan|unreachable
```

V1's portal nav links the wallet statements page. V2 routes `/wallet/statements` but its `items` list stops at Wallet, so the page is reachable only by typing the URL. Halt 13 (nav leaf dropped). Fix: the nav entry. Proof: Section-0 nav-tree diff.

### PX-UI1b — Ticket detail lost its "Reopen" action for solved and closed tickets (the API route exists)

```defect
id:        PX-UI1b
file:      v2/apps/web/src/pages/TicketDetailPage.tsx
line:      36
severity:  medium
command:   /compare-v1
class:     ui/affordance-dropped
mg_class:  MG-UI-1
detector:  parity-auditor Section 0 (per-axis enumeration)
anchor:    </main>
v1_file:   v1/resources/views/portal/tickets/show.blade.php
v1_line:   11
v1_anchor: <form method="POST" action="/api/tickets/{{ $ticket->id }}/reopen">
clean:     {['solved', 'closed'].includes(ticket.status) && (\n        <button type="button" onClick={() => void api.post(`/tickets/${id}/reopen`)}>\n          {t('reopen')}\n        </button>\n      )}\n    </main>
match:     reopen
match:     button|action|missing|dropped|ui|page
```

V1's ticket page shows a Reopen form on solved and closed tickets. V2 ported `POST /api/tickets/{id}/reopen` and the `reopen` string in both catalogs, but the page renders no control, so customers open a new ticket instead. Fix: the button. Proof: Section-0 per-axis enumeration (actions per page).

### PX-UI2a — Order filters live in component state: Back, reload and a shared link lose them (V1 kept them in the query string)

```defect
id:        PX-UI2a
file:      v2/apps/web/src/pages/OrdersPage.tsx
line:      21
severity:  medium
command:   /compare-v1
class:     ui/state-drift
mg_class:  MG-UI-2
detector:  parity-auditor halt 12 (UI state)
anchor:    const [status, setStatus] = useState<string[]>([]);
v1_file:   v1/resources/views/portal/orders.blade.php
v1_line:   7
v1_anchor: <form method="GET" action="{{ route('portal.orders') }}" class="filters">
clean:     const [status, setStatus] = useUrlState<string[]>('status', []);
match:     filter|status|useState|useUrlState
match:     url|query string|back|reload|lost|state|shared link
```

V1's filter form is a GET form, so filters survive Back, reload and a pasted link. V2 keeps `page` in the URL with `useUrlState` but `status` in `useState`, so the filter resets on every navigation. `InvoicesPage` does it right. Fix: `useUrlState`. Proof: halt 12 state check (navigate away and back).

### PX-UI2b — "Place order" stays enabled while the request is in flight: a double click places two orders (V1 disabled it on submit)

```defect
id:        PX-UI2b
file:      v2/apps/web/src/pages/PlaceOrderPage.tsx
line:      29
severity:  medium
command:   /compare-v1
class:     ui/state-drift
mg_class:  MG-UI-2
detector:  parity-auditor halt 12 (UI state)
anchor:    <button type="submit">{t('place')}</button>
v1_file:   v1/resources/views/portal/orders/create.blade.php
v1_line:   6
v1_anchor: onsubmit="this.querySelector('button[type=submit]').disabled = true"
clean:     <button type="submit" disabled={placing}>{t('place')}</button>
match:     submit|place|button
match:     disabl|double|twice|pending|in.?flight
```

V1 disables the submit button on submit. V2 tracks `placing` (it shows a spinner) and never disables the button, so a double click places and reserves stock for two orders. Fix: `disabled={placing}`. Proof: halt 12 state check (double submit).

## Decoys (must not be reported)

Each decoy is correct code that looks like a seeded defect. A finding pinned to one is a false positive by construction.

| id | file:line | probes | why it is correct |
|----|-----------|--------|-------------------|
| PX-DECOY-01 | `v2/apps/api/src/inventory/stock.controller.ts:21` | PX-RT1a | Renamed route with a `pair-map.tsv` row and ADR-0004; same query and shape. |
| PX-DECOY-02 | `v1/routes/api.php:60` | PX-RT1a | Dead V1 route: zero callers on six axes, deprecated by ADR-0009, ledger F009 `deprecated` (precedent 2). |
| PX-DECOY-03 | `v2/apps/api/src/users/me.controller.ts:14` | PX-AZ1a | V1's per-route `auth:sanctum` is covered by the global `APP_GUARD` (JwtAuthGuard); no `@Public()`. |
| PX-DECOY-04 | `v2/deploy/nginx/facade.conf:57` | PX-AZ1a | The `signed` + `auth` guard moved to the façade (`auth_request`, ADR-0005, pair-map `moved-to-gateway`). |
| PX-DECOY-05 | `v2/apps/api/src/auth/auth.controller.ts:29` | PX-ER1a | 422 → 400 on token login is declared: ADR-0006 + `changes_baseline` on ledger F008. |
| PX-DECOY-06 | `v2/packages/contracts/src/tickets.ts:7` | PX-VO1a | V2-only value `merged` with tolerant consumers (ADR-0008 + `changes_baseline` on ledger F003). |
| PX-DECOY-07 | `v2/apps/web/src/locales/en/orders.json:13` | PX-VO1a | Label-only change; the wire and stored value stay `packed` (low for label-only). |
| PX-DECOY-08 | `v2/apps/web/src/lib/format.ts:4` | PX-MN1b | Display-only rounding of an already-rounded string; nothing is stored or charged from it (precedent 11). |
| PX-DECOY-09 | `v2/apps/api/src/reports/reports.service.ts:53` | PX-MN1a | Half-even chosen by ADR-0012 for a reported statistic, with `changes_baseline`. |
| PX-DECOY-10 | `v2/apps/api/src/tickets/tag-suggest.ts:7` | PX-ORD1a | Order is "unspecified" in the contract and the only consumer sorts client-side (precedent 7). |
| PX-DECOY-11 | `v2/apps/api/src/notifications/ticket-notifications.subscriber.ts:26` | PX-SE1a | V1's `TicketObserver::created` effect moved to a subscriber in the notifications module; it also skips replicated writes. |
| PX-DECOY-12 | `v2/apps/api/src/migrations/Migration20261002000000_invoice_audit.ts:19` | PX-SE1b | V1's observer-written audit row comes from a V2 DB trigger (ADR-0014). |
| PX-DECOY-13 | `v2/deploy/k8s/cronjobs/weekly-report.yaml:9` | PX-JB1a | The weekly report cron moved to a Kubernetes CronJob with the same zone (ADR-0013). |
| PX-DECOY-14 | `v2/scripts/backfill/wallet-transactions.backfill.ts:8` | PX-DM1a | Append-only table: one-shot load up to a high-water mark plus counts, no dual write needed (precedent 12). |
| PX-DECOY-15 | `v2/deploy/cdc/wallets-cdc.yaml:15` | PX-DM3a | A declared, bounded CDC lag with the reconcile window set to match (precedent 13). |
| PX-DECOY-16 | `v2/scripts/backfill/tickets.backfill.ts:9` | PX-DM7a | Soft-deleted tickets filtered at backfill with a reason (ADR-0010). |
| PX-DECOY-17 | `v2/apps/api/src/tickets/tickets.controller.ts:12` | PX-VA1a | The tickets module does trim and empty → null; this line is the one module that matches V1. |
| PX-DECOY-18 | `v2/deploy/istio/tickets-mirror.yaml:13` | PX-CO3a | The tickets mirror copies GET only. |
| PX-DECOY-19 | `v2/apps/api/test/parity/wallets.parity.spec.ts:7` | PX-PP1a | A test moved 1:1 from V1 with a `test-map.tsv` row; same request and expectation. |
| PX-DECOY-20 | `ai/migration/contracts/orders.md:22` | PX-PP3a | A V1 bug fixed with ADR-0011 + `changes_baseline` + a Known V1 bugs entry (precedent 3). |
| PX-DECOY-21 | `v2/apps/api/test/fixtures/orders.test-data.ts:5` | PX-VO1a | V1's stored vocabulary inside `*.test-data.ts`, input to the mapper tests. |
| PX-DECOY-22 | `v2/apps/web/src/locales/ar/tickets.json:7` | PX-I18N | Complete Arabic plural set (zero, one, two, few, many, other). |
| PX-DECOY-23 | `v2/apps/api/src/common/not-found.filter.ts:7` | PX-RT1a | Laravel `Route::fallback` ↔ the Nest catch-all filter: same 404 status; only V1's message text for a missing model differs, which is tolerated (precedent 9; ADR-0017, pair-map row `ANY /api/{*}`). |
| PX-DECOY-24 | `v1/lang/en/emails.php:5` | PX-RT1a | A translation string that looks like a route; V1 registers no such route. |
| PX-DECOY-25 | `v2/.github/workflows/ci.yml:26` | PX-PP5 | The contract job does set `V1_REPO_PATH` for its suite. |
| PX-DECOY-26 | `v2/apps/api/src/wallets/wallets.controller.ts:39` | PX-AZ1a | Restored twin of PX-AZ1a: the credit-limit handler keeps V1’s `permission:wallets.adjust`. |
| PX-DECOY-27 | `v2/apps/api/src/invoices/invoice.entity.ts:6` | PX-AZ3a | Restored twin of PX-AZ3a: `Invoice` keeps the account filter. |
| PX-DECOY-28 | `v2/apps/api/src/inventory/stock.repository.ts:34` | PX-AZ3b | Restored twin of PX-AZ3b: the raw low-stock query carries the account predicate. |
| PX-DECOY-29 | `v2/packages/contracts/src/invoices.ts:4` | PX-VO1a | Restored twin of PX-VO1a: the invoice status set equals V1’s `InvoiceStatus`. |
| PX-DECOY-30 | `v2/packages/contracts/src/orders.ts:43` | PX-VA1b | Restored twin of PX-VA1b: the update body keeps V1’s rule. |
| PX-DECOY-31 | `v2/apps/api/src/common/money.ts:6` | PX-MN1a | Restored twin of the rounding seeds: decimal.js `ROUND_HALF_UP` is half away from zero, PHP’s mode. |
| PX-DECOY-32 | `v2/apps/api/src/jobs/invoice-schedules.ts:13` | PX-JB1a | Restored twin of PX-JB1a: the nightly invoice run matches V1’s time, zone and single-runner. |
| PX-DECOY-33 | `v2/apps/api/src/invoices/invoice.entity.ts:8` | PX-DM7b | Restored twin: V1’s `unique([account_id, number])` kept on `Invoice`. |
| PX-DECOY-34 | `v2/apps/web/src/pages/InvoicesPage.tsx:18` | PX-UI2a | Restored twin of PX-UI2a: invoice filters live in the URL. |
| PX-DECOY-35 | `v2/deploy/flags/cutover.yaml:9` | PX-DM11a | Restored twin of PX-DM11a: the orders read flag is gated on checkpoint + reconcile. |
| PX-DECOY-36 | `ai/runbooks/cutover-orders.md:16` | PX-DM12a | Restored twin of PX-DM12a: reverse sync plus a named, signed point of no return. |

```decoy
id:       PX-DECOY-01
file:     v2/apps/api/src/inventory/stock.controller.ts
line:     21
command:  /compare-v1
class:    decoy/PX-RT1a
anchor:   @Get('alerts')
match:    alerts|low-stock|route
match:    renam|dropped|missing|404
```
```decoy
id:       PX-DECOY-02
file:     v1/routes/api.php
line:     60
command:  /compare-v1
class:    decoy/PX-RT1a
anchor:   Route::get('/reports/legacy-aging', [ReportController::class, 'legacyAging'])->middleware('can:reports.view');
match:    legacy-aging|legacyAging
match:    dropped|missing|not ported|404
```
```decoy
id:       PX-DECOY-03
file:     v2/apps/api/src/users/me.controller.ts
line:     14
command:  /compare-v1 /security-audit
class:    decoy/PX-AZ1a
anchor:   @Get('me')
match:    \bme\b|auth
match:    guard|unauthenticat|public|no auth|missing
```
```decoy
id:       PX-DECOY-04
file:     v2/deploy/nginx/facade.conf
line:     57
command:  /compare-v1 /security-audit
class:    decoy/PX-AZ1a
anchor:   auth_request /internal/authz/export;
match:    export
match:    auth|signed|guard|missing|dropped
```
```decoy
id:       PX-DECOY-05
file:     v2/apps/api/src/auth/auth.controller.ts
line:     29
command:  /compare-v1
class:    decoy/PX-ER1a
anchor:   token(@Body(new ValidationPipe({ whitelist: true })) body: TokenDto) {
match:    token|ValidationPipe
match:    400|422|status|error
```
```decoy
id:       PX-DECOY-06
file:     v2/packages/contracts/src/tickets.ts
line:     7
command:  /compare-v1
class:    decoy/PX-VO1a
anchor:   export const TicketStatus = z.enum(['open', 'pending', 'solved', 'closed', 'merged']);
match:    merged|status
match:    enum|vocabular|value|V2.only
```
```decoy
id:       PX-DECOY-07
file:     v2/apps/web/src/locales/en/orders.json
line:     13
command:  /compare-v1
class:    decoy/PX-VO1a
anchor:   "status_packed": "Ready to ship",
match:    packed|Ready to ship
match:    label|enum|vocabular|renam
```
```decoy
id:       PX-DECOY-08
file:     v2/apps/web/src/lib/format.ts
line:     4
command:  /compare-v1
class:    decoy/PX-MN1b
anchor:   return new Intl.NumberFormat(locale, { style: 'currency', currency, maximumFractionDigits: 2 }).format(Number(amount));
match:    Intl|NumberFormat|format
match:    round|half|float|Number\(
```
```decoy
id:       PX-DECOY-09
file:     v2/apps/api/src/reports/reports.service.ts
line:     53
command:  /compare-v1
class:    decoy/PX-MN1a
anchor:   Decimal.ROUND_HALF_EVEN
match:    HALF_EVEN|half.even|average
match:    round|half|banker
```
```decoy
id:       PX-DECOY-10
file:     v2/apps/api/src/tickets/tag-suggest.ts
line:     7
command:  /compare-v1
class:    decoy/PX-ORD1a
anchor:   { limit: 10 }
match:    tag|suggest
match:    order|sort|unspecified|ORDER BY
```
```decoy
id:       PX-DECOY-11
file:     v2/apps/api/src/notifications/ticket-notifications.subscriber.ts
line:     26
command:  /compare-v1
class:    decoy/PX-SE1a
anchor:   'ticket-opened-sms'
match:    ticket.?opened|sms|observer
match:    dropped|missing|lost|moved
```
```decoy
id:       PX-DECOY-12
file:     v2/apps/api/src/migrations/Migration20261002000000_invoice_audit.ts
line:     19
command:  /compare-v1
class:    decoy/PX-SE1b
anchor:   this.addSql('create trigger invoices_audit_trg after update on invoices for each row execute function invoice_audit_row();');
match:    audit|trigger
match:    dropped|missing|observer|lost
```
```decoy
id:       PX-DECOY-13
file:     v2/deploy/k8s/cronjobs/weekly-report.yaml
line:     9
command:  /compare-v1
class:    decoy/PX-JB1a
anchor:   schedule: "0 7 * * 0"
match:    weekly|report|cron
match:    not ported|missing|schedul|zone
```
```decoy
id:       PX-DECOY-14
file:     v2/scripts/backfill/wallet-transactions.backfill.ts
line:     8
command:  /compare-v1
class:    decoy/PX-DM1a
anchor:   export async function verifyWalletTransactions(
match:    wallet_transactions|append
match:    dual.?write|checkpoint|resum|idempot|CDC
```
```decoy
id:       PX-DECOY-15
file:     v2/deploy/cdc/wallets-cdc.yaml
line:     15
command:  /compare-v1
class:    decoy/PX-DM3a
anchor:   exclude_updated_within_seconds: 30
match:    lag|exclude|cdc
match:    mask|drift|reconcil|hide
```
```decoy
id:       PX-DECOY-16
file:     v2/scripts/backfill/tickets.backfill.ts
line:     9
command:  /compare-v1
class:    decoy/PX-DM7a
anchor:   const SOURCE_FILTER = 'deleted_at IS NULL';
match:    deleted_at|soft.?delet
match:    lost|filter|dropped|missing
```
```decoy
id:       PX-DECOY-17
file:     v2/apps/api/src/tickets/tickets.controller.ts
line:     12
command:  /compare-v1
class:    decoy/PX-VA1a
anchor:   @UsePipes(new NormalizeInputPipe({ trim: true, emptyToNull: true }))
match:    NormalizeInputPipe|trim
match:    missing|global|empty
```
```decoy
id:       PX-DECOY-18
file:     v2/deploy/istio/tickets-mirror.yaml
line:     13
command:  /compare-v1
class:    decoy/PX-CO3a
anchor:   method: { exact: GET }
match:    mirror|shadow
match:    POST|write|isolat|side.?effect
```
```decoy
id:       PX-DECOY-19
file:     v2/apps/api/test/parity/wallets.parity.spec.ts
line:     7
command:  /compare-v1
class:    decoy/PX-PP1a
anchor:   describeV1('wallet adjust parity', () => {
match:    wallet|test
match:    modif|moved|changed|rewritten|V1.?pinned
```
```decoy
id:       PX-DECOY-20
file:     ai/migration/contracts/orders.md
line:     22
command:  /compare-v1
class:    decoy/PX-PP3a
anchor:   - KB-1 (ADR-0011,
match:    order number|KB-1|max\(id\)
match:    unrecorded|silent|differ|bug
```
```decoy
id:       PX-DECOY-21
file:     v2/apps/api/test/fixtures/orders.test-data.ts
line:     5
command:  /compare-v1
class:    decoy/PX-VO1a
anchor:   status: 'cancelled'
match:    cancell?ed
match:    enum|vocabular|spelling|drift
```
```decoy
id:       PX-DECOY-22
file:     v2/apps/web/src/locales/ar/tickets.json
line:     7
command:  /compare-v1 /frontend-audit
class:    decoy/PX-I18N
anchor:   "open_count_few": "{{count}} تذاكر مفتوحة",
match:    plural|open_count
match:    arabic|missing|form|few|many
```
```decoy
id:       PX-DECOY-23
file:     v2/apps/api/src/common/not-found.filter.ts
line:     7
command:  /compare-v1
class:    decoy/PX-RT1a
anchor:   @Catch(NotFoundException, NotFoundError)
match:    fallback|not.?found|404
match:    missing|dropped|route
```
```decoy
id:       PX-DECOY-24
file:     v1/lang/en/emails.php
line:     5
command:  /compare-v1
class:    decoy/PX-RT1a
anchor:   'track' => 'Track it any time at /api/orders/:id/track or from the portal.',
match:    track
match:    route|endpoint|missing|dropped
```
```decoy
id:       PX-DECOY-25
file:     v2/.github/workflows/ci.yml
line:     26
command:  /compare-v1 /test-audit
class:    decoy/PX-PP5
anchor:   V1_REPO_PATH: ${{ github.workspace }}/v1-snapshot
match:    V1_REPO_PATH|contract
match:    skip|unset|never|not run
```
```decoy
id:       PX-DECOY-26
file:     v2/apps/api/src/wallets/wallets.controller.ts
line:     39
command:  /compare-v1 /security-audit
class:    decoy/PX-AZ1a
anchor:   @Permissions('wallets:adjust')
match:    credit.?limit|wallets?[.:]adjust
match:    permission|authori[sz]|widen|missing
```
```decoy
id:       PX-DECOY-27
file:     v2/apps/api/src/invoices/invoice.entity.ts
line:     6
command:  /compare-v1 /security-audit
class:    decoy/PX-AZ3a
anchor:   @scoped.AccountScoped()
match:    invoice
match:    tenant|account|scope|cross
```
```decoy
id:       PX-DECOY-28
file:     v2/apps/api/src/inventory/stock.repository.ts
line:     34
command:  /compare-v1 /security-audit
class:    decoy/PX-AZ3b
anchor:   where account_id = ? and quantity_available <= reorder_level
match:    lowStock|raw|stock
match:    tenant|account|scope|predicate
```
```decoy
id:       PX-DECOY-29
file:     v2/packages/contracts/src/invoices.ts
line:     4
command:  /compare-v1
class:    decoy/PX-VO1a
anchor:   export const InvoiceStatus = z.enum(['draft', 'issued', 'paid', 'void']);
match:    invoice.?status|enum
match:    drift|vocabular|value|spelling
```
```decoy
id:       PX-DECOY-30
file:     v2/packages/contracts/src/orders.ts
line:     43
command:  /compare-v1
class:    decoy/PX-VA1b
anchor:   po_number: z.string().max(30).regex(/^[A-Z0-9-]+$/).nullable().optional(),
match:    po_number
match:    max|regex|validation|rule
```
```decoy
id:       PX-DECOY-31
file:     v2/apps/api/src/common/money.ts
line:     6
command:  /compare-v1
class:    decoy/PX-MN1a
anchor:   return new Decimal(value).toDecimalPlaces(scale, Decimal.ROUND_HALF_UP).toNumber();
match:    ROUND_HALF_UP|roundHalfAway|round
match:    half|negative|toward|mode
```
```decoy
id:       PX-DECOY-32
file:     v2/apps/api/src/jobs/invoice-schedules.ts
line:     13
command:  /compare-v1
class:    decoy/PX-JB1a
anchor:   @Cron('0 30 1 * * *', { name: 'invoices-issue-nightly', timeZone: 'Asia/Riyadh' })
match:    nightly|invoices?.issue|cron
match:    zone|missing|schedul|overlap
```
```decoy
id:       PX-DECOY-33
file:     v2/apps/api/src/invoices/invoice.entity.ts
line:     8
command:  /compare-v1
class:    decoy/PX-DM7b
anchor:   @Unique({ properties: ['account', 'number'] })
match:    unique|number
match:    constraint|lost|missing|soft
```
```decoy
id:       PX-DECOY-34
file:     v2/apps/web/src/pages/InvoicesPage.tsx
line:     18
command:  /compare-v1
class:    decoy/PX-UI2a
anchor:   const [status, setStatus] = useUrlState<string[]>('status', []);
match:    filter|status|useUrlState
match:    state|url|lost|back
```
```decoy
id:       PX-DECOY-35
file:     v2/deploy/flags/cutover.yaml
line:     9
command:  /compare-v1
class:    decoy/PX-DM11a
anchor:   - reconcile.orders.green
match:    orders?\.read_from|flag
match:    gate|ungated|requires|reconcil
```
```decoy
id:       PX-DECOY-36
file:     ai/runbooks/cutover-orders.md
line:     16
command:  /compare-v1
class:    decoy/PX-DM12a
anchor:   8. Point of no return (named, signed by the engineering lead and finance)
match:    rollback|point of no return|reverse
match:    missing|no reverse|undeclared|lost
```

## Measured

Measured 2026-10-18 with the migration pack's `pair-inventory.py` (`python3 -I`), every run into a scratch `--out`; the
write check printed 0 new files under both trees on every run. Candidate rows carry a `lane` column (`# CANDIDATE lane diff
key attr v1 v2 v1_at v2_at tags excerpt`).
- `run.sh --verify`: 92 V2 anchors + 92 V1 anchors + 36 decoys resolve; the clean pair derives (92 replacements, 2
  overlay files); `v1/` hashes to the pin.
- `find v1 -name "*.php"`: 83 PHP files — the first PHP in any benchmark fixture (eval § 3.6 measured 0).
- **Record.** `ai/migration/v1-inventory/*.tsv` is the engine's own `--record-v1 --live-v1 --v1=v1 --pin=<pin>` output
  (copied in; the engine never writes into the fixture), plus the two deliberate faults (`I-ENUM` sha, `I-SCHED` hash).
- **Calibration** (`--calibrate --live-v1` on `run.sh --clean-pair`, with `ai/migration/pair-map.tsv`): **0 rows on all 11
  lanes** (I-ROUTES 44/36 rows per side, I-AUTHZ 44/36, I-RULES 46/44, I-ENUM 8/8, I-ERR 5/5, I-SIDE 8/8, I-SCHED 5/5,
  I-SCOPE 12/12, I-SCHEMA 139/153, I-MONEY 5/5, I-CONF 3/3). The pair-map carries the decoys' ADR rows: V1-key renames and
  removals, policy-ability vocabulary, V2-only acknowledgements (`-` in the v1-key column) and attribute acceptances.
- **Paired** (`--v1=v1 --v2=v2 --live-v1` on the fixture root, without the `change/` overlay): 34 candidate rows, every
  one caused by a seed (the clean pair diffs to 0). V1-ONLY/V2-ONLY/CHANGED per lane and the seeds behind them:
  - I-ROUTES 2/0/0 — PX-RT1a, PX-RT1b · I-AUTHZ 2/0/4 — PX-RT1a, PX-RT1b, PX-AZ1a, PX-AZ1b, PX-AZ2a, PX-AZ2b
  - I-RULES 0/0/6 — PX-VA1a (`GLOBAL trim_strings`, `empty_to_null`: the pipe sits in a function nothing calls),
    PX-VA1b (`po_number` max, regex), PX-VO1b (ticket `priority` `in`, POST and PATCH)
  - I-ENUM 0/0/4 — PX-VO1a, PX-VO1b (`type:` and `col:`) · I-ERR 1/0/0 — PX-ER1a (`code:order_not_editable`)
  - I-SIDE 2/0/0 — PX-SE1a (`order.updated`), PX-SE1b (`wallet.updated`) · I-SCHED 2/0/0 — PX-JB1a, PX-JB1b
  - I-SCOPE 0/0/2 — PX-AZ3a (`table:ticket tenant`), PX-DM7a (`table:order soft_delete`)
  - I-SCHEMA 2/0/1 — PX-DM10a (`derived:order.line_count`), PX-DM10b (`fk:ticket_message on_delete`), PX-HC1a
    (`view:finance_invoice_totals`)
  - I-MONEY 1/1/2 — PX-MN1b (`area:order` float-tofixed), PX-MN2b (`area:wallet` modes; `allocateCents` orphaned),
    PX-MN1a (`area:pricing`: `creditFor` exists only in the `change/` overlay) · I-CONF 0/0/2 — PX-SD1a, PX-TZ1a
  - 25 distinct seeds, 0 rows without a seed. Lane seeds read only by their detector §: PX-RT2a/RT2b (page base, query
    parser), PX-AZ3b (raw SQL predicate), PX-ER1b (first-error), PX-SD1b (currency), PX-MN2a, PX-NUM1a/NUM1b, PX-TZ1b,
    PX-SE2a/SE2b, PX-HC1b, PX-DM7b.
- **Solo** (`--v2=v2 --v1-inventory=ai/migration/v1-inventory`): the same rows on every checked lane; `I-ENUM` tagged
  `stale-v1-inventory (74e3de7b0c6f vs pin 61cb5c927438)`, `I-SCHED` `blocked (extractor changed since record;
  re-record)`, verdict ceiling `GO-UNVERIFIED` — the solo key's expectations.

## Integrator requests

- **IR-1 — calibration is a regression gate.** Re-run `--calibrate` on `run.sh --clean-pair` after any lane-module change;
  a non-zero lane is an extractor asymmetry, never a seed.
- **IR-2 — re-record on extractor change.** The recorded inventory carries the extractor hashes of the record run. A later
  `lanes_laravel.py` edit turns every solo lane `blocked` (correctly); re-run `--record-v1 --live-v1`, re-apply the two faults
  with the build-notes generator (`~/.claude/refract-program/build-notes/port-pair/gen.py`) and re-check the solo anchors.
- **IR-3 — `score.py` credits only the V2 anchor.** A finding that cites the V1 line (`v1/routes/api.php:27 — duplicate
  route not ported`) is UNMATCHED today. `score.py` should accept `v1_file`/`v1_line` as a second match location for a
  ```defect block that declares them (benchmarks/score.py is outside this task).
- **IR-4 — `/compare-v1` invocation.** The key assumes § 4.9's signature (`--whole-repo --v1= --v2=`, and
  `--v1-inventory=` for solo). If the rewrite lands another flag shape, update both `Invocation:` lines, not the seeds.

