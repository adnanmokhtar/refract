# messaging-scan — stack lanes beyond Node

Loaded by [`SKILL.md`](SKILL.md) only when its F1 line printed the stack. Each lane gives the client versions to read, the [`broker-semantics.md`](../../../../snippets/broker-semantics.md) rows its verdicts rest on, the pre-flight greps with their § and tested status, the read questions and the decoys. The § numbers are `SKILL.md`'s; the rules, boundaries, oracles (V291–V299) and halts there apply unchanged. Grep ids are the research notes A ids (SK, RMQ, SQS, NATS, RS, GPS, CEL, SQ, RAILS, LAR, LRK, MT, GO). **Tested** means every BAD line of the research samples hit and the GOOD sample printed nothing it should not (2026-10-14); **untested** greps narrow only — reading decides. Line-level greps miss multi-line config literals (Go struct literals, C# initializers, YAML blocks): read the file around every hit and every consumer F2 lists.

Run the arrays block once, then the lanes F1 printed, in the same script. Include globs first, exclusions last (the last matching glob wins); every `rg` names its path.

```bash
ROOTS=(.)   # the server-side code; config greps search .
X=(-g '!**/node_modules/**' -g '!**/{dist,build,out,target,bin,obj,vendor,.venv,venv,__pycache__,coverage,generated}/**'
   -g '!**/{test,tests,__tests__,spec,specs,e2e,fixtures,__fixtures__,mocks,__mocks__,testdata}/**'
   -g '!**/*{Test,Tests,IT,Spec}.{java,kt,cs}' -g '!**/*_test.go' -g '!**/test_*.py' -g '!**/*_test.py' -g '!**/conftest.py' -g '!**/*_spec.rb'
   -g '!**/{migrations,migration,db/migrate,alembic/versions,seeders,seeds}/**' -g '!**/{docs,ai,.claude}/**')
PY=(-g '*.py'); JV=(-g '*.{java,kt}'); GO=(-g '*.go'); CS=(-g '*.cs'); RB=(-g '*.rb'); PHP=(-g '*.php')
CFG=(--hidden -g '*.{yml,yaml,properties,json,conf,tf,env}' -g '!.git/**' -g '!**/node_modules/**' -g '!**/{test,tests,fixtures,testdata}/**' -g '!**/{package-lock,composer}.json')
NC=(rg -v --pcre2 '^[^:]+:\d+:\s*(?://|/\*|\*(?:\s|/|$)|#)')
```

## Java and Kotlin — Spring Kafka, the Kafka clients, Kafka Streams, Spring AMQP

F1: `spring-kafka`, `kafka-clients`, `kafka-streams`, `spring-rabbit`, `amqp-client`, `spring-cloud-aws-sqs` in `pom.xml` / `build.gradle*`. Rows: KA1–KA11 (Spring Kafka forces auto-commit off, `AckMode.BATCH`; `DefaultErrorHandler()` = 10 attempts, no delay, then log-and-skip; whole-batch retry; idempotence silently off under `acks` ≠ all, `retries=0`, `max.in.flight` > 5; Streams 4 rejects `exactly_once`), RQ6 (Spring AMQP requeues a rejected message by default), AW5 (Spring Cloud AWS `ALWAYS`).

