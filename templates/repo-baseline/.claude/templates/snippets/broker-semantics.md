# Broker semantics — the defaults every distributed-systems verdict rests on

One row per fact, each tagged and dated. A verdict that depends on how a broker, a client library,
a retry or lock library or a workflow SDK behaves by default (does a nack count toward the delivery
limit, does a void handler delete the message, does a bare `@retry` stop) names the row it rests
on, read **at the installed version**; a verdict that names no row is invalid. Cited by the
distributed-systems detectors (`messaging-scan`, `dual-write-scan`, `retry-deadline-scan`,
`coordination-scan`, `workflow-scan`, `event-contract-scan`), by `/ds-audit` and `/ds-fix`, and by
[`precedents/distributed.md`](precedents/distributed.md) § 1, § 4, § 7, § 15, § 21, § 24 and § 25.
The oracles are in [`proof-oracles.md`](proof-oracles.md) § Distributed (V291–V327).

Tags: `[V]` verified against the source on the date given · `[K]` known, not re-fetched · `[K?]`
uncertain — prove it on the `ds-defects` fixture or in a container before a detector asserts it.
`build` marks a row whose source was re-read when this file was written. A library changes these;
a row older than the installed version's docs is re-read before it decides a verdict. A managed
broker or cache whose server setting is not in the repo (no parameter group, no config file) is
`UNREAD (<service>)`, never the self-hosted default.

## BullMQ and Bull (Node)

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| BQ1 | BullMQ 6.0 | 6.0.0 (2026-07-30) **removed legacy repeatable jobs** — the `repeat` option on `add`/`addBulk`, the `Repeat` class, `getRepeatableJobs`, `removeRepeatable*` — in favour of Job Schedulers (`upsertJobScheduler(id, repeatOpts, template)`, an upsert by id); `repeat` was deprecated in 5.16.0. 6.0 also removed `Queue#client` and `Worker#blockingClient` and added a PostgreSQL backend | [V] 2026-10-14, build · bullmq `docs/gitbook/changelog.md`; docs.bullmq.io *Job Schedulers* |
| BQ2 | BullMQ worker defaults | `concurrency` 1 · `lockDuration` 30 000 ms · `lockRenewTime` = `lockDuration / 2`, renewed **on the event loop** (CPU-bound synchronous work blocks it) · `stalledInterval` 30 000 ms · **`maxStalledCount` 1** (a stalled job is moved back to wait once — a second execution — then failed) · **`attempts` 1** (no retry) · no `backoff` → a retry runs immediately | [V] 2026-10-14, build · bullmq `src/classes/worker.ts` master (`attempts` in `src/interfaces/base-job-options.ts`); docs *Retrying failing jobs*, *Stalled jobs* |
| BQ3 | BullMQ retention | `removeOnComplete` / `removeOnFail` default: keep forever. The failed set is the dead-letter store; `removeOnFail: true` discards it. A count (`removeOnComplete: 1000`) keeps the last N | [V] 2026-10-14 · docs *Auto-removal of jobs* |
| BQ4 | BullMQ `jobId` | Adding a job with an existing id is ignored, **but a removed job (manual, `removeOnComplete`, `removeOnFail`) is no longer a duplicate**: the same id can be added again. Custom ids must not contain `:` or be all digits | [V] 2026-10-14 · docs *Job Ids* |
| BQ5 | BullMQ `deduplication` | `{ id }` dedupes only while the first job is not completed or failed; `{ id, ttl }` is a throttle window; with `extend`/`replace` + delay a debounce. An admission filter, **not** an idempotency key for the effect | [V] 2026-10-14 · docs *Deduplication* |
| BQ6 | BullMQ on Redis | Correct only with `maxmemory-policy noeviction` (any LRU/LFU/volatile policy can silently delete job keys); workers need ioredis `maxRetriesPerRequest: null` | [V] 2026-10-14 · docs *Going to production* |
| BQ7 | BullMQ `QueueScheduler` | Required in 1.x for stalled and delayed jobs; removed in 2.0 — `new QueueScheduler(` in a ≥ 2.0 repo is dead code or a build error | [K?] · release date not re-fetched |
| BQ8 | BullMQ flows | A child that fails without `failParentOnFailure`, `ignoreDependencyOnFailure` or `removeDependencyOnFailure` leaves the parent in `waiting-children` | [V] 2026-10-14 · docs *Flows*; [K?] that no timeout releases it |
| BQ9 | Bull (legacy) | 4.16.5 (2024-12-18), maintenance mode (bug fixes only); same lock and stall defaults; `process(n, fn)` concurrency; a `done()` call ends the job | [V] 2026-10-14 · bull README, `lib/queue.js` |

## Kafka — kafkajs and confluent-kafka-javascript

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| KJ1 | kafkajs status | 2.2.4, last npm publish **2023-02-27**; maintainer's "Looking for maintainers" issue #1603 (2023-08-08). A migration note on any finding, **never a defect on its own** | [V] 2026-10-14, build · npm registry; GitHub tulios/kafkajs |
| KJ2 | kafkajs commit | `autoCommit` true: the offset is committed after each `eachMessage` **resolves**; `eachBatchAutoResolve` true commits the batch's last offset when `eachBatch` does not throw | [V] 2026-10-14 · kafkajs `docs/Consuming.md` |
| KJ3 | kafkajs timing | `sessionTimeout` 30 000 · `rebalanceTimeout` 60 000 · `heartbeatInterval` 3 000 ms; a long `eachBatch` must call `heartbeat()` | [V] 2026-10-14 · `docs/Consuming.md`, `Configuration.md` |
| KJ4 | kafkajs handler throw | `retry.retries` 5 (exponential), then `restartOnFailure` (default `async () => true`) restarts from the last committed offset → **a poison message loops forever and blocks the partition**. confluent's compat API: `restartOnFailure` true and not changeable | [V] 2026-10-14 · `docs/Configuration.md`; confluent `MIGRATION.md` |
| KJ5 | kafkajs producer | `acks` -1 (all) · `idempotent` false ("experimental") · `maxInFlightRequests` null = unlimited | [V] 2026-10-14 · `docs/Producing.md` |
| KJ6 | kafkajs partitioner | 2.0 made the Java-compatible murmur2 partitioner the default (`DefaultPartitioner`); the old default is `LegacyPartitioner` — a key may land on a different partition than from a pre-2.0 producer | [V] 2026-10-14 · `docs/MigrationGuide-2-0-0.md` |
| KJ7 | confluent compat API | `@confluentinc/kafka-javascript` 1.11.0 (2026-10-07): `autoCommit` is **periodic, every 5 000 ms**, per consumer; `rebalanceTimeout` 300 000 also sets the max poll interval; batch size ≤ 32; partitioner `murmur2_random`; heartbeats automatic | [V] 2026-10-14 · confluent `MIGRATION.md` |
| KJ8 | Kafka EOS scope | Transactions (`transactionalId`, `idempotent: true`, `maxInFlightRequests: 1`, `sendOffsets`) cover Kafka → Kafka only; a DB write or HTTP call in a transactional consumer is still at-least-once | [V] 2026-10-14 · `docs/Transactions.md` |
| KJ9 | kafkajs concurrency | `partitionsConsumedConcurrently` 1; at any value per-partition order is kept (concurrency is across partitions) | [V] 2026-10-14 · `docs/Consuming.md` |

