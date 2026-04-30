---
name: migration-discipline
description: Migration Rule: V1→V2 port discipline
kind: rule
pack: migration
---

# Migration Rule: V1→V2 port discipline

> **Project-specific block** — Phase 4.6 fills this in from `.claude/_extracted-codebase.md § Migration` + `_extracted-idioms.md`. Do **not** delete; if extraction is empty, leave the placeholder + open a TODO.
>
> - **V1 root**: `<extracted-from-codebase>` (e.g., `apps/web-v1/`, `Reports/views.py`, `legacy/`)
> - **V2 root**: `<extracted-from-codebase>` (e.g., `apps/web/`, `reports_v2/`, `src/v2/`)
> - **Migration ledger**: `ai/migration/ledger.md` (per-feature state machine)
> - **Parity test location**: `<extracted>` (e.g., `tests/parity/`, `__tests__/parity/`)
> - **Cutover mechanism**: `<extracted>` (feature flag system OR router rule OR env var OR build flag)
> - **Caching primitive in V2**: `<extracted>` (e.g., Redis client at `<path:line>`, in-process LRU helper, framework cache adapter)
> - **DB query primitive in V2**: `<extracted>` (ORM + connection-pool location + index migration tool)

This rule governs every per-feature port. It exists because the most common migration failure is **subtle behavioural drift** — V2 *almost* matches V1, ships, and a long-tail of customer issues surface over months. The second most common is **scope creep** — the port becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed. The third most common is **trusted summary** — an executor delegates V1↔V2 comparison to a search/exploration agent, the agent reports "looks identical" in confident summary language, and the executor echoes that into the audit without verifying the claim against source. F039 in tenant-portal-v2 (Apr 2026) is the canonical example: a missing "add new mapping" UI button + a divergent query-param surface both passed audit because the summary said "identical."

**This rule is the universal contract** — it must be enforceable by any AI tool. Tools with full capability (commands + agents + skills + hooks) compose the discipline by dispatching `/port-feature` → `parity-auditor` → `extract-v1-contract` etc. Tools with rules only (Aider, Codex, Gemini) enforce the discipline by reading and following this file directly. Therefore: the procedural detail is inlined here, not just referenced. Do not delete the inlined procedures in favour of references; rule-only tool users have no other surface.

## Required artifacts per feature — tiered floor

Every feature port produces an artifact set scaled to its actual risk. The discipline is **tiered**, not one-size-fits-all: a 1-line bulk-delete URL fix and a 25-file payment-flow rewrite have different audit needs. Tier is set on the ledger row at audit time and propagates through the port.

> **Why this is tiered (added 2026-04-30 from tenant-portal-v2 Phase 7 lesson)**: prior single-floor discipline produced ~95% docs / ~5% code on small features (all 8 artifacts mandatory regardless of feature size). 1-line fixes generated 5-section contracts + 30-fixture parity tests + 12-candidate perf surveys + 7-stage runbooks. The tiered model preserves the F039 anti-Trusted-Summary protections on heavy features while letting trivial features ship in proportion.

### Tier classification (set by audit; trivial-by-default)

| Tier | Triggers (any one promotes) | Required artifacts |
|---|---|---|
| **trivial** (DEFAULT) | No promoter triggers | Audit + code edit + ledger note |
| **standard** | 1–3 P1 gaps OR single API contract divergence OR <300 LOC change | Audit + code edit + 3-section contract (Inputs/Outputs/Known V1 bugs) + short plan + 10-fixture parity test + ledger row |
| **heavy** | Any P0 OR cross-repo blocker OR contract break OR storefront blast radius OR write-path mutation OR security-sensitive | Full 8-artifact set per § "Heavy-tier artifact spec" below |

**Rules**:
- **Default tier is trivial.** Every audit starts at trivial UNLESS findings include P0 OR cross-repo blocker OR security/privacy concerns OR contract break OR write-path mutation. The prior "heavy by default" rule is replaced — heavy ceremony was overproducing docs (~95% docs / ~5% code on simple ports per Phase 7 lesson).
- Tier is **set by audit**, written to the ledger row's `tier:` field. Without explicit promoter triggers, the row stays trivial.
- Heavy tier requires either (a) an audit-flagged trigger above, OR (b) explicit user opt-in via `/port-feature <feature> --heavy`.
- User can **upgrade** a tier (trivial → standard → heavy) anytime but cannot downgrade without an ADR.
- Audit MUST state the tier in 1-2 sentences citing trigger absence/presence.
- `/migration-gate <N>` validates the artifact set **for the row's tier**, not the heavy floor universally.
- If a port produces more than the tier requires, that's allowed but not required — the rule does not reward over-production.

## Anti-bloat rules

