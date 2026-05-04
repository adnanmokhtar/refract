---
name: migration-discipline
kind: example
pack: migration
---


> **STACK ASSUMPTION**: this example uses Vue 3 + PrimeVue + TypeScript syntax for illustration. The rule / pattern / anti-pattern itself is universal; substitute your project's primitives from `_extracted-idioms.md`. The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack pack's fingerprint set automatically.

# Migration Rule: V1→V2 port discipline

> **Project-specific values** — V1 root, V2 root, parity-test location, cutover mechanism, caching primitive, DB query primitive — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Migration-pack-specific anchors live in `ai/migration/_v2-anchors.md`.

This rule governs every per-feature port. It exists because the most common migration failure is **subtle behavioural drift** — V2 *almost* matches V1, ships, and a long-tail of customer issues surface over months. The second most common is **scope creep** — the port becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed.

## Must

- **Read V1 before writing V2.** Use `extract-v1-contract` to produce `ai/migration/contracts/<feature>.md` covering: every input shape, every output shape, every side effect (DB writes, external calls, queue publishes, cache invalidations), every error path with its observable shape, every business rule discovered (including the ones encoded only in conditionals), every implicit invariant (ordering, idempotency, retry behaviour), every undocumented edge case (search git log + tests + comments). The contract is the spec V2 must satisfy.
- **Generate parity tests before V2 code.** Use `parity-test-generate`. Tests run V1 + V2 against identical inputs and assert equivalence per the tolerance taxonomy (exact / structural / numeric tolerance / order-insensitive / timestamp-insensitive). Red baseline before V2 is fine — green is required before cutover.
- **One feature per port PR.** Atomic unit = one feature in the migration ledger. Multi-feature PRs hide regressions and make rollback ambiguous.
- **Update the ledger on every state transition.** `V1-only → In-progress → V2-shadow → V2-canary → V2-only → V1-deleted`. The ledger is the source of truth — code grep is not.
- **Cutover is gated.** Move from V2-canary → V2-only only when: (1) parity tests green, (2) shadow / canary metrics show no regression on error rate / latency / business KPIs for the agreed observation window, (3) the relevant ADR (if any) is merged, (4) rollback path tested.
- **Delete V1 only when last reference is gone.** Use `git grep` + dead-code analyser + telemetry "no traffic in N days" before deletion. The ledger transition `V2-only → V1-deleted` requires evidence attached.
- **Document every intentional behaviour break.** If V2 changes a contract from V1 (e.g., V1 returned `null` on missing user, V2 throws), it MUST be in `ai/decisions/<NNN>-<feature>-v2-break.md` with: V1 behaviour, V2 behaviour, why the break is necessary, who's affected, migration path for callers, deprecation timeline.
- **Capture migration-time perf wins explicitly.** Run `perf-uplift-survey` during port. For each candidate (N+1 → batch query, missing index, unbounded SELECT *, sequential await, no caching), decide: applied / deferred / rejected — with a reason. Decisions live in `ai/migration/perf-decisions/<feature>.md`. A perf change MUST NOT silently break parity — it's either parity-preserving (most cases — same observable, faster) or it's a documented break (above bullet).
- **Use V2's primitives, not V1's.** If V2's architecture says "service-layer + repository", DO NOT carry over V1's "fat controller". The port is the moment to align with V2 — that's the entire point.
- **Keep V1 untouched during port.** No "while I'm here" fixes in V1 code. V1 is the oracle for parity testing — if you change V1 you've changed the oracle.

## Must not