## Kafka — Java client, Spring Kafka, Kafka Streams

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| KA1 | Java consumer commit | kafka-clients 4.4.0: `enable.auto.commit` **true** (raw client); the commit happens inside the **next** `poll()` for what the previous poll returned; `auto.commit.interval.ms` 5 000 | [V] 2026-10-14 · apache/kafka `ConsumerConfig.java` trunk |
| KA2 | Java consumer timing | `max.poll.interval.ms` 300 000 · `max.poll.records` 500 · `session.timeout.ms` 45 000 · `group.protocol` default still `classic` · assignment `[RangeAssignor, CooperativeStickyAssignor]` | [V] 2026-10-14 · `ConsumerConfig.java` |
| KA3 | Java isolation | `isolation.level` **read_uncommitted** (librdkafka differs, LD3) | [V] 2026-10-14 · `ConsumerConfig.java` |
| KA4 | Java producer | `acks` all (since 3.0) · `enable.idempotence` true **only if no conflicting setting is present: with `acks` ≠ all, `retries=0` or `max.in.flight.requests.per.connection` > 5 and idempotence not set explicitly, it is silently disabled** (explicit true + conflict = `ConfigException`) · `max.in.flight` 5 · `retries` `Integer.MAX_VALUE` · `delivery.timeout.ms` 120 000 | [V] 2026-10-14, build · `ProducerConfig.java`; kafka.apache.org *Producer configs* |
| KA5 | Kafka Streams 4 | `processing.guarantee` default `at_least_once`; the only other value is `exactly_once_v2` — `exactly_once` and `exactly_once_beta` were removed in 4.0 (2025-03) and fail at startup | [V] 2026-10-14, build · the 4.0 `StreamsConfig` validator (the 4.0 upgrade notes say only "eos-v1 no longer supported") |
| KA6 | Spring Kafka acks | spring-kafka 4.1.1: forces `enable.auto.commit=false` unless set; default `AckMode.BATCH` (commit after the poll batch); `MANUAL_IMMEDIATE` commits at `acknowledge()` | [V] 2026-10-14 · docs *Message listener containers* |
| KA7 | Spring `DefaultErrorHandler()` | No-arg = `FixedBackOff(0, 9)`: **10 attempts, no delay**, then the default recoverer **logs and skips with the offset committed** — without a `DeadLetterPublishingRecoverer` the record is dropped. Not retried: `DeserializationException`, `MessageConversionException`, `ConversionException`, `MethodArgumentResolutionException`, `NoSuchMethodException`, `ClassCastException` | [V] 2026-10-14, build · docs 4.1.1 *Handling exceptions*; `DefaultErrorHandler.java`, `SeekUtils.java` |
| KA8 | Spring batch listener | Any exception other than `BatchListenerFailedException(index)` retries the **whole batch** | [V] 2026-10-14 · docs *Handling exceptions* |
| KA9 | Spring DLT | `DeadLetterPublishingRecoverer` publishes to `<topic>-dlt`, **same partition number** (the DLT needs ≥ the source's partitions; since 2.7 a missing partition falls back to Kafka's choice) | [V] 2026-10-14 · same |
| KA10 | Spring Kafka + DB | `ChainedKafkaTransactionManager` is deprecated; Kafka + DB transaction synchronisation is best-effort 1PC, not atomic — a dual write | [V] 2026-10-14 · spring-kafka main source |
| KA11 | `@RetryableTopic` | Non-blocking retry topics give up per-key ordering (records move to retry topics while later ones proceed) | [K?] · design property, wording not re-read |

## Kafka — librdkafka family and Go clients

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| LD1 | librdkafka offset store | v2.16.0 (2026-10-06), used by Confluent.Kafka (.NET), confluent-kafka-python and -go, node-rdkafka: **`enable.auto.offset.store` true stores the offset of the last message *handed to the application***, so the background auto-commit can commit a message still being processed; a crash mid-handler loses it. Fix: `false` + `StoreOffset()` after processing | [V] 2026-10-14 · librdkafka `CONFIGURATION.md` master |
| LD2 | librdkafka idempotence | `enable.idempotence` **false** (Java: true) | [V] 2026-10-14 · same |
| LD3 | librdkafka isolation | `isolation.level` **read_committed** (Java: read_uncommitted) | [V] 2026-10-14 · same |
| LD4 | librdkafka partitioner | **`consistent_random` (CRC32)**; Java and kafkajs 2.x hash with murmur2 — the same key lands on different partitions when both write one topic. Fix: `partitioner=murmur2_random` | [V] 2026-10-14 · same |
| LD5 | librdkafka timing | `session.timeout.ms` 45 000 · `max.poll.interval.ms` 300 000 · auto-commit every 5 000 ms on a background thread | [V] 2026-10-14 · same |
| GL1 | kafka-go | v0.4.51: **`ReadMessage` with a `GroupID` commits at read**, before the handler; explicit mode is `FetchMessage` + `CommitMessages`, cumulative per partition (committing 3 commits 1–2) | [V] 2026-10-14 · segmentio/kafka-go README |
| GL2 | franz-go | v1.22.2: default autocommit commits what the **previous** poll returned; `GreedyAutoCommit` commits everything polled (the docs warn of loss); `AutoCommitMarks` + `MarkCommitRecords` for async work | [V] 2026-10-14 · `pkg/kgo/config.go` master |
| GL3 | sarama | v1.61.1: `Consumer.Offsets.AutoCommit.Enable` true commits **marked** offsets; `MarkMessage` before processing commits unprocessed work | [K?] · default wording not re-read |
| GL4 | Watermill Kafka | v1.5.3: the router acks on `nil` and nacks on error; the Kafka subscriber **re-sends a nacked message after `NackResendSleep` (100 ms) forever** unless a `Retry` or `PoisonQueue` middleware ends it | [V] 2026-10-14 · watermill-kafka `pkg/kafka/subscriber.go` |