```bash
# J1 §1 SK-01 ack before the effect (MANUAL_IMMEDIATE); SK-04 a poll loop handing records to an executor (auto-commit then commits them) — tested
rg -n --no-heading -U --pcre2 '@KafkaListener[^\n]*\n(?:\s*@[^\n]*\n)*\s*public\s+[^\n{]*\bAcknowledgment\s+(\w+)[^\n{]*\{\s*\n\s*\1\.acknowledge\(\)' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | rg --pcre2 '@KafkaListener'
rg -n --no-heading -U --pcre2 'for\s*\(\s*(?:final\s+)?(?:ConsumerRecord<[^>]*>|var)\s+\w+\s*:\s*[\w.()]+\s*\)\s*\{\s*\n(?:[^\n]*\n){0,5}?[^\n]*(?:\bexecutor\w*\.(?:submit|execute)\(|CompletableFuture\.(?:runAsync|supplyAsync)\()' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | rg --pcre2 '\bfor\b'
# J2 §1 RMQ-01 auto-ack (Java client, Spring AMQP); §3 RMQ-03 requeue on reject — tested
rg -n --no-heading --pcre2 '\bbasicConsume\(\s*[^,]+,\s*true\s*,|AcknowledgeMode\.NONE\b|\bbasic(?:Nack|Reject)\((?:[^()]|\([^()]*\))*,\s*true\s*\)|setDefaultRequeueRejected\(\s*true' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading --pcre2 'acknowledge[-_]mode\s*[:=]\s*["\x27]?none\b|default[-_]requeue[-_]rejected\s*[:=]\s*["\x27]?true' "${CFG[@]}" . | "${NC[@]}"
# J3 §3 SK-02 an error handler with no recoverer; the repo-level absences (no DeadLetterPublishingRecoverer; a batch listener with no BatchListenerFailedException) — tested
rg -n --no-heading --pcre2 'new\s+DefaultErrorHandler\(\s*(?:\)|new\s+(?:Fixed|Exponential\w*)BackOff\b)' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -l --pcre2 'DeadLetterPublishingRecoverer|ConsumerRecordRecoverer|@DltHandler|AmqpRejectAndDontRequeueException|RejectAndDontRequeueRecoverer|BatchListenerFailedException' "${JV[@]}" "${X[@]}" "${ROOTS[@]}"
# J4 §5 §7 §11 SK-05 config that disables idempotence, weak acks, auto-commit back on, removed EOS names; max.poll.records for the §5 arithmetic — tested
rg -n --no-heading --pcre2 '(?i)(?:\backs["\x27]?\s*[:=,]\s*["\x27]?(?:0|1)\b|ACKS_CONFIG\s*,\s*"(?:0|1)"|enable[._-]idempotence["\x27]?\s*[:=,]\s*["\x27]?false|ENABLE_IDEMPOTENCE_CONFIG\s*,\s*(?:false|"false")|MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION\s*,\s*"?(?:[6-9]|\d{2,})|max[._-]in[._-]flight[._-]requests[._-]per[._-]connection["\x27]?\s*[:=]\s*["\x27]?(?:[6-9]|\d{2,})|enable[._-]auto[._-]commit["\x27]?\s*[:=,]\s*["\x27]?true|ENABLE_AUTO_COMMIT_CONFIG\s*,\s*(?:true|"true")|processing[._-]guarantee["\x27]?\s*[:=,]\s*["\x27]?exactly_once(?:_beta)?\b(?!_v2)|\bretries["\x27]?\s*[:=]\s*["\x27]?0\b|max[._-]poll[._-](?:records|interval[._-]ms))' "${JV[@]}" "${CFG[@]}" "${X[@]}" . | "${NC[@]}"
# J5 §4 §7 SK-06 Kafka + DB "transactions", external effects inside Streams, retry topics on an ordered stream; SK-03 a send whose result is dropped — tested
rg -n --no-heading --pcre2 '\bChainedKafkaTransactionManager\b|\.(?:foreach|peek)\(\s*\([^)]*\)\s*->[^\n]*(?:[rR]estTemplate|[wW]ebClient|[rR]estClient|[rR]epository|jdbcTemplate|httpClient)|@RetryableTopic\b|^[ \t]*(?!return\b)[\w$.]*[kK]afkaTemplate\.send(?:Default)?\([^;]*\)\s*;' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# J6 §5 SK-08 manual commits with a bare subscribe (no ConsumerRebalanceListener) — untested; read revocation handling
rg -l0 --pcre2 '\bcommit(?:Sync|Async)\(' "${JV[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -0 -r rg -H -n --no-heading --pcre2 '\.subscribe\(\s*(?:List\.of|Arrays\.asList|Collections\.singletonList|Pattern\.compile|\w+)\s*\)\s*;'
```