- **Copy-paste V1 into V2.** Even if the V2 architecture happens to look the same shape — the port must be re-derived from the contract, not transposed line-by-line. Copy-paste smuggles V1's hidden invariants (which V2's structure may not satisfy) and reproduces V1's bugs.
- **Skip the contract step.** "V1 is small / I read it once / it's obvious" — every regression post-cutover is preceded by this sentence. The contract takes hours; the regression takes weeks.
- **Skip parity tests because "the unit tests cover it".** Unit tests in V1 test what V1's authors *thought* it did. Parity tests pin what V1 *actually* does — production has called V1 with inputs no unit test covers. Use record-replay against real production traffic samples (anonymised).
- **Bundle features in one port PR.** "Port the user module" is not one feature — it's `getUser`, `listUsers`, `searchUsers`, `updateUser`, etc. Each is its own port + its own ledger row.
- **Bundle perf changes that break parity into the port PR.** Either it preserves parity (ship in port PR) or it changes contract (separate PR + ADR + caller migration plan + deprecation window).
- **Cutover without rollback path.** A feature flag that can't be flipped back, a DB schema change without a reversible migration, a deleted V1 path — all of these turn a 2-minute incident into a 2-hour incident.
- **Leave the ledger stale.** A merged PR that ports a feature without updating `ai/migration/ledger.md` is incomplete. Phase 5 verification halts on ledger drift.
- **Use V2's "future" architecture as a moving target.** Pin V2's architecture before the migration starts. If V2's architecture itself needs to evolve, finish or pause the migration first.
- **Ignore non-functional behaviour.** Latency p95, memory footprint, error rate, log volume are part of the contract. A V2 that returns the same JSON 5× slower has not preserved parity.
- **Mix migration with feature work.** "We're porting search and adding fuzzy matching" guarantees both regressions and missed scope. Port first (parity-equivalent), ship cutover, then add the feature on V2.
- **Treat "no test exists for this in V1" as "no behaviour exists".** Read git log, read PR descriptions, read related issues, run V1 against fuzz inputs — V1's untested behaviour is still observable, still load-bearing for some caller.

## Should

- **Slice vertically (full feature) over horizontally (just data layer).** Vertical slices ship value + can be cut over independently. Horizontal slices (port all controllers, then all services, then all repos) leave V2 unusable until the last layer ports.
- **Pick the lowest-risk feature for the first port.** Health checks, read-only endpoints, internal admin tools — they exercise the toolchain without exposing customers to a parity bug. The first port shakes out the parity-test infrastructure, the ledger workflow, the cutover path.
- **Run V1 + V2 in shadow before canary.** Shadow = V2 receives the same input but its output is compared (not served). Catches behavioural drift the parity test suite missed. Run for ≥1 week per high-traffic feature.
- **Anchor perf-uplift candidates to a measurement.** Don't add Redis caching in V2 because "caching is fast." Capture V1's call rate + payload size + cache-hit projection + estimated DB load reduction. The decision file must show the math.
- **Index proactively when V2's query shape differs from V1.** Different `WHERE` clause = different optimal index. Use `EXPLAIN ANALYZE` on V2's query plans against prod-sized data before cutover — see `database/skills/migration-rehearsal.md`.
- **Project columns minimally.** V1's `SELECT *` becomes V2's `SELECT id, name, status` if those are all the consumer needs. Less network bandwidth, less ORM hydration, less GC pressure. The contract should list the *consumed* columns, not the *queried* ones.
- **Replace sequential await loops with bounded parallelism.** During port, sequential `for await` patterns in V1 are the highest-leverage perf upgrade — see `backend/rules/concurrency-discipline.md` + `backend/skills/parallelize-independent-ops.md`. Always preserves parity (assuming independence).
- **Cap the contract in writing.** A 500-line contract is fine. A 50-page contract means the feature is too big — split it before porting.
- **Run parity tests against a frozen V1 commit.** Pinning the parity oracle prevents "V1 evolved while we ported V2" — the ledger row records the V1 commit hash used.

## Examples per concern (parity / scope / perf-uplift / cutover)

### Parity preservation