## RabbitMQ

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| RQ1 | Quorum delivery limit | Default delivery limit **20 since 4.0**; over it the message is **dropped unless a DLX is configured**; `x-delivery-limit=-1` disables it. Server 4.3.0 published 2026-04-23 (tagged 2026-04-21; 4.3.6 on 2026-09-14) | [V] 2026-10-14, build · rabbitmq.com *Quorum queues* (4.3); GitHub releases |
| RQ2 | 4.3 nack change | From 4.3 the limit is evaluated on `delivery-count`, incremented **only for failures** — `basic.reject`, AMQP 1.0 `rejected` / `modified` with `delivery_failed=true`, a channel or session crash with pending deliveries. **`basic.nack` (AMQP 0.9.1) does not increment it → a nack-requeue loop is unbounded.** 4.3 adds the `x-acquired-count` header | [V] 2026-10-14, build · rabbitmq-website `docs/quorum-queues/index.md` |
| RQ3 | Classic queues | No delivery limit at all: a requeue loop runs forever | [K] · inferred from the quorum-only feature |
| RQ4 | amqplib | 2.2.0 (2026-09-28): `consume` `noAck` false · `nack(msg, allUpTo, requeue)` / `reject(msg, requeue)` **requeue true when omitted** · `prefetch` never called (or `prefetch(0)`) = **unlimited** · `publish` has no confirm unless `createConfirmChannel()` + callback / `waitForConfirms()`. 1.1.0 added built-in connection recovery | [V] 2026-10-14 · amqplib `lib/api_args.js`, `lib/channel_model.js`, `CHANGELOG.md` |
| RQ5 | pika | 1.4.4: `basic_nack` / `basic_reject` `requeue=True` by default | [V] 2026-10-14 · pika `channel.py` |
| RQ6 | Spring AMQP | `AcknowledgeMode.AUTO` (ack after the listener returns) · **`defaultRequeueRejected` true** (an exception requeues) · prefetch 250 | [V] 2026-10-14 · spring-amqp `AbstractMessageListenerContainer.java` |
| RQ7 | Quorum dead-lettering | `dead-letter-strategy` default **at-most-once**; at-least-once needs `overflow: reject-publish` and a DLX | [V] 2026-10-14 · *Quorum queues* (4.3) |
| RQ8 | `consumer_timeout` | 30 min; exceeded → the channel is closed and its unacked deliveries requeued; per queue via policy or `x-consumer-timeout`; **4.3: quorum queues only** | [V] 2026-10-14 · rabbitmq.com *Consumers* (4.3) |
| RQ9 | Mirroring | Classic queue mirroring (`ha-mode` policies) removed in 4.0: such a policy is dead configuration | [K] · not re-read |