Read: which `AckMode`, and where `acknowledge()` sits on every path; the one `CommonErrorHandler` bean or each factory's; is the value deserializer an `ErrorHandlingDeserializer` (a bad payload otherwise fails before the listener); `max.poll.records × p99` against `max.poll.interval.ms`, both cited; does every consumer of a transactional topic set `read_committed` (KA3; the consumer may live in another repo: Unconfirmed). F2 locates `@KafkaListener` / `@RabbitListener` only; their factory and error handler are a read step. Decoys: a synchronous raw poll loop under auto-commit (precedent 1; still §2 for duplicates); `acks=1` on a metrics topic with a written loss budget; `new DefaultErrorHandler()` in a test configuration; `@RetryableTopic` on commutative events. Dual write (`repo.save` then `kafkaTemplate.send`) is `dual-write-scan` §1.

## Python — Celery, pika, boto3 SQS, redis-py Streams, confluent-kafka

F1: `celery`, `kombu`, `pika`, `aio-pika`, `boto3`, `redis`, `confluent-kafka`, `aiokafka`, `dramatiq`, `rq` in `requirements*.txt` / `pyproject.toml`. Rows: CY1–CY5 (Celery acks on receipt; `max_retries=None` is forever; Redis/SQS `visibility_timeout` 1 h vs a longer ETA re-runs the task), RQ5 (pika requeues by default), LD1–LD4 (confluent-kafka: the offset store, idempotence off, CRC32 partitioner), RD1, RD3.

```bash
# P1 §1 CEL-05 no acks_late anywhere (every task acks on receipt) — the file list is empty when the repo never sets it; RMQ-01 pika auto_ack — tested
rg -l --pcre2 '\backs_late\s*=\s*True\b|\btask_acks_late\s*=\s*True\b|\bCELERY_TASK_ACKS_LATE\s*=\s*True\b|\btask_reject_on_worker_lost\b' "${PY[@]}" "${X[@]}" "${ROOTS[@]}"
rg -n --no-heading --pcre2 '\bauto_ack\s*=\s*True\b|\bno_ack\s*=\s*True\b' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# P2 §1 SQS-01 delete before the work in a boto3 receive loop — tested
rg -n --no-heading -U --pcre2 '^[ \t]*for\s+\w+\s+in\s+[^\n]*Messages[^\n]*\n[^\n]*\.delete_message(?:_batch)?\(' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | rg --pcre2 '\bfor\b'
# P3 §2 §3 CEL-02 unbounded or catch-all autoretry on an effect; §3 pika nack/reject that requeues — tested
rg -n --no-heading --pcre2 '\bmax_retries\s*=\s*None\b|\bautoretry_for\s*=\s*\(\s*Exception\s*,?\s*\)|\bbasic_nack\((?![^)]*requeue\s*=\s*False)[^)]*\)|\bbasic_reject\((?![^)]*requeue\s*=\s*False)[^)]*\)' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# P4 §6 CEL-01 an ETA or countdown ≥ 4,000 s (compare with visibility_timeout, CY4); CEL-03 the transport options and broker URL that decide it — tested
rg -n --no-heading --pcre2 '\bcountdown\s*=\s*(?:[4-9]\d{3}|\d{5,}|[\d_]+\s*\*\s*(?:60\s*\*\s*60|3600|86400))|\beta\s*=|["\x27]visibility_timeout["\x27]\s*:\s*\d+|\bbroker_transport_options\b|\bBROKER_TRANSPORT_OPTIONS\b|\b(?:broker_url|BROKER_URL|CELERY_BROKER_URL)\b' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# P5 §1 §4 §7 LRK-01/02 confluent-kafka consumers that keep the auto offset store, producers with idempotence off or a non-murmur2 partitioner — tested
rg -n --no-heading --pcre2 '\bConsumer\(\s*\{(?![^\n]*(?:enable\.auto\.offset\.store["\x27]?\s*:\s*(?:False|false|["\x27]false)|enable\.auto\.commit["\x27]?\s*:\s*(?:False|false|["\x27]false)))|["\x27]enable\.idempotence["\x27]\s*:\s*(?:False|false|["\x27]false)|["\x27]partitioner["\x27]\s*:\s*["\x27](?:consistent_random|consistent|random|fnv1a\w*)["\x27]' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# P6 §8 §9 Redis Streams: XREADGROUP with no count, MAXLEN/MINID trims with no ACKED — tested
rg -n --no-heading -i --pcre2 '\bxreadgroup\((?![^\n]*\bcount\s*=)|\bx(?:add|trim)\((?![^\n]*ACKED)[^\n]*\b(?:maxlen|minid)\s*=' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# P7 §3 an except with no raise in a task or consumer file (X-SWALLOW, Python) — untested on this lane's samples; read each
rg -l0 --pcre2 '@(?:\w+\.)?(?:shared_task|task)\b|\bbasic_consume\(|\.receive_message\(|\bxreadgroup\(|\bConsumer\(' "${PY[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -0 -r rg -H -n --no-heading -U --pcre2 '^\s*except\b[^\n]*:\s*\n(?:(?!\s*(?:raise|self\.retry|return\s+self\.retry)\b)[^\n]*\n){1,6}?(?=\S|\s*$)' | rg --pcre2 '\bexcept\b'
```

