# distributed-systems pack — changelog

Release history for `templates/packs/distributed-systems/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

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