## AWS SQS and SNS (non-Lambda consumers; Lambda event sources are infrastructure's)

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| AW1 | Visibility | Default **30 s**; extended by `ChangeMessageVisibility` (a heartbeat); hard cap 12 h from the first receive. A standard queue may deliver a message more than once even within the window | [V] 2026-10-14 · SQS Developer Guide *Visibility timeout* |
| AW2 | FIFO | The next message in a `MessageGroupId` is withheld while one is in flight (a constant group id serialises the queue); dedupe window **5 min**, tracked even after delete | [V] 2026-10-14 · *Message deduplication ID* |
| AW3 | DLQ | `maxReceiveCount` in the redrive policy (1 dead-letters transient failures); a **standard-queue DLQ keeps the original enqueue timestamp**, so its retention must exceed the source's; with `maxReceiveCount` > 3 a message received ≥ 3 times goes to the back of the queue | [V] 2026-10-14 · *Dead-letter queues* |
| AW4 | sqs-consumer ≥ 14 | **A message is deleted only when `handleMessage` returns it** (same `MessageId`); an `async` handler with no `return` leaves it on the queue → reprocessed after the visibility timeout until `maxReceiveCount`, then dead-lettered despite success. `alwaysAcknowledge: true` deletes whatever the return; `terminateVisibilityTimeout` true = immediate hot retry; `heartbeatInterval` extends visibility; `handleMessageTimeout` rejects the wait while the handler keeps running → a duplicate. 14.0.0 released 2025-09-15 (#583; the CHANGELOG does not record it); 15.0.4 on 2026-09-25 | [V] 2026-10-14, build · bbc/sqs-consumer v14.0.0 GitHub release, README, `src/consumer.ts`, npm registry |
| AW5 | Spring Cloud AWS SQS | 4.2.0: `AcknowledgementMode` default `ON_SUCCESS`; `ALWAYS` acks on error (a loss) | [V] 2026-10-14 · `AbstractContainerOptions.java` |
| AW6 | SNS → SQS duplicate | A duplicate SNS delivery arrives as a **new SQS message with a new SQS `MessageId`**; the dedupe key is the SNS `MessageId` or an application event id | [K?] · reasoned from the delivery model; confirm with a dated AWS sentence or LocalStack |
| AW7 | Batch APIs | `SendMessageBatch`, `DeleteMessageBatch`, `ChangeMessageVisibilityBatch`, SNS `PublishBatch` return 200 with a per-entry `Failed` list; ignoring it is silent loss (send) or silent redelivery (delete) | [K] · API reference, not re-read |
| AW8 | In-flight limit | About 120 000 in flight per standard queue: short polling errors with `OverLimit`, long polling silently returns nothing | [V] 2026-10-14 · Developer Guide |

## NATS, Redis Streams, Google Pub/Sub

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| NA1 | JetStream consumer | nats-server 2.15.1: `AckWait` 30 s · `MaxAckPending` 1 000 · **`MaxDeliver` -1 = unlimited redelivery** (a poison message every `AckWait`, or at once on `Nak()`) · `InProgress()` resets `AckWait` · `Term()` stops redelivery | [V] 2026-10-14, build · nats-server `server/consumer.go`; nats.go `jetstream/consumer_config.go` (the docs.nats.io consumers page no longer states `MaxDeliver`) |
| NA2 | JetStream ack policy | nats.go v1.54.0 `jetstream`: `AckExplicit` is the default; `AckAll` acks everything below the acked sequence (with concurrent handlers that acks unprocessed messages); `AckNone` is at-most-once. Core NATS (`Subscribe`/`Publish`) is at-most-once with no persistence | [V] 2026-10-14 · `jetstream/consumer_config.go` |
| NA3 | JetStream dedupe | Stream duplicate window **2 min** for `Nats-Msg-Id` | [V] 2026-10-14 · `server/stream.go` |
| NA4 | NATS durability | Jepsen, NATS 2.12.1 (2025-12-08): JetStream lost acknowledged writes under crashes because by default it fsyncs about every **2 minutes**, not before the ack; `sync_interval: always` is the durable setting | [V] 2026-10-14, build · jepsen.io *NATS 2.12.1* |
| NA5 | nats npm | `nats` 2.29.3 is deprecated ("package moved"); the v3 split packages are `@nats-io/transport-node`, `@nats-io/jetstream` | [V] 2026-10-14 · npm registry |
| RD1 | Streams trimming | Trim default `KEEPREF` deletes entries even while pending (the PEL keeps dangling ids); `ACKED` / `DELREF` trim conditions exist **since Redis 8.2** | [V] 2026-10-14 · redis.io `XADD`, `XTRIM` |
| RD2 | Streams idempotence | `XADD … IDMP` / `IDMPAUTO` (idempotent production) since **8.6**; `XNACK` since **8.8.0** | [V] 2026-10-14 · redis.io command pages |
| RD3 | Streams consumption | `XREADGROUP` without `COUNT` returns everything available; `NOACK` keeps entries out of the PEL (at-most-once); `XAUTOCLAIM` (6.2+) increments the delivery count. Redis pub/sub is fire-and-forget | [V] 2026-10-14 · redis.io `XREADGROUP`, `XAUTOCLAIM` |
| RD4 | Redis key expiry | Expiry uses the **wall clock**: a clock jump can expire a lock early | [V] 2026-10-14 · redis.io *Distributed locks* |
| RD5 | Managed Redis / Valkey | The `maxmemory-policy` default of ElastiCache, Memorystore and DigitalOcean Managed Caching is **not** taken from memory: `UNREAD (<service>)` unless a parameter group is in the repo | [K?] · per-provider default not read |
| GP1 | Pub/Sub DLQ | `max_delivery_attempts` default 5 (range 5–100), counted best-effort; works only when the Pub/Sub service agent has publisher on the DLQ topic and subscriber on the source subscription | [V] 2026-10-14 · Google Cloud *Handling message failures* (updated 2026-10-09) |
| GP2 | Pub/Sub exactly-once | Pull / StreamingPull only, one region; learn the ack result with `ackWithResponse()`; publish-side duplicates still occur (a client publish retry makes a new id). Default ack deadline 60 s | [V] 2026-10-14 · *Exactly-once delivery* (updated 2026-10-09) |

## Python, Ruby, PHP and .NET job systems

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| CY1 | Celery ack | celery 5.6.3: **`task_acks_late` False** (acked on receipt, before running — a crash loses the task) · `task_reject_on_worker_lost` False (with `acks_late`, a task whose worker process died is still acked) · `task_acks_on_failure_or_timeout` True | [V] 2026-10-14, build · celery `app/defaults.py`; docs *Configuration* |
| CY2 | Celery prefetch | `worker_prefetch_multiplier` 4 · `worker_cancel_long_running_tasks_on_connection_loss` False (with `acks_late`, a broker connection loss redelivers tasks still running) | [V] 2026-10-14 · same |
| CY3 | Celery retry | `autoretry_for` none · `max_retries` 3 (`None` = forever) · `default_retry_delay` 180 s · `retry_backoff` False · `retry_backoff_max` 600 s · `retry_jitter` True | [V] 2026-10-14 · `app/task.py`; docs *Tasks* |
| CY4 | Celery visibility | Redis and SQS transports: **`visibility_timeout` 1 h**; an ETA, countdown or retry delay longer than it is redelivered and executed again | [V] 2026-10-14, build · docs *Using Redis* |
| CY5 | Celery after commit | `delay_on_commit()` since 5.4 (Django): enqueue at `transaction.on_commit` — no phantom, the loss window stays (OX5) | [V] 2026-10-14 · docs *First steps with Django* |
| RB1 | Sidekiq | 8.1.7 (OSS): concurrency 5 · shutdown timeout 25 s · retries 25 · Dead set 10 000 jobs / 6 months. `BasicFetch` pops the job; a graceful shutdown re-pushes unfinished jobs, a **crash (`kill -9`, OOM) loses in-progress jobs** — `super_fetch` is Sidekiq Pro | [V] 2026-10-14 · sidekiq `lib/sidekiq/config.rb`, `fetch.rb`; [K?] the loss-on-crash wording |
| RB2 | Sidekiq options | `retry: false` discards a failing job; `dead: false` discards an exhausted one instead of moving it to Dead | [K?] · whether `retry: false` also skips the Dead set |
| RB3 | Rails after-commit enqueue | Per-job `enqueue_after_transaction_commit` default false in 8.1; Rails main (8.2, unreleased on 2026-10-14) enqueues after commit by default for `load_defaults "8.2"` | [V] 2026-10-14 · rails `activejob/CHANGELOG.md` main |
| RB4 | Solid Queue / GoodJob | Enqueue is atomic with the app's transaction only when the queue tables share its connection: GoodJob uses the app's connection by default; Rails 8's Solid Queue setup uses a separate `queue` database | [K?] · read `config/database.yml` per repo |
| LV1 | Laravel queues | laravel/framework 13.36.0; skeleton `config/queue.php`: `retry_after` 90 (database, redis, beanstalkd) · `after_commit` false · `queue:work` `--timeout=60 --tries=1 --backoff=0` | [V] 2026-10-14 · laravel/laravel `config/queue.php`; `WorkCommand.php` |
| LV2 | Laravel timing | `--timeout` must be several seconds shorter than `retry_after`, or a running job is released and processed twice; `$tries = 0` = unlimited | [K] / [K?] · docs wording not re-read |
| NT1 | MassTransit licence | **9.x is commercial** (9.0.0 on 2026-01-06; 9.2.3 on 2026-10-02); 8.x stays Apache-2.0 (8.5.11 on 2026-09-30). "Upgrade to 9" is never a fix | [V] 2026-10-14 · NuGet registration API |
| NT2 | MassTransit outbox | `UseInMemoryOutbox` is **not durable**; the EF Core / Mongo transactional outbox writes in the business transaction; the bus outbox's delivery `ConcurrentDeliveryLimit` is 1. A `Publish` after the last `SaveChangesAsync` under the bus outbox is never persisted | [V] 2026-10-14 · masstransit.massient.com *Outbox*; [K?] the publish-after-save loss |
| NT3 | .NET defaults | MassTransit: no retry unless configured, faults to `<queue>_error`; Azure Service Bus: `AutoCompleteMessages` true, `ReceiveAndDelete` = at-most-once, `MaxDeliveryCount` 10; NServiceBus: 5 immediate + 3 delayed retries | [K] · not re-read |

## Outbox, CDC and stable message ids

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| OX1 | Debezium Outbox Event Router | debezium 3.7: columns `id, aggregatetype, aggregateid, type, payload`; **Kafka key = `aggregateid`** (per-aggregate order); the event id goes to header `id`; an UPDATE on the outbox → `table.op.invalid.behavior` **warn**; `route.tombstone.on.empty.payload` false | [V] 2026-10-14 · debezium.io *Outbox Event Router* (3.7) |
| OX2 | Debezium delivery | A connector restart resumes from the last committed source offset and re-emits what followed (at-least-once); `snapshot.mode=initial` emits every existing row as a read (`op=r`) | [K] · standard behaviour, wording not re-read |
| OX3 | Debezium tombstones | `tombstones.on.delete` default true on source connectors | [K?] |
| OX4 | Spring Modulith registry | 2.1.1: publication rows written in the business transaction, completed only on listener success; the **staleness monitor is off by default**; `republish-outstanding-events-on-restart` default believed false; `@Externalized` lacks outbox guarantees (use `externalization.mode=outbox`) | [V] 2026-10-14 · docs.spring.io spring-modulith 2.1.1 *Events*; [K?] the republish default |
| OX5 | After-commit helpers | Celery `delay_on_commit`, Rails after-commit enqueue, Laravel `afterCommit`, Sidekiq `after_commit` remove the phantom (database V8) and **keep the loss window** (a crash after commit, a broker down) | [V] 2026-10-14 · the rows above |
| OX6 | `@nestjs/cqrs` | 12.1.0: `EventBus` is in-process only — no outbox, no durability; `@Saga()` runs in memory with no compensation | [V] 2026-10-14 · npm; NestJS docs *CQRS* |
| OX7 | DB-backed queues | GoodJob / Solid Queue enqueue is a built-in outbox only on the app's own connection (RB4) | [K?] |
| ID1 | Kafka id | Use a producer-assigned event id header (Debezium `id`, CloudEvents `id`) or `topic-partition-offset` (stable for one record, not across a producer retry that wrote a duplicate) | [V] 2026-10-14 · Debezium docs; Kafka record model |
| ID2 | RabbitMQ id | Use `properties.messageId` set by the publisher (empty unless set); never `deliveryTag` (per channel, changes on redelivery) | [V] 2026-10-14 · AMQP 0.9.1 reference |
| ID3 | SQS id | Use an app event id, the SNS `MessageId` (SNS-fed, AW6) or `MessageDeduplicationId` (FIFO); never `ReceiptHandle` (changes per receive) | [V] 2026-10-14 · SQS Developer Guide |
| ID4 | BullMQ id | Use a business key; `job.id` only when it is a custom stable `jobId` (BQ4); never the auto id | [V] 2026-10-14 · docs *Job Ids* |
| ID5 | NATS id | Use the publisher's `Nats-Msg-Id` or the stream sequence; never the consumer delivery sequence | [V] 2026-10-14 · nats docs |
| ID6 | Redis Streams id | The entry id (stable) or the producer's `IDMP` id | [V] 2026-10-14 · redis.io |
| ID7 | Pub/Sub id | `message.id` (service retries reuse it; a client publish retry makes a new one — add an app id attribute); never `ackId` | [V] 2026-10-14 · Google Cloud docs |
| ID8 | Celery id | A business key from the arguments; `task_id` is stable per invocation, a re-`delay()` is a new id | [V] 2026-10-14 · celery docs |
| ID9 | Sidekiq id | A business key; `jid` changes per `perform_async` | [V] 2026-10-14 · sidekiq source |

## Retry and deadline libraries

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| RY1 | tenacity | Bare `@retry`: stop never, wait none, any exception — "retry forever without waiting" | [V] 2026-10-14, build · tenacity.readthedocs.io |
| RY2 | p-retry | `retries` 10 · `factor` 2 · `minTimeout` 1 s · `maxTimeout` ∞ · **`randomize` false** (no jitter) · `maxRetryTime` ∞ | [V] 2026-10-14 · p-retry README |
| RY3 | axios-retry | `retries` 3 · **`retryDelay` 0** · condition `isNetworkOrIdempotentRequestError`: idempotent methods on 5xx or network errors, **and any method — POST included — on a network error** · `shouldResetTimeout` false | [V] 2026-10-14 · axios-retry README and source |
| RY4 | got | `limit` 2 · methods GET, PUT, HEAD, DELETE, OPTIONS, TRACE, QUERY (**not POST**) · status 408, 413, 429, 5xx · `backoffLimit` ∞ · `noise` ±100 ms | [V] 2026-10-14 · got docs *Retry* |
| RY5 | go-retryablehttp | `RetryMax` 4 · wait 1–30 s · `DefaultBackoff` exponential **without jitter** · `DefaultRetryPolicy` retries transport errors, 429 and 5xx ≠ 501 **without checking the method (POST retried)**; `LinearJitterBackoff` is the jittered option | [V] 2026-10-14 · hashicorp/go-retryablehttp `client.go` |
| RY6 | Polly v8 | `RetryStrategyOptions`: `MaxRetryAttempts` 3 · `Delay` 2 s · `BackoffType` **Constant** · **`UseJitter` false** · `ShouldHandle` = every exception except `OperationCanceledException` | [V] 2026-10-14 · Polly docs |
| RY7 | .NET standard handler | `AddStandardResilienceHandler`: rate limiter → total 30 s → retry 3, exponential, **jitter on**, 2 s → breaker → attempt 10 s; handles ≥ 500, 408, 429; **retries every HTTP method, POST included** unless `DisableForUnsafeHttpMethods()`; the docs say add **one** handler. `ConfigureHttpClientDefaults(…AddStandardResilienceHandler())` applies it to every client | [V] 2026-10-14 · learn.microsoft.com *Build resilient HTTP apps* |
| RY8 | Resilience4j | Retry `maxAttempts` 3 (first call included) · `waitDuration` 500 ms **constant** · every exception | [V] 2026-10-14 · resilience4j docs |
| RY9 | Spring Framework 7 `@Retryable` | Core `@Retryable` / `RetryTemplate` (`@EnableResilientMethods`, Nov 2025): `maxRetries` 3 (4 invocations) · `delay` 1 s · any exception; jitter and multiplier opt-in. A second retry layer over Spring Retry, Resilience4j or a Kafka error handler is the nested shape | [V] 2026-10-14 · Spring Framework 7.0 reference |
| RY10 | AWS SDKs | Standard mode is the default (legacy still the default in the Java, Python, Ruby, PHP and C++ SDKs and the CLI): `max_attempts` **3** (DynamoDB 4) · full jitter `random(0,1) × min(20 s, base × 2^n)`, base 50 ms (transient) / 1 000 ms (throttling) · a retry quota of 500 tokens. **2026: the updated retry behaviour is opt-in through `AWS_NEW_RETRIES_2026=true`** until it becomes the default — gate 3 reads the SDK version **and** the environment. An SDK call inside another retry loop is nested retry; `maxAttempts: 1` plus one outer layer is the clean form | [V] 2026-10-14, build · docs.aws.amazon.com *SDKs and Tools reference — Retry behavior*; [K?] per-SDK minimum versions and the default-flip date |
| RY11 | gRPC deadlines | No deadline by default ("effectively forever"); propagation automatic in Java and Go, explicit in C++; Node and Python: treat as manual. The deadline travels as a remaining timeout | [V] 2026-10-14 · grpc.io *Deadlines* |
| RY12 | cenkalti/backoff v5 | `InitialInterval` 500 ms · `RandomizationFactor` 0.5 (jittered) · `Multiplier` 1.5 · `MaxInterval` 60 s | [V] 2026-10-14 · source; [K?] v5's elapsed and try caps |

Cross-references: BullMQ attempts and backoff (BQ2), Celery (CY3), Sidekiq (RB1), Spring Kafka
(KA7), kafkajs (KJ4), Temporal activities (WK6), redlock `retryCount` (LO2).

## Locks, leases and leader election

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| LO1 | Redis lock pattern | `SET k v NX PX <ms>`; release compares the value — **`DELEX key IFEQ value` (Redis ≥ 8.4)** or the GET-compare-DEL Lua script; a plain `DEL` can delete another client's lock. The page now tells users to implement **fencing tokens**, and notes expiry runs on the wall clock (RD4) | [V] 2026-10-14, build · redis.io *Distributed locks*, `DELEX` |
| LO2 | node-redlock | npm `latest` is **5.0.0-beta.2** (2022-03-06): `acquire(resources, ttl)`; `lock.extend(ms)` returns a **new** `Lock`; `using(resources, ttl, async (signal) => …)` auto-extends, and on a failed extension **fires the `AbortSignal` — the routine must check `signal.aborted`**; `retryCount: -1` = unbounded | [V] 2026-10-14 · npm registry; node-redlock README |
| LO3 | redis-py `Lock` | redis 8.1.0: **`timeout=None` default — the lock never expires**; `blocking=True` with `blocking_timeout=None` waits forever; `thread_local=True`; `with r.lock(…)` raises if not acquired; release is a Lua token compare; `extend()` raises on a lock with no timeout | [V] 2026-10-14, build · redis-py `redis/lock.py` |
| LO4 | Redisson | Watchdog `lockWatchdogTimeout` 30 s renews while the JVM lives; **passing `leaseTime` disables the watchdog**; `tryLock(wait, lease, unit)` returns boolean; `RFencedLock` (`lockAndGetToken()`) exists, first version 3.19.0; `RedLock` deprecated | [V] 2026-10-14 · redisson.pro *Locks and synchronizers*; [K?] the `leaseTime` rule (implied, not stated) and the 3.19.0 date |
| LO5 | ShedLock | 7.10.1: `lockAtMostFor` is the safety lease (a task past it may run twice); `lockAtLeastFor` the minimum hold; **assumes synchronised clocks** (`usingDbTime()` for JDBC); no fencing token | [V] 2026-10-14 · ShedLock README |
| LO6 | go-redsync | v4.18.0: expiry 8 s · tries 32 · `Lock()` returns `error` · `Unlock()` / `Extend()` return `(bool, error)` with **`ErrLockAlreadyExpired`** — a `defer mutex.Unlock()` drops "the lock expired while you worked" | [V] 2026-10-14 · redsync `mutex.go` |
| LO7 | DistributedLock (.NET) | madelson 2.8.3: `TryAcquire*` returns **null** when not acquired (default timeout 0); `HandleLostToken` signals a lost connection | [V] 2026-10-14 · README |
| LO8 | client-go leader election | v0.37.1: the package doc says it **does not guarantee that only one client acts as leader** (no fencing); requires `LeaseDuration > RenewDeadline > 1.2 × RetryPeriod`; tolerant of clock skew, not of skew *rate* | [V] 2026-10-14 · `tools/leaderelection/leaderelection.go` |
| LO9 | etcd | v3.7.2: lease + `concurrency.Mutex`; the fencing token is the key's revision, checked with a `Txn(If(ModRevision …))` | [K?] · API name not re-read |
| LO10 | PostgreSQL advisory locks | Session locks (`pg_advisory_lock`, `pg_try_advisory_lock`) persist until unlocked or the session ends and ignore rollback; `pg_advisory_xact_lock` releases at transaction end. Through a pool, a session lock can be unlocked on another connection; a transaction-mode pooler hands the session to others | [K] · PostgreSQL docs *Advisory lock functions*, not re-read |

## Schedulers and migration runners

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| SD1 | @nestjs/schedule | 12.0.2: `SchedulerRegistry.addCronJob` / `addInterval` / `addTimeout` register with no `@Cron` text at the call site; `ScheduleModule.forRoot({ cronJobs, intervals, timeouts })` is the per-process off-switch | [V] 2026-10-14 · package `dist/` typings and explorer |
| SD2 | sidekiq-scheduler | `cron` / `at` jobs dedupe across instances; **`every` / `interval` / `in` jobs are pushed once per host** | [V] 2026-10-14 · README (v6) |
| SD3 | Laravel scheduler | `onOneServer()` needs a shared cache store; closures need `->name()`; `withoutOverlapping()` lock expires after 24 h; a timezone schedule may run twice or not at all across DST | [V] 2026-10-14 · laravel.com *Task Scheduling* 12.x |
| SD4 | gocron v2 | 2.22.0: without `WithDistributedElector` / `WithDistributedLocker` every instance runs every job; `WithSingletonMode` is per process | [V] 2026-10-14 · pkg.go.dev |
| SD5 | Temporal Schedules | Overlap policy default **Skip**; `AllowAll` permits concurrent runs; catch-up window default **1 year** | [V] 2026-10-14 · docs.temporal.io *Schedule* |
| SD6 | Kubernetes CronJob | `concurrencyPolicy` default `Allow`; "approximately once" — two Jobs or none are possible; `.spec.timeZone` stable since 1.27, `CRON_TZ` / `TZ` in the schedule rejected | [V] 2026-10-14 · kubernetes.io *CronJob* (modified 2026-05-13) |
| SD7 | Quartz, RedBeat | Quartz clusters only with a JDBC store and `isClustered=true`, node clocks within 1 s; celery-redbeat 2.4.2 takes its beat lock by default (`redbeat_lock_key = None` disables it) | [V] 2026-10-14 · quartz-scheduler.org; redbeat `schedulers.py` |

Migration runners at boot — cross-process lock (owner: `precedents/performance.md` § 77; cited by
`precedents/distributed.md` § 24). **Yes** clears a startup migration on a lock-capable database
behind a session-mode pooler or none; **No** and **Opt-in** stay candidates unless the run is a
Job, an init container or a release step.

| # | Runner | Version read | Lock | Tag · date · source |
|---|---|---|---|---|
| MG1 | Prisma Migrate | 8.0.0-rc.22 | **Yes** (PG `pg_advisory_lock`, 10 s timeout; off with `PRISMA_SCHEMA_DISABLE_ADVISORY_LOCK`) | [V] 2026-10-14 · prisma docs; lock id from secondary sources |
| MG2 | Rails | main | **Yes** (`with_advisory_lock`, `ConcurrentMigrationError`; breaks under a transaction-mode pooler) | [V] 2026-10-14 · `activerecord/lib/active_record/migration.rb` |
| MG3 | Flyway | docs | **Yes** (PG advisory lock; `postgresql.transactional.lock` default true) | [V] 2026-10-14 · Redgate docs |
| MG4 | Liquibase | master | **Yes** (`DATABASECHANGELOGLOCK` row; a killed process leaves it locked) | [V] 2026-10-14 · `StandardLockService.java` |
| MG5 | Knex | 3.3.0 | **Yes** (`knex_migrations_lock` row in a transaction) | [V] 2026-10-14 · `Migrator.js` |
| MG6 | golang-migrate | v4.20.1 | **Yes** (PG `pg_advisory_lock`) | [V] 2026-10-14 · `database/postgres/postgres.go` |
| MG7 | EF Core | ≥ 9 | **Yes** for `Migrate()`, `database update` and bundles (SQL scripts do not; SQLite's lock table can be abandoned) | [V] 2026-10-14 · learn.microsoft.com EF Core 9 *What's new*; [K?] Npgsql/Pomelo specifics |
| MG8 | goose | v3.29.0 | **Opt-in** (`NewPostgresSessionLocker` passed to the Provider; default no lock) | [V] 2026-10-14 · goose `lock/postgres.go` |
| MG9 | MikroORM | migrations 7.2.5 | **No** (no lock in the package) | [V] 2026-10-14 · package source grep |
| MG10 | TypeORM | 1.1.2 | **No** (a transaction, no lock) | [V] 2026-10-14 · `MigrationExecutor.js` |
| MG11 | Drizzle | drizzle-orm 0.45.4 | **No** (reads the last row outside the transaction) | [V] 2026-10-14 · `pg-core/dialect.js` |
| MG12 | Sequelize + Umzug | umzug 3.8.3 | **No** cross-host lock (`FileLocker` is per host) | [V] 2026-10-14 · `lib/file-locker.js` |
| MG13 | Django | 6.1.2 | **No** | [V] 2026-10-14 · `migrations/executor.py` grep; Django forum t/21283 |
| MG14 | Alembic | 1.20.0 | **No** (users add `pg_advisory_lock` in `env.py`) | [V] 2026-10-14 · `runtime/migration.py` grep |

## Workflow engines and sagas

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| WK1 | Temporal TypeScript | `@temporalio/workflow` 1.24.0: the sandbox **replaces `Date.now()`, `new Date()`, `Math.random()` and `setTimeout()` with deterministic versions** — not replay hazards. The TS hazards: Node or I/O imports in the workflow bundle, `process.env`, `crypto.randomUUID()`, value-imports of activity implementations, branching on `workflowInfo().unsafe.isReplaying`; `ignoreModules` is the escape hatch. Versioning `patched()` / `deprecatePatch()`; replay `Worker.runReplayHistories` | [V] 2026-10-14, build · docs.temporal.io *TypeScript workflow basics*, *Testing suite* |
| WK2 | Temporal Go | sdk v1.49.0: `workflow.Now`, `workflow.Sleep`, `workflow.Go`, `workflow.GetVersion`. **`workflowcheck` v0.6.0** flags `time.Now`, `time.Sleep`, global `math/rand`, `crypto/rand.Reader`, `os.Stdin/Stdout/Stderr`, goroutines, channel use, **map range**; suppression `//workflowcheck:ignore`; misses global-variable mutation; needs compilable code | [V] 2026-10-14 · sdk-go `contrib/tools/workflowcheck` README |
| WK3 | Temporal Java | 1.40.0: `System.currentTimeMillis`, `Instant.now`, `new Random`, `UUID.randomUUID`, `Thread.sleep`, threads, `CompletableFuture` are forbidden in workflow code (use `Workflow.*`); versioning `Workflow.getVersion`; replay `WorkflowReplayer` | [V] 2026-10-14 · docs *Java workflow basics* |
| WK4 | Temporal Python | 1.34.0: a runtime sandbox; `workflow.now()`, `workflow.random()`, `workflow.uuid4()`; **`asyncio.sleep` in a workflow is a durable timer**; sandbox off via `UnsandboxedWorkflowRunner()` or `@workflow.defn(sandboxed=False)` | [V] 2026-10-14 · docs *Python workflow basics* |
| WK5 | Temporal .NET | 1.20.0: `Task.Run`, `Task.Delay`, `Thread.Sleep`, `Task.WhenAny/WhenAll`, `ConfigureAwait(false)`, `DateTime.Now/UtcNow`, `Guid.NewGuid`, `Random` forbidden (`Workflow.*` replacements); a runtime listener throws on off-scheduler tasks; no first-party analyzer | [V] 2026-10-14 · docs *.NET workflow basics*; NuGet |
| WK6 | Temporal activities | An activity **must** set Start-To-Close or Schedule-To-Close (neither → rejected at schedule time); heartbeat timeout default 0 (off); **default retry: 1 s initial, ×2.0, max 100 × initial, unlimited attempts, no non-retryable types**; workflows have no retry policy by default | [V] 2026-10-14, build · docs.temporal.io *Retry policies* (the retry defaults); *Detecting activity failures* (the required timeout) |
| WK7 | Temporal limits | History **51 200 events / 50 MB** (warnings at 10 240 / 10 MB); payload 2 MB per request; 2 000 incomplete activities, signals or children per execution | [V] 2026-10-14 · docs *Cloud limits* (self-hosted defaults may differ, [K?]) |
| WK8 | Durable Task | `Microsoft.DurableTask.Analyzers` 1.26.0: DURABLE0001 `DateTime.Now/UtcNow` · 0002 `Guid.NewGuid` · 0003 `Task.Delay`/`Thread.Sleep` · 0004 threads and `Task.Run` · 0005 direct I/O · 0006 environment · 0011 `while (true)` without ContinueAsNew. JS and Python orchestrators must be **generators**, never `async`. In-process model support ends **2026-11-10** | [V] 2026-10-14 · durabletask-dotnet `AnalyzerReleases.Shipped.md`; learn.microsoft.com *Code constraints* (2026-10-12) |
| WK9 | Step Functions | Task `TimeoutSeconds` and `HeartbeatSeconds` default **99 999 999** (about 3.2 years) | [V] 2026-10-14 · docs.aws.amazon.com *Task state* |
| WK10 | Inngest, Restate | Inngest 4.23.0: code outside `step.run` re-executes on every resume; step ids and order must stay stable for in-flight runs. Restate 1.17.3: side effects in `ctx.run`; `ctx.rand`, `ctx.date.now()` are journaled | [V] 2026-10-14 · inngest.com *Working with loops*; docs.restate.dev |
| WK11 | Saga compensation | Temporal Java `Saga`: `setParallelCompensation(false)` default → **reverse order of registration**; `setContinueWithError(false)` default → the first failing compensation stops the rest. Go: a compensation in `defer` needs `workflow.NewDisconnectedContext(ctx)` or it never runs on cancellation. Register a compensation **before** an activity that can fail after mutating state | [V] 2026-10-14 · temporal-sdk 1.40.0 `Saga.java`; docs *Go cancellation*; community.temporal.io (guidance, not docs) |

## Event contracts and event stores

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| SZ1 | buf | v1.73.0: `buf breaking --against '.git#branch=<base>'`; categories FILE (default) → PACKAGE → **WIRE_JSON (recommended minimum)** → WIRE | [V] 2026-10-14 · buf.build *Breaking rules* |
| SZ2 | Avro | Spec 1.12.0: a reader field without a default that the writer lacks is an **error**; an unknown writer enum symbol uses the reader's enum `default`, else an error; renames only through aliases | [V] 2026-10-14 · avro.apache.org spec (2026-10-01) |
| SZ3 | Confluent Schema Registry | **`BACKWARD` default, checked against the latest version only**; `BACKWARD_TRANSITIVE` checks all; Protobuf: transitive recommended | [V] 2026-10-14 · Confluent Platform 8.3 docs (2026-06-29) |
| SZ4 | AsyncAPI CLI | `@asyncapi/cli` 6.2.1: `asyncapi diff OLD NEW -t breaking` **exits non-zero on a breaking change unless `--no-error`** | [V] 2026-10-14 · cli `docs/usage.md` |
| SZ5 | json-schema-diff | 1.0.0: fails when anything the old schema accepted is now rejected | [V] 2026-10-14 · npm README |
| SZ6 | Tolerant-reader defaults | Jackson `new ObjectMapper()` has **`FAIL_ON_UNKNOWN_PROPERTIES` on** (Spring Boot's auto-configured mapper turns it off); System.Text.Json ignores unknown members unless `UnmappedMemberHandling.Disallow`; pydantic ignores extras unless `extra="forbid"`; zod `z.object` strips unknown keys unless `.strict()` | [V] 2026-10-14 · Spring Boot how-to; library docs |
| SZ7 | oasdiff | v1.33.0: `oasdiff breaking base.yaml head.yaml --fail-on ERR` (event payloads in OpenAPI webhooks only). The npm name `oasdiff` is a security placeholder — never `npm i oasdiff` | [V] 2026-10-14 · oasdiff README; npm registry |
| EV1 | KurrentDB Node | `@kurrent/kurrentdb-client` 1.3.1: **`appendToStream(stream, events)` defaults `streamState` to `ANY` — no optimistic-concurrency check**; values `ANY`, `NO_STREAM`, `STREAM_EXISTS` or a revision; a conflict throws `WrongExpectedVersionError` | [V] 2026-10-14, build · KurrentDB-Client-NodeJS `packages/db-client/src/streams/appendToStream/index.ts` (`@defaultValue ANY`) |
| EV2 | KurrentDB .NET / Python | `KurrentDB.Client` 1.5.0 `AppendToStreamAsync(stream, StreamState, events)` and `kurrentdbclient` 1.3.3 `append_to_stream(…, current_version=…)`: `StreamState.Any` = no check | [V] 2026-10-14 · client docs; [K?] .NET parameter order |
| EV3 | Marten | 9.50.1: `FetchForWriting<T>(id)` is the recommended optimistic path; `Append(id, expectedVersion, events)` needs `EventAppendMode.Rich` (the default is Quick); plain `Append(id, events)` has no guard; each async projection runs on **exactly one** process; Postgres sequence gaps from rolled-back transactions (the high-water mark) | [V] 2026-10-14 · martendb.io *Appending events*, *Async daemon* |

## Clocks

| # | Subject | Fact | Tag · date · source |
|---|---|---|---|
| TM1 | Go monotonic clock | `time.Now()` carries a monotonic reading used by `Sub`, `Since`, `Until`, `Before`, `After`, `Equal`, `Compare`; **stripped by `Round(0)`, `Truncate`, `AddDate`, `In`, `Local`, `UTC`; omitted by JSON, binary, text and gob encoding** — a time from another process compares on the wall clock | [V] 2026-10-14 · pkg.go.dev `time` (go1.27.2) |
| TM2 | Monotonic APIs | Node `performance.now()` / `process.hrtime.bigint()` · Java `System.nanoTime()` · Python `time.monotonic()` / `perf_counter()` · .NET `Stopwatch` / `Environment.TickCount64` · Go `time.Since(start)` with an in-process start | [K] · platform docs |
| TM3 | Wall-clock expiry | Redis expiry (RD4), ShedLock (LO5) and Quartz clustering (SD7) assume synchronised wall clocks | [V] 2026-10-14 · the rows cited |
| TM4 | Token time checks | node-jsonwebtoken `clockTolerance` 0 with seconds-based timestamps; PyJWT `leeway` 0; Spring Security 60 s; Microsoft.IdentityModel 5 min. Token checks are security's; DS keeps a skew note only | [V] 2026-10-14 · `verify.js`; [K?] the Spring and .NET values (secondary sources) |

## Dated changes that move findings

| Date | Product | Change | Rows |
|---|---|---|---|
| 2023-02-27 | kafkajs | last release (2.2.4); unmaintained since | KJ1 |
| 2025-03 | Apache Kafka 4.0 | ZooKeeper removed; Streams `exactly_once` / `exactly_once_beta` removed | KA5 |
| 2025-09-15 | sqs-consumer 14 | a void handler no longer deletes the message | AW4 |
| 2025-11 | Spring Framework 7.0 | core `@Retryable` — a possible second retry layer | RY9 |
| 2025-12-08 | NATS (Jepsen 2.12.1) | default fsync interval loses acknowledged writes; `sync_interval: always` | NA4 |
| 2026-01-06 | MassTransit 9.0 | commercial licence; 8.x stays Apache-2.0 | NT1 |
| 2026-04-23 | RabbitMQ 4.3.0 | `basic.nack` no longer counts toward the quorum delivery limit | RQ2 |
| 2026-07-30 | BullMQ 6.0.0 | legacy `repeat` removed (Job Schedulers) | BQ1 |
| 2026 (opt-in) | AWS SDKs | updated retry behaviour behind `AWS_NEW_RETRIES_2026=true` until it becomes the default | RY10 |
| 2026-11-10 | Azure Durable Functions | in-process model support ends | WK8 |

Sources: the distributed-systems research catalog (2026-10-14) and its notes A (BullMQ, Kafka,
RabbitMQ, SQS/SNS, NATS, Redis Streams, Pub/Sub, Celery, Sidekiq, Rails, Laravel, .NET, librdkafka,
Go clients, outbox and CDC, the stable-id table), B (locks, leader election, schedulers, migration
runners, workflow SDKs, sagas, schema formats, event stores, clocks) and C (retry and deadline
library defaults, the AWS Builders' Library, Google SRE ch. 21–22, Jepsen NATS 2.12.1), each fact
read at the named source on 2026-10-14; and the batch-5 distributed-systems eval (2026-10-14) § 3.1.
Licences: project docs and source under their own licences (MIT, Apache-2.0, BSD, MPL-2.0, CC BY
4.0); paraphrased, no text reproduced beyond short quoted identifiers and option names.