Read: the broker URL (Redis/SQS: visibility applies; RabbitMQ: `consumer_timeout`, RQ8) against the longest ETA and run; per task `acks_late`, `reject_on_worker_lost`, the retry class list, cap and backoff (`ds-inventory.py --lane=celery` resolves the decorator and `app.conf`); where exhausted tasks go. `CELERY_TASK_ALWAYS_EAGER` is not an oracle (precedent 33). Decoys: early ack on a re-derivable task (cache warmers, precedent 6); a long countdown on RabbitMQ; `autoretry_for=(Exception,)` on a pure read. `Order.objects.create` then `.delay` is `dual-write-scan` §1 (inside `atomic` → database `transaction-scan` §1).

## Go — kafka-go, franz-go, sarama, confluent-kafka-go, Watermill, NATS

F1: `go.mod` lines for `segmentio/kafka-go`, `twmb/franz-go`, `IBM/sarama`, `confluent-kafka-go`, `ThreeDotsLabs/watermill*`, `nats-io/nats.go`. Rows: GL1–GL4, LD1–LD5, NA1–NA4.

```bash
# G1 §1 GO-01 kafka-go ReadMessage with a GroupID (commits at read) and franz-go GreedyAutoCommit — tested; GO-03 sarama MarkMessage first — untested
rg -n --no-heading --pcre2 '\.ReadMessage\(\s*ctx\s*\)|\bkgo\.GreedyAutoCommit\(\)' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading -U --pcre2 'for\s+\w+\s*:=\s*range\s+claim\.Messages\(\)\s*\{\s*\n\s*\w+\.MarkMessage\(' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | rg --pcre2 '\brange\b'
# G2 §1 NATS-01 ack policy None/All and ack before the work; §3 NATS-02 a bare Nak, NATS-03 consumer configs with no MaxDeliver on the line; §1 §7 NATS-04 core subscribe and JetStream publish with no msg id — tested
rg -n --no-heading --pcre2 '\bAck(?:None|All)Policy\b|\.Nak\(\s*\)|(?:jetstream\.ConsumerConfig|nats\.ConsumerConfig|CreateOrUpdateConsumer|AddConsumer)\b(?![^\n]*\bMaxDeliver\b)|\bnc\.(?:Subscribe|QueueSubscribe)\(|\bjs\.(?:Publish|PublishAsync)\((?![^\n]*(?:WithMsgID|MsgId|Nats-Msg-Id))' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
rg -n --no-heading -U --pcre2 '\bfunc\s*\(\s*(\w+)\s+(?:jetstream\.Msg|\*nats\.Msg)\s*\)\s*\{\s*\n\s*\1\.(?:Ack|AckSync)\(\)' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | rg --pcre2 '\bfunc\b'
# G3 §3 GO-02 Watermill handler files with no Retry or PoisonQueue middleware (the router may add them elsewhere: repo-level check) — tested
rg -l0 --pcre2 '\.Add(?:NoPublisher|Consumer)?Handler\(' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -0 -r rg --files-without-match --pcre2 'middleware\.(?:Retry|PoisonQueue\w*)|PoisonQueue'
# G4 §6 NATS-05 consumers with no InProgress (compare the handler's run with AckWait 30 s, NA1) — untested in Go; read
rg -l0 --pcre2 '\.(?:Consume|Messages|Fetch)\(' "${GO[@]}" "${X[@]}" "${ROOTS[@]}" | xargs -0 -r rg -l0 --pcre2 'jetstream|nats\.' | xargs -0 -r rg --files-without-match --pcre2 'InProgress\('
```

