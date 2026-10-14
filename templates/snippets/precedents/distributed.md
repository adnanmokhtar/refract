# Precedents — Distributed systems (delivery, ordering, dual write, retries and deadlines, locks and leases, schedulers, workflows and sagas, event contracts and event sourcing, clocks)

Read by the verifier under [`refute-before-report.md`](../refute-before-report.md) § 4 for every
candidate in a **distributed-systems** class: a redelivery, a crash between two writes, a paused
lock holder, a retry, a rebalance, a deploy or a skewed clock turns into a lost, duplicated,
reordered or stale effect. The oracles that prove them are in
[`proof-oracles.md`](../proof-oracles.md) § Distributed (V291–V327). The library, broker and SDK
defaults every verdict rests on are rows of [`broker-semantics.md`](../broker-semantics.md): a
verdict that depends on a default names its row, and a verdict that names none is invalid. The
detectors are `messaging-scan`, `dual-write-scan`, `retry-deadline-scan`, `coordination-scan`,
`workflow-scan` and `event-contract-scan` (distributed-systems pack), run by `/ds-audit` and closed
by `/ds-fix`. `@resilience-reviewer` judges the first four (`@system-architect` with it on leader
rows), `@workflow-orchestrator` the workflow rows and `@event-sourcing-architect` the contract and
event-sourcing rows; without them, `@verifier` in refute mode.

**Owned elsewhere.** A neighbour that sees the same site lists it as corroboration, deduped by
`file:line`; without the owner's pack the row is tagged `<class> (owner pack not installed)` and
listed, never graded as the owner would grade it. Publish or enqueue **inside** a transaction is
database `transaction-scan` §1 (V8); an outbox claim without `SKIP LOCKED` is database §5; a lost
update mid-saga is database §8 (V5). Idempotency on money, stock and credit effects, check-then-act
on a balance and PSP idempotency keys are security `logic-race-scan` §4–§5. A store per replica and
a lease with no fencing on a side effect are performance `request-path-scan` §18 (V38);
once-per-fleet schedulers and migrations at boot are §20 (V40); worker capacity is §23; timeout
presence is §12. Lambda, EventBridge and SQS-to-Lambda timing are infrastructure
`serverless-reliability-scan` §1–§6; proxy timeout chains and proxy retries are
`edge-reliability-scan` §1, §3. Trace context across a queue hop is observability
`trace-propagation-scan` §2.

Each entry names when a pattern that *looks* like a defect is not one, and the evidence that flips
it back. A match makes the candidate **Hardening** (or Refuted, where the entry says so) unless the
flip evidence is shown with a `file:line`, a config value or a recorded oracle run. Numbers are
stable: detectors cite `precedents/distributed.md § <n>`.

Index: the claim and the gates · delivery and acknowledgement § 1–7 · ordering § 8–9 · dual write
and outbox § 10–13 · retries and deadlines § 14–18 · locks, leases, leaders and schedulers § 19–24 ·
workflows and sagas § 25–27 · contracts and event sourcing § 28–30 · clocks § 31 · scope and
evidence § 32–33 · real-repo precedents § 34–36 · rationalizations.

## The claim, restated

§ 1 of the protocol takes this shape here. A candidate that fits it with no concrete value is not a
finding.

> Under **[redelivery / a crash between X and Y / a rebalance / a paused holder / clock skew / a
> retry / a deploy with open executions]**, **[the consumer, job, handler, lock holder or workflow
> at file:line]** performs **[the effect]** without **[a reserve / an outbox / fencing / a version
> check / a version gate]**, which causes **[a duplicate charge / a lost event / a stale overwrite /
> a replay break]**, proven by **[the V-number and its tier]**.

**Two parts, refuted separately.** Part A says *what the snippet is*: "this is the consumer", "this
is a retry", "this is the lock". Part B says *what the defect is*, given the `broker-semantics.md`
row it rests on. Part A is cheap to refute and is refuted first: polling, a reconnect loop or a
periodic job is not a retry (§ 16); a cache key is not a lock; a producer is not a consumer. In the
WASABI study 29 of 60 false positives were non-retry code labelled retry.

**The proof rule.** A grep hit is a candidate. The class oracle in `proof-oracles.md` § Distributed
at its tier is the proof:

