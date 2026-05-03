---
name: feature-port
description: Pattern: Feature port (V1→V2)
kind: ai-pattern
pack: migration
---

# Pattern: Feature port (V1→V2)

> **Hard rule:** Each ported feature traverses the six phases (Understand → Plan → Port → Parity → Perf → Cutover) with one ledger row, a pinned V1 commit, and a green parity suite at every gate. Touching V1 during the port, copy-pasting V1 code into V2, or advancing cutover stages without parity evidence is forbidden.

**When to apply**
- A feature has been selected from the inventory and is moving from V1 to V2.
- A previously-ported feature regressed and needs re-entry into the parity-test phase.
- A new V2 module shape is being validated against a representative pilot feature.

**When NOT to apply**
- A V2-only feature with no V1 oracle — use ordinary scaffolding, not the port pattern.
- A trivial config-only change with no behavioral surface — overhead exceeds value.

**Halt conditions / mandatory cites**
- Every phase output MUST cite its file at `<path:line>` (contract, plan, V2 implementation, parity test, perf decision, cutover ledger row).
- Cutover stage advances MUST cite the parity-run ID + dashboard evidence in the ledger.
- A PR that ports without updating the ledger in the same commit is a bug — reject.
- Hand-wave grep on `etc.`, `...`, `appears to`, `roughly` is forbidden in contracts and parity assertions.
- If V1 root, V2 root, parity test root, or cutover mechanism aren't extracted, halt before phase 1.

> **Project-specific block** — Phase 4.6 fills this from `.claude/_extracted-codebase.md § Migration`. Do not delete; if extraction is empty, leave the placeholder + open a TODO.
>
> - **V1 root**: `<extracted>` (e.g., `Reports/views.py`, `apps/web-v1/`, `legacy/`)
> - **V2 root**: `<extracted>` (e.g., `apps/web/`, `reports_v2/`, `src/v2/`)
> - **Module-shape in V2**: `<extracted>` (e.g., feature-folder containing service/repo/dto/controller-equivalent files; OR app-per-feature in framework-native shape; OR feature folder per route — the actual convention extracted from V2)
> - **Cutover mechanism**: `<extracted>` (feature flag library + path / URL routing rule / build-time toggle / env var)
> - **Parity test root**: `<extracted>` (e.g., `tests/parity/`, `__tests__/parity/`)
> - **Migration ledger**: `ai/migration/ledger.md`
> - **First-port pilot candidate**: `<extracted>` (lowest-risk feature — e.g., a read-only health/admin endpoint)

This pattern is the playbook for porting one feature from V1 to V2. It assumes the strategic decision (port at all? strangler vs big-bang? V2 architecture?) has already been made by the `legacy-modernizer` agent and the **feature inventory** has been generated. Each feature in the inventory follows this pattern.

## Per-feature lifecycle (six phases, one ledger row)

```
       ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
   ┌──▶│ 1. UNDER-│───▶│ 2. PLAN  │───▶│ 3. PORT  │───▶│ 4. PARITY│───▶│ 5. PERF  │───▶│ 6. CUT-  │──▶ done
   │   │   STAND  │    │     V2   │    │          │    │   TEST   │    │   UPLIFT │    │   OVER   │
   │   └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
   │                                                          ▲                                ▲
   │                                                          └─── runs after every step ──────┘
   │                                                                  (regress = stop)
   └─────────── stop & rollback any time on parity-red OR scope-creep evidence ─────────────────
```

### 1. Understand V1 (no V2 code yet)

**Output**: `ai/migration/contracts/<feature>.md`

Use `extract-v1-contract`. Read V1 deeply — not just the entry point, but every conditional branch, every error path, every dependency call, every side effect. Capture:

- **Inputs**: every parameter shape, accepted types, validation rules (declared + ad-hoc), default values, optional vs required.
- **Outputs**: every return shape per code path (happy path + every error path + every empty-state path).
- **Side effects**: DB writes, external HTTP, queue publishes, cache reads/writes, file I/O, logs that systems depend on, metrics emitted.
- **Business rules**: every conditional that gates behaviour — including the ones encoded inline in if/else without a name. Give them names in the contract.
- **Invariants**: ordering guarantees, idempotency, retry semantics, atomicity, eventual consistency timing.
- **Edge cases**: empty inputs, null inputs, oversize inputs, malformed inputs, concurrent calls, partial failures, network errors. Search git log + bug tracker + tests for cases V1 has handled before.
- **Performance characteristics**: latency p50/p95, throughput cap, DB cost (queries per call), cache behaviour, memory footprint.
- **Known issues**: bugs V1 has that we may NOT want to preserve (decide explicitly per bug — preserve = parity, fix = contract break + ADR).