```text
# ❌ Behavioural drift (silent break)
V1: getUser(missingId) returns null
V2: getUser(missingId) throws NotFoundError

→ Caller code that did `if (user) {...}` now crashes.
→ This is an INTENTIONAL break that requires an ADR + caller-migration plan.
→ It MUST NOT ship in the port PR. The port preserves V1's null-return; the break ships separately on V2 only.

# ✅ Parity-preserving improvement
V1: SELECT * FROM users WHERE id = ?  (returns 47 columns, hydrates 47-field model)
V2: SELECT id, name, email, status FROM users WHERE id = ?  (returns 4-field DTO)

→ External observable: a JSON object with the 4 fields the caller documented (V1's caller never read the other 43).
→ Parity test asserts the 4 fields match V1's response shape.
→ Network + memory + GC win, no contract change.
```

### Scope discipline

```text
# ❌ Mission creep
Port PR title: "Port /reports/orders + add CSV export + cache + pagination"
→ 4 things in 1 PR. Reviewer can't tell which change caused which delta. Rollback is all-or-nothing.

# ✅ Atomic
Port PR 1: "Port /reports/orders (parity-equivalent)" — V2 endpoint shadows V1, parity green.
Perf PR 2: "Add Redis cache to /reports/orders V2" — measurement included, parity tests still green.
Feature PR 3: "Add CSV export to /reports/orders V2" — V1 didn't have this; pure-V2 feature, on V2 only.
Feature PR 4: "Paginate /reports/orders V2 (deprecating non-paginated response)" — ADR + caller migration plan attached.
```

### Migration-time perf uplift (the user's specific concern)

| V1 anti-pattern | V2 with parity-preserving uplift |
|---|---|
| `for (id of ids) const u = await getUser(id)` (10 sequential awaits) | `Promise.all(ids.map(id => limit(() => getUser(id))))` with `pLimit(8)` — bounded parallel |
| 1 query + N follow-ups (`getOrders` then `getCustomer(o.customerId)` per order) | Single JOIN OR `getCustomersByIds(unique(orderCustomerIds))` (batch) |
| `SELECT * FROM users` consumed by template that uses 3 fields | `SELECT id, name, status FROM users` |
| No cache; same lookup repeated per request | Per-request memoisation (request-scoped cache) OR cross-request cache (Redis) with explicit TTL + invalidation rule |
| Missing index on `WHERE created_at > ? AND status = ?` (V2 query shape changed) | New migration adds composite `(status, created_at)` index; rehearse via `migration-rehearsal` |
| `findAll().filter(x => x.active)` | `findWhere({ active: true })` — push the filter to the DB |
| Single 200-row `INSERT` per loop | Batched `INSERT INTO ... VALUES (...), (...), (...)` |
| Synchronous external HTTP in a hot path | Move to background job + return optimistic response (only if contract allows; ADR otherwise) |

Each row in this table is a `perf-uplift-survey` finding. Each finding gets a decision in `ai/migration/perf-decisions/<feature>.md`: applied / deferred / rejected, with: V1 cost (wall-clock + DB load), expected V2 saving, parity-preservation argument.

### Cutover rigor

```text
# ❌ Big-bang cutover
Day 1: Deploy V2; flip env var V2_ENABLED=true; route 100% traffic.
Day 2: Customer reports breakage; rollback requires re-deploy.

# ✅ Progressive cutover
T+0d: Shadow — V1 serves; V2 receives copy of every request; outputs compared offline.
T+7d: Parity-bug fixes from shadow; shadow re-runs clean for 7 days.
T+14d: Canary 1% — V2 serves 1% of traffic. Watch error rate / latency / business KPIs for 24h.
T+15d: 10%. T+16d: 50%. T+17d: 100%.
T+24d: V1 traffic = 0 confirmed via telemetry.
T+38d: Delete V1 (after 14d of zero traffic).
```

## Review checklist