Read: the `ReaderConfig` (`ReadMessage` without a `GroupID` does not commit); explicit `FetchMessage` + `CommitMessages` commits cumulatively per partition, so out-of-order concurrent completion then commit is §1 (GL1); `errcheck` (golangci-lint) is the tool lane for dropped `Publish`/`WriteMessages`/`Ack` errors (§7). `tx.Commit()` then `Publish` is `dual-write-scan` §1. Decoys: `AckNonePolicy` on a telemetry stream; `Nak()` guarded by `NumDelivered >= N → Term()` (precedent 7); `nc.Subscribe` for request/reply with caller-side retries.

## .NET — Confluent.Kafka, MassTransit, Azure Service Bus

F1: `PackageReference` for `Confluent.Kafka`, `MassTransit*`, `Azure.Messaging.ServiceBus`, `RabbitMQ.Client`, `NServiceBus`, `WolverineFx`, `DotNetCore.CAP`. Rows: LD1–LD4, NT1–NT3 (MassTransit 9 is commercial: never recommend the upgrade; `UseInMemoryOutbox` is not durable).

```bash
# N1 §1 §4 §7 LRK-01/02 consumers keeping the auto offset store; producers with weak acks, idempotence off or a non-murmur2 partitioner — tested
rg -n --no-heading --pcre2 '\bnew\s+ConsumerConfig\b(?![^\n]*(?:EnableAutoOffsetStore\s*=\s*false|EnableAutoCommit\s*=\s*false))|\bEnableIdempotence\s*=\s*false\b|\bAcks\s*=\s*Acks\.(?:None|Leader)\b|\bPartitioner\s*=\s*Partitioner\.(?:ConsistentRandom|Consistent|Random)\b' "${CS[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# N2 §1 §3 MT-02 in-memory outbox, discarded faults, hot immediate retries, receive-and-delete — tested
rg -n --no-heading --pcre2 '\bUseInMemory(?:Inbox)?Outbox\b|\bDiscard(?:Faulted|Skipped)Messages\(\)|\br\.Immediate\(\s*(?:[1-9]\d+|int\.MaxValue)\s*\)|\br\.Interval\(\s*int\.MaxValue|\bReceiveMode\s*=\s*ServiceBusReceiveMode\.ReceiveAndDelete\b' "${CS[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
```

Read: the MassTransit major and outbox flavour; `UseMessageRetry` × broker redelivery × delayed redelivery is a multiplied retry (`retry-deadline-scan` §4); `CS4014` is the tool lane for an un-awaited `Publish`/`ProduceAsync` (§7). `SaveChangesAsync` then `Publish` (MT-01) is `dual-write-scan` §1. Decoys: `UseInMemoryOutbox` on a consumer with no database write; `Acks.Leader` on telemetry.

## Ruby — Sidekiq, Active Job, Solid Queue, GoodJob

