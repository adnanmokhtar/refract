---
name: migration-discipline
kind: example
pack: migration
---


> **STACK ASSUMPTION**: this example uses Vue 3 + PrimeVue + TypeScript syntax for illustration. The rule / pattern / anti-pattern itself is universal; substitute your project's primitives from `_extracted-idioms.md`. The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack pack's fingerprint set automatically.

# Migration Rule: V1→V2 port discipline

> **Project-specific values** — V1 root, V2 root, parity-test location, cutover mechanism, caching primitive, DB query primitive — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Migration-pack-specific anchors live in `ai/migration/_v2-anchors.md`.

This rule governs every per-feature port. It exists because the most common migration failure is **subtle behavioural drift** — V2 *almost* matches V1, ships, and a long-tail of customer issues surface over months. The second most common is **scope creep** — the port becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed.

## CORE PHILOSOPHY — read this first, internalize, do not deviate

**V1 is the production reference. V1 is sacred truth.** We are in MIGRATION mode, not refactor mode. V1's behaviour, API, permissions, response shapes and error contracts are the PRODUCTION CONTRACT. V2's job is to mirror that contract while using V2's structure.

1. **Do NOT halt to verify V1.** The auditor reads V1 source DIRECTLY and treats what it reads as the contract. There is no "confirm with the user that V1 actually does this" step — V1 source IS the verification.
2. **API verification is not a halt condition.** Halts fire for V2-deviation-from-V1 or artifact-completeness, never for "V1 might be wrong". A V1 bug is either a documented behaviour we preserve (`known_v1_bug` in the contract) or a user-decided break (ADR + caller migration).
3. **API samples are HELPFUL, not REQUIRED** when V1 source is unambiguous — missing api-samples WARN, they do not halt.
4. **We are NOT refactoring.** If V1 has odd query params, V2 has the same odd query params. Mid-migration "while I'm here" improvements are FORBIDDEN; refactor happens after migration, on V2-only, with its own ADR.
5. **Halts that DO fire**: V2 deviates from V1 · cross-repo blocker · a contract break the user wants · dead V1 code being ported · an artifact missing for the row's tier.

**Project-level anchor for V1 stability** (in `ai/migration/_v2-anchors.md`): `v1_status: production-stable | actively-developed | frozen` · `v1_api_frozen:` · `v1_reference_commit:`. Under `production-stable`, V1-side verification halts are SKIPPED and api-samples WARN; under `actively-developed`, the pinned commit is the oracle and api-samples remain a hard halt.

**TL;DR: in migration mode, V1 is gospel. Don't ask, port.**

## Required artifacts per feature — tiered floor

Every feature port produces an artifact set scaled to its actual risk. Tier is set on the ledger row **by the audit** and propagates through the port; the default is trivial.

| Tier | Triggers (any one promotes) | Required artifacts |
|---|---|---|
| **trivial** (DEFAULT) | No promoter triggers | Audit + code edit + ledger note |
| **standard** | 1–3 P1 gaps OR single API contract divergence OR <300 LOC change | Audit + code edit + 3-section contract (Inputs/Outputs/Known V1 bugs) + short plan + 10-fixture parity test + ledger row |
| **heavy** | Any P0 OR cross-repo blocker OR contract break OR storefront blast radius OR write-path mutation OR security-sensitive | Full 8-artifact set |

The audit MUST state the tier in 1-2 sentences citing trigger absence/presence. A user may upgrade a tier at any time but cannot downgrade without an ADR. `/migration-gate <N>` validates the artifact set **for the row's tier**, not the heavy floor universally.

## Anti-bloat rules

Merge gates (not suggestions), from the Phase 7 incident (~95% docs / ~5% code): **code edits are the deliverable** · ADRs justify USER-decided breaks only (agent-default closure = edit V2 to match V1) · per-axis enumeration required wherever a gap exists, at every tier (hand-wave grep HALTs on `etc.` / `...` / `N+ items`) · single agent dispatch + shared 5K context blob by default · default-true wrapper props set explicitly when removing UI affordances (F040) · audit verdict = V1-parity, NOT plan-execution · trivial tier produces no contracts/plans/perf-docs/runbooks. Full gate definitions + tier artifact specs: `.claude/references/migration-discipline-procedures.md § Anti-bloat rules`.

## Contract — 9 required sections

The contract at `ai/migration/contracts/<feature>.md` MUST contain all 9 sections — 1. Inputs · 2. Outputs (per code path) · 3. Side effects · 4. Business rules · 5. Invariants · 6. Performance baseline · 7. Caller assumptions · 8. Edge cases · 9. Known V1 bugs — every claim cited `<path:line>`; a contract missing any section is incomplete and the audit halts. Full section-by-section template: `.claude/references/migration-discipline-procedures.md § Contract template`.

## Per-feature audit — 13 hard halts

The audit runs against an implementation + its artifacts and HALTS (refuses to advance the feature) on any of these 13 conditions:

1. **Contract missing or incomplete** — the file doesn't exist, a section is empty, or a `<path:line>` citation doesn't resolve.
2. **Parity tests missing or thin** — no parity dir, `tolerance.yaml` doesn't cover every documented output field, corpus under 30 entries with no record-replay alternative, or no entry per happy path / error path / business rule / edge case.
3. **Parity tests not green** against the V1 commit pinned in the ledger — or tolerance loosened in the same PR (loosening = separate PR + ADR).
4. **Plan missing** or not matching the actual implementation (V2 module shape, cutover plan, rollback path).
5. **Perf-decisions missing or incomplete** — a candidate unclassified, an `applied` candidate with no measurement, or an `applied` candidate that is `parity_preserving: no`.
6. **V1 modified in the port PR** (only exception: additive cutover-mechanism wiring that doesn't change V1 behaviour).
7. **Ledger drift** — row not updated, required fields for the new state unpopulated, or pinned V1 commit ≠ the commit parity tests ran against.
8. **Rollback runbook missing** or not naming the cutover mechanism + per-stage rollback steps + on-call assignment.
9. **Scope creep** — PR ≠ exactly one ledger feature row, diff touches files outside V2's `<feature>/`, or contains unrelated "while I'm here" refactors.
10. **Cutover mechanism not tested in staging** — no evidence the rollback path was executed in staging within the last 7 days (Shadow → Canary advance only).
11. **Dead V1 code in port queue** — zero callers across all 6 reachability axes. Halt the port; mark the row `status: deprecated`, `deprecation_reason: dead-v1-no-callers`. Override: `--include-dead` + a 1-line `caller_evidence: <path:line>`.
12. **UI surface audit row missing v1_states / v2_states enumeration** — any UI row must enumerate every interaction state V1 exposes (idle / loading / opened / single-result / empty / error / hover / disabled / each conditional-render branch). One-line rows HALT.
13. **Module/page audit missing navigation inventory** — a Navigation Inventory (Section 0, BEFORE per-axis work) mapping every clickable label/route in V1 to V2 1:1. A V1 nav leaf with no V2 navigation surface is DRIFT, not STRUCTURE_OK. The scan is TWO-LAYER (route tree + per-leaf template grep); a Layer-A-only scan is incomplete and HALTS.

**Output of any halt**: a structured remediation list — specific finding + specific action — written to the audit file. NO advance until each halt is cleared. Tier gating: halts 1, 2, 4, 5, 8 are artifact-existence checks gated by the row's `tier:`; halts 3, 6, 7, 9, 10, 11, 12, 13 apply across **all** tiers.

## What counts as dead V1 code (the 6-axis check)

A V1 feature is dead — and must NOT be ported — only when **all six** reachability axes return zero callers: 1. app-source callers · 2. test references (downstream, not the feature's own) · 3. cron/scheduler config · 4. route/API registration · 5. infra/deploy config · 6. production telemetry (N/A if unwired). One live axis → port it. Override: `--include-dead` + `caller_evidence: <path:line>`, logged in `_history.md`. Full axis definitions + edge cases (public APIs, library exports, in-development, flag-gated): `.claude/references/migration-discipline-procedures.md § Dead V1 code — 6-axis check`.

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
- **Index proactively when V2's query shape differs from V1.** Different `WHERE` clause = different optimal index. Use `EXPLAIN ANALYZE` on V2's query plans against prod-sized data before cutover — see `database/skills/migration-rehearsal/SKILL.md`.
- **Project columns minimally.** V1's `SELECT *` becomes V2's `SELECT id, name, status` if those are all the consumer needs. Less network bandwidth, less ORM hydration, less GC pressure. The contract should list the *consumed* columns, not the *queried* ones.
- **Replace sequential await loops with bounded parallelism.** During port, sequential `for await` patterns in V1 are the highest-leverage perf upgrade — see `backend/rules/concurrency-discipline.md` + `backend/skills/parallelize-independent-ops/SKILL.md`. Always preserves parity (assuming independence).
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
- **`/migration-status` command** reports per-feature state and flags rows older than the SLA (e.g., a feature in `In-progress` for >30d is flagged stalled). The SLA defaults are declared in `/migration-status` itself and in `.claude/references/migration-discipline-procedures.md § Enforcement matrix` — this rule does not set them, it cites them.
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
- **The Zombie Port** — porting a V1 feature with zero callers across all 6 reachability axes. Dead code migrated into V2 inflates its surface and accretes maintenance for code no consumer exercises. Halt #11 excludes it at scan time.
- **The Trusted Summary** — delegating V1↔V2 comparison to a search/exploration agent that reports "looks identical", then echoing that into the audit without verifying against source. Every "identical" claim carries a `<path:line>` citation that resolves, or the audit halts.

The full named catalogue — **Zombie Port · Transposition Trap · Bundled Cutover · Stale Oracle · Silent Break · Test-by-Test Port · Eternal Shadow · Buried Perf "Improvement" · V1 Deletion Sprint · Trusted Summary · Hand-waved Query Param · Optimistic Form Field Match · Permission-gate Drop · Guessed Type · Reinvented Wrapper · Silent Catch · Wrong Lifecycle Hook on Nested Child · Misplaced i18n Key · Consumer Compensation · Auto-import Trip** — with fingerprints, real-world costs, and fixes is in `.claude/references/migration-discipline-catalogue.md § Anti-patterns`. The names above are load-bearing vocabulary; audits cite them; the catalogue holds the definitions.

## References

- `.claude/skills/extract-v1-contract/SKILL.md` — how to read V1 deeply and produce the contract.
- `.claude/skills/parity-test-generate/SKILL.md` — how to build the parity test suite.
- `.claude/skills/perf-uplift-survey/SKILL.md` — how to find migration-time perf wins.
- `.claude/agents/migration-architect.md` — strategic per-feature planner.
- `.claude/agents/parity-auditor.md` — pre-cutover audit.
- `.claude/commands/port-feature.md` — the orchestrator.
- `ai/patterns/feature-port.md` — per-feature lifecycle.
- `ai/patterns/parity-testing.md` — test technique catalogue.
- `ai/patterns/migration-ledger.md` — state-machine + record format.
- `code-quality/agents/legacy-modernizer.md` — strategic-level migration (sets the feature inventory this rule operates inside).
- `backend/rules/concurrency-discipline.md` — the parallel-I/O bullet under "Should" links here.
- `database/skills/migration-rehearsal/SKILL.md` — DB-only migration rehearsal (used during V2 query plan + index changes).
