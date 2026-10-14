# distributed-systems pack — changelog

Release history for `templates/packs/distributed-systems/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

## 2.0.1 — 2026-10-14

**Integrator follow-ups.** `@workflow-orchestrator` (and its `_examples` copy) cites `broker-semantics.md` WK1–WK14, so the Restate versioning, DBOS and Zeebe rows reach its verdicts; `workflow-scan`'s F1 comment says the same. `coordination-scan` 11c routes CronJob manifest fields (`timeZone`, `concurrencyPolicy`, `startingDeadlineSeconds`) to infrastructure `k8s-wiring-scan` §5; backend `job-lifecycle-scan` §6 keeps only which local time the job means (Boundaries, §11, the measured rows and the output example updated).

**`ds-defects` fixture gaps (IR-1..IR-11).** `ds-inventory.py` applies a library default when the manifest major is `0` (amqplib `^0.10.9` rows were UNRESOLVED) and follows kafkajs producers injected through a DI token (`@Inject(KAFKA_PRODUCER) … : Producer` → the provider factory's `producer({…})` options), with two new self-test cases and `tests/ds-inventory/` re-recorded. `messaging-scan`: Go lane G5 (kafka-go/sarama messages with no `Key`, non-murmur2 balancers, writers with no `Balancer`; `broker-semantics.md` GL5), 8e (a RabbitMQ queue or policy with a TTL or max-length and no dead-letter exchange in the same object), and 10's file-level `no sync_interval` line for JetStream servers. `workflow-scan` §2a compares workflow files with their `CONTRACT_BASE` copy when there is no `WF_BASE` (`/ds-audit --contract-base` now passes it), 1e no longer lists `Task.WhenAll` in a Durable orchestrator (`.Result` is the hazard), and 5d skips a registration whose next line calls the undo's own noun. `dual-write-scan` O3 takes no port from a raw INSERT into an `*outbox` table with no event column. `retry-deadline-scan` 7b matches `code` and `confirm` as whole tokens. `event-contract-scan` 9a/S9 end a body at the method's own closing line, 9b sees `saveSnapshot(`, `OrderSnapshots` and `order_snapshots` in aggregate files only, and the tool lane prints `VERSION-BUMP` for an `info.version`-only AsyncAPI change and NOT-RUN up front for a 2019-09/2020-12 JSON Schema (SZ9, SZ10). `/ds-audit` Phase 3 F4 reads `ledger_outbox_rows` and Django outbox models; F5 counts sagas as `workflow-scan` F2 does.

## 2.0.0 — 2026-10-14

**The distributed-systems pack became a set of detectors with one audit, one fix loop and three judges (Track A batch 5).** Before this release the pack had two skills and no detector: delivery, dual-write, retry, lock, clock, workflow and contract defects were found, if at all, by agents reading prose checklists, and `chaos-test` ran `kubectl` against whatever context was current. Now each class has one owning skill with a one-script pre-flight (every `rg` names its path; include globs first, exclusions last), a version gate read from files, the [`broker-semantics.md`](../../snippets/broker-semantics.md) row every verdict rests on, a class-coverage block, a refute step and a failing-first oracle against the real broker or store in a throwaway container. Major version: new commands, three agents rebuilt as judges, Contracts on every agent, and `/audit-distributed-tx` narrowed to the runtime lane.

New detectors (`skills/`), each measured 2026-10-14 on the research samples, the benchmark fixtures and a read-only real repository (never named):
- `messaging-scan` § 1–§ 11 with `stacks.md` and `scripts/ds-inventory.py` (stdlib; `--self-test`, plus the regression tree `tests/ds-inventory/`) — ack or commit before the effect, consumer idempotency and unstable reserve ids, poison and DLQ, ordering, rebalance, lock or visibility vs run time (`THR-DS-CONSUMER-TIMING`), producer confirms, retention and eviction, consumer buffering, broker durability, library and version traps (V291–V299). `ds-inventory.py` resolves queue options across files — the wrapper, the subclass override, imported constants, env fallbacks — and resolved 20/20 producers and consumers on the real repo; its `# candidate:` line found a custom backoff whose worker sets no `backoffStrategy` (BullMQ throws `Unknown backoff strategy`, BQ10).
- `dual-write-scan` § 1–§ 6 — finds the project's outbox port first (27 of 28 write-then-publish calls on the real repo went through it), then commit-then-publish, publish-then-commit, the relay, the inbox reserve and its retention (`THR-DS-DEDUPE-WINDOW`), CDC consumers, and gap-blind catch-up cursors (V300–V303).
- `retry-deadline-scan` § 1–§ 8 — retry eligibility, caps, backoff and `Retry-After`, layers multiplied across a call chain (the layer worksheet with a failure-propagation column; `THR-RES-RETRY` `layers: 1`), retries of non-idempotent calls including library defaults (axios-retry on network errors), state reset, deadline propagation and timeout order (V304–V309).
- `coordination-scan` § 1–§ 11 with `stacks.md` — lock release without an owner check, TTL, ignored acquire results, leases shorter than the work and dropped renewals (`THR-DS-LEASE`), session advisory locks through a pooler, leadership loss; wall-clock durations, cross-clock expiry, last-write-wins on timestamps, time as an identifier, DST in coordinated schedules (V310–V319).
- `workflow-scan` § 1–§ 6 — determinism per SDK (TypeScript Temporal `Date.now()` and `Math.random()` are replaced by the sandbox and are not findings), versioning with open executions, activity and engine configuration (Temporal, Durable Task, Step Functions, Restate, DBOS, Inngest, Zeebe, BullMQ flows), saga compensation, order and idempotency (V320–V322).
- `event-contract-scan` § 1–§ 10 with `stacks.md` and `--contract-base=<dir>` — breaking schema changes through buf, json-schema-diff, the AsyncAPI CLI (metrics off), oasdiff (webhooks) and the avsc resolver, each read by its measured exit code (a tool that parsed nothing is NOT-RUN, never PASS); unchecked inbound events, intolerant readers, semantic changes, naming and versioning; event-sourcing appends without an expected version, missing UNIQUE(stream, version), projection checkpoints, side effects in `apply`, read-after-command lag (V323–V327).

New commands: `/ds-audit` (read-only; all six detectors on a whole-repo run, `ds-inventory.py` once, the outbox-writer pre-flight before dual-write § 1, three judges, routed rows to their owners, the CONTRACT and REPLAY gates, a fixed class ledger and a three-state verdict; `--runtime` is the old `/audit-distributed-tx` count, on named sources only) and `/ds-fix` (failing-first on a throwaway broker, the loss probe beside the duplicate probe, a grep of the fix's own diff for loss trades, stop lines before a delivery-guarantee, DLQ, money-path TTL or consumed-schema change).

Judges and agents:
- `@resilience-reviewer` is the judge (`role: judge`, `writes: none` under `/ds-audit`) of the messaging, dual-write, retry and coordination rows, with the layer invariant and timeout order; timeout presence is performance's.
- `@workflow-orchestrator` judges `workflow-scan` (Temporal facts corrected: activity retries default unlimited, a Start-To-Close or Schedule-To-Close is required); `@event-sourcing-architect` judges `event-contract-scan` (`streamState: ANY` fails the expected-version check).
- `@system-architect` and `@capacity-planner` carry a `## Contract` (`role: proposer`); `lint-agent-contract.sh` lists distributed-systems as a pack whose agents must have one.

Kept, edited: `chaos-test` (a named kubeconfig and context first; Toxiproxy with Testcontainers as the local default), `dlq-replay` (a Verify block: depth before and after, duplicate effects by business id, out-of-order count per key), `/add-event-handler` and `/add-saga` (the class oracle in Phase 6, the reserve and the ambiguous-failure rules), `/audit-distributed-tx` (the runtime lane of `/ds-audit`), `ai-patterns/idempotency.md` and `outbox.md` (each Detectors section points to the § that runs it; a reused key with a different body answers 422, a concurrent duplicate 409; the reserve commits with the effect; the relay claims, commits, then publishes outside row locks), `_examples/circuit-breaker.md` (a monotonic clock), and `rules/distributed-principles.md` (a timeout always; retries at exactly one layer; a breaker only where the call can cascade; Enforcement names `/ds-audit`'s CONTRACT and REPLAY gates).

Snippets and governance: `broker-semantics.md` (the dated defaults table, each row `[V]`/`[K]`/`[K?]` with a source: BullMQ, Kafka clients, RabbitMQ, SQS/SNS, NATS, Redis Streams, Pub/Sub, job systems, outbox and stable ids, retry libraries, locks, schedulers and migration runners MG1–MG14, workflow engines, schema tools and their measured exit codes, event stores, clocks), `precedents/distributed.md` § 1–36, `proof-oracles.md` § Distributed V291–V327, thresholds `THR-DS-CONSUMER-TIMING`, `THR-DS-DEDUPE-WINDOW`, `THR-DS-LEASE` and `THR-RES-RETRY` `layers: 1`, and seven `ownership.json` rows (`messaging-delivery`, `dual-write`, `retry-policy`, `distributed-lock`, `clock-misuse`, `workflow-determinism`, `event-contract`).

`_essentials.md` gains `messaging-scan`, `dual-write-scan`, `/ds-audit` and `/ds-fix` — the two classes that lose or duplicate data, and the audit pair. `_topics.md` registers the six detectors and the two commands with their sources as fallbacks.

**Compatibility.** The pack stands alone; neighbours own classes at its edges and it routes to them when installed (soft dependencies): database (`transaction-scan` § 1 publish inside a transaction, § 5 claims without `SKIP LOCKED`, § 8 saga lost update), security (`logic-race-scan` § 4–§ 5 money, stock and credit effects), performance (`request-path-scan` § 12 timeout presence, § 18 per-replica locks and fencing, § 20 once-per-fleet work, § 23 worker capacity; § 24 is now the fallback for consumer idempotency, poison and lock vs run time when this pack is absent), backend (`job-lifecycle-scan`, `http-contract-scan` § 10, `wire-format-scan` § 5), code-quality (`type-safety-scan` § 1 boundary casts) and infrastructure (`serverless-reliability-scan` for Lambda event sources). Without an owner pack the rows are reported here, tagged `(owner pack not installed)`.

## 1.4.0 — 2026-08-23

**Fixes (correctness).**
- `agents/workflow-orchestrator.md` + its `_examples/` fallback cited `defineWorkflow` and
  `defineActivity` as Temporal TypeScript API. Neither exists — `@temporalio/workflow` exports
  `defineSignal` / `defineQuery` / `defineUpdate` / `proxyActivities` and no workflow or activity
  definer (`typescript.temporal.io/api/namespaces/workflow`); workflows and activities are plain
  exported async functions. The invented name was load-bearing in a halt condition ("those must
  precede the first `defineWorkflow`"), so the halt was unfollowable. `defineUpdate`, which is real
  and the correct answer to signal-then-poll-a-query, was missing and is now named.
- `ai-patterns/consistency-models.md` (+ fallback) classified Dynamo as **PC/EL**. Abadi's taxonomy
  puts Dynamo / Cassandra / Riak / Cosmos DB in **PA/EL**; PC/EL is PNUTS. The old gloss was also
  self-contradictory ("consistent under partition — Dynamo-style"). PC/EC examples moved to systems
  the taxonomy actually classifies. Source: en.wikipedia.org/wiki/PACELC_design_principle.
- `agents/capacity-planner.md` (+ fallback) worked example contradicted its own formula:
  `ceil(8k x 0.05 / 200) x 1.4` rendered "3 -> 5 w/ headroom" where the arithmetic gives 2 -> 3, and
  the DB-connections row below consumed the unsupported 5. Re-derived. Disproportionately serious for
  an agent whose Hard rule is "every capacity number shows formula + inputs". The storage row
  (80 x 730 x 3 x 1.3 = 227,760 GB = 228 TB) was verified correct and left alone.
- `agents/event-sourcing-architect.md` (+ fallback) contradicted itself on snapshots: Hard rules said
  "< 100 events typical; snapshot past that", the Output block said "every 50", the Snapshots section
  gave no number at all. Replaced by the inequality that determines the cadence, with the worked
  numbers labelled as inputs rather than recommendations.
- `_examples/distributed-principles.md` was missing the source's strongest Must-not — "exactly-once
  *delivery* is impossible ... claim effectively-once and show the idempotency key" — and still
  carried the superseded "best effort" bullet. Greenfield installs were losing it. Fallback
  re-synced, and its Enforcement block re-generalised to match the source's stack-agnostic phrasing
  (it still named Jaeger / Tempo / Datadog / Pact where the source had been cleaned to "the project's
  trace backend" — the source-generalised-but-fallback-not defect class).
- `commands/add-event-handler.md` offered an escape from its own halt ("or require
  `ai/patterns/event-handlers.md` to define one") to a file that only this command's own Phase 5
  creates — circular on the first handler. The escape is now named as unavailable, with the three
  that are real. Also marked its `ai/patterns/event-handlers.md` read *(project signal)* in
  `/audit-distributed-tx`, the convention `design-system.md` had already established.

**Currency.** EventStoreDB -> KurrentDB (renamed at release 25.0, kurrent.io/releases/kurrentdb/25-0);
`hystrix-go` -> `failsafe-go` (afex/hystrix-go last pushed 2024-02-24 per the GitHub API; upstream
Netflix Hystrix in maintenance since 2018) across the rule, the pattern and both reviewer files;
`brew install shopify/shopify/toxiproxy` -> `brew install toxiproxy` (now homebrew-core, v2.12.0).
Measured and deliberately NOT changed: `Maxwell` (CDC) is alive — zendesk/maxwell pushed 2026-08-13.

**Dispatch.** `workflow-orchestrator` and `event-sourcing-architect` had **0 command dispatchers**
between them (measured across all 133 commands; the only references were Related-section bullets),
and were precisely the two agents carrying the fabricated API, the internal contradiction and the
stale product name — batch 3's dispatch/rot correlation, reproduced exactly. Both are now wired:
`/audit-distributed-tx` gains a Phase 2.5 dispatching `@workflow-orchestrator` on stuck-workflow rows
and `@event-sourcing-architect` on schema-version drift (its concerns 1 and 5 — the two the command
was judging by hand while three others are pure counting), and `/design-system` dispatches
`@event-sourcing-architect` conditionally on any event-sourced aggregate, before ADRs are written.
All 5 pack agents are now dispatched by at least one command **in the source tree — and, after
the two repairs below, on a greenfield install as well**.

**Greenfield — the dispatch fix above did not actually ship.** The claim was true of
`templates/packs/` and FALSE of every greenfield / `--lightweight` / `[EXTRACTION-WEAK]` install,
for two independent reasons, both now closed. Net effect before the repair: both agents remained at
0 reachable dispatchers on greenfield — precisely the defect this release headlines as closed.
- `_topics.md` declared `fallback: stub-from-sections` for `add-event-handler`, `add-saga`,
  `audit-distributed-tx` and `dlq-replay` while giving none of them a `sections:` list.
  `phase-4.2-apply.md:26` defines that literal as emitting "a sectioned stub from that topic's
  `sections:` list" — with no list there is nothing to build from, so greenfield received EMPTY
  files for 750 lines of finished command/skill sitting beside them on disk (add-event-handler 183,
  add-saga 211, audit-distributed-tx 188, dlq-replay 168). `/audit-distributed-tx` is one of the two
  commands the dispatch fix was installed into, so it materialised empty. All four now declare
  source-as-fallback (`commands/<name>.md`, `skills/dlq-replay/SKILL.md`) — the shape
  phase-4.2-apply step 2 provides for, and the same repair already made in security
  (CHANGELOG:87), business and data-engineering; infrastructure (CHANGELOG:106) took the other
  valid route and added the missing `sections:` lists.
- `_examples/design-system.md` contained **zero** occurrences of `event-sourcing-architect`
  (measured `grep -c` = 0) after the source gained the conditional dispatch and its `## Related`
  bullet, so greenfield installed a `/design-system` that never reaches the agent — and the
  one-way-door decisions the source names (event envelope, concurrency key, snapshot cadence, GDPR
  strategy) were made without it. Fallback re-synced, in Phase 4 and in the Phase-2 sequence line.
  Inconsistent application rather than unawareness: the same release re-synced
  `_examples/distributed-principles.md` for exactly this reason.

All 19 gates stayed green throughout both defects: `validate-pack-consistency` check 3 only fails a
`fallback:` that does not RESOLVE, and the literal `stub-from-sections` always resolves; check 8b
reads neither a command source nor its `_examples/` sibling, so a dispatch target present in one and
absent from the other is invisible to it.

**Theory -> decision** (the pack was charged with being theory-heavy and execution-light).
- `workflow-orchestrator`: the 30-line "Core design principles" tutorial became one decision table —
  what goes in a workflow vs an activity, and why replay makes that the only question; the four-way
  platform tour became a "Pick when / Disqualifier" table; the generic Checklist and "Common bugs"
  list became 8 numbered **Detectors (cite-or-halt)**, each with where to look and a verdict
  (ORPHAN-RISK / STUCK-FOREVER / DOUBLE-EFFECT / WASTE). It was the only agent of the five with
  neither an output verdict nor a verdict-matches-body clause; it now has both.
- `event-sourcing-architect`: gained 8 **Detectors (cite-or-halt)** and a SOUND / DEGRADED / CORRUPT
  verdict. Detector 8 lets it recommend *against* event sourcing, which is a valid output it
  previously had no way to render. The expository blocks the detectors duplicated were compressed to
  pay for the additions.
- `ai-patterns/circuit-breaker.md`: `failureThreshold: e.g. 50 percent`, `windowSize: e.g. last 10
  calls`, `openDuration: e.g. 30s` were arbitrary example numbers presented as config. Replaced by
  what *determines* each knob (measured baseline error rate, call volume, the dependency's observed
  recovery time, the caller's latency budget), the failure mode of getting each wrong, and a halt
  when those inputs are not extracted.

**Sibling boundaries.** 12 of the 15 in-source sibling entries were the content-free stub "`@X` —
sibling agent in distributed-systems pack", which answers none of the only question a sibling list is
asked: when do I pick that one instead of this one? All 12 replaced with the arbitration line and the
direction work flows. Separately, only 1 of 5 agent `_examples/` fallbacks carried any boundary
signal (repo-wide the measured figure is 0 of 25 as a section, because check-8b's protected set
omits it) — all 5 now carry a compressed inline `**Boundary:**` line, so a greenfield install no
longer receives five agents with no arbitration between them.

**Rule budget.** `rules/distributed-principles.md` 1,903 -> 1,593 tok (7,614 -> 6,373 chars, -16.3
percent). Deleted: the 8-fallacies recital (a list with no attached action, resident every turn; the
canon survives as a one-clause attribution on the intro line and every fallacy is already enforceable
in Must/Must-not below it), the Communication-patterns block (strictly dominated by
`system-architect` section "3. Communication pattern decision", a 6-row table with a "Watch out for"
column the rule did not have), the Review checklist (measured 8/8 restatement of the Must/Must-not
above it) and the References bibliography (four pointer lines a model cannot open). Two clauses that
existed nowhere else were preserved by moving them up rather than deleted with their sections:
event/RPC names never inline (-> Must not) and payload-carries-IDs-not-entities (-> Should). The
fallback was edited in the same pass so the pair stays consistent under check 8b.

FIXED (integration pass, same release)
- **Four topics emitted an EMPTY file on greenfield.** `_topics.md` declared
  `fallback: stub-from-sections` with **no `sections:` key** for `add-event-handler`, `add-saga`,
  `audit-distributed-tx` and `dlq-replay`. `phase-4.2-apply.md:26` defines that sentinel as "emits a
  sectioned stub from that topic's `sections:` list" — with no list there is nothing to emit, so a
  greenfield / `--lightweight` / `[EXTRACTION-WEAK]` project received four empty files while 750
  lines of finished command and skill sat beside them on disk. No gate fires:
  `validate-pack-consistency.sh:200-206` skips any fallback that does not look like a path
  (`echo "$fb" | grep -qE '/|\.md$' || continue`). The `add-event-handler` entry even carried the
  comment "ships in commands/; no _examples sibling" — the shape was known and the sentinel declared
  anyway. All four repointed to source-as-fallback, the same one-line repair `finops`,
  `data-engineering`, `product` and `business` applied to 35 topics this release. Measured
  repo-wide: the class was 8, is now 4, and all 4 remaining are in `observability`.
- **`_examples/design-system.md` lost the `@event-sourcing-architect` dispatch the source added.**
  The fallback dispatched `system-architect` then `resilience-reviewer` at exactly the point the
  source now branches, so on greenfield an event-sourced project had its ADRs written without the
  event envelope, concurrency key, snapshot decision or GDPR strategy ever being raised — all
  one-way doors once the first event is stored. Conditional dispatch restored, plus the Phase 2
  sequence and pause lines that named the wrong chain. Check 8b cannot see this class: it fails a
  fallback that **asserts** something its source disowns, never one **missing** something the source
  added.

## 1.3.0 — 2026-07-10

- add-event-handler + add-saga Phase 6: HALT precondition requiring the dedupe/reserve be cited at
  path:line and be ATOMIC (compensations keyed by (sagaId, stepName)); scenarios now cover
  concurrent duplicate delivery, crash between effect-commit and ack, and redelivered compensation —
  not a sequential twice-call.
- resilience-reviewer: halt conditions — an idempotency claim resting on check-then-act or an
  in-memory map is NOT idempotent.

## 1.2.1 — 2026-07-10

- add-saga + add-event-handler: Phase-6 now enforces scenarios_green == scenarios_required OR HALT —
  the per-scenario tests (happy/failure/timeout/crash/idempotency/DLQ/replay) must actually run
  green or the success block is not emitted; per-scenario PASS/FAIL rendered, not an asserted
  checklist.

## 1.2.0 — 2026-07-10

- ai-patterns +1: reconciliation (cross-store anti-entropy — divergence detection + resumable repair +
  divergence metric for projections/caches/indexes/dual-writes; consumes event-sourcing replay as
  one repair mode).

## 1.1.0 — 2026-07-09

- CORRECTNESS: idempotency.md — fencing-token requirement on distributed locks (Redlock controversy) +
  corrected DELETE idempotency (state-effect not status code; 404/410 on repeat is valid) + RFC
  7231->9110. distributed-principles.md — exactly-once-delivery-is-impossible / effectively-once =
  at-least-once + idempotent processing.
- NEW ai-patterns: consistency-models (CAP/PACELC, linearizable->sequential->causal->RYW->eventual
  ladder with pick-criteria, delivery semantics, per-datastore CP/AP table), distributed-lock
  (fencing tokens, lease/TTL, Redlock/Kleppmann-vs-Antirez, lock-free CAS alternatives),
  sharding-partitioning (key selection, consistent hashing + vnodes, hot-partition, resharding,
  scale-cube Z, when-NOT), backpressure (bounded queues, load-shedding 503+Retry-After, AIMD
  adaptive concurrency, credit flow control, bulkhead — closes the dangling backend bulkhead
  pointer). saga.md +Saga-isolation section (semantic lock / commutative / pessimistic view /
  reread-version / by-value).
- NEW agents/capacity-planner.md (model:opus) — the quantitative system-design specialist: capacity
  model (Littles Law L=lambda*W, storage/bandwidth/cache/connection budgets) -> bottleneck ledger
  1x/10x/100x -> scaling axis (vertical->horizontal->read-replicas->shard) ->
  data-migration-at-scale cutover (dual-write->backfill->shadow-read->expand-contract->flip); 7
  detectors + capacity/bottleneck/scaling/partition-ADR output. commands/design-system.md +Phase-3.5
  capacity+scaling dispatch; dangling event-bus.md/replication.md refs fixed. This is the
  system-design EXPANSION (boundary call: expand, not a new pack).
- House-contract: all 4 pre-existing agents +hand-wave hard-halt clause +### Skills subsection
  +@capacity-planner sibling; resilience-reviewer + system-architect promoted sonnet->opus (were
  inverted) +verdict-matches-body; system-architect +datastore-selection table +C4
  (container/component/deployment + sequence) diagrams; add-saga +Premise/Mechanical-halt.
  Registered consistency-models/distributed-lock/sharding-partitioning/backpressure +
  capacity-planner in _topics/_essentials.