F1: `Gemfile` / `Gemfile.lock` for `sidekiq` (and `sidekiq-pro`), `solid_queue`, `good_job`, `rails`. Rows: RB1–RB4 (OSS Sidekiq loses in-progress jobs on a crash; `retry: false` discards; after-commit enqueue keeps the loss window, OX5).

```bash
# R1 §3 SQ-01 jobs that discard on failure; RAILS-03 retry_on with no attempts (inventory) — SQ-01 tested, RAILS-03 untested
rg -n --no-heading --pcre2 'sidekiq_options\b[^\n]*\b(?:retry:\s*(?:false|0)\b|dead:\s*false\b)|\bretry_on\s+\w+(?![^\n]*attempts:)|\bdiscard_on\b' "${RB[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
# R2 §1 SQ-04 OSS Sidekiq with no super_fetch (in-progress jobs lost on a crash) — repo-level; both lines empty or the first non-empty decides
rg -n --no-heading --pcre2 "gem\s+['\"]sidekiq(?:-pro|-ent)?['\"]" -g '**/Gemfile' .
rg -l --pcre2 'super_fetch!' "${RB[@]}" "${X[@]}" "${ROOTS[@]}"
# R3 §2 RAILS-01 per-job opt-out of after-commit enqueue (the phantom half → database transaction-scan §1) — tested
rg -n --no-heading --pcre2 'enqueue_after_transaction_commit\s*=\s*(?:false|:never)\b' "${RB[@]}" "${X[@]}" "${ROOTS[@]}" | "${NC[@]}"
```

Read: each job's effect class against RB1 (a money job on OSS Sidekiq with no reconciliation is §1, Unconfirmed until V291 runs); `sidekiq-unique-jobs` is admission, not idempotency (§2); Solid Queue on a separate `queue` database is not an outbox (RB4). `after_save` enqueues are database `transaction-scan` §1; `Order.create!` then `perform_async` is `dual-write-scan` §1.

## PHP — Laravel queues

F1: `laravel/framework` in `composer.json`. Rows: LV1, LV2 (`--timeout` must stay below `retry_after`; `$tries = 0` is unlimited).

```bash
# H1 §6 LAR-01 timing inventory (compare --timeout and $timeout with retry_after); §1 §3 LAR-03 unlimited tries, afterResponse, in-process drivers, after_commit off — tested
rg -n --no-heading --pcre2 "['\"]retry_after['\"]\s*=>|\bpublic\s+(?:int\s+)?\\\$timeout\s*=\s*\d+|\bqueue:work\b[^\n]*--timeout[= ]\d+|\bRETRY_AFTER\s*=|\bpublic\s+(?:int\s+)?\\\$tries\s*=\s*0\b|->afterResponse\(\)|\bQUEUE_CONNECTION\s*=\s*(?:sync|deferred|background)\b|['\"]after_commit['\"]\s*=>\s*false" "${PHP[@]}" -g '**/.env*' -g '**/Dockerfile*' -g '**/*.{yml,yaml,conf,sh}' "${X[@]}" . | "${NC[@]}"
```

Read: per job `$timeout` vs the connection's `retry_after` (both cited, tier S); `ShouldBeUnique` and `WithoutOverlapping` are admission and locks, not idempotency (`expireAfter` vs run time → `coordination-scan` §4). `Queue::fake()` is not an oracle (precedent 33). `Model::create` then `dispatch` (LAR-02) is `dual-write-scan` §1; the `deferred` and `background` drivers hold work in process memory → performance `request-path-scan` § 22.

## Google Cloud Pub/Sub

