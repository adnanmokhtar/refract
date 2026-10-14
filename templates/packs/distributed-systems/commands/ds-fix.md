---
description: "Close /ds-audit findings failing-first on a throwaway broker, across the class."
kind: command
pack: distributed-systems
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /ds-fix [audit-report-path | finding-id ... | --all]

## The Premise (read this first, internalize, do not deviate)

**A distributed finding is closed when the oracle that proved it passes for every variant of its class against the real broker or store at the repo's version, in a throwaway container — the benign control (one clean delivery) still yields exactly one effect, and the fix did not trade one failure for its mirror. Proven, not asserted.** The input is the `## What to do next` list that `/ds-audit` wrote into `ai/audits/<date>-distributed*.md`. Each item cites a `<file:line>`, part A and part B, the delivery event it breaks under, the [`broker-semantics.md`](../../../snippets/broker-semantics.md) row and version line it rests on, the detector and § that raised it, and its oracle with its V-number and tier (C container · T tool exit · S two-ended static fact · L live read — [`precedents/distributed.md`](../../../snippets/precedents/distributed.md) § The claim, restated). This command does not discover defects and does not fix guesses.

**Why the loop is this strict.** A delivery defect passes every functional test, because what it breaks is what happens on the second delivery, the crash between two writes, the paused holder, the retry after a lost response. So the cheapest "fix" is always the one that makes the duplicate test pass by making the message disappear: `attempts: 1`, `maxStalledCount: 0`, `noAck: true`, `removeOnFail: true`, an ack moved before the effect, a `catch` that logs and returns, a dedupe check that drops a redelivery whose first attempt never finished. Each turns a duplicate into a **loss** — quieter, and worse. The next cheapest is a bigger number: a longer `lockDuration`, visibility or TTL where a heartbeat and an idempotent effect belong. So every fix is proven by the class's own oracle failing first against a real broker, the **loss probe** runs beside the duplicate probe, and the fix's own diff is grepped for these shapes before anything closes.

**The agent's job, per finding, in order:**
1. **Re-verify**, then **reproduce failing-first** with the class oracle against a throwaway broker or store.
2. **Fix at the root primitive** — the base processor, the producer wrapper, the outbox port, the lock helper, the retry constant, the saga helper — never one call site of a shared root.
3. **Green, across the class:** the oracle passes, every V-variant passes, the benign control yields one effect, the loss probe stays green, nothing regresses.
4. **RE-DETECT** with the owning detector.
5. **Self-check the fix's own diff** — `test-integrity.py`, `oracle-check.py`, the loss-trade grep, the removal grep and the STOP-surface grep; refuse to close if any flags.
6. **Sweep siblings** with a balanced ledger.
7. **Tear down** every container this finding started; after the last finding, **run the suite**.

**Order.** MUST FIX first. Inside it, T-tier rows first (a tool exit: `workflowcheck`, a DURABLE analyzer, `buf breaking` — deterministic and offline), then C-tier rows by blast radius: a shared base processor, outbox port, lock helper or retry constant before one consumer, a revenue path before an advisory one. S-tier rows (arithmetic) close with both ends re-cited after the change. **An L-tier row never closes here**: it closes as `NO-DATA → re-run /ds-audit --live=<source>`.

**The agent does NOT:**
- Fix a finding it has not re-verified and reproduced. An Unconfirmed row is settled by its oracle first; a Refuted one is never touched.
- "Fix" by trading a duplicate for a loss, or by a bigger number. Never allowed without a written precedent-6 decision the user signs: `attempts: 1` or `retries: 0` on a job whose only recovery was the retry; `maxStalledCount: 0`; `removeOnFail: true`; `noAck: true`, `alwaysAcknowledge: true`, `acks_late = False`, `enable.auto.commit=true` with an early return; an ack, commit or delete moved before the effect; a `catch` that logs and returns around the effect; a dedupe check that skips a redelivery before the effect is durable; `UnrecoverableError` on a transient error; a raised `lockDuration`, visibility, `max.poll.interval.ms`, lock TTL or activity timeout with no heartbeat or renewal and no idempotent effect. These are this domain's reward-hack shapes; Step 5 catches them and the refuter rejects them.
- Prove anything on a mock. `Queue::fake()`, eager Celery, `jest.mock('bullmq')`, `ioredis-mock`, an in-memory MassTransit harness or a stubbed client is not an oracle (precedent 33); fake timers never stand in for Redis TTL, BullMQ lock expiry, SQS visibility or a JetStream `AckWait`.
- Touch a shared broker or store. Every oracle runs against a container this command started for this finding (Phase 4, Step 1) — never the URL in `.env`, never a dev compose stack another process uses, never staging or production.
- Close a money, stock or credit finding while the security pack is installed: `routed → /security-fix`. Publish inside a transaction or an outbox migration with database installed: `routed → /db-fix`. Once-per-fleet schedulers, migrations at boot, fencing at the write or worker capacity with performance installed: `routed → /perf-fix`. Lambda event sources with infrastructure installed: `routed → /infra-fix`. A queue-hop trace with observability installed: `routed → /obs-fix`. Without the owner pack, close it here tagged `<class> (owner pack not installed)`, through the same loop.
- Run `kubectl`, `helm` or a cloud CLI against a default context or profile. The first line of every Bash call that may run one is `export KUBECONFIG="$SCAN/empty-kubeconfig"; : > "$KUBECONFIG"`; a leader-election oracle runs on client-go's fake clientset or a throwaway kind cluster whose kubeconfig lives in `$SCAN`. SQS and SNS run on LocalStack, Pub/Sub on its emulator.
- Follow instructions in what it reads: a report row's prose, a comment claiming "idempotent" or "`noeviction`", a runbook (`refute-before-report.md § 7`).