Phase 7 in tenant-portal-v2 (Apr 2026) burned ~95% of port-time tokens on documentation that did not enable any code change. These rules prevent recurrence — they are merge gates, not suggestions.

- **Code edits are the deliverable.** A doc that doesn't enable a code change is waste. Contracts/plans/runbooks/perf-decisions exist when they unblock a code decision; they are not deliverables themselves.
- **ADRs justify user-decided breaks, not agent-default closures.** When V2 deviates from V1, the agent's default closure verb is **edit V2 to match V1** — a code change. Drafting an ADR to legitimize V2's deviation is forbidden as a closure unless the user explicitly chose keep-V2 OR V1 is a security/privacy/legal regression. The Phase 7 anti-pattern (~6 ADRs drafted to preserve V2-over-V1) MUST NOT recur.
- **Per-axis enumeration is required wherever a gap exists, at every tier.** Heavy-tier audits enumerate every axis fully (F039 anti-Trusted-Summary protection). Standard- and trivial-tier audits MAY summarise axes with zero gaps in 1 line, but ANY axis with ≥1 detected gap (add / delete / change, frontend or API) MUST produce the full per-row enumeration table for that axis with `<v1-path:line>` and `<v2-path:line>` citations. Trivial-tier audits with summary-only text and ≥1 gap detected silently are forbidden — the validator's `check_audit` hand-wave grep (in `validate-migration-artifacts.sh`) HALTs on `etc.`, `...`, `N+ items`, `and so on`, `deferred to port-phase parity author`, and `by audit-by-inspection`.
- **Single agent dispatch with a shared 5K-token context blob is the default.** Parallel sub-agents are heavy-tier-only AND require a deduplicated context blob (each sub-agent reading 50K+ token files independently is forbidden — prior Phase 7 cost: 200-360K duplicate tokens per port).
- **Default-true wrapper props MUST be set explicitly when removing UI affordances.** Components like `<CrudActions>`, `<TableHeader>`, `<TableActions>` default `show-*` / `can-*` props to `true`. Removing a `@delete-selected` event handler does NOT hide the button. The fix is `:show-delete="false"` / `:can-delete="false"` set explicitly. Removing the handler alone is the F040-class default-true bug.
- **Audit verdict criterion is V1-parity, not plan-execution.** "PASS" means V2 matches V1, NOT "the agent shipped what the plan said." Phase 7 audits drifted into plan-execution checks; the discipline reverts.
- **Trivial-tier ports do not produce contracts, plans, perf-decisions, or runbooks.** The audit + ledger note carry the risk register. Heavy-tier opt-in is required for those artifacts.

### Heavy-tier artifact spec (the historical floor)

| Artifact | Path | Purpose | Mandatory sections |
|---|---|---|---|
| Contract | `ai/migration/contracts/<feature>.md` | The spec V2 must satisfy. Re-derived from V1 source, not from a summary. | See § "Contract — 9 required sections" below. |
| Plan | `ai/migration/plans/<feature>.md` | V2 module shape, parity strategy, cutover plan, rollback path, non-goals. | V2 module shape, dependencies, parity strategy, perf-uplift candidates (planned), cutover plan, rollback path, non-goals, risks. |
| Parity tests | `<parity-test-root>/<feature>/` | Runnable assertion that V2 matches V1 within tolerance. | Input corpus (≥30 inputs OR record-replay), `tolerance.yaml`, golden snapshots OR property tests, runner integration. |
| Tolerance | `<parity-test-root>/<feature>/tolerance.yaml` | Per-field equivalence rules. | Every contract output field has a tolerance entry (`exact` / `structural` / `numeric_tolerance` / `order_insensitive` / `ignore`). |
| Perf decisions | `ai/migration/perf-decisions/<feature>.md` | Every perf-uplift candidate classified. | One row per candidate (applied / deferred / rejected) with V1 cost, V2 estimate, parity argument, measurement. |
| Rollback runbook | `ai/runbooks/migration-rollback-<feature>.md` | Concrete steps to flip back to V1. | Mechanism, per-stage rollback steps, on-call assignment, data reconciliation steps for write paths. |
| Audit | `ai/migration/audits/<feature>.md` | Per-feature finding from parity audit. | Classification, per-axis comparison, gaps, tenant-isolation gate, decision recommended, ADR references, notes. |
| Ledger row | `ai/migration/ledger.md` § `<feature>` | Source-of-truth state machine row. | Per-state required fields per `migration-ledger.md`. |

### Standard-tier artifact spec (light floor)

