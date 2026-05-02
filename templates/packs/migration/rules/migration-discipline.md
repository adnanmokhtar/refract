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

This rule governs every per-feature port. It exists because the most common migration failure is **subtle behavioural drift** — V2 *almost* matches V1, ships, and a long-tail of customer issues surface over months. The second most common is **scope creep** — the port becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed. The third most common is **trusted summary** — an executor delegates V1↔V2 comparison to a search/exploration agent, the agent reports "looks identical" in confident summary language, and the executor echoes that into the audit without verifying the claim against source. The canonical real-world incident: a missing UI affordance + a divergent query-param surface both passed audit because the summary said "identical".

**This rule is the universal contract** — it must be enforceable by any AI tool. Tools with full capability (commands + agents + skills + hooks) compose the discipline by dispatching `/port-feature` → `parity-auditor` → `extract-v1-contract` etc. Tools with rules only (Aider, Codex, Gemini) enforce the discipline by reading and following this file directly. Therefore: the procedural detail is inlined here, not just referenced. Do not delete the inlined procedures in favour of references; rule-only tool users have no other surface.

## Required artifacts per feature — tiered floor

Every feature port produces an artifact set scaled to its actual risk. The discipline is **tiered**, not one-size-fits-all: a 1-line bulk-delete URL fix and a 25-file payment-flow rewrite have different audit needs. Tier is set on the ledger row at audit time and propagates through the port.

> **Why this is tiered (added 2026-04-30 from a Phase 7 incident lesson)**: prior single-floor discipline produced ~95% docs / ~5% code on small features (all 8 artifacts mandatory regardless of feature size). 1-line fixes generated 5-section contracts + 30-fixture parity tests + 12-candidate perf surveys + 7-stage runbooks. The tiered model preserves the F039 anti-Trusted-Summary protections on heavy features while letting trivial features ship in proportion.

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