**Gate to phase 2**: contract is reviewed; ambiguities resolved; the V1 commit hash is pinned in the ledger row.

### 2. Plan V2 (no V2 code yet)

**Output**: `ai/migration/plans/<feature>.md`

Use `migration-architect`. Decide:

- **V2 module shape**: which folders / files / classes / interfaces — must mirror V2's existing architecture, not V1's.
- **What's parity-equivalent vs what's an intentional break**: every break gets queued for an ADR.
- **Perf-uplift candidates**: run `perf-uplift-survey` on V1 + the planned V2 design. Categorise: parity-preserving (ship in port PR) vs contract-breaking (separate PR).
- **Slicing**: if the contract is >500 lines, split the feature into sub-features each with its own ledger row.
- **Dependencies**: which other features must port first (e.g., this feature calls `getUser` — V2's `getUser` must exist already).
- **Cutover plan**: shadow window length, canary stages, rollback steps, success metrics.

**Gate to phase 3**: plan reviewed; dependent features confirmed ported; perf-uplift decisions logged.

### 3. Port (write V2)

**Output**: V2 implementation in `<v2-root>/<feature>/`

- Re-derive from the contract — DO NOT copy-paste from V1. Use V2's primitives (DI, repository pattern, error types, logging facade) as already established in V2.
- Apply the parity-preserving perf uplifts decided in phase 2 (column projection, batched queries, bounded parallel I/O, request-scoped cache).
- Defer contract-breaking changes — they ship in separate PRs after cutover.
- DO NOT modify V1 in this PR. V1 is the parity oracle.

**Gate to phase 4**: V2 compiles; unit tests for V2 internals pass; ledger row updated `In-progress`.

### 4. Parity test

**Output**: `<parity-test-root>/<feature>.test.*` + `ai/migration/parity-runs/<feature>-<run-id>.md`

Use `parity-test-generate`. Build the suite using the techniques from `parity-testing.md`:

- **Golden master**: capture V1 outputs for a curated input corpus (manual + fuzz + production samples anonymised); assert V2 produces equivalent output per tolerance taxonomy.
- **Record-replay**: tap real production traffic to V1 (anonymised); replay against V1 + V2; compare.
- **Property-based**: declare invariants (e.g., "for all valid orders, V1.total === V2.total within $0.01"); fuzzer searches for counter-examples.
- **Dual-write audit** (for write paths): in shadow / canary, V1 + V2 both write; periodic job compares the two output stores.

Tolerance choices live in the test file itself (per-assertion) AND in the contract.

**Gate to phase 5**: parity green for the full suite against the pinned V1 commit; ledger updated.

### 5. Perf uplift verification

**Output**: `ai/migration/perf-decisions/<feature>.md` (final form, post-implementation)

For each candidate from phase 2's `perf-uplift-survey`:

- **Applied**: measure before/after — V2 latency p50/p95, DB queries per call, memory per call, cache hit rate. Confirm parity tests still green. Record the measurement.
- **Deferred**: list the reason (e.g., "needs Redis infra not yet in V2"; "needs schema migration which is a separate PR").
- **Rejected**: list the reason (e.g., "introduces eventual consistency that breaks contract").

The user's specific concerns are first-class candidates here:

- **Caching strategy**: per-request memo, cross-request Redis, ORM-level cache. Choose by hit-rate × latency × invalidation cost. Document the invalidation rule (TTL? event-driven? both?).
- **DB index**: V2's query shape probably differs from V1's. Run `EXPLAIN ANALYZE` against prod-sized data (`migration-rehearsal`); add reversible composite indexes when sequential scans appear.
- **Query optimisation**: N+1 → batch / JOIN; in-app filtering → DB filtering; subqueries that re-execute → CTEs / lateral.
- **Column selection**: replace `SELECT *` with `SELECT <documented-consumed-columns>`. If the contract didn't list consumed columns, go back to phase 1.

**Gate to phase 6**: every perf candidate has a decision; applied changes have measurements; parity still green.

### 6. Cutover

**Output**: V2 serving traffic; ledger updated through states; (eventually) V1 deleted.

Progressive cutover (the only acceptable mode for non-trivial features):

| Stage | Traffic | Duration | Halt criteria |
|---|---|---|---|
| Shadow | V1 100% serving; V2 receives copy of every input; outputs compared offline | ≥7 days | parity diff > 0 → back to phase 4 |
| Canary 1% | V2 serves 1% | 24h | error rate / latency / business KPI regression > threshold → roll back to shadow |
| Canary 10% | V2 serves 10% | 24h | same |
| Canary 50% | V2 serves 50% | 24h | same |
| 100% | V2 serves 100%; V1 idle | observation window | regression → roll back |
| V2-only | V1 path removed from router; V1 code remains for safety | ≥14 days zero V1 traffic | any V1 traffic spike → investigate |
| V1-deleted | V1 code deleted | — | none — terminal state |

Ledger row updates on each transition with: timestamp, evidence (dashboard link, parity-run ID, traffic-percent metric), reviewer.

**Halt + rollback** at any stage: flip the cutover mechanism back to V1; ledger goes to a `Halted` state with a root-cause file in `ai/migration/halts/<feature>-<date>.md`.

## Decision: strangler-fig vs big-bang

The strategic decision sits with `legacy-modernizer`, but per-feature, the rule of thumb is:

- **Strangler-fig** is the default. One feature at a time, behind a router or feature flag. Rollback is per-feature, in seconds.
- **Big-bang** is acceptable only when: (1) the V1+V2 cohabitation cost is genuinely higher than the cutover risk, AND (2) full system parity tests + canary cover every feature simultaneously, AND (3) executive sign-off on the cutover risk window. This is rare. Default to strangler.

## Decision: vertical vs horizontal slicing

- **Vertical slice** (the default): port one feature *all the way through* V1's stack — controller, service, repo, schema, view, frontend caller — and ship cutover. Customer value lands per-port.
- **Horizontal slice** (rarely correct): port all controllers first, then all services, then all repos. V2 is unusable until the last layer ships. Risk: a horizontal slice that turns out to be wrong reverberates across every feature.

Choose horizontal only when: a shared layer (e.g., a new error envelope) MUST land before any feature can sensibly port. Even then, ship the shared layer behind a flag, port one feature on it, validate, then port the rest.

## Cutover modes (per-feature)

| Mode | When | Rollback time |
|---|---|---|
| **Shadow** | Always run before any traffic shift | Instant — V2 wasn't serving |
| **Canary** | After shadow is clean | Minutes — flip flag back |
| **Dual-write** | Write paths (need both stores in sync during cutover) | Minutes — promote one store, demote the other |
| **Read-from-V2 + write-to-both** | Read paths that mutate via V1 elsewhere | Minutes — flip read flag |
| **One-shot cutover** | Trivial features only (health checks, internal tools) | Re-deploy |

## Rollback protocol

Pre-conditions for any cutover stage advance:

- Rollback path tested in staging within the last 7 days.
- Person on-call has access to the cutover mechanism (flag dashboard, admin panel, deploy pipeline).
- Runbook exists at `ai/runbooks/migration-rollback-<feature>.md`.

Trigger conditions (any one halts cutover + rolls back):

- Error rate (V2) > 1.5× error rate (V1 at same traffic level).
- Latency p95 (V2) > 1.5× latency p95 (V1 at same traffic level).
- Any business KPI delta > N% (per-feature N negotiated in plan).
- A parity test that was green now reds (regression introduced post-cutover).
- A user-reported issue traced to V2 with parity gap as root cause.

## Examples from codebase

> Phase 4.6 fills this section with 1-2 features from the codebase that have already been ported (or are planned), citing their contract / plan / parity-tests / perf-decisions. If none yet, leave a TODO.

## Pitfalls (named)

- **Reading V1 once and feeling done.** Re-read on every contract revision. V1 has decade-old conditionals that look obvious but encode a 2018 contract.
- **Skipping shadow because "it's just a refactor."** It's not a refactor — it's a rebuild. Shadow always runs.
- **Treating the contract as eternal.** The contract gets revised when phase 4 (parity-test) finds a behaviour the contract didn't capture. Revise the contract, re-pin V1, continue.
- **Letting a perf change "obviously" preserve parity.** Run the parity tests. Until they're green, you don't know.
- **Touching V1 to make it match V2.** Never. V1 is the oracle. If V1 is wrong, fix it AFTER V2 is on 100%, never during port.
- **Counting the port done at 100% canary.** The port is done at "V1 deleted + last commit referencing V1 is older than retention window."
- **Skipping the ledger update because "I'll do it after the PR merges."** The ledger update IS part of the PR. Phase 5 verification halts on drift.