- **Contract**: 3 sections only — Inputs (form fields + query params), Outputs (per code path), Known V1 bugs. Cite `<path:line>` per claim. Skip side effects / business rules / invariants / perf baseline / caller assumptions / edge cases as separate sections — fold the load-bearing items into the relevant section if surfaced by audit.
- **Plan**: 1 page — V2 files to touch, gap closures (1 line each), perf candidates classified inline (no separate doc), cutover = "per-tenant DNS, no special handling".
- **Parity tests**: ≥10 fixtures (not 30), tolerance.yaml covers contract output fields.
- **Audit**: standard structure, no enumeration of every form field/button on a page that has no P0/P1 gaps.
- **Skip** (compared to heavy): no separate perf-decisions doc, no separate rollback runbook, no separate plan-vs-implementation reconciliation. Audit + ledger row carry the risk register.

### Trivial-tier artifact spec (audit + code only)

- **Audit**: classification + 1-paragraph "what changed" + 1-paragraph "why no contract" + **per-axis enumeration table for any axis with ≥1 gap** (frontend axes per `parity-auditor.md` §  frontend axes; API axes per § backend axes). Axes with zero gaps may be summarised in 1 line. A trivial audit that hides ≥1 gap inside summary prose without the per-row table is rejected.
- **Code edit**: the actual gap-closure(s) — **all gaps from the audit, not a subset**. Gap-count-in MUST equal gap-count-closed before the row advances. The `find-and-fix` re-DETECT step enforces this.
- **Ledger row**: status, parity_test (if any), v1_commit_pinned, ported_at, 2-line note, `gaps_in: <N>`, `gaps_closed: <N>` (must be equal).
- **No** contract, plan, separate parity tests, perf-decisions, runbook. Standard CI tests must still pass.

**Output of `/migration-gate <N>` validates the artifact set required by each row's tier; a missing artifact at the row's tier REFUSES the gate. Heavy-tier rows still hit the full 8 artifacts.**

## Contract — 9 required sections

The contract document at `ai/migration/contracts/<feature>.md` must contain ALL 9 sections below. A contract missing any section is incomplete; the audit halts.

```markdown
# Contract: <feature>

> V1 entry point: `<v1-path:line>`
> V1 commit pinned: `<sha>`
> Author: <name> | Reviewed: <name> | Date: <iso>

## 1. Inputs
For each input parameter / form field / query param / header / file upload:
- Name, type, constraints (declared validators + ad-hoc conditionals), default, required vs optional.
- Edge cases V1 handles: empty, null, oversize, malformed, Unicode, etc.
- Citation: `<v1-path:line>` for the validation/handling code.

## 2. Outputs (per code path)
For EACH code path (every happy path, every error path, every empty-state path):
- Shape: full structured output (response body, return value, emitted event).
- Field-by-field semantics (e.g., `total = sum(line.amount) + tax`).
- HTTP status / exit code / event type.
- Citation: `<v1-path:line>` for the output construction.

## 3. Side effects (every code path)
- DB writes: table, columns, condition, idempotency key.
- External HTTP: endpoint, method, when, retry, timeout.
- Queue publishes: queue, message shape, ordering required.
- Cache: read keys, write keys + TTL, invalidation rule.
- File I/O: path, mode, atomicity required.
- Logs systems depend on: structured field name, consumer system.
- Metrics emitted: counter, histogram, when.

## 4. Business rules
For each named rule (give it a name even if V1 doesn't):
- Rule-NNN: name, description, source `<path:line>`, test `<path:line>` (or "no direct test"), origin (commit or issue).

## 5. Invariants
- Ordering, idempotency, retry semantics, atomicity, eventual consistency timing, concurrency guarantees.
- Each cited to `<path:line>`.

## 6. Performance characteristics (V1 baseline)
- Latency p50/p95/p99 (source: dashboard / log / measurement).
- DB queries per call (with EXPLAIN if available).
- External HTTP calls per call.
- Memory per call.
- Throughput cap.

## 7. Caller assumptions
For each consumer of V1 (`grep` for the symbol/endpoint/route):
- `<consumer-path:line>` expects V1 to: <observable>. Breaking this is a contract change.
- Lists every observable the consumers depend on.

## 8. Edge cases V1 handles
Catalogued, with citations: empty input, null, concurrent calls with same key, network errors, dependency timeouts, oversized input, malformed input, etc. Each cited to `<path:line>`.

## 9. Known V1 bugs
For each: description, issue link if any, decision (preserve = parity / fix = contract break + ADR-NNN), rationale.
```

**Citation discipline**: every `<path:line>` reference must resolve. The validator script `scripts/validate-migration-artifacts.sh` checks this — but a tool without scripting must check by hand before declaring the contract complete.

## Per-feature audit — 10 hard halts

The audit step runs against an implementation + its artifacts. The audit HALTS (refuses to advance the feature) on any of these 10 conditions:

1. **Contract missing or incomplete** — file at `ai/migration/contracts/<feature>.md` doesn't exist OR any of the 9 sections is empty OR any `<path:line>` citation doesn't resolve.
2. **Parity tests missing or thin** — `<parity-test-root>/<feature>/` doesn't exist OR `tolerance.yaml` doesn't cover every documented output field OR input corpus has fewer than 30 entries (no record-replay setup as alternative) OR no entry exists per documented happy path / error path / business rule / edge case.
3. **Parity tests not green** — latest CI run on the PR's commit is not green for parity tests AGAINST the V1 commit pinned in the ledger; OR tolerance was loosened in the same PR (loosening = separate PR + ADR).
4. **Plan missing** — `ai/migration/plans/<feature>.md` doesn't exist OR doesn't match the actual implementation (V2 module shape under `<v2-root>/<feature>/`; cutover plan present; rollback path documented).
5. **Perf-decisions missing or incomplete** — `ai/migration/perf-decisions/<feature>.md` doesn't exist OR not every candidate classified (applied / deferred / rejected) OR any `applied` candidate has no measurement OR any `applied` candidate is `parity_preserving: no` (those would be contract breaks; ship separately).
6. **V1 modified in the port PR** — diff touches any file under V1 root (the only acceptable exception: cutover-mechanism wiring that is additive and doesn't change V1 behaviour).
7. **Ledger drift** — the PR doesn't update the ledger row OR required fields for the new state are not populated OR V1 commit pinned in ledger ≠ commit used by parity tests ≠ commit V1 is at HEAD of the audited branch.
8. **Rollback runbook missing** — `ai/runbooks/migration-rollback-<feature>.md` doesn't exist OR doesn't name the cutover mechanism + per-stage rollback steps + on-call assignment.
9. **Scope creep** — PR title/description ≠ exactly one ledger feature row OR diff touches files outside V2's `<feature>/` (allowed: ledger update, contract revision, plan revision, perf-decision update, parity test files, cutover wiring [additive only], feature-flag config) OR contains unrelated refactors / "while I'm here" cleanups.
10. **Cutover mechanism not tested in staging** — no evidence (CI run, deploy log, screenshot) that the rollback path was executed in staging within the last 7 days. (Applies to Shadow → Canary advance; not to first-port PR.)

**Output of any halt**: a structured remediation list — specific finding + specific action — written to the audit file. NO advance until each halt is cleared.

## Frontend audit axes (when feature is a UI page / component / route)

The 6 generic comparison axes (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) are necessary but NOT sufficient for frontend ports. Add these axes for any feature whose V1/V2 entry is a page/component/route/screen:

- **Form fields** — enumerate every input on the page: name, type, validation rules (declared + inline), default value, placeholder, required vs optional, disabled-when, hidden-when. Every form field is a contract surface; missing one = silent break.
- **UI affordances** — enumerate every button, link, dropdown, modal trigger, file-upload control, toggle switch, copy-to-clipboard button, "view detail" link. Each affordance has a permission gate, an event handler, and an observable effect. **F039's missed "add new mapping" button is exactly this axis.**
- **Templated query params** — enumerate every URL query param the page reads (router.query, useSearchParams, etc.). V1's list endpoint may filter by 6 params; V2 may send 4. The list endpoint's contract is "the union of every param V1 sends" — verify by reading the V1 list call construction line by line.
- **Event handlers** — every `@click`, `@submit`, `@change`, `@input`, `onclick`, `onsubmit` — what it calls, with what args, what the side effect is.
- **Per-button permission gates** — V1 may hide an action via `v-if="hasPermission(...)"` / `{user.can(...) && ...}` — V2 must render the same gate. Enumerate; per-button audit.
- **Accessibility** — keyboard navigation order, ARIA labels on icon-only buttons, focus management on modal open/close, screen-reader-only text. axe-core baseline + diff is the parity test.
- **DOM-equivalent** (use the `dom-equivalent` tolerance class from `parity-testing.md`) — semantically equal markup; pixel-perfect not required but structural parity is.
- **Reactive lifecycle** — V1's `onMounted` vs V2's `onActivated` (when the framework supports keep-alive); refetch-on-locale-change; refetch-on-tenant-switch. Stale-on-tab-return is a tenant leak vector for multi-tenant apps.

## Frontend anti-pattern catalogue (V1 → V2 hot list)

These recur in every frontend V1→V2 port. Add to project-specific anchor's framework column when relevant.

| V1 anti-pattern | Why it's bad | V2 fix |
|---|---|---|
| `array.find()` / `array.includes()` inside a `v-for` / map / loop | O(N²) on every render | Build `Map` / `Set` once via computed; O(1) lookup |
| Sequential `await` in `mounted` / `onMounted` for independent fetches | Blocks first paint by sum of latencies | `Promise.all` for independent calls; lazy-load non-critical |
| `localStorage.getItem('selectedLanguage')` / `localStorage.userInformation` outside `secureStorage`/`tokenProvider` | Tenant leak: stale value survives logout | Read from live store (Pinia/Redux/etc.); auth `logout()` clears the store |
| `onMounted` data fetch on cached page (KeepAlive / `<keep-alive>`) | Stale on tab return / tenant switch | `onActivated` (Vue) / framework's reactivate hook |
| `v-html` / `dangerouslySetInnerHTML` without sanitize | XSS surface | Route through DOMPurify wrapper; document the sanitize boundary |
| Search input wired directly to API without debounce | API spam; 1 request per keypress | `useDebounceFn(fetch, 300)` |
| DDL endpoints (`countries/minimal`, `users/minimal`) refetched on every dialog open | N×call per session | Module-level cache with TTL; invalidate on logout |
| Missing route lazy-load (eager `import` of route component) | Huge initial bundle | `() => import('./Page.vue')` per route leaf |
| Per-page inline business logic | Untestable; duplicated across pages | Extract to composable / hook |
| Manual `Authorization: Bearer ${token}` headers in service calls | Bypasses interceptor + refresh queue; double-source-of-truth on token | Interceptor on the HTTP client only; never per-call |
| Untrottled `setInterval` / `setTimeout` in `mounted` without cleanup | Memory leak; multiple instances on KeepAlive resume | `onUnmounted` / `useEffect` return; clean up the timer |
| Per-component `axios.create()` outside the canonical client | Double interceptors, unrelated refresh logic | Single `apiClient` + `publicClient`; never `axios.create` per feature |
| Routes redirect via path strings (`router.push('/dashboard')`) | Refactor-fragile | Named routes (`router.push({ name: 'dashboard' })`) |
| Translation-fields sent as `{ en: ..., ar: ... }` flat objects | Backend may want `name_translations: { ... }` envelope | Match V1's submitted shape exactly; document in contract |

## Tool-agnostic procedure (for tools without skill dispatch)

The skills `extract-v1-contract`, `parity-test-generate`, `perf-uplift-survey` describe canonical procedures. AI tools that support skills dispatch them directly. AI tools that don't (Aider / Codex / Gemini / Cline / Windsurf reading rules only) MUST follow the inlined procedure below to produce the same artifacts:

### Procedure: extract V1 contract

1. Pin V1's commit hash (`git -C <v1-root> rev-parse HEAD`); record in ledger row's `v1_commit_pinned`.
2. Identify ONE entry point. Trace OUTWARD until I/O boundaries.
3. Read every file in the call graph end-to-end (no skim). Note: every conditional, every error path, every side effect, every type, every dependency call, every time/random/external dependence.
4. Read every test that touches the feature.
5. Read git log for the feature's files (`git log --follow -p <path>`); flag recent bug fixes + hotfixes.
6. Search bug tracker / issue list for the feature name; capture open V1 bugs + fixed-but-relevant.
7. Inspect production telemetry if available: latency p50/p95/p99, error rate, throughput, DB cost. Sample 100 production logs (anonymised).
8. Inspect adjacent code that consumes V1 (`git grep` exported symbols / endpoints); capture caller assumptions per `<file>:<line>`.
9. Synthesise into the 9-section contract. Every claim has a `<path:line>` citation. Every section is populated.
10. Have a second reviewer read V1 alongside the contract; they look for what the contract missed.

### Procedure: generate parity tests

1. Confirm contract exists and is complete; refuse to proceed otherwise.
2. Pick recipes per `parity-testing.md` recipe-mix table (golden master always; property-based for invariants; record-replay for high-traffic; shadow for read-heavy production; dual-write for write paths; component snapshot / composable golden / E2E parity / a11y / visual regression for frontend).
3. Build input corpus at `<parity-test-root>/<feature>/inputs/`: ≥1 per happy path, ≥1 per error path, ≥1 per business rule (boundary), ≥1 per edge case, 50–100 anonymised production samples if available. **Aim for ≥30 inputs**.
4. Capture V1 outputs into `__golden__/` (deterministic environment: seeded test DB, fixed time/random, stubbed external HTTP).
5. Build `tolerance.yaml`: every contract output field gets one of `exact` / `structural` / `numeric_tolerance` / `order_insensitive` / `ignore`. Default for unsure fields: `exact`.
6. Author golden-master test (load input → run V2 → compare to golden per tolerance).
7. Author property-based tests for each invariant in the contract.
8. (If applicable) record-replay corpus + replay test.
9. (If applicable) shadow comparator + dual-write audit.
10. CI integration: golden + property on every push; replay nightly or `[parity]` label.

### Procedure: perf-uplift survey

For each of the 10 candidate areas (N+1, missing index, column projection, caching, sequential await, in-app filter, batched insert, raw SQL vs ORM, sync external HTTP, payload shape):
1. Inspect V1's behaviour for the candidate (cite `<v1-path:line>`).
2. Document V1's cost (queries × latency; bytes; etc.).
3. Decide V2's transformation (parity-preserving or contract-breaking).
4. Classify: applied / deferred / rejected. With rationale.
5. For `applied`: implement; measure before/after; verify parity tests still green.
6. For `deferred`: log blocker (infra not ready, scope, ADR pending).
7. For `rejected`: log reason + ADR link if contract-breaking.
8. Record in `ai/migration/perf-decisions/<feature>.md`.

## Must

- **Read V1 before writing V2.** Produce `ai/migration/contracts/<feature>.md` with all 9 sections per the procedure above. The contract is the spec V2 must satisfy.
- **Generate parity tests before V2 code.** Follow the parity-test procedure above. Tests run V1 + V2 against identical inputs and assert equivalence per the tolerance taxonomy (exact / structural / numeric tolerance / order-insensitive / timestamp-insensitive / dom-equivalent). Red baseline before V2 is fine — green is required before cutover. Corpus has ≥30 inputs OR a record-replay setup; tolerance.yaml exists; every contract output field has a tolerance entry.
- **One feature per port PR.** Atomic unit = one feature in the migration ledger. Multi-feature PRs hide regressions and make rollback ambiguous.
- **Update the ledger on every state transition.** `V1-only → In-progress → V2-shadow → V2-canary → V2-only → V1-deleted`. The ledger is the source of truth — code grep is not.
- **Cutover is gated.** Move from V2-canary → V2-only only when: (1) parity tests green, (2) shadow / canary metrics show no regression on error rate / latency / business KPIs for the agreed observation window, (3) the relevant ADR (if any) is merged, (4) rollback path tested.
- **Delete V1 only when last reference is gone.** Use `git grep` + dead-code analyser + telemetry "no traffic in N days" before deletion. The ledger transition `V2-only → V1-deleted` requires evidence attached.
- **Default to V1-parity, ADR is opt-in.** When audit finds V2 has something V1 doesn't (extra button, renamed route, flipped default, new field), the **default action is to remove V2's deviation** to match V1. An ADR is required ONLY when the user explicitly chooses to keep V2's behavior (or the V1 behavior is a security / privacy / legal regression). The architect/port agent MUST NOT silently draft an ADR to legitimize V2 deviations — that pattern (observed in tenant-portal-v2 Phase 7: ~6 ADRs drafted to preserve V2 over V1) inflates documentation while leaving the user-visible parity gap unfixed. Surface the divergence to the user, offer "match V1 / keep V2 + ADR / deprecate-V1-feature + ADR", wait for explicit choice.
- **When an ADR IS warranted**, document the intentional behaviour break in `ai/decisions/<NNN>-<feature>-v2-break.md` with: V1 behaviour, V2 behaviour, why the break is necessary (user decision rationale), who's affected, migration path for callers, deprecation timeline.
- **Capture migration-time perf wins explicitly.** Follow the perf-uplift procedure above during port. For each candidate (N+1 → batch query, missing index, unbounded SELECT *, sequential await, no caching, in-app filter, etc.), decide: applied / deferred / rejected — with a reason and (for applied) a measured before/after. Decisions live in `ai/migration/perf-decisions/<feature>.md`. A perf change MUST NOT silently break parity — it's either parity-preserving (most cases — same observable, faster) or it's a documented break (above bullet).
- **Use V2's primitives, not V1's.** If V2's architecture says "service-layer + repository", DO NOT carry over V1's "fat controller". The port is the moment to align with V2 — that's the entire point.
- **Keep V1 untouched during port.** No "while I'm here" fixes in V1 code. V1 is the oracle for parity testing — if you change V1 you've changed the oracle.
- **Every deferred gap must have an explicit destination.** A gap that cannot be closed in the current run (structural blocker, cross-repo dependency, user-decided complex restructure) MUST be assigned exactly one of: (a) a target phase number in the ledger row's `notes` field (e.g., `deferred to phase 10`), (b) an ADR ID (`intentional_break: ADR-NNN`), or (c) `status: parked` with a 1-line rationale via `/migration-park`. A gap noted as "deferred" with no destination is a floating obligation — the ledger row stays `halted`, the phase gate REFUSES, and the port is incomplete. **No deferred gap without a destination.** This is the lesson from F055 (Phase 9, tenant-portal-v2): gap 14 was noted as "deferred; requires major restructure" with no phase target, no ADR, no park decision — the row held `status: halted`, `gaps_in=14`, `gaps_closed=13`, and REFUSED the phase gate until the user decided.

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
- **Leave a gap deferred with no destination.** `status: halted` + `gaps_in > gaps_closed` + no target phase / ADR / park in notes = a floating obligation. The phase gate will REFUSE. Assign a destination immediately: the next phase, an ADR, or `/migration-park`.
- **Advance a `halted` row to `done` without closing all gaps.** If `gaps_in != gaps_closed`, the row is not done — the RE-DETECT step (in `find-and-fix.md § 3.5`) enforces this, and the gate's `check_gap_count_parity` enforces it again. Both must be equal before a row can exit `halted`.

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

- **The Transposition Trap** — line-by-line copy of V1 into V2. Carries V1's bugs + V1's hidden invariants. The port must be re-derived from the contract AND must follow V2's NEW structure (shared components, conventions, file layout). Concrete frontend fingerprints — `validate-migration-artifacts.sh § check_v2_structure` HALTs on any of these in V2 files:
    - Raw framework components in pages where wrappers exist — `<Dialog>` / `<Paginator>` / `<Dropdown>` / `<Calendar>` (PrimeVue equivalents). V2 ships wrappers like `<BaseModal>`, `<CrudPaginator>`, `<BaseDropdown>`, `<DatePicker>`. Use those.
    - `<FormField :label="$t('...')">` — `<FormField>` calls `$t()` internally; pass bare key string `<FormField label="Module.key">`. Double-translation produces missing-key warnings + bare keys rendered to users.
    - `<div class="col-md-6"><FormField>` — wrapper col around `FormField`. `FormField` has its own `col-class` prop; no wrapper needed. Nested cols inside `.row` break Bootstrap grid silently → labels misalign + child components like `<BaseDropdown>` collapse to weird widths and look like text inputs.
    - Hand-rolled phone field (`phone-row` div with disabled code prefix + number input) — V2 has `<PhoneInput>` with `code-readonly` mode. Use it.
    - `localStorage.{get,set}Item(*, *token*)` — tenant leak; use `secureStorage` + `tokenProvider`.
    - `axios.create(...)` outside the project's canonical client file — there is exactly ONE authenticated client per app.
    - `console.log` / `console.debug` in production code — ESLint rule, but check anyway.
    - Manual `Authorization: Bearer ${token}` headers in service calls — bypasses the interceptor + refresh queue; double-source-of-truth on token.
    - Raw `<form @submit>` in dialogs/pages — use `<BaseForm @submit="...">` which provides `<fieldset disabled>` + `.row` wrapper.
    - Inline `style="..."` attributes — use scoped SCSS + design tokens.
    - V1's grid system carried over verbatim — V1 used Bootstrap col wrappers; V2 uses component-level `col-class` props. Re-derive layout from V2's gold-standard equivalent feature, not from V1's template.
    - `onMounted` for data fetch on a page V2's KeepAlive caches — V2 uses `onActivated` so data refreshes on tab return + tenant switch.
    - Hardcoded translation language keys — `ref<Translations>({ en: '', ar: '' })`, `{ en: '', ar: '' }` literals, or `locale.value === 'en' ? 'en' : 'ar'` ternary. V2 supports dynamic languages via `useLanguages().buildEmptyTranslations()` and reads available codes from `appConfig` store. Hardcoding 2 languages (a) breaks tenants with Spanish/French enabled, (b) sends stale dead keys when a language is disabled. **The correct pattern**: `const { buildEmptyTranslations } = useLanguages(); const translations = ref<Translations>(buildEmptyTranslations())`. For the active-language ref: `const activeLanguage = ref(locale.value)` — no ternary. (tenant-portal-v2 Phase 7 lesson: 17 V2 files copied V1's `{ en, ar }` literal instead of using V2's helper.)

  **Phase 3 of `/port-feature` (Retrieve) MUST list the gold-standard V2 files the executor reads BEFORE writing.** The plan's "V2 patterns I will follow" section names them explicitly. Skipping Phase 3 is the trigger — the executor opens V1, reads it, opens V2's destination directory, and writes by analogy to V1 instead of by analogy to V2's gold standard.
- **The Bundled Cutover** — porting + redesigning + adding features + perf-tuning in one PR. Reviewer cannot localise regressions; rollback is all-or-nothing.
- **The Stale Oracle** — V1 evolves during port; parity tests pass against a moving target. Pin V1's commit; freeze it for the duration of the port.
- **The Silent Break** — V2 changes an output shape, returns a different error type, drops a side effect. Ships unnoticed; long-tail customer issues surface for months.
- **The Test-by-Test Port** — porting V1's unit tests verbatim. Misses production behaviours that V1 has but V1's tests don't cover. Use record-replay against real traffic samples (anonymised).
- **The Eternal Shadow** — V2 lives in shadow indefinitely "until we're sure". The longer V2 stays in shadow, the more divergent it becomes from V1 (which keeps shipping). Set a cutover deadline; if missed, re-baseline parity.
- **The Buried Perf "Improvement"** — an N+1 fix that quietly changes ordering / nullability / ID stability. The "improvement" is a contract break; ships under the port PR; surfaces as a bug 6 weeks later.
- **The V1 Deletion Sprint** — deleting V1 modules en masse "to clean up." A single `import` left in a stale cron job means a silent prod failure when the cron next fires. Delete only when last reference is gone + telemetry confirms zero traffic.
- **The Trusted Summary** — delegating V1↔V2 comparison to a search/exploration agent that returns "looks identical" in confident summary language; the executor echoes that into the audit without verifying claim against source. The audit is a checklist, not a vibe-check; every "identical" claim has a `<path:line>` citation that resolves OR the audit halts. (F039 in tenant-portal-v2: a missing add-button + divergent query-param surface both passed audit because the summary said identical. Lesson: trust agents to *find* sources, not to *verify* equivalence; verification reads source line by line.)
- **The Hand-waved Query Param** — audit declares "GET /endpoint?foo=&bar=&..." with `&...` as the trailing surface, hiding 4 unenumerated params. The contract's Inputs section enumerates EVERY param V1 sends. No `&...`, no "etc.", no "and so on" — list them all or halt the contract.
- **The Optimistic Form Field Match** — audit declares V1↔V2 form fields "identical" without enumerating them. Frontend-specific anti-pattern: a missing field, a wrong type, a missing validator passes audit. Contract's Inputs section lists every field on V1's page, V2 must render the union.
- **The Permission-gate Drop** — V1 hides an action via `v-if="hasPermission(...)"` / `{user.can(...) && ...}`; V2's port renders the action without the gate. Per-button audit enumerates every gate; missing gate is a security regression.

## References

These references are **convenience pointers for AI tools that support them**. The rule itself is self-sufficient — every procedure is inlined above. If your tool doesn't expose these as commands/agents/skills, follow the inlined procedures.

### For tools with command + agent + skill dispatch (Claude Code, OpenCode, partial: Cursor, Copilot)

- `.claude/skills/extract-v1-contract.md` — V1-contract-extraction procedure (inlined above).
- `.claude/skills/parity-test-generate.md` — parity-test-generation procedure (inlined above).
- `.claude/skills/perf-uplift-survey.md` — perf-uplift-survey procedure (inlined above).
- `.claude/agents/migration-architect.md` — strategic per-feature planner.
- `.claude/agents/parity-auditor.md` — pre-cutover audit (Stage A halts inlined as the 10-halt checklist above).
- `.claude/commands/find-and-fix.md` — DEFAULT per-feature loop (detect → decide → fix → verify → record).
- `.claude/commands/port-feature.md` — heavy-tier orchestrator (`--heavy` flag for full ceremony).
- `.claude/commands/migration-phase.md` — phase orchestrator (chains via find-and-fix per row by default).
- `.claude/commands/migration-gate.md` — phase exit verifier (validates the artifact set above).

### Patterns (read by all tools as ai/ knowledge)

- `ai/patterns/feature-port.md` — per-feature lifecycle (six phases per ledger row).
- `ai/patterns/parity-testing.md` — test technique catalogue + tolerance taxonomy.
- `ai/patterns/migration-ledger.md` — state-machine + record format.

### Cross-pack references

- `code-quality/agents/legacy-modernizer.md` — strategic-level migration (sets the feature inventory this rule operates inside).
- `backend/rules/concurrency-discipline.md` — the parallel-I/O bullet (perf-uplift candidate #5) links here.
- `database/skills/migration-rehearsal.md` — DB-only migration rehearsal (used during V2 query plan + index changes).
- `frontend/` pack (if loaded) — component / page / a11y testing recipes the parity-test step uses for frontend ports.
- `testing/` pack (if loaded) — golden-master, property-based, record-replay recipes — the parity-test step uses these.

### Validator script (universal, runs from any tool)

- `scripts/validate-migration-artifacts.sh` — validates contract sections, citation resolution, corpus size, tolerance coverage, plan presence, perf-decisions completeness, runbook presence. Runnable from CI / pre-commit / any tool's hook system. Tool-agnostic.

### For rule-only tools (Aider, Codex, Gemini, partial: Cline, Windsurf)

This rule **is** the surface. The 9 contract sections, the 10 hard halts, the frontend axes, the anti-pattern catalogue, and the three procedures (extract / parity-test / perf-uplift) are all inlined above. No skill / agent / command dispatch is required — follow the rule as a checklist.