F1: `@google-cloud/pubsub`, `google-cloud-pubsub`, `cloud.google.com/go/pubsub`. Rows: GP1, GP2 (DLQ needs the service agent's IAM; exactly-once is pull-only, one region, `ackWithResponse`). GPS-01..04 are **untested**: narrowing only.

```bash
# S1 §1 GPS-01 an ack as a statement (read its position against the effect); §2 GPS-02 exactly-once settings (pair with ackWithResponse); §3 GPS-03 dead-letter policy and its IAM; §4 GPS-04 ordering keys
rg -n --no-heading --pcre2 '\bmessage\.ack\(\)\s*;?\s*$|enableExactlyOnceDelivery|exactly_once_delivery|enable_exactly_once_delivery|ackWithResponse|ack_with_response|dead_letter_policy|deadLetterPolicy|max_delivery_attempts|maxDeliveryAttempts|gcp-sa-pubsub|orderingKey|ordering_key|messageOrdering|enable_message_ordering|resumePublishing' -g '*.{ts,js,py,go,java,tf}' "${X[@]}" . | "${NC[@]}"
```

Read: a subscription with a dead-letter policy and no publisher/subscriber binding for the Pub/Sub service agent silently never dead-letters (GP1, §3). The emulator's DLQ and exactly-once support is [K?]: prove those oracles in a throwaway project, never against the user's.

## confluent-kafka-javascript (Node, non-compat API) and node-rdkafka

These ride librdkafka (LD1–LD5), not kafkajs: the Node lane's 1c/1d do not apply. The Python LRK grep shape applies to their `{ 'enable.auto.offset.store': … }` config objects; read every `new Kafka.KafkaConsumer(` / `Consumer(` config for the offset store and every producer for `enable.idempotence` and `partitioner` (LD4: a CRC32 producer and a murmur2 producer on one topic split a key across partitions). The KafkaJS-compat API keeps kafkajs shapes with a periodic 5 s commit (KJ7): a handler that returns early is §1 under it.

## Measured (2026-10-14)

| Tree | Result |
|---|---|
| Research samples, non-Node lanes (Java + Spring YAML, Python pika / Celery / boto3 / redis-py / confluent-kafka, Go kafka-go / franz-go / Watermill, NATS Go, .NET, Ruby, PHP) | 0.2 s, 0 rg errors. Every BAD line of the tested greps surfaces: J1 ack-first listener and executor hand-off (1 + 1), J2 auto-ack, requeueing nack and `AcknowledgeMode.NONE` in Java and YAML (3 + 2), J3 two `DefaultErrorHandler`s with no recoverer, J4 7 config lines (`acks` 1, `max.in.flight` 10, auto-commit back on, `max-poll-records` 2000, idempotence false, Streams `exactly_once`), J5 chained transaction manager, an HTTP call in `foreach`, `@RetryableTopic`, a dropped `kafkaTemplate.send`; P2 delete-first boto3 loop, P3 unbounded/catch-all autoretry and requeueing pika nack/reject (4), P4 countdown 86 400, an ETA, a 7 200 s retry countdown and the 300 s visibility, P5 offset store and CRC32 partitioner, P6 `xreadgroup` with no count and `maxlen` with no ACKED; G1 `ReadMessage` + `GreedyAutoCommit`, G2 AckAll/AckNone, bare `Nak`, core subscribe, msgID-less publish, ack-first JetStream (5 + 1), G3 a Watermill handler with no middleware; N1 auto offset store and weak producer acks, N2 in-memory outbox / discarded faults / `Immediate(50)` / receive-and-delete; R1 `retry: false`, R3 the commit opt-out; H1 `$tries = 0`, `afterResponse`, `retry_after`. Presence lists (J3 second line, P1, G4) print the good samples by design. GOOD files print nothing else except H1's timing inventory line |
| Seeded by nobody yet (untested): J6 (SK-08), P7 (Python X-SWALLOW), G1 second line (GO-03 sarama), R2 (SQ-04), S1 (GPS-01..04) | Narrowing only; the `ds-defects` fixture (eval § 3.7) carries their seeds |
| `benchmarks/fixtures/*` (18) and the real repository | 0 lines, except obs-defects P4 (a Celery broker URL from the environment: the inventory line that says the Redis visibility caveat applies). A first draft of H1 matched every `--timeout` in CI and Dockerfile `HEALTHCHECK` lines (ci-defects 7, the real repository 2): now scoped to `queue:work` |