A real-world Phase 7 incident (Apr 2026) burned ~95% of port-time tokens on documentation that did not enable any code change. These rules prevent recurrence — they are merge gates, not suggestions.

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
| Mapping (added 2026-05-01) | `ai/migration/mapping/<feature>.md` | V1-X→V2-Y inventory. Names every shared wrapper / util / hook / type / pattern V2 will reuse — entries come from the project's `_extracted-idioms.md`. Authored BEFORE code. | 2-column table at minimum; heavy tier adds "shared entity used" + "behaviour delta" columns. Validator: `check_v2_mapping_doc`. |
| API samples (added 2026-05-01, conditional — port touches the project's service / data-access layer) | `ai/migration/api-samples/<feature>/<endpoint>.json` | Captured real API responses. V2 type derived from these, not guessed from V1 caller code. | At least 1 sample per endpoint the service calls. Validator: `check_api_response_sample`. |
| Ledger row | `ai/migration/ledger.md` § `<feature>` | Source-of-truth state machine row. | Per-state required fields per `migration-ledger.md`. |

### Standard-tier artifact spec (light floor)

- **Contract**: 3 sections only — Inputs (form fields + query params), Outputs (per code path), Known V1 bugs. Cite `<path:line>` per claim. Skip side effects / business rules / invariants / perf baseline / caller assumptions / edge cases as separate sections — fold the load-bearing items into the relevant section if surfaced by audit.
- **Mapping doc**: same as trivial — 2-column V1→V2 table at `ai/migration/mapping/<feature>.md`.
- **API samples**: same as trivial — captured responses at `ai/migration/api-samples/<feature>/` if port touches `services/`.
- **Plan**: 1 page — V2 files to touch, gap closures (1 line each), perf candidates classified inline (no separate doc), cutover = "per-tenant DNS, no special handling".
- **Parity tests**: ≥10 fixtures (not 30), tolerance.yaml covers contract output fields.
- **Audit**: standard structure, no enumeration of every form field/button on a page that has no P0/P1 gaps.
- **Skip** (compared to heavy): no separate perf-decisions doc, no separate rollback runbook, no separate plan-vs-implementation reconciliation. Audit + ledger row carry the risk register.

### Trivial-tier artifact spec (audit + code only)

- **Audit**: classification + 1-paragraph "what changed" + 1-paragraph "why no contract" + **per-axis enumeration table for any axis with ≥1 gap** (frontend axes per `parity-auditor.md` §  frontend axes; API axes per § backend axes). Axes with zero gaps may be summarised in 1 line. A trivial audit that hides ≥1 gap inside summary prose without the per-row table is rejected.
- **Mapping doc** (`ai/migration/mapping/<feature>.md`, **every tier** — added 2026-05-01): a 2-column V1-X→V2-Y table. Names every shared wrapper, util, hook, type, pattern the V2 port will reuse — entries come from the project's `_extracted-idioms.md`. Authored BEFORE code. The `check_v2_mapping_doc` validator halts the gate if the file is missing or has zero mapping rows.
- **API samples** (`ai/migration/api-samples/<feature>/`, **only when the port touches the project's service / data-access layer** — added 2026-05-01): at least one captured JSON response per endpoint the service calls. The V2 type's field names + nullability are derived from this sample. The `check_api_response_sample` validator halts the gate if the dir is missing or empty.
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

## Per-feature audit — 11 hard halts

The audit step runs against an implementation + its artifacts. The audit HALTS (refuses to advance the feature) on any of these 11 conditions:

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
11. **Dead V1 code in port queue** — the V1 source of this feature has zero callers across all 6 reachability axes (see § "What counts as dead V1 code" below). Halt the port; do NOT migrate dead code into V2. Mark the ledger row `status: deprecated` with `deprecation_reason: dead-v1-no-callers` (no ADR required for this case — dead code is a structural fact, not a user-facing decision). If the user disputes the dead-code finding (e.g., "it's called from a cron job our scanner missed"), they pass `--include-dead` to override AND attach a 1-line `caller_evidence: <path:line>` to the ledger row proving the missed caller.

**Output of any halt**: a structured remediation list — specific finding + specific action — written to the audit file. NO advance until each halt is cleared.

## What counts as dead V1 code (the 6-axis check)

A V1 feature is "dead" — and therefore must NOT be ported — if **all six** of these reachability axes return zero callers. If even one axis shows a caller, the feature is alive and must be ported.

1. **App source callers** — `git grep -F` for the feature's exported symbols / route paths / endpoint names across V1's app source (excluding the feature's own files + tests). Zero matches → axis 1 dead.
2. **Test references** — same grep across V1's test directories. Zero matches → axis 2 dead. (Note: a test that ONLY exercises the feature itself — the feature's own unit test — does NOT count as a caller; the feature would still be dead. Look for downstream tests that exercise other features which transitively call this one.)
3. **Cron / scheduler config** — grep across V1's cron config, scheduler manifest, queue worker registration files. Zero matches → axis 3 dead.
4. **Route / API registration** — for HTTP endpoints: check V1's router config / route table. For RPC endpoints: check the RPC registration. For event handlers: check the event-bus subscription table. Zero matches → axis 4 dead.
5. **Infra / deploy config** — grep across V1's Dockerfile, k8s manifests, terraform, CI workflows, deploy scripts for the feature's binary names / endpoint URLs / cron commands. Zero matches → axis 5 dead.
6. **Production telemetry** — if observability is wired (APM dashboard, log volume, request count): zero invocations / zero log lines for ≥ 90 days → axis 6 dead. If observability is NOT wired, this axis is **N/A** (skip — but axes 1–5 must all show dead).

**All 6 axes dead** → feature is dead → halt #11 fires. Mark `status: deprecated` with `deprecation_reason: dead-v1-no-callers` and `dead_evidence: 6-axis check passed at v1_commit_pinned: <sha>`.

**At least one axis alive** → feature is not dead → port it normally.

**Edge cases**:
- **Public API endpoints** with no internal caller but documented in API docs / called by external clients — axis 4 (route registration) shows them as alive. NOT dead.
- **Library exports** consumed by external repos — axis 1 within V1 is dead, but external consumer is unprovable from V1 alone. The user must explicitly mark such features `--external-consumer` at scan time; otherwise default to dead.
- **Recently-added features** with no callers yet because they're not wired up — these are "in development", not dead. The user marks them `--in-development` at scan time; without that flag, they look identical to dead code.
- **Feature-flag-gated code** where the flag is OFF in production — STILL DEAD if the flag has been OFF for ≥ 90 days. If the flag is on for some tenants only, axis 6 (telemetry) shows alive for those tenants. Port it.

**The user's override**: `--include-dead` flag at scan time forces a row to be queued for port despite the dead-code verdict. Required field on the override: `caller_evidence: <path:line>` proving the missed caller. The override is logged in `ai/migration/_history.md` for audit trail.

## Per-stack extensions (frontend / backend specifics)

The 6 generic comparison axes (Inputs / Outputs / Error contract / Auth + permissions / Side effects / Performance) are necessary but NOT sufficient for stack-specific ports. Stack-specific audit axes, anti-pattern catalogues, and Transposition-Trap fingerprints live in the per-stack packs:

- **Frontend ports** — see `frontend/rules/migration-frontend.md`. Adds: form-field axis, UI-affordance axis, templated-query-param axis, event-handler axis, per-button permission-gate axis, accessibility axis, DOM-equivalent axis, reactive-lifecycle axis. Plus the frontend anti-pattern catalogue (raw library components in pages, mount-hook on cached routes, hardcoded language keys, etc.) and Transposition-Trap fingerprints the validator's `check_v2_structure` enforces under `PROJECT_KIND in frontend-*`.
- **Backend / API ports** — see `backend/rules/migration-backend.md` (if your backend pack defines one). Adds: DTO-shape axis, query-param surface axis, response-envelope axis, validator-stack axis, tenant-isolation axis, transaction-boundary axis. Plus the backend anti-pattern catalogue and fingerprints the validator enforces under `PROJECT_KIND in backend-*`.
- **If your project has no per-stack pack file**, extract one from this universal rule's history (the catalogues lived here pre-2026-05-01) or author one against your stack's primitives — `_extracted-idioms.md` is the source of truth.

The universal rule below stays stack-agnostic. All concrete component / hook / library names belong in the per-stack packs.

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

- **Inventory V2 before reading V1** (added 2026-05-01). Before extracting the V1 contract, scan V2's shared inventory — every wrapper, every shared util / hook / composable, every design token, every base class — at the paths declared in the project's `_extracted-codebase.md § Gold standards` and `_extracted-idioms.md`. Produce `ai/migration/mapping/<feature>.md`: a 2-column "V1 X → V2 Y" table naming the V2 equivalent for each V1 surface. Skipping this is the #1 cause of the Transposition Trap. Required at every tier; `check_v2_mapping_doc` halts the gate without it.
- **Reuse-Before-Create** (added 2026-05-01). Before authoring any component, hook / composable, util, type, style, or markup pattern, search the project's shared inventory. If it exists → reuse. If it partially exists → extend the shared one (don't fork). Authoring a duplicate is a migration failure, not a stylistic choice. The specific shared entries to check are project-specific (see `_extracted-idioms.md`); the validator's `check_v2_structure` is stack-conditional and reads its fingerprint list from the project's PROJECT_KIND anchor. PRs that introduce a new V1-pattern fingerprint must add a corresponding detector to the script.
- **Read V1 before writing V2.** Produce `ai/migration/contracts/<feature>.md` with all 9 sections per the procedure above. The contract is the spec V2 must satisfy.
- **Capture real API responses to derive types from** (added 2026-05-01). For any port that touches the project's service / data-access layer, store at least one captured response per endpoint under `ai/migration/api-samples/<feature>/<endpoint>.json`. The V2 type's field names + nullability + nested shape are derived from this sample, not guessed from V1 caller code. The Guessed Type anti-pattern (a typed DTO that doesn't match the actual response field names) ships empty UIs that look like "API returned nothing" rather than "type mismatch". The validator's `check_api_response_sample` halts the gate when the directory is missing or empty.
- **Generate parity tests before V2 code.** Follow the parity-test procedure above. Tests run V1 + V2 against identical inputs and assert equivalence per the tolerance taxonomy (exact / structural / numeric tolerance / order-insensitive / timestamp-insensitive / dom-equivalent). Red baseline before V2 is fine — green is required before cutover. Corpus has ≥30 inputs OR a record-replay setup; tolerance.yaml exists; every contract output field has a tolerance entry.
- **One feature per port PR.** Atomic unit = one feature in the migration ledger. Multi-feature PRs hide regressions and make rollback ambiguous.
- **Update the ledger on every state transition.** `V1-only → In-progress → V2-shadow → V2-canary → V2-only → V1-deleted`. The ledger is the source of truth — code grep is not.
- **Cutover is gated.** Move from V2-canary → V2-only only when: (1) parity tests green, (2) shadow / canary metrics show no regression on error rate / latency / business KPIs for the agreed observation window, (3) the relevant ADR (if any) is merged, (4) rollback path tested.
- **Delete V1 only when last reference is gone.** Use `git grep` + dead-code analyser + telemetry "no traffic in N days" before deletion. The ledger transition `V2-only → V1-deleted` requires evidence attached.
- **Structure → V2 wins; observable behaviour → V1 wins** (added 2026-05-01). This resolves the apparent conflict between "Use V2's primitives" and "Default to V1-parity". They apply on different axes: **structure** (file layout, component shape, naming, layering, which shared wrapper is used, where state lives, layer boundaries) follows V2 unconditionally — V1 conflicts are forfeit. **Observable behaviour** (inputs accepted, outputs returned, events fired, side effects performed, error contracts, response shape consumed) follows V1 unless the user explicitly opts to break it. The Transposition Trap recurs when porters confuse the two and copy V1's structure to "preserve behaviour"; the Silent Break recurs when porters change V2's behaviour to "match V2's structure". Neither is correct. Concrete shapes of the rule: a V1-only routing pattern → use V2's routing primitive (structure); a V1 query param V2 omits → add it to V2 (behaviour); a V1 nullable return V2 throws on → V2 returns null (behaviour) but routes through V2's service/repository layout (structure).
- **Default to V1-parity, ADR is opt-in (BEHAVIOURAL axis).** When audit finds V2's *behaviour* deviates (extra button, missing field, flipped default), the **default action is to remove V2's deviation** to match V1. An ADR is required ONLY when the user explicitly chooses to keep V2's behaviour (or V1 is a security / privacy / legal regression). The architect/port agent MUST NOT silently draft an ADR to legitimize V2 deviations — that pattern (observed in a real-world Phase 7 incident: ~6 ADRs drafted to preserve V2 over V1) inflates documentation while leaving the user-visible parity gap unfixed. Surface the divergence to the user, offer "match V1 / keep V2 + ADR / deprecate-V1-feature + ADR", wait for explicit choice. **This rule applies to BEHAVIOUR ONLY, not structure** — see the rule above.
- **No frontend compensation for backend gaps.** If V2's API is missing a field, returning a wrong shape, or behaving differently than V1's API, the fix is a backend ticket — not a UI workaround. Workarounds (mapping `c.name` to `c.label` in the component, hardcoding a missing field, sending a fake parameter) drift the contract silently and re-surface as bugs in every other consumer. File the API ticket; if the port is blocked waiting, mark the feature `status: halted` with an explicit dependency, do not ship a UI patch.
- **No silent catches** (added 2026-05-01). A `catch { /* fail silent */ }` or empty `catch {}` swallow makes failures indistinguishable from empty success states — empty lists, missing widgets, no error indicator. Every catch in port code must either (a) call the project's error handler (named in `_extracted-idioms.md`) or (b) include a one-line comment explaining why this specific failure mode is recoverable AND log at debug level. The validator's `check_v2_structure` flags both patterns. The user reports "looks empty" rather than "is erroring", and the bug hides for weeks.
- **When an ADR IS warranted**, document the intentional behaviour break in `ai/decisions/<NNN>-<feature>-v2-break.md` with: V1 behaviour, V2 behaviour, why the break is necessary (user decision rationale), who's affected, migration path for callers, deprecation timeline.
- **Capture migration-time perf wins explicitly.** Follow the perf-uplift procedure above during port. For each candidate (N+1 → batch query, missing index, unbounded SELECT *, sequential await, no caching, in-app filter, etc.), decide: applied / deferred / rejected — with a reason and (for applied) a measured before/after. Decisions live in `ai/migration/perf-decisions/<feature>.md`. A perf change MUST NOT silently break parity — it's either parity-preserving (most cases — same observable, faster) or it's a documented break (above bullet).
- **Use V2's primitives, not V1's.** If V2's architecture says "service-layer + repository", DO NOT carry over V1's "fat controller". The port is the moment to align with V2 — that's the entire point.
- **Keep V1 untouched during port.** No "while I'm here" fixes in V1 code. V1 is the oracle for parity testing — if you change V1 you've changed the oracle.
- **Every deferred gap must have an explicit destination.** A gap that cannot be closed in the current run (structural blocker, cross-repo dependency, user-decided complex restructure) MUST be assigned exactly one of: (a) a target phase number in the ledger row's `notes` field (e.g., `deferred to phase 10`), (b) an ADR ID (`intentional_break: ADR-NNN`), or (c) `status: parked` with a 1-line rationale via `/migration-park`. A gap noted as "deferred" with no destination is a floating obligation — the ledger row stays `halted`, the phase gate REFUSES, and the port is incomplete. **No deferred gap without a destination.** This was the lesson from a Phase 9 incident: a gap was noted as "deferred; requires major restructure" with no phase target, no ADR, no park decision — the row held `status: halted` with unequal `gaps_in`/`gaps_closed`, and REFUSED the phase gate until the user decided.

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
- **Port dead V1 code.** If the V1 source has zero callers across all 6 reachability axes (app source, tests, cron/scheduler, route registration, infra config, production telemetry — see § "What counts as dead V1 code"), it is dead. Porting it migrates rot into V2, inflates V2's surface area with code that has no consumer, and perpetuates V1's accumulated cruft into the new structure. The port queue is for **live** features only. Dead V1 code is marked `status: deprecated` with `deprecation_reason: dead-v1-no-callers` and excluded from V2 entirely (it gets deleted from V1 at the V1-retirement phase, NOT ported then deleted). The user can override via `--include-dead` + `caller_evidence: <path:line>` if the dead-code detector missed a caller, but the override is explicit + logged.

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

- [ ] `ai/migration/mapping/<feature>.md` exists with V1-X→V2-Y rows naming every shared wrapper / util / hook / type used.
- [ ] `ai/migration/api-samples/<feature>/` contains real captured responses per endpoint when port touches the project's service / data-access layer.
- [ ] V2 type field names match the captured sample exactly (not the V1 caller's untyped interpretation).
- [ ] Every entry in the project's shared inventory (per `_extracted-idioms.md`) has been considered before authoring custom markup / CSS / util.
- [ ] No silent catches in port code — all failures route through the project's error handler or include explicit recovery comment + debug log.
- [ ] No frontend / consumer workaround for backend / provider gaps — divergent API shape filed as ticket, port halted with explicit dependency.
- [ ] Lifecycle / data-fetch hooks chosen for the component's actual mount semantics (per the project's framework conventions in CLAUDE.md / `_extracted-idioms.md`).
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

## Reviewer-approval mechanism (heavy-tier rows)

Heavy-tier rows pause for reviewer approval before they can flip to `done`. Real protocol, not a soft suggestion:

**Ledger field**: every heavy-tier row has a `reviewer_approval:` field. Initially empty. Approval lands as `<reviewer-name>@<iso>` (e.g., `reviewer_approval: alice@2026-05-02T18:30Z`).

**Halt behaviour**: when `/migration-fast` / `/port-feature` reaches a heavy-tier row's RECORD step:
1. Applies the fix and runs VERIFY as normal (parity tests, contract check, audit).
2. Writes the row to ledger with `status: pending-review` (NOT `done`).
3. Writes `ai/migration/halts/<id>-pending-review.md` with: assigned reviewer, what to verify (audit + contract + parity-test results), how to approve.
4. Continues to the next row (heavy rows do NOT block the rest of the phase).

**Approval flow**:
- Reviewer reads the halt file + the audit at `ai/migration/audits/<id>.md` + the impact / runbook.
- Reviewer adds `reviewer_approval: <name>@<iso>` to the ledger row + commits the ledger update.
- On next `/migration-gate <N>` run, rows with non-empty `reviewer_approval` flip from `pending-review` → `done`.

**Reviewer assignment**:
- Default: project's `CODEOWNERS` for the row's V2 path OR the `default_reviewer:` field in `ai/migration/_v2-anchors.md`.
- Override: pass `--reviewer=<name>` to `/migration-fast` / `/port-feature`.
- Fallback: if no reviewer assignable, halt the row with "manual review required".

**Timeout**: default 7 days. After timeout, row stays `pending-review`; `/migration-status --blockers` surfaces it. No auto-fail. No silent advance.

**Validator** treats `pending-review` as terminal-non-fix; gate accepts the row only when `reviewer_approval` is non-empty.

## Mid-port tier promotion

Mid-port the agent may realize a row's tier was wrong (scan classified standard, but fix touches > 25 files; or trivial port turns out to remove a public API symbol). Procedure:

1. **Halt the row** at DECIDE; agent surfaces the promotion request with reasoning.
2. **User decides** via `/migration-promote-tier <id> <new-tier> [--reason="<text>"]`:
   - `<new-tier>` ∈ `{trivial, standard, heavy}`.
   - Promotions (trivial → standard → heavy) require no further justification.
   - Demotions require `--reason=`. Demotion of any row whose audit flagged P0 / cross-repo / contract-break / write-path-mutation is **forbidden**.
3. **Backfill artifacts** for the new tier:
   - Promote to standard → backfill ≤200-char rationale + 3-section contract (Inputs / Outputs / Known V1 bugs) + 10-fixture parity test.
   - Promote to heavy → backfill full 8-artifact set (contract, plan, parity tests, tolerance.yaml, perf-decisions, runbook, audit, mapping); reviewer-approval flow kicks in.
4. **Resume**: agent re-enters DECIDE → FIX → VERIFY → RECORD with the new tier's discipline.

`/migration-promote-tier` writes one line to `ai/migration/_history.md`: `<iso> promote-tier <id> <old>→<new> | reason: <text>`.

## Idiom-drift propagation

When `_extracted-idioms.md` / `ai/architecture.md` / `ai/conventions.md` is modified between scan and execution, ledger rows that referenced the changed conventions may need re-evaluation:

**`/migration-scan` detection**: at end of scan, compares the oracle files' git hashes against hashes recorded in prior scan's `ai/migration/_session-digest.md`. If changed:
1. Scan-report includes "Oracle drift detected" section listing changed entries + affected rows (rows whose `notes` cite the changed convention OR whose plan references the changed module shape).
2. Recommended action: re-run `/migration-recheck <area>` for affected rows OR `/migration-replan --include-drifted`.

**`/migration-replan --include-drifted`**: re-phases rows whose plan references changed conventions. `done` rows flip to `unverified` ONLY if the change materially affects their port (architectural rename, primitive replaced); cosmetic changes leave `done` rows alone.

**Validator**: `check_oracle_drift` (planned) compares oracle hashes pre- and post-port; halts the gate if any row's audit cites a now-stale oracle reference.

## Enforcement

- **Phase 5 audit** halts on: ledger drift (PR ports a feature without updating ledger), missing contract file, parity-test red, perf-decision file missing.
- **`/migration-status` command** reports per-feature state and flags rows older than the SLA (e.g., a feature in `In-progress` for >30d is flagged stalled).
- **`parity-auditor` agent** is invoked in PR review; its checklist hard-fails on missing parity tests, missing contract, scope-creep evidence (V1 modifications in a port PR).
- **Phase 4.6 STUDY-DECIDE-ACT** anchors this rule to the project's actual V1/V2 paths, ledger location, and cutover mechanism. A rule that talks about generic feature flags while the project uses Django settings + URL routing is a leak — the project-specific block is mandatory.
- **Validator script** `scripts/validate-migration-artifacts.sh` operationalizes the enforcement of the named anti-patterns below — each anti-pattern maps to a specific check function that halts the gate when its fingerprint matches:
    - "The Zombie Port" → `check_no_dead_v1_ported` (planned). Re-runs the 6-axis reachability check against the port PR's V1 entry point at the pinned commit; if all 6 axes return zero callers, the gate REFUSES the port. Override allowed via `--include-dead` flag on the originating scan + `caller_evidence: <path:line>` field in the ledger row.
    - "The Hand-waved Query Param" → `check_audit` hand-wave grep (rejects `etc.`, `...`, `&...`, `N+ items`, `and so on`, `deferred to port-phase`).
    - "The Permission-gate Drop" → `check_v2_structure § per-button-permission-gate` (per-stack fingerprint set).
    - "The Reinvented Wrapper" → `check_v2_mapping_doc` halts on missing/empty `ai/migration/mapping/<feature>.md` + `check_v2_structure` flags the most common reinvention fingerprints.
    - "The Wrong Lifecycle Hook on Nested Child" → `check_v2_structure § lifecycle-hooks` (stack-conditional via `PROJECT_KIND`; per-stack pack rules name the concrete hook pairs).
    - "The Misplaced i18n / Locale Key" → planned-validator `check_i18n_locale_parity` in the same script (catches keys that don't resolve in the project's locale tree).
    - "The Consumer Compensation" → audit-time review-checklist row "No frontend/consumer workaround for backend/provider gaps"; `parity-auditor` flags it during PR review.

## Anti-patterns (named)

- **The Zombie Port** (added 2026-05-02) — porting a V1 feature that has zero callers. The feature is dead code; porting it migrates rot from V1 into V2, inflates V2's surface area, and creates a maintenance burden for code no consumer exercises. The fingerprint: a feature whose 6-axis reachability check (app source / tests / cron / route registration / infra / production telemetry) returns zero callers, yet the migration plan still queues it. The fix: dead V1 code is excluded from the port queue at scan time (halt #11), marked `status: deprecated` with `deprecation_reason: dead-v1-no-callers`, and deleted from V1 directly during V1 retirement — never touches V2. Override only via `--include-dead` + `caller_evidence: <path:line>` proving a missed caller. Real-world cost: every zombie port ships ~50–500 lines of V2 code that exercises no test, has no consumer, and accretes onto V2's maintenance budget. A 200-feature migration with 15% dead code = 30 zombies = ~10K lines of pure waste in V2.
- **The Transposition Trap** — line-by-line copy of V1 into V2. Carries V1's bugs + V1's hidden invariants. The port must be re-derived from the contract AND must follow V2's NEW structure (shared wrappers, conventions, file layout). Concrete fingerprints are stack-specific and live in the per-stack packs:
    - Frontend fingerprints → `frontend/rules/migration-frontend.md § Frontend Transposition Trap fingerprints`
    - Backend fingerprints → `backend/rules/migration-backend.md` (if defined)
    - The validator's `check_v2_structure` is stack-conditional via `PROJECT_KIND` and applies the per-stack fingerprint set automatically.

  **Phase 3 of `/port-feature` (Retrieve) MUST list the gold-standard V2 files the executor reads BEFORE writing.** The plan's "V2 patterns I will follow" section names them explicitly. Skipping Phase 3 is the trigger — the executor opens V1, reads it, opens V2's destination directory, and writes by analogy to V1 instead of by analogy to V2's gold standard.
- **The Bundled Cutover** — porting + redesigning + adding features + perf-tuning in one PR. Reviewer cannot localise regressions; rollback is all-or-nothing.
- **The Stale Oracle** — V1 evolves during port; parity tests pass against a moving target. Pin V1's commit; freeze it for the duration of the port.
- **The Silent Break** — V2 changes an output shape, returns a different error type, drops a side effect. Ships unnoticed; long-tail customer issues surface for months.
- **The Test-by-Test Port** — porting V1's unit tests verbatim. Misses production behaviours that V1 has but V1's tests don't cover. Use record-replay against real traffic samples (anonymised).
- **The Eternal Shadow** — V2 lives in shadow indefinitely "until we're sure". The longer V2 stays in shadow, the more divergent it becomes from V1 (which keeps shipping). Set a cutover deadline; if missed, re-baseline parity.
- **The Buried Perf "Improvement"** — an N+1 fix that quietly changes ordering / nullability / ID stability. The "improvement" is a contract break; ships under the port PR; surfaces as a bug 6 weeks later.
- **The V1 Deletion Sprint** — deleting V1 modules en masse "to clean up." A single `import` left in a stale cron job means a silent prod failure when the cron next fires. Delete only when last reference is gone + telemetry confirms zero traffic.
- **The Trusted Summary** — delegating V1↔V2 comparison to a search/exploration agent that returns "looks identical" in confident summary language; the executor echoes that into the audit without verifying claim against source. The audit is a checklist, not a vibe-check; every "identical" claim has a `<path:line>` citation that resolves OR the audit halts. (Canonical real-world incident: a missing add-button + divergent query-param surface both passed audit because the summary said identical. Lesson: trust agents to *find* sources, not to *verify* equivalence; verification reads source line by line.)
- **The Hand-waved Query Param** — audit declares "GET /endpoint?foo=&bar=&..." with `&...` as the trailing surface, hiding 4 unenumerated params. The contract's Inputs section enumerates EVERY param V1 sends. No `&...`, no "etc.", no "and so on" — list them all or halt the contract.
- **The Optimistic Form Field Match** — audit declares V1↔V2 form fields "identical" without enumerating them. Frontend-specific anti-pattern: a missing field, a wrong type, a missing validator passes audit. Contract's Inputs section lists every field on V1's page, V2 must render the union.
- **The Permission-gate Drop** — V1 hides an action via `v-if="hasPermission(...)"` / `{user.can(...) && ...}`; V2's port renders the action without the gate. Per-button audit enumerates every gate; missing gate is a security regression.
- **The Guessed Type** (added 2026-05-01) — the V2 DTO / interface / type is authored by reading V1 caller code (which destructures the response untyped) instead of from a captured API response. When V1 silently returns one field name and V2 types another, the field mismatch produces empty consumer UIs / blank widgets / undefined-everywhere with no error thrown. Fix: every service-touching port captures real responses to `ai/migration/api-samples/<feature>/`; V2 types derive from those samples. The validator's `check_api_response_sample` enforces the artifact.
- **The Reinvented Wrapper** (added 2026-05-01) — porter authors custom markup / CSS / util / hook for a surface that already has a shared wrapper in the project's gold-standard inventory. Common shapes: a custom field group when a shared field-wrapper exists; a hand-rolled language toggle when a shared translation-input exists; a nested wrapper-inside-wrapper that the host already handles internally (causing double labels / double padding). Root cause: porter never inventoried the shared layer before writing. Fix: the `mapping/<feature>.md` artifact (required at every tier) names the project's shared equivalent for every V1 surface BEFORE code is written. The validator's `check_v2_mapping_doc` halts on missing/empty mapping; the stack-conditional fingerprints in `check_v2_structure` flag the most common reinventions.
- **The Silent Catch** (added 2026-05-01) — port code wraps API calls in `catch { /* fail silent */ }` or empty `catch {}`. Empty UI / blank widgets / missing data become indistinguishable from "operation succeeded with empty result". Bugs hide for weeks because users report "looks empty" not "is erroring". Fix: every catch in port code calls the project's error handler (named in `_extracted-idioms.md`) OR includes a comment + debug log explaining recovery. The validator's `check_v2_structure` flags both swallow patterns.
- **The Wrong Lifecycle Hook on Nested Child** (added 2026-05-01) — port copies a page-level / route-level lifecycle pattern onto a nested child component with different mount semantics. The chosen hook never fires (e.g., a hook that only fires when the framework's route-cache reactivates, chosen for a component that the route-cache never reaches); the child never fetches; the page renders "no data" forever. Fix: nested children that fetch data use the project's standard mount-AND-reactivate hook pair (named in `_extracted-idioms.md`), not just one. The validator's `check_v2_structure` flags the framework-specific shape via `PROJECT_KIND`; per-stack pack rules (e.g., `frontend/rules/migration-frontend.md`) name the concrete hook pairs.
- **The Misplaced i18n / Locale Key** (added 2026-05-01) — code references a translation / locale key path that doesn't resolve in the project's actual locale tree (key was added at the wrong namespace level, or reference predates a key move, or namespace casing differs). The literal key string renders to users instead of the translated text. Fix: i18n key paths must resolve against the actual locale file structure. A future validator addition will grep referenced keys against the resolved locale tree.
- **The Consumer Compensation** (added 2026-05-01) — provider returns wrong field name / missing field / different shape; the consumer "fixes" it locally by mapping fields in the component / job / handler instead of filing a provider ticket. The drift accumulates silently across consumers. Fix: when audit detects provider-shape divergence, mark the row `status: halted` with explicit dependency on the provider fix ticket; do NOT ship a consumer-side workaround.

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

This rule **is** the surface. The 9 contract sections, the 11 hard halts (including the dead-V1-code halt), the 6-axis dead-code check, the frontend axes, the anti-pattern catalogue, and the three procedures (extract / parity-test / perf-uplift) are all inlined above. No skill / agent / command dispatch is required — follow the rule as a checklist.