| Tier | What it is |
|---|---|
| **C** | A container oracle: Testcontainers (or `docker run`) with the real broker or store, Toxiproxy for faults, small real durations for Redis TTL and BullMQ lock expiry, a fake clock only for client-side backoff and clock skew |
| **T** | A tool's exit: `workflowcheck`, a DURABLE analyzer, `buf breaking`, `asyncapi diff`, `json-schema-diff`, typescript-eslint `no-floating-promises`, `errcheck`, ruff `RUF006`, Error Prone `FutureReturnValueIgnored` |
| **S** | A static fact with both ends cited: visibility or lock vs the p99 run time, `max.poll.records × p99` vs `max.poll.interval.ms`, a Celery ETA vs `visibility_timeout`, a lease TTL vs the work's bound, attempts × layers — each term with its `file:line` or its `broker-semantics.md` row |
| **L** | A live, read-only broker or engine read (`--live` only, credentials from the user's environment); without it `NO-DATA(<broker>)` |

A Finding needs C or T, or an S-tier fact with both ends cited. A mocked broker is never C (§ 33).
A managed broker or cache with no parameter group in the repo prints its server-side default as
`UNREAD (<service>)`, and every row resting on it is **Unconfirmed** with the setting to read.

## Reading the seven gates for distributed systems

| Gate | Distributed systems |
|---|---|
| 1 Reachability | The consumer, job, relay or workflow is registered and runs in a deployed process: the module that registers it, the worker entry point, the process role (an API image vs a worker image, a role switch). A processor class no module registers is dead code |
| 2 Trigger | The failure really occurs. Redelivery is always possible under at-least-once delivery; so are a crash between two writes, a rebalance, a paused holder (a GC pause, a long await, `SIGSTOP`), a retry, a deploy with open executions, a clock step and a DST transition |
| 3 Version | The `broker-semantics.md` row **at the installed version**: client versions from manifests and lockfiles, server versions from images, compose or IaC. A managed service with no parameter group in the repo is `UNREAD`. **Never from memory**: no version found → the version-gated rows are Unconfirmed with the probe written out |
| 4 Existing control | **Cross-file**, never the matched line alone: the base processor class, `defaultJobOptions` / `registerQueue`, decorators and interceptors, error-handler beans, `ConfigureHttpClientDefaults`, the outbox port's implementation, the claims ledger, the project's lock helper, broker definitions or IaC (in this repo or another, § 5). Read the whole file and its callees: a check 20 lines below the hit refutes it |
| 5 Impact | A lost, duplicated, reordered or stale effect that someone relies on: an order, stock, a customer message, a fact another service consumes. Money is security's. An advisory push, a cache warm or a refresh ping is efficiency only (§ 10, § 19) |
| 6 Proof | The oracle fired failing first at its tier (above), or the S-tier two-ended fact. A mocked broker never passes (§ 33) |
| 7 Environment | Replicas and autoscalers (HPA, KEDA `ScaledObject`), process roles, which process imports which module, the process time zone (`TZ` in the image or manifests, a JVM `-Duser.timezone`), the pooler mode. One replica does **not** make a delivery or dual-write row latent (§ 32) |

## Delivery and acknowledgement

1. **Auto-commit with a fully awaited handler is at-least-once, not ack-before-process.** kafkajs commits only resolved offsets (`broker-semantics.md` KJ2); a raw Java consumer commits at the next `poll()` only what the previous poll returned (KA1); Spring Kafka forces auto-commit off (KA6). *Flips back:* work handed to an executor, an in-memory buffer or an un-awaited promise; `spring.kafka.consumer.enable-auto-commit: true`; confluent-js periodic commit with an early return (KJ7); librdkafka `enable.auto.offset.store=true`, which stores the offset when the message is *handed* to the app (LD1).
2. **A naturally idempotent effect needs no inbox:** an upsert by business key, a conditional transition (`WHERE status = 'pending'`), SET not INCREMENT, a provider call with an idempotency key derived from the business id. **Amended (real repo, 2026-10-14) — a third reserve shape:** an effect table that carries the event id, read through an anti-join (`not exists (select 1 from ledger l where l.event_id = e.id)`), *is* the reserve; a claims table beside it coordinates in-flight work and does not need to be atomic with the effect. *Flips back:* the key is a broker delivery id that changes on redelivery (`deliveryTag`, `ReceiptHandle`, a BullMQ auto id, a Sidekiq `jid`, an SQS `MessageId` behind SNS — rows ID1–ID9), or the guard is read-then-write.
3. **An in-memory dedupe set is never a reserve** (its per-replica half is performance `request-path-scan` §18). No precedent clears it.
4. **"Exactly-once" settings clear producer duplicates only:** Kafka transactions and Streams `exactly_once_v2` cover Kafka → Kafka (KJ8, KA5); SQS FIFO dedupe is a 5-minute send window (AW2); a JetStream `Nats-Msg-Id` is a 2-minute publish window (NA3); Pub/Sub exactly-once is ack semantics within the deadline, pull only, one region (GP2); BullMQ `deduplication` is admission only (BQ5). None clears consumer idempotency for an external effect.
5. **A DLQ configured elsewhere is a control once read** — an infrastructure repo, broker definitions, Terraform, a broker policy. Not read → Unconfirmed with the file to read, never a Finding (mirrors `precedents/performance.md` § 81).
6. **At-most-once by written decision is not ack-before-effect** — telemetry, presence, cache pings; `maxStalledCount: 0` for jobs that must never run twice. *Flips back:* the effect moves money or sends a message, and no alert watches the failed set.
7. **A bounded nack is not a requeue loop:** an attempt counter (`x-death`, `NumDelivered >= N → Term()`, `attemptsMade`) checked before the requeue, or `reject` on a quorum queue with a DLX and `x-delivery-limit` (a reject increments the delivery count). *Flips back:* `basic.nack` on RabbitMQ ≥ 4.3 relying on the delivery limit (RQ2); a classic queue (RQ3).

## Ordering

8. **Ordering matters only where a per-key invariant needs it** — a state machine, a balance, last-write semantics. Commutative effects, append-only logs and per-user notifications do not care. *Flips back:* the handler overwrites state from the payload with no version check.
9. **Per-key serialisation is the control:** kafkajs `partitionsConsumedConcurrently` (per-partition order kept, KJ9), Spring `concurrency` ≤ partitions, an SQS `MessageGroupId` per entity, a RabbitMQ single active consumer, a version or sequence guard on the write (`WHERE version < :v`, `ON CONFLICT … WHERE excluded.seq > t.seq`).

## Dual write and outbox

10. **Commit-then-publish of an advisory, re-derivable event with a written reconciler is not a dual write** — cache-bust pings, "refresh" notifications. *Flips back:* another service relies on the fact (an order placed, a payment captured).
11. **A framework outbox is the control:** the Spring Modulith publication registry (with republish and staleness configured, OX4), the MassTransit EF/Mongo outbox (NT2), the NServiceBus outbox, the Wolverine durable outbox, CAP, the Watermill forwarder, the Debezium Outbox Event Router on an insert-only table (OX1), GoodJob or Solid Queue **in the same database connection** (OX7). After-commit enqueue (Rails, Celery `delay_on_commit`, Laravel `afterCommit`, Sidekiq `after_commit`) clears the *phantom* (database V8) but **not** the loss window (OX5).
12. **At-least-once relay publishing is correct.** The finding is a relay that marks before the publish is confirmed, a consumer without a reserve, or a gap-blind cursor.
13. **`WHERE id > $last` is safe with one serial writer** (a single-connection appender, an advisory-locked appender) or a log-ordered source (Debezium). The same rule covers every **watermark minted before commit**: a sequence `nextval`, a `now()` / `created_at` default (the transaction's start, not its commit), an app-side UUIDv7 or ULID. `createdAt > :since` over rows that concurrent transactions stamp is gap-blind exactly like `id > $last`. Also safe: a floor held back by a lag longer than the longest transaction, plus a periodic rescan that dedupes (the residual is clock skew, `coordination-scan` § 8). *Flips back:* concurrent transactions write the compared column and the cursor advances to the newest value it read, with no lag and no rescan (`dual-write-scan` § 6, V301 gap variant). *Also flips back — the double take:* even with one serial writer, a mark read in one statement and the rows summed or collected in a second, both under READ COMMITTED, are two snapshots: a row committing between them, stamped after the mark, is taken by this pass and again by the next when the sum is not bounded by the mark it saves. Cleared by one statement (the mark computed inside the sum's query), REPEATABLE READ or SERIALIZABLE around both, the sum bounded by the saved mark (`<= mark`; the gap rule above still applies), or each row stamped with the collection that took it (`dual-write-scan` § 6, the double-take variant).

## Retries and deadlines

14. **Exactly one retrying layer per call chain is the design** (AWS Builders' Library; Google SRE: retry only at the layer immediately above the one rejecting). A missing circuit breaker alone is Hardening — AWS prefers a local retry token bucket to a breaker's modal behaviour, and the baseline row RES-2 allows `n-a` with the reason it cannot cascade. *Flips back:* two or more layers retry the same call (the SDK, a wrapper, job `attempts`, broker redelivery, an activity's policy).
15. **Library defaults decide "no cap / no backoff / no jitter":** read them at the installed version (rows RY1–RY12): tenacity bare = forever with no wait; axios-retry delay 0, POST excluded except on network errors; p-retry unjittered; got 2 retries, POST excluded, ±100 ms noise; Polly v8 constant and unjittered; Resilience4j constant 500 ms; go-retryablehttp unjittered and retries POST; the .NET standard handler jittered but retries POST; the AWS SDK's standard mode full jitter with a retry quota, its 2026 behaviour opt-in through `AWS_NEW_RETRIES_2026=true`; Spring Kafka `DefaultErrorHandler` 10 attempts, 0 delay (KA7); Temporal activities unlimited attempts (WK6).
16. **Polling, spin-locks and periodic re-execution are not retry** (WASABI's largest false-positive class). Retry is re-executing the same failed operation.
17. **Retrying a POST is safe when the server stores the client's idempotency key** (Stripe-style keys, the EC2 client token, the IETF Idempotency-Key draft header) — verify the server half (gate 4).
18. **Background work without a deadline is not a missing deadline** when lateness is harmless (reports, cleanup). *Flips back:* a user-facing command that is wrong once late (an OTP, a reservation hold, a price quote).

## Locks, leases, leaders and schedulers

19. **An efficiency lock needs no fencing** — duplicate work is harmless (`precedents/performance.md` § 75 agrees). **Amended (real repo, 2026-10-14):** name the advisory case in the finding — a websocket or SSE push, a cache warm or a "refresh" ping is efficiency only — and write which case it is. *Flips back:* the protected code sends mail, charges or inserts without a unique key.
20. **A lock scoped to the DB transaction that does the write is its own fence** (`pg_advisory_xact_lock`, `SELECT … FOR UPDATE` in the same transaction, LO10). ShedLock, Quartz JDBC clustered and Laravel `onOneServer` are once-per-fleet controls; a lease whose side effects run past `lockAtMostFor` is still a lease shorter than the work (LO5).
21. **A library-managed release is owner-checked** — redlock `release()`, redis-py `with lock`, Redisson `unlock()`, redsync `Unlock()` (LO2–LO6). **Amended (real repo, 2026-10-14):** so is one atomic compare-and-delete — a Lua `if get == token then del`, or `DELEX key IFEQ token` on Redis ≥ 8.4 (LO1). A `GET`, a compare in the app, then a `DEL` in a second round trip is the **narrow release-without-owner-check**: LOW when no await or I/O sits between them, MEDIUM when the holder can pause between the read and the delete (a GC pause, a long await). The fix is the project's own atomic helper when one exists. *Flips back:* a hand-written `DEL` of the same key elsewhere (a cleanup cron, an admin endpoint) reachable from production.
22. **Kubernetes Lease leader election does not guarantee one acting leader** (client-go package doc, LO8). Leader work needs fencing or idempotence, or the process must exit on loss. Not a clearing precedent: a leader that keeps acting after loss stays a candidate.
23. **A scheduler module imported only by a single-replica worker is cleared** (the `precedents/performance.md` § 73 shape). *Flips back:* an HPA or a second Deployment imports it.
24. **Migration runners that take a lock clear a migration at boot** — on a lock-capable database behind a session-mode pooler or none. **Amended:** this entry follows `precedents/performance.md` § 77, which owns the class; the dated per-runner table (which runners lock and wait, which skip or fail the others, which take no lock, goose opt-in, EF Core ≥ 9) is § 77's — the same rows, with sources, are `broker-semantics.md` MG1–MG14 — and is cited, not restated. The class's owner is devops `deploy-safety-scan` §1 when that pack is installed.

## Workflows and sagas

25. **TS Temporal `Date.now()`, `Math.random()` and `setTimeout` are sandbox-deterministic** — not workflow non-determinism (WK1). *Flips back:* the module is in `ignoreModules`, or a custom loader bypasses the sandbox. Python `asyncio.sleep` / `gather` on workflow coroutines are durable (WK4).
26. **The pivot step, and retriable steps after it, need no compensation;** a single-database "saga" needs a transaction, not compensations; a written irreversibility acceptance clears a missing compensation.
27. **Temporal Java `Saga` defaults compensate in reverse order of registration** (WK11), which clears the order half; `continueWithError = false` (stop at the first failing compensation) is a design choice.

## Contracts and event sourcing

28. **Additive, optional changes are compatible:** an Avro field with a default, a new protobuf field number, a JSON field for tolerant readers (SZ1–SZ6). A strict reader on an **outbound** DTO is not an intolerant reader.
29. **`streamState: ANY` is correct for append-only facts with no invariant** — audit, telemetry (EV1). *Flips back:* any decision made from loaded state before the append.
30. **Library event stores own the uniqueness constraint** — Marten, the Axon JPA store, the Python `eventsourcing` library (EV3): a custom-table uniqueness finding does not apply.

## Clocks

31. **Wall-clock timestamps are fine for display, audit and single-store TTLs** (Redis `PX`, the database's `now()` on one primary). *Flips back:* ordering or last-write-wins across hosts, or a duration that guards a lease or a timeout (TM1–TM3).

## Scope and evidence

32. **One replica by design makes cross-replica rows latent** (`precedents/performance.md` § 73), but redelivery, rebalance and broker crashes happen on one replica too: delivery and dual-write classes are **not** latent on a single replica.
33. **Mocked brokers prove nothing about delivery semantics** — `Queue::fake()`, eager Celery, an in-memory MassTransit harness. `@EmbeddedKafka` is acceptable for ordering and poison only. A proof needs the real broker in a container.

## Real-repo precedents (batch-5 eval, read-only run, 2026-10-14)

34. **A comment or a doc that claims a guarantee is a pointer, not evidence.** "`noeviction`", "idempotent", "one replica", "the far end dedupes" are read in the config, the schema or the callee, or the row is Unconfirmed with the file to read (`refute-before-report.md` § 7). A managed Redis or Valkey with no parameter group in the repo leaves `maxmemory-policy` `UNREAD` whatever the comment says (RD5).
35. **A schedule with no time zone in a UTC process is not a DST defect.** UTC means `TZ` unset in the image and manifests, or set to UTC. *Flips back:* `ENV TZ=<a DST zone>`, a JVM `-Duser.timezone`, a host-mounted `/etc/localtime`, or an explicit DST `timeZone` at a time inside the transition hour.
36. **A job deadline that aborts the work is the control for "a retry runs beside the original"** — an `AbortSignal` (or a cancelled context) threaded into the outbound calls. *Flips back:* the deadline only rejects the promise and the work keeps running (`Promise.race` without an abort).

## Rationalizations to reject (distributed systems)

**Wrongly accepting:** "every external call needs a retry and a breaker" (§ 14: one retrying layer;
a breaker only where it can cascade) · "`Date.now()` in a workflow" in TypeScript (§ 25) · "no DLQ"
when the failed set is kept and alerted on, or the DLQ lives in another repo (§ 5) · "kafkajs is
unmaintained", reported as a defect (a migration note, KJ1) · "retries without jitter" when the
installed library jitters by default (§ 15) · "41 crons without a time zone" in a UTC process
(§ 35) · "the advisory push can be lost" (§ 19) · "the relay may publish twice" (§ 12) · "MassTransit
9 fixes it" as a fix (a licence change, NT1).

**Wrongly dismissing:** "we use exactly-once" (§ 4) · "the comment says `noeviction`" (§ 34) · "we
dedupe on the message id" (which id — rows ID1–ID9) · "we enqueue after commit, so there is no dual
write" (§ 11: the loss window stays) · "the lock has a TTL" (is the TTL longer than the work, and is
the `extend()` result checked?) · "the test passes" on `Queue::fake()` (§ 33) · "one replica, so no
duplicates" (§ 32) · "the job has a deadline" (`Promise.race` without an abort, § 36) · "attempts are
bounded" (count the layers, § 14) · "`basic.nack` is bounded by the delivery limit" on RabbitMQ ≥ 4.3
(§ 7) · "the handler returns, so sqs-consumer deletes it" on sqs-consumer ≥ 14 (AW4).

---

Sources: the distributed-systems research catalog (2026-10-14) § 4 (precedents 1–33) and its notes
A (messaging per stack, outbox and inbox), B (locks, leaders, schedulers, migration runners,
workflow engines, sagas, contracts, event sourcing, clocks) and C (retries and deadlines — the AWS
Builders' Library, Google SRE ch. 21–22 — the WASABI study, SOSP '24, and the AWS 2025-10-19
summary); and the batch-5 distributed-systems eval (2026-10-14) § 3.5, which amended precedents 2,
19, 21 and 24 and added 34–36 from a read-only real-repo run (NestJS 11, BullMQ 6.3, MikroORM 6.6,
ioredis on managed Valkey). Paraphrased; no text reproduced beyond short quoted identifiers.
