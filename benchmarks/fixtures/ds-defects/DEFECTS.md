# Seeded defects — `ds-defects`

**This file is the answer key.** `benchmarks/run.sh` never copies it into the workdir the
agent scans. If you stage the fixture by hand, delete this file from the copy first — an
agent that reads it will score 100% and the number will mean nothing.

Fixture shape: `Acme Fulfilment` — order intake, warehouse picking, carrier booking, cash-on-delivery settlement and
notifications, in six stacks plus a deploy tree: a NestJS 11 / Fastify API and a worker on MikroORM 6.6, `@nestjs/bullmq`
+ BullMQ 6, kafkajs 2.2.4, amqplib, sqs-consumer 14, ioredis, redlock and KurrentDB; Temporal TypeScript workflows; a
Django 6 + Celery 5.6 billing service on Redis with tenacity; a Spring Boot 3.5 ledger (Spring Kafka 4.1, Kafka Streams
4.1, Resilience4j, Redisson, ShedLock, Temporal Java, Eventuate sagas); a Go 1.25 dispatcher (kafka-go, Temporal Go,
client-go leader election, go-retryablehttp, redsync, NATS JetStream); and a .NET 9 notification service (MassTransit 8
with the EF outbox, `Microsoft.Extensions.Http.Resilience`, Polly, Marten, a Durable Functions orchestrator). Messaging,
dual write and outbox, retries and deadlines, locks, leaders and clocks, workflows and sagas, event contracts and event
sourcing — seeded across every root — plus 16 hand-offs to the database, security, performance, infrastructure,
observability and backend audits, and 46 decoys: correct siblings that look like a seeded defect and must NOT be
reported.

Invocation: /ds-audit --whole-repo --contract-base=.refract-fixture/contract-base
Invocation[/db-audit]: /db-audit
Invocation[/security-audit]: /security-audit
Invocation[/perf-audit]: /perf-audit
Invocation[/infra-audit]: /infra-audit --whole-repo
Invocation[/obs-audit]: /obs-audit --whole-repo
Invocation[/backend-audit]: /backend-audit --whole-repo
Stage with: --git — the audits read the history for their context map, and a whole-repo run on a copy with no base
branch says so with the flag instead of leaving the diff lookup to fail.

Eval source: Track A batch 5, items 28–29 (`eval-batch5-distributed-systems.md` § 3.7). Classes follow the owning skills'
own § numbering (`templates/packs/distributed-systems/skills/*/SKILL.md`, each with its `stacks.md`; the routed rows name
their owner's skill and §). Roots: `apps/api` (producers, the outbox port `OutboxService implements OutboxPort` behind
`TxRunner`, the outbox relay, crons with Redis leader keys, the shared outbound client, the KurrentDB order store, the
hand-rolled sagas), `apps/worker` (BullMQ processors on a `BaseProcessor` that owns `process()` and an aborting
`withDeadline`, kafkajs and amqplib consumers, a Redis Streams reader, catch-up cursors, projections, the scheduler role),
`apps/workflows-ts` (Temporal TS workers and one recorded history), `apps/web` (React Router 7 actions),
`packages/event-log` (a Prisma event table), `services/billing-py`, `services/ledger-jvm`, `services/dispatch-go`,
`services/notify-dotnet`, `schemas/` (protobuf with `buf.yaml`, Avro, AsyncAPI 3, JSON Schema 2020-12) and `deploy/`
(RabbitMQ 4.3 `definitions.json`, the production Kafka hosts' compose file, NATS server and stream config, `redis.conf`,
three Debezium connectors, Terraform SQS for a long-lived poller and a Lambda event source, Kubernetes manifests with an
HPA, a KEDA `ScaledObject`, a single-replica scheduler, a migrate Job and two CronJobs, PgBouncer, the k3s cluster's
host time zone, a capacity sheet).

**The contract and workflow base is offline.** `.refract-fixture/contract-base/` mirrors repo-relative paths: the base
copies of the four schema documents, of the two producers whose meaning changed (`invoice-events.ts`,
`route-events.producer.ts`) and of the two workflows changed without a version gate (`fulfilment.workflow.ts`,
`SettlementWorkflowImpl.java`). `/ds-audit --contract-base=` hands it to `event-contract-scan` and `workflow-scan` as `CONTRACT_BASE`; the
staged `--git` copy has a single commit, so a merge-base lookup would print `BASE NOT-RUN`, and `workflow-scan` §2a
compares each workflow file with its base copy instead (distributed-systems 2.0.1, IR-5).

Departures from the eval, stated so a reader can audit them:
- **46 decoys, not 44.** The eval's decoy column holds 44 entries (it says 42), plus its two additions (the graphile-worker
  job in the same transaction, the single-replica scheduler); every one is here.