- [ ] `ai/migration/contracts/<feature>.md` exists, lists I/O / side-effects / errors / invariants / edge cases — with `<path>:<line>` citations into V1.
- [ ] Parity tests exist in `<extracted parity dir>`, run V1 + V2, assert per tolerance taxonomy.
- [ ] Parity tests green against the V1 commit pinned in the ledger row.
- [ ] PR title + scope = exactly one ledger feature row.
- [ ] Ledger row updated with new state, V1 commit hash, V2 commit hash, evidence (parity-test run ID, shadow report link, canary metrics dashboard).
- [ ] No V1 files modified in this PR.
- [ ] Any contract break is in a separate PR with an ADR + caller-migration plan.
- [ ] `ai/migration/perf-decisions/<feature>.md` records every perf candidate from `perf-uplift-survey` as applied / deferred / rejected with rationale + measurement.
- [ ] V2 query plans rehearsed against prod-sized data; new indexes ship with reversible migrations.
- [ ] V2's column projection is minimal (matches the documented consumed columns).
- [ ] Cutover plan attached: shadow window, canary stages, rollback steps, success metrics.
- [ ] V1 deletion (if in scope) shows zero-traffic evidence + dead-code-finder report.

## Enforcement

- **Phase 5 audit** halts on: ledger drift (PR ports a feature without updating ledger), missing contract file, parity-test red, perf-decision file missing.
- **`/migration-status` command** reports per-feature state and flags rows older than the SLA (e.g., a feature in `In-progress` for >30d is flagged stalled).
- **`parity-auditor` agent** is invoked in PR review; its checklist hard-fails on missing parity tests, missing contract, scope-creep evidence (V1 modifications in a port PR).
- **Phase 4.6 STUDY-DECIDE-ACT** anchors this rule to the project's actual V1/V2 paths, ledger location, and cutover mechanism. A rule that talks about generic feature flags while the project uses Django settings + URL routing is a leak — the project-specific block is mandatory.

## Anti-patterns (named)

- **The Transposition Trap** — line-by-line copy of V1 into V2. Carries V1's bugs + V1's hidden invariants. The port must be re-derived from the contract.
- **The Bundled Cutover** — porting + redesigning + adding features + perf-tuning in one PR. Reviewer cannot localise regressions; rollback is all-or-nothing.
- **The Stale Oracle** — V1 evolves during port; parity tests pass against a moving target. Pin V1's commit; freeze it for the duration of the port.
- **The Silent Break** — V2 changes an output shape, returns a different error type, drops a side effect. Ships unnoticed; long-tail customer issues surface for months.
- **The Test-by-Test Port** — porting V1's unit tests verbatim. Misses production behaviours that V1 has but V1's tests don't cover. Use record-replay against real traffic samples (anonymised).
- **The Eternal Shadow** — V2 lives in shadow indefinitely "until we're sure". The longer V2 stays in shadow, the more divergent it becomes from V1 (which keeps shipping). Set a cutover deadline; if missed, re-baseline parity.
- **The Buried Perf "Improvement"** — an N+1 fix that quietly changes ordering / nullability / ID stability. The "improvement" is a contract break; ships under the port PR; surfaces as a bug 6 weeks later.
- **The V1 Deletion Sprint** — deleting V1 modules en masse "to clean up." A single `import` left in a stale cron job means a silent prod failure when the cron next fires. Delete only when last reference is gone + telemetry confirms zero traffic.

## References

- `.claude/skills/extract-v1-contract.md` — how to read V1 deeply and produce the contract.
- `.claude/skills/parity-test-generate.md` — how to build the parity test suite.
- `.claude/skills/perf-uplift-survey.md` — how to find migration-time perf wins.
- `.claude/agents/migration-architect.md` — strategic per-feature planner.
- `.claude/agents/parity-auditor.md` — pre-cutover audit.
- `.claude/commands/port-feature.md` — the orchestrator.
- `ai/patterns/feature-port.md` — per-feature lifecycle.
- `ai/patterns/parity-testing.md` — test technique catalogue.
- `ai/patterns/migration-ledger.md` — state-machine + record format.
- `code-quality/agents/legacy-modernizer.md` — strategic-level migration (sets the feature inventory this rule operates inside).
- `backend/rules/concurrency-discipline.md` — the parallel-I/O bullet under "Should" links here.
- `database/skills/migration-rehearsal.md` — DB-only migration rehearsal (used during V2 query plan + index changes).
