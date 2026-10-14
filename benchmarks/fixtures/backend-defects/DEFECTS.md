# Seeded defects — `backend-defects`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Lumen Orders` — a NestJS 11 / Fastify API, an Express 5 admin console, a Django/DRF billing service with Celery and APScheduler and a Go/gin storefront edge, with a committed OpenAPI spec, a drifted generated one, a CI spec-diff job and an offline runtime-oracle lane.
The HTTP contract, the validation boundary, the edge error mapping, the wire format of money, ids and time, job and
schedule lifecycles and state transitions — seeded across four service roots, the spec and CI — plus
17 hand-offs to the security, database, performance, code-quality, observability and distributed-systems audits, and
55 decoys: correct siblings that look like a seeded defect and must NOT be reported.

Invocation: /backend-audit --whole-repo
Invocation[/security-audit]: /security-audit
Invocation[/db-audit]: /db-audit
Invocation[/perf-audit]: /perf-audit --whole-repo
Invocation[/quality-audit]: /quality-audit --whole-repo
Invocation[/obs-audit]: /obs-audit --whole-repo
Invocation[/ds-audit]: /ds-audit --whole-repo
Stage with: --git — the audits read the history for their context map, and a whole-repo run on a copy with no base
branch says so with the flag instead of leaving the diff lookup to fail.

Eval source: Track A batch 5, item 24 (`eval-batch5-backend.md` § 5.11). Classes follow the owning skills' own §
numbering (`templates/packs/backend/skills/*/SKILL.md`; the routed rows name their owner's skill and §). Roots:
`apps/api` (NestJS 11.1 on `@nestjs/platform-fastify`, MikroORM 6.4, class-validator 0.15, BullMQ 6.3, `@nestjs/schedule`
6.1 on `cron` 4.4, `@nestjs/swagger`, xstate 5, a Mercurius GraphQL schema; the validation pipe is an `APP_PIPE`
**subclass** — `AppValidationPipe extends ValidationPipe` — the filter an `APP_FILTER` catch-all, a response-envelope
interceptor, a pagination kernel, an outbound-HTTP wrapper and an idempotency interceptor, as on the real repo the eval
measured), `apps/admin` (Express 5.1 + zod 4 + multer 2, `pg`), `services/billing-py` (Django 6.1 + DRF 3.18 + Celery
5.6 + APScheduler 3.11 + `transitions`), `services/edge-go` (Go 1.27, gin 1.12, `net/http` ServeMux on an internal port,
robfig/cron v3, go-retryablehttp). Contract: `ai/api-conventions.md` (statuses, the envelope, strict vs tolerant
readers, money as decimal strings, RFC 9745 deprecation) and `openapi/openapi.yaml` (P1: every status, method and
envelope finding cites one of them). Versions: `pnpm-lock.yaml` pins Nest 11.1.6, Fastify 5.4.0, class-validator 0.15.1,
`@nestjs/schedule` 6.1.3, cron 4.4.0, Express 5.1.0, zod 4.1.5; Python and Go pin in `requirements.txt` and `go.mod`.
Process zones: `apps/api/Dockerfile` sets `TZ=America/New_York`, `services/edge-go/Dockerfile` `TZ=Europe/London`; the
API runs 3 replicas (`deploy/api-deployment.yaml`).

**The runtime lane is scored offline.** `.refract-fixture/runtime/` holds transcripts of the U-tier oracles in the
shape each tool prints, as `ci-defects` holds its `gh api` response shapes — **authored to match the seeded code on the
pinned versions, not captured from a run** (nothing in this tree is installed or booted): `failure-matrix.txt` (V345, the ten failure classes through the
real bootstrap of both Node apps — the e2e harness `apps/api/test/pricing.e2e-spec.ts` imports the real `AppModule` and
`configureApp`), `coercion-table.txt` (V341), `round-trip.txt` (V339) and `schemathesis-junit.xml` (`--checks all`;
**`API Links: 0 covered`**, so the stateful phase is `NOT-RUN`, never PASS). A row whose oracle is in a transcript is
settled from it; without the transcript it is `Unconfirmed` with the request written out — never PASS.

Departures from the eval, stated so a reader can audit them:
- **Routed owners follow the task**: security, database, performance, code-quality, observability and
  distributed-systems. The eval's two devops rows (a lazily read PSP secret, `migrator.up()` in `main.ts` with three
  replicas) are not seeded; two performance rows (an outbound call with no timeout, a fully buffered upload) and two
  observability rows (a 500 with no capture, a lost stack) take the slots.
- **`job-lifecycle-scan` §3 has two lanes.** Its diff lane needs `BASE=<base-branch>`, so a `--whole-repo` run
  prints that lane `N/A`. Its whole-repo **3w** lane (added in backend 2.0.1 from IR-4 below) prints the two static
  seeds: a processor reading a field its producer never sets, and a task that gained a required argument.
- **Spec drift is evidence, not a separate seed**: `openapi/openapi.generated.yaml` differs from the committed spec in
  four places (201 on the preview action, `total` string → number, `partnerReference` no longer required, 204 on the
  subscription DELETE). Each difference is credited to the code seed that causes it (BD-HC-1a, BD-WF-1b, BD-HC-10b,
  BD-HC-1c); §10's own seeds are the gate that cannot fail (`oasdiff` without `--fail-on`, `npx @tufin/oasdiff`) and the
  decorator that lies.
- **HC §11 carries five seeds** (Express 5 boot syntax and query parser on the admin app, a Fastify `onRequest` hook
  reading the body, a module-scope DataLoader, a `[T!]!` list) and **HC §1 five**; every other § carries two or three.
- **The project param decorator that wraps `@Body` with a pipe is a decoy** (BD-DECOY-02): `@ZodBody(schema)` is
  `Body(new ZodValidationPipe(schema))` over a `.strict()` zod schema, so the body is validated and unknown keys are
  rejected. `dto-types.py` sees no `@Body` param at that site; the `/backend-audit` wiring map (F3) prints the decorator
  with its use count and tells VB §1/§8 to read the pipe — reading it clears the row. Reporting it as "a body the
  global pipe never sees" is the false positive this decoy measures.

Ownership and scoring. Seven runs, seven results rows, each staged in its own copy. **`/backend-audit`** (the
`Invocation:` line) scores the 109 backend rows: a whole-repo run dispatches all six detectors
(`validation-boundary-scan`, `edge-error-scan`, `http-contract-scan`, `wire-format-scan`, `job-lifecycle-scan`,
`state-transition-scan`) after its wiring map. The 17 `BD-HO-*` hand-off rows are scored **only under their owner** —
`/security-audit` (3), `/db-audit` (2), `/perf-audit` (3), `/quality-audit` (4), `/obs-audit` (2), `/ds-audit` (3) — and
`/backend-audit` must list each as a routed row (`→ <owner> (k)`), never grade it; a `/backend-audit` finding on them is
UNMATCHED, not credited. The decoys all name `/backend-audit`.

Secrets. None. Every credential is an environment reference or a `canary-placeholder`; hosts are `*.example.test`;
lockfile integrity hashes are placeholders. No exploit payload is in the tree.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap. If you edit fixture source, regenerate this key.


## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| BD-VB-1a | `apps/api/src/pricing/pricing.controller.ts:17` | high | `/backend-audit` | validation/union-body-object-metatype |
| BD-VB-1b | `apps/api/src/orders/orders.controller.ts:33` | high | `/backend-audit` | validation/array-body-array-metatype |
| BD-VB-2a | `apps/api/src/orders/dto/create-order.dto.ts:10` | high | `/backend-audit` | validation/validate-nested-no-type |
| BD-VB-2b | `apps/api/src/delivery/dto/bulk-status.dto.ts:10` | high | `/backend-audit` | validation/type-no-validate-nested |
| BD-VB-3a | `apps/api/src/reports/reports.controller.ts:17` | high | `/backend-audit` | validation/implicit-conversion-boolean |
| BD-VB-3b | `apps/api/src/customers/dto/list-customers.query.ts:13` | high | `/backend-audit` | validation/type-boolean-query |
| BD-VB-4a | `apps/admin/src/routes/users.routes.ts:10` | high | `/backend-audit` | validation/zod-coerce-boolean |
| BD-VB-4b | `apps/api/src/tickets/dto/update-ticket.dto.ts:7` | medium | `/backend-audit` | validation/isenum-numeric-enum-key |
| BD-VB-4c | `services/billing-py/billing_service/settings.py:51` | high | `/backend-audit` | validation/env-bool-truthy-string |
| BD-VB-4d | `services/edge-go/internal/http/cart.go:12` | medium | `/backend-audit` | validation/gin-required-zero |
| BD-VB-5a | `apps/api/src/products/dto/update-product.dto.ts:7` | high | `/backend-audit` | validation/optional-admits-null-500 |
| BD-VB-5b | `apps/api/src/tickets/dto/update-ticket.dto.ts:12` | high | `/backend-audit` | validation/optional-admits-null-500 |
| BD-VB-6a | `apps/api/src/common/app-validation.pipe.ts:10` | medium | `/backend-audit` | validation/unknown-keys-stripped-silently |
| BD-VB-6b | `services/edge-go/internal/http/quotes.go:20` | medium | `/backend-audit` | validation/go-decoder-unknown-fields |
| BD-VB-7a | `apps/api/src/orders/orders-search.controller.ts:10` | medium | `/backend-audit` | validation/named-primitive-query-array |
| BD-VB-7b | `apps/api/src/inventory/inventory.controller.ts:11` | medium | `/backend-audit` | validation/named-primitive-body-object |
| BD-VB-8a | `apps/api/src/main.ts:15` | high | `/backend-audit` | validation/microservice-no-inherit-app-config |
| BD-VB-8b | `apps/api/src/cart-sync/cart-sync.gateway.ts:20` | high | `/backend-audit` | validation/gateway-no-pipe |
| BD-VB-8c | `apps/api/src/legacy/legacy-routes.ts:15` | high | `/backend-audit` | validation/raw-adapter-route |
| BD-VB-9a | `apps/api/src/products/dto/create-product.dto.ts:13` | medium | `/backend-audit` | validation/no-each-array |
| BD-VB-9b | `apps/api/src/imports/import-row.validator.ts:19` | medium | `/backend-audit` | validation/groups-skip-ungrouped |
| BD-EE-1a | `apps/admin/src/app.ts:35` | high | `/backend-audit` | edge/catch-all-flattens-status |
| BD-EE-1b | `apps/api/src/files/files.plugin.ts:10` | high | `/backend-audit` | edge/fastify-scope-error-handler-flattens |
| BD-EE-2a | `apps/api/src/common/filters/global-exception.filter.ts:10` | high | `/backend-audit` | edge/orm-not-found-unmapped-name-collision |
| BD-EE-2b | `apps/api/src/ledger/ledger.errors.ts:2` | high | `/backend-audit` | edge/domain-error-family-unmapped |
| BD-EE-3a | `apps/api/src/payments/payments-exception.filter.ts:10` | high | `/backend-audit` | edge/express-api-on-fastify |
| BD-EE-3b | `apps/api/src/attachments/attachments.controller.ts:2` | high | `/backend-audit` | edge/platform-express-interceptor-on-fastify |
| BD-EE-4a | `services/edge-go/cmd/edge/main.go:15` | high | `/backend-audit` | edge/gin-new-no-recovery |
| BD-EE-4b | `services/edge-go/cmd/edge/main.go:20` | medium | `/backend-audit` | edge/servemux-no-recover |
| BD-EE-5a | `apps/admin/src/routes/invoices.routes.ts:26` | high | `/backend-audit` | edge/express5-send-status-number |
| BD-EE-5b | `services/edge-go/internal/http/internal_ops.go:25` | high | `/backend-audit` | edge/go-http-error-no-return |
| BD-EE-5c | `apps/api/src/exports/exports.controller.ts:17` | high | `/backend-audit` | edge/res-without-passthrough-returns |
| BD-EE-6a | `services/billing-py/billing_service/settings.py:34` | high | `/backend-audit` | edge/drf-no-exception-handler |
| BD-EE-6b | `services/edge-go/internal/http/orders.go:18` | medium | `/backend-audit` | edge/gin-bind-writes-400 |
| BD-EE-7a | `apps/api/src/carts/carts.service.ts:12` | medium | `/backend-audit` | edge/object-body-breaks-envelope |
| BD-EE-7b | `apps/api/src/quotas/quotas.service.ts:12` | medium | `/backend-audit` | edge/thrown-object-literal |
| BD-EE-8a | `apps/admin/src/routes/psp-proxy.routes.ts:15` | medium | `/backend-audit` | edge/upstream-status-passed-through |
| BD-EE-8b | `services/edge-go/internal/upstream/rates.go:20` | medium | `/backend-audit` | edge/upstream-status-passed-through |
| BD-HC-1a | `apps/api/src/quotes/quotes.controller.ts:10` | medium | `/backend-audit` | http/action-post-201 |
| BD-HC-1b | `apps/api/src/carts/carts.controller.ts:10` | medium | `/backend-audit` | http/action-post-201 |
| BD-HC-1c | `apps/api/src/subscriptions/subscriptions.controller.ts:11` | medium | `/backend-audit` | http/204-with-body |
| BD-HC-1d | `apps/admin/src/routes/coupons.routes.ts:16` | low | `/backend-audit` | http/201-no-location |
| BD-HC-1e | `services/billing-py/billing/views.py:39` | low | `/backend-audit` | http/201-no-location |
| BD-HC-2a | `apps/api/src/orders/orders.controller.ts:27` | high | `/backend-audit` | http/missing-resource-200-null |
| BD-HC-2b | `services/billing-py/billing/views.py:19` | high | `/backend-audit` | http/missing-resource-200-null |
| BD-HC-2c | `apps/admin/src/routes/invoices.routes.ts:20` | high | `/backend-audit` | http/missing-resource-200-null |
| BD-HC-3a | `apps/admin/src/app.ts:17` | medium | `/backend-audit` | http/catch-all-parser-no-415 |
| BD-HC-3b | `apps/api/src/imports/imports.plugin.ts:7` | medium | `/backend-audit` | http/catch-all-content-type-parser |
| BD-HC-4a | `apps/api/src/orders/order-actions.controller.ts:11` | high | `/backend-audit` | http/unsafe-get |
| BD-HC-4b | `apps/admin/src/routes/users.routes.ts:23` | high | `/backend-audit` | http/unsafe-get |
| BD-HC-5a | `apps/api/src/warehouses/warehouses.controller.ts:30` | medium | `/backend-audit` | http/put-merges |
| BD-HC-5b | `apps/api/src/notifications/dto/update-notification-prefs.dto.ts:11` | high | `/backend-audit` | http/patch-default-wipes |
| BD-HC-5c | `services/billing-py/billing/views.py:47` | medium | `/backend-audit` | http/put-forced-partial |
| BD-HC-6a | `apps/api/src/common/idempotency/idempotency.interceptor.ts:30` | high | `/backend-audit` | http/idempotency-key-not-scoped |
| BD-HC-6b | `apps/api/src/common/idempotency/idempotency.interceptor.ts:34` | high | `/backend-audit` | http/idempotency-no-fingerprint |
| BD-HC-7a | `apps/api/src/activity/activity-feed.controller.ts:39` | medium | `/backend-audit` | http/pagination-no-tiebreak |
| BD-HC-7b | `apps/admin/src/routes/audit-log.routes.ts:9` | high | `/backend-audit` | http/limit-unbounded |
| BD-HC-7c | `services/billing-py/billing/views.py:26` | medium | `/backend-audit` | http/drf-unordered-pagination |
| BD-HC-8a | `apps/api/src/orders/orders-bulk.controller.ts:11` | high | `/backend-audit` | http/batch-partial-failure-hidden |
| BD-HC-8b | `services/billing-py/billing/views_batch.py:12` | high | `/backend-audit` | http/batch-partial-failure-hidden |
| BD-HC-9a | `apps/admin/src/routes/legacy.routes.ts:9` | low | `/backend-audit` | http/deprecation-draft-syntax |
| BD-HC-9b | `apps/api/src/legacy/deprecation.hook.ts:6` | low | `/backend-audit` | http/sunset-before-deprecation |
| BD-HC-10a | `.github/workflows/api.yml:25` | high | `/backend-audit` | http/spec-gate-no-fail-on |
| BD-HC-10b | `apps/api/src/quotes/quote-preview.dto.ts:17` | medium | `/backend-audit` | http/spec-optional-server-requires |
| BD-HC-10c | `apps/api/package.json:11` | medium | `/backend-audit` | http/spec-diff-npm-placeholder |
| BD-HC-11a | `apps/admin/src/routes/invoices.routes.ts:15` | critical | `/backend-audit` | http/express5-optional-param-throws-at-boot |
| BD-HC-11b | `apps/admin/src/routes/invoices.routes.ts:9` | high | `/backend-audit` | http/express5-simple-query-parser |
| BD-HC-11c | `apps/api/src/tenancy/tenant.hook.ts:14` | high | `/backend-audit` | http/onrequest-reads-body |
| BD-HC-11d | `apps/api/src/graphql/loaders.ts:11` | high | `/backend-audit` | http/dataloader-module-scope |
| BD-HC-11e | `apps/api/src/graphql/catalog.graphql:12` | medium | `/backend-audit` | http/graphql-nonnull-list-blast-radius |
| BD-HC-12a | `services/edge-go/internal/upstream/geo.go:19` | medium | `/backend-audit` | http/go-body-not-closed |
| BD-HC-12b | `apps/admin/src/services/psp-capture.ts:11` | medium | `/backend-audit` | http/post-follows-redirect |
| BD-HC-12c | `services/billing-py/billing/exports.py:11` | medium | `/backend-audit` | http/python-stream-not-closed |
| BD-HC-13a | `apps/admin/src/routes/uploads.routes.ts:14` | medium | `/backend-audit` | http/multipart-field-order |
| BD-HC-13b | `apps/api/src/documents/documents.controller.ts:17` | medium | `/backend-audit` | http/multipart-field-order |
| BD-HC-13c | `apps/api/src/storage/storage.service.ts:25` | medium | `/backend-audit` | http/partial-upload-completed |
| BD-WF-1a | `services/billing-py/billing_service/settings.py:42` | high | `/backend-audit` | wire/drf-decimal-as-float |
| BD-WF-1b | `apps/api/src/orders/order.mapper.ts:16` | high | `/backend-audit` | wire/decimal-to-number |
| BD-WF-2a | `apps/api/src/ledger/ledger-entry.entity.ts:10` | high | `/backend-audit` | wire/bigint-as-number |
| BD-WF-2b | `services/edge-go/internal/upstream/catalog.go:27` | high | `/backend-audit` | wire/go-any-float64 |
| BD-WF-3a | `apps/api/src/fx/fx.routes.ts:22` | high | `/backend-audit` | wire/fastify-response-schema-truncates |
| BD-WF-3b | `apps/api/src/invoices/invoices.controller.ts:10` | high | `/backend-audit` | wire/serializer-drops-field |
| BD-WF-4a | `services/billing-py/billing/serializers.py:8` | medium | `/backend-audit` | wire/output-rounding-half-even |
| BD-WF-4b | `services/billing-py/billing/tax.py:8` | high | `/backend-audit` | wire/quantize-no-rounding-mode |
| BD-WF-5a | `apps/api/src/payments/capture.producer.ts:15` | high | `/backend-audit` | wire/float-money-in-queue |
| BD-WF-5b | `services/billing-py/billing/services.py:18` | high | `/backend-audit` | wire/float-money-in-queue |
| BD-WF-6a | `apps/api/src/invoices/dto/create-invoice.dto.ts:15` | medium | `/backend-audit` | wire/calendar-date-as-instant |
| BD-WF-6b | `services/edge-go/internal/http/slots.go:12` | medium | `/backend-audit` | wire/go-time-parse-no-zone |
| BD-WF-7a | `services/billing-py/billing_service/settings.py:48` | high | `/backend-audit` | wire/django-use-tz-false |
| BD-WF-7b | `services/billing-py/billing/views_feed.py:13` | high | `/backend-audit` | wire/cursor-precision-lost |
| BD-JL-1a | `apps/api/src/pricing/reprice.producer.ts:15` | high | `/backend-audit` | jobs/entity-in-payload |
| BD-JL-1b | `services/billing-py/billing/services.py:12` | medium | `/backend-audit` | jobs/model-in-payload |
| BD-JL-2a | `apps/api/src/invoices/invoice-pdf.processor.ts:14` | medium | `/backend-audit` | jobs/deleted-record-fails |
| BD-JL-2b | `services/billing-py/billing/tasks.py:10` | medium | `/backend-audit` | jobs/deleted-record-fails |
| BD-JL-3a | `apps/api/src/settlement/settlement.processor.ts:25` | high | `/backend-audit` | jobs/payload-field-never-set |
| BD-JL-3b | `services/billing-py/billing/tasks.py:22` | high | `/backend-audit` | jobs/task-signature-drift |
| BD-JL-4a | `apps/api/src/settlement/settlement.scheduler.ts:12` | critical | `/backend-audit` | jobs/cron-self-overlap-money |
| BD-JL-4b | `services/edge-go/internal/jobs/sync.go:14` | high | `/backend-audit` | jobs/robfig-no-skip |
| BD-JL-5a | `services/billing-py/billing/scheduler.py:12` | high | `/backend-audit` | jobs/misfire-default-skips |
| BD-JL-5b | `apps/api/src/invoices/invoicing.scheduler.ts:12` | high | `/backend-audit` | jobs/in-process-no-catch-up |
| BD-JL-6a | `apps/api/src/payouts/payout-cutoff.scheduler.ts:12` | high | `/backend-audit` | jobs/schedule-zone-dst |
| BD-JL-6b | `services/edge-go/internal/jobs/sync.go:20` | medium | `/backend-audit` | jobs/schedule-zone-dst |
| BD-JL-7a | `apps/api/src/notifications/receipt.worker.ts:12` | medium | `/backend-audit` | jobs/failure-discarded |
| BD-JL-7b | `services/billing-py/billing/reports_tasks.py:5` | medium | `/backend-audit` | jobs/ignore-result-then-polled |
| BD-ST-1a | `services/billing-py/billing/refunds.py:20` | critical | `/backend-audit` | transitions/illegal-event-then-refund |
| BD-ST-1b | `apps/api/src/orders/order-workflow.service.ts:26` | critical | `/backend-audit` | transitions/illegal-event-then-refund |
| BD-ST-1c | `apps/api/src/orders/order-workflow.service.ts:18` | high | `/backend-audit` | transitions/illegal-event-answered-success |
| BD-ST-2a | `services/billing-py/billing/disputes.py:12` | high | `/backend-audit` | transitions/wildcard-reopens-terminal |
| BD-ST-2b | `apps/api/src/webhooks/psp-webhook.handler.ts:29` | high | `/backend-audit` | transitions/direct-status-write-bypasses-machine |
| BD-HO-DB-a | `apps/api/src/orders/place-order.use-case.ts:19` | high | `/db-audit` | database/enqueue-inside-transaction |
| BD-HO-DB-b | `services/billing-py/billing/signals.py:11` | high | `/db-audit` | database/model-callback-enqueue-before-commit |
| BD-HO-CQ-a | `apps/admin/src/services/geo.ts:11` | medium | `/quality-audit` | code-quality/outbound-status-unchecked |
| BD-HO-CQ-b | `apps/api/src/fx/fx.client.ts:13` | medium | `/quality-audit` | code-quality/response-cast-unchecked |
| BD-HO-CQ-c | `apps/api/src/payments/psp-amount.ts:4` | high | `/quality-audit` | code-quality/minor-units-hard-coded |
| BD-HO-CQ-d | `apps/admin/src/routes/uploads.routes.ts:27` | medium | `/quality-audit` | code-quality/temp-file-left-on-failure |
| BD-HO-DS-a | `apps/api/src/payments/psp.client.ts:6` | high | `/ds-audit` | distributed-systems/library-retries-post |
| BD-HO-DS-b | `services/edge-go/internal/upstream/notify.go:22` | high | `/ds-audit` | distributed-systems/library-retries-post |
| BD-HO-DS-c | `apps/api/src/invoices/issue-invoice.use-case.ts:20` | high | `/ds-audit` | distributed-systems/commit-then-publish |
| BD-HO-SEC-a | `apps/api/src/refunds/refund-lines.service.ts:18` | high | `/security-audit` | security/repeated-key-cap |
| BD-HO-SEC-b | `apps/admin/src/routes/imports.routes.ts:7` | high | `/security-audit` | security/upload-no-size-cap |
| BD-HO-SEC-c | `services/edge-go/internal/http/orders.go:24` | high | `/security-audit` | security/stack-in-error-body |
| BD-HO-PERF-a | `services/billing-py/billing/psp.py:6` | high | `/perf-audit` | performance/outbound-no-timeout |
| BD-HO-PERF-b | `apps/api/src/media/media.controller.ts:13` | medium | `/perf-audit` | performance/upload-fully-buffered |
| BD-HO-PERF-c | `apps/api/src/notifications/digest.scheduler.ts:11` | medium | `/perf-audit` | performance/cron-every-replica |
| BD-HO-OBS-a | `apps/api/src/common/filters/global-exception.filter.ts:63` | medium | `/obs-audit` | observability/5xx-without-capture |
| BD-HO-OBS-b | `apps/api/src/payments/psp.client.ts:21` | medium | `/obs-audit` | observability/stack-lost |