- **Owner invocations follow the commands on disk.** `/db-audit` and `/perf-audit` take no `--whole-repo` flag (their
  signatures are `[base-branch]`); with no diff they scan the whole repo. `/backend-audit --whole-repo` scores the two
  `job-lifecycle-scan` rows the task added (§4 self-overlap, §6 one schedule's own zone).
- **16 routed rows**: database 4 (`transaction-scan` §1 ×2, §5, §8), security 3 (`logic-race-scan` §5 clamped debit, §4 ×2),
  performance 4 (`request-path-scan` §20 ×2, §18, §23), infrastructure 2 (`serverless-reliability-scan` §2, §4),
  observability 1 (`trace-propagation-scan` §2), backend 2 (`job-lifecycle-scan` §4, §6).
- **Money stays with security.** Seeds whose effect is money (the COD balance consumer DS-CO-04a, the `@Saga()` refund
  DS-WF-06a, the ledger posting listener DS-MQ-01c) are scored under `/ds-audit` for their distributed class and name
  `logic-race-scan` as corroboration; the three money rows the eval routed are `DS-HO-SEC-*`.
- **DS-MQ-04b** uses kafka-go's `CRC32Balancer` (the librdkafka-compatible partitioner) with no key, beside the Java
  murmur2 producer on `shipment.status`; the eval named librdkafka.
- **DS-EC-01b**: `asyncapi diff -t breaking` exits 0 on a required payload field; the evidence is the unclassified-change
  count and a `json-schema-diff` of the extracted payload. The head document keeps `info.version: 2.2.0`, because the CLI
  classifies an `info.version` edit itself as breaking (measured below) and a bump would hide the payload change behind it.
- **DS-RT-08a is medium**: the customs broker deduplicates on `reference`, so the overrun orphans the work but a re-run
  does not duplicate it.
- **Coordination §8 seed b** is a UUIDv7 window bound computed on the consumer host (`uuidv7At(Date.now() - lag)`) against
  ids minted on three services' clocks; dual-write §6 keeps the floor-with-no-lag seed (DS-DW-06b).
- **The outbox port has 4 call sites, not 28**, all split as `outbox port` by `dual-write-scan` F2; the decoy
  (DS-DECOY-11, `create-shipment`) is one of them.

Ownership and scoring. Seven runs, seven results rows, each staged in its own copy. **`/ds-audit`** (the `Invocation:`
line) scores the 111 distributed rows: a whole-repo run dispatches all six detectors plus `ds-inventory.py`. The 16
`DS-HO-*` rows are scored **only under their owner** — `/db-audit` (4), `/security-audit` (3), `/perf-audit` (4),
`/infra-audit` (2), `/obs-audit` (1), `/backend-audit` (2) — and `/ds-audit` must list each as a routed row, never grade
it; a `/ds-audit` finding on them is UNMATCHED, not credited. DS-DECOY-46 probes `/perf-audit`; the other 45 probe
`/ds-audit`.

Secrets. None. Credentials are `${file:…}` references, `secretRef`s or `canary-placeholder` values. Broker hosts are
fixture names (`*.fulfilment.svc`, `kafka-1`); the managed Valkey host is a fixture name on the provider's domain, there
to make its settings `UNREAD`.

Line numbers are exact against the files in this directory and are re-checked by
`benchmarks/run.sh --verify`, which also fails if a decoy sits close enough to a defect in the
same file for their scoring windows to overlap (every decoy here is at least 15 lines from any seed in its file). If you
edit fixture source, re-run it.

## Summary

| id | file:line | severity | command | class |
|----|-----------|----------|---------|-------|
| DS-MQ-01a | `apps/worker/src/jobs/receipts.processor.ts:22` | critical | `/ds-audit` | messaging/ack-before-effect |
| DS-MQ-01b | `services/billing-py/billing/tasks.py:10` | critical | `/ds-audit` | messaging/ack-before-effect |
| DS-MQ-01c | `services/ledger-jvm/src/main/java/com/acme/ledger/kafka/PostingListener.java:21` | high | `/ds-audit` | messaging/ack-before-effect |
| DS-MQ-02a | `apps/worker/src/jobs/labels.processor.ts:28` | high | `/ds-audit` | messaging/unstable-reserve-id |
| DS-MQ-02b | `apps/api/src/carriers/carrier-events.poller.ts:24` | high | `/ds-audit` | messaging/never-acked-redelivery |
| DS-MQ-02c | `apps/api/src/invoices/invoice-mailer.producer.ts:14` | high | `/ds-audit` | messaging/dedupe-ends-at-removal |
| DS-MQ-03a | `apps/worker/src/consumers/returns.consumer.ts:31` | high | `/ds-audit` | messaging/poison-requeue-loop |
| DS-MQ-03b | `services/ledger-jvm/src/main/java/com/acme/ledger/kafka/KafkaConfig.java:19` | high | `/ds-audit` | messaging/poison-skipped |
| DS-MQ-03c | `apps/worker/src/jobs/catalog-sync.processor.ts:25` | high | `/ds-audit` | messaging/swallow-and-ack |
| DS-MQ-04a | `apps/worker/src/consumers/order-status.consumer.ts:25` | high | `/ds-audit` | messaging/ordering-broken |
| DS-MQ-04b | `services/dispatch-go/internal/dispatch/statusproducer.go:37` | high | `/ds-audit` | messaging/ordering-broken |
| DS-MQ-05a | `apps/worker/src/consumers/inventory-snapshots.consumer.ts:23` | medium | `/ds-audit` | messaging/rebalance |
| DS-MQ-05b | `services/ledger-jvm/src/main/resources/application.yml:10` | medium | `/ds-audit` | messaging/rebalance |
| DS-MQ-06a | `apps/worker/src/jobs/invoice-pdf.processor.ts:29` | high | `/ds-audit` | messaging/lock-shorter-than-run |
| DS-MQ-06b | `services/billing-py/billing/dunning.py:9` | high | `/ds-audit` | messaging/visibility-shorter-than-eta |
| DS-MQ-07a | `apps/api/src/orders/orders.controller.ts:19` | high | `/ds-audit` | messaging/producer-fire-and-forget |
| DS-MQ-07b | `services/ledger-jvm/src/main/resources/application.yml:19` | medium | `/ds-audit` | messaging/producer-idempotence-off |
| DS-MQ-07c | `apps/api/src/queue/base.producer.ts:28` | medium | `/ds-audit` | messaging/enqueue-raced-timer |
| DS-MQ-08a | `deploy/redis.conf:7` | high | `/ds-audit` | messaging/eviction-drops-jobs |
| DS-MQ-08b | `deploy/rabbitmq/definitions.json:23` | high | `/ds-audit` | messaging/ttl-drops-unprocessed |
| DS-MQ-09a | `apps/worker/src/consumers/label-print.consumer.ts:18` | medium | `/ds-audit` | messaging/unbounded-prefetch |
| DS-MQ-09b | `apps/worker/src/streams/tracking-stream.reader.ts:27` | medium | `/ds-audit` | messaging/unbounded-prefetch |
| DS-MQ-10a | `deploy/nats/nats-server.conf:7` | high | `/ds-audit` | messaging/broker-durability |
| DS-MQ-10b | `deploy/kafka/compose.kafka.yaml:18` | high | `/ds-audit` | messaging/broker-durability |
| DS-MQ-11a | `apps/api/src/reports/report-schedule.ts:11` | medium | `/ds-audit` | messaging/version-trap |
| DS-MQ-11b | `services/ledger-jvm/src/main/resources/application.yml:29` | high | `/ds-audit` | messaging/version-trap |
| DS-DW-01a | `apps/api/src/orders/place-order.usecase.ts:24` | critical | `/ds-audit` | dualwrite/commit-then-publish |
| DS-DW-01b | `services/notify-dotnet/src/Notify.Api/Controllers/PreferencesController.cs:20` | high | `/ds-audit` | dualwrite/commit-then-publish |
| DS-DW-01c | `services/billing-py/billing/tasks.py:34` | high | `/ds-audit` | dualwrite/after-commit-loss-window |
| DS-DW-02a | `apps/api/src/orders/cancel-order.usecase.ts:18` | high | `/ds-audit` | dualwrite/publish-then-commit |
| DS-DW-02b | `services/dispatch-go/internal/dispatch/assign.go:28` | high | `/ds-audit` | dualwrite/publish-then-commit |
| DS-DW-03a | `apps/api/src/outbox/outbox.relay.ts:32` | high | `/ds-audit` | dualwrite/relay-unordered |
| DS-DW-03b | `apps/api/src/outbox/outbox.relay.ts:43` | high | `/ds-audit` | dualwrite/relay-parallel |
| DS-DW-04a | `apps/worker/src/consumers/fulfilment-tasks.consumer.ts:29` | medium | `/ds-audit` | dualwrite/inbox-two-stores |
| DS-DW-04b | `apps/worker/src/consumers/invoice-mirror.consumer.ts:25` | medium | `/ds-audit` | dualwrite/inbox-read-then-write |
| DS-DW-05a | `deploy/debezium/billing-outbox-connector.json:18` | high | `/ds-audit` | dualwrite/cdc-update-dropped |
| DS-DW-05b | `apps/worker/src/consumers/billing-cdc.consumer.ts:23` | high | `/ds-audit` | dualwrite/cdc-tombstone |
| DS-DW-06a | `apps/worker/src/sync/warehouse-sync.ts:23` | high | `/ds-audit` | dualwrite/gap-blind-cursor |
| DS-DW-06b | `apps/worker/src/sync/order-feed.cursor.ts:23` | high | `/ds-audit` | dualwrite/gap-blind-cursor |
| DS-RT-01a | `services/billing-py/billing/clients/tax_client.py:14` | medium | `/ds-audit` | retries/non-retryable-retried |
| DS-RT-01b | `services/ledger-jvm/src/main/java/com/acme/ledger/clients/RatesClient.java:15` | medium | `/ds-audit` | retries/non-retryable-retried |
| DS-RT-02a | `services/billing-py/billing/clients/erp_client.py:10` | high | `/ds-audit` | retries/no-cap |
| DS-RT-02b | `apps/api/src/locks/redlock.ts:7` | high | `/ds-audit` | retries/no-cap |
| DS-RT-03a | `apps/api/src/carriers/carrier-sync.producer.ts:11` | medium | `/ds-audit` | retries/no-backoff |
| DS-RT-03b | `services/notify-dotnet/src/Notify.Api/Sms/SmsRetry.cs:18` | medium | `/ds-audit` | retries/no-jitter |
| DS-RT-04a | `apps/worker/src/clients/geo.client.ts:19` | high | `/ds-audit` | retries/multiplied-layers |
| DS-RT-04b | `services/notify-dotnet/src/Notify.Api/Program.cs:23` | high | `/ds-audit` | retries/multiplied-layers |
| DS-RT-05a | `apps/api/src/carriers/dhl.client.ts:17` | high | `/ds-audit` | retries/non-idempotent-retried |
| DS-RT-05b | `services/dispatch-go/internal/courier/client.go:30` | high | `/ds-audit` | retries/non-idempotent-retried |
| DS-RT-05c | `apps/api/src/carriers/pickup-booking.ts:17` | high | `/ds-audit` | retries/key-minted-per-attempt |
| DS-RT-06a | `apps/api/src/addresses/address-book.usecase.ts:18` | medium | `/ds-audit` | retries/state-not-reset |
| DS-RT-06b | `apps/worker/src/jobs/delivery-confirmation.processor.ts:26` | high | `/ds-audit` | retries/step-repeated |
| DS-RT-07a | `apps/api/src/grpc/quotes.grpc.ts:25` | medium | `/ds-audit` | deadlines/not-propagated |
| DS-RT-07b | `apps/api/src/auth/otp.controller.ts:21` | high | `/ds-audit` | deadlines/command-without-expiry |
| DS-RT-08a | `apps/worker/src/jobs/customs-docs.processor.ts:12` | medium | `/ds-audit` | deadlines/timeout-order |
| DS-RT-08b | `apps/workflows-ts/src/workflows/quote-expiry.workflow.ts:9` | medium | `/ds-audit` | deadlines/timeout-order |
| DS-CO-01a | `apps/api/src/catalog/catalog-import.job.ts:29` | high | `/ds-audit` | locks/release-without-owner-check |
| DS-CO-01b | `apps/api/src/locks/lock-helpers.ts:16` | medium | `/ds-audit` | locks/release-get-compare-del |
| DS-CO-02a | `apps/api/src/reports/nightly-rollup.job.ts:16` | high | `/ds-audit` | locks/no-ttl |
| DS-CO-02b | `services/billing-py/billing/reports.py:12` | high | `/ds-audit` | locks/no-ttl |
| DS-CO-03a | `services/ledger-jvm/src/main/java/com/acme/ledger/jobs/StatementCloseJob.java:25` | high | `/ds-audit` | locks/acquire-result-ignored |
| DS-CO-03b | `apps/api/src/catalog/price-sync.job.ts:17` | high | `/ds-audit` | locks/acquire-result-ignored |
| DS-CO-04a | `apps/worker/src/consumers/cod-settlement.consumer.ts:29` | high | `/ds-audit` | locks/lease-renewal-ignored |
| DS-CO-04b | `services/ledger-jvm/src/main/java/com/acme/ledger/jobs/ReconciliationJob.java:26` | high | `/ds-audit` | locks/lease-shorter-than-work |
| DS-CO-05a | `apps/api/src/scheduling/singleton-runner.ts:15` | high | `/ds-audit` | locks/advisory-via-pool |
| DS-CO-05b | `apps/api/src/db/migrate-lock.ts:10` | high | `/ds-audit` | locks/advisory-via-pool |
| DS-CO-06a | `services/dispatch-go/internal/leader/dispatcher.go:22` | high | `/ds-audit` | locks/leader-after-loss |
| DS-CO-06b | `services/dispatch-go/internal/leader/rebalancer.go:32` | high | `/ds-audit` | locks/leader-after-loss |
| DS-CO-07a | `apps/worker/src/sync/route-planner.lease.ts:36` | high | `/ds-audit` | clocks/wall-clock-duration |
| DS-CO-07b | `services/dispatch-go/internal/dispatch/batcher.go:12` | medium | `/ds-audit` | clocks/monotonic-stripped |
| DS-CO-08a | `apps/api/src/scheduling/job-leases.repo.ts:13` | high | `/ds-audit` | clocks/two-clocks |
| DS-CO-08b | `apps/worker/src/sync/audit-feed.cursor.ts:25` | high | `/ds-audit` | clocks/two-clocks |
| DS-CO-09a | `apps/worker/src/consumers/customer-profile.consumer.ts:37` | high | `/ds-audit` | clocks/last-write-wins |
| DS-CO-09b | `apps/worker/src/projections/order-timeline.projector.ts:18` | high | `/ds-audit` | clocks/order-by-timestamp |
| DS-CO-10a | `apps/worker/src/outbox/worker-outbox.writer.ts:15` | high | `/ds-audit` | clocks/time-as-id |
| DS-CO-10b | `apps/api/src/catalog/price-events.producer.ts:16` | medium | `/ds-audit` | clocks/time-as-id |
| DS-CO-11a | `apps/api/src/billing/settlement.cron.ts:17` | high | `/ds-audit` | clocks/dst-schedule |
| DS-CO-11b | `deploy/k8s/cronjobs/payout-export.yaml:7` | high | `/ds-audit` | clocks/dst-schedule |
| DS-WF-01a | `apps/workflows-ts/src/workflows/returns.workflow.ts:6` | medium | `/ds-audit` | workflows/non-determinism |
| DS-WF-01b | `services/dispatch-go/internal/workflows/route.go:20` | critical | `/ds-audit` | workflows/non-determinism |
| DS-WF-02a | `apps/workflows-ts/src/workflows/fulfilment.workflow.ts:23` | critical | `/ds-audit` | workflows/unversioned-change |
| DS-WF-02b | `services/ledger-jvm/src/main/java/com/acme/ledger/workflow/SettlementWorkflowImpl.java:24` | critical | `/ds-audit` | workflows/unversioned-change |
| DS-WF-03a | `apps/workflows-ts/src/workflows/linehaul.workflow.ts:9` | high | `/ds-audit` | workflows/activity-unlimited-retry |
| DS-WF-03b | `apps/workflows-ts/src/workflows/manifest.workflow.ts:7` | medium | `/ds-audit` | workflows/heartbeat-never-sent |
| DS-WF-04a | `apps/api/src/sagas/order-placement.saga.ts:29` | high | `/ds-audit` | sagas/missing-compensation |
| DS-WF-04b | `services/ledger-jvm/src/main/java/com/acme/ledger/saga/CarrierInvoiceSaga.java:18` | high | `/ds-audit` | sagas/missing-compensation |
| DS-WF-05a | `apps/api/src/sagas/exchange.saga.ts:33` | medium | `/ds-audit` | sagas/compensation-order |
| DS-WF-05b | `services/dispatch-go/internal/workflows/cod.go:20` | high | `/ds-audit` | sagas/compensation-cancelled-context |
| DS-WF-05c | `apps/api/src/sagas/order-placement.saga.ts:37` | medium | `/ds-audit` | sagas/compensation-registered-late |
| DS-WF-06a | `apps/api/src/sagas/refund.sagas.ts:17` | high | `/ds-audit` | sagas/in-memory-saga |
| DS-WF-06b | `apps/api/src/sagas/consolidation.saga.ts:19` | medium | `/ds-audit` | sagas/compensation-not-idempotent |
| DS-EC-01a | `schemas/proto/acme/dispatch/v1/courier_assigned.proto:9` | high | `/ds-audit` | contracts/breaking-change |
| DS-EC-01b | `schemas/asyncapi/orders.asyncapi.yaml:26` | high | `/ds-audit` | contracts/breaking-change |
| DS-EC-02a | `apps/worker/src/consumers/order-events.consumer.ts:20` | medium | `/ds-audit` | contracts/unvalidated-payload |
| DS-EC-02b | `services/billing-py/billing/tasks_ingest.py:11` | medium | `/ds-audit` | contracts/unvalidated-payload |
| DS-EC-03a | `apps/worker/src/consumers/order-events.consumer.ts:38` | high | `/ds-audit` | contracts/intolerant-reader |
| DS-EC-03b | `services/ledger-jvm/src/main/java/com/acme/ledger/kafka/ShipmentCostListener.java:17` | high | `/ds-audit` | contracts/intolerant-reader |
| DS-EC-04a | `apps/api/src/invoices/invoice-events.ts:17` | high | `/ds-audit` | contracts/semantic-change |
| DS-EC-04b | `apps/worker/src/routing/route-events.producer.ts:19` | high | `/ds-audit` | contracts/semantic-change |
| DS-EC-05a | `apps/api/src/milestones/milestones.consumer.ts:21` | medium | `/ds-audit` | contracts/name-drift |
| DS-EC-05b | `apps/worker/src/consumers/returns-approved.consumer.ts:17` | medium | `/ds-audit` | contracts/consumed-never-produced |
| DS-EC-06a | `apps/api/src/orders/order-aggregate.store.ts:25` | high | `/ds-audit` | eventsourcing/append-without-expected-version |
| DS-EC-06b | `services/notify-dotnet/src/Notify.Api/Preferences/SubscriberPreferencesService.cs:28` | high | `/ds-audit` | eventsourcing/append-without-expected-version |
| DS-EC-07a | `apps/api/db/migrations/0007_order_events.sql:2` | high | `/ds-audit` | eventsourcing/no-stream-uniqueness |
| DS-EC-07b | `packages/event-log/prisma/schema.prisma:11` | high | `/ds-audit` | eventsourcing/no-stream-uniqueness |
| DS-EC-08a | `apps/worker/src/projections/courier-stats.projector.ts:18` | high | `/ds-audit` | eventsourcing/projection-not-idempotent |
| DS-EC-08b | `apps/worker/src/projections/order-summary.projector.ts:19` | medium | `/ds-audit` | eventsourcing/checkpoint-before-write |
| DS-EC-09a | `apps/api/src/orders/order.aggregate.ts:41` | high | `/ds-audit` | eventsourcing/side-effect-in-apply |
| DS-EC-09b | `apps/api/src/orders/order-snapshots.ts:10` | medium | `/ds-audit` | eventsourcing/snapshot-without-version |
| DS-EC-10a | `apps/api/src/orders/orders-admin.controller.ts:17` | medium | `/ds-audit` | eventsourcing/read-model-lag |
| DS-EC-10b | `apps/web/src/routes/orders.new.tsx:12` | medium | `/ds-audit` | eventsourcing/read-model-lag |
| DS-HO-DB-a | `apps/api/src/invoices/issue-invoice.usecase.ts:18` | high | `/db-audit` | database/enqueue-inside-transaction |
| DS-HO-DB-b | `apps/api/src/returns/approve-return.usecase.ts:19` | high | `/db-audit` | database/enqueue-inside-transaction |
| DS-HO-DB-c | `apps/worker/src/outbox/ledger-outbox.relay.ts:21` | high | `/db-audit` | database/claim-without-skip-locked |
| DS-HO-DB-d | `apps/api/src/sagas/order-amend.saga.ts:26` | high | `/db-audit` | database/lost-update |
| DS-HO-SEC-a | `apps/api/src/label-ocr/ocr-credits.service.ts:15` | high | `/security-audit` | security/clamped-debit |
| DS-HO-SEC-b | `apps/worker/src/jobs/cod-payout.processor.ts:25` | critical | `/security-audit` | security/money-consumer-no-reserve |
| DS-HO-SEC-c | `apps/worker/src/jobs/customs-duty-charge.processor.ts:29` | critical | `/security-audit` | security/psp-key-per-retry |
| DS-HO-PERF-a | `apps/api/src/scheduling/cron-explorer.ts:27` | high | `/perf-audit` | performance/once-per-fleet-per-replica |
| DS-HO-PERF-b | `apps/api/src/main.ts:13` | high | `/perf-audit` | performance/migrate-at-boot |
| DS-HO-PERF-c | `apps/api/src/couriers/courier-sms.throttle.ts:10` | medium | `/perf-audit` | performance/per-replica-lock |
| DS-HO-PERF-d | `apps/worker/src/jobs/tracking-ingest.processor.ts:15` | high | `/perf-audit` | performance/worker-capacity |
| DS-HO-INF-a | `deploy/terraform/lambda-returns.tf:9` | high | `/infra-audit` | infrastructure/sqs-lambda-visibility |
| DS-HO-INF-b | `deploy/terraform/lambda-returns.tf:30` | high | `/infra-audit` | infrastructure/partial-batch-response |
| DS-HO-OBS-a | `apps/api/src/notifications/notifications.module.ts:8` | medium | `/obs-audit` | observability/queue-hop-no-propagation |
| DS-HO-BE-a | `apps/worker/src/schedules/eta-recompute.cron.ts:19` | medium | `/backend-audit` | backend/schedule-self-overlap |
| DS-HO-BE-b | `apps/worker/src/schedules/carrier-cutoff.cron.ts:13` | medium | `/backend-audit` | backend/schedule-zone-dst |

Severity split: 8 critical · 82 high · 37 medium · 0 low. Total 127 seeded defects (111 scored under `/ds-audit`, 4 under `/db-audit`, 3 under `/security-audit`, 4 under `/perf-audit`, 2 under `/infra-audit`, 1 under `/obs-audit`, 2 under `/backend-audit`), 46 decoys.

### Coverage by detector §

One row per detector §; every distributed-systems § carries at least two seeds (52 §s, 111 seeds). The routed rows follow, one per owner §.

| detector § | classes | seeded | ids |
|------------|---------|--------|-----|
| `messaging-scan §1` | messaging/ack-before-effect | 3 | DS-MQ-01a, DS-MQ-01b, DS-MQ-01c |
| `messaging-scan §2` | messaging/dedupe-ends-at-removal, messaging/never-acked-redelivery, messaging/unstable-reserve-id | 3 | DS-MQ-02a, DS-MQ-02b, DS-MQ-02c |
| `messaging-scan §3` | messaging/poison-requeue-loop, messaging/poison-skipped, messaging/swallow-and-ack | 3 | DS-MQ-03a, DS-MQ-03b, DS-MQ-03c |
| `messaging-scan §4` | messaging/ordering-broken | 2 | DS-MQ-04a, DS-MQ-04b |
| `messaging-scan §5` | messaging/rebalance | 2 | DS-MQ-05a, DS-MQ-05b |
| `messaging-scan §6` | messaging/lock-shorter-than-run, messaging/visibility-shorter-than-eta | 2 | DS-MQ-06a, DS-MQ-06b |
| `messaging-scan §7` | messaging/enqueue-raced-timer, messaging/producer-fire-and-forget, messaging/producer-idempotence-off | 3 | DS-MQ-07a, DS-MQ-07b, DS-MQ-07c |
| `messaging-scan §8` | messaging/eviction-drops-jobs, messaging/ttl-drops-unprocessed | 2 | DS-MQ-08a, DS-MQ-08b |
| `messaging-scan §9` | messaging/unbounded-prefetch | 2 | DS-MQ-09a, DS-MQ-09b |
| `messaging-scan §10` | messaging/broker-durability | 2 | DS-MQ-10a, DS-MQ-10b |
| `messaging-scan §11` | messaging/version-trap | 2 | DS-MQ-11a, DS-MQ-11b |
| `dual-write-scan §1` | dualwrite/after-commit-loss-window, dualwrite/commit-then-publish | 3 | DS-DW-01a, DS-DW-01b, DS-DW-01c |
| `dual-write-scan §2` | dualwrite/publish-then-commit | 2 | DS-DW-02a, DS-DW-02b |
| `dual-write-scan §3` | dualwrite/relay-parallel, dualwrite/relay-unordered | 2 | DS-DW-03a, DS-DW-03b |
| `dual-write-scan §4` | dualwrite/inbox-read-then-write, dualwrite/inbox-two-stores | 2 | DS-DW-04a, DS-DW-04b |
| `dual-write-scan §5` | dualwrite/cdc-tombstone, dualwrite/cdc-update-dropped | 2 | DS-DW-05a, DS-DW-05b |
| `dual-write-scan §6` | dualwrite/gap-blind-cursor | 2 | DS-DW-06a, DS-DW-06b |
| `retry-deadline-scan §1` | retries/non-retryable-retried | 2 | DS-RT-01a, DS-RT-01b |
| `retry-deadline-scan §2` | retries/no-cap | 2 | DS-RT-02a, DS-RT-02b |
| `retry-deadline-scan §3` | retries/no-backoff, retries/no-jitter | 2 | DS-RT-03a, DS-RT-03b |
| `retry-deadline-scan §4` | retries/multiplied-layers | 2 | DS-RT-04a, DS-RT-04b |
| `retry-deadline-scan §5` | retries/key-minted-per-attempt, retries/non-idempotent-retried | 3 | DS-RT-05a, DS-RT-05b, DS-RT-05c |
| `retry-deadline-scan §6` | retries/state-not-reset, retries/step-repeated | 2 | DS-RT-06a, DS-RT-06b |
| `retry-deadline-scan §7` | deadlines/command-without-expiry, deadlines/not-propagated | 2 | DS-RT-07a, DS-RT-07b |
| `retry-deadline-scan §8` | deadlines/timeout-order | 2 | DS-RT-08a, DS-RT-08b |
| `coordination-scan §1` | locks/release-get-compare-del, locks/release-without-owner-check | 2 | DS-CO-01a, DS-CO-01b |
| `coordination-scan §2` | locks/no-ttl | 2 | DS-CO-02a, DS-CO-02b |
| `coordination-scan §3` | locks/acquire-result-ignored | 2 | DS-CO-03a, DS-CO-03b |
| `coordination-scan §4` | locks/lease-renewal-ignored, locks/lease-shorter-than-work | 2 | DS-CO-04a, DS-CO-04b |
| `coordination-scan §5` | locks/advisory-via-pool | 2 | DS-CO-05a, DS-CO-05b |
| `coordination-scan §6` | locks/leader-after-loss | 2 | DS-CO-06a, DS-CO-06b |
| `coordination-scan §7` | clocks/monotonic-stripped, clocks/wall-clock-duration | 2 | DS-CO-07a, DS-CO-07b |
| `coordination-scan §8` | clocks/two-clocks | 2 | DS-CO-08a, DS-CO-08b |
| `coordination-scan §9` | clocks/last-write-wins, clocks/order-by-timestamp | 2 | DS-CO-09a, DS-CO-09b |
| `coordination-scan §10` | clocks/time-as-id | 2 | DS-CO-10a, DS-CO-10b |
| `coordination-scan §11` | clocks/dst-schedule | 2 | DS-CO-11a, DS-CO-11b |
| `workflow-scan §1` | workflows/non-determinism | 2 | DS-WF-01a, DS-WF-01b |
| `workflow-scan §2` | workflows/unversioned-change | 2 | DS-WF-02a, DS-WF-02b |
| `workflow-scan §3` | workflows/activity-unlimited-retry, workflows/heartbeat-never-sent | 2 | DS-WF-03a, DS-WF-03b |
| `workflow-scan §4` | sagas/missing-compensation | 2 | DS-WF-04a, DS-WF-04b |
| `workflow-scan §5` | sagas/compensation-cancelled-context, sagas/compensation-order, sagas/compensation-registered-late | 3 | DS-WF-05a, DS-WF-05b, DS-WF-05c |
| `workflow-scan §6` | sagas/compensation-not-idempotent, sagas/in-memory-saga | 2 | DS-WF-06a, DS-WF-06b |
| `event-contract-scan §1` | contracts/breaking-change | 2 | DS-EC-01a, DS-EC-01b |
| `event-contract-scan §2` | contracts/unvalidated-payload | 2 | DS-EC-02a, DS-EC-02b |
| `event-contract-scan §3` | contracts/intolerant-reader | 2 | DS-EC-03a, DS-EC-03b |
| `event-contract-scan §4` | contracts/semantic-change | 2 | DS-EC-04a, DS-EC-04b |
| `event-contract-scan §5` | contracts/consumed-never-produced, contracts/name-drift | 2 | DS-EC-05a, DS-EC-05b |
| `event-contract-scan §6` | eventsourcing/append-without-expected-version | 2 | DS-EC-06a, DS-EC-06b |
| `event-contract-scan §7` | eventsourcing/no-stream-uniqueness | 2 | DS-EC-07a, DS-EC-07b |
| `event-contract-scan §8` | eventsourcing/checkpoint-before-write, eventsourcing/projection-not-idempotent | 2 | DS-EC-08a, DS-EC-08b |
| `event-contract-scan §9` | eventsourcing/side-effect-in-apply, eventsourcing/snapshot-without-version | 2 | DS-EC-09a, DS-EC-09b |
| `event-contract-scan §10` | eventsourcing/read-model-lag | 2 | DS-EC-10a, DS-EC-10b |
| `job-lifecycle-scan §4 (backend)` | backend/schedule-self-overlap | 1 | DS-HO-BE-a |
| `job-lifecycle-scan §6 (backend)` | backend/schedule-zone-dst | 1 | DS-HO-BE-b |
| `logic-race-scan §4 (security)` | security/money-consumer-no-reserve, security/psp-key-per-retry | 2 | DS-HO-SEC-b, DS-HO-SEC-c |
| `logic-race-scan §5 (security)` | security/clamped-debit | 1 | DS-HO-SEC-a |
| `request-path-scan §18 (performance)` | performance/per-replica-lock | 1 | DS-HO-PERF-c |
| `request-path-scan §20 (performance)` | performance/migrate-at-boot, performance/once-per-fleet-per-replica | 2 | DS-HO-PERF-a, DS-HO-PERF-b |
| `request-path-scan §23 (performance)` | performance/worker-capacity | 1 | DS-HO-PERF-d |
| `serverless-reliability-scan §2 (infrastructure)` | infrastructure/sqs-lambda-visibility | 1 | DS-HO-INF-a |
| `serverless-reliability-scan §4 (infrastructure)` | infrastructure/partial-batch-response | 1 | DS-HO-INF-b |
| `trace-propagation-scan §2 (observability)` | observability/queue-hop-no-propagation | 1 | DS-HO-OBS-a |
| `transaction-scan §1 (database)` | database/enqueue-inside-transaction | 2 | DS-HO-DB-a, DS-HO-DB-b |
| `transaction-scan §5 (database)` | database/claim-without-skip-locked | 1 | DS-HO-DB-c |
| `transaction-scan §8 (database)` | database/lost-update | 1 | DS-HO-DB-d |
| **decoys (must not be reported)** | — | **46** | DS-DECOY-01 … DS-DECOY-46 |

---

## DS-MQ-01a — Receipt processor returns before the e-mail send settles

```defect
id:       DS-MQ-01a
file:     apps/worker/src/jobs/receipts.processor.ts
line:     22
severity: critical
command:  /ds-audit
class:    messaging/ack-before-effect
detector: messaging-scan §1
anchor:   this.mailer.sendReceipt(job.data.orderId);
match:    await|ack|complet|receipt|floating|before
```

`handle()` calls `this.mailer.sendReceipt(…)` without `await` or `return`, so the base processor's `process()` resolves at once and BullMQ marks the job completed (BQ2) while the send is still in flight; a crash, a deploy or a mail-API error after that point loses the customer's receipt, and a rejection becomes an unhandled promise. Grep 1a (the `handle(` arm: `BaseProcessor` owns `process()`). Fix: `await this.mailer.sendReceipt(…)` (the mailer already sends a stable `idempotency-key`). Proof: V291 — kill the worker after `handle()` returns and before the mail mock answers; the receipt is never sent before the fix, sent once after.

## DS-MQ-01b — Celery task that creates billing orders acks on receipt (no `acks_late` anywhere)

```defect
id:       DS-MQ-01b
file:     services/billing-py/billing/tasks.py
line:     10
severity: critical
command:  /ds-audit
class:    messaging/ack-before-effect
detector: messaging-scan §1
anchor:   def create_billing_order(self, shipment_id: str, merchant_id: str, amount_minor: int) -> int:
match:    acks?_late|ack|receipt|lost|celery
```

No task, `app.conf` or settings line sets `acks_late`/`task_acks_late` (P1's presence list is empty), so Celery acknowledges `create_billing_order` when the worker receives it (CY1). A worker killed mid-task (OOM, deploy, node drain) loses the billing order or its ERP push for good. Fix: `acks_late=True` + `reject_on_worker_lost=True` on this task with an idempotent create (`get_or_create` on `shipment_id`, which is already unique on invoices). Proof: V291 — SIGKILL the worker inside the task against Redis in a container; the task is gone before the fix and re-runs once after.

## DS-MQ-01c — Ledger posting listener acknowledges before booking (MANUAL_IMMEDIATE)

```defect
id:       DS-MQ-01c
file:     services/ledger-jvm/src/main/java/com/acme/ledger/kafka/PostingListener.java
line:     21
severity: high
command:  /ds-audit
class:    messaging/ack-before-effect
detector: messaging-scan §1
anchor:   ack.acknowledge();
match:    acknowledge|ack|before|manual|commit
```

`ack-mode: manual_immediate` (application.yml) commits the offset synchronously on `ack.acknowledge()`, and the listener calls it on its first line; a crash or a database error in `postingService.book(…)` after that point loses the posting — the offset is already past it (KA1, SK-01, grep J1). Money: security `logic-race-scan` corroborates. Fix: acknowledge after `book(…)` returns (the insert is `ON CONFLICT DO NOTHING`, so a redelivery is harmless). Proof: V291 — fail `book` once after the ack against Kafka in a container; the posting never lands before the fix.

## DS-MQ-02a — Label purchase reserved on `job.id`, an id a re-enqueue changes

```defect
id:       DS-MQ-02a
file:     apps/worker/src/jobs/labels.processor.ts
line:     28
severity: high
command:  /ds-audit
class:    messaging/unstable-reserve-id
detector: messaging-scan §2
anchor:   const fresh = await this.claims.reserve(`label:${job.id}`);
match:    job\.id|stable|reserve|claim|duplicat|idempot
```

The claim key is the BullMQ auto id: a producer retry or a re-enqueue from the console creates a new `job.id`, so the reserve lets a second carrier label be bought (a billable transaction); the claim also commits in its own statement before the purchase, so a crash between the two loses the label (ID4; the non-atomic half corroborates `dual-write-scan` §4). Grep 2b. Fix: key the claim on the business id (`label:${shipmentId}`) and send it to the carrier as its idempotency key. Proof: V292 — enqueue the same shipment twice; two labels before the fix, one after.

## DS-MQ-02b — sqs-consumer ≥ 14 handler never returns the message: every scan is redelivered

```defect
id:       DS-MQ-02b
file:     apps/api/src/carriers/carrier-events.poller.ts
line:     24
severity: high
command:  /ds-audit
class:    messaging/never-acked-redelivery
detector: messaging-scan §2
anchor:   handleMessage: async (message) => {
match:    return|delete|sqs-consumer|redeliver|handleMessage
```

`sqs-consumer` ^14.1 (apps/api/package.json) deletes only a message the handler returns (AW4); this handler returns `undefined`, so every carrier scan comes back after the 120 s visibility timeout, inserts another `tracking_history` row and pushes another "parcel moved" notification, until the redrive policy moves it to the DLQ after five receives (deploy/terraform/sqs-carrier-events.tf). Grep 2d. Fix: `return message;` at the end of the handler (or `strictReturn`), plus a unique key on `(carrier, tracking_no, scanned_at)`. Proof: V292 against LocalStack — one scan, wait two visibility windows: one row after the fix, five before.

## DS-MQ-02c — `jobId` dedupe relied on with `removeOnComplete: true`

```defect
id:       DS-MQ-02c
file:     apps/api/src/invoices/invoice-mailer.producer.ts
line:     14
severity: high
command:  /ds-audit
class:    messaging/dedupe-ends-at-removal
detector: messaging-scan §2
anchor:   { jobId: `invoice-email:${invoiceId}`, removeOnComplete: true }
match:    jobId|removeOnComplete|dedup|duplicat
```

The comment relies on the job id to send each invoice e-mail once, but `removeOnComplete: true` deletes the job the moment it completes, freeing the id (BQ4): any later request for the same invoice (a console resend, a retried API call) enqueues and sends again. Grep 2c. Fix: a reserve keyed on the invoice id in the consumer's transaction (or keep completed ids for the dedupe window: `removeOnComplete: { age: 86400 }`). Proof: V292 — add, complete, add again with the same id: two e-mails before the fix.

## DS-MQ-03a — amqplib `nack(msg)` requeues forever on a RabbitMQ 4.3 quorum queue

```defect
id:       DS-MQ-03a
file:     apps/worker/src/consumers/returns.consumer.ts
line:     31
severity: high
command:  /ds-audit
class:    messaging/poison-requeue-loop
detector: messaging-scan §3
anchor:   this.channel.nack(msg);
match:    nack|requeue|delivery.?limit|poison|loop
```

`nack` requeues by default (RQ4), and on RabbitMQ 4.3 a nack-requeue no longer counts toward the quorum queue's `x-delivery-limit` (RQ2), so the limit and DLX in deploy/rabbitmq/definitions.json never fire: a return that always fails inspection loops hot at the head of `returns.inspect`. The comment claims the opposite (precedent 34). Grep 3d. Fix: `nack(msg, false, false)` (or `reject(msg, false)`) to dead-letter, with a bounded retry queue. Proof: V293 — one poison + 100 good against rabbitmq:4.3: the poison loops before the fix.

## DS-MQ-03b — `new DefaultErrorHandler()` with no recoverer on the ledger container factory

```defect
id:       DS-MQ-03b
file:     services/ledger-jvm/src/main/java/com/acme/ledger/kafka/KafkaConfig.java
line:     19
severity: high
command:  /ds-audit
class:    messaging/poison-skipped
detector: messaging-scan §3
anchor:   factory.setCommonErrorHandler(new DefaultErrorHandler());
match:    DefaultErrorHandler|recoverer|dead.?letter|DLT|skip|poison
```

The no-arg handler retries a failing record 9 more times with no back-off and then logs and skips it (KA7, SK-02): a posting that fails 10 times vanishes from the ledger with a log line. Grep J3 (no `DeadLetterPublishingRecoverer` anywhere). Fix: `new DefaultErrorHandler(new DeadLetterPublishingRecoverer(template), new ExponentialBackOffWithMaxRetries(5))` and an alert on the `.DLT` topic. Proof: V293 against Kafka in a container — a poison posting lands on `ledger.postings.DLT` after the fix, nowhere before.

## DS-MQ-03c — Catalog-sync processor catches and logs: the job completes, never retries, never fails

```defect
id:       DS-MQ-03c
file:     apps/worker/src/jobs/catalog-sync.processor.ts
line:     25
severity: high
command:  /ds-audit
class:    messaging/swallow-and-ack
detector: messaging-scan §3
anchor:   } catch (syncErr) {
match:    catch|swallow|complet|retr|failed
```

The `catch` logs and falls through, so BullMQ records the job as completed: a WMS outage silently drops the SKU push (no retry, nothing in the failed set the base class reports on). Grep 3a. Fix: rethrow (or `throw new UnrecoverableError` for permanent 4xx) so attempts and the failed-set report apply. Proof: V293 — fail the WMS mock once: the job completes with no push before the fix.

## DS-MQ-04a — Order-status batch applied in parallel: a later status can land first

```defect
id:       DS-MQ-04a
file:     apps/worker/src/consumers/order-status.consumer.ts
line:     25
severity: high
command:  /ds-audit
class:    messaging/ordering-broken
detector: messaging-scan §4
anchor:   await Promise.all(batch.messages.map((m) => this.apply(batch.topic, m)));
match:    Promise\.all|parallel|order|batch
```

The topic is keyed by order id so a partition holds each order's statuses in order, but `Promise.all` over the batch runs `UPDATE … SET status = ?` for `picking` and `packed` of one order concurrently; whichever commits last wins, with no version guard (KJS-03). Grep 4a. Fix: group the batch by key and apply each key's messages serially, or guard the write with the event's sequence. Proof: V294 — v1…v100 for one order: final status not the last one before the fix.

## DS-MQ-04b — Go producer writes `shipment.status` with no key and a CRC32 balancer

```defect
id:       DS-MQ-04b
file:     services/dispatch-go/internal/dispatch/statusproducer.go
line:     37
severity: high
command:  /ds-audit
class:    messaging/ordering-broken
detector: messaging-scan §4
anchor:   return p.writer.WriteMessages(ctx, kafka.Message{Value: body})
match:    key|partition|CRC32|murmur|order
```

dispatch-go sends status changes with no key, so the CRC32 balancer spreads one shipment's changes across partitions, and ledger-jvm writes `settled` to the same topic keyed with murmur2 (ShipmentStatusProducer): even with a key the two producers place one shipment on different partitions (LD4, LRK-02). Consumers see a shipment's statuses out of order. `stacks.md` G5 prints the key-less message and the CRC32 balancer (distributed-systems 2.0.1, IR-3); the other producer on the topic is the read. Fix: key by shipment id and use `&kafka.Murmur2Balancer{}` (the Java default). Proof: V294 — produce v1…v100 for one shipment from both services; one partition after the fix.

## DS-MQ-05a — `eachBatch` with no `heartbeat()` over a 2 k-message batch

```defect
id:       DS-MQ-05a
file:     apps/worker/src/consumers/inventory-snapshots.consumer.ts
line:     23
severity: medium
command:  /ds-audit
class:    messaging/rebalance
detector: messaging-scan §5
anchor:   eachBatch: async ({ batch, resolveOffset }) => {
match:    heartbeat|rebalance|session|isStale|eachBatch
```

A batch of ~2 k snapshots at ~150 ms each (p99 400 ms, the class comment) runs minutes against `sessionTimeout: 30_000`, and the handler never calls `heartbeat()` or checks `isStale()` (KJ3, KJS-04): the member is kicked, the partition is reassigned mid-batch and the new owner reprocesses it. The upsert is guarded by `taken_at`, so the effect is idempotent — medium. Grep 5a. Fix: `await heartbeat()` per message and `if (isStale()) break`. Proof: V295.

## DS-MQ-05b — `max-poll-records: 500` × p99 2 s against `max.poll.interval.ms: 300000`

```defect
id:       DS-MQ-05b
file:     services/ledger-jvm/src/main/resources/application.yml
line:     10
severity: medium
command:  /ds-audit
class:    messaging/rebalance
detector: messaging-scan §5
anchor:   max-poll-records: 500
match:    max.poll|records|interval|rebalance|p99
```

slo.yml cites the posting handler's p99 as 2 000 ms; 500 records × 2 s = 1 000 s per poll, more than three times `max.poll.interval.ms` 300 000 (both ends cited, tier S): on a slow day the consumer is evicted, its partitions move and the uncommitted records are reprocessed (KA2, SK-05). Grep J4. Fix: `max-poll-records: 100` (100 × 2 s = 200 s) or a longer interval sized from the p99. Proof: V295.

## DS-MQ-06a — 40 s synchronous PDF render inline at the default 30 s lock

```defect
id:       DS-MQ-06a
file:     apps/worker/src/jobs/invoice-pdf.processor.ts
line:     29
severity: high
command:  /ds-audit
class:    messaging/lock-shorter-than-run
detector: messaging-scan §6
anchor:   const pdf = renderInvoicePdfSync(invoice);
match:    lock|stall|CPU|render|sandbox|event loop
```

perf/pdf-render-baseline.json measures p99 40.2 s; the render is synchronous pdfkit work, so BullMQ's lock renewal (which runs on this event loop) cannot fire, the 30 s `lockDuration` default lapses (BQ2), the job is declared stalled and re-run once by `maxStalledCount` 1 — and the merchant gets the invoice e-mail twice. Fix: a sandboxed processor (`new Worker(queue, path)`) for the render, plus a reserve on the e-mail. Proof: V296 — a 1.5 × lockDuration CPU loop: 2 effects before, 1 after.

## DS-MQ-06b — `countdown=7200` on the Redis broker with the default 1 h visibility timeout

```defect
id:       DS-MQ-06b
file:     services/billing-py/billing/dunning.py
line:     9
severity: high
command:  /ds-audit
class:    messaging/visibility-shorter-than-eta
detector: messaging-scan §6
anchor:   send_dunning_reminder.apply_async(args=[invoice_id], countdown=7200)
match:    countdown|visibility|ETA|redeliver|7200
```

The broker is Redis (`CELERY_BROKER_URL`, settings.py) with no `broker_transport_options`, so `visibility_timeout` is the 3 600 s default (CY4); a task scheduled 7 200 s out is redelivered to another worker after an hour, and the reminder is sent twice. Grep P4. Fix: `broker_transport_options = {'visibility_timeout': 4 * 3600}` or schedule the reminder with beat/RedBeat instead of an ETA. Proof: V296 with a short visibility against Redis in a container.

## DS-MQ-07a — `confirm-order` enqueued without `await` in the controller

```defect
id:       DS-MQ-07a
file:     apps/api/src/orders/orders.controller.ts
line:     19
severity: high
command:  /ds-audit
class:    messaging/producer-fire-and-forget
detector: messaging-scan §7
anchor:   this.ordersQueue.add('confirm-order'
match:    await|floating|fire|unhandled|enqueue
```

The controller answers 201 before `ordersQueue.add` settles; a Redis error becomes an unhandled rejection and the order never gets its confirmation e-mail, wave assignment or SLA timer while the merchant saw success (BMQ-05). Grep 7a. Fix: `await` it and surface the failure — or, since the order is already committed, emit it through the outbox port in the same transaction. Proof: V297 — pause the Redis container, place an order: 201 and no job before the fix.

## DS-MQ-07b — Producer `retries: 0` beside `enable.idempotence: true`

```defect
id:       DS-MQ-07b
file:     services/ledger-jvm/src/main/resources/application.yml
line:     19
severity: medium
command:  /ds-audit
class:    messaging/producer-idempotence-off
detector: messaging-scan §7
anchor:   retries: 0
match:    retries|idempoten
```

Idempotence needs `retries` > 0; with `retries: 0` the producer either rejects the config or silently runs non-idempotent depending on version (KA4, SK-05), and a transient broker error now drops the send instead of retrying it. Grep J4. Fix: drop `retries` (the default is effectively unbounded within `delivery.timeout.ms`). Proof: the static fact plus V297 with a broker restart.

## DS-MQ-07c — Enqueue bounded by `Promise.race`: the losing `add` still lands after the 503

```defect
id:       DS-MQ-07c
file:     apps/api/src/queue/base.producer.ts
line:     28
severity: medium
command:  /ds-audit
class:    messaging/enqueue-raced-timer
detector: messaging-scan §7
anchor:   await Promise.race([this.queue.add(
match:    Promise\.race|timeout|503|land|offline
```

When Redis stalls, the timer wins and the caller gets 503, but the `add` already sits in ioredis's offline queue and runs when Redis returns; the client app retries the 503 and the job is enqueued twice (grep 7d, BMQ-05 variant). Every producer extending `BaseProducer` inherits it — one finding, N sites. Fix: a `jobId` from the business id so the retry is deduplicated, or abort the command (no offline queue for producers). Proof: V297 stall-then-recover — pause Redis, enqueue, resume, count jobs.

## DS-MQ-08a — `maxmemory-policy allkeys-lru` on the job Redis

```defect
id:       DS-MQ-08a
file:     deploy/redis.conf
line:     7
severity: high
command:  /ds-audit
class:    messaging/eviction-drops-jobs
detector: messaging-scan §8
anchor:   maxmemory-policy allkeys-lru
match:    maxmemory|evict|allkeys|noeviction
```

This Redis holds every BullMQ queue, the Celery broker DB and the lock keys; under memory pressure LRU eviction deletes job hashes and lock keys silently (BQ6 requires `noeviction`). Grep 8a. Fix: `maxmemory-policy noeviction` with an alert on `used_memory`, and cache keys on a separate instance. Proof: V298 — fill a redis:8.2 container past `maxmemory`: queued jobs vanish before the fix.

## DS-MQ-08b — `label-print` has a 15-minute `x-message-ttl` and no dead-letter exchange

```defect
id:       DS-MQ-08b
file:     deploy/rabbitmq/definitions.json
line:     23
severity: high
command:  /ds-audit
class:    messaging/ttl-drops-unprocessed
detector: messaging-scan §8
anchor:   "x-message-ttl": 900000
match:    ttl|dead.?letter|DLX|expire|label-print
```

At the 16:00 cut-off 40–60 k labels queue at once (LabelPrintConsumer's comment); anything older than 15 minutes expires and, with no `x-dead-letter-exchange` on the queue, is discarded — parcels leave without labels and nothing records which (RMQ-05). 8e prints the queue's `arguments` line: a TTL with no dead-letter exchange in the same object (distributed-systems 2.0.1, IR-4). Fix: a DLX on the queue (or no TTL). Proof: V298 — publish past the TTL against rabbitmq:4.3: the message is in the DLQ after the fix.

## DS-MQ-09a — amqplib consumer with no `prefetch()`

```defect
id:       DS-MQ-09a
file:     apps/worker/src/consumers/label-print.consumer.ts
line:     18
severity: medium
command:  /ds-audit
class:    messaging/unbounded-prefetch
detector: messaging-scan §9
anchor:   await this.channel.consume('label-print'
match:    prefetch|unbounded|buffer|memory
```

With no `channel.prefetch(n)`, RabbitMQ pushes the whole backlog (40–60 k labels at cut-off) into this process (RQ4): memory climbs and every message is unacked at once, so a crash redelivers all of them. Grep 9a. Fix: `await this.channel.prefetch(20)` before `consume`. Proof: V299 — publish 100 k: unacked ≤ prefetch after the fix.

## DS-MQ-09b — `XREADGROUP` with no `COUNT` on a 3 k entries/s stream

```defect
id:       DS-MQ-09b
file:     apps/worker/src/streams/tracking-stream.reader.ts
line:     27
severity: medium
command:  /ds-audit
class:    messaging/unbounded-prefetch
detector: messaging-scan §9
anchor:   const res = (await this.redis.xreadgroup('GROUP', GROUP, this.consumerName, 'BLOCK', 5_000, 'STREAMS', STREAM, '>'))
match:    COUNT|xreadgroup|unbounded|batch
```

Without `COUNT` one read returns every new entry (RD3), so after a pause the reader pulls the whole backlog into memory and into its pending list at once. Grep 9b. Fix: `'COUNT', 200`. Proof: V299.

## DS-MQ-10a — JetStream with no `sync_interval` carrying the PAYMENTS stream

```defect
id:       DS-MQ-10a
file:     deploy/nats/nats-server.conf
line:     7
severity: high
command:  /ds-audit
class:    messaging/broker-durability
detector: messaging-scan §10
anchor:   jetstream {
match:    sync_interval|fsync|JetStream|durab|PAYMENTS
```

The PAYMENTS stream (COD collections, deploy/nats/streams/payments.json) relies on the server default, which flushes to disk every 2 minutes (NA4): an acknowledged collection can be lost if the replicas lose power together (one rack, one zone). Grep 10's file-level line lists `nats-server.conf` as a JetStream server with no `sync_interval` (distributed-systems 2.0.1, IR-4); the stream it carries is the read. Fix: `sync_interval: always` in the `jetstream` block for this cluster. Proof: the static fact with both ends (the stream and the server config).

## DS-MQ-10b — `KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "true"` on the production brokers

```defect
id:       DS-MQ-10b
file:     deploy/kafka/compose.kafka.yaml
line:     18
severity: high
command:  /ds-audit
class:    messaging/broker-durability
detector: messaging-scan §10
anchor:   KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE: "true"
match:    unclean|leader|election|durab
```

This compose file is the production broker on the three Kafka hosts (its header), carrying orders and ledger postings: an out-of-sync replica may become leader and acknowledged records are truncated away. Grep 10. Fix: `false` (the default). Proof: the static fact.

## DS-MQ-11a — `repeat: { pattern }` on BullMQ 6

```defect
id:       DS-MQ-11a
file:     apps/api/src/reports/report-schedule.ts
line:     11
severity: medium
command:  /ds-audit
class:    messaging/version-trap
detector: messaging-scan §11
anchor:   repeat: { pattern: '0 6 * * *' }
match:    repeat|upsertJobScheduler|BullMQ 6|scheduler
```

BullMQ ^6.3.4 removed the legacy `repeat` option (BQ1); the daily merchant report is no longer scheduled after the upgrade. Grep 11. Fix: `reportsQueue.upsertJobScheduler('daily-merchant-report', { pattern: '0 6 * * *' })`. Proof: the version line plus the dated change; the job count after boot.

## DS-MQ-11b — `processing.guarantee: exactly_once` on Kafka Streams 4.1

```defect
id:       DS-MQ-11b
file:     services/ledger-jvm/src/main/resources/application.yml
line:     29
severity: high
command:  /ds-audit
class:    messaging/version-trap
detector: messaging-scan §11
anchor:   processing.guarantee: exactly_once
match:    exactly_once|processing.guarantee|Streams 4|v2
```

kafka-streams 4.1.0 (pom.xml) removed `exactly_once` (KA5): the ledger-balances topology fails to start. Grep J4. Fix: `exactly_once_v2`. Proof: the version line plus the dated change.

## DS-DW-01a — `em.flush()` then `kafka.send(orders.placed)` with nothing durable between

```defect
id:       DS-DW-01a
file:     apps/api/src/orders/place-order.usecase.ts
line:     24
severity: critical
command:  /ds-audit
class:    dualwrite/commit-then-publish
detector: dual-write-scan §1
anchor:   await this.kafka.send({ topic: 'orders.placed'
match:    outbox|dual|commit|flush|lost|publish
```

The order commits on `flush()`; a crash or a broker error before `send` resolves loses `orders.placed`, the only way the worker learns to open the fulfilment task — the order exists and is never picked. The project's outbox port (`OutboxService`, used by the shipment, manifest and invoice use cases) is bypassed here. Grep 1a (a `candidates` line, not `outbox port`). Fix: `TxRunner.run` + `outbox.emit('orders.placed', …)`. Proof: V300 — throw once between flush and send against Postgres and Kafka in containers: the event is missing before the fix.

## DS-DW-01b — `SaveChangesAsync` then `Publish` in an API controller (no bus outbox)

```defect
id:       DS-DW-01b
file:     services/notify-dotnet/src/Notify.Api/Controllers/PreferencesController.cs
line:     20
severity: high
command:  /ds-audit
class:    dualwrite/commit-then-publish
detector: dual-write-scan §1
anchor:   await db.SaveChangesAsync(ct);
match:    SaveChanges|Publish|outbox|bus|dual
```

MassTransit's EF outbox is registered for consumers only (`AddEntityFrameworkOutbox` without `UseBusOutbox`), so this controller's `Publish` goes straight to RabbitMQ after the commit: a crash between them leaves the preference changed and the worker's customer-profile mirror never told (MT-01, NT2). Grep 1b. Fix: `o.UseBusOutbox()` and publish before `SaveChangesAsync`. Proof: V300.

## DS-DW-01c — `delay_on_commit` for a fact the ledger relies on

```defect
id:       DS-DW-01c
file:     services/billing-py/billing/tasks.py
line:     34
severity: high
command:  /ds-audit
class:    dualwrite/after-commit-loss-window
detector: dual-write-scan §1
anchor:   notify_ledger_invoice_finalized.delay_on_commit(invoice.pk)
match:    delay_on_commit|on_commit|outbox|lost|ledger
```

`delay_on_commit` closes the phantom (no task for a rolled-back invoice) but keeps the loss window: a crash after the commit and before the enqueue, or Redis down at that moment, and the ledger never books the receivable — the comment says nothing else tells it (CY5, OX5). The billing outbox and Debezium router already exist (`record_event`). Grep O4. Fix: `record_event('invoice', …, 'invoice.finalized', …)` in the same `atomic()`. Proof: V300 broker-down variant.

## DS-DW-02a — `orders.cancelled` published before the status change commits

```defect
id:       DS-DW-02a
file:     apps/api/src/orders/cancel-order.usecase.ts
line:     18
severity: high
command:  /ds-audit
class:    dualwrite/publish-then-commit
detector: dual-write-scan §2
anchor:   await this.kafka.send({ topic: 'orders.cancelled'
match:    publish|commit|phantom|rollback|cancel
```

The warehouse stops picking and the carrier booking is voided on this event, but the write follows the publish: if the `flush` fails (a concurrent ship, a timeout) the order stays live while every consumer acted on a cancellation that never committed. Grep 2. Fix: write first and emit through the outbox port in one transaction. Proof: V300 reverse probe — fault the flush after the send.

## DS-DW-02b — `WriteMessages(courier.assigned)` before `tx.Commit()`

```defect
id:       DS-DW-02b
file:     services/dispatch-go/internal/dispatch/assign.go
line:     28
severity: high
command:  /ds-audit
class:    dualwrite/publish-then-commit
detector: dual-write-scan §2
anchor:   if err := a.writer.WriteMessages(ctx, kafka.Message{Key: []byte(shipmentID), Value: body}); err != nil {
match:    WriteMessages|Commit|publish|phantom|before
```

The courier app and the tracking page act on `courier.assigned`, but the commit that makes the assignment true comes after the publish; a failed commit (the `status = 'ready'` guard lost a race) leaves a courier driving to a shipment assigned to someone else. Grep 2 (Go). Fix: commit first and publish through an outbox row written in the transaction. Proof: V300 reverse probe.

## DS-DW-03a — Outbox relay reads unpublished rows with no `ORDER BY`

```defect
id:       DS-DW-03a
file:     apps/api/src/outbox/outbox.relay.ts
line:     32
severity: high
command:  /ds-audit
class:    dualwrite/relay-unordered
detector: dual-write-scan §3
anchor:   const rows = await em.find(OutboxEvent, { publishedAt: null }, { limit: 200 });
match:    order|relay|outbox|sequence
```

Postgres returns the 200 rows in no defined order, so `shipment.created`/`manifest.closed`/`invoice.voided` for one aggregate can be relayed in reverse (OBX-01); consumers apply the older state last. Grep 3a. Fix: `{ orderBy: { id: 'asc' } }` (ids are UUIDv7). Proof: V301 — two updates to one aggregate: the consumer sees v1 then v2 after the fix.

## DS-DW-03b — Outbox relay publishes the batch in parallel

```defect
id:       DS-DW-03b
file:     apps/api/src/outbox/outbox.relay.ts
line:     43
severity: high
command:  /ds-audit
class:    dualwrite/relay-parallel
detector: dual-write-scan §3
anchor:   await Promise.all(rows.map(publish));
match:    Promise\.all|parallel|order|relay
```

`Promise.all(rows.map(publish))` sends every row concurrently, so even an ordered read loses per-aggregate order on the wire (OBX-02). Grep 3b. Fix: publish per aggregate in order (group by `aggregateId`, serial within a group). Proof: V301 under relay parallelism 4.

## DS-DW-04a — Dedupe reserve in Redis, effect in Postgres

```defect
id:       DS-DW-04a
file:     apps/worker/src/consumers/fulfilment-tasks.consumer.ts
line:     29
severity: medium
command:  /ds-audit
class:    dualwrite/inbox-two-stores
detector: dual-write-scan §4
anchor:   const fresh = await this.redis.set(`processed:manifest-closed:${eventId}`, '1', 'EX', 86_400, 'NX');
match:    redis|NX|reserve|inbox|atomic|two
```

The reserve commits in Redis before the `dock_tasks` insert; a crash between them marks the event processed with no task (lost), and after 24 h (`EX 86_400`) a redelivery or replay opens a second task. Grep 4a. Fix: `INSERT INTO processed_events … ON CONFLICT DO NOTHING` in the same transaction as the task, or a unique `manifest_id` on `dock_tasks`. Proof: V303 — crash after the reserve: the task is never created before the fix.

## DS-DW-04b — Inbox as read-then-write, recorded after a non-idempotent effect

```defect
id:       DS-DW-04b
file:     apps/worker/src/consumers/invoice-mirror.consumer.ts
line:     25
severity: medium
command:  /ds-audit
class:    dualwrite/inbox-read-then-write
detector: dual-write-scan §4
anchor:   const seen = await em.findOne(ProcessedEvent, { eventId });
match:    read.then.write|findOne|processed|inbox|atomic|reserve
```

`findOne` then the `void_count + 1` update then the inbox insert, with no transaction: two concurrent deliveries both see nothing and both increment, and a crash between the update and the insert re-applies the increment on redelivery. Grep 4b. Fix: insert the inbox row first with `ON CONFLICT DO NOTHING RETURNING` and do the update in the same transaction. Proof: V303 and V292's barrier variant.

## DS-DW-05a — Debezium outbox router set to `warn` while billing UPDATEs outbox rows

```defect
id:       DS-DW-05a
file:     deploy/debezium/billing-outbox-connector.json
line:     18
severity: high
command:  /ds-audit
class:    dualwrite/cdc-update-dropped
detector: dual-write-scan §5
anchor:   "transforms.outbox.table.op.invalid.behavior": "warn"
match:    op\.invalid|warn|update|outbox|EventRouter
```

`billing/outbox.py` `amend_pending_event` rewrites a pending outbox row with `.update(payload=…)`; the EventRouter only routes inserts, and with `table.op.invalid.behavior: warn` the update is logged and dropped (OX1): the corrected invoice never reaches the ERP. Grep 5. Fix: insert a new outbox row (an `invoice.amended` event) instead of updating, and set the behaviour to `fatal`. Proof: V302.

## DS-DW-05b — CDC consumer with no null-value branch on a topic that emits tombstones

```defect
id:       DS-DW-05b
file:     apps/worker/src/consumers/billing-cdc.consumer.ts
line:     23
severity: high
command:  /ds-audit
class:    dualwrite/cdc-tombstone
detector: dual-write-scan §5
anchor:   const change = InvoiceChange.safeParse(JSON.parse(message.value!.toString()).payload);
match:    tombstone|null|delete|CDC|crash
```

deploy/debezium/invoices-cdc-connector.json sets `tombstones.on.delete: true`; a deleted invoice produces a record with a null value, `message.value!.toString()` throws, and kafkajs's `restartOnFailure` crash-loops the partition (OX3). Grep 5 (file-level: no null branch). Fix: `if (message.value === null) return handleDelete(message.key)` before parsing. Proof: V302 — delete a row: the partition keeps moving after the fix.

## DS-DW-06a — `WHERE id > $checkpoint` over a bigserial written by four concurrent importers

```defect
id:       DS-DW-06a
file:     apps/worker/src/sync/warehouse-sync.ts
line:     23
severity: high
command:  /ds-audit
class:    dualwrite/gap-blind-cursor
detector: dual-write-scan §6
anchor:   'SELECT id, stream_id, type, data FROM order_events WHERE id > $1 ORDER BY id LIMIT 500',
match:    checkpoint|cursor|bigserial|gap|skip|late
```

Sequence values are drawn at insert time, not at commit: importer A holds id 10 open while B commits 11, the sync advances its checkpoint to 11, and A's event 10 is never sent to the WMS (E5). Grep 6. Fix: a lag behind the oldest open transaction (`pg_snapshot_xmin`) plus a periodic rescan, or a serial appender. Proof: V301 gap variant.

## DS-DW-06b — UUIDv7 floor with no lag and no rescan

```defect
id:       DS-DW-06b
file:     apps/worker/src/sync/order-feed.cursor.ts
line:     23
severity: high
command:  /ds-audit
class:    dualwrite/gap-blind-cursor
detector: dual-write-scan §6
anchor:   'SELECT id, merchant_id FROM orders WHERE id > $1 ORDER BY id LIMIT 1000',
match:    floor|UUIDv7|cursor|lag|rescan|skip
```

Order ids are UUIDv7 minted on each api pod's clock before the insert commits; the floor is the last id seen, so a slower transaction or a pod whose clock trails commits an id below the floor and the partner feed skips that order forever. Grep 6 (the decoy `outbox-feed.cursor.ts` is the same floor with a lag and a rescan). Fix: hold the floor back by a lag longer than the longest transaction plus clock skew, and rescan. Proof: V301 gap variant (coordination-scan §8 corroborates on the clock half).

## DS-RT-01a — tenacity `@retry` with no `retry=` around a call that raises `ValidationError` on 422

```defect
id:       DS-RT-01a
file:     services/billing-py/billing/clients/tax_client.py
line:     14
severity: medium
command:  /ds-audit
class:    retries/non-retryable-retried
detector: retry-deadline-scan §1
anchor:   @retry(stop=stop_after_attempt(5), wait=wait_exponential_jitter(max=20))
match:    retry=|ValidationError|422|permanent|classif
```

Without `retry=`, tenacity retries every exception (RY1), so a 422 for an unknown tariff code is retried five times over ~40 s before the caller hears it. Grep 1a. Fix: `retry=retry_if_exception_type((requests.ConnectionError, requests.Timeout))` and raise `ValidationError` unretried. Proof: V304 — one permanent error: 1 attempt after the fix.

## DS-RT-01b — Resilience4j retry with the default predicate on a 4xx-answering client

```defect
id:       DS-RT-01b
file:     services/ledger-jvm/src/main/java/com/acme/ledger/clients/RatesClient.java
line:     15
severity: medium
command:  /ds-audit
class:    retries/non-retryable-retried
detector: retry-deadline-scan §1
anchor:   private final Retry retry = Retry.of("fxRates", RetryConfig.custom()
match:    retryExceptions|predicate|4xx|400|permanent|Resilience4j
```

`RetryConfig.custom()` with no `retryExceptions`/`ignoreExceptions` retries every exception, including the treasury API's 400 for an unsupported pair (`HttpClientErrorException`) — four calls for an answer that will not change (RY9). Grep 1c. Fix: `.retryExceptions(ResourceAccessException.class, HttpServerErrorException.class)`. Proof: V304.

## DS-RT-02a — Bare tenacity `@retry` on the ERP push (retries forever, no wait)

```defect
id:       DS-RT-02a
file:     services/billing-py/billing/clients/erp_client.py
line:     10
severity: high
command:  /ds-audit
class:    retries/no-cap
detector: retry-deadline-scan §2
anchor:   @retry
match:    @retry|cap|forever|stop|unbounded
```

A bare `@retry` has no stop and no wait (RY1): during an ERP outage `push_order` spins forever inside the Celery task, holding the worker slot and hammering the ERP. Grep 2a. Fix: `@retry(stop=stop_after_attempt(5), wait=wait_exponential_jitter(max=60), retry=retry_if_exception_type(requests.ConnectionError))`. Proof: V304 — a persistent 503: attempts ≤ 5, then the error surfaces.

## DS-RT-02b — Redlock `retryCount: -1` (wait forever for the lock)

```defect
id:       DS-RT-02b
file:     apps/api/src/locks/redlock.ts
line:     7
severity: high
command:  /ds-audit
class:    retries/no-cap
detector: retry-deadline-scan §2
anchor:   retryCount: -1,
match:    retryCount|-1|unbounded|forever|redlock
```

`-1` makes `acquire` retry without bound (LO2): when the holder dies without releasing (or the key outlives it), every manifest-closer call blocks forever, piling up requests. Grep 2a. Fix: a finite `retryCount` with a surfaced "busy" result. Proof: V304.

## DS-RT-03a — BullMQ `attempts: 5` with no `backoff`

```defect
id:       DS-RT-03a
file:     apps/api/src/carriers/carrier-sync.producer.ts
line:     11
severity: medium
command:  /ds-audit
class:    retries/no-backoff
detector: retry-deadline-scan §3
anchor:   await this.queue.add('sync-carrier', { carrier }, { attempts: 5 });
match:    backoff|attempts|immediate|delay
```

The `carrier-sync` queue has no `defaultJobOptions` and this call sets no `backoff`, so the five attempts run back to back (BQ2) against a carrier API that is already failing. F2 (ds-inventory) resolves `backoff=none`. Fix: `backoff: { type: 'exponential', delay: 5_000 }` (BullMQ adds no jitter: use a custom strategy for full jitter). Proof: V305.

## DS-RT-03b — Polly constant 2 s delay with `UseJitter = false` on a shared provider

```defect
id:       DS-RT-03b
file:     services/notify-dotnet/src/Notify.Api/Sms/SmsRetry.cs
line:     18
severity: medium
command:  /ds-audit
class:    retries/no-jitter
detector: retry-deadline-scan §3
anchor:   UseJitter = false,
match:    jitter|constant|backoff|Polly
```

Every notify pod retries the throttled SMS provider at the same fixed 2 s rhythm, so after a 429 storm the retries arrive synchronised (RY6). Grep 3a. Fix: `BackoffType = DelayBackoffType.Exponential, UseJitter = true` and honour `Retry-After`. Proof: V305.

## DS-RT-04a — Geocode job attempts 3 × client attempts 3 against a shared quota

```defect
id:       DS-RT-04a
file:     apps/worker/src/clients/geo.client.ts
line:     19
severity: high
command:  /ds-audit
class:    retries/multiplied-layers
detector: retry-deadline-scan §4
anchor:   retry: { attempts: 3, backoffMs: 500 },
match:    layer|multipl|attempts|9|nine|budget
```

`GeocodeProducer` inherits `BaseProducer`'s `attempts: 3` and the processor calls `GeoClient.geocode`, whose kernel retries 3 times: one failing address makes 9 calls against the company-wide 50 req/s maps quota (RT-4, the real-repo shape). Grep 4d prints the chain `geocode.processor.ts ← GeoClient ← geo.client.ts`. Fix: one retrying layer — `retry: { attempts: 1 }` here, the job keeps its attempts. Proof: V306 — a mock that always fails: 9 calls before, 3 after.

## DS-RT-04b — Standard resilience handler on every client plus a per-client retry on the SMS client

```defect
id:       DS-RT-04b
file:     services/notify-dotnet/src/Notify.Api/Program.cs
line:     23
severity: high
command:  /ds-audit
class:    retries/multiplied-layers
detector: retry-deadline-scan §4
anchor:   builder.Services.ConfigureHttpClientDefaults(
match:    layer|standard|resilience|multipl|handler
```

`ConfigureHttpClientDefaults(…AddStandardResilienceHandler())` puts a retry (3 retries) on every HttpClient, and the SMS client adds `SmsRetry` (4 retries) on top: one throttled send can make up to 20 provider calls (RY7). Grep 4b. Fix: remove the default for this client (`RemoveAllResilienceHandlers()`) or drop the per-client retry. Proof: V306.

## DS-RT-05a — `axiosRetry` on the client that POSTs DHL shipments

```defect
id:       DS-RT-05a
file:     apps/api/src/carriers/dhl.client.ts
line:     17
severity: high
command:  /ds-audit
class:    retries/non-idempotent-retried
detector: retry-deadline-scan §5
anchor:   axiosRetry(this.http, { retries: 3, retryDelay: axiosRetry.exponentialDelay });
match:    axios.?retry|POST|idempot|duplicat|network
```

axios-retry's default condition retries network errors on any method (RY3); a `POST /v2/shipments` whose response is lost after DHL created the shipment is sent again — a second shipment and a second billable label. Grep 5b. Fix: `retryCondition` excluding POST, or a stable idempotency key per shipment if DHL stores one. Proof: V307 — apply then drop the response: 2 shipments before the fix.

## DS-RT-05b — go-retryablehttp POST that creates a courier job

```defect
id:       DS-RT-05b
file:     services/dispatch-go/internal/courier/client.go
line:     30
severity: high
command:  /ds-audit
class:    retries/non-idempotent-retried
detector: retry-deadline-scan §5
anchor:   resp, err := c.http.Post(c.base+"/assignments", "application/json", bytes.NewReader(body))
match:    retryablehttp|POST|idempot|duplicat
```

retryablehttp retries POSTs on connection errors and 5xx (RY5); each POST creates a new job on the courier's phone, so a lost response becomes two jobs for one shipment. Grep 5c. Fix: send an `Idempotency-Key` the courier backend stores, or a non-retrying client for this call. Proof: V307.

## DS-RT-05c — `Idempotency-Key: randomUUID()` inside the `pRetry` callback

```defect
id:       DS-RT-05c
file:     apps/api/src/carriers/pickup-booking.ts
line:     17
severity: high
command:  /ds-audit
class:    retries/key-minted-per-attempt
detector: retry-deadline-scan §5
anchor:   'Idempotency-Key': randomUUID()
match:    Idempotency-Key|randomUUID|per attempt|stable|key
```

Kurier24 deduplicates on the key, but a new UUID is minted on every attempt, so a retried POST after a lost response books a second pickup (BO-05). Grep 5e. Fix: derive the key once from the business id (`pickup-${warehouseId}-${date}`) outside the callback. Proof: V307.

## DS-RT-06a — `pRetry` around `em.flush()` on an EntityManager a failed flush left dirty

```defect
id:       DS-RT-06a
file:     apps/api/src/addresses/address-book.usecase.ts
line:     18
severity: medium
command:  /ds-audit
class:    retries/state-not-reset
detector: retry-deadline-scan §6
anchor:   await pRetry(() => this.em.flush(), { retries: 3, randomize: true, minTimeout: 200 });
match:    flush|unit of work|retry|identity map|reset
```

After a unique-violation the identity map still holds the conflicting entity, so attempts 2–4 replay the same INSERT and fail the same way (the retry cannot resolve the conflict it was written for). Grep 6a. Fix: retry the whole unit of work with a fresh `em.fork()` inside the callback, or upsert. Proof: V308.

## DS-RT-06b — E-mail then carrier close in one job with no per-step checkpoint

```defect
id:       DS-RT-06b
file:     apps/worker/src/jobs/delivery-confirmation.processor.ts
line:     26
severity: high
command:  /ds-audit
class:    retries/step-repeated
detector: retry-deadline-scan §6
anchor:   await this.mailer.sendDeliveredEmail(job.data.customerEmail, job.data.trackingNo, signal);
match:    checkpoint|step|email|repeat|retry
```

When `closeShipment` fails the job is retried from the top, so the customer receives the "delivered" e-mail again on every attempt (BJ-10). Grep 6b. Fix: a `(jobId, step)` reserve, or split the close into its own job. Proof: V308 — fail the close once: two e-mails before the fix.

## DS-RT-07a — gRPC quote handler fans out with no deadline taken from the call

```defect
id:       DS-RT-07a
file:     apps/api/src/grpc/quotes.grpc.ts
line:     25
severity: medium
command:  /ds-audit
class:    deadlines/not-propagated
detector: retry-deadline-scan §7
anchor:   async getQuote(call: ServerUnaryCall<QuoteRequest, QuoteReply>, callback: sendUnaryData<QuoteReply>): Promise<void> {
match:    deadline|getDeadline|propagat|budget|grpc
```

The checkout service gives up after 800 ms, but the handler calls three carrier rate APIs with a fixed 5 s timeout and never reads `call.getDeadline()` (RY11: manual in Node), so work continues long after the caller left. Grep 7a. Fix: pass the remaining budget (an `AbortSignal` from `call.getDeadline()`) into each request. Proof: V309.

## DS-RT-07b — OTP SMS enqueued with no `expiresAt` on a queue that retries for hours

```defect
id:       DS-RT-07b
file:     apps/api/src/auth/otp.controller.ts
line:     21
severity: high
command:  /ds-audit
class:    deadlines/command-without-expiry
detector: retry-deadline-scan §7
anchor:   await this.smsQueue.add('send-otp'
match:    expir|OTP|late|deadline|TTL
```

The code is valid 5 minutes, but the job carries no expiry and the queue retries for up to ~6 h behind a 5 msg/s limiter, so couriers receive dead codes (and pay for SMS) long after the login gave up (precedent 18 does not apply: lateness is wrong here). Grep 7b. Fix: `expiresAt` in the job data, checked first in the processor (drop when past). Proof: V309.

## DS-RT-08a — Job deadline 30 s over a 10 s × 3 customs tier with 2 s backoff

```defect
id:       DS-RT-08a
file:     apps/worker/src/jobs/customs-docs.processor.ts
line:     12
severity: medium
command:  /ds-audit
class:    deadlines/timeout-order
detector: retry-deadline-scan §8
anchor:   const JOB_TIMEOUT_MS = 30_000;
match:    deadline|30|timeout|attempts|overrun|budget
```

`CustomsClient` allows 3 attempts of `requestTimeout: 10_000` with up to 2 s and 4 s of backoff (≈ 36 s), above the 30 s job deadline, and the processor ignores the deadline's `AbortSignal`: the job fails at 30 s (attempts 1, so the on-call is paged) while the filing carries on and its MRN is discarded — the shipment waits for a manual re-run. The broker deduplicates on `reference`, so a re-run is safe (medium, not high). Grep 8 prints both ends. Fix: pass `signal` into `fileDeclaration`, and size inner × attempts + backoff under the deadline. Proof: V309.

## DS-RT-08b — Activity Start-To-Close 30 min under a 15-minute quote hold

```defect
id:       DS-RT-08b
file:     apps/workflows-ts/src/workflows/quote-expiry.workflow.ts
line:     9
severity: medium
command:  /ds-audit
class:    deadlines/timeout-order
detector: retry-deadline-scan §8
anchor:   startToCloseTimeout: '30 minutes',
match:    StartToClose|30 minutes|15|hold|deadline
```

The hold is worth 15 minutes, but `bookHeldSlot` may run (and be retried) for up to 30 minutes per attempt, so a booking can land after the carrier re-priced. Grep 8. Fix: `startToCloseTimeout` well under the remaining hold, and `scheduleToCloseTimeout: '15 minutes'`. Proof: V309 / V321 time-skipping.

## DS-CO-01a — Catalog import lock released with a bare `DEL`

```defect
id:       DS-CO-01a
file:     apps/api/src/catalog/catalog-import.job.ts
line:     29
severity: high
command:  /ds-audit
class:    locks/release-without-owner-check
detector: coordination-scan §1
anchor:   await this.redis.del(CATALOG_IMPORT_LOCK);
match:    del|owner|token|release|lock
```

The lock is set with a 10-minute TTL and the pid as value, but released with `redis.del`: an import that outlives the TTL deletes the next replica's lock, and a third replica starts a parallel import (LO1). Grep 1a. Fix: `LeaderLock.withLeaderLock` (the project's compare-and-delete). Proof: V310.

## DS-CO-01b — GET → compare → DEL release in two round trips (2 sites)

```defect
id:       DS-CO-01b
file:     apps/api/src/locks/lock-helpers.ts
line:     16
severity: medium
command:  /ds-audit
class:    locks/release-get-compare-del
detector: coordination-scan §1
anchor:   if (current === token) await redis.del(key);
match:    GET|compare|DEL|atomic|Lua|owner
```

`releaseImportLock` and `releaseRateCardLease` read the token and delete in separate commands; if the key expires and is re-acquired between them, the old holder deletes the new holder's lock (precedent 21, narrow). One helper pattern, two sites. Grep 1b. Fix: the Lua compare-and-delete `LeaderLock` already ships (F2b). Proof: V310 with a pause between GET and DEL.

## DS-CO-02a — `SET lock:nightly-rollup 1 NX` with no TTL

```defect
id:       DS-CO-02a
file:     apps/api/src/reports/nightly-rollup.job.ts
line:     16
severity: high
command:  /ds-audit
class:    locks/no-ttl
detector: coordination-scan §2
anchor:   const got = await this.redis.set('lock:nightly-rollup', '1', 'NX');
match:    TTL|PX|EX|expire|NX
```

A replica that dies during the rollup leaves the key forever: every later night's rollup returns at `if (!got)`. Grep 2a. Fix: `set(k, token, 'PX', ttl, 'NX')` and an owner-checked release. Proof: V311.

## DS-CO-02b — redis-py `r.lock(…)` with no `timeout=`

```defect
id:       DS-CO-02b
file:     services/billing-py/billing/reports.py
line:     12
severity: high
command:  /ds-audit
class:    locks/no-ttl
detector: coordination-scan §2
anchor:   with r.lock("reports:monthly-close"):
match:    timeout|lock|expire|redis-py
```

redis-py's `Lock` defaults to `timeout=None`: the key never expires (LO3), so a worker killed during the month close blocks every later close until someone deletes the key by hand. Grep py-2. Fix: `r.lock(name, timeout=1800, blocking_timeout=10)`. Proof: V311.

## DS-CO-03a — Redisson `tryLock(…)` as a statement

```defect
id:       DS-CO-03a
file:     services/ledger-jvm/src/main/java/com/acme/ledger/jobs/StatementCloseJob.java
line:     25
severity: high
command:  /ds-audit
class:    locks/acquire-result-ignored
detector: coordination-scan §3
anchor:   lock.tryLock(0, 60, TimeUnit.SECONDS);
match:    tryLock|result|boolean|acquire
```

`tryLock` returns false when another replica holds the lock, and the job closes statements anyway: two or three replicas insert the month's statements. The explicit lease also turns off the watchdog (LO4). Grep jv-3/jv-4. Fix: `if (!lock.tryLock(0, 10, MINUTES)) return;`. Proof: V312.

## DS-CO-03b — `pg_try_advisory_xact_lock` result discarded

```defect
id:       DS-CO-03b
file:     apps/api/src/catalog/price-sync.job.ts
line:     17
severity: high
command:  /ds-audit
class:    locks/acquire-result-ignored
detector: coordination-scan §3
anchor:   await tx.execute('SELECT pg_try_advisory_xact_lock(4242)');
match:    pg_try|advisory|result|ignored|acquire
```

The try-lock answers `false` on the second replica, which applies the surcharge anyway — the fuel surcharge is compounded once per replica that runs the cron. Grep 3a. Fix: read the boolean and return when false (or `pg_advisory_xact_lock` to wait). Proof: V312.

## DS-CO-04a — Settlement lease `extend()` result dropped on a balance-crediting consumer

```defect
id:       DS-CO-04a
file:     apps/worker/src/consumers/cod-settlement.consumer.ts
line:     29
severity: high
command:  /ds-audit
class:    locks/lease-renewal-ignored
detector: coordination-scan §4
anchor:   await this.settlementLease.extend();
match:    extend|lease|renew|false|holder
```

`extend()` answers false once another replica holds `lease:cod-balances`, and the loop credits the next balance anyway; the increment is not idempotent, so two holders double-credit merchants (security `logic-race-scan` §4 corroborates: money). No later check backstops it (the decoy `catalog-mirror.worker.ts` has one). Grep 4a. Fix: `if (!(await this.settlementLease.extend())) return;` before each write, plus a per-collection reserve. Proof: V313.

## DS-CO-04b — ShedLock `lockAtMostFor = "PT1M"` on a reconciliation bounded at 5 minutes

```defect
id:       DS-CO-04b
file:     services/ledger-jvm/src/main/java/com/acme/ledger/jobs/ReconciliationJob.java
line:     26
severity: high
command:  /ds-audit
class:    locks/lease-shorter-than-work
detector: coordination-scan §4
anchor:   @SchedulerLock(name = "reconcile", lockAtMostFor = "PT1M", lockAtLeastFor = "PT30S")
match:    lockAtMostFor|PT1M|5|lease|ShedLock
```

`ledger.reconcile.timeout: PT5M` (application.yml) bounds the pass at 5 minutes, but the lock is released after 1, so the next 10-minute tick on another replica can start while the first still writes adjustment postings — duplicates (LO5). Grep jv-4. Fix: `lockAtMostFor = "PT10M"` (above the bound). Proof: V313.

## DS-CO-05a — Session advisory lock through `pool.query` behind PgBouncer transaction mode

```defect
id:       DS-CO-05a
file:     apps/api/src/scheduling/singleton-runner.ts
line:     15
severity: high
command:  /ds-audit
class:    locks/advisory-via-pool
detector: coordination-scan §5
anchor:   const { rows } = await this.pool.query<{ locked: boolean }>('SELECT pg_try_advisory_lock($1) AS locked', [key]);
match:    advisory|pool|session|pgbouncer|transaction
```

Lock and unlock run on whatever pool connection is free, and `DATABASE_URL` reaches PgBouncer with `pool_mode = transaction` (deploy/k8s): the session lock lands on a server connection another client then reuses, excludes nothing, and the unlock misses it (LO10). Grep 5a + 5b. Fix: `pg_advisory_xact_lock` inside the transaction that does the work, or one checked-out client on a direct connection. Proof: V314.

## DS-CO-05b — Migration wrapper takes a session advisory lock through a pool behind PgBouncer

```defect
id:       DS-CO-05b
file:     apps/api/src/db/migrate-lock.ts
line:     10
severity: high
command:  /ds-audit
class:    locks/advisory-via-pool
detector: coordination-scan §5
anchor:   await pool.query('SELECT pg_advisory_lock(72707369)');
match:    advisory|migrat|pool|session|pgbouncer
```

Same shape in the migrate Job: the lock is taken and released on pool connections through the transaction-mode pooler, so two overlapping rollouts can migrate at once. Grep 5a. Fix: a direct (session-mode) connection, one client for lock and unlock. Proof: V314.

## DS-CO-06a — Dispatcher runs its loop under `context.Background()` on leadership

```defect
id:       DS-CO-06a
file:     services/dispatch-go/internal/leader/dispatcher.go
line:     22
severity: high
command:  /ds-audit
class:    locks/leader-after-loss
detector: coordination-scan §6
anchor:   OnStartedLeading: func(_ context.Context) {
match:    OnStartedLeading|context\.Background|leader|cancel
```

client-go cancels the leader context on loss, but the loop ignores it and runs under `context.Background()`; `OnStoppedLeading` only flips a metric, so the old leader keeps assigning shipments while the new one does too (LO8: no fencing). Grep go-6. Fix: `loop.Run(ctx)` with the callback's context and exit or stop on loss. Proof: V315.

## DS-CO-06b — `OnStoppedLeading` only logs; the cached `leading` flag stays true

```defect
id:       DS-CO-06b
file:     services/dispatch-go/internal/leader/rebalancer.go
line:     32
severity: high
command:  /ds-audit
class:    locks/leader-after-loss
detector: coordination-scan §6
anchor:   log.Printf("rebalancer: leadership lost")
match:    OnStoppedLeading|leading|flag|leader|log
```

`Trigger` (the ops console's rebalance button on every pod) checks `r.leading`, which is set on start and never cleared: after a lost lease this pod keeps accepting rebalances and moving couriers alongside the new leader. Grep go-6. Fix: `r.leading.Store(false)` in `OnStoppedLeading` (or exit). Proof: V315.

## DS-CO-07a — Lease expiry judged by `Date.now() - acquiredAt` on the wall clock

```defect
id:       DS-CO-07a
file:     apps/worker/src/sync/route-planner.lease.ts
line:     36
severity: high
command:  /ds-audit
class:    clocks/wall-clock-duration
detector: coordination-scan §7
anchor:   if (Date.now() - this.acquiredAt > ROUTE_LEASE_TTL_MS) {
match:    Date\.now|wall|monotonic|clock|lease
```

A step back of the wall clock (NTP) makes the 60 s lease look fresh, and a pause past it is not seen until the next region — the planner keeps planning while another pod took over (`acquiredAt` is also a stored instant from another host's clock, coordination §8). Grep 7a. Fix: a monotonic clock for the in-process budget and the database's clock for the takeover. Proof: V316.

## DS-CO-07b — `time.Now().UTC()` strips the monotonic reading before a timeout compare

```defect
id:       DS-CO-07b
file:     services/dispatch-go/internal/dispatch/batcher.go
line:     12
severity: medium
command:  /ds-audit
class:    clocks/monotonic-stripped
detector: coordination-scan §7
anchor:   start := time.Now().UTC()
match:    UTC|monotonic|time\.Since|clock
```

`.UTC()` drops the monotonic clock (TM1), so `time.Since(start)` uses the wall clock: a step back makes the 3 s batch window run long, a step forward ends it early. Grep go-7. Fix: `start := time.Now()`. Proof: V316.

## DS-CO-08a — Lease expiry written on the app clock, compared with `now()` in SQL

```defect
id:       DS-CO-08a
file:     apps/api/src/scheduling/job-leases.repo.ts
line:     13
severity: high
command:  /ds-audit
class:    clocks/two-clocks
detector: coordination-scan §8
anchor:   await this.em.nativeUpdate('job_leases', { shard, owner }, { expiresAt: new Date(Date.now() + ttlMs) });
match:    expires|clock|skew|now\(\)|Date\.now
```

`renew` and `takeOver` stamp `expires_at` from each api pod's clock while `takeOver` compares it with the database's `now()`: a pod whose clock trails by a few seconds writes leases that look expired early, and another replica takes the shard while the holder still sweeps. Grep 8a + 8b. Fix: `expires_at = now() + interval` in SQL on both ends. Proof: V317.

## DS-CO-08b — UUIDv7 window bound computed on the consumer host against ids minted on three services' clocks

```defect
id:       DS-CO-08b
file:     apps/worker/src/sync/audit-feed.cursor.ts
line:     25
severity: high
command:  /ds-audit
class:    clocks/two-clocks
detector: coordination-scan §8
anchor:   const upper = uuidv7At(Date.now() - FLOOR_LAG_MS);
match:    UUIDv7|clock|skew|floor|window
```

A writer whose clock trails the worker's by more than the 2 s lag mints ids below `upper` after the window moved past them; those admin actions never reach the compliance archive (no rescan). Grep 8c. Fix: a lag above the measured skew plus a rescan, or the database's sequence. Proof: V317 (dual-write-scan §6 owns the cursor half).

## DS-CO-09a — Last-write-wins on `updatedAt` stamped by two services' clocks

```defect
id:       DS-CO-09a
file:     apps/worker/src/consumers/customer-profile.consumer.ts
line:     37
severity: high
command:  /ds-audit
class:    clocks/last-write-wins
detector: coordination-scan §9
anchor:   } else if (incoming.updatedAt > row.updatedAt) {
match:    updatedAt|last.write|clock|skew|version
```

The merchant console and notify-dotnet both publish profile changes stamped with their own host clocks; with skew, an older change overwrites a newer one and the customer's new phone number is lost silently. Grep 9a. Fix: a version counter owned by one writer, or the event's stream position. Proof: V318.

## DS-CO-09b — `ORDER BY created_at` across event streams in a projector

```defect
id:       DS-CO-09b
file:     apps/worker/src/projections/order-timeline.projector.ts
line:     18
severity: high
command:  /ds-audit
class:    clocks/order-by-timestamp
detector: coordination-scan §9
anchor:   'SELECT stream_id, type, data, created_at FROM order_events WHERE created_at > $1 ORDER BY created_at LIMIT 500',
match:    created_at|order|stream|timestamp
```

`created_at` is `now()` at each importer's transaction start, so events from four concurrent importers interleave by start time, not commit order; the timeline shows events out of order and the `created_at >` cursor skips late commits (dual-write-scan §6 corroborates). Grep 9b. Fix: order within a stream by `version`, across streams by a log position. Proof: V318.

## DS-CO-10a — Ledger outbox row id is `String(Date.now())`

```defect
id:       DS-CO-10a
file:     apps/worker/src/outbox/worker-outbox.writer.ts
line:     15
severity: high
command:  /ds-audit
class:    clocks/time-as-id
detector: coordination-scan §10
anchor:   id: String(Date.now()),
match:    Date\.now|id|collision|millisecond
```

Two worker replicas (or two postings in one millisecond) mint the same primary key: the second insert fails and rolls back the money-moving transaction, or — where the relay keys `event-id` on it — the ledger deduplicates two different postings into one. Grep 10a. Fix: a UUIDv7 or a sequence. Proof: the static fact (minting line + `headers: { 'event-id': row.id }` in the relay).

## DS-CO-10b — `Date.now()` as the Kafka key on a compacted topic

```defect
id:       DS-CO-10b
file:     apps/api/src/catalog/price-events.producer.ts
line:     16
severity: medium
command:  /ds-audit
class:    clocks/time-as-id
detector: coordination-scan §10
anchor:   messages: [{ key: `${Date.now()}`, value: JSON.stringify({ carrier, pct }) }],
match:    Date\.now|key|compact|partition
```

The quoting service keeps the latest value per key, but every surcharge change gets a new time-based key, so compaction never collapses them and changes for one carrier land on random partitions, out of order. Grep 10a. Fix: key by carrier. Proof: the static fact.

## DS-CO-11a — COD settlement at 02:30 in `TZ=Europe/Berlin` under a 10-minute fleet lock

```defect
id:       DS-CO-11a
file:     apps/api/src/billing/settlement.cron.ts
line:     17
severity: high
command:  /ds-audit
class:    clocks/dst-schedule
detector: coordination-scan §11
anchor:   @Cron('0 30 2 * * *')
match:    DST|TZ|Berlin|02:30|twice|time.?zone
```

apps/api/Dockerfile sets `ENV TZ=Europe/Berlin`; on the October transition 02:30 occurs twice an hour apart, the 10-minute leader key has expired by the second, and settlement books the day's transfers twice (in March it never fires). Grep 11a with F3's TZ line. Fix: run the process in UTC or give the cron `timeZone: 'UTC'` at a time outside the transition, and key the run on the settlement day. Proof: V319.

## DS-CO-11b — CronJob at 02:30 with no `timeZone` on a cluster whose controller runs in Europe/Berlin

```defect
id:       DS-CO-11b
file:     deploy/k8s/cronjobs/payout-export.yaml
line:     7
severity: high
command:  /ds-audit
class:    clocks/dst-schedule
detector: coordination-scan §11
anchor:   schedule: "30 2 * * *"
match:    timeZone|DST|02:30|CronJob|Berlin
```

deploy/cluster/k3s-config.yaml and hosts.yml put kube-controller-manager in Europe/Berlin; with no `spec.timeZone` the payout export fires twice on the October night (and `concurrencyPolicy: Allow`) and not at all in March. Grep 11c. Fix: `timeZone: Etc/UTC` and `concurrencyPolicy: Forbid`. Proof: V319.

## DS-WF-01a — TS workflow reads `process.env` and imports `node:fs`

```defect
id:       DS-WF-01a
file:     apps/workflows-ts/src/workflows/returns.workflow.ts
line:     6
severity: medium
command:  /ds-audit
class:    workflows/non-determinism
detector: workflow-scan §1
anchor:   const RETURN_WINDOW_DAYS = Number(process.env.RETURN_WINDOW_DAYS ?? 30);
match:    process\.env|node:fs|determinis|sandbox|readFileSync
```

Workflow code may not read the environment or the filesystem: the bundler rejects `node:fs` and `process.env` is not the worker's inside the sandbox, so the return window can differ between the first run and a replay (WK1; the sandbox raises at first run, hence medium). Grep 1a. Fix: pass the window and the inspection days as workflow arguments or read them in an activity. Proof: V320.

## DS-WF-01b — Go workflow branches on `time.Now()`

```defect
id:       DS-WF-01b
file:     services/dispatch-go/internal/workflows/route.go
line:     20
severity: critical
command:  /ds-audit
class:    workflows/non-determinism
detector: workflow-scan §1
anchor:   if time.Now().After(cutoff) {
match:    time\.Now|workflow\.Now|determinis|replay|workflowcheck
```

On replay `time.Now()` returns a later time, so the branch can take `ReturnToDepot` where the history recorded `DeliverStop`: a non-determinism error on a route that is mid-delivery. Grep 1c (`workflowcheck` is the T tier). Fix: `workflow.Now(ctx)`. Proof: V320 — replay a recorded history after the cutoff.

## DS-WF-02a — New `notifyWarehouse` activity in a workflow with executions open for days, no `patched()`

```defect
id:       DS-WF-02a
file:     apps/workflows-ts/src/workflows/fulfilment.workflow.ts
line:     23
severity: critical
command:  /ds-audit
class:    workflows/unversioned-change
detector: workflow-scan §2
anchor:   await notifyWarehouse(orderId, pickList);
match:    patched|version|replay|open executions|notifyWarehouse
```

Against the base copy (`.refract-fixture/contract-base/…/fulfilment.workflow.ts`) the head inserts an activity before the 5-day `condition`; every execution open at deploy time replays into a different command sequence (the recorded `histories/fulfilment-2.13.json` schedules a timer where the new code schedules an activity). Grep 2c prints 0 gate calls; 2a prints the file with `gate-lines-added=0` against its `--contract-base` copy (distributed-systems 2.0.1, IR-5). Fix: `if (patched('notify-warehouse')) await notifyWarehouse(…)`. Proof: V320 — replay `histories/fulfilment-2.13.json`.

## DS-WF-02b — Java settlement workflow gains an activity with no `Workflow.getVersion`

```defect
id:       DS-WF-02b
file:     services/ledger-jvm/src/main/java/com/acme/ledger/workflow/SettlementWorkflowImpl.java
line:     24
severity: critical
command:  /ds-audit
class:    workflows/unversioned-change
detector: workflow-scan §2
anchor:   activities.notifyMerchant(merchantId, period, balance);
match:    getVersion|version|replay|notifyMerchant|open
```

Settlements stay open for the 3-day dispute window, so every deploy meets open executions; the inserted `notifyMerchant` call breaks replay of all of them (base copy in `.refract-fixture/contract-base/`). Grep 2c. Fix: `int v = Workflow.getVersion("notify-merchant", DEFAULT_VERSION, 1); if (v == 1) …`. Proof: V320.

## DS-WF-03a — Non-idempotent `bookLinehaul` activity with the default (unlimited) retry

```defect
id:       DS-WF-03a
file:     apps/workflows-ts/src/workflows/linehaul.workflow.ts
line:     9
severity: high
command:  /ds-audit
class:    workflows/activity-unlimited-retry
detector: workflow-scan §3
anchor:   const { bookLinehaul } = proxyActivities<typeof acts>({ startToCloseTimeout: '1 minute' });
match:    maximumAttempts|retry|unlimited|idempot|bookLinehaul
```

No `retry` means unlimited attempts (WK6); each `POST /bookings` books and bills a pallet position and the partner has no idempotency key, so every timeout after a successful POST books another. Grep 3b. Fix: `retry: { maximumAttempts: 1 }` plus a reconciliation lookup, or a partner-side reference used as a key. Proof: V321.

## DS-WF-03b — 2-hour activity with `heartbeatTimeout` and no `heartbeat()` call

```defect
id:       DS-WF-03b
file:     apps/workflows-ts/src/workflows/manifest.workflow.ts
line:     7
severity: medium
command:  /ds-audit
class:    workflows/heartbeat-never-sent
detector: workflow-scan §3
anchor:   heartbeatTimeout: '1 minute',
match:    heartbeat|timeout|activity
```

`buildAndUploadManifest` pages through up to 400 k parcels and never heartbeats, so the server times every attempt out after one minute and the three attempts all fail — the day's manifest is never uploaded (3d: 0 heartbeat calls). Fix: `Context.current().heartbeat(cursor)` per page (and resume from the heartbeat details). Proof: V321 time-skipping.

## DS-WF-04a — Stock reservation step registers no compensation

```defect
id:       DS-WF-04a
file:     apps/api/src/sagas/order-placement.saga.ts
line:     29
severity: high
command:  /ds-audit
class:    sagas/missing-compensation
detector: workflow-scan §4
anchor:   await this.inventory.reserve(order.lines);
match:    compensat|reserve|stock|release|saga
```

If the pick wave or the carrier booking fails, the saga undoes those steps but leaves the stock reserved forever (`InventoryClient.releaseReservation` exists and is never registered). Grep 4b pairing. Fix: register `releaseReservation(order.id)` before the reserve call. Proof: V322 — fail step 3: stock still reserved before the fix.

## DS-WF-04b — Eventuate step `lockCarrierInvoice` with no `.withCompensation`

```defect
id:       DS-WF-04b
file:     services/ledger-jvm/src/main/java/com/acme/ledger/saga/CarrierInvoiceSaga.java
line:     18
severity: high
command:  /ds-audit
class:    sagas/missing-compensation
detector: workflow-scan §4
anchor:   .invokeParticipant(this::lockCarrierInvoice)
match:    withCompensation|compensat|lock|Eventuate
```

A failure at `postToLedger` or `schedulePayment` cancels the review and reverses the posting but leaves the carrier's invoice locked in their portal, so the carrier can never correct it. Grep 4a. Fix: `.withCompensation(this::unlockCarrierInvoice)`. Proof: V322.

## DS-WF-05a — Compensations collected with `push` and run forward

```defect
id:       DS-WF-05a
file:     apps/api/src/sagas/exchange.saga.ts
line:     33
severity: medium
command:  /ds-audit
class:    sagas/compensation-order
detector: workflow-scan §5
anchor:   for (const undo of compensations) {
match:    reverse|order|push|forward|compensat
```

`push` + `for…of` undoes the return label before the replacement and the outbound booking — the reverse of the order the steps ran in, so a cancellation can hit a label the outbound still references. Grep 5a. Fix: `unshift` (or iterate reversed). Proof: V322.

## DS-WF-05b — Go compensation scheduled on the workflow context in a `defer`

```defect
id:       DS-WF-05b
file:     services/dispatch-go/internal/workflows/cod.go
line:     20
severity: high
command:  /ds-audit
class:    sagas/compensation-cancelled-context
detector: workflow-scan §5
anchor:   _ = workflow.ExecuteActivity(ctx, RefundCodFee, collectionID).Get(ctx, nil)
match:    Disconnected|cancel|context|Refund|compensat
```

When the workflow is cancelled, `ctx` is already cancelled, so the deferred `RefundCodFee` is never scheduled and the error is discarded — the customer keeps paying a fee for a failed delivery. Grep 5c. Fix: `newCtx, _ := workflow.NewDisconnectedContext(ctx)` for the compensation, and handle its error. Proof: V322 with cancellation.

## DS-WF-05c — Carrier booking compensation registered after the call returns

```defect
id:       DS-WF-05c
file:     apps/api/src/sagas/order-placement.saga.ts
line:     37
severity: medium
command:  /ds-audit
class:    sagas/compensation-registered-late
detector: workflow-scan §5
anchor:   const booking = await this.carrier.book(order.id, order.parcels);
match:    regist|after|compensat|timeout|book
```

`book` can succeed at the carrier and then time out here (20 s), and the cancel is never registered, so the booking survives the saga's rollback. Grep 5d. Fix: register a cancel by order reference before the call (as the pick-wave step does). Proof: V322 ambiguous-failure variant.

## DS-WF-06a — `@Saga()` drives a refund command from memory

```defect
id:       DS-WF-06a
file:     apps/api/src/sagas/refund.sagas.ts
line:     17
severity: high
command:  /ds-audit
class:    sagas/in-memory-saga
detector: workflow-scan §6
anchor:   @Saga()
match:    @Saga|memory|persist|refund|crash
```

The @nestjs/cqrs saga lives in process memory: an api restart between `ShipmentLostEvent` and the command loses the refund, and nothing records that one was owed (security `logic-race-scan` corroborates: money). Grep 6a. Fix: a persisted process manager or an outbox-driven consumer with a reserve. Proof: V322.

## DS-WF-06b — Bay release compensation decrements a counter with no `(sagaId, step)` reserve

```defect
id:       DS-WF-06b
file:     apps/api/src/sagas/consolidation.saga.ts
line:     19
severity: medium
command:  /ds-audit
class:    sagas/compensation-not-idempotent
detector: workflow-scan §6
anchor:   compensations.unshift(() => this.wms.releaseBay(bayId));
match:    idempot|releaseBay|decrement|compensat|saga
```

Registered before `occupyBay`, the compensation runs even when the occupy never happened, and `decrement-in-use` is not idempotent, so a retried rollback drives the zone's occupied-bay count below the truth. Grep 6c. Fix: release by consolidation id (`DELETE bay occupancy WHERE consolidation_id = …`) or a `(sagaId, step)` reserve. Proof: V322.

## DS-EC-01a — Proto field number 3 reused (`vehicle_id` string → `eta_minutes` int32)

```defect
id:       DS-EC-01a
file:     schemas/proto/acme/dispatch/v1/courier_assigned.proto
line:     9
severity: high
command:  /ds-audit
class:    contracts/breaking-change
detector: event-contract-scan §1
anchor:   int32 eta_minutes = 3;
match:    field number|reuse|buf|breaking|3
```

Against the base copy, field 3 changes name and type; old readers decode `eta_minutes` bytes as `vehicle_id` and stored events misread under the new schema. `buf breaking` exits 100 (SZ1). Fix: `reserved 3; reserved "vehicle_id";` and a new number. Proof: V323 — `buf breaking schemas/proto --against <base>`.

## DS-EC-01b — AsyncAPI payload gains a required `fulfilmentCenterId`

```defect
id:       DS-EC-01b
file:     schemas/asyncapi/orders.asyncapi.yaml
line:     26
severity: high
command:  /ds-audit
class:    contracts/breaking-change
detector: event-contract-scan §1
anchor:   required: [type, orderId, merchantId, placedAt, fulfilmentCenterId]
match:    required|fulfilmentCenterId|unclassified|breaking|json-schema-diff
```

Events already in `orders.placed` (and the producer, which never sends the field) fail readers validating against the new payload. `asyncapi diff -t breaking` exits 0 on this change — payload changes are `unclassified` (SZ4) — so the evidence is the non-zero unclassified-change count (24 here) and a `json-schema-diff` of the extracted payload (backward: exit 1, "Breaking changes found"). The document's `info.version` was not bumped; had it been, `-t breaking` would exit 1 on the version edit alone (measured below), not on the payload. Fix: add the field as optional, or version the message. Proof: V323 on the payload schema.

## DS-EC-02a — `JSON.parse(…) as OrderEvent` with no validation

```defect
id:       DS-EC-02a
file:     apps/worker/src/consumers/order-events.consumer.ts
line:     20
severity: medium
command:  /ds-audit
class:    contracts/unvalidated-payload
detector: event-contract-scan §2
anchor:   evt = JSON.parse(message.value!.toString()) as OrderEvent;
match:    JSON\.parse|cast|valid|zod|schema
```

The cast checks nothing: a message with no `orderId` inserts a task with a null order, and one with an unknown `type` reaches `assertNever` (DS-EC-03a). Grep 2a/2b/2c. Fix: a zod schema for the union, invalid → `deadLetter`. Proof: V324.

## DS-EC-02b — `json.loads(body)` straight into `Invoice.objects.create(**data)`

```defect
id:       DS-EC-02b
file:     services/billing-py/billing/tasks_ingest.py
line:     11
severity: medium
command:  /ds-audit
class:    contracts/unvalidated-payload
detector: event-contract-scan §2
anchor:   data = json.loads(body)
match:    json\.loads|valid|model|\*\*data|schema
```

Any key the carrier sends becomes a model kwarg: an unknown field raises `TypeError` and the task fails (Celery retries nothing), a renamed one persists an invoice with defaults. Grep 2a/2b. Fix: a pydantic model (or a form) with an explicit field list. Proof: V324.

## DS-EC-03a — `default: assertNever(evt)` on a topic another service extends

```defect
id:       DS-EC-03a
file:     apps/worker/src/consumers/order-events.consumer.ts
line:     38
severity: high
command:  /ds-audit
class:    contracts/intolerant-reader
detector: event-contract-scan §3
anchor:   default: return assertNever(evt);
match:    assertNever|unknown|tolerant|new event type|crash
```

apps/api deploys independently of the worker; the first new order event type (an `OrderAmended`) throws here, and kafkajs's `restartOnFailure` loops the partition, stopping every later order's fulfilment task. Grep 3a. Fix: ignore (and count) unknown types. Proof: V324 tolerant-reader fixture.

## DS-EC-03b — Plain `new ObjectMapper()` in a Kafka listener

```defect
id:       DS-EC-03b
file:     services/ledger-jvm/src/main/java/com/acme/ledger/kafka/ShipmentCostListener.java
line:     17
severity: high
command:  /ds-audit
class:    contracts/intolerant-reader
detector: event-contract-scan §3
anchor:   private final ObjectMapper mapper = new ObjectMapper();
match:    ObjectMapper|FAIL_ON_UNKNOWN|unknown|tolerant
```

A bare ObjectMapper fails on unknown properties (SZ6); the first field dispatch-go adds to `shipment.costs` makes every cost fail to deserialize and, with the default error handler, be skipped. Grep 3b. Fix: inject Spring's configured mapper or `FAIL_ON_UNKNOWN_PROPERTIES=false`. Proof: V324.

## DS-EC-04a — `amount` switched from minor to major units with the same type

```defect
id:       DS-EC-04a
file:     apps/api/src/invoices/invoice-events.ts
line:     17
severity: high
command:  /ds-audit
class:    contracts/semantic-change
detector: event-contract-scan §4
anchor:   amount: invoice.totalMinor / 100,
match:    minor|major|units|amount|/ ?100|semantic
```

Against the base copy, `amount` was `totalMinor`; it is now `totalMinor / 100`, and the schema's description changed from minor to major units while the type stayed `number` — `json-schema-diff` passes and the ERP export and the ledger book invoices 100× too small. Grep 4 (diff lines). Fix: a new field (`amountMajor`) or a new event version with an upcaster. Proof: V324 replay-old-events corpus.

## DS-EC-04b — `durationS` now carries milliseconds

```defect
id:       DS-EC-04b
file:     apps/worker/src/routing/route-events.producer.ts
line:     19
severity: high
command:  /ds-audit
class:    contracts/semantic-change
detector: event-contract-scan §4
anchor:   durationS: Date.now() - startedAt,
match:    durationS|ms|millis|seconds|unit|semantic
```

The base copy rounds to seconds; the head sends milliseconds in a field named for seconds, so ledger-jvm pays couriers for 1 000× the route time. Grep 4 (the removed `Math.round(… / 1000)` line). Fix: keep seconds, or add `durationMs` and deprecate. Proof: V324.

## DS-EC-05a — `order.placed` subscribed where three files use `orders.placed`

```defect
id:       DS-EC-05a
file:     apps/api/src/milestones/milestones.consumer.ts
line:     21
severity: medium
command:  /ds-audit
class:    contracts/name-drift
detector: event-contract-scan §5
anchor:   await consumer.subscribe({ topics: ['order.placed'] });
match:    order\.placed|orders\.placed|name|topic|twin
```

The producer and two consumers use `orders.placed`; this consumer subscribes to the near-twin `order.placed`, which nothing produces, so merchant milestones silently stop counting. Grep 5a (near-twin). Fix: a shared topic constant. Proof: V324.

## DS-EC-05b — `returns.approved` consumed but produced nowhere

```defect
id:       DS-EC-05b
file:     apps/worker/src/consumers/returns-approved.consumer.ts
line:     17
severity: medium
command:  /ds-audit
class:    contracts/consumed-never-produced
detector: event-contract-scan §5
anchor:   await consumer.subscribe({ topics: ['returns.approved'] });
match:    returns\.approved|never produced|producer|topic
```

apps/api approves returns by enqueuing a BullMQ label job; nothing publishes `returns.approved`, so return pickups are never booked from this consumer. Grep 5b. Fix: publish the event from `ApproveReturn` (through the outbox) or remove the consumer. Proof: V324.

## DS-EC-06a — KurrentDB append after a read-decide with the default `ANY`

```defect
id:       DS-EC-06a
file:     apps/api/src/orders/order-aggregate.store.ts
line:     25
severity: high
command:  /ds-audit
class:    eventsourcing/append-without-expected-version
detector: event-contract-scan §6
anchor:   await this.client.appendToStream(stream, events);
match:    expected|revision|streamState|ANY|append
```

The command decides from the loaded stream and appends with no expected revision (EV1: Node defaults to `ANY`), so two concurrent commands both pass `assertCancellable`/`ship` checks and both append. Grep 6a. Fix: `{ streamState: <revision read> }` and retry on `WrongExpectedVersion`. Proof: V325.

## DS-EC-06b — Marten `Append` after `AggregateStreamAsync` (no expected version)

```defect
id:       DS-EC-06b
file:     services/notify-dotnet/src/Notify.Api/Preferences/SubscriberPreferencesService.cs
line:     28
severity: high
command:  /ds-audit
class:    eventsourcing/append-without-expected-version
detector: event-contract-scan §6
anchor:   session.Events.Append(subscriberId, new PreferenceChanged(subscriberId, channel, enabled));
match:    Append|FetchForWriting|expected|version|Marten
```

A concurrent opt-out and opt-in both read the same state and both append; the order they land decides the subscriber's consent, which regulators require never to be lost (EV3). Grep S6 (stacks.md). Fix: `FetchForWriting<SubscriberPreferences>` then append through the returned stream. Proof: V325.

## DS-EC-07a — `order_events` with `stream_id, version` and no UNIQUE(stream_id, version)

```defect
id:       DS-EC-07a
file:     apps/api/db/migrations/0007_order_events.sql
line:     2
severity: high
command:  /ds-audit
class:    eventsourcing/no-stream-uniqueness
detector: event-contract-scan §7
anchor:   CREATE TABLE order_events (
match:    UNIQUE|stream|version|duplicate
```

`B2bOrderEvents.append` writes `expectedVersion + 1` with nothing enforcing it: two importers can both write version n+1 of one stream. The index is not unique. Grep 7a. Fix: `UNIQUE (stream_id, version)`. Proof: V325.

## DS-EC-07b — Prisma `ReturnEvent` without `@@unique([streamId, version])`

```defect
id:       DS-EC-07b
file:     packages/event-log/prisma/schema.prisma
line:     11
severity: high
command:  /ds-audit
class:    eventsourcing/no-stream-uniqueness
detector: event-contract-scan §7
anchor:   model ReturnEvent {
match:    @@unique|stream|version|Prisma|duplicate
```

`appendReturnEvent` writes `readVersion + 1`; only `@@index` covers the pair, so concurrent appends both succeed. Grep 7c. Fix: `@@unique([streamId, version])`. Proof: V325.

## DS-EC-08a — Projection increments, checkpoint saved in a separate statement

```defect
id:       DS-EC-08a
file:     apps/worker/src/projections/courier-stats.projector.ts
line:     18
severity: high
command:  /ds-audit
class:    eventsourcing/projection-not-idempotent
detector: event-contract-scan §8
anchor:   await this.pool.query('UPDATE courier_stats SET deliveries = deliveries + 1 WHERE courier_id = $1', [evt.data.courierId]);
match:    \+ ?1|increment|checkpoint|idempot|transaction
```

A crash between the increment and `checkpoints.save` replays the event and counts the delivery twice; the leaderboard drives courier bonuses. Grep 8a. Fix: one transaction for the effect and the checkpoint, or record the applied position per courier. Proof: V326.

## DS-EC-08b — Checkpoint saved before the projection writes

```defect
id:       DS-EC-08b
file:     apps/worker/src/projections/order-summary.projector.ts
line:     19
severity: medium
command:  /ds-audit
class:    eventsourcing/checkpoint-before-write
detector: event-contract-scan §8
anchor:   await this.checkpoints.save('order-summary', events[events.length - 1].position);
match:    checkpoint|before|lost|projection
```

The position advances first; a crash mid-loop leaves the rest of the batch never applied — the admin order list keeps a stale status. Grep 8a. Fix: write the rows and the checkpoint in one transaction, checkpoint last. Proof: V326.

## DS-EC-09a — `onOrderShipped` sends an e-mail during apply

```defect
id:       DS-EC-09a
file:     apps/api/src/orders/order.aggregate.ts
line:     41
severity: high
command:  /ds-audit
class:    eventsourcing/side-effect-in-apply
detector: event-contract-scan §9
anchor:   this.mailer.sendShippedEmail(event.customerEmail, event.trackingNo);
match:    apply|replay|email|side effect|loadFromHistory
```

`loadFromHistory` replays every event through the `on…` handlers on each command, so every later command on a shipped order re-sends the "shipped" e-mail. Grep 9a. Fix: state changes only in `on…`; send from a subscriber of the committed event. Proof: V326 — rebuild the aggregate: 0 e-mails after the fix.

## DS-EC-09b — Snapshots stored with no stream version or schema version

```defect
id:       DS-EC-09b
file:     apps/api/src/orders/order-snapshots.ts
line:     10
severity: medium
command:  /ds-audit
class:    eventsourcing/snapshot-without-version
detector: event-contract-scan §9
anchor:   async saveSnapshot(order: OrderAggregate): Promise<void> {
match:    snapshot|version|schema|stream
```

`order_snapshots` keeps only the state: a load cannot tell which events the snapshot already contains (it replays from the start or skips), and a change to the aggregate's state shape reads old snapshots wrongly. Grep 9b. Fix: store the stream revision and a schema version, and discard on mismatch. Proof: V326.

## DS-EC-10a — Bulk cancel → 303 to a list read from the async projection

```defect
id:       DS-EC-10a
file:     apps/api/src/orders/orders-admin.controller.ts
line:     17
severity: medium
command:  /ds-audit
class:    eventsourcing/read-model-lag
detector: event-contract-scan §10
anchor:   return reply.redirect('/admin/orders?cancelled=1', 303);
match:    303|redirect|projection|stale|read model
```

The redirect lands on `/admin/orders`, served from `order_summary`, which the worker projects asynchronously: the admin sees the orders still live and cancels again. Grep 10a. Fix: return the stream positions and wait for the projection, or show the result from the write side. Proof: V327.

## DS-EC-10b — Route action places an order, then redirects to a loader that reads the projection

```defect
id:       DS-EC-10b
file:     apps/web/src/routes/orders.new.tsx
line:     12
severity: medium
command:  /ds-audit
class:    eventsourcing/read-model-lag
detector: event-contract-scan §10
anchor:   return redirect('/orders');
match:    redirect|projection|stale|read model|loader
```

The `/orders` loader reads `/orders/summary` (the projected read model), so the order the merchant just placed is missing on the page they land on. Grep 10b. Fix: redirect to the new order's write-side page, or wait for the projection position. Proof: V327.

## DS-HO-DB-a — Enqueue inside `em.transactional` (phantom job)

```defect
id:       DS-HO-DB-a
file:     apps/api/src/invoices/issue-invoice.usecase.ts
line:     18
severity: high
command:  /db-audit
class:    database/enqueue-inside-transaction
detector: transaction-scan §1 (database)
anchor:   await this.invoiceQueue.add('render-invoice-pdf', { invoiceId: invoice.id });
match:    transaction|enqueue|phantom|commit|inside
```

The job is in Redis before the invoice's `issued` status commits: the processor can load it as `draft` (or find nothing after a rollback). Owner: database `transaction-scan` §1 (V8); `/ds-audit` lists it routed. Fix: enqueue after commit through the outbox port.

## DS-HO-DB-b — Return-label job enqueued inside `em.transactional`

```defect
id:       DS-HO-DB-b
file:     apps/api/src/returns/approve-return.usecase.ts
line:     19
severity: high
command:  /db-audit
class:    database/enqueue-inside-transaction
detector: transaction-scan §1 (database)
anchor:   await this.labelsQueue.add('book-return-label', { returnId: request.id, carrier: request.carrier });
match:    transaction|enqueue|phantom|commit|inside
```

Same shape: a rollback after the add leaves a label booked for a return that was never approved. Owner: database `transaction-scan` §1 (V8).

## DS-HO-DB-c — Outbox claim `FOR UPDATE` without `SKIP LOCKED`, held across the Kafka sends

```defect
id:       DS-HO-DB-c
file:     apps/worker/src/outbox/ledger-outbox.relay.ts
line:     21
severity: high
command:  /db-audit
class:    database/claim-without-skip-locked
detector: transaction-scan §5 (database)
anchor:   'SELECT id, topic, payload FROM ledger_outbox_rows WHERE sent_at IS NULL ORDER BY id LIMIT 100 FOR UPDATE',
match:    SKIP LOCKED|FOR UPDATE|claim|relay|lock
```

Both worker replicas run the relay; the second blocks on the first's row locks for the whole batch of sends, and the locks are held across network I/O (transaction-scan §1 corroborates). Owner: database `transaction-scan` §5. Fix: `FOR UPDATE SKIP LOCKED` in a short claim transaction, publish outside it.

## DS-HO-DB-d — Saga rewrites `status` read before a remote call (lost update)

```defect
id:       DS-HO-DB-d
file:     apps/api/src/sagas/order-amend.saga.ts
line:     26
severity: high
command:  /db-audit
class:    database/lost-update
detector: transaction-scan §8 (database)
anchor:   order.status = 'placed';
match:    lost update|status|version|optimistic|overwrite
```

The order is read, the WMS call takes seconds, and the flush writes `status = 'placed'` over the warehouse's `picking` set in between — no version column on `Order`. Owner: database `transaction-scan` §8 (V5). Fix: a version column or `UPDATE … WHERE status = 'placed'`.

## DS-HO-SEC-a — OCR credits debited with a clamp after the work (read-modify-write)

```defect
id:       DS-HO-SEC-a
file:     apps/api/src/label-ocr/ocr-credits.service.ts
line:     15
severity: high
command:  /security-audit
class:    security/clamped-debit
detector: logic-race-scan §5 (security)
anchor:   account.ocrCredits = Math.max(0, account.ocrCredits - pages);
match:    clamp|Math\.max|credit|debit|check.then.act|race
```

Concurrent scans read the same balance and both write; the clamp hides the overspend at 0. Owner: security `logic-race-scan` §5 (grep 8c). Fix: `UPDATE … SET credits = credits - $1 WHERE credits >= $1` before the model call.

## DS-HO-SEC-b — COD payout transfer with no reserve and no idempotency key

```defect
id:       DS-HO-SEC-b
file:     apps/worker/src/jobs/cod-payout.processor.ts
line:     25
severity: critical
command:  /security-audit
class:    security/money-consumer-no-reserve
detector: logic-race-scan §4 (security)
anchor:   await this.psp.transfer({ merchantId: job.data.merchantId
match:    idempot|transfer|reserve|duplicate|payout
```

A stalled re-run (BQ2) or a re-enqueue pays the merchant twice; the PSP call carries no key. Owner: security `logic-race-scan` §4, with the stall mechanism from `messaging-scan` §2 as evidence. Fix: a payout reserve keyed `(merchantId, day)` and the same value as the PSP idempotency key.

## DS-HO-SEC-c — PSP charge key minted inside the job body (new key per attempt)

```defect
id:       DS-HO-SEC-c
file:     apps/worker/src/jobs/customs-duty-charge.processor.ts
line:     29
severity: critical
command:  /security-audit
class:    security/psp-key-per-retry
detector: logic-race-scan §4 (security)
anchor:   const idempotencyKey = randomUUID();
match:    idempot|randomUUID|key|charge|retry
```

Jobs run with attempts 5: each attempt mints a fresh key, so a charge whose response was lost is charged again on the retry. Owner: security `logic-race-scan` §4 (`retry-deadline-scan` §5 grep 5e corroborates). Fix: key from `shipmentId`.

## DS-HO-PERF-a — Merchant crons registered in every api replica via `SchedulerRegistry.addCronJob` (HPA min 3)

```defect
id:       DS-HO-PERF-a
file:     apps/api/src/scheduling/cron-explorer.ts
line:     27
severity: high
command:  /perf-audit
class:    performance/once-per-fleet-per-replica
detector: request-path-scan §20 (performance)
anchor:   this.registry.addCronJob(`${wrapper.name}.${method}`, job);
match:    SchedulerRegistry|addCronJob|replica|fleet|HPA
```

Every api pod (3–12 under the HPA) registers and runs each merchant export, so exports run 3–12 times a night. Owner: performance `request-path-scan` §20 (V40; the explorer shape is IR-2 of the batch-5 eval).

## DS-HO-PERF-b — MikroORM `getMigrator().up()` at boot on 3 replicas

```defect
id:       DS-HO-PERF-b
file:     apps/api/src/main.ts
line:     13
severity: high
command:  /perf-audit
class:    performance/migrate-at-boot
detector: request-path-scan §20 (performance)
anchor:   await orm.getMigrator().up();
match:    migrat|boot|replica|getMigrator|lock
```

Each api replica migrates on start; MikroORM's migrator takes no lock, so a rollout runs the migrations concurrently (precedents/performance § 77). Owner: performance `request-path-scan` §20 (V40).

## DS-HO-PERF-c — In-flight `Set` used as a lock around the courier SMS (per replica)

```defect
id:       DS-HO-PERF-c
file:     apps/api/src/couriers/courier-sms.throttle.ts
line:     10
severity: medium
command:  /perf-audit
class:    performance/per-replica-lock
detector: request-path-scan §18 (performance)
anchor:   private readonly inFlight = new Set<string>();
match:    replica|in.?memory|Set|lock|per.process
```

The set lives in one api process; the other replicas send the same stop SMS. Owner: performance `request-path-scan` §18 (V38). Fix: a shared reserve keyed `(courierId, stopId)`.

## DS-HO-PERF-d — Tracking-ingest capacity below the arrival rate

```defect
id:       DS-HO-PERF-d
file:     apps/worker/src/jobs/tracking-ingest.processor.ts
line:     15
severity: high
command:  /perf-audit
class:    performance/worker-capacity
detector: request-path-scan §23 (performance)
anchor:   @Processor('tracking-ingest', { concurrency: 2 })
match:    capacity|concurrency|arrival|λ|lambda|throughput|KEDA
```

2 pods (KEDA max 2) × concurrency 2 / 0.3 s ≈ 13 jobs/s against a 40/s peak (deploy/capacity/tracking-ingest.yaml): the queue grows all afternoon. Owner: performance `request-path-scan` §23 (V43).

## DS-HO-INF-a — Lambda SQS source with visibility 60 s against a 30 s function timeout

```defect
id:       DS-HO-INF-a
file:     deploy/terraform/lambda-returns.tf
line:     9
severity: high
command:  /infra-audit
class:    infrastructure/sqs-lambda-visibility
detector: serverless-reliability-scan §2 (infrastructure)
anchor:   visibility_timeout_seconds = 60
match:    visibility|timeout|6|Lambda|SQS
```

AWS recommends visibility ≥ 6 × the function timeout (180 s); at 60 s, batches retried with back-off reappear while still in flight. Owner: infrastructure `serverless-reliability-scan` §2 (SLS-02, V255).

## DS-HO-INF-b — Event source mapping with batch 10 and no `ReportBatchItemFailures`

```defect
id:       DS-HO-INF-b
file:     deploy/terraform/lambda-returns.tf
line:     30
severity: high
command:  /infra-audit
class:    infrastructure/partial-batch-response
detector: serverless-reliability-scan §4 (infrastructure)
anchor:   batch_size                         = 10
match:    ReportBatchItemFailures|partial|batch|function_response_types
```

One failed label re-delivers the whole batch of 10, re-rendering nine labels. Owner: infrastructure `serverless-reliability-scan` §4 (SLS-04, V257).

## DS-HO-OBS-a — The `notify` BullMQ connection has no telemetry: the push hop drops trace context

```defect
id:       DS-HO-OBS-a
file:     apps/api/src/notifications/notifications.module.ts
line:     8
severity: medium
command:  /obs-audit
class:    observability/queue-hop-no-propagation
detector: trace-propagation-scan §2 (observability)
anchor:   BullModule.forRoot('notify', {
match:    trace|traceparent|telemetry|propagat|BullMQOtel
```

The job Redis connection sets `telemetry: new BullMQOtel(…)`; the `notify` connection does not, so every push job starts a new trace. Owner: observability `trace-propagation-scan` §2 (TR-02, V194).

## DS-HO-BE-a — `@Interval(60_000)` handler that runs 70–110 s

```defect
id:       DS-HO-BE-a
file:     apps/worker/src/schedules/eta-recompute.cron.ts
line:     19
severity: medium
command:  /backend-audit
class:    backend/schedule-self-overlap
detector: job-lifecycle-scan §4 (backend)
anchor:   @Interval(60_000)
match:    overlap|Interval|running|guard|70
```

setInterval fires the next pass while the previous one still runs on the same process; passes pile up and race on `eta_version`. Owner: backend `job-lifecycle-scan` §4 (single process; coordination-scan keeps the fleet half). Fix: a running flag or a self-rescheduling timeout.

## DS-HO-BE-b — Pickup cut-off at 01:30 America/Chicago on the single scheduler pod

```defect
id:       DS-HO-BE-b
file:     apps/worker/src/schedules/carrier-cutoff.cron.ts
line:     13
severity: medium
command:  /backend-audit
class:    backend/schedule-zone-dst
detector: job-lifecycle-scan §6 (backend)
anchor:   @Cron('0 30 1 * * *', { timeZone: 'America/Chicago' })
match:    DST|01:30|Chicago|zone|twice
```

01:30 occurs twice on the November transition and the second run closes the next day's early requests. Owner: backend `job-lifecycle-scan` §6 (one schedule's own zone; the scheduler pod is single-replica, so `coordination-scan` §11 does not own it).

## Decoys — must NOT be reported

Each decoy is the correct sibling of a seeded shape, built from the eval's decoy column (§ 3.7) and its two additions,
with the precedent that clears it (`templates/snippets/precedents/distributed.md`). A finding that names the decoy's file,
cites a line within the tolerance window and matches every one of its `match:` patterns is **pinned** to it and reported
as `DECOYS FLAGGED k/N` (`score.py`, § DECOYS). Every decoy sits at least 15 lines from every defect in its file
(`--verify` enforces more than 12). DS-DECOY-09 is the precedent-34 case: a comment claims `noeviction` beside a managed
Valkey with no parameter group, so the row is Unconfirmed (`UNREAD`), never a Finding.

| id | file:line | looks like | why it is safe |
|----|-----------|-----------|----------------|
| DS-DECOY-01 | `apps/worker/src/consumers/shipments.consumer.ts:23` | DS-MQ-01a | kafkajs auto-commit with a fully awaited handler is at-least-once (precedent 1) |
| DS-DECOY-02 | `apps/worker/src/consumers/shipments.consumer.ts:37` | DS-MQ-02a | upsert by the business key is naturally idempotent (precedent 2) |
| DS-DECOY-03 | `apps/worker/src/consumers/delivery-attempts.consumer.ts:31` | DS-MQ-02a | the claim is a coordination aid; the effect is an anti-join on event_id (precedent 2, amended) |
| DS-DECOY-04 | `apps/worker/src/consumers/carrier-webhooks.consumer.ts:37` | DS-MQ-03a | bounded by x-death to a TTL retry queue, then parked (precedent 7) |
| DS-DECOY-05 | `apps/worker/src/jobs/base.processor.ts:33` | DS-MQ-03c | the catch is the best-effort report after the job is already in the failed set (the real-repo shape) |
| DS-DECOY-06 | `apps/worker/src/jobs/newsletter.processor.ts:16` | DS-MQ-04a | independent, commutative jobs; the provider dedupes (precedent 8) |
| DS-DECOY-07 | `apps/worker/src/jobs/with-deadline.ts:16` | DS-MQ-06a | the deadline aborts the attempt through the signal every client takes (precedent 36) |
| DS-DECOY-08 | `apps/api/src/telemetry/usage-ping.ts:14` | DS-MQ-07a | telemetry with a written loss budget (ADR-0012, precedent 6) |
| DS-DECOY-09 | `apps/api/src/redis/notify-redis.ts:7` | DS-MQ-08a | managed Valkey with no parameter group: the policy is UNREAD, the row is Unconfirmed, never a Finding (precedent 34) |
| DS-DECOY-10 | `apps/api/package.json:34` | DS-MQ-11b | kafkajs unmaintained is a migration note, never a row (KJ1) |
| DS-DECOY-11 | `apps/api/src/shipments/create-shipment.usecase.ts:19` | DS-DW-01a | the outbox port inside TxRunner.run (precedent 11) |
| DS-DECOY-12 | `apps/api/src/exports/request-export.usecase.ts:21` | DS-DW-01a | graphile-worker job in the same transaction on the same connection: the queue is the outbox (OX7, precedent 11) |
| DS-DECOY-13 | `apps/api/src/catalog/reprice.usecase.ts:22` | DS-DW-02a | an intent the consumer re-verifies against the source (precedent 10) |
| DS-DECOY-14 | `apps/api/src/outbox/live-updates.relay.ts:27` | DS-CO-04a | advisory websocket push re-polled every 30 s (precedent 19, amended) |
| DS-DECOY-15 | `apps/worker/src/consumers/courier-ratings.consumer.ts:26` | DS-DW-04a | the effect row carries the event id under a unique key (precedent 2, amended) |
| DS-DECOY-16 | `deploy/debezium/ledger-outbox-connector.json:15` | DS-DW-05a | default router on an insert-only outbox (ledger-jvm only inserts) |
| DS-DECOY-17 | `apps/worker/src/sync/outbox-feed.cursor.ts:31` | DS-DW-06b | floor held back by a lag on the database clock plus an hourly rescan (Hardening at most, precedent 13) |
| DS-DECOY-18 | `apps/api/src/storage/s3.client.ts:7` | DS-RT-01b | AWS SDK standard mode classifies retryable errors itself (precedent 15) |
| DS-DECOY-19 | `apps/api/src/realtime/ws-upstream.ts:22` | DS-RT-02a | a jittered, capped reconnect loop on a long-lived connection is not a retry (precedent 16) |
| DS-DECOY-20 | `apps/api/src/http/outbound-client.ts:18` | DS-RT-03b | full jitter with a cap (the real-repo shape) |
| DS-DECOY-21 | `apps/worker/src/clients/eta.client.ts:13` | DS-RT-04a | one retrying layer: the job; the client makes one attempt |
| DS-DECOY-22 | `apps/api/src/carriers/ups.client.ts:15` | DS-RT-05a | UPS stores the transId/idempotency key, stable per shipment (precedent 17) |
| DS-DECOY-23 | `apps/api/src/reports/report-request.controller.ts:16` | DS-RT-07b | a report built late is still correct (precedent 18) |
| DS-DECOY-24 | `apps/api/src/locks/leader-lock.ts:32` | DS-CO-01a | Lua compare-and-delete release (precedent 21) |
| DS-DECOY-25 | `apps/api/src/locks/leader-lock.ts:18` | DS-CO-02a | PX before NX on one command: the TTL is set atomically (the P12 trap) |
| DS-DECOY-26 | `apps/api/src/reports/weekly-digest.job.ts:19` | DS-CO-03b | the acquire result is checked before the first effect |
| DS-DECOY-27 | `apps/worker/src/sync/catalog-mirror.worker.ts:23` | DS-CO-04a | the per-item `if (!(await this.lease.extend())) return` below backstops the dropped renewal (the real-repo shape) |
| DS-DECOY-28 | `apps/api/src/catalog/sku-allocator.ts:12` | DS-CO-05a | transaction-scoped advisory lock inside the transaction that does the work (precedent 20) |
| DS-DECOY-29 | `services/dispatch-go/internal/leader/tariffs.go:30` | DS-CO-06a | the process exits on loss; the work runs under the leader context |
| DS-DECOY-30 | `apps/api/scripts/backfill-eta.ts:12` | DS-CO-07a | a one-off CLI timing log (precedent 31) |
| DS-DECOY-31 | `apps/api/src/scheduling/report-leases.repo.ts:12` | DS-CO-08a | written and compared on the database clock only |
| DS-DECOY-32 | `apps/api/src/couriers/courier-presence.ts:20` | DS-CO-09a | display-only "last seen" (precedent 31) |
| DS-DECOY-33 | `apps/worker/src/schedules/housekeeping.cron.ts:23` | DS-CO-11a | the scheduler pod runs in UTC: no TZ in the image or the manifests (precedent 35) |
| DS-DECOY-34 | `apps/workflows-ts/src/workflows/backorder.workflow.ts:14` | DS-WF-01b | Date.now() in a TypeScript workflow is deterministic under the sandbox (precedent 25) |
| DS-DECOY-35 | `apps/workflows-ts/src/workflows/loyalty-tier.workflow.ts:7` | DS-WF-02a | a brand-new workflow type has no open executions |
| DS-DECOY-36 | `services/ledger-jvm/src/main/java/com/acme/ledger/saga/RemittanceSaga.java:22` | DS-WF-04b | the pivot step, last, after every compensatable step (precedent 26) |
| DS-DECOY-37 | `services/ledger-jvm/src/main/java/com/acme/ledger/workflow/ReturnsWorkflowImpl.java:21` | DS-WF-05a | Temporal Java Saga defaults compensate in reverse, registered before each call (precedent 27) |
| DS-DECOY-38 | `schemas/avro/shipment_delivered.avsc:9` | DS-EC-01a | an Avro field added with a default is compatible both ways (precedent 28) |
| DS-DECOY-39 | `apps/worker/src/consumers/carrier-scans.consumer.ts:25` | DS-EC-02a | validated by `CarrierScan.safeParse(raw)` on the next line |
| DS-DECOY-40 | `apps/api/src/webhooks/merchant-webhook.dto.ts:14` | DS-EC-03b | a strict schema on an OUTBOUND payload (precedent 28) |
| DS-DECOY-41 | `apps/worker/test/consumers.e2e-spec.ts:10` | DS-EC-05a | a name used only in a test |
| DS-DECOY-42 | `apps/api/src/audit/audit-trail.ts:14` | DS-EC-06a | append-only audit stream; nothing is decided from its state (precedent 29) |
| DS-DECOY-43 | `services/notify-dotnet/src/Notify.Api/Preferences/MartenSetup.cs:10` | DS-EC-07a | Marten's own event store owns stream uniqueness (precedent 30) |
| DS-DECOY-44 | `apps/worker/src/projections/daily-volume.projector.ts:25` | DS-EC-08a | rebuild-and-swap: a crash leaves the old table serving, a rerun starts over |
| DS-DECOY-45 | `apps/web/src/routes/returns.new.tsx:11` | DS-EC-10b | the landing page's loader reads the write side |
| DS-DECOY-46 | `deploy/k8s/worker-scheduler.yaml:9` | DS-HO-PERF-a | the scheduler role is one pod by design with Recreate (precedent 23) |

```decoy
id:       DS-DECOY-01
file:     apps/worker/src/consumers/shipments.consumer.ts
line:     23
command:  /ds-audit
class:    decoy/DS-MQ-01a
anchor:   eachMessage: async ({ topic, message }) => {
match:    ack|commit|await|eachMessage
```
```decoy
id:       DS-DECOY-02
file:     apps/worker/src/consumers/shipments.consumer.ts
line:     37
command:  /ds-audit
class:    decoy/DS-MQ-02a
anchor:   await em.upsert(Shipment, { id: evt.shipmentId, orderId: evt.orderId, carrier: evt.carrier });
match:    idempot|reserve|dedup|duplicat
```
```decoy
id:       DS-DECOY-03
file:     apps/worker/src/consumers/delivery-attempts.consumer.ts
line:     31
command:  /ds-audit
class:    decoy/DS-MQ-02a
anchor:   await this.claims.reserve(evt.eventId, 'delivery-attempts');
match:    idempot|reserve|claim|atomic|dedup
```
```decoy
id:       DS-DECOY-04
file:     apps/worker/src/consumers/carrier-webhooks.consumer.ts
line:     37
command:  /ds-audit
class:    decoy/DS-MQ-03a
anchor:   this.channel.nack(msg, false, false);
match:    nack|requeue|loop|poison
```
```decoy
id:       DS-DECOY-05
file:     apps/worker/src/jobs/base.processor.ts
line:     33
command:  /ds-audit
class:    decoy/DS-MQ-03c
anchor:   } catch (reportErr) {
match:    catch|swallow|failed
```
```decoy
id:       DS-DECOY-06
file:     apps/worker/src/jobs/newsletter.processor.ts
line:     16
command:  /ds-audit
class:    decoy/DS-MQ-04a
anchor:   @Processor('newsletter', { concurrency: 10 })
match:    concurrency|order
```
```decoy
id:       DS-DECOY-07
file:     apps/worker/src/jobs/with-deadline.ts
line:     16
command:  /ds-audit
class:    decoy/DS-MQ-06a
anchor:   controller.abort(new DeadlineExceeded(ms));
match:    deadline|lock|abort|race
```
```decoy
id:       DS-DECOY-08
file:     apps/api/src/telemetry/usage-ping.ts
line:     14
command:  /ds-audit
class:    decoy/DS-MQ-07a
anchor:   void this.telemetryQueue.add('usage'
match:    void|await|fire|floating|lost
```
```decoy
id:       DS-DECOY-09
file:     apps/api/src/redis/notify-redis.ts
line:     7
command:  /ds-audit
class:    decoy/DS-MQ-08a
anchor:   maxmemory-policy is noeviction on this cluster
match:    maxmemory|evict|noeviction
```
```decoy
id:       DS-DECOY-10
file:     apps/api/package.json
line:     34
command:  /ds-audit
class:    decoy/DS-MQ-11b
anchor:   "kafkajs": "2.2.4"
match:    kafkajs|unmaintained|deprecat
```
```decoy
id:       DS-DECOY-11
file:     apps/api/src/shipments/create-shipment.usecase.ts
line:     19
command:  /ds-audit
class:    decoy/DS-DW-01a
anchor:   await this.outbox.emit('shipment.created'
match:    outbox|dual|commit|publish
```
```decoy
id:       DS-DECOY-12
file:     apps/api/src/exports/request-export.usecase.ts
line:     21
command:  /ds-audit
class:    decoy/DS-DW-01a
anchor:   await client.query('SELECT graphile_worker.add_job($1, $2::json)'
match:    enqueue|transaction|dual|outbox
```
```decoy
id:       DS-DECOY-13
file:     apps/api/src/catalog/reprice.usecase.ts
line:     22
command:  /ds-audit
class:    decoy/DS-DW-02a
anchor:   await this.kafka.send({ topic: 'quotes.refresh-requested'
match:    publish|commit|phantom|rollback
```
```decoy
id:       DS-DECOY-14
file:     apps/api/src/outbox/live-updates.relay.ts
line:     27
command:  /ds-audit
class:    decoy/DS-CO-04a
anchor:   await this.lease.extend();
match:    extend|lease|renew
```
```decoy
id:       DS-DECOY-15
file:     apps/worker/src/consumers/courier-ratings.consumer.ts
line:     26
command:  /ds-audit
class:    decoy/DS-DW-04a
anchor:   'INSERT INTO courier_ratings (event_id, courier_id, stars) VALUES (?, ?, ?) ON CONFLICT (event_id) DO NOTHING',
match:    inbox|reserve|atomic|dedup
```
```decoy
id:       DS-DECOY-16
file:     deploy/debezium/ledger-outbox-connector.json
line:     15
command:  /ds-audit
class:    decoy/DS-DW-05a
anchor:   "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter",
match:    op\.invalid|update|router|CDC
```
```decoy
id:       DS-DECOY-17
file:     apps/worker/src/sync/outbox-feed.cursor.ts
line:     31
command:  /ds-audit
class:    decoy/DS-DW-06b
anchor:   WHERE id > $1 AND created_at < now() - ($2 || ' milliseconds')::interval
match:    floor|cursor|gap|skip
```
```decoy
id:       DS-DECOY-18
file:     apps/api/src/storage/s3.client.ts
line:     7
command:  /ds-audit
class:    decoy/DS-RT-01b
anchor:   retryMode: 'standard'
match:    retry|classif|4xx
```
```decoy
id:       DS-DECOY-19
file:     apps/api/src/realtime/ws-upstream.ts
line:     22
command:  /ds-audit
class:    decoy/DS-RT-02a
anchor:   while (true) {
match:    retry|cap|forever|unbounded|loop
```
```decoy
id:       DS-DECOY-20
file:     apps/api/src/http/outbound-client.ts
line:     18
command:  /ds-audit
class:    decoy/DS-RT-03b
anchor:   export const backoffMs = (attempt: number): number =>
match:    jitter|backoff|constant
```
```decoy
id:       DS-DECOY-21
file:     apps/worker/src/clients/eta.client.ts
line:     13
command:  /ds-audit
class:    decoy/DS-RT-04a
anchor:   retry: { attempts: 1 }
match:    layer|multipl|attempts
```
```decoy
id:       DS-DECOY-22
file:     apps/api/src/carriers/ups.client.ts
line:     15
command:  /ds-audit
class:    decoy/DS-RT-05a
anchor:   method: 'POST',
match:    POST|idempot|duplicat|retry
```
```decoy
id:       DS-DECOY-23
file:     apps/api/src/reports/report-request.controller.ts
line:     16
command:  /ds-audit
class:    decoy/DS-RT-07b
anchor:   await this.reportsQueue.add('monthly-statement'
match:    expir|deadline|late
```
```decoy
id:       DS-DECOY-24
file:     apps/api/src/locks/leader-lock.ts
line:     32
command:  /ds-audit
class:    decoy/DS-CO-01a
anchor:   const released = await this.redis.eval(RELEASE, 1, key, token);
match:    del|owner|release
```
```decoy
id:       DS-DECOY-25
file:     apps/api/src/locks/leader-lock.ts
line:     18
command:  /ds-audit
class:    decoy/DS-CO-02a
anchor:   const ok = await this.redis.set(key, token, 'PX', ttlMs, 'NX');
match:    TTL|PX|NX|expire
```
```decoy
id:       DS-DECOY-26
file:     apps/api/src/reports/weekly-digest.job.ts
line:     19
command:  /ds-audit
class:    decoy/DS-CO-03b
anchor:   if (!acquired) return;
match:    acquire|result|ignored
```
```decoy
id:       DS-DECOY-27
file:     apps/worker/src/sync/catalog-mirror.worker.ts
line:     23
command:  /ds-audit
class:    decoy/DS-CO-04a
anchor:   await this.lease.extend();
match:    extend|lease|renew
```
```decoy
id:       DS-DECOY-28
file:     apps/api/src/catalog/sku-allocator.ts
line:     12
command:  /ds-audit
class:    decoy/DS-CO-05a
anchor:   await tx.execute('SELECT pg_advisory_xact_lock(hashtext(?))', [merchantId]);
match:    advisory|pool|session|pgbouncer
```
```decoy
id:       DS-DECOY-29
file:     services/dispatch-go/internal/leader/tariffs.go
line:     30
command:  /ds-audit
class:    decoy/DS-CO-06a
anchor:   log.Fatal("tariff loader: lost leadership
match:    leader|OnStoppedLeading|loss
```
```decoy
id:       DS-DECOY-30
file:     apps/api/scripts/backfill-eta.ts
line:     12
command:  /ds-audit
class:    decoy/DS-CO-07a
anchor:   console.log(`cleared ${rowCount} ETAs in ${Date.now() - started} ms
match:    Date\.now|wall|monotonic
```
```decoy
id:       DS-DECOY-31
file:     apps/api/src/scheduling/report-leases.repo.ts
line:     12
command:  /ds-audit
class:    decoy/DS-CO-08a
anchor:   WHERE report_id = ? AND (owner = ? OR lease_until < now()) RETURNING report_id
match:    clock|skew|now\(\)|expir
```
```decoy
id:       DS-DECOY-32
file:     apps/api/src/couriers/courier-presence.ts
line:     20
command:  /ds-audit
class:    decoy/DS-CO-09a
anchor:   if (ping.lastSeenAt > courier.lastSeenAt) courier.lastSeenAt = ping.lastSeenAt;
match:    last.write|clock|updatedAt|lastSeen
```
```decoy
id:       DS-DECOY-33
file:     apps/worker/src/schedules/housekeeping.cron.ts
line:     23
command:  /ds-audit
class:    decoy/DS-CO-11a
anchor:   @Cron('0 30 2 * * *')
match:    DST|time.?zone|TZ
```
```decoy
id:       DS-DECOY-34
file:     apps/workflows-ts/src/workflows/backorder.workflow.ts
line:     14
command:  /ds-audit
class:    decoy/DS-WF-01b
anchor:   const deadline = Date.now() + 14 * 24 * 3600_000;
match:    Date\.now|determinis
```
```decoy
id:       DS-DECOY-35
file:     apps/workflows-ts/src/workflows/loyalty-tier.workflow.ts
line:     7
command:  /ds-audit
class:    decoy/DS-WF-02a
anchor:   export async function merchantTierWorkflow(merchantId: string): Promise<void> {
match:    patched|version|replay
```
```decoy
id:       DS-DECOY-36
file:     services/ledger-jvm/src/main/java/com/acme/ledger/saga/RemittanceSaga.java
line:     22
command:  /ds-audit
class:    decoy/DS-WF-04b
anchor:   .invokeParticipant(this::releaseFunds)
match:    compensat|withCompensation
```
```decoy
id:       DS-DECOY-37
file:     services/ledger-jvm/src/main/java/com/acme/ledger/workflow/ReturnsWorkflowImpl.java
line:     21
command:  /ds-audit
class:    decoy/DS-WF-05a
anchor:   Saga saga = new Saga(new Saga.Options.Builder().build());
match:    order|reverse|compensat
```
```decoy
id:       DS-DECOY-38
file:     schemas/avro/shipment_delivered.avsc
line:     9
command:  /ds-audit
class:    decoy/DS-EC-01a
anchor:   "name": "signedBy"
match:    breaking|compatib|field
```
```decoy
id:       DS-DECOY-39
file:     apps/worker/src/consumers/carrier-scans.consumer.ts
line:     25
command:  /ds-audit
class:    decoy/DS-EC-02a
anchor:   const raw: unknown = JSON.parse(message.value?.toString() ?? 'null');
match:    JSON\.parse|valid|cast
```
```decoy
id:       DS-DECOY-40
file:     apps/api/src/webhooks/merchant-webhook.dto.ts
line:     14
command:  /ds-audit
class:    decoy/DS-EC-03b
anchor:   .strict();
match:    strict|tolerant|unknown
```
```decoy
id:       DS-DECOY-41
file:     apps/worker/test/consumers.e2e-spec.ts
line:     10
command:  /ds-audit
class:    decoy/DS-EC-05a
anchor:   topic: 'orders.placed.e2e'
match:    topic|name|drift
```
```decoy
id:       DS-DECOY-42
file:     apps/api/src/audit/audit-trail.ts
line:     14
command:  /ds-audit
class:    decoy/DS-EC-06a
anchor:   await this.client.appendToStream(`audit-${tenantId}`, event, { streamState: ANY });
match:    expected|ANY|append|revision
```
```decoy
id:       DS-DECOY-43
file:     services/notify-dotnet/src/Notify.Api/Preferences/MartenSetup.cs
line:     10
command:  /ds-audit
class:    decoy/DS-EC-07a
anchor:   services.AddMarten(o =>
match:    UNIQUE|stream|version
```
```decoy
id:       DS-DECOY-44
file:     apps/worker/src/projections/daily-volume.projector.ts
line:     25
command:  /ds-audit
class:    decoy/DS-EC-08a
anchor:   await client.query('ALTER TABLE daily_volume_next RENAME TO daily_volume');
match:    idempot|checkpoint|projection
```
```decoy
id:       DS-DECOY-45
file:     apps/web/src/routes/returns.new.tsx
line:     11
command:  /ds-audit
class:    decoy/DS-EC-10b
anchor:   return redirect(`/returns/${created.id}`);
match:    redirect|projection|stale
```
```decoy
id:       DS-DECOY-46
file:     deploy/k8s/worker-scheduler.yaml
line:     9
command:  /perf-audit
class:    decoy/DS-HO-PERF-a
anchor:   replicas: 1
match:    replica|fleet|once
```

## Detector measurement — the pre-flights run on this fixture

Measured 2026-10-14 on a staged copy (answer key removed, `git init` with one commit, `ds-inventory.py` installed at
`.claude/skills/messaging-scan/scripts/`), each `SKILL.md` and `stacks.md` pre-flight extracted verbatim (an `echo` marker
added before each comment line, nothing else changed) and run as one bash 3.2 script from the copy's root, an empty
isolated `KUBECONFIG` first, `HOME` pointed at a scratch directory. ripgrep 15.2.0. Tool lane on `PATH` from a scratch
`npm install`: `@bufbuild/buf` 1.73.0, `json-schema-diff` 1.0.0, `@asyncapi/cli` 6.2.1 (run with `CI=true` and an
analytics-off `ASYNCAPI_METRICS_CONFIG_PATH`; no `~/.asyncapi-analytics` was written), `avsc` 5.7.9 through `NODE_PATH`.
Not installed: `workflowcheck`, `dotnet` (the DURABLE analyzers), `oasdiff`, `errcheck`, `ruff`, `temporal`, a docker
daemon. Every pre-flight wrote nothing to stderr and no rg exited 2; `git status` on the copy was clean after the run.
Re-measured the same day after distributed-systems 2.0.1 closed IR-1..IR-11 (same recipe, a fresh staged copy;
`workflow-scan` now gets `CONTRACT_BASE` as `/ds-audit --contract-base` passes it). The rows below are the re-measured
numbers; what each fix changed is stated in its row.

Line counts include the added marker lines. A seed is **caught** when its owner's pre-flight prints its `file:line` (or a line of the same unit within 6), the
file-level or inventory row that names it, or the tool verdict for its schema. **Partial** means the unit or line is
printed but the class is settled only by the read. These are grep results, not a scored `/ds-audit` run — no run is
recorded in `RESULTS.md` yet.

| detector | lines printed · time | seeds it owns | caught by its pre-flight | partial / missed | decoys printed → read |
|----------|----------------------|---------------|--------------------------|------------------|-----------------------|
| `ds-inventory.py` | 61 rows · `# resolved 59/61 — consumers 37/39, producers 22/22, wrappers 1` (97 %, over the 90 % gate) | — (F2 for messaging and retry) | `create_billing_order acks_late=false [default:celery.task]` (MQ-01b), `invoices … lockDuration=30000 [default:bullmq.worker]` (MQ-06a's first term), `carrier-sync attempts=5; backoff='none'` (RT-03a), the `BaseProducer.enqueue` wrapper with its subclasses | 2 UNRESOLVED: the Spring rows (locate-only, by design). Fixed in 2.0.1: the 3 amqplib rows resolve `noAck=false [default:amqplib.consume]` and `label-print` prints `prefetch='unbounded'` (MQ-09a, a second surface) (IR-1); the 3 kafkajs producers injected through a DI token (`place-order`, `cancel-order`, `reprice`) are rows, and every `KAFKA_PRODUCER` row carries the provider's `idempotent=true`, `maxInFlightRequests=5 [kafka.module.ts:14 via KAFKA_PRODUCER]` (IR-2) | DECOY-13 (`reprice.usecase.ts:22`) is now an inventory row — a producer, never a finding; § 10 clears it as before |
| `messaging-scan` (+ `stacks.md`) | 273 + 35 · 0.7 s + 0.3 s | 26 (§1–§11) | **25** — 1a (MQ-01a, through `handle(`), P1 empty list = no `acks_late` anywhere (MQ-01b), J1 (MQ-01c), 2b (MQ-02a), 2d (MQ-02b), 2c (MQ-02c), 3d (MQ-03a), J3 + no recoverer in the repo (MQ-03b), 3a (MQ-03c), 4a (MQ-04a), 5a (MQ-05a), J4 `max-poll-records` + `max.poll.interval.ms` (MQ-05b), P4 `countdown=7200` + the Redis broker URL (MQ-06b), 7a (MQ-07a), J4 `retries: 0` (MQ-07b), 7d (MQ-07c), 8a (MQ-08a), 9a (MQ-09a), 9b (MQ-09b), 10 (MQ-10b), 11 (MQ-11a), J4 `exactly_once` (MQ-11b), and since 2.0.1 G5 `kafka.Message{Value: body}` + `&kafka.CRC32Balancer{}` (MQ-04b), 8e the `"x-message-ttl": 900000` arguments with no DLX (MQ-08b), 10 `no sync_interval (JetStream default, NA4): ./deploy/nats/nats-server.conf` (MQ-10a) | MQ-06a partial (the F2 lock default prints; the 40 s inline render is the read of `perf/pdf-render-baseline.json`). Missed 0 (before 2.0.1: MQ-04b, MQ-08b, MQ-10a — IR-3, IR-4) | DECOY-03 (2a input list), -05 (3a), -06 (4c), -08 (7a, 2c), -09 (8b), -10 (F1a): each cleared by one precedent or read (§ 2 amended, the failed set kept, § 8, § 6, § 34, KJ1). DECOY-01, -02, -04, -07 print nothing (the base's `withDeadline` call prints in 6c, cleared by § 36) |
| `dual-write-scan` | 106 · 0.4 s · O3 ports `OutboxPort\|OutboxService\|WorkerOutboxWriter`, receivers `outbox` | 13 (§1–§6) | **13** — 1a `7 matches → outbox port 4 · candidates 3` (DW-01a, DW-01b; the third is the routed DB-b, with 1d's `em.transactional` opener), 1b (DW-01b), O4 `delay_on_commit` (DW-01c), 2 (DW-02a, DW-02b in Go), 3a + 3b (DW-03a, DW-03b), 4a + 4b (DW-04a, DW-04b), 5 `op.invalid.behavior: warn` + the no-null-branch file (DW-05a, DW-05b), 6 (DW-06a, DW-06b) | — | DECOY-11 split as `outbox port` (counted in the 4, never a candidate); -13 (2) → § 10; -16 (5) → insert-only; -17 (6) → § 13. -12, -15 print nothing. Unseeded: `digest_outbox` (an e-mail dedupe table) prints under `O2 not a port source`, so `DigestMailer` is no longer a port (IR-6, 2.0.1); 5's file-level line also lists `billing/models.py` and `billing/outbox.py` (they name Debezium, consume nothing: part A) |
| `retry-deadline-scan` | 248 · 0.7 s | 17 (§1–§8) | **17** — 1a (RT-01a, RT-02a), 1c (RT-01b), 2a (RT-02a, RT-02b), F2 inventory (RT-03a), 3a (RT-03b), 4d `geocode.processor.ts ← GeoClient ← geo.client.ts ← HttpClient` (RT-04a), 4b (RT-04b), 5b (RT-05a), 5c (RT-05b), 5e (RT-05c, and the routed SEC-c), 6a (RT-06a), 6b `delivery-confirmation.processor.ts:2` (RT-06b), 7a (RT-07a), 7b (RT-07b), 8 both ends (RT-08a, RT-08b) | — | DECOY-18 (0b) → § 15; -21 (0b, 4d chain) → one layer; -22 (5a) → § 17. -19, -20, -23 print nothing. Unseeded: 5a `customs.client.ts` POST with `retry:` — the broker's dedupe on `reference` is a comment, so the row stays Unconfirmed until its contract is read (§ 34); 7b no longer matches `enqueue('geocode'` or `add('confirm-order'` (IR-7, 2.0.1: `code` and `confirm` are whole tokens) |
| `coordination-scan` (+ `stacks.md`) | 111 + 25 · 0.5 s + 0.4 s (110 before the 2.0.1 follow-ups added 4f, which prints `4f lock helpers: none` here) | 22 (§1–§11) | **22** — 1a (CO-01a), 1b ×2 sites (CO-01b), 2a (CO-02a), py-2 (CO-02b), jv-3 (CO-03a), 3a (CO-03b), 4a (CO-04a), jv-4 (CO-04b), 5a + 5b `?pgbouncer=true`, `pool_mode = transaction` (CO-05a, CO-05b), go-6 (CO-06a `func(_ context.Context)`, CO-06b `OnStoppedLeading`), 7a (CO-07a), go-7 (CO-07b), 8a + 8b (CO-08a), 8c (CO-08b), 9a (CO-09a), 9b (CO-09b), 10a (CO-10a, CO-10b), 11a + F3 `ENV TZ=Europe/Berlin` (CO-11a), 11c (CO-11b) | — | DECOY-24 (F2b Lua) → § 21; -27 (4a) → the per-item check four lines below; -29 (go-6) → exits; -31 (8b) → DB clock both ends; -32 (9a) → § 31; -33 (11a; the worker image and manifests set no TZ) → § 35; -14 (4a) → § 19. -25, -26, -28 print only in F2a; -30 prints nothing. 11b also prints the routed BE-b |
| `workflow-scan` | 119 · 0.5 s · F2 TS 7 · Go 2 · Java 2 · .NET 1 · sagas 8 | 13 (§1–§6) | **13** — 2a `gate-lines-added=0` for `fulfilment.workflow.ts` (WF-02a) and `SettlementWorkflowImpl.java` (WF-02b) against their `CONTRACT_BASE` copies, 1a (WF-01a, two lines), 1c (WF-01b; `§1 Go: blocked (workflowcheck not installed)`), 3b (WF-03a), 3d `heartbeatTimeout` + `heartbeat calls in activity files: 0` (WF-03b), 4b pairing (WF-04a), 4a (WF-04b), 5a (WF-05a), 5c (WF-05b), 5d (WF-05c), 6a (WF-06a), 6c (WF-06b) | — (before 2.0.1 WF-02a and WF-02b were partial: no base on a whole-repo run, IR-5) | DECOY-36 (4a) → § 26; -37 (5d) → registered before its call, § 27. -34, -35 print nothing. Since 2.0.1 (IR-8): 1e no longer prints `Task.WhenAll(sends)` in the Durable orchestrator (the documented fan-out), and 5d prints only the seed (`order-placement.saga.ts:38`) — the three register-before-call lines and `ReturnsWorkflowImpl.java:25` beside DECOY-37 are gone (DECOY-37 still prints in 4b's listing); the .NET DURABLE lane prints its install line |
| `event-contract-scan` (+ `stacks.md`) | 78 + 6 · 2.5 s (tools) + 0.1 s | 20 (§1–§10) | **20** — `1t buf ./schemas/proto BREAKING` with `courier_assigned.proto:9:3` (EC-01a); `1t asyncapi … PASS` + `payload changes unclassified: 24` (EC-01b; `json-schema-diff` on the extracted payload exits 1 "Breaking changes found" backward, 0 forward); 2b + 2c (EC-02a, EC-02b); 3a, 3b (EC-03a, EC-03b); 4 diff lines (EC-04a `+ amount: invoice.totalMinor / 100`, EC-04b `- durationS: Math.round(…)`); 5a near-twin `order.placed  orders.placed` (EC-05a); 5b (EC-05b, one of 24 consumed-never-produced names); 6a (EC-06a); S6 (EC-06b); 7a, 7c (EC-07a, EC-07b); 8a (EC-08a, EC-08b); 10a, 10b (EC-10a, EC-10b) | — since 2.0.1: 9a prints `order.aggregate.ts:38:onOrderShipped` (EC-09a; was `:29:onOrderPlaced`, partial) and 9b lists `order-snapshots.ts` (EC-09b; was missed, with `inventory-snapshots.consumer.ts` printed instead) (IR-9) | `1t avsc … PASS` both ways (DECOY-38); -39 (2c, not 2b: the `safeParse` follows); -40 (3b) → § 28; -42 (6a) → § 29; -44 (8a) → rebuild-and-swap; -45 (10b) → write-side loader. -41 (a test), -43 print nothing. Unseeded: `1t json-schema-diff schemas/events/invoice-issued.schema.json NOT-RUN (a 2019-09/2020-12 $schema …)` once, before the tool runs — json-schema-diff 1.0.0 cannot load a 2020-12 `$schema`; NOT-RUN, never PASS (IR-10, 2.0.1); 7c lists the outbox entity (`aggregateId`, class `OutboxEvent`) as an event table; S9 no longer prints the pure `Apply` in `SubscriberPreferences` (IR-9) |
| `/ds-audit` Phase 3 (context map) | 153 · 0.5 s | — | F1 5 managed-endpoint lines (the managed Valkey on port 25061 → `UNREAD`); F3 22 lines, `TZ lines: 1`; F5 `workflow files: TS 7 · Go 2 · Java 2 · Python 0 · .NET 1 · sagas 8`, `schema files: 4`, `ci gate lines: none` (REPLAY and CONTRACT GATE gaps); F6 `testcontainers` in both apps, `docker: no daemon` | — since 2.0.1 F4 prints `ledger_outbox_rows` and the Django `OutboxMessage` model (`store lines: 9`, was 7) and F5 counts the hand-rolled `compensations.push/unshift` sagas as `workflow-scan` F2 does (8, was 4) (IR-11) | — |

Totals: **110 of 111** distributed seeds surface in their owner's verbatim pre-flight with the class-specific row, **1
partial** (MQ-06a) and **0 missed** (before 2.0.1: 103, 4 partial — MQ-06a, WF-02a, WF-02b, EC-09a — and 4 missed — MQ-04b,
MQ-08b, MQ-10a, EC-09b). Decoys: 30 of 45 `/ds-audit`
decoys print somewhere and each clears by one precedent or one printed fact; 15 print nothing; no new grep line lands on a
decoy without its clearing fact in the same output.

**Tool-lane traps measured here** (both recorded in `event-contract-scan`'s exit-code table and `broker-semantics.md` SZ9/SZ10 in 2.0.1; the block now prints `VERSION-BUMP` and an up-front NOT-RUN for them):
- `asyncapi diff -t breaking` exits **1** with `DiffBreakingChangeError` when the only change is an `info.version` edit
  (2.2.0 → 2.3.0; `"path": "/info/version", "type": "breaking"`), so a correctly bumped document prints `BREAKING` for a
  release with no breaking channel change, and the payload change still sits only in the unclassified count.
- `json-schema-diff` 1.0.0 exits 1 with `Error: no schema with key or ref "https://json-schema.org/draft/2020-12/schema"`
  on a 2020-12 document — the same exit code as breaking; the block's `v()` reads it as NOT-RUN, as designed.

Hand-off rows, run through their owners' pre-flights on the same copy (blocks extracted the same way; `blocks.awk` and
`plan-joins.jq` from `iac-lifecycle-scan` installed under `.claude/skills/`, no Terraform plan, so the plan lane prints a
`jq` error):
- **database** — `transaction-scan` prints both `em.transactional` openers with the `add` inside (DB-a, DB-b) and the
  relay's `BEGIN … FOR UPDATE` with the `producer.send` inside (DB-c). DB-d (a saga's absolute write after a remote call,
  §8) prints nothing: a read step. **3/4.**
- **security** — `logic-race-scan` prints the clamped debit (SEC-a, twice), the payout transfer (SEC-b) and the
  per-attempt key with the charge (SEC-c). **3/3.**
- **performance** — `request-path-scan` prints `addCronJob` (PERF-a), `getMigrator().up()` in `main.ts` (PERF-b; also in
  the migrate Job's wrapper, part A), the in-flight `Set` (PERF-c), the `tracking-ingest` worker (PERF-d) and the
  scheduler's `replicas: 1` (DECOY-46, cleared by § 23). **4/4.**
- **infrastructure** — `serverless-reliability-scan` prints `visibility_timeout_seconds = 60` beside `timeout = 30`
  (INF-a) and the event source mapping under §4's absent-switch line (INF-b). **2/2.**
- **observability** — `trace-propagation-scan` §2 lists every BullMQ producer, including the `push` producer, and the
  two `BullMQOtel` connections; the `notify` connection with none is the read (OBS-a partial). **1 partial.**
- **backend** — `job-lifecycle-scan` prints `4b eta-recompute.cron.ts:19 @Interval(60_000)` (BE-a) and
  `4a`/`6g hour 1` on the Chicago 01:30 cron (BE-b). **2/2.**

Self-check of the key: a findings file built from each seed's own title and text scores 111/111 under `/ds-audit` and
4/4, 3/3, 4/4, 2/2, 1/1, 2/2 under the owners, with 0 decoys pinned; a file of one typical false report per decoy pins
45/45 under `/ds-audit` and 1/1 under `/perf-audit`.

### Integrator requests (skill gaps this fixture found)

None of these files were edited when the fixture was built; each was for the distributed-systems pack owner. **All eleven
are closed in distributed-systems 2.0.1 (2026-10-14)** — the measurement above is the re-run; the requests are kept as the
record of what the fixture found.

- **IR-1 — `ds-inventory.py` treats a 0.x major as unread.** `version()` returns `int("0")` for `amqplib ^0.10.9`, and the
  default is applied only `if major` (line 474), so every amqplib row prints `noAck=UNRESOLVED (default needs the amqplib
  version)` (3 rows here). Use `major is not None`.
- **IR-2 — `ds-inventory.py` misses kafkajs producers injected through a DI token** (`@Inject(KAFKA_PRODUCER) private
  readonly kafka: Producer` → `this.kafka.send(…)`): 3 producer sites are not rows. `dual-write-scan` 1a sees them; the
  inventory's producer count is short.
- **IR-3 — `messaging-scan` §4 has no Go producer grep.** kafka-go `kafka.Message{` with no `Key:`, and `CRC32Balancer` /
  `Hash{}` beside a Java producer on the same topic (LD4), print nothing (DS-MQ-04b). The Go lane in `stacks.md` covers
  consumers only.
- **IR-4 — absent broker settings in JSON/conf files.** 8d's alternation matches `x-dead-letter-exchange` but not
  `"x-message-ttl"` (and 8c is TS-only), so a TTL'd queue with no DLX in `definitions.json` is invisible (DS-MQ-08b); 10
  prints `sync_interval` only when present, so a `jetstream {}` block with no `sync_interval` carrying a payments stream
  is invisible (DS-MQ-10a). Both want a file-level "has X, lacks Y" check.
- **IR-5 — `workflow-scan` §2 has no base on a whole-repo run without git history.** 2a reads only `WF_BASE`; `/ds-audit
  --contract-base=<dir>` already carries a mirrored base tree. Pass it to `workflow-scan` (2a: files whose base copy
  differs, with the gate lines the head adds) — DS-WF-02a and DS-WF-02b stay partial until then.
- **IR-6 — `dual-write-scan` O2 matches any table name containing `outbox`** (`digest_outbox`, an e-mail dedupe table), so
  `DigestMailer` is resolved as an outbox port. Harmless here; on a repo where that class also publishes it would hide a
  candidate.
- **IR-7 — `retry-deadline-scan` 7b's `code` and `confirm` alternatives match `geocode` and `confirm-order`.** Anchor them
  (`[-_.:]code\b`, `\bconfirm(?:ation)?[-_.:]?(?:code|email)`) or accept the noise.
- **IR-8 — `workflow-scan` FP shapes.** 1e flags `Task.WhenAll` over `CallActivityAsync` tasks in a Durable orchestrator
  (the documented fan-out; needs a dated source before it is dropped from the list); 5d cannot tell which call a
  registration belongs to, so a registration that precedes its own call prints whenever the previous step's call is on the
  line above (3 lines here).
- **IR-9 — `event-contract-scan` 9a/9b and `stacks.md` S9.** The method-boundary lookahead `(?!\n[ \t]*\}\n)` is evaluated
  at a line start, where it can never match, so a hit is attributed to the first apply-like method within 12 lines
  (`onOrderPlaced` instead of `onOrderShipped`) and a pure `Apply` prints when the next method awaits. 9b's `\bsnapshot`
  misses camelCase and snake_case names (`saveSnapshot(`, `order_snapshots`) and matches a comment (`stock snapshots (`).
- **IR-10 — `event-contract-scan` tool table.** Record the two traps above: `asyncapi diff -t breaking` exits 1 on an
  `info.version` edit alone (drop `/info/version` before reading the verdict, or print it as `version-bump`), and
  `json-schema-diff` 1.0.0 cannot load a 2020-12 `$schema` (strip `$schema` into a scratch copy, or print NOT-RUN with
  that reason, as it does now).
- **IR-11 — `/ds-audit` Phase 3** (`commands/ds-audit.md`): F4's table-name regex needs no `\b` after the store word
  (`ledger_outbox_rows`) and the Django `class …Outbox…(models.Model)` arm `dual-write-scan` O1 has; F5's saga count
  should include `compensations?\.(?:push|unshift)\(` as `workflow-scan` F2 does.