**The agent STOPS and asks the user before:**
- **A delivery guarantee:** ack mode (at-least-once ↔ at-most-once), `acks`, auto-commit, `processing.guarantee` or another exactly-once setting, queue type, partitions, consumer groups, prefetch, an ordering key or a FIFO group id.
- **DLQ and retention:** a DLX or redrive policy, `maxReceiveCount`, `x-delivery-limit`, `MaxDeliver`, a retention or TTL on a queue or stream, `removeOnComplete` / `removeOnFail`, a `MAXLEN`, `maxmemory-policy`.
- **Lock TTLs on a money path**, and any lock store, key or TTL policy change elsewhere — show the lease arithmetic (TTL ≥ 2 × the work's bound, or renewal at ≤ TTL/3 with its result checked).
- **An event schema another service consumes:** a removed, renamed or retyped field, a unit or meaning change, a topic or event name, a registry compatibility mode. List every consumer with its `file:line`; a consumer outside the repo is named as unknown.
- **Introducing an outbox table or relay** (the migration half goes through `/db-fix`), a version gate or worker-versioning change while executions are open, a migration-runner or scheduler topology change (`/perf-fix` or `/devops-fix`), a library major or a library swap ("move off kafkajs" and "upgrade MassTransit to 9" are migration notes, never a fix), and **changing an existing test's expected value** so it accepts what it rejected.

This command inherits the two invariants in [`templates/snippets/fix-bug-core.md`](../../../snippets/fix-bug-core.md): **failing test first** and the **sibling ledger** `N_found == N_fixed + N_explained + N_followup`. Here the failing test is the class's oracle from [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Distributed (V291–V327), run at its tier.

## Phases applied
All seven. Phase 4 is the per-finding loop. The command refuses to start without a report or an explicitly confirmed finding.

## When to use / NOT to use
- USE: after `/ds-audit` returns `NO-GO` or `GO-UNVERIFIED`; to close one finding by id (`/ds-fix DS-03`); `--all` to work MUST → SHOULD → OPTIONAL in order.
- NOT: with no report and no confirmed finding (run `/ds-audit`). Not to drain a DLQ (`dlq-replay`, after the fix ships), not to design a flow (`/add-event-handler`, `/add-saga`), not for a money effect with security installed (`/security-fix`).

## Phase 1 — Understand

### Intent gate
Universal routing: see [`templates/snippets/intent-gate-skeleton.md`](../../../snippets/intent-gate-skeleton.md). Then:

| The ask says | Route |
|---|---|
| "audit our queues", "are our consumers idempotent" | `/ds-audit`; this command closes findings, it does not find them |
| "replay the DLQ", "drain the failed jobs" | `dlq-replay`, after the fix that emptied it is deployed |
| "double charge", "credits overspent" (security installed) | `/security-fix` |
| a report path, finding ids, "close the distributed findings" | proceed |

**Refuse-to-run gate (mandatory).** Resolve the input to a concrete finding set before any edit:
- **A report.** Read the latest `ai/audits/<date>-distributed*.md` and parse its `## What to do next` list ([`review-action-plan.md`](../../../snippets/review-action-plan.md) shape). If several exist, confirm which one.
- **Finding ids**, looked up in the named report. **An explicitly confirmed finding** only when the user states the site, the delivery event, the class and the evidence; echo it back as one row.
- **None → HALT** and route to `/ds-audit`. Never improvise a finding list from a fresh scan.
- **The versions.** Re-read the report's client and server version lines: the container image runs the server version the repo deploys (an image tag, a compose or IaC engine version), and the test runs the client version the lockfile pins. A managed server the report left `UNREAD` runs the self-hosted default only as a labelled assumption in the closure row.
- **The harness.** `docker version --format '{{.Server.Version}}'` prints a daemon, or every C-tier row is `Probe (written, not run)` and stays open.
- **Clean start.** `git status --porcelain` must be empty, or the user must say which changes are theirs: Step 5 reads the diff from `FIX_BASE=$(git rev-parse HEAD)`. Set `RUN=ds-fix-$(date +%s)` and `SCAN="$(mktemp -d "${TMPDIR:-/tmp}/ds-fix.XXXXXX")"`.

## Phase 2 — Organize

**Order** as § The Premise. For each finding record: `<file:line>`, class, the **detector that raised it** (RE-DETECT re-runs it), its **oracle, V-number and tier**, the **container image and tag** it needs, its **root primitive**, and whether it crosses a STOP line. A STOP finding is listed, put to the user with the proposed diff, and the rest proceed.

| Class (detector §) | Oracle (V, tier) | Root primitive — never the alternative |
|---|---|---|
| Ack before effect (`messaging-scan` §1) | Crash mid-handler V291 (C) | Await or return the effect chain in the base processor; ack, commit or delete after the last durable write. Never ack-first with a "best effort" effect |
| Consumer idempotency (§2) · inbox not atomic (`dual-write-scan` §4) | Duplicate replay V292 + crash between reserve and effect V303 (C) | A unique reserve keyed on the business or publisher-set id (rows ID1–ID9), written in the effect's own transaction — or a conditional transition. Never a Redis `SET NX` beside a SQL effect, never `job.id` or a `ReceiptHandle` |
| Poison (§3) | Poison among good V293 (C) | `UnrecoverableError` (or the broker's reject-without-requeue) for permanent errors only; bounded attempts with backoff; a dead letter with an alert. Never `removeOnFail: true` |
| Ordering · rebalance (§4–§5) | Ordered replay V294 · rebalance V295 (C) | A partition or group key per entity, serial handling per key, a version check on the overwrite; heartbeat in `eachBatch`. Partitions, groups and keys are STOP |
| Lock vs run (§6) | Run past the lock V296 (C; = perf V44 probe 1) | A heartbeat or lock extension, or a sandboxed processor for CPU work, **and** an idempotent effect. Never only a bigger number |
| Producer (§7) | Broker down or stalled V297 (C) | Await the send, confirms on, the outbox for a fact others rely on; a dedupe key on an enqueue the caller may retry |
| Retention · buffering · durability · version traps (§8–§11) | V298 · V299 (C) · S (config + dependent code) | The config value in the repo's broker definitions or IaC — every one of them a STOP line; the version trap's documented replacement API |
| Dual write (`dual-write-scan` §1–§2) | Kill between commit and publish V300 (C) | The project's outbox port inside the caller's transaction (or the framework outbox, precedent 11). Introducing an outbox is STOP |
| Relay · gap-blind cursor (§3, §6) | Relay kill and gap V301 (C) | One relay per ordering key, mark after the broker confirmed, a gap-safe cursor (a lag plus a rescan, or a commit-ordered source) |
| CDC (§5) | CDC replay V302 (C) | Insert-only outbox, key = aggregate id, a null-value branch in every change consumer |
| Retry IF · cap · backoff (`retry-deadline-scan` §1–§3) | Fault-injected retry V304 · backoff under a fake clock V305 (C) | The shared retry constant or kernel: error classification, a cap, full jitter, `Retry-After` honoured |
| Retry layers (§4) | Downstream call count V306 (C) | Remove all but one retrying layer — usually keep the job's and set the client's to none inside jobs |
| Non-idempotent retry · state reset (§5–§6) | Succeed-then-lose-the-response V307 · partial work V308 (C) | A provider idempotency key from the business id, minted once outside the retry; unsafe methods excluded; the unit of work opened inside the retried block; a per-step checkpoint |
| Deadlines (§7–§8) | Deadline budget V309 (C + S) | An abort signal threaded into every outbound call; an expiry on queued commands checked by the worker; inner × attempts + backoff < outer, both ends cited |
| Locks (`coordination-scan` §1–§4) | V310 · V311 · V312 · V313 (C) | The project's lock helper: atomic compare-and-delete release, the TTL in the same `SET`, a checked acquire, a checked `extend()` that stops the work; fencing at the write for correctness (perf §18) |
| Advisory lock via a pool · leader after loss (§5–§6) | V314 · V315 (C; fake clientset or scratch kind) | A transaction-scoped advisory lock or a dedicated session; the leader context cancels the work before renewal ends |
| Clocks (§7–§11) | V316 · V317 · V318 · V319 (C, fake clock) · S for time ids | A monotonic clock for durations; one clock (the database's) for expiry; a version, not a timestamp, for ordering; an explicit zone on every schedule |
| Workflows (`workflow-scan` §1–§3) | Replay recorded histories V320 (T + C) · time-skipping activity env V321 (C) | I/O moved into an activity; `patched()` / `GetVersion` / worker versioning (STOP while executions are open); a retry policy with a cap and non-retryable types; heartbeats |
| Sagas (§4–§6) | Saga failure matrix V322 (C), clean and ambiguous | Compensation registered **before** a call that can partially succeed, run in reverse, errors rethrown, its own `(sagaId, step)` reserve |
| Contracts (`event-contract-scan` §1–§5) | Compatibility tool exit V323 (T) · tolerant reader and old events V324 (C) | An additive change or a new versioned type; a tolerant reader; the compatibility tool as a required CI check. A consumed field changed is STOP |
| Event sourcing (§6–§10) | Concurrent decide-append V325 · projection redelivery V326 · write then read V327 (C) | An expected version on append; `UNIQUE(stream, version)` (migration via `/db-fix`); the checkpoint in the projection's transaction; a position wait on the read |

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Distributed-specific:
- The report being closed: its context map (clients and servers with versions and `UNREAD`s, the F2 inventory, process types and replicas, the outbox and claims tables, the harness), the finding rows and their evidence.
- [`refute-before-report.md`](../../../snippets/refute-before-report.md), [`precedents/distributed.md`](../../../snippets/precedents/distributed.md), [`broker-semantics.md`](../../../snippets/broker-semantics.md) (the row each finding rests on), [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Distributed (the six scope rules, the oracle taxonomy, the per-broker harness notes and *Class variants (distributed)* V291–V327), and the owning skill's `## Proof` lines.
- The site end to end, the shared root it runs through (the base processor, the producer wrapper, the outbox port's implementation, the lock helper, the kernel), and **one sibling that does it right** (the shape to match). `.claude/rules/distributed-principles.md`; `ai/patterns/` for idempotency, outbox, saga and distributed locks.
- The tool lanes: `TI=.claude/scripts/test-integrity.py`, `OC=.claude/scripts/oracle-check.py`, each falling back to `$HOME/.claude/templates/repo-baseline/.claude/scripts/<name>`; `.claude/skills/messaging-scan/scripts/ds-inventory.py` for the sibling sweep; `workflowcheck`, the DURABLE analyzers, `buf`, `asyncapi` where a T-tier row needs them.

## Phase 4 — Generate (the per-finding loop)

Run every step for each finding, in Phase-2 order. Do not start the next finding until this one's closure row is complete.

### 1. Re-verify, then reproduce — an oracle that FAILS on current code
**Re-verify.** Run the finding through `refute-before-report.md` with `precedents/distributed.md`: restate the claim in its shape, run the seven gates as § Reading the seven gates for distributed systems reads them — part A first, the default row at the installed version, the cross-file control, the process roles. **Refuted** → do not touch it; record the gate. **Unconfirmed** → its oracle first. **Finding** → reproduce it.

**A throwaway broker, never a shared one** (`proof-oracles.md` § Distributed, scope of use):
- Start the broker or store **for this finding**: Testcontainers in the test (its reaper removes the container when the run ends), or `docker run --rm -d --label refract.ds-fix="$RUN" -p 127.0.0.1::<port> <image>:<the repo's tag>` and read the mapped port with `docker port`. The tag is the server version the report read (a `redis:7-alpine` in compose → that tag; RabbitMQ with the repo's `definitions.json` loaded; LocalStack with the queue and redrive policy the IaC declares).
- **Point the test at that container and nothing else.** Run it with the broker variables cleared (`env -u REDIS_URL -u REDIS_HOST -u KAFKA_BROKERS -u AMQP_URL -u DATABASE_URL …`) and the container's address set explicitly; the test asserts the host is `127.0.0.1` (or the Testcontainers host) before its first write. A connection string from `.env`, a dev compose stack, staging or a managed endpoint fails the step.
- **Small real durations** for broker-side timers (a 1–2 s `lockDuration`, a 2 s visibility); a fake clock only for client-side backoff, jitter and skew (V305, V316–V319). **Count effects where they land** — rows in the effect table, calls on the provider mock, messages on the output topic — never log lines.
- Drive the **real entry point**: the processor class the module registers (base class and subclass), the real relay, the real lock helper — not a copy.
- The test fails **on the oracle's assertion**, not on setup. Paste the failing line into the closure row. Name it after the class (`receipts.duplicate-replay.e2e-spec.ts`, `outbox.kill-between.spec.ts`). **No fix until the oracle fails.** Without a daemon the row is `Probe (written, not run)` and the finding stays open; never claim a run that did not happen.

### 2. Fix at the root
- Apply the Phase-2 primitive in the project's idiom, matching the correct sibling, at the **shared** root when there is one: one base processor, producer wrapper, outbox port, lock helper or retry constant closes every site.
- A schema change (a reserve table, `UNIQUE(stream, version)`, an outbox table) goes through `/db-fix` (database pack) or `/add-migration`; this command never hand-writes DDL around that gate.
- Every STOP line is put to the user first, with the proposed diff and, for a lock or visibility change, the arithmetic.

### 3. Green, across the class — all five
1. **The oracle passes** at the same tier, against the same broker image and client version.
2. **Every class variant passes** (`proof-oracles.md` § Distributed, *Class variants*, for the finding's V): every consumer under the fixed base processor, every lane the repo runs (BullMQ and kafkajs, both relays), not the one cited site.
3. **The benign control holds:** one clean delivery yields exactly one effect; a healthy lock holder still completes; a valid event still deserialises.
4. **The loss probe stays green — the mirror of the fix.** After a duplicate fix, the crash probe runs too: a kill before the effect still completes once on redelivery (V291 beside V292). After a poison fix, the good messages are all processed and the bad one is in the dead letter, not gone (V293). After a lock fix, a holder that loses the lock stops, and the work still completes once under the next holder (V313). A fix that passes the duplicate test and fails this one turned a duplicate into a loss.
5. **Every number is labelled measured**, with the broker image, client version and tool that produced it.

If any of the five fails, the fix is wrong. Do not move on.

### 4. RE-DETECT (the owning detector on the diff)
Re-run the detector recorded in Phase 2 on the patched `<file:line>` and its surrounding diff (for `dual-write-scan`, its F2 writer resolution first). It must go quiet there and raise nothing new. A detector that still reports means the patch moved the symptom; reopen the finding.

### 5. Self-check the fix's own diff
The command does not grade its own honesty; the scripts do. On the diff from `FIX_BASE` to the working tree:

```bash
python3 "$TI" --base="$FIX_BASE" --json      # deleted test or case, fewer assertions, new skip/only/xfail, removed CI test step
python3 "$OC" --base="$FIX_BASE" --json      # no-assertion, weak-oracle, tautology in every case this fix added or touched
git diff -U0 "$FIX_BASE" | rg -n --pcre2 '^\+(?!\+\+).*(?:\battempts\s*:\s*1\b|\b(?:retries|max_retries|maxRetries|maxAttempts|max_attempts)\s*[:=]\s*0\b|\bmaxStalledCount\s*:\s*0\b|\bremoveOnFail\s*:\s*true\b|\bnoAck\s*:\s*true\b|\balwaysAcknowledge\s*:\s*true\b|\bskip(?:LockRenewal|StalledCheck)\s*:\s*true\b|\backs_late\s*=\s*False\b|\benable\.auto\.commit\b|\bautoCommit\s*:\s*true\b|\bUnrecoverableError\b|\.(?:ack|nack|reject|term|resolveOffset|commitOffsets\w*|deleteMessage\w*|acknowledge)\(|\bDeleteMessage(?:Batch)?Command\b|\bcatch\b|\bexcept\b|\brescue\b|\bvoid\s+(?:this\.)?[\w$]+(?:\.[\w$]+)*\(|no-floating-promises|\b(?:lockDuration|stalledInterval|visibility_?[tT]imeout|VisibilityTimeout|handleMessageTimeout|max\.poll\.interval\.ms|consumer_timeout|ack_?[wW]ait|lockAtMostFor|leaseTime|startToCloseTimeout|scheduleToCloseTimeout)\b|["\x27](?:PX|EX)["\x27]\s*,|\b(?:jest|vi)\.mock\(\s*["\x27](?:bullmq|bull|kafkajs|amqplib|ioredis|redis|sqs-consumer|@aws-sdk/client-sqs|nats)["\x27]|ioredis-mock|\bQueue::fake\(|\balways_eager\b|\bInMemoryTestHarness\b|workflowcheck:ignore|#pragma\s+warning\s+disable\s+DURABLE|--no-error\b|\bcompatibility\b[^\n]*\bNONE\b|\bstreamState\s*:\s*["\x27]?any\b|\bStreamState\.Any\b|\bExpectedVersion\.Any\b)'
git diff -U0 "$FIX_BASE" | rg -n -i --pcre2 '^-(?!--).*(?:\b(?:it|test|describe|context)\s*\(|\bdef\s+test_|@Test\b)[^\n]*(?:twice|duplicate|redeliver|replay|concurren|idempot|poison|crash|kill|order|rebalance|stall)|^-(?!--).*(?:\boutbox\w*|\binbox\w*|\bidempoten\w*|\bdedup\w*|\breserve\w*|processed_(?:messages|events)|\bon\s+conflict\b|\bonConflict\w*|\bdeadLetter\w*|\bdlq\b|\bheartbeat\w*\(|\.extend\(|\bpatched\(|\bgetVersion\(|\bGetVersion\()'
git diff -U0 "$FIX_BASE" | rg -n --pcre2 '^[+-](?![+-]{2}).*(?:\backs\b|\bprocessing\.guarantee\b|\bisolation\.level\b|x-queue-type|x-dead-letter-\w+|x-delivery-limit|\bRedrivePolicy\b|\bredrive_policy\b|\bmaxReceiveCount\b|\bMaxDeliver\b|\bmax_deliver\b|\bmessage_retention_seconds\b|\bMessageRetentionPeriod\b|x-message-ttl|\bremoveOn(?:Complete|Fail)\b|maxmemory-policy|\bMAXLEN\b|\bretention\.ms\b|\bnum\.partitions\b|\bpartitions\s*[:=]|\bgroupId\b|\bgroup\.id\b|\bprefetch\w*|\bMessageGroupId\b|\bdeprecatePatch\(|\bversioningBehavior\b|\bbuildId\b|\bschemaVersion\b)'
git diff --name-status "$FIX_BASE" | rg -n --pcre2 '^D\s|\.(?:proto|avsc|avdl)$|asyncapi[^/\n]*\.ya?ml$|(?:^|/)(?:schemas?|contracts|events)/[^\n]*\.json$|definitions\.json$|redis\.conf$|(?:^|/)migrations?/|\.tf$|(?:^|/)(?:deploy|k8s|helm|charts)/'
```

- **Either script exits 1 → the finding does not close.** Rework the fix so nothing is net-removed, or put the row to the user as a STOP item; until approved it stays `escalated (integrity: <kind> <file:line>)`. Exit 2 is a failed lane: `self-check: blocked`, never clean.
- **Every line the loss-trade grep prints** is read in context and either cited as legitimate in the closure row — an ack that now follows the last durable write, a `catch` that rethrows or dead-letters, a lock TTL raised **together with** a checked renewal and the arithmetic, `UnrecoverableError` on a validation failure that can never succeed — or the hunk is reverted. A loss-trade shape with no written precedent-6 decision is never closed.
- **Every line the removal grep prints** is a deleted duplicate, crash or poison test, or a removed reserve, outbox, dead letter, heartbeat, renewal or version gate: each needs the user's recorded yes, or the hunk is reverted.
- **Every line the STOP-surface grep prints, and every file the last line prints,** touches a delivery guarantee, a DLQ or retention rule, a partition or group, a version gate or a consumed schema: the closure row cites the STOP approval for that hunk, or shows it is the finding's own primitive and crosses no STOP line.
- Without the repo-baseline scripts, read `git diff -U0 "$FIX_BASE"` for removed assertions and added skips, run the four greps, and mark the row `self-check: inline (repo-baseline scripts absent)`.

### 6. Sweep for siblings
State the root cause in one line (`refute-before-report.md § 6`): "the base processor returns before `handle()`'s promise settles", "every producer subclass spreads the caller's options after the wrapper's dedupe key", "the cron jobs release their lock with GET, compare, DEL" — not "the receipts job acks early". Grep it with the owning detector's pre-flight line narrowed to that cause (and `ds-inventory.py` for options inherited from a base or a wrapper), and run each hit back through Step 1. Each confirmed hit is **fixed**, **explained** (one line, or Refuted by a named gate), or **followup** (its own id). `N_found == N_fixed + N_explained + N_followup` must hold.

### 7. Tear down, then the suite (after the last finding)
`docker rm -f $(docker ps -aq --filter label=refract.ds-fix="$RUN")` and `rm -rf "$SCAN"`; `docker ps --filter label=refract.ds-fix="$RUN"` prints nothing. Then run the project's tests (through `bash .claude/hooks/test-lane.sh run '<cmd>'` when the repo-baseline is installed), the typecheck and the lint at its CI level, and each T-tier tool on the touched files. Red here reopens the finding whose change it traces to.

### Commit (one finding = one commit, only where the repo allows it)
Read the convention first (recent `git log`, a protected or PR-only branch, a no-commit rule in `CLAUDE.md` or `CONTRIBUTING`). Where commits are allowed: `fix(ds): <what a redelivery, a crash or a retry could do> — <finding id>`, for example `fix(ds): a redelivered receipt job sent a second email — DS-02`. Otherwise **leave the change staged and say so**.

## Phase 5 — Update
- Update `ai/audits/<date>-distributed*.md` in place, or write a `-fix.md` companion: mark each finding and append the closure table.
- `ai/dynamic/changelog.md`: `Distributed fix on <scope>: C closed, S staged, P probe-written (docker owed), N no-data (L-tier), E escalated, D deferred`.
- `ai/status.md` `## Recent Changes`: one bullet per STOP decision still owed (a delivery guarantee, a DLQ or retention rule, a money-path lock TTL, a consumed schema and its consumers, an outbox introduction).

### Closure table (required artifact)
```
| Finding | Class (detector §)          | Tier | Oracle: before → after (broker)                         | Variants | Control · loss probe | Self-check (TI · OC · trade · rm · stop) | RE-DETECT | State                         |
|---------|-----------------------------|------|---------------------------------------------------------|----------|----------------------|------------------------------------------|-----------|-------------------------------|
| DS-01   | ack before effect (msg §1)  | C    | V291 redis:7-alpine, bullmq 6.3.4: 0 effects → 1        | 4/4      | 1 effect · V292 green | 0 · 0 · 1 (cited: ack after write) · 0 · 0 | quiet   | <sha> fix(ds)                 |
| DS-02   | consumer idempotency (§2)   | C    | V292 sequential + barrier: 2 emails → 1                 | 6/6      | 1 effect · V291 green | 0 · 0 · 0 · 0 · 0                        | quiet     | staged (PR-only)              |
| DS-03   | release (coord §1)          | C    | V310 pause between GET and DEL: new holder's key deleted → kept | 2/2 | holder completes · V313 green | 0 · 0 · 0 · 0 · 0            | quiet     | <sha> fix(ds)                 |
| DS-05   | retry layers (retry §4)     | C    | Probe (written, not run): no docker daemon              | —        | —                    | —                                        | —         | open (docker owed)            |
| DS-07   | DLQ retention (msg §8)      | S    | redrive maxReceiveCount 1000 → (proposed) 5             | —        | —                    | —                                        | —         | escalated: STOP DLQ policy    |
```
A finding with no failing-first proof against a throwaway broker, a variant not run, a benign control above one effect, a loss probe that went red, a self-check that flagged, or a RE-DETECT that is not `quiet` is **not** closed. An L-tier row reads `NO-DATA → re-run /ds-audit --live=<source>`, never closed.

## Phase 6 — Validate
- Each closed finding has a failing-first proof against a container this run started, a green run of every variant, a one-effect benign control, a green loss probe, a clean self-check, a quiet RE-DETECT, a balanced sibling ledger and a green suite.
- **Re-run `/ds-audit` on the touched scope** (with the same `--classes`). The verdict must not regress, and each first-pass finding must no longer reproduce at its `<file:line>`.
- No delivery guarantee, DLQ or retention rule, money-path lock TTL, consumed schema or version gate changed without the user's yes; no test pointed at a shared broker; no container from this run is left running.

## Phase 7 — Improve
- `/learn-from-task`: record each closed class and the primitive that closed it.
- A class seen in two audits gets an ADR in `ai/decisions/` and its mechanical guard: the duplicate-replay and crash-mid-handler container tests kept beside the base processor in CI, the kill-between test beside the outbox port, `no-floating-promises` at error, the atomic lock helper as the only acquire and release path, a replay test over recorded histories, the schema compatibility tool as a required check.

## Output format
```
## /ds-fix — <N closed · M staged · P probe-written · L no-data · E escalated · K deferred>
Input:  ai/audits/<date>-distributed.md  (findings: <total>; routed: /security-fix <s>, /db-fix <d>, /perf-fix <p>, /infra-fix <i>)
Broker: redis:7-alpine (deploy/local/datastores.yaml:79) via Testcontainers · bullmq 6.3.4 (lockfile) · Valkey (managed) UNREAD → self-hosted default, labelled
Order:  MUST FIX (<c>: T <t>, C <cc>, S <s>) → SHOULD FIX (<m>) → OPTIONAL (<l>)
Closure table: (Phase 5 — one row per finding)
Escalated (decision owed):
  - DS-07  redrive maxReceiveCount 1000 → 5 on orders-queue: messages dead-lettered sooner — change it? (V293 before/after attached)
  - DS-09  OrderPlaced.amount minor → major units: 2 consumers in this repo, others unknown — new versioned event instead?
Teardown: 0 containers left (label refract.ds-fix=<run>) · Suite: jest PASS · typecheck PASS
Re-audit: /ds-audit on touched scope → verdict <was → now>, no regression
Status: COMPLETE | INCOMPLETE  (COMPLETE only when every MUST-FIX finding is closed, escalated, probe-written with its command or NO-DATA with its source, the self-check is clean and the re-audit did not regress)
```

## What to do next — required closing section
Every run ends with `## What to do next`: the remaining work as ONE ordered, numbered to-do. **MUST FIX** (open or escalated BLOCKER and HIGH) first, then **SHOULD FIX**, then **OPTIONAL**. Each step carries `<file:line>`, the **Fix**, and the **Verify** (the oracle, its tier, its V-number and the broker image). An escalated item names the decision the user owes: the delivery guarantee and what it trades, the DLQ or retention rule and its loss window, the lock TTL and its arithmetic, the schema change and every consumer. A probe-written item names the docker daemon it needs and the command to run. The closing steps are: re-run `/ds-audit` to confirm the verdict, replay what the fix emptied with `dlq-replay` once it is deployed, `/learn-from-task`, then ship or open the PR. A fully closed run collapses to one line. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- **A duplicate turned into a loss.** `attempts: 1`, `maxStalledCount: 0`, ack-first, a swallowing `catch`: the duplicate test passes and the message is gone. The loss probe and Step 5 refuse it.
- **A bigger number instead of a heartbeat.** A longer lock or visibility hides the race until the next slow run.
- **A mocked broker as proof.** `Queue::fake()` or eager Celery passes on code that loses messages on the real broker (precedent 33).
- **The shared broker.** A test that read `REDIS_URL` from `.env` ran against someone else's queue.
- **One consumer fixed, the base left.** Seven processors inherit one `process()`; the fix goes there.
- **A STOP line crossed quietly:** an ack mode, a redrive policy, a money-path TTL or a consumed field changed as "just the fix".
- **A container left running.** Every run ends with the label filter empty.

## Related

### Sibling commands
- `/ds-audit`: the producer. Without a report the refuse-to-run gate halts.
- `/add-event-handler`, `/add-saga` (this pack): build consumers and sagas whose Phase 6 runs the same oracles. `dlq-replay` (this pack): drains what a fix emptied. `/security-fix`, `/db-fix`, `/perf-fix`, `/infra-fix`, `/obs-fix` (when installed): the routed classes. `/fix-bug`: the general discipline ([`fix-bug-core.md`](../../../snippets/fix-bug-core.md)).

### Detector skills (re-run for RE-DETECT)
This pack: `messaging-scan` (`scripts/ds-inventory.py`) · `dual-write-scan` · `retry-deadline-scan` · `coordination-scan` · `workflow-scan` · `event-contract-scan`.

### Agents
`@resilience-reviewer` (this pack; judges a proposed fix to a delivery, dual-write, retry or lock row) · `@workflow-orchestrator` (this pack; workflow and saga fixes) · `@event-sourcing-architect` (this pack; contract and event-store fixes) · `@verifier` (repo-baseline, mode `refute`).

### Shared contracts
[`refute-before-report.md`](../../../snippets/refute-before-report.md) · [`precedents/distributed.md`](../../../snippets/precedents/distributed.md) · [`broker-semantics.md`](../../../snippets/broker-semantics.md) · [`proof-oracles.md`](../../../snippets/proof-oracles.md) § Distributed · [`fix-bug-core.md`](../../../snippets/fix-bug-core.md) · [`review-action-plan.md`](../../../snippets/review-action-plan.md)