### Coverage by detector §

One row per detector §; every backend § carries at least two seeds (`wire-format-scan` §8, the clock seam, is an enabler and never a finding, so it has none). Routed rows are listed under their owner and scored only in that owner's run.

| detector § | classes | seeded | ids |
|------------|---------|--------|-----|
| `validation-boundary-scan §1` | validation/array-body-array-metatype, validation/union-body-object-metatype | 2 | BD-VB-1a, BD-VB-1b |
| `validation-boundary-scan §2` | validation/type-no-validate-nested, validation/validate-nested-no-type | 2 | BD-VB-2a, BD-VB-2b |
| `validation-boundary-scan §3` | validation/implicit-conversion-boolean, validation/type-boolean-query | 2 | BD-VB-3a, BD-VB-3b |
| `validation-boundary-scan §4` | validation/env-bool-truthy-string, validation/gin-required-zero, validation/isenum-numeric-enum-key, validation/zod-coerce-boolean | 4 | BD-VB-4a, BD-VB-4b, BD-VB-4c, BD-VB-4d |
| `validation-boundary-scan §5` | validation/optional-admits-null-500 | 2 | BD-VB-5a, BD-VB-5b |
| `validation-boundary-scan §6` | validation/go-decoder-unknown-fields, validation/unknown-keys-stripped-silently | 2 | BD-VB-6a, BD-VB-6b |
| `validation-boundary-scan §7` | validation/named-primitive-body-object, validation/named-primitive-query-array | 2 | BD-VB-7a, BD-VB-7b |
| `validation-boundary-scan §8` | validation/gateway-no-pipe, validation/microservice-no-inherit-app-config, validation/raw-adapter-route | 3 | BD-VB-8a, BD-VB-8b, BD-VB-8c |
| `validation-boundary-scan §9` | validation/groups-skip-ungrouped, validation/no-each-array | 2 | BD-VB-9a, BD-VB-9b |
| `edge-error-scan §1` | edge/catch-all-flattens-status, edge/fastify-scope-error-handler-flattens | 2 | BD-EE-1a, BD-EE-1b |
| `edge-error-scan §2` | edge/domain-error-family-unmapped, edge/orm-not-found-unmapped-name-collision | 2 | BD-EE-2a, BD-EE-2b |
| `edge-error-scan §3` | edge/express-api-on-fastify, edge/platform-express-interceptor-on-fastify | 2 | BD-EE-3a, BD-EE-3b |
| `edge-error-scan §4` | edge/gin-new-no-recovery, edge/servemux-no-recover | 2 | BD-EE-4a, BD-EE-4b |
| `edge-error-scan §5` | edge/express5-send-status-number, edge/go-http-error-no-return, edge/res-without-passthrough-returns | 3 | BD-EE-5a, BD-EE-5b, BD-EE-5c |
| `edge-error-scan §6` | edge/drf-no-exception-handler, edge/gin-bind-writes-400 | 2 | BD-EE-6a, BD-EE-6b |
| `edge-error-scan §7` | edge/object-body-breaks-envelope, edge/thrown-object-literal | 2 | BD-EE-7a, BD-EE-7b |
| `edge-error-scan §8` | edge/upstream-status-passed-through | 2 | BD-EE-8a, BD-EE-8b |
| `http-contract-scan §1` | http/201-no-location, http/204-with-body, http/action-post-201 | 5 | BD-HC-1a, BD-HC-1b, BD-HC-1c, BD-HC-1d, BD-HC-1e |
| `http-contract-scan §2` | http/missing-resource-200-null | 3 | BD-HC-2a, BD-HC-2b, BD-HC-2c |
| `http-contract-scan §3` | http/catch-all-content-type-parser, http/catch-all-parser-no-415 | 2 | BD-HC-3a, BD-HC-3b |
| `http-contract-scan §4` | http/unsafe-get | 2 | BD-HC-4a, BD-HC-4b |
| `http-contract-scan §5` | http/patch-default-wipes, http/put-forced-partial, http/put-merges | 3 | BD-HC-5a, BD-HC-5b, BD-HC-5c |
| `http-contract-scan §6` | http/idempotency-key-not-scoped, http/idempotency-no-fingerprint | 2 | BD-HC-6a, BD-HC-6b |
| `http-contract-scan §7` | http/drf-unordered-pagination, http/limit-unbounded, http/pagination-no-tiebreak | 3 | BD-HC-7a, BD-HC-7b, BD-HC-7c |
| `http-contract-scan §8` | http/batch-partial-failure-hidden | 2 | BD-HC-8a, BD-HC-8b |
| `http-contract-scan §9` | http/deprecation-draft-syntax, http/sunset-before-deprecation | 2 | BD-HC-9a, BD-HC-9b |
| `http-contract-scan §10` | http/spec-diff-npm-placeholder, http/spec-gate-no-fail-on, http/spec-optional-server-requires | 3 | BD-HC-10a, BD-HC-10b, BD-HC-10c |
| `http-contract-scan §11` | http/dataloader-module-scope, http/express5-optional-param-throws-at-boot, http/express5-simple-query-parser, http/graphql-nonnull-list-blast-radius, http/onrequest-reads-body | 5 | BD-HC-11a, BD-HC-11b, BD-HC-11c, BD-HC-11d, BD-HC-11e |
| `http-contract-scan §12` | http/go-body-not-closed, http/post-follows-redirect, http/python-stream-not-closed | 3 | BD-HC-12a, BD-HC-12b, BD-HC-12c |
| `http-contract-scan §13` | http/multipart-field-order, http/partial-upload-completed | 3 | BD-HC-13a, BD-HC-13b, BD-HC-13c |
| `wire-format-scan §1` | wire/decimal-to-number, wire/drf-decimal-as-float | 2 | BD-WF-1a, BD-WF-1b |
| `wire-format-scan §2` | wire/bigint-as-number, wire/go-any-float64 | 2 | BD-WF-2a, BD-WF-2b |
| `wire-format-scan §3` | wire/fastify-response-schema-truncates, wire/serializer-drops-field | 2 | BD-WF-3a, BD-WF-3b |
| `wire-format-scan §4` | wire/output-rounding-half-even, wire/quantize-no-rounding-mode | 2 | BD-WF-4a, BD-WF-4b |
| `wire-format-scan §5` | wire/float-money-in-queue | 2 | BD-WF-5a, BD-WF-5b |
| `wire-format-scan §6` | wire/calendar-date-as-instant, wire/go-time-parse-no-zone | 2 | BD-WF-6a, BD-WF-6b |
| `wire-format-scan §7` | wire/cursor-precision-lost, wire/django-use-tz-false | 2 | BD-WF-7a, BD-WF-7b |
| `job-lifecycle-scan §1` | jobs/entity-in-payload, jobs/model-in-payload | 2 | BD-JL-1a, BD-JL-1b |
| `job-lifecycle-scan §2` | jobs/deleted-record-fails | 2 | BD-JL-2a, BD-JL-2b |
| `job-lifecycle-scan §3` | jobs/payload-field-never-set, jobs/task-signature-drift | 2 | BD-JL-3a, BD-JL-3b |
| `job-lifecycle-scan §4` | jobs/cron-self-overlap-money, jobs/robfig-no-skip | 2 | BD-JL-4a, BD-JL-4b |
| `job-lifecycle-scan §5` | jobs/in-process-no-catch-up, jobs/misfire-default-skips | 2 | BD-JL-5a, BD-JL-5b |
| `job-lifecycle-scan §6` | jobs/schedule-zone-dst | 2 | BD-JL-6a, BD-JL-6b |
| `job-lifecycle-scan §7` | jobs/failure-discarded, jobs/ignore-result-then-polled | 2 | BD-JL-7a, BD-JL-7b |
| `state-transition-scan §1` | transitions/illegal-event-answered-success, transitions/illegal-event-then-refund | 3 | BD-ST-1a, BD-ST-1b, BD-ST-1c |
| `state-transition-scan §2` | transitions/direct-status-write-bypasses-machine, transitions/wildcard-reopens-terminal | 2 | BD-ST-2a, BD-ST-2b |
| `transaction-scan §1 (database)` | database/enqueue-inside-transaction, database/model-callback-enqueue-before-commit | 2 | BD-HO-DB-a, BD-HO-DB-b |
| `error-handling-scan §3 (code-quality)` | code-quality/outbound-status-unchecked | 1 | BD-HO-CQ-a |
| `type-safety-scan §1 (code-quality)` | code-quality/response-cast-unchecked | 1 | BD-HO-CQ-b |
| `correctness-smell-scan §4 (code-quality)` | code-quality/minor-units-hard-coded | 1 | BD-HO-CQ-c |
| `error-handling-scan §7 (code-quality)` | code-quality/temp-file-left-on-failure | 1 | BD-HO-CQ-d |
| `retry-deadline-scan §5 (distributed-systems)` | distributed-systems/library-retries-post | 2 | BD-HO-DS-a, BD-HO-DS-b |
| `dual-write-scan §1 (distributed-systems)` | distributed-systems/commit-then-publish | 1 | BD-HO-DS-c |
| `logic-race-scan §2 (security)` | security/repeated-key-cap | 1 | BD-HO-SEC-a |
| `file-access-scan §2 (security)` | security/upload-no-size-cap | 1 | BD-HO-SEC-b |
| `data-exposure-scan §1 (security)` | security/stack-in-error-body | 1 | BD-HO-SEC-c |
| `request-path-scan §12 (performance)` | performance/outbound-no-timeout | 1 | BD-HO-PERF-a |
| `request-path-scan §6 (performance)` | performance/upload-fully-buffered | 1 | BD-HO-PERF-b |
| `request-path-scan §20 (performance)` | performance/cron-every-replica | 1 | BD-HO-PERF-c |
| `error-tracking-scan §4 (observability)` | observability/5xx-without-capture | 1 | BD-HO-OBS-a |
| `log-signal-scan §2 (observability)` | observability/stack-lost | 1 | BD-HO-OBS-b |
| **decoys (must not be reported)** | — | **55** | BD-DECOY-01 … BD-DECOY-55 |

---

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| BD-DECOY-01 | `apps/api/src/oauth/oauth-register.controller.ts:30` | BD-VB-1a | RFC 7591 registration: `parseRegistration` bounds every field (type, length, enum) and the protocol owns its error body (B-D1). |
| BD-DECOY-02 | `apps/api/src/transfers/transfers.controller.ts:23` | BD-VB-1a / §8 | The project param decorator `ZodBody` wraps `@Body` with `ZodValidationPipe` over a `.strict()` schema (zod-body.decorator.ts): the body IS validated, unknown keys rejected. dto-types.py sees no `@Body` param here; the /backend-audit wiring map lists `@ZodBody (pipe)` and VB §1/§8 read the pipe — reading it clears the row. **Decoy, not seed.** |
| BD-DECOY-03 | `apps/api/src/integrations/dto/create-webhook-subscription.dto.ts:13` | BD-VB-2a | Free-form `metadata` labels, echoed verbatim and never interpreted (VB § shapes not to report). |
| BD-DECOY-04 | `apps/api/src/common/page-query.dto.ts:16` | BD-VB-3b | `@Type(() => Number)` with `@IsInt @Min @Max` on a page size: `""` → 0 is rejected by `@Min(1)`. |
| BD-DECOY-05 | `apps/admin/src/env.ts:5` | BD-VB-4a | Env parsed once at boot, where an empty value cannot occur by deployment config (B-A13). |
| BD-DECOY-06 | `services/edge-go/internal/http/checkout.go:11` | BD-VB-4d | Pointer fields (`*int`, `*bool`) with `required`: gin checks nil, so `0`/`false` are accepted. |
| BD-DECOY-07 | `apps/api/src/suppliers/dto/update-supplier.dto.ts:8` | BD-VB-5a | The project's `IsAbsentOr()` (`ValidateIf(v !== undefined)`): absent allowed, `null` refused. |
| BD-DECOY-08 | `services/edge-go/internal/http/webhooks.go:19` | BD-VB-6b | Provider webhooks are documented tolerant readers (ai/api-conventions.md § Request bodies; B-A11, B-G17). |
| BD-DECOY-09 | `apps/api/src/regions/regions.controller.ts:15` | BD-VB-7a | `assertRegion()` runs before any use; unknown → 404 (B-D10). |
| BD-DECOY-10 | `apps/api/src/common/current-user.decorator.ts:10` | BD-VB-8b | Returns the server-derived principal, never client input (VB §8 decoy shape). |
| BD-DECOY-11 | `apps/api/src/catalog/dto/bundle.dto.ts:18` | BD-VB-9a | Arrays of nested objects are validated without `each: true` (class-validator iterates them) [V 12.1.3]. |
| BD-DECOY-12 | `apps/api/test/app-validation.pipe.spec.ts:6` | BD-VB-6a | A unit test that builds its own pipe with the same options while `test/pricing.e2e-spec.ts` imports the real `AppModule` + `configureApp` (B-D7). |
| BD-DECOY-13 | `apps/api/src/legacy/legacy-v1.filter.ts:18` | BD-EE-3a | `reply.status()` is a valid `FastifyReply` alias of `.code()` (B-D3). |
| BD-DECOY-14 | `apps/api/src/files/files.plugin.ts:26` | BD-EE-3a | `reply.redirect(url, 302)` is the Fastify v5 argument order (fastify 5.4.0 locked; B-D3). |
| BD-DECOY-15 | `apps/api/src/webhooks/psp-webhook.controller.ts:15` | BD-EE-5c | Every branch sends or throws, and the reason for `@Res()` is written (a bare `ok` within 3 s) — B-D2. |
| BD-DECOY-16 | `apps/api/src/webhooks/psp-webhook.controller.ts:20` | BD-EE-5c | `reply.send` with no `return` inside a Nest controller: Nest does not need the return (B-D8). |
| BD-DECOY-17 | `apps/admin/src/routes/health.routes.ts:8` | EE §4 (Express 4 async crash) | Express 5 (5.1.0 locked) forwards a rejected promise to the error middleware; the Express 4 crash (B-A15) does not apply. |
| BD-DECOY-18 | `apps/api/src/legacy/legacy-v1.filter.ts:9` | BD-EE-7a / BD-EE-1a | The v1 door documents its own `LegacyError` shape (openapi) and reuses the global `statusFor` mapping, so no arm is missing (B-D6). |
| BD-DECOY-19 | `services/billing-py/billing/views_refunds.py:12` | BD-EE-6a | `DoesNotExist` is caught and raised as DRF `NotFound` (an `APIException`): 404, not the HTML 500. |
| BD-DECOY-20 | `apps/admin/src/routes/geo-proxy.routes.ts:14` | BD-EE-8a | A documented pass-through proxy for the map widget (its docstring and the conventions' scope). |
| BD-DECOY-21 | `services/edge-go/internal/http/checkout.go:20` | BD-EE-6b | `ShouldBindJSON` (no early write) and 422 is what openapi documents for `/v1/checkout` (B-A7). |
| BD-DECOY-22 | `apps/api/src/catalog/catalog-export.routes.ts:20` | BD-EE-5b | `return reply.send(...)` in a raw Fastify handler is the correct form. |
| BD-DECOY-23 | `apps/api/src/customers/customers.controller.ts:17` | BD-HC-1a | An action POST that sets `@HttpCode(200)`. |
| BD-DECOY-24 | `apps/api/src/orders/order-actions.controller.ts:28` | BD-HC-4a | `cancellations` is not the segment `cancel` (B-D11); the route is read-only through the kernel. |
| BD-DECOY-25 | `apps/api/src/receipts/receipts.controller.ts:15` | BD-HC-4a | A GET that writes an audit row (who viewed which receipt) — B-A6. |
| BD-DECOY-26 | `apps/api/src/outbox/outbox-relay.ts:35` | BD-HC-7a | An internal drain whose processed rows leave the filter (`publishedAt: null`), so a tie is picked up next pass (B-D4). |
| BD-DECOY-27 | `apps/api/src/common/pagination.ts:35` | BD-HC-7a | The pagination kernel: clamp, allow-listed sort, `id` tiebreak, `total` under the same `where` (B-D9). |
| BD-DECOY-28 | `apps/api/src/products/products-bulk.controller.ts:27` | BD-HC-8a | 207 with `results[i]` aligned to `changes[i]`, as openapi documents (B-G15). |
| BD-DECOY-29 | `services/edge-go/internal/http/legacy.go:11` | BD-HC-9a | RFC 9745 `@<epoch>` with a `Sunset` after it. |
| BD-DECOY-30 | `.github/workflows/api.yml:49` | BD-HC-10a | `oasdiff changelog` is informational (a PR summary); the gate is the `breaking` step. |
| BD-DECOY-31 | `apps/admin/src/routes/files.routes.ts:14` | BD-HC-11a | `/*splat` is the Express 5 wildcard syntax. |
| BD-DECOY-32 | `apps/api/src/graphql/request-loaders.ts:8` | BD-HC-11d | Built per request inside a factory. |
| BD-DECOY-33 | `apps/api/src/common/http-client.ts:20` | BD-HC-12b | The shared outbound wrapper sets `redirect: "manual"` once for every caller (P5). |
| BD-DECOY-34 | `apps/api/src/documents/contracts.controller.ts:19` | BD-HC-13b | Field-first is documented and enforced: a file before `contractId` is refused with 400. |
| BD-DECOY-35 | `apps/api/src/products/products.controller.ts:15` | BD-HC-1d | A create that answers 201 and sets `Location`. |
| BD-DECOY-36 | `apps/api/src/common/page-query.dto.ts:10` | BD-HC-5b | Initialisers on a query DTO, not on an Update/Patch DTO (B-D13). |
| BD-DECOY-37 | `apps/admin/src/routes/files.routes.ts:8` | BD-HC-3a | A parser scoped to one content type: anything else leaves `req.body` empty. |
| BD-DECOY-38 | `apps/api/src/ledger/journal-sequence.entity.ts:14` | BD-WF-2a | Every read goes through `toJournalDto` (safe-integer check, rendered as a string), the generator caps it below 2^31 and the column set is pinned (B-D5). |
| BD-DECOY-39 | `apps/api/src/shipments/parcel.mapper.ts:9` | BD-WF-1b | A measure, not money: a JSON number is the documented contract (B-R2). |
| BD-DECOY-40 | `apps/api/src/activity/activity-feed.controller.ts:23` | BD-WF-6a | Dates kept as strings with a strict ISO validator (B-D12). |
| BD-DECOY-41 | `apps/api/src/payouts/payout.producer.ts:17` | BD-WF-5a | Integer minor units plus the currency in the payload. |
| BD-DECOY-42 | `apps/api/src/catalog/catalog-export.routes.ts:13` | BD-WF-3a | The feed schema hides `costPrice` and `supplierId` on purpose (B-A12); `price` stays a string. |
| BD-DECOY-43 | `apps/api/src/stores/store-hours.entity.ts:16` | BD-WF-7a | Opening hours are wall-clock times with the store's zone beside them (B-R3). |
| BD-DECOY-44 | `services/billing-py/billing/tax.py:25` | BD-WF-4b | An explicit rounding mode that matches the PSP. |
| BD-DECOY-45 | `apps/api/src/catalog/catalog-cache.warmer.ts:12` | BD-JL-4a | Idempotent, read-only, ~50 ms, process-local cache warm (B-R8). |
| BD-DECOY-46 | `services/billing-py/billing/fx_scheduler.py:8` | BD-JL-4b / BD-JL-5a | APScheduler's default `max_instances=1` (B-R1), and a display-only job whose skipped run is harmless (`coalesce=True`). |
| BD-DECOY-47 | `apps/api/src/catalog/product-sync.processor.ts:18` | BD-JL-2a | A not-found branch that discards the job. |
| BD-DECOY-48 | `apps/api/src/catalog/nightly-reindex.scheduler.ts:12` | BD-JL-6a | UTC schedule, UTC meaning, `timeZone: "UTC"` explicit (B-R9). |
| BD-DECOY-49 | `apps/api/src/exports/export-job.processor.ts:17` | BD-JL-7a | A `failed` listener that writes the failure to `export_jobs`. |
| BD-DECOY-50 | `services/billing-py/billing/subscriptions.py:23` | BD-ST-1a | The trigger's `False` is checked and answered 409 before any effect (B-R5). |
| BD-DECOY-51 | `apps/api/src/shipments/shipments.service.ts:17` | BD-ST-1b | `can()` is asked first and an illegal event answers 409; the write also carries a status predicate. |
| BD-DECOY-52 | `apps/api/src/exports/export-job.processor.ts:20` | BD-ST-2b | `export_jobs` is a plain status table with no machine (grep 0 lists none for it). |
| BD-DECOY-53 | `apps/api/src/outbox/outbox-relay.ts:32` | BD-JL-4a | An in-process running flag guards the `@Interval` drain. |
| BD-DECOY-54 | `apps/api/src/orders/get-order.use-case.ts:19` | BD-HC-7a | A unique tiebreak (`id`) beside the sort key. |
| BD-DECOY-55 | `apps/api/src/products/update-product.use-case.ts:13` | BD-EE-2a | The domain `NotFoundError`, which the global filter maps to 404. |

## BD-VB-1a — `@Body() dto: WriteCollectionDto | null` — the union emits `Object`, so the pipe validates nothing

```defect
id:       BD-VB-1a
file:     apps/api/src/pricing/pricing.controller.ts
line:     17
severity: high
command:  /backend-audit
class:    validation/union-body-object-metatype
detector: validation-boundary-scan §1
anchor:   @Body() dto: WriteCollectionDto | null,
match:    union|\| ?null|Object|metatype|paramtypes|WriteCollectionDto
```

tsconfig has `strict: true`, so `X | null` is emitted as `Object` in `design:paramtypes`; the global `AppValidationPipe` skips it: `@ArrayMaxSize(100)`, the nested `@ValidateNested` items and `notes` length never run and `whitelist` strips nothing. Payload: `PUT /v1/pricing/collections/<id> {"title": 5, "items": [{"productId": "x"}], "x": 1}` → 200. Fix: `@Body() dto: WriteCollectionDto` (decide null inside the DTO). Proof: V340, or `Reflect.getMetadata("design:paramtypes", …)` printing `Object`.

## BD-VB-1b — `@Body() items: LineDto[]` — an array body reaches the pipe as `Array` and is never validated

```defect
id:       BD-VB-1b
file:     apps/api/src/orders/orders.controller.ts
line:     33
severity: high
command:  /backend-audit
class:    validation/array-body-array-metatype
detector: validation-boundary-scan §1
anchor:   @Body() items: LineDto[]
match:    LineDto\[\]|array|Array|ParseArrayPipe|metatype
```

The pipe skips the `Array` metatype: `quantity: -5`, `productId: "x"` and unknown keys reach `addLines`. Fix: `@Body(new ParseArrayPipe({ items: LineDto, whitelist: true, forbidNonWhitelisted: true }))` or a wrapper DTO. Proof: V340 `POST /v1/orders/<id>/lines [{"productId":"x","sku":1,"quantity":-5}]` → 400.

## BD-VB-2a — `@ValidateNested({ each: true }) lines` with no `@Type(() => LineDto)` — children never checked

```defect
id:       BD-VB-2a
file:     apps/api/src/orders/dto/create-order.dto.ts
line:     10
severity: high
command:  /backend-audit
class:    validation/validate-nested-no-type
detector: validation-boundary-scan §2
anchor:   @ValidateNested({ each: true })
match:    ValidateNested|@Type|nested|LineDto
```

Without `@Type` class-transformer leaves plain objects, so `LineDto`'s `@IsUUID`/`@Min(1)` never run on `POST /v1/orders`. Fix: add `@Type(() => LineDto)`. Proof: V340 `{"currency":"AED","lines":[{"productId":"x","quantity":0}]}` → 400 naming `lines.0.productId`.

## BD-VB-2b — `@Type(() => OrderRefDto)` with no `@ValidateNested` — the child's `@IsUUID` never runs

```defect
id:       BD-VB-2b
file:     apps/api/src/delivery/dto/bulk-status.dto.ts
line:     10
severity: high
command:  /backend-audit
class:    validation/type-no-validate-nested
detector: validation-boundary-scan §2
anchor:   @Type(() => OrderRefDto)
match:    type-no-validate-nested|ValidateNested|OrderRefDto|IsUUID
```

The inverse direction (two real-repo hits): the carrier callback `POST /v1/delivery/bulk-status` passes `{"orders":[{"orderId":"x"}]}` straight into `order_id = any(?)`. Fix: `@ValidateNested({ each: true })`. Proof: V340 → 400 naming `orders.0.orderId`.

## BD-VB-3a — Controller-scoped pipe with `enableImplicitConversion: true` — `?includeRefunded=false` turns the filter on

```defect
id:       BD-VB-3a
file:     apps/api/src/reports/reports.controller.ts
line:     17
severity: high
command:  /backend-audit
class:    validation/implicit-conversion-boolean
detector: validation-boundary-scan §3
anchor:   enableImplicitConversion: true
match:    enableImplicitConversion|implicit|"false"|includeRefunded|boolean
```

Implicit conversion runs `Boolean("false") === true` before `@IsBoolean`, so the finance report includes refunds when asked not to; `?year=` becomes `0`. Transcript: `.refract-fixture/runtime/coercion-table.txt`. Fix: drop implicit conversion; `@Transform(({ value }) => value === "true")` per boolean. Proof: V341.

## BD-VB-3b — `@Type(() => Boolean) @IsBoolean() active` — `?active=false` lists active customers

```defect
id:       BD-VB-3b
file:     apps/api/src/customers/dto/list-customers.query.ts
line:     13
severity: high
command:  /backend-audit
class:    validation/type-boolean-query
detector: validation-boundary-scan §3
anchor:   @Type(() => Boolean)
match:    @Type\(\(\) => Boolean\)|Boolean|active|"false"
```

`Boolean("false")` is `true`; the win-back campaign query (`?active=false`) returns the opposite set. Fix: `@Transform(({ value }) => value === "true")`. Proof: V341 `GET /v1/customers?active=false` → handler sees `false`.

## BD-VB-4a — `z.coerce.boolean()` on a query flag — `"false"` and `"0"` are `true`

```defect
id:       BD-VB-4a
file:     apps/admin/src/routes/users.routes.ts
line:     10
severity: high
command:  /backend-audit
class:    validation/zod-coerce-boolean
detector: validation-boundary-scan §4
anchor:   includeDisabled: z.coerce.boolean()
match:    z\.coerce\.boolean|coerce|stringbool|includeDisabled
```

zod 4 `coerce.boolean` is `Boolean(value)`: `?includeDisabled=false` lists disabled admins. Fix: `z.stringbool()`. Proof: V341 (coercion-table.txt row).

## BD-VB-4b — `@IsEnum(TicketPriority)` on a numeric TS enum — the KEY `"Urgent"` validates through the reverse mapping

```defect
id:       BD-VB-4b
file:     apps/api/src/tickets/dto/update-ticket.dto.ts
line:     7
severity: medium
command:  /backend-audit
class:    validation/isenum-numeric-enum-key
detector: validation-boundary-scan §4
anchor:   @IsEnum(TicketPriority)
match:    IsEnum|numeric enum|TicketPriority|reverse mapping|key
```

`TicketPriority` has no initialisers, so `Object.values` holds both names and numbers; `{"priority":"Urgent"}` passes and reaches the `int` column (500). Fix: a string enum or `@IsIn([0,1,2,3])` + `@IsInt`. Proof: V341.

## BD-VB-4c — `bool(os.getenv("CAPTURE_ENABLED"))` — `CAPTURE_ENABLED=false` turns card capture ON

```defect
id:       BD-VB-4c
file:     services/billing-py/billing_service/settings.py
line:     51
severity: high
command:  /backend-audit
class:    validation/env-bool-truthy-string
detector: validation-boundary-scan §4
anchor:   CAPTURE_ENABLED = bool(os.getenv("CAPTURE_ENABLED"))
match:    bool\(os\.getenv|CAPTURE_ENABLED|"false"|truthy
```

Any non-empty string is truthy: the Helm value `"false"` enables live capture. The env-loader row of the coercion table (BC-02). Fix: parse an explicit allow-list (`in {"1","true","yes"}`) or pydantic-settings. Proof: V341 env row — `CAPTURE_ENABLED=false` at boot → `False`.

## BD-VB-4d — gin `Qty int binding:"required,min=0"` — `qty: 0` (remove the line) is rejected as missing

```defect
id:       BD-VB-4d
file:     services/edge-go/internal/http/cart.go
line:     12
severity: medium
command:  /backend-audit
class:    validation/gin-required-zero
detector: validation-boundary-scan §4
anchor:   binding:"required,min=0,max=99"
match:    required|binding|qty|\*int|zero|0
```

gin's `required` fails on the zero value, so the documented "qty 0 removes the line" always answers 400. Fix: `Qty *int` with `required`. Proof: V341 `{"qty":0}` → 200.

## BD-VB-5a — `@IsOptional() name?: string` — `{"name": null}` skips every validator and reaches `name.trim()` → 500

```defect
id:       BD-VB-5a
file:     apps/api/src/products/dto/update-product.dto.ts
line:     7
severity: high
command:  /backend-audit
class:    validation/optional-admits-null-500
detector: validation-boundary-scan §5
anchor:   name?: string;
match:    IsOptional|null|trim|500|IsAbsentOr|name
```

`@IsOptional` skips `null`; `UpdateProductUseCase` guards with `!== undefined` (update-product.use-case.ts) and `Product.rename` calls `trim()`; the column is NOT NULL. Transcript: failure-matrix row 13. Fix: the project's own `IsAbsentOr()` (suppliers/dto/is-absent-or.ts). Proof: V342.

## BD-VB-5b — `@IsOptional() assigneeEmail?: string` — `{"assigneeEmail": null}` → `toLowerCase()` on null → 500

```defect
id:       BD-VB-5b
file:     apps/api/src/tickets/dto/update-ticket.dto.ts
line:     12
severity: high
command:  /backend-audit
class:    validation/optional-admits-null-500
detector: validation-boundary-scan §5
anchor:   assigneeEmail?: string;
match:    IsOptional|null|toLowerCase|500|assigneeEmail
```

Same shape on a second Update DTO: `UpdateTicketUseCase` guards `!== undefined` and calls `.toLowerCase()`; the column is NOT NULL. Fix: `IsAbsentOr()`. Proof: V342 → 400.

## BD-VB-6a — The `APP_PIPE` subclass sets `whitelist` without `forbidNonWhitelisted` — unknown fields are stripped silently

```defect
id:       BD-VB-6a
file:     apps/api/src/common/app-validation.pipe.ts
line:     10
severity: medium
command:  /backend-audit
class:    validation/unknown-keys-stripped-silently
detector: validation-boundary-scan §6
anchor:   super({ transform: true, whitelist: true, stopAtFirstError: false });
match:    whitelist|forbidNonWhitelisted|unknown|strip|typo
```

`ai/api-conventions.md` makes the public API a strict reader (unknown field → 400 `UNKNOWN_FIELD`); a misspelled optional field is dropped and its default applied with 2xx. One finding at the pipe, N routes (P5). Fix: `forbidNonWhitelisted: true` in the subclass. Proof: V343 `{"notee": "x"}` → 400.

## BD-VB-6b — Go `json.NewDecoder(...).Decode` on a public `/v1` route — unknown and miscased keys accepted

```defect
id:       BD-VB-6b
file:     services/edge-go/internal/http/quotes.go
line:     20
severity: medium
command:  /backend-audit
class:    validation/go-decoder-unknown-fields
detector: validation-boundary-scan §6
anchor:   json.NewDecoder(c.Request.Body).Decode(&req)
match:    DisallowUnknownFields|NewDecoder|unknown|strict
```

`{"expressShiping": true}` silently prices standard delivery; `encoding/json` also matches `ExpressShipping` case-insensitively. The conventions make `/v1/*` a strict reader. Fix: `dec.DisallowUnknownFields()` (and reject trailing data). Proof: V343.

## BD-VB-7a — `@Query('status') status: string` — no pipe; `?status=a&status=b` arrives as `string[]`

```defect
id:       BD-VB-7a
file:     apps/api/src/orders/orders-search.controller.ts
line:     10
severity: medium
command:  /backend-audit
class:    validation/named-primitive-query-array
detector: validation-boundary-scan §7
anchor:   @Query('status') status: string
match:    @Query\('status'\)|primitive|array|string\[\]|ParseEnumPipe|repeated
```

The pipe skips `String` metatypes; Fastify hands an array for a repeated key and it reaches the ORM `where` as `$in` (coercion-table.txt); any string is accepted as a status. Fix: `new ParseEnumPipe(OrderStatus)` or a query DTO. Proof: V340.

## BD-VB-7b — `@Body('sku') sku: string` (and `cartId`) — an object or number body field reaches the reservation query

```defect
id:       BD-VB-7b
file:     apps/api/src/inventory/inventory.controller.ts
line:     11
severity: medium
command:  /backend-audit
class:    validation/named-primitive-body-object
detector: validation-boundary-scan §7
anchor:   @Body('sku') sku: string
match:    @Body\('sku'\)|primitive|object|SkuDto
```

`{"sku": {"x": 1}, "cartId": 7}` passes the pipe (String metatype); `cartId.length` is undefined and the object is bound into SQL (pg 500). The operator-object reading is security's (P3). Fix: `@Body() dto: ReserveDto`. Proof: V340.

## BD-VB-8a — `connectMicroservice(...)` without `{ inheritAppConfig: true }` — partner bus messages skip the global pipe

```defect
id:       BD-VB-8a
file:     apps/api/src/main.ts
line:     15
severity: high
command:  /backend-audit
class:    validation/microservice-no-inherit-app-config
detector: validation-boundary-scan §8
anchor:   app.connectMicroservice({ transport: Transport.REDIS
match:    connectMicroservice|inheritAppConfig|microservice|EventPattern|Payload
```

`PartnerOrdersController` (`@EventPattern("partner.order.created")`) receives partner-published payloads; `APP_PIPE` does not apply to the hybrid transport, so `PartnerOrderDto` never validates (`quantity: -3` accepted). Fix: `app.connectMicroservice(opts, { inheritAppConfig: true })`. Proof: V340 through the Redis transport.

## BD-VB-8b — WebSocket gateway takes browser messages with no `@UsePipes` — `CartUpdateDto` never validates

```defect
id:       BD-VB-8b
file:     apps/api/src/cart-sync/cart-sync.gateway.ts
line:     20
severity: high
command:  /backend-audit
class:    validation/gateway-no-pipe
detector: validation-boundary-scan §8
anchor:   @SubscribeMessage('cart.update')
match:    SubscribeMessage|gateway|UsePipes|WebSocket|MessageBody
```

Global pipes do not cover gateways; `{"quantity": 1000}` from the storefront is accepted. Fix: `@UsePipes(new AppValidationPipe())` on the gateway. Proof: V340 over the socket.

## BD-VB-8c — A raw Fastify route registered on the adapter instance — no pipe, no schema, `request.body as LegacyOrderBody`

```defect
id:       BD-VB-8c
file:     apps/api/src/legacy/legacy-routes.ts
line:     15
severity: high
command:  /backend-audit
class:    validation/raw-adapter-route
detector: validation-boundary-scan §8
anchor:   app.getHttpAdapter().getInstance().post('/v1/legacy/orders'
match:    getHttpAdapter|getInstance|raw|Fastify route|legacy
```

Neither the Nest pipe nor a Fastify body schema runs: `qty: "lots"` or a missing `sku` creates an order id. (The cast itself is code-quality type-safety §1, corroboration only.) Fix: a route `schema.body` with `additionalProperties: false` + ajv `removeAdditional: false`, or move it to a Nest controller. Proof: V340.

## BD-VB-9a — `@IsString()` on `tags: string[]` without `{ each: true }` — every valid request is rejected

```defect
id:       BD-VB-9a
file:     apps/api/src/products/dto/create-product.dto.ts
line:     13
severity: medium
command:  /backend-audit
class:    validation/no-each-array
detector: validation-boundary-scan §9
anchor:   tags!: string[];
match:    each|IsString|tags|array
```

`{"tags": ["lamp"]}` → 400 "tags must be a string"; only a bare string passes (and then the column gets a string). Fix: `@IsString({ each: true })`. Proof: V344 — `[]`, one, many, over-max.

## BD-VB-9b — `validate(row, { groups: ["import"] })` — the un-grouped `@IsInt @Min(0) @Max(1_000_000)` on `priceMinor` never run

```defect
id:       BD-VB-9b
file:     apps/api/src/imports/import-row.validator.ts
line:     19
severity: medium
command:  /backend-audit
class:    validation/groups-skip-ungrouped
detector: validation-boundary-scan §9
anchor:   validate(plainToInstance(ImportRowDto, row), { groups: ['import'] })
match:    groups|always|ungrouped|priceMinor|Max
```

With groups given, class-validator applies only validators in those groups (no `always: true`): a CSV row `priceMinor=-500` or `abc` is accepted. Fix: `always: true` on the price validators or drop the groups. Proof: V344.

## BD-EE-1a — Express error middleware answers 500 for every error — a `ZodError` (400) and body-parser errors (400/413/415) included

```defect
id:       BD-EE-1a
file:     apps/admin/src/app.ts
line:     35
severity: high
command:  /backend-audit
class:    edge/catch-all-flattens-status
detector: edge-error-scan §1
anchor:   res.status(500).json({ error: { code: 'INTERNAL', message: 'Something went wrong' } });
match:    500|catch-all|ZodError|status|flatten|error middleware
```

The handler never reads `err.status`/`err.statusCode` and has no `ZodError` arm: `POST /admin/coupons {"code":"x"}` → 500 (failure-matrix row 05b); a malformed JSON body → 500. Fix: map `ZodError` → 400 with details and keep `err.status` for HTTP errors before the 500 arm. Proof: V345.

## BD-EE-1b — Fastify scope `setErrorHandler` answers 500 for every error under `/v1/files` — the 413 body limit and 404s included

```defect
id:       BD-EE-1b
file:     apps/api/src/files/files.plugin.ts
line:     10
severity: high
command:  /backend-audit
class:    edge/fastify-scope-error-handler-flattens
detector: edge-error-scan §1
anchor:   return reply.code(500).send({ error: { code: 'FILE_ERROR'
match:    setErrorHandler|500|413|flatten|statusCode|FILE_ERROR
```

`POST /v1/files/direct` with 11 MiB → 500 `FILE_ERROR` (failure-matrix row 11); clients retry a 500 forever. Fix: `reply.code(error.statusCode ?? 500)` for `statusCode < 500`, envelope kept. Proof: V345.

## BD-EE-2a — The global filter maps the DOMAIN `NotFoundError`; MikroORM's `NotFoundError` (from `findOneOrFail`) falls to 500

```defect
id:       BD-EE-2a
file:     apps/api/src/common/filters/global-exception.filter.ts
line:     10
severity: high
command:  /backend-audit
class:    edge/orm-not-found-unmapped-name-collision
detector: edge-error-scan §2
anchor:   import { DomainError, NotFoundError } from '../errors';
match:    NotFoundError|mikro-orm|findOneOrFail|collision|same-named|404
```

The import is `../errors`, not `@mikro-orm/core`, and no `findOneOrFailHandler` is configured (app.module.ts). `POST /v1/pricing/rate-cards/apply {"rateCardId": <random uuid>}` → 500 (failure-matrix row 06b); 10+ `findOneOrFail` sites reached by client ids. Fix: `findOneOrFailHandler: (entity, where) => new NotFoundError(entity, …)` in the ORM config, or import the ORM class under an alias with its own 404 arm. Proof: V330.

## BD-EE-2b — `LedgerError` family (insufficient funds, frozen account, currency mismatch) extends `Error`, not `DomainError` — no mapper names it

```defect
id:       BD-EE-2b
file:     apps/api/src/ledger/ledger.errors.ts
line:     2
severity: high
command:  /backend-audit
class:    edge/domain-error-family-unmapped
detector: edge-error-scan §2
anchor:   export class LedgerError extends Error {
match:    LedgerError|InsufficientFunds|AccountFrozen|unmapped|409|422
```

`POST /v1/transfers` from a frozen account → 500 `INTERNAL` (failure-matrix row 09): a client-caused refusal reported as an outage. Fix: extend `DomainError` with 409/422 codes (or an arm in `statusFor`). Proof: V330.

## BD-EE-3a — A controller filter calls Express `res.status().json()` on the Fastify adapter — every decline answers 500

```defect
id:       BD-EE-3a
file:     apps/api/src/payments/payments-exception.filter.ts
line:     10
severity: high
command:  /backend-audit
class:    edge/express-api-on-fastify
detector: edge-error-scan §3
anchor:   res.status(402).json(
match:    \.json|express|Fastify|adapter|Response|402
```

`getResponse<Response>()` typed from `express`; `FastifyReply` has no `.json`, the filter throws `TypeError` and the decline (402) becomes 500 (failure-matrix row 12). Fix: `reply.status(402).send(...)` or `httpAdapterHost.httpAdapter.reply(...)`. Proof: V345 on the real adapter (V346 if both adapters).

## BD-EE-3b — `FileInterceptor` from `@nestjs/platform-express` on the Fastify adapter — the upload route cannot work

```defect
id:       BD-EE-3b
file:     apps/api/src/attachments/attachments.controller.ts
line:     2
severity: high
command:  /backend-audit
class:    edge/platform-express-interceptor-on-fastify
detector: edge-error-scan §3
anchor:   import { FileInterceptor } from '@nestjs/platform-express';
match:    FileInterceptor|platform-express|multer|Fastify|adapter
```

multer expects an Express request; on Fastify the interceptor throws and every attachment upload answers 500. The body half of the adapter delta is HC §11 (corroboration). Fix: `@fastify/multipart` (`request.file()`), as `documents.controller.ts` does. Proof: V345 on the real adapter.

## BD-EE-4a — `gin.New()` with only `gin.Logger()` — a handler panic is never recovered

```defect
id:       BD-EE-4a
file:     services/edge-go/cmd/edge/main.go
line:     15
severity: high
command:  /backend-audit
class:    edge/gin-new-no-recovery
detector: edge-error-scan §4
anchor:   r := gin.New()
match:    gin\.New|Recovery|panic|recover
```

gin.New has no Recovery middleware: a nil dereference in any `/v1` handler aborts the connection (no envelope, no 500). Fix: `r.Use(gin.Recovery())` or a JSON recovery middleware. Proof: V345 — a panicking route, then a healthy request.

## BD-EE-4b — The internal `http.ServeMux` port has no recover middleware — a panic aborts the caller's connection

```defect
id:       BD-EE-4b
file:     services/edge-go/cmd/edge/main.go
line:     20
severity: medium
command:  /backend-audit
class:    edge/servemux-no-recover
detector: edge-error-scan §4
anchor:   mux := http.NewServeMux()
match:    ServeMux|recover|panic|internal
```

net/http logs the panic and drops the connection: the ops tooling sees a transport error, not a 500 envelope. Fix: wrap the mux in a recover handler. Proof: V345 (panic class).

## BD-EE-5a — `res.send(404)` on Express 5 — answers **200** with body `404`

```defect
id:       BD-EE-5a
file:     apps/admin/src/routes/invoices.routes.ts
line:     26
severity: high
command:  /backend-audit
class:    edge/express5-send-status-number
detector: edge-error-scan §5
anchor:   res.send(404);
match:    res\.send\(404\)|sendStatus|200|404
```

Express 5 removed the status-number overload: voiding a missing invoice "succeeds" (failure-matrix admin row 06). Fix: `res.status(404).json(<envelope>)`. Proof: V345.

## BD-EE-5b — `http.Error(...)` on a decode failure with no `return` — the handler continues, saves and writes 201

```defect
id:       BD-EE-5b
file:     services/edge-go/internal/http/internal_ops.go
line:     25
severity: high
command:  /backend-audit
class:    edge/go-http-error-no-return
detector: edge-error-scan §5
anchor:   http.Error(w, `{"error":{"code":"MALFORMED_JSON","message":"invalid body"}}`, http.StatusBadRequest)
match:    http\.Error|return|WriteHeader|superfluous|continue
```

After the 400 the handler runs on a zero-value request, calls `saveSubscription` and `WriteHeader(201)` (`superfluous WriteHeader`); a write follows, so High (B-R10). Fix: `return` after `http.Error`. Proof: V345 with the log captured.

## BD-EE-5c — `@Res()` without `passthrough` in a method that returns a value — the not-ready branch hangs

```defect
id:       BD-EE-5c
file:     apps/api/src/exports/exports.controller.ts
line:     17
severity: high
command:  /backend-audit
class:    edge/res-without-passthrough-returns
detector: edge-error-scan §5
anchor:   return { id, status: job.status };
match:    @Res|passthrough|hang|return
```

With `@Res()` Nest never sends the returned object: `GET /v1/exports/<id>` for a queued export never answers (client timeout). Fix: `@Res({ passthrough: true })`, or `reply.send(...)` on every branch. Proof: V345 with a timeout on the request.

## BD-EE-6a — DRF with no `EXCEPTION_HANDLER` — `IntegrityError` and `DoesNotExist` answer an HTML 500

```defect
id:       BD-EE-6a
file:     services/billing-py/billing_service/settings.py
line:     34
severity: high
command:  /backend-audit
class:    edge/drf-no-exception-handler
detector: edge-error-scan §6
anchor:   REST_FRAMEWORK = {
match:    EXCEPTION_HANDLER|IntegrityError|DoesNotExist|HTML|500
```

The default handler returns `None` for non-`APIException`: a duplicate invoice `number` on `/billing/invoices-new/` and `InvoiceReplace`'s `.get(pk=…)` on a missing id answer `text/html` 500 outside the envelope. Fix: a project `EXCEPTION_HANDLER` mapping `IntegrityError` → 409, `ObjectDoesNotExist` → 404 in the envelope. Proof: V345 (unique-violation and not-found rows).

## BD-EE-6b — gin `c.Bind` writes a plain-text 400 before the handler's own envelope

```defect
id:       BD-EE-6b
file:     services/edge-go/internal/http/orders.go
line:     18
severity: medium
command:  /backend-audit
class:    edge/gin-bind-writes-400
detector: edge-error-scan §6
anchor:   if err := c.Bind(&req); err != nil {
match:    c\.Bind|ShouldBind|400|422|envelope|text/plain
```

`Bind` aborts with 400 and `text/plain`; the later `c.JSON(422, …)` only logs `[WARNING] Headers were already written`, so the documented envelope never reaches the client. Fix: `c.ShouldBindJSON`. Proof: V345 (validation row).

## BD-EE-7a — `throw new UnprocessableEntityException({ code: "CART_LOCKED", … })` — the filter passes the object through verbatim

```defect
id:       BD-EE-7a
file:     apps/api/src/carts/carts.service.ts
line:     12
severity: medium
command:  /backend-audit
class:    edge/object-body-breaks-envelope
detector: edge-error-scan §7
anchor:   throw new UnprocessableEntityException({ code: 'CART_LOCKED'
match:    UnprocessableEntityException|envelope|CART_LOCKED|object body|statusCode
```

The global filter rebuilds only bodies that carry `statusCode`; this one leaves as `{"code":"CART_LOCKED","lockedAt":…}` with no `error` wrapper (failure-matrix row 07) — and the conventions give a locked cart 409. Fix: `throw new ConflictError(...)` (mapped), or rebuild every object body in the filter. Proof: V345 — body validated against `Error`.

## BD-EE-7b — `throw { message, code: "QUOTA_EXCEEDED" }` — a thrown non-Error loses its status: 500 instead of 429

```defect
id:       BD-EE-7b
file:     apps/api/src/quotas/quotas.service.ts
line:     12
severity: medium
command:  /backend-audit
class:    edge/thrown-object-literal
detector: edge-error-scan §7
anchor:   throw { message: 'Monthly API quota exceeded'
match:    throw \{|object literal|non-Error|429|quota
```

Thrown from `QuotaGuard` (APP_GUARD) on every partner call over quota; the filter maps it to 500 `INTERNAL` (failure-matrix row 10) and partners page on it. Fix: a `DomainError` subclass with 429 + `Retry-After`. Proof: V345.

## BD-EE-8a — The PSP's status is handed to the console as our own (`res.status(e.response.status)`)

```defect
id:       BD-EE-8a
file:     apps/admin/src/routes/psp-proxy.routes.ts
line:     15
severity: medium
command:  /backend-audit
class:    edge/upstream-status-passed-through
detector: edge-error-scan §8
anchor:   res.status(e.response.status)
match:    response\.status|upstream|502|401|pass
```

A PSP 401 (our credentials) logs the support agent out; a PSP 404 reads as "payment does not exist". The conventions say provider failures are 502 `UPSTREAM_*`. Fix: map 401/403 → 502 `UPSTREAM_AUTH`, 404 → 502, 429 → 503 + `Retry-After`. Proof: V354 with a PSP stub.

## BD-EE-8b — `w.WriteHeader(resp.StatusCode)` — the carrier's status and body go to the storefront unmapped

```defect
id:       BD-EE-8b
file:     services/edge-go/internal/upstream/rates.go
line:     20
severity: medium
command:  /backend-audit
class:    edge/upstream-status-passed-through
detector: edge-error-scan §8
anchor:   w.WriteHeader(resp.StatusCode)
match:    WriteHeader|StatusCode|upstream|502|pass
```

A carrier 401/429/500 reaches `/v1/rates/:lane` callers as ours, with the carrier's body instead of the envelope. Fix: 2xx → body; else 502/503 with our code. Proof: V354.

## BD-HC-1a — `@Post('preview')` with no `@HttpCode` — an action answers 201 (the Nest default); the spec documents 200

```defect
id:       BD-HC-1a
file:     apps/api/src/quotes/quotes.controller.ts
line:     10
severity: medium
command:  /backend-audit
class:    http/action-post-201
detector: http-contract-scan §1
anchor:   @Post('preview')
match:    201|HttpCode|preview|action
```

Nothing is created; `openapi/openapi.yaml` documents 200 and the Schemathesis report shows `Received 201` (`.refract-fixture/runtime/schemathesis-junit.xml`). Fix: `@HttpCode(200)`. Proof: V328.

## BD-HC-1b — `@Post(':id/validate')` with no `@HttpCode` — a validation action answers 201

```defect
id:       BD-HC-1b
file:     apps/api/src/carts/carts.controller.ts
line:     10
severity: medium
command:  /backend-audit
class:    http/action-post-201
detector: http-contract-scan §1
anchor:   @Post(':id/validate')
match:    201|HttpCode|validate|action
```

The conventions list validate among the 200 actions; the storefront keys "created" on 201. Fix: `@HttpCode(200)`. Proof: V328.

## BD-HC-1c — `@HttpCode(204)` on a method that returns `SubscriptionDto` — the documented body is dropped

```defect
id:       BD-HC-1c
file:     apps/api/src/subscriptions/subscriptions.controller.ts
line:     11
severity: medium
command:  /backend-audit
class:    http/204-with-body
detector: http-contract-scan §1
anchor:   @HttpCode(204)
match:    204|body|HttpCode|SubscriptionDto|endsOn
```

The spec documents 200 + `Subscription` (the last billed day); with 204 the body never leaves (B-A1 flips: a client is documented to receive it). the Schemathesis report shows the 204. Fix: `@HttpCode(200)`. Proof: V328.

## BD-HC-1d — Create answers 201 with no `Location` header

```defect
id:       BD-HC-1d
file:     apps/admin/src/routes/coupons.routes.ts
line:     16
severity: low
command:  /backend-audit
class:    http/201-no-location
detector: http-contract-scan §1
anchor:   res.status(201).json({ data: rows[0] });
match:    Location|201|coupon
```

The conventions require `Location: /admin/coupons/<id>` on a create. Fix: `res.status(201).location(...)`. Proof: V328 (Location GETs 200).

## BD-HC-1e — DRF `InvoiceCreate` answers 201 with no `Location`

```defect
id:       BD-HC-1e
file:     services/billing-py/billing/views.py
line:     39
severity: low
command:  /backend-audit
class:    http/201-no-location
detector: http-contract-scan §1
anchor:   status=status.HTTP_201_CREATED
match:    Location|201|HTTP_201_CREATED|get_success_headers
```

A hand-written `APIView` skips `CreateModelMixin.get_success_headers`. Fix: `headers={"Location": …}`. Proof: V328.

## BD-HC-2a — `GET /v1/orders/:id` declares `Promise<OrderDto | null>` — a missing order answers 200

```defect
id:       BD-HC-2a
file:     apps/api/src/orders/orders.controller.ts
line:     27
severity: high
command:  /backend-audit
class:    http/missing-resource-200-null
detector: http-contract-scan §2
anchor:   Promise<OrderDto | null>
match:    null|404|returns-nullable|missing|200
```

`GetOrderUseCase.execute` returns `null` and nothing throws below; Fastify renders `{"data":null}` with 200 while the spec documents 404. Fix: throw `NotFoundError` in the use case. Proof: V329.

## BD-HC-2b — DRF `get_object()` overridden with `.filter(...).first()` — a missing invoice answers 200 with an empty body

```defect
id:       BD-HC-2b
file:     services/billing-py/billing/views.py
line:     19
severity: high
command:  /backend-audit
class:    http/missing-resource-200-null
detector: http-contract-scan §2
anchor:   pk=self.kwargs["pk"]).first()
match:    first\(\)|get_object|404|None|Http404
```

`retrieve` serializes `None`; `get_object_or_404` was the contract. Fix: `get_object_or_404(self.get_queryset(), pk=…)`. Proof: V329.

## BD-HC-2c — `res.json(await repo.findOne(...))` — a missing invoice answers 200 with an empty body

```defect
id:       BD-HC-2c
file:     apps/admin/src/routes/invoices.routes.ts
line:     20
severity: high
command:  /backend-audit
class:    http/missing-resource-200-null
detector: http-contract-scan §2
anchor:   res.json(await repo.findOne('invoices', req.params.id));
match:    findOne|undefined|404|200|empty
```

`findOne` resolves `undefined`; Express 5 sends 200 with no body (failure-matrix admin row 06b). Fix: a 404 branch, as `GET /admin/users/:id` has. Proof: V329.

## BD-HC-3a — `express.json({ type: '*/*' })` — every content type is parsed as JSON; no 415

```defect
id:       BD-HC-3a
file:     apps/admin/src/app.ts
line:     17
severity: medium
command:  /backend-audit
class:    http/catch-all-parser-no-415
detector: http-contract-scan §3
anchor:   app.use(express.json({ type: '*/*', limit: '256kb' }));
match:    type: '\*/\*'|415|content type|express\.json
```

A `text/csv` or `multipart` body is fed to the JSON parser (400 or a wrong parse) instead of 415; the multipart upload router then sees a consumed stream. Fix: `express.json()` (default `application/json`) and a 415 guard. Proof: V331.

## BD-HC-3b — `addContentTypeParser('*', …)` — any content type is accepted and parsed as CSV

```defect
id:       BD-HC-3b
file:     apps/api/src/imports/imports.plugin.ts
line:     7
severity: medium
command:  /backend-audit
class:    http/catch-all-content-type-parser
detector: http-contract-scan §3
anchor:   fastify.addContentTypeParser('*'
match:    addContentTypeParser|'\*'|415|content type
```

A JSON or XML body to `POST /v1/imports/prices` is parsed as CSV rows (garbage rows, or 202) instead of 415. Fix: register `text/csv` only. Proof: V331.

## BD-HC-4a — `@Get(':id/cancel')` cancels the order — a link prefetcher or mail scanner cancels orders

```defect
id:       BD-HC-4a
file:     apps/api/src/orders/order-actions.controller.ts
line:     11
severity: high
command:  /backend-audit
class:    http/unsafe-get
detector: http-contract-scan §4
anchor:   @Get(':id/cancel')
match:    GET|cancel|unsafe|prefetch|side effect
```

Whole-segment match (`cancel`), beside the read-only `GET cancellations` (B-D11 decoy). E-mail link scanners follow GETs. Fix: `POST /orders/:id/cancel` behind a confirmation page. Proof: V332 — GET, then the state is unchanged.

## BD-HC-4b — `GET /admin/users/:id/deactivate` disables an admin user

```defect
id:       BD-HC-4b
file:     apps/admin/src/routes/users.routes.ts
line:     23
severity: high
command:  /backend-audit
class:    http/unsafe-get
detector: http-contract-scan §4
anchor:   router.get('/users/:id/deactivate'
match:    GET|deactivate|unsafe|side effect
```

Business state changes on a GET (B-A6 does not apply). Fix: `POST`. Proof: V332.

## BD-HC-5a — `PUT /v1/warehouses/:id` merges (`Object.assign` of an all-optional DTO) — the spec says replace

```defect
id:       BD-HC-5a
file:     apps/api/src/warehouses/warehouses.controller.ts
line:     30
severity: medium
command:  /backend-audit
class:    http/put-merges
detector: http-contract-scan §5
anchor:   Object.assign(warehouse, dto);
match:    PUT|merge|replace|Object\.assign|UpdateWarehouseDto
```

openapi: "omitted optional fields are cleared"; here an omitted `address` keeps its old value. Fix: a full `ReplaceWarehouseDto` and assign every field (or document PATCH). Proof: V333.

## BD-HC-5b — PATCH DTO initialiser `marketing?: boolean = false` — every PATCH that omits it opts the user out

```defect
id:       BD-HC-5b
file:     apps/api/src/notifications/dto/update-notification-prefs.dto.ts
line:     11
severity: high
command:  /backend-audit
class:    http/patch-default-wipes
detector: http-contract-scan §5
anchor:   marketing?: boolean = false;
match:    initiali[sz]er|= false|PATCH|default|marketing
```

With `transform: true` the initialiser is applied, so `{"sms": true}` also writes `marketing: false` (the controller filters only `undefined`). Fix: no initialisers on Update DTOs. Proof: V333 — PATCH one field, the others unchanged.

## BD-HC-5c — DRF `put` with `partial=True` — a "full replacement" skips required fields

```defect
id:       BD-HC-5c
file:     services/billing-py/billing/views.py
line:     47
severity: medium
command:  /backend-audit
class:    http/put-forced-partial
detector: http-contract-scan §5
anchor:   partial=True
match:    partial=True|PUT|replace|required
```

openapi documents PUT as a full replacement of a draft; `partial=True` lets `{}` succeed and keeps every old value (BF-DJ-02). Fix: `partial=False` on PUT. Proof: V333.

## BD-HC-6a — The Idempotency-Key store key has no principal or tenant — another caller's reuse gets the first caller's stored response

```defect
id:       BD-HC-6a
file:     apps/api/src/common/idempotency/idempotency.interceptor.ts
line:     30
severity: high
command:  /backend-audit
class:    http/idempotency-key-not-scoped
detector: http-contract-scan §6
anchor:   const storeKey = `idem:${key}`;
match:    tenant|principal|scope|key|another
```

On `POST /v1/support-tickets` (an HC §6 route; `/v1/payments/captures` uses the same interceptor and is security §4's) two tenants sending the same UUID collide: the second receives the first ticket. Fix: `idem:${tenantId}:${route}:${key}`. Proof: V334 (S1 property shape).

## BD-HC-6b — Replay without a body fingerprint — the same key with a different body returns the first response

```defect
id:       BD-HC-6b
file:     apps/api/src/common/idempotency/idempotency.interceptor.ts
line:     34
severity: high
command:  /backend-audit
class:    http/idempotency-no-fingerprint
detector: http-contract-scan §6
anchor:   return of(rec.response.body);
match:    fingerprint|body hash|different body|replay|422
```

The client believes the second, different ticket was opened (B-A14 flips back; B-G7). The replay is also stored and returned as 200, not the original status. Fix: hash the body into the record and answer 422 on mismatch. Proof: V334.

## BD-HC-7a — The activity feed bypasses the pagination kernel — one non-unique sort key with a limit, `before=<occurredAt>`

```defect
id:       BD-HC-7a
file:     apps/api/src/activity/activity-feed.controller.ts
line:     39
severity: medium
command:  /backend-audit
class:    http/pagination-no-tiebreak
detector: http-contract-scan §7
anchor:   { limit: 50, orderBy: { occurredAt: 'desc' } }
match:    tiebreak|orderBy|occurredAt|kernel|unique|skip
```

Events sharing a timestamp at the page edge are skipped (`$lt` on a tie). The conventions route every client list through `common/pagination`. Fix: keyset on `(occurredAt, id)` or the kernel. Proof: V335 (S3 completeness).

## BD-HC-7b — `limit` taken from the query with no clamp — `?limit=1000000` dumps the audit log, `?limit=abc` → `NaN`

```defect
id:       BD-HC-7b
file:     apps/admin/src/routes/audit-log.routes.ts
line:     9
severity: high
command:  /backend-audit
class:    http/limit-unbounded
detector: http-contract-scan §7
anchor:   const take = Number(req.query.limit ?? 50);
match:    limit|clamp|max|NaN|unbounded|take
```

Compliance exports page this list; no server maximum (B-G10: over-max is coerced down). Fix: `Math.min(Math.max(n, 1), 100)` with an integer check. Proof: V335.

## BD-HC-7c — DRF pagination over an unordered queryset — pages skip and repeat overdue invoices

```defect
id:       BD-HC-7c
file:     services/billing-py/billing/views.py
line:     26
severity: medium
command:  /backend-audit
class:    http/drf-unordered-pagination
detector: http-contract-scan §7
anchor:   queryset = Invoice.objects.filter(status="overdue")
match:    order_by|unordered|UnorderedObjectListWarning|pagination
```

`OverdueInvoiceList` pages `Invoice.objects.filter(...)` with no `order_by` (BF-DJ-04, `UnorderedObjectListWarning`). Fix: `.order_by("issued_at", "id")`. Proof: V335; `-W error::UnorderedObjectListWarning` in the tool lane.

## BD-HC-8a — `POST /v1/orders/bulk` swallows per-item failures and answers 200 with `created[]` only

```defect
id:       BD-HC-8a
file:     apps/api/src/orders/orders-bulk.controller.ts
line:     11
severity: high
command:  /backend-audit
class:    http/batch-partial-failure-hidden
detector: http-contract-scan §8
anchor:   @Post('bulk')
match:    bulk|batch|207|partial|catch|continue
```

Partners cannot tell which orders failed (no per-item status, no index alignment) and retry the whole batch, duplicating the rest. Fix: all-or-nothing in one transaction, or 207 with `results[i]` aligned (B-G15). Proof: V336.

## BD-HC-8b — ERP batch import drops failing rows (`except Exception: continue`) and answers 200

```defect
id:       BD-HC-8b
file:     services/billing-py/billing/views_batch.py
line:     12
severity: high
command:  /backend-audit
class:    http/batch-partial-failure-hidden
detector: http-contract-scan §8
anchor:   for row in request.data.get("invoices", []):
match:    batch|207|partial|except|continue
```

The docstring says callers retry the whole batch on non-2xx; a partial success answers 200 with no per-row status. Fix: atomic batch or 207 with per-row results. Proof: V336.

## BD-HC-9a — `Deprecation: true` — the draft syntax; RFC 9745 is `@<unix-seconds>`, and no `Sunset`

```defect
id:       BD-HC-9a
file:     apps/admin/src/routes/legacy.routes.ts
line:     9
severity: low
command:  /backend-audit
class:    http/deprecation-draft-syntax
detector: http-contract-scan §9
anchor:   res.setHeader('Deprecation', 'true');
match:    Deprecation|true|@\d|RFC 9745|Sunset
```

The conventions mandate `@<epoch>` plus a later `Sunset`. Fix: `Deprecation: @<ts>` and `Sunset`. Proof: V337.

## BD-HC-9b — `Sunset` (2026-09-01) is earlier than `Deprecation` (@1798761600 = 2027-01-01)

```defect
id:       BD-HC-9b
file:     apps/api/src/legacy/deprecation.hook.ts
line:     6
severity: low
command:  /backend-audit
class:    http/sunset-before-deprecation
detector: http-contract-scan §9
anchor:   const SUNSET_AT = 'Tue, 01 Sep 2026 00:00:00 GMT';
match:    Sunset|Deprecation|before|2026|2027
```

Clients read the route as already retired before it is deprecated. Fix: `Sunset` six months after the deprecation date. Proof: V337.

## BD-HC-10a — `oasdiff breaking` without `--fail-on ERR` — exits 0 on a breaking diff, so the spec gate never fails

```defect
id:       BD-HC-10a
file:     .github/workflows/api.yml
line:     25
severity: high
command:  /backend-audit
class:    http/spec-gate-no-fail-on
detector: http-contract-scan §10
anchor:   run: oasdiff breaking openapi/openapi.yaml openapi/openapi.generated.yaml --format githubactions
match:    fail-on|oasdiff|breaking|exit 0|gate
```

The generated spec already drifts (201 on preview, `total` string → number, `partnerReference` no longer required, 204 on DELETE); CI stays green. Fix: `--fail-on ERR`. Proof: V338 — the same command with `--fail-on ERR` exits 1 on these two files.

## BD-HC-10b — `@ApiPropertyOptional` with `@IsNotEmpty()` — the generated spec says optional, the server requires it

```defect
id:       BD-HC-10b
file:     apps/api/src/quotes/quote-preview.dto.ts
line:     17
severity: medium
command:  /backend-audit
class:    http/spec-optional-server-requires
detector: http-contract-scan §10
anchor:   @ApiPropertyOptional({ description: 'Partner reference echoed on the quote' })
match:    ApiPropertyOptional|IsNotEmpty|optional|required|drift
```

SDKs generated from the spec omit `partnerReference` and get 400; the committed spec still lists it as required (the drift oasdiff would catch). Fix: `@ApiProperty()` (or make it truly optional). Proof: V338.

## BD-HC-10c — `npx @tufin/oasdiff` — not an npm package; the local spec diff never runs (and has no `--fail-on`)

```defect
id:       BD-HC-10c
file:     apps/api/package.json
line:     11
severity: medium
command:  /backend-audit
class:    http/spec-diff-npm-placeholder
detector: http-contract-scan §10
anchor:   "spec:diff": "npx @tufin/oasdiff
match:    npx|@tufin/oasdiff|npm|not on npm|NOT-RUN
```

npm has no oasdiff (`@tufin/oasdiff` 404s): the developer-facing check is NOT-RUN, never clean. Fix: the pinned Go binary or `tufin/oasdiff:v1.33.0`, with `--fail-on ERR`. Proof: V338.

## BD-HC-11a — Express 5 route `'/invoice-pdf/:id?'` — path-to-regexp 8 throws at boot

```defect
id:       BD-HC-11a
file:     apps/admin/src/routes/invoices.routes.ts
line:     15
severity: critical
command:  /backend-audit
class:    http/express5-optional-param-throws-at-boot
detector: http-contract-scan §11
anchor:   router.get('/invoice-pdf/:id?'
match:    path-to-regexp|:id\?|boot|Express 5|\{/:id\}
```

express 5.1.0 (pnpm-lock.yaml): the `?` optional-parameter syntax is gone; the admin app fails to start. Fix: `/invoice-pdf{/:id}`. Proof: V346 / V357 — boot on the installed version.

## BD-HC-11b — `req.query.filter.status` on Express 5 — the default `simple` parser never nests `filter[status]`, so the list is unfiltered

```defect
id:       BD-HC-11b
file:     apps/admin/src/routes/invoices.routes.ts
line:     9
severity: high
command:  /backend-audit
class:    http/express5-simple-query-parser
detector: http-contract-scan §11
anchor:   const status = req.query.filter && req.query.filter.status;
match:    query parser|filter\[status\]|simple|extended|unfiltered
```

`?filter[status]=overdue` arrives as the flat key `"filter[status]"`; `status` is undefined and every invoice is listed. Fix: `app.set("query parser", "extended")` or read the flat key. Proof: V346.

## BD-HC-11c — Fastify `onRequest` hook reads `request.body` — the body is not parsed yet, so it is always undefined

```defect
id:       BD-HC-11c
file:     apps/api/src/tenancy/tenant.hook.ts
line:     14
severity: high
command:  /backend-audit
class:    http/onrequest-reads-body
detector: http-contract-scan §11
anchor:   const fromBody = (request.body as
match:    onRequest|body|preHandler|parsed|tenant
```

Partner posts that carry `tenantId` only in the body resolve no tenant. (Which tenant a request may act for is security's reading, P3.) Fix: `preHandler` (after parsing). Proof: V346.

## BD-HC-11d — `new DataLoader` at module scope — its cache lives for the process: stale products across requests

```defect
id:       BD-HC-11d
file:     apps/api/src/graphql/loaders.ts
line:     11
severity: high
command:  /backend-audit
class:    http/dataloader-module-scope
detector: http-contract-scan §11
anchor:   export const productLoader = new DataLoader
match:    DataLoader|module scope|per request|cache|stale
```

A price change never shows until the process restarts; across tenants the cache also serves another tenant's row (that reading routes to security). Fix: build loaders per request (`graphql/request-loaders.ts` does). Proof: V346.

## BD-HC-11e — `products: [Product!]!` over a loader that returns `null` for unpublished products — one null nulls the whole `category`

```defect
id:       BD-HC-11e
file:     apps/api/src/graphql/catalog.graphql
line:     12
severity: medium
command:  /backend-audit
class:    http/graphql-nonnull-list-blast-radius
detector: http-contract-scan §11
anchor:   products: [Product!]!
match:    \[Product!\]!|non-null|null|data|blast
```

The schema's own description says products can disappear between reads; `productLoader` returns `null` → the non-null error propagates up. Fix: `[Product]!` or filter nulls in the resolver. Proof: V346 with one unpublished product.

## BD-HC-12a — `geoClient.Do` with no `defer resp.Body.Close()` — every response (and every non-200) leaks a connection

```defect
id:       BD-HC-12a
file:     services/edge-go/internal/upstream/geo.go
line:     19
severity: medium
command:  /backend-audit
class:    http/go-body-not-closed
detector: http-contract-scan §12
anchor:   resp, err := geoClient.Do(req)
match:    Body\.Close|bodyclose|leak|defer
```

golangci-lint `bodyclose` flags it; under load the edge runs out of connections to the geo provider. Fix: `defer resp.Body.Close()` right after the error check. Proof: V354 (FD count stable at 2 × pool + 1).

## BD-HC-12b — Outbound POST to the PSP with default redirect handling — a 302 is replayed as a GET that "succeeds"

```defect
id:       BD-HC-12b
file:     apps/admin/src/services/psp-capture.ts
line:     11
severity: medium
command:  /backend-audit
class:    http/post-follows-redirect
detector: http-contract-scan §12
anchor:   method: 'POST',
match:    redirect|manual|302|POST|GET
```

`fetch` follows a 302/303 on POST as GET and drops the body; the capture looks successful. The api's `OutboundHttp` sets `redirect: "manual"` once (P5); the admin client does not. Fix: `redirect: "manual"` and treat 3xx as an error. Proof: V355.

## BD-HC-12c — `requests.get(..., stream=True)` outside `with` — the "too large" branch leaves the connection checked out

```defect
id:       BD-HC-12c
file:     services/billing-py/billing/exports.py
line:     11
severity: medium
command:  /backend-audit
class:    http/python-stream-not-closed
detector: http-contract-scan §12
anchor:   resp = requests.get(url, stream=True, timeout=(3, 30))
match:    stream=True|with|close|leak
```

A streamed response is released only when fully read or closed; the `ValueError` path does neither. Fix: `with requests.get(...) as resp:`. Proof: V354.

## BD-HC-13a — multer `fileFilter` reads `req.body.kind` — undefined unless the client sends the field before the file

```defect
id:       BD-HC-13a
file:     apps/admin/src/routes/uploads.routes.ts
line:     14
severity: medium
command:  /backend-audit
class:    http/multipart-field-order
detector: http-contract-scan §13
anchor:   const kind = req.body.kind;
match:    fileFilter|req\.body|field order|before the file|multipart
```

Field order is not guaranteed by browsers or SDKs: a logo sent file-first is filtered as a PDF and dropped. Fix: decide after the upload, or document and enforce field-first (as `contracts.controller.ts` does). Proof: V356 — file-first vs file-last give the same outcome.

## BD-HC-13b — `request.parts()` loop stores the file before the `kind` field is read — file-first uploads land in `documents/misc/`

```defect
id:       BD-HC-13b
file:     apps/api/src/documents/documents.controller.ts
line:     17
severity: medium
command:  /backend-audit
class:    http/multipart-field-order
detector: http-contract-scan §13
anchor:   key = await this.storage.put(`documents/${kind ?? 'misc'}/${part.filename}`, part.file);
match:    parts\(\)|kind|field order|misc|multipart
```

Nothing in the contract fixes the part order. Fix: buffer fields first or stream to a temp key and move once `kind` is known. Proof: V356.

## BD-HC-13c — `CompleteMultipartUpload` in a `finally` — an aborted client stream still completes a truncated object

```defect
id:       BD-HC-13c
file:     apps/api/src/storage/storage.service.ts
line:     25
severity: medium
command:  /backend-audit
class:    http/partial-upload-completed
detector: http-contract-scan §13
anchor:   await this.s3.send(new CompleteMultipartUploadCommand
match:    CompleteMultipartUpload|finally|abort|partial
```

A disconnect at 50 % leaves a valid-looking partial document. Fix: complete only on success; `AbortMultipartUpload` in `catch`. Proof: V356 — abort mid-stream: no object.

## BD-WF-1a — `COERCE_DECIMAL_TO_STRING: False` — every DRF decimal leaves as a JSON float

```defect
id:       BD-WF-1a
file:     services/billing-py/billing_service/settings.py
line:     42
severity: high
command:  /backend-audit
class:    wire/drf-decimal-as-float
detector: wire-format-scan §1
anchor:   "COERCE_DECIMAL_TO_STRING": False,
match:    COERCE_DECIMAL_TO_STRING|float|10\.1|scale|string
```

Money is a decimal string by contract; `10.10` renders `10.1`, `9007199254740993.00` loses digits. Fix: remove the setting (default `True`). Proof: V339 rendered-body round trip.

## BD-WF-1b — `total: Number(order.totalAmount)` — the decimal column leaves as a float: `10.10` → `10.1`

```defect
id:       BD-WF-1b
file:     apps/api/src/orders/order.mapper.ts
line:     16
severity: high
command:  /backend-audit
class:    wire/decimal-to-number
detector: wire-format-scan §1
anchor:   total: Number(order.totalAmount),
match:    Number\(|totalAmount|float|10\.1|string|scale
```

Shown in round-trip.txt and the Schemathesis report (`total` is not of type string); clients re-submit `total` to payment pages. Fix: keep the string (`total: order.totalAmount`). Proof: V339.

## BD-WF-2a — `@Property({ type: "bigint" }) pspTransactionId!: number` read straight into a response — values past 2^53 change

```defect
id:       BD-WF-2a
file:     apps/api/src/ledger/ledger-entry.entity.ts
line:     10
severity: high
command:  /backend-audit
class:    wire/bigint-as-number
detector: wire-format-scan §2
anchor:   pspTransactionId!: number;
match:    bigint|2\^53|number|precision|string|pspTransactionId
```

`9007199254740993` renders `…992` (round-trip.txt); finance re-submits it to the PSP lookup. No mapper (contrast `journal.mapper.ts`, B-D5). Fix: type it `string` and render a string. Proof: V339.

## BD-WF-2b — PIM documents decoded into `map[string]any` without `UseNumber()` — 64-bit ids become `float64`

```defect
id:       BD-WF-2b
file:     services/edge-go/internal/upstream/catalog.go
line:     27
severity: high
command:  /backend-audit
class:    wire/go-any-float64
detector: wire-format-scan §2
anchor:   var item map[string]any
match:    map\[string\]any|UseNumber|float64|64-bit
```

The handler re-encodes the map, so `id: 9007199254740993` leaves as `…992`. Fix: `dec.UseNumber()` or a typed struct with `int64`/`json:",string"`. Proof: V339.

## BD-WF-3a — Fastify response schema types `amount` as `integer` — `12.70` renders `12`

```defect
id:       BD-WF-3a
file:     apps/api/src/fx/fx.routes.ts
line:     22
severity: high
command:  /backend-audit
class:    wire/fastify-response-schema-truncates
detector: wire-format-scan §3
anchor:   amount: { type: 'integer' },
match:    response schema|integer|12\.7|12|truncat|fast-json-stringify
```

fast-json-stringify coerces to the schema type (`12.7` → `12`, round-trip.txt). Fix: `type: "string"` and return the decimal string. Proof: V338 — response equals the domain value.

## BD-WF-3b — `excludeExtraneousValues: true` while `InvoiceResponse.taxAmount` has no `@Expose()` — the 2.4.0 VAT field never ships

```defect
id:       BD-WF-3b
file:     apps/api/src/invoices/invoices.controller.ts
line:     10
severity: high
command:  /backend-audit
class:    wire/serializer-drops-field
detector: wire-format-scan §3
anchor:   @SerializeOptions({ excludeExtraneousValues: true })
match:    excludeExtraneousValues|Expose|taxAmount|dropped
```

Transcript: `GET /v1/invoices/<id>` body has no `taxAmount` (round-trip.txt). Fix: `@Expose() taxAmount`. Proof: V338.

## BD-WF-4a — DRF `DecimalField(decimal_places=2)` over a 4-dp amount, no `rounding=` — `10.1250` renders `10.12` (half-even)

```defect
id:       BD-WF-4a
file:     services/billing-py/billing/serializers.py
line:     8
severity: medium
command:  /backend-audit
class:    wire/output-rounding-half-even
detector: wire-format-scan §4
anchor:   amount_due = serializers.DecimalField(max_digits=12, decimal_places=2)
match:    DecimalField|rounding|half|10\.12|decimal_places
```

The model computes at 4 dp; the PSP rounds half-up (`tax.psp_amount`), so the shown and charged amounts differ by a cent on ties (round-trip.txt). Fix: `rounding=ROUND_HALF_UP` (or quantize before save). Proof: V348.

## BD-WF-4b — `quantize(CENT)` with no rounding mode — VAT is banker's-rounded while the PSP rounds half-up

```defect
id:       BD-WF-4b
file:     services/billing-py/billing/tax.py
line:     8
severity: high
command:  /backend-audit
class:    wire/quantize-no-rounding-mode
detector: wire-format-scan §4
anchor:   return (net * rate).quantize(CENT)
match:    quantize|rounding|ROUND_HALF|half-even|VAT
```

The docstring says this value is printed and sent to the PSP (B-R4 flips: the rendered number is the charged number). Fix: `rounding=ROUND_HALF_UP`, as `psp_amount` does. Proof: V348 with `x.xx5` ties.

## BD-WF-5a — BullMQ capture payload carries `Number(dto.amount)` — money crosses the queue as a float

```defect
id:       BD-WF-5a
file:     apps/api/src/payments/capture.producer.ts
line:     15
severity: high
command:  /backend-audit
class:    wire/float-money-in-queue
detector: wire-format-scan §5
anchor:   amount: Number(dto.amount),
match:    Number\(|float|queue|payload|minor units|amount
```

`19.99` and 3-dp currencies (KWD `1.005`) become binary floats the worker charges from. Fix: the decimal string or integer minor units + currency (as `payout.producer.ts`). Proof: V348 — read the raw Redis payload.

## BD-WF-5b — Celery `charge_card.delay(..., float(invoice.amount_due), ...)` — the charge amount crosses the broker as a float

```defect
id:       BD-WF-5b
file:     services/billing-py/billing/services.py
line:     18
severity: high
command:  /backend-audit
class:    wire/float-money-in-queue
detector: wire-format-scan §5
anchor:   charge_card.delay(invoice.pk, float(invoice.amount_due), invoice.currency)
match:    float\(|delay|payload|amount_due|Celery
```

The 4-dp decimal is truncated to a binary float and re-sent to the PSP. Fix: `str(amount)` or integer minor units. Proof: V348.

## BD-WF-6a — `dueDate` (a calendar day) bound with `@Type(() => Date) @IsDate()` — coerced to an instant before validation

```defect
id:       BD-WF-6a
file:     apps/api/src/invoices/dto/create-invoice.dto.ts
line:     15
severity: medium
command:  /backend-audit
class:    wire/calendar-date-as-instant
detector: wire-format-scan §6
anchor:   @Type(() => Date)
match:    @Type\(\(\) => Date\)|IsDate|dueDate|2026-02-30|calendar|zone
```

`"2026-02-30"` rolls to March 2; `toISOString().slice(0, 10)` in the use case shifts the day under `TZ=America/New_York` (the image's zone). VB §3 lists the same line as corroboration. Fix: `@IsISO8601({ strict: true })` / `@Matches(/^\d{4}-\d{2}-\d{2}$/)` and keep a string. Proof: V347.

## BD-WF-6b — `time.Parse("2006-01-02 15:04", ...)` — the store's local time is read as UTC

```defect
id:       BD-WF-6b
file:     services/edge-go/internal/http/slots.go
line:     12
severity: medium
command:  /backend-audit
class:    wire/go-time-parse-no-zone
detector: wire-format-scan §6
anchor:   time.Parse("2006-01-02 15:04", c.Query("from"))
match:    time\.Parse|zone|UTC|ParseInLocation|local
```

Slots are rendered as RFC 3339 `Z` times offset by the store's zone (4 h in Dubai). Fix: `time.ParseInLocation(layout, s, storeLoc)` or require an offset. Proof: V347.

## BD-WF-7a — `USE_TZ = False` with `TIME_ZONE = "Asia/Dubai"` — every instant is stored and rendered without an offset

```defect
id:       BD-WF-7a
file:     services/billing-py/billing_service/settings.py
line:     48
severity: high
command:  /backend-audit
class:    wire/django-use-tz-false
detector: wire-format-scan §7
anchor:   USE_TZ = False
match:    USE_TZ|naive|offset|TIME_ZONE|aware
```

`issued_at` and `updated_at` leave as naive local strings; the ERP sync (UTC) reads them 4 h off. Fix: `USE_TZ = True` (with a data migration). Proof: V349 — identical responses under two server zones.

## BD-WF-7b — The sync cursor encodes `updated_at` with `DjangoJSONEncoder` — microseconds cut to milliseconds

```defect
id:       BD-WF-7b
file:     services/billing-py/billing/views_feed.py
line:     13
severity: high
command:  /backend-audit
class:    wire/cursor-precision-lost
detector: wire-format-scan §7
anchor:   cls=DjangoJSONEncoder
match:    DjangoJSONEncoder|microsecond|millisecond|cursor|precision
```

Rows updated within the same millisecond after the cursor are skipped forever by the keyset `updated_at > c.u`. Fix: `isoformat()` with microseconds (or an integer epoch-µs). Proof: V349 — round-trip `…10:00:00.123456`.

## BD-JL-1a — The whole `Order` entity is the job payload; `RepriceProcessor` merges it back and flushes

```defect
id:       BD-JL-1a
file:     apps/api/src/pricing/reprice.producer.ts
line:     15
severity: high
command:  /backend-audit
class:    jobs/entity-in-payload
detector: job-lifecycle-scan §1
anchor:   await this.repriceQueue.add('reprice-order', order);
match:    payload|entity|stale|id|reprice
```

An order paid or cancelled between enqueue and run is overwritten with the stale snapshot (`em.merge(Order, job.data)` + flush). Fix: enqueue `{ orderId }` and reload. Proof: V351 — enqueue at v1, update to v2, run → v2 kept.

## BD-JL-1b — `send_invoice_email.delay(invoice)` — a pickled model instance; the task saves it back

```defect
id:       BD-JL-1b
file:     services/billing-py/billing/services.py
line:     12
severity: medium
command:  /backend-audit
class:    jobs/model-in-payload
detector: job-lifecycle-scan §1
anchor:   send_invoice_email.delay(invoice)
match:    delay\(invoice\)|pickle|model|stale|id
```

`celery.py` switched the serializer to pickle for this; the task writes `status = "sent"` over whatever changed since (a void or a payment). Fix: pass `invoice.pk`, reload, update one field. Proof: V351.

## BD-JL-2a — The PDF processor `findOneOrFail`s an invoice merchants may delete — the job fails instead of discarding

```defect
id:       BD-JL-2a
file:     apps/api/src/invoices/invoice-pdf.processor.ts
line:     14
severity: medium
command:  /backend-audit
class:    jobs/deleted-record-fails
detector: job-lifecycle-scan §2
anchor:   findOneOrFail(Invoice, { id: job.data.invoiceId })
match:    findOneOrFail|deleted|discard|not found|retry
```

Drafts deleted before the render throw `NotFoundError`; the `failed` listener is empty, so the failure is noise. Fix: `findOne` + discard on null. Proof: V351 — enqueue, delete, run → one discard, 0 retries.

## BD-JL-2b — Celery `render_invoice_pdf` uses `.get(pk=…)` with no `DoesNotExist` branch

```defect
id:       BD-JL-2b
file:     services/billing-py/billing/tasks.py
line:     10
severity: medium
command:  /backend-audit
class:    jobs/deleted-record-fails
detector: job-lifecycle-scan §2
anchor:   invoice = Invoice.objects.get(pk=invoice_id)
match:    objects\.get|DoesNotExist|deleted|discard
```

A draft deleted before the task runs raises `DoesNotExist` (a failed task per deletion). Fix: `.filter(...).first()` + return, as `send_dunning` does. Proof: V351.

## BD-JL-3a — The settlement processor reads `job.data.currency`, which `SettlementScheduler` never sets

```defect
id:       BD-JL-3a
file:     apps/api/src/settlement/settlement.processor.ts
line:     25
severity: high
command:  /backend-audit
class:    jobs/payload-field-never-set
detector: job-lifecycle-scan §3
anchor:   job.data.currency.toUpperCase(),
match:    currency|job\.data|producer|payload|drift|delay
```

Jobs carry a 6 h delay, so payloads from the previous deploy are always in flight; every `settle-day` job throws `TypeError` today. Fix: add `currency` to the producer with a payload `version` and a default for old jobs. Proof: V351 cross-commit replay.

## BD-JL-3b — `send_dunning(invoice_id, template)` gained a required argument; producers still call it with one

```defect
id:       BD-JL-3b
file:     services/billing-py/billing/tasks.py
line:     22
severity: high
command:  /backend-audit
class:    jobs/task-signature-drift
detector: job-lifecycle-scan §3
anchor:   def send_dunning(self, invoice_id, template):
match:    template|signature|positional|apply_async|drift
```

`services.remind_overdue` sends `args=[inv.pk]` with a 1 h countdown: every queued and new reminder fails with `TypeError` (B-R7 flips: queued messages cross deploys). Fix: `template="friendly"` default and a versioned payload. Proof: V351.

## BD-JL-4a — `@Cron('*/1 * * * * *')` money sweep (~2.5 s) with no `waitForCompletion` and no guard — runs overlap on one process

```defect
id:       BD-JL-4a
file:     apps/api/src/settlement/settlement.scheduler.ts
line:     12
severity: critical
command:  /backend-audit
class:    jobs/cron-self-overlap-money
detector: job-lifecycle-scan §4
anchor:   @Cron('*/1 * * * * *'
match:    waitForCompletion|overlap|every second|2\.5|guard|lock
```

@nestjs/schedule 6.1.3 on cron 4.4.0 (pnpm-lock.yaml): overlap is the default, so two sweeps read the same unsettled captures and credit merchant balances twice. Money job → BLOCKER floor. It also runs on all 3 replicas (deploy/api-deployment.yaml) — a second finding for performance §20. Fix: `waitForCompletion: true` and a claim (`update … set settled_at … returning`). Proof: V352 — 1 s schedule, 2.5 s body, 6 s → max concurrency 1.

## BD-JL-4b — robfig `cron.New()` without `SkipIfStillRunning` — the 5-minute partner stock sync (5–8 min at peak) overlaps itself

```defect
id:       BD-JL-4b
file:     services/edge-go/internal/jobs/sync.go
line:     14
severity: high
command:  /backend-audit
class:    jobs/robfig-no-skip
detector: job-lifecycle-scan §4
anchor:   c := cron.New(
match:    SkipIfStillRunning|DelayIfStillRunning|overlap|robfig
```

Two syncs apply the same deltas. Fix: `cron.WithChain(cron.SkipIfStillRunning(logger))`. Proof: V352.

## BD-JL-5a — APScheduler month-end close with the default `misfire_grace_time` (1 s) — a late start skips the month

```defect
id:       BD-JL-5a
file:     services/billing-py/billing/scheduler.py
line:     12
severity: high
command:  /backend-audit
class:    jobs/misfire-default-skips
detector: job-lifecycle-scan §5
anchor:   scheduler.add_job(close_month
match:    misfire_grace_time|coalesce|misfire|month-end|skipped
```

The scheduler pod restarting at 04:00 on the 1st skips the close entirely; finance needs exactly one run. Fix: `misfire_grace_time=6*3600, coalesce=True` plus a "period closed?" check. Proof: V352 — downtime across the fire time on a fake clock.

## BD-JL-5b — Monthly invoicing on an in-process `@Cron` — if no process is up at 05:00 on the 1st, the month is never invoiced

```defect
id:       BD-JL-5b
file:     apps/api/src/invoices/invoicing.scheduler.ts
line:     12
severity: high
command:  /backend-audit
class:    jobs/in-process-no-catch-up
detector: job-lifecycle-scan §5
anchor:   @Cron('0 5 1 * *'
match:    misfire|catch-up|in-process|month|missed
```

npm `cron` keeps nothing durable; a deploy or crash at the fire time loses the run. Fix: a durable scheduler (BullMQ job scheduler) or a "last run" row checked at boot. Proof: V352.

## BD-JL-6a — `@Cron('30 2 * * *')` with no `timeZone` — the process zone is `America/New_York` (Dockerfile), so 02:30 does not exist on spring-forward day

```defect
id:       BD-JL-6a
file:     apps/api/src/payouts/payout-cutoff.scheduler.ts
line:     12
severity: high
command:  /backend-audit
class:    jobs/schedule-zone-dst
detector: job-lifecycle-scan §6
anchor:   @Cron('30 2 * * *'
match:    timeZone|TZ|DST|02:30|America/New_York|zone
```

The payout cutoff is skipped once a year and the business zone is Asia/Dubai anyway. The same in-process entry also has no catch-up (JL §5 prints it in 5a): one site, two classes — score either. Fix: `timeZone: "Asia/Dubai"` (and a durable or catch-up schedule). Proof: V352 — the library iterator over a year.

## BD-JL-6b — `AddFunc("0 1 * * *")` with no `WithLocation`/`CRON_TZ` in a `TZ=Europe/London` image — 01:00 is skipped in March and runs twice in October

```defect
id:       BD-JL-6b
file:     services/edge-go/internal/jobs/sync.go
line:     20
severity: medium
command:  /backend-audit
class:    jobs/schedule-zone-dst
detector: job-lifecycle-scan §6
anchor:   _, _ = c.AddFunc("0 1 * * *", expireLoyaltyPoints)
match:    CRON_TZ|WithLocation|Europe/London|DST|01:
```

Loyalty points expire twice (or not at all) on DST days. Fix: `cron.WithLocation(time.UTC)` or `CRON_TZ=Europe/London` at a DST-safe hour. Proof: V352.

## BD-JL-7a — BullMQ receipts worker: `attempts: 1`, no `failed` listener — a failed VAT receipt leaves no record anyone reads

```defect
id:       BD-JL-7a
file:     apps/api/src/notifications/receipt.worker.ts
line:     12
severity: medium
command:  /backend-audit
class:    jobs/failure-discarded
detector: job-lifecycle-scan §7
anchor:   export const receiptWorker = new Worker(
match:    failed|attempts|listener|DLQ|silent
```

The customer never gets the receipt and nobody is told. Fix: a `failed` listener that records the failure (and `attempts` with backoff — retry policy is distributed-systems'). Proof: V353 — make it throw → a failure record exists.

## BD-JL-7b — `ignore_result=True` on a task whose result the console polls with `AsyncResult`

```defect
id:       BD-JL-7b
file:     services/billing-py/billing/reports_tasks.py
line:     5
severity: medium
command:  /backend-audit
class:    jobs/ignore-result-then-polled
detector: job-lifecycle-scan §7
anchor:   @shared_task(ignore_result=True)
match:    ignore_result|AsyncResult|PENDING|result
```

`AgingReportStatus` reads `result.state` — with results ignored it is `PENDING` forever, success or failure. Fix: drop `ignore_result` (and set a result backend) or persist a report row. Proof: V353.

## BD-ST-1a — `transitions.Machine(..., ignore_invalid_triggers=True)` then `refund.approve()` unchecked → the PSP refund runs

```defect
id:       BD-ST-1a
file:     services/billing-py/billing/refunds.py
line:     20
severity: critical
command:  /backend-audit
class:    transitions/illegal-event-then-refund
detector: state-transition-scan §1
anchor:   model_attribute="state", ignore_invalid_triggers=True)
match:    ignore_invalid_triggers|approve|refund|illegal|409
```

Approving an already `paid` or `rejected` refund returns False silently and `refund_capture` pays again: an illegal event reaches money (BLOCKER floor). Fix: drop the flag (raise `MachineError` → 409) or check the trigger's return before the effect. Proof: V350 — (paid × approve) → 409 and zero PSP calls.

## BD-ST-1b — XState `actor.send({ type: 'REFUND' })` with no `can()` — a cancelled order is refunded in full

```defect
id:       BD-ST-1b
file:     apps/api/src/orders/order-workflow.service.ts
line:     26
severity: critical
command:  /backend-audit
class:    transitions/illegal-event-then-refund
detector: state-transition-scan §1
anchor:   actor.send({ type: 'REFUND' });
match:    send|can\(|REFUND|illegal|refund
```

XState ignores an event the state does not accept; the service then calls `refundInFull` and writes `refunded`. Contrast `shipments.service.ts`, which asks `can()` first. Fix: `if (!actor.getSnapshot().can({ type: "REFUND" })) throw new IllegalStateError(…)`. Proof: V350.

## BD-ST-1c — `actor.send({ type: 'CANCEL' })` with no `can()` — cancelling a shipped order answers `{"status":"cancelled"}`

```defect
id:       BD-ST-1c
file:     apps/api/src/orders/order-workflow.service.ts
line:     18
severity: high
command:  /backend-audit
class:    transitions/illegal-event-answered-success
detector: state-transition-scan §1
anchor:   actor.send({ type: 'CANCEL' });
match:    send|can\(|CANCEL|cancelled|success|409
```

XState ignores CANCEL outside `open`; the state is written back unchanged and `GET /v1/orders/:id/cancel` still answers "cancelled" (no money moves, so High, not the BLOCKER floor). Fix: check `can()` and answer 409 `ILLEGAL_STATE`. Proof: V350 — (shipped × CANCEL) → 409, state unchanged.

## BD-ST-2a — `add_transition("reopen", source="*", dest="open")` — a `won` or `lost` dispute (final) can be re-opened

```defect
id:       BD-ST-2a
file:     services/billing-py/billing/disputes.py
line:     12
severity: high
command:  /backend-audit
class:    transitions/wildcard-reopens-terminal
detector: state-transition-scan §2
anchor:   machine.add_transition("reopen", source="*", dest="open")
match:    source="\*"|wildcard|terminal|won|lost|reopen
```

The card network ruling is final; support can re-open it and the evidence workflow runs again. Fix: `source=["evidence_submitted"]` (or no re-open). Proof: V350 — (terminal × every event) → no change.

## BD-ST-2b — The PSP webhook writes `order.status = 'paid'` directly — a late `payment.succeeded` re-opens a cancelled or refunded order

```defect
id:       BD-ST-2b
file:     apps/api/src/webhooks/psp-webhook.handler.ts
line:     29
severity: high
command:  /backend-audit
class:    transitions/direct-status-write-bypasses-machine
detector: state-transition-scan §2
anchor:   order.status = 'paid';
match:    status = 'paid'|machine|terminal|refunded|cancelled|webhook
```

`order.machine.ts` marks `cancelled`/`refunded` final; the webhook path bypasses it. Fix: send `PAY` through the machine and ignore (200) events the state does not accept. Proof: V350 via the webhook path.

## BD-HO-DB-a — `queue.add` inside `em.transactional` — the worker can run before the commit, or for a rolled-back order

```defect
id:       BD-HO-DB-a
file:     apps/api/src/orders/place-order.use-case.ts
line:     19
severity: high
command:  /db-audit
class:    database/enqueue-inside-transaction
detector: transaction-scan §1 (database)
anchor:   await this.fulfilmentQueue.add('reserve-stock'
match:    transaction|enqueue|queue\.add|commit|outbox
```

Routed: `/backend-audit` lists it `→ database transaction-scan §1`, never grades it (B-R6).

## BD-HO-DB-b — `post_save` → `.delay()` under `ATOMIC_REQUESTS` — the task can read the invoice before the request commits

```defect
id:       BD-HO-DB-b
file:     services/billing-py/billing/signals.py
line:     11
severity: high
command:  /db-audit
class:    database/model-callback-enqueue-before-commit
detector: transaction-scan §1 (database)
anchor:   render_invoice_pdf.delay(instance.pk)
match:    post_save|on_commit|delay|transaction|ATOMIC_REQUESTS
```

Fix belongs to the owner (`transaction.on_commit`). Routed.

## BD-HO-CQ-a — `fetch(...).then((r) => r.json())` with no `r.ok` check — a 500 page is parsed as a geocode

```defect
id:       BD-HO-CQ-a
file:     apps/admin/src/services/geo.ts
line:     11
severity: medium
command:  /quality-audit
class:    code-quality/outbound-status-unchecked
detector: error-handling-scan §3 (code-quality)
anchor:   .then((r) => r.json())
match:    \.ok|status|json\(\)|unchecked
```

Routed (B-R12).

## BD-HO-CQ-b — `(await res.json()) as Rates` — the provider response is cast with no runtime check

```defect
id:       BD-HO-CQ-b
file:     apps/api/src/fx/fx.client.ts
line:     13
severity: medium
command:  /quality-audit
class:    code-quality/response-cast-unchecked
detector: type-safety-scan §1 (code-quality)
anchor:   return (await res.json()) as Rates;
match:    as Rates|cast|runtime check|schema
```

Routed (B-A16): backend's class is the pipe, not this cast.

## BD-HO-CQ-c — `Math.round(parseFloat(amount) * 100)` — minor units hard-coded to 2 decimals (JPY 0, KWD 3)

```defect
id:       BD-HO-CQ-c
file:     apps/api/src/payments/psp-amount.ts
line:     4
severity: high
command:  /quality-audit
class:    code-quality/minor-units-hard-coded
detector: correctness-smell-scan §4 (code-quality)
anchor:   return Math.round(parseFloat(amount) * 100);
match:    \* ?100|minor units|JPY|KWD|exponent|parseFloat
```

Arithmetic in code, not a carrier or serializer setting → code-quality (research § 7.3 boundary). Routed.

## BD-HO-CQ-d — multer `diskStorage` keeps the uploaded file when the 422 branch rejects the request

```defect
id:       BD-HO-CQ-d
file:     apps/admin/src/routes/uploads.routes.ts
line:     27
severity: medium
command:  /quality-audit
class:    code-quality/temp-file-left-on-failure
detector: error-handling-scan §7 (code-quality)
anchor:   res.status(422).json({ error: { code: 'BAD_MERCHANT'
match:    unlink|diskStorage|422|temp|left
```

Paired state on an error path. Routed.

## BD-HO-DS-a — `axiosRetry(psp, { retries: 3 })` on the PSP client — the default condition retries a POST capture after a network error

```defect
id:       BD-HO-DS-a
file:     apps/api/src/payments/psp.client.ts
line:     6
severity: high
command:  /ds-audit
class:    distributed-systems/library-retries-post
detector: retry-deadline-scan §5 (distributed-systems)
anchor:   axiosRetry(psp, { retries: 3
match:    axios-retry|axiosRetry|POST|retries|idempoten
```

Routed (B-R13; RT-5).

## BD-HO-DS-b — `retryablehttp` POST to the per-message-billed SMS provider with `RetryMax = 4`

```defect
id:       BD-HO-DS-b
file:     services/edge-go/internal/upstream/notify.go
line:     22
severity: high
command:  /ds-audit
class:    distributed-systems/library-retries-post
detector: retry-deadline-scan §5 (distributed-systems)
anchor:   resp, err := notifyClient.Post(
match:    retryablehttp|RetryMax|POST|SMS|duplicate
```

Routed (RT-5).

## BD-HO-DS-c — `em.flush()` then `events.publish(...)` with nothing durable between — a crash loses `invoice.issued`

```defect
id:       BD-HO-DS-c
file:     apps/api/src/invoices/issue-invoice.use-case.ts
line:     20
severity: high
command:  /ds-audit
class:    distributed-systems/commit-then-publish
detector: dual-write-scan §1 (distributed-systems)
anchor:   await this.events.publish('invoice.issued'
match:    outbox|flush|publish|dual write|commit
```

Routed (DW-1).

## BD-HO-SEC-a — Per-line refund cap with no aggregation — `[{sku:"A",qty:2},{sku:"A",qty:2}]` refunds 4 of 2

```defect
id:       BD-HO-SEC-a
file:     apps/api/src/refunds/refund-lines.service.ts
line:     18
severity: high
command:  /security-audit
class:    security/repeated-key-cap
detector: logic-race-scan §2 (security)
anchor:   if (line.quantity > (qtyBySku.get(line.sku) ?? 0)) {
match:    repeated|duplicate sku|cap|sum|refund
```

Routed (P3).

## BD-HO-SEC-b — multer `memoryStorage()` with no `limits` — an unbounded file is buffered in memory

```defect
id:       BD-HO-SEC-b
file:     apps/admin/src/routes/imports.routes.ts
line:     7
severity: high
command:  /security-audit
class:    security/upload-no-size-cap
detector: file-access-scan §2 (security)
anchor:   const csvUpload = multer({ storage: multer.memoryStorage() });
match:    limits|fileSize|memoryStorage|size cap
```

Routed (BU-01).

## BD-HO-SEC-c — The 500 body carries `err.Error()` and `debug.Stack()`

```defect
id:       BD-HO-SEC-c
file:     services/edge-go/internal/http/orders.go
line:     24
severity: high
command:  /security-audit
class:    security/stack-in-error-body
detector: data-exposure-scan §1 (security)
anchor:   "stack": string(debug.Stack())
match:    stack|err\.Error|exposure|debug\.Stack
```

Error body content is security's (EE § Boundaries). Routed.

## BD-HO-PERF-a — `requests.post(...)` to the PSP with no `timeout` — a stalled PSP pins the Celery worker forever

```defect
id:       BD-HO-PERF-a
file:     services/billing-py/billing/psp.py
line:     6
severity: high
command:  /perf-audit
class:    performance/outbound-no-timeout
detector: request-path-scan §12 (performance)
anchor:   resp = requests.post(f"{settings.PSP_BASE_URL}/v2/charges"
match:    timeout|requests\.post|hang
```

Routed (outbound timeouts → performance §12).

## BD-HO-PERF-b — 25 MB videos fully buffered with `file.toBuffer()` to hash them

```defect
id:       BD-HO-PERF-b
file:     apps/api/src/media/media.controller.ts
line:     13
severity: medium
command:  /perf-audit
class:    performance/upload-fully-buffered
detector: request-path-scan §6 (performance)
anchor:   const buffer = await file.toBuffer();
match:    toBuffer|buffer|stream|memory
```

Routed (BU-04).

## BD-HO-PERF-c — Hourly digest `@Cron` runs on every replica (3) — each merchant gets three digests

```defect
id:       BD-HO-PERF-c
file:     apps/api/src/notifications/digest.scheduler.ts
line:     11
severity: medium
command:  /perf-audit
class:    performance/cron-every-replica
detector: request-path-scan §20 (performance)
anchor:   @Cron(CronExpression.EVERY_HOUR
match:    replica|once per fleet|every pod|lock|leader
```

One schedule, guarded against self-overlap (`waitForCompletion`) and UTC-pinned, so JL §4/§6 are clean; once-per-fleet is performance §20. Routed.

## BD-HO-OBS-a — The global filter answers 500 with no log and no error-tracker capture

```defect
id:       BD-HO-OBS-a
file:     apps/api/src/common/filters/global-exception.filter.ts
line:     63
severity: medium
command:  /obs-audit
class:    observability/5xx-without-capture
detector: error-tracking-scan §4 (observability)
anchor:   reply.status(500).send({ error: { code, message: 'Internal error' } });
match:    capture|log|500|Sentry|tracker
```

The mapping is right for EE; the telemetry gap is observability's (both rows stand). Routed.

## BD-HO-OBS-b — Refund failures are logged as `err.message` only — the stack and cause are lost

```defect
id:       BD-HO-OBS-b
file:     apps/api/src/payments/psp.client.ts
line:     21
severity: medium
command:  /obs-audit
class:    observability/stack-lost
detector: log-signal-scan §2 (observability)
anchor:   this.logger.error(`refund failed for ${captureId}: ${(err as Error).message}`);
match:    stack|message|err\b|logger\.error
```

Routed (LG-02).

## Decoys

```decoy
id:       BD-DECOY-01
file:     apps/api/src/oauth/oauth-register.controller.ts
line:     30
command:  /backend-audit
class:    decoy/BD-VB-1a
anchor:   async register(@Body() body: unknown)
match:    unknown|any-unknown|metatype|Object
```
```decoy
id:       BD-DECOY-02
file:     apps/api/src/transfers/transfers.controller.ts
line:     23
command:  /backend-audit
class:    decoy/BD-VB-1a
anchor:   @ZodBody(createTransferSchema) dto: CreateTransfer
match:    ZodBody|param decorator|pipe|bypass
```
```decoy
id:       BD-DECOY-03
file:     apps/api/src/integrations/dto/create-webhook-subscription.dto.ts
line:     13
command:  /backend-audit
class:    decoy/BD-VB-2a
anchor:   @IsObject()
match:    IsObject|ValidateNested|Type|metadata
```
```decoy
id:       BD-DECOY-04
file:     apps/api/src/common/page-query.dto.ts
line:     16
command:  /backend-audit
class:    decoy/BD-VB-3b
anchor:   @Max(100)
match:    @Type|Number|Boolean|Max|pageSize|coerc
```
```decoy
id:       BD-DECOY-05
file:     apps/admin/src/env.ts
line:     5
command:  /backend-audit
class:    decoy/BD-VB-4a
anchor:   PORT: z.coerce.number().int().positive().default(3001),
match:    coerce|PORT|env
```
```decoy
id:       BD-DECOY-06
file:     services/edge-go/internal/http/checkout.go
line:     11
command:  /backend-audit
class:    decoy/BD-VB-4d
anchor:   binding:"required,min=0,max=30"
match:    required|binding|\*int|zero
```
```decoy
id:       BD-DECOY-07
file:     apps/api/src/suppliers/dto/update-supplier.dto.ts
line:     8
command:  /backend-audit
class:    decoy/BD-VB-5a
anchor:   name?: string;
match:    IsOptional|null|IsAbsentOr
```
```decoy
id:       BD-DECOY-08
file:     services/edge-go/internal/http/webhooks.go
line:     19
command:  /backend-audit
class:    decoy/BD-VB-6b
anchor:   json.NewDecoder(c.Request.Body).Decode(&ev)
match:    DisallowUnknownFields|unknown|strict
```
```decoy
id:       BD-DECOY-09
file:     apps/api/src/regions/regions.controller.ts
line:     15
command:  /backend-audit
class:    decoy/BD-VB-7a
anchor:   @Query('region') region: string
match:    @Query\('region'\)|primitive|ParseEnumPipe
```
```decoy
id:       BD-DECOY-10
file:     apps/api/src/common/current-user.decorator.ts
line:     10
command:  /backend-audit
class:    decoy/BD-VB-8b
anchor:   export const CurrentUser = createParamDecorator(
match:    createParamDecorator|validateCustomDecorators|CurrentUser|pipe|validat
```
```decoy
id:       BD-DECOY-11
file:     apps/api/src/catalog/dto/bundle.dto.ts
line:     18
command:  /backend-audit
class:    decoy/BD-VB-9a
anchor:   @ValidateNested()
match:    each|ValidateNested|array
```
```decoy
id:       BD-DECOY-12
file:     apps/api/test/app-validation.pipe.spec.ts
line:     6
command:  /backend-audit
class:    decoy/BD-VB-6a
anchor:   const pipe = new ValidationPipe({ transform: true, whitelist: true });
match:    ValidationPipe|hand-built|test|whitelist|forbidNonWhitelisted
```
```decoy
id:       BD-DECOY-13
file:     apps/api/src/legacy/legacy-v1.filter.ts
line:     18
command:  /backend-audit
class:    decoy/BD-EE-3a
anchor:   reply.status(status).send({ error: message });
match:    \.status\(|Express|Fastify|adapter
```
```decoy
id:       BD-DECOY-14
file:     apps/api/src/files/files.plugin.ts
line:     26
command:  /backend-audit
class:    decoy/BD-EE-3a
anchor:   return reply.redirect(
match:    redirect|302|order|v4|Express|adapter|Fastify
```
```decoy
id:       BD-DECOY-15
file:     apps/api/src/webhooks/psp-webhook.controller.ts
line:     15
command:  /backend-audit
class:    decoy/BD-EE-5c
anchor:   @Res() reply: FastifyReply
match:    @Res|passthrough|hang
```
```decoy
id:       BD-DECOY-16
file:     apps/api/src/webhooks/psp-webhook.controller.ts
line:     20
command:  /backend-audit
class:    decoy/BD-EE-5c
anchor:   reply.status(200).send('ok');
match:    reply\.send|return|ALREADY_SENT
```
```decoy
id:       BD-DECOY-17
file:     apps/admin/src/routes/health.routes.ts
line:     8
command:  /backend-audit
class:    decoy/EE-§4-Express-4-async-crash
anchor:   router.get('/health/db', async (_req, res) => {
match:    async|crash|express-async-errors|unhandled
```
```decoy
id:       BD-DECOY-18
file:     apps/api/src/legacy/legacy-v1.filter.ts
line:     9
command:  /backend-audit
class:    decoy/BD-EE-7a
anchor:   @Catch()
match:    Catch|legacy|envelope|shape|wrapper|status|500
```
```decoy
id:       BD-DECOY-19
file:     services/billing-py/billing/views_refunds.py
line:     12
command:  /backend-audit
class:    decoy/BD-EE-6a
anchor:   except Refund.DoesNotExist:
match:    DoesNotExist|500|HTML|NotFound
```
```decoy
id:       BD-DECOY-20
file:     apps/admin/src/routes/geo-proxy.routes.ts
line:     14
command:  /backend-audit
class:    decoy/BD-EE-8a
anchor:   res.status(response.status)
match:    response\.status|pass|upstream
```
```decoy
id:       BD-DECOY-21
file:     services/edge-go/internal/http/checkout.go
line:     20
command:  /backend-audit
class:    decoy/BD-EE-6b
anchor:   c.JSON(http.StatusUnprocessableEntity
match:    422|400|ShouldBind|envelope
```
```decoy
id:       BD-DECOY-22
file:     apps/api/src/catalog/catalog-export.routes.ts
line:     20
command:  /backend-audit
class:    decoy/BD-EE-5b
anchor:   return reply.send(rows);
match:    reply\.send|return|raw Fastify
```
```decoy
id:       BD-DECOY-23
file:     apps/api/src/customers/customers.controller.ts
line:     17
command:  /backend-audit
class:    decoy/BD-HC-1a
anchor:   @Post('search')
match:    201|HttpCode|search
```
```decoy
id:       BD-DECOY-24
file:     apps/api/src/orders/order-actions.controller.ts
line:     28
command:  /backend-audit
class:    decoy/BD-HC-4a
anchor:   @Get('cancellations')
match:    cancel|GET|unsafe
```
```decoy
id:       BD-DECOY-25
file:     apps/api/src/receipts/receipts.controller.ts
line:     15
command:  /backend-audit
class:    decoy/BD-HC-4a
anchor:   await this.em.getConnection().execute('insert into receipt_views
match:    GET|write|insert|audit|unsafe
```
```decoy
id:       BD-DECOY-26
file:     apps/api/src/outbox/outbox-relay.ts
line:     35
command:  /backend-audit
class:    decoy/BD-HC-7a
anchor:   { orderBy: { createdAt: 'asc' }, limit: 200 }
match:    tiebreak|orderBy|createdAt|limit
```
```decoy
id:       BD-DECOY-27
file:     apps/api/src/common/pagination.ts
line:     35
command:  /backend-audit
class:    decoy/BD-HC-7a
anchor:   orderBy: [{ [sort]: dir }, { id: QueryOrder.ASC }] as never,
match:    kernel|tiebreak|clamp|pagination
```
```decoy
id:       BD-DECOY-28
file:     apps/api/src/products/products-bulk.controller.ts
line:     27
command:  /backend-audit
class:    decoy/BD-HC-8a
anchor:   @HttpCode(207)
match:    bulk|batch|207|allSettled
```
```decoy
id:       BD-DECOY-29
file:     services/edge-go/internal/http/legacy.go
line:     11
command:  /backend-audit
class:    decoy/BD-HC-9a
anchor:   c.Header("Deprecation", "@1767225600")
match:    Deprecation|Sunset
```
```decoy
id:       BD-DECOY-30
file:     .github/workflows/api.yml
line:     49
command:  /backend-audit
class:    decoy/BD-HC-10a
anchor:   run: oasdiff changelog openapi/openapi.yaml
match:    fail-on|changelog|oasdiff
```
```decoy
id:       BD-DECOY-31
file:     apps/admin/src/routes/files.routes.ts
line:     14
command:  /backend-audit
class:    decoy/BD-HC-11a
anchor:   router.get('/files/*splat'
match:    \*splat|wildcard|path-to-regexp|boot
```
```decoy
id:       BD-DECOY-32
file:     apps/api/src/graphql/request-loaders.ts
line:     8
command:  /backend-audit
class:    decoy/BD-HC-11d
anchor:   category: new DataLoader
match:    DataLoader|module scope|per request
```
```decoy
id:       BD-DECOY-33
file:     apps/api/src/common/http-client.ts
line:     20
command:  /backend-audit
class:    decoy/BD-HC-12b
anchor:   redirect: 'manual',
match:    redirect|POST
```
```decoy
id:       BD-DECOY-34
file:     apps/api/src/documents/contracts.controller.ts
line:     19
command:  /backend-audit
class:    decoy/BD-HC-13b
anchor:   if (!fields.contractId) throw new BadRequestException('contractId must precede the file');
match:    field order|parts|multipart
```
```decoy
id:       BD-DECOY-35
file:     apps/api/src/products/products.controller.ts
line:     15
command:  /backend-audit
class:    decoy/BD-HC-1d
anchor:   reply.status(201).header('Location', `/v1/products/${id}`);
match:    Location|201
```
```decoy
id:       BD-DECOY-36
file:     apps/api/src/common/page-query.dto.ts
line:     10
command:  /backend-audit
class:    decoy/BD-HC-5b
anchor:   page: number = 1;
match:    initiali[sz]er|default|PATCH
```
```decoy
id:       BD-DECOY-37
file:     apps/admin/src/routes/files.routes.ts
line:     8
command:  /backend-audit
class:    decoy/BD-HC-3a
anchor:   express.raw({ type: 'application/pdf', limit: '5mb' })
match:    type|415|content type
```
```decoy
id:       BD-DECOY-38
file:     apps/api/src/ledger/journal-sequence.entity.ts
line:     14
command:  /backend-audit
class:    decoy/BD-WF-2a
anchor:   lastValue!: number;
match:    bigint|number|2\^53
```
```decoy
id:       BD-DECOY-39
file:     apps/api/src/shipments/parcel.mapper.ts
line:     9
command:  /backend-audit
class:    decoy/BD-WF-1b
anchor:   weightKg: Number(parcel.weightKg)
match:    Number\(|float|decimal
```
```decoy
id:       BD-DECOY-40
file:     apps/api/src/activity/activity-feed.controller.ts
line:     23
command:  /backend-audit
class:    decoy/BD-WF-6a
anchor:   @IsISO8601({ strict: true })
match:    ISO8601|Date|coerc
```
```decoy
id:       BD-DECOY-41
file:     apps/api/src/payouts/payout.producer.ts
line:     17
command:  /backend-audit
class:    decoy/BD-WF-5a
anchor:   await this.payoutsQueue.add('payout', { merchantId: payout.merchantId, amountMinor: payout.amountMinor, currency: payout.currency });
match:    float|payload|amount
```
```decoy
id:       BD-DECOY-42
file:     apps/api/src/catalog/catalog-export.routes.ts
line:     13
command:  /backend-audit
class:    decoy/BD-WF-3a
anchor:   properties: { sku: { type: 'string' }, title: { type: 'string' }, price: { type: 'string' }, currency: { type: 'string' } },
match:    response schema|dropped|costPrice|supplierId
```
```decoy
id:       BD-DECOY-43
file:     apps/api/src/stores/store-hours.entity.ts
line:     16
command:  /backend-audit
class:    decoy/BD-WF-7a
anchor:   opensAt!: string;
match:    time|zone|offset|naive
```
```decoy
id:       BD-DECOY-44
file:     services/billing-py/billing/tax.py
line:     25
command:  /backend-audit
class:    decoy/BD-WF-4b
anchor:   return total.quantize(CENT, rounding=ROUND_HALF_UP)
match:    quantize|rounding
```
```decoy
id:       BD-DECOY-45
file:     apps/api/src/catalog/catalog-cache.warmer.ts
line:     12
command:  /backend-audit
class:    decoy/BD-JL-4a
anchor:   @Cron(CronExpression.EVERY_MINUTE
match:    overlap|waitForCompletion|guard
```
```decoy
id:       BD-DECOY-46
file:     services/billing-py/billing/fx_scheduler.py
line:     8
command:  /backend-audit
class:    decoy/BD-JL-4b
anchor:   scheduler.add_job(
match:    max_instances|overlap|misfire
```
```decoy
id:       BD-DECOY-47
file:     apps/api/src/catalog/product-sync.processor.ts
line:     18
command:  /backend-audit
class:    decoy/BD-JL-2a
anchor:   if (!product) {
match:    deleted|findOne|discard
```
```decoy
id:       BD-DECOY-48
file:     apps/api/src/catalog/nightly-reindex.scheduler.ts
line:     12
command:  /backend-audit
class:    decoy/BD-JL-6a
anchor:   @Cron('0 0 * * *'
match:    timeZone|DST|zone
```
```decoy
id:       BD-DECOY-49
file:     apps/api/src/exports/export-job.processor.ts
line:     17
command:  /backend-audit
class:    decoy/BD-JL-7a
anchor:   @OnWorkerEvent('failed')
match:    failed|listener|record
```
```decoy
id:       BD-DECOY-50
file:     services/billing-py/billing/subscriptions.py
line:     23
command:  /backend-audit
class:    decoy/BD-ST-1a
anchor:   model_attribute="state", ignore_invalid_triggers=True)
match:    ignore_invalid_triggers|illegal|409
```
```decoy
id:       BD-DECOY-51
file:     apps/api/src/shipments/shipments.service.ts
line:     17
command:  /backend-audit
class:    decoy/BD-ST-1b
anchor:   actor.send({ type: 'DISPATCH' });
match:    send|can\(|illegal
```
```decoy
id:       BD-DECOY-52
file:     apps/api/src/exports/export-job.processor.ts
line:     20
command:  /backend-audit
class:    decoy/BD-ST-2b
anchor:   row.status = 'failed';
match:    status|machine|terminal
```
```decoy
id:       BD-DECOY-53
file:     apps/api/src/outbox/outbox-relay.ts
line:     32
command:  /backend-audit
class:    decoy/BD-JL-4a
anchor:   if (this.running) return;
match:    overlap|Interval|guard
```
```decoy
id:       BD-DECOY-54
file:     apps/api/src/orders/get-order.use-case.ts
line:     19
command:  /backend-audit
class:    decoy/BD-HC-7a
anchor:   { orderBy: { createdAt: 'desc', id: 'asc' }, limit: 100 }
match:    tiebreak|orderBy|limit
```
```decoy
id:       BD-DECOY-55
file:     apps/api/src/products/update-product.use-case.ts
line:     13
command:  /backend-audit
class:    decoy/BD-EE-2a
anchor:   if (!product) throw new NotFoundError('Product', id);
match:    NotFoundError|404|unmapped
```

## Detector measurement (2026-10-14)

**How it was run.** The fixture was staged by hand exactly as `run.sh` stages it (`tar --exclude=DEFECTS.md`, then
`git init` + one commit, the `--git` flag), into a scratch directory outside the repo; `dto-types.py` was installed at
`.claude/skills/validation-boundary-scan/scripts/` in the copy (where a standard install puts it). The `/backend-audit`
wiring map (Phase 3, `commands/backend-audit.md`) and each detector's `## Pre-flight greps` block were extracted
byte-for-byte from the repo and run with bash 3.2; the only edit is the documented one — each detector's `ROOTS=(.)`
line replaced by the array the wiring map printed: `ROOTS=(./apps/admin/src ./apps/api/src ./services/billing-py
./services/edge-go)` (it also listed `apps/api/test` as "not a root"). `SCAN`, `DT` and `VB` came from the wiring map's
last line; `job-lifecycle-scan` ran with `BASE` empty (a whole-repo run). Tools: `rg`, `python3`, `awk`, `git`; the
wiring map's F6 line calls `docker version` (local daemon only). No package was installed, nothing was built or booted,
no network call was made; `git status` on the copy after all seven runs showed only the `.claude/` install.

**Wall time and errors** (re-run the same way after backend 2.0.1 closed IR-1 to IR-12; the first run's line counts
follow in brackets). Wiring map 0.7 s, 130 lines [130]; `validation-boundary-scan` 0.36 s / 90 [91];
`edge-error-scan` 0.76 s / 81 [82]; `http-contract-scan` 0.70 s / 113 [118]; `wire-format-scan` 0.20 s / 53 [49];
`job-lifecycle-scan` 0.59 s / 51 [52]; `state-transition-scan` 0.19 s / 25 [25]. Every block exited 0 with **empty stderr** (no
`rg` exit 2). `dto-types.py --self-test`: 75/75. On the copy it read 167 files, parsed 57 of 58 raw param hits (the 58th
is a GraphQL method-level `@Query(() => T)`), 0 `UNPARSED`, 100 % resolved, `strictNullChecks` on for all 57 (from
`apps/api/tsconfig.json` `strict: true`), and bucketed `@ZodBody` as `custom-pipe(ZodValidationPipe)` — not a VB1 row.

**The wiring map** printed what every detector needs first: F1 the four roots, every manifest range and the locked
versions from `pnpm-lock.yaml` (Nest 11.1.6, Fastify 5.4.0, class-validator 0.15.1, `@nestjs/schedule` 6.1.3, cron
4.4.0, Express 5.1.0, zod 4.1.5, xstate 5.20.1); F2 the `APP_PIPE` subclass, the controller-scoped
`enableImplicitConversion` pipe (BD-VB-3a), the `ZodBody` decorator and its pipe, all four mappers (admin error
middleware, the global `@Catch()`, the files-scope `setErrorHandler`, the legacy `@Catch()`), the adapter, the
un-inherited `connectMicroservice` (BD-VB-8a), `COERCE_DECIMAL_TO_STRING` / `TIME_ZONE` / `USE_TZ` (BD-WF-1a, BD-WF-7a),
`excludeExtraneousValues` (BD-WF-3b), MikroORM config with no `findOneOrFailHandler`, the pagination kernel, both
outbound clients and the idempotency interceptor (3 route uses); F3 49 handlers, "POST with no @HttpCode 3",
"@Res() without passthrough 2", **`@ZodBody (pipe)` — "read the pipe once"** (the BD-DECOY-02 cue) and `@CurrentUser
(principal)`; F4 both specs, the generator, the npm `oasdiff` script (BD-HC-10c) and — because F4 greps with
`--hidden` — the CI `oasdiff breaking` step without `--fail-on` (BD-HC-10a); F5 11 processors, 11 producers, 10
schedules, 5 machines; F6 one e2e file that builds the real app, two that hand-build a pipe or adapter (BD-DECOY-12 is
one).

### Seeds printed per detector §

"Line" = a pre-flight line names the seed's file within ±6 lines of its anchor; "file" = a file-level list names the
file (the § lists files with no line by design); "count" = the § prints a count or a class name, not a path; "missed" =
nothing in the block points at it.

| detector | seeds | line | file | count / name | missed |
|---|---|---|---|---|---|
| `validation-boundary-scan` | 21 | 20 | 1 (VB-6b: 6c lists the Go file) | — | 0 |
| `edge-error-scan` | 17 | 14 | 1 (EE-2a: the ORM-name row names the filter file) | 2 (EE-2b: `EE2c family named by NO mapper: LedgerError (4 classes)`; EE-6a: `6 drf: EXCEPTION_HANDLER=0`) | 0 |
| `http-contract-scan` | 38 | 34 | 4 (HC-1d, HC-1e from HC1d; HC-12a, HC-12b from HC12a/HC12c) | — | 0 (first run: 2, HC-10a and HC-11d — IR-1, IR-2) |
| `wire-format-scan` | 14 | 13 | 1 (WF-2b: 2c lists the Go file) | — | 0 (first run: 1, WF-3a — IR-3) |
| `job-lifecycle-scan` | 14 | 12 | 1 (JL-7a: `7a no failed listener`) | 1 (JL-7b: `7c ignore_result=True: 1 · result reads: 1`) | 0 (first run: 2, JL-3a and JL-3b at `3 N/A (diff-only)` — IR-4; now the 3w lane) |
| `state-transition-scan` | 5 | 5 | — | — | 0 |
| **total** | **109** | **98** | **8** | **3** | **0** (first run: 5) |

**All 109 seeds are printed by their own detector's pre-flight** (backend 2.0.1). The first run missed 5 by grep shape
(IR-1 to IR-4); each now prints at its own line. Notes
on the printed ones that still need the read the skill prescribes: BD-VB-6a prints as the `class AppValidationPipe
extends ValidationPipe` line (the options sit two lines down in `super(...)`); BD-EE-4b is the `4d go routers: 1 ·
recover layers: 0` count (the ServeMux shares `main.go` with BD-EE-4a); BD-HC-6a/6b print as the module's in-flight lines
and, since IR-10, as `HC6-no-principal` and `HC6-no-fingerprint` on the interceptor that reads the header; BD-HC-9b prints as the two `reply.header` lines that use the constants;
BD-JL-5b's 5a row also names `payout-cutoff.scheduler.ts` (BD-JL-6a's site: one entry, two classes).

**Routed rows.** The backend blocks print the routed counts their skills promise — `job-lifecycle-scan` R lines (`→
database transaction-scan §1: 1 files` = BD-HO-DB-a; `→ performance request-path-scan §20: 9 unguarded schedule
files`), EE §6's Django row (IntegrityError/ObjectDoesNotExist named by no mapper). The owners' own pre-flights were
**not run** in this measurement; the 17 `BD-HO-*` rows are scored only in their owners' runs.

### Decoys

19 decoys are printed by some backend block or the wiring map (after backend 2.0.1), each by design, and each cleared by the read its skill
prescribes: BD-DECOY-01 (VB1, B-D1), -05 (grep 4a, B-A13), -08 (6c, tolerant reader), -09 (VB7, B-D10), -10 (grep 8,
principal), -18 (EE 1a and F2, B-D6 — and since the legacy filter reads `statusCode`, not in 1c), -20 (EE8, documented
proxy), -21 (VB grep 0 `ShouldBindJSON`), -26 (HC7a, B-D4), -28 (HC8/HC8b, 207), -29 (HC9, RFC 9745), -30 (wiring F4 and
HC10-ci, both tagging the `changelog` step informational), -33 (HC12c-setting, P5), -34 (HC13b, field-first enforced), -38 (WF 2a, B-D5), -42 (WF 3a, B-A12 — the
`-U` of IR-3 makes 3a list every schema), -45 (JL 4a, B-R8), -50 (ST 1a, B-R5), -52 (ST 2c, no machine). BD-DECOY-02 (`@ZodBody`) is **not** a VB1 row:
`dto-types.py` buckets it `custom-pipe(ZodValidationPipe)` and only the wiring map's F3 line names it, with the
instruction to read the pipe. BD-DECOY-46 printed in JL 5b/7g in the first run and prints in no block since IR-6. The other 36 decoys print in no block; they measure false positives an agent adds by
reading, not by grep.

**Unseeded rows the blocks print (precision noise, each closed by one read):** `HC4b-django(method unknown: read the
view)` — the Django `path(".../approve/")` route, which is `@require_POST` (IR-12 took the tag, not the drop); HC10-ci's
two `Install oasdiff` step names and two `curl` lines (untagged); HC11d-nofp `files.plugin.ts` (an encapsulated error
handler, intended); VB5 lists 10
`optional-admits-null` props on Update DTOs — 2 are seeds (BD-VB-5a/5b), the rest reach a mapped NOT NULL arm (400), a
nullable column or a JSON merge; HC7a the cache warmer's internal `order by rank limit 50`; ST 2c `tasks.py`
`invoice.status = "sent"` (no machine on `Invoice`). Gone since backend 2.0.1: HC11g's 16 admin-app `express`
imports (IR-5), VB 6c `upstream/catalog.go` (IR-7), JL 5b/7g `fx_scheduler.py` and `scheduler.py` (IR-6), EE2c
`IllegalTransition` (IR-11), the F4-ci tags on step names, `curl` and `changelog` lines (IR-8), and F3's doc-comment
`@ZodBody` use (IR-9: `1 uses`). Two unseeded true rows found by the first run were removed from the
tree rather than left unscored: `UpstreamError` is now mapped to 502 by the global filter, and the PSP calls in
`billing/psp.py` pass `allow_redirects=False`; the files plugin's direct upload now sets `Location`.

`bash benchmarks/run.sh --verify --fixture=backend-defects`: **181/181 anchors resolve (55 of them decoys)**, and no
decoy sits within 12 lines of a seed in its file.

Self-check of the key: a findings file built from each seed's own title and text scores **109/109** under
`/backend-audit` (3/3 `/security-audit`, 2/2 `/db-audit`, 3/3 `/perf-audit`, 4/4 `/quality-audit`, 2/2 `/obs-audit`,
3/3 `/ds-audit`) with 0 decoys pinned; a file of one typical false report per decoy (the looked-like seed's wording at
the decoy's line) pins **55/55** and credits 0 seeds.

### Integrator requests (skill gaps this fixture found)

Not edited here (the fixture owns no skill file); each names the grep and the seed that shows it. **All twelve were closed
in backend 2.0.1 (2026-10-14)**, and the measurement above is the re-run after the fixes. IR-10's absence rows run
over the idempotency files that read the request header; IR-12 kept the Django row as `HC4b-django`, tagged.

- **IR-1 — `http-contract-scan` HC10-ci never reads `.github/`.** The `rg` has no `--hidden`, so
  `.github/workflows/*.yml` is skipped and the CI `oasdiff breaking` step without `--fail-on` is invisible (BD-HC-10a
  missed; `/backend-audit` F4, which passes `--hidden`, does print it). Add `--hidden` (and `-g '!**/.git/**'`).
- **IR-2 — `http-contract-scan` HC11e misses `new DataLoader<K, V>(`.** The module-scope pattern requires `\(` right
  after `DataLoader`; TypeScript type arguments break it (BD-HC-11d missed). Allow `(?:<[^\n]*?>)?\s*\(`.
- **IR-3 — `wire-format-scan` grep 3a is single-line.** `response\s*:\s*\{\s*['"]?(?:[1-5]\d\d|…)` never matches the
  prettier layout where `200:` is on the next line (BD-WF-3a missed; the catalog feed schema, BD-DECOY-42, is unseen
  too). Run it with `-U` so `\s*` spans the newline.
- **IR-4 — `job-lifecycle-scan` §3 is diff-only.** A whole-repo run prints `N/A`, yet two drift shapes are static: a
  processor reading `job.data.<f>` that no producer of the same queue sets (BD-JL-3a: `currency`, delayed 6 h), and a
  Celery task whose required positional arguments outnumber what its `.delay(`/`apply_async(args=[…])` callers pass
  (BD-JL-3b). Propose a whole-repo 3w lane (producer key set vs consumer reads, joined on the queue name or task name),
  printed as candidates, with the cross-commit replay (V351) as the settling oracle.
- **IR-5 — `http-contract-scan` HC11g is gated repo-wide.** `rg -l FastifyAdapter … >/dev/null &&` over all `ROOTS`
  turns the Express-import grep on for every root, so a monorepo's separate Express app prints every import (16 rows
  here). Run the gate and the import grep per root.
- **IR-6 — `job-lifecycle-scan` 5b/7g match the must-run words against the full path.** Every file under
  `services/billing-py/billing/` is "must-run" because of `bill` in a directory name (BD-DECOY-46 printed in 5b and 7g).
  Match the basename or the handler name.
- **IR-7 — `validation-boundary-scan` 6c lists outbound decoders.** `json.NewDecoder` with no `DisallowUnknownFields`
  includes `resp.Body` decoders of provider responses (`upstream/catalog.go`). Scope to request bodies (`r.Body`,
  `c.Request.Body`, `req.Body`).
- **IR-8 — `/backend-audit` F4-ci tags every `oasdiff` line.** The awk marks the step name, the `curl` download and the
  informational `oasdiff changelog` step (BD-DECOY-30) "NOT-RUN, never a gate". Tag only `oasdiff (breaking|diff)`
  lines, as HC10-ci's awk does.
- **IR-9 — `/backend-audit` F3 counts a JSDoc mention as a decorator use** (`@ZodBody (pipe): 2 uses` for one use; the
  second is the decorator's own doc comment). Apply `NC` to the use count.
- **IR-10 — `http-contract-scan` HC6 cannot print an absence.** The composition grep lists principal/fingerprint/in-flight
  terms that exist; a store key with no principal (BD-HC-6a) and a replay with no fingerprint (BD-HC-6b) print nothing.
  Add `--files-without-match` lines over the W0-idem files: "no principal/tenant term", "no fingerprint/hash term".
- **IR-11 — `edge-error-scan` 2c reports DRF `APIException` subclasses** as a family no mapper names; DRF's default
  handler maps them. Seed the mapped set with `APIException` when `rest_framework` is present.
- **IR-12 — `http-contract-scan` HC4b matches Django `path()` routes** whose segment is an unsafe word regardless of
  method (`path("refunds/<int:pk>/approve/", approve_refund)` is `@require_POST`). Drop `\bpath\s*\(` from HC4b or tag
  it `method unknown: read the view`.
