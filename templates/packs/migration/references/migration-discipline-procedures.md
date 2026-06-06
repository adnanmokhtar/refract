# Migration discipline — procedures & operational reference

> Companion to `rules/migration-discipline.md` (the always-loaded core). This file is **loaded on demand** — by migration commands/skills/agents when extracting contracts, generating parity tests, auditing, reviewing, or re-tiering — NOT auto-loaded into every session.
> Rule-only tools (Aider / Codex / Gemini): this file ships alongside the core rule in your adapter bundle — read both; together they are the complete discipline.
> Content relocated verbatim from the core rule on 2026-06-07 (40k-char always-on limit); wording unchanged.

## Tier artifact specs

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


    **The Navigation Inventory MUST be a TWO-LAYER scan; a Layer-A-only scan is incomplete and HALTS:**
    - **Layer A — Route tree**: read every router file in V1 + V2; build the route hierarchy. This catches top-level tabs + route children + redirects.
    - **Layer B — Per-leaf template grep (MANDATORY, not optional)**: for EACH leaf component identified in Layer A (the leaf-component / view-template file the route resolves to), open its source and grep for in-template tab patterns. If ANY match, those are ADDITIONAL nav leaves to enumerate under that parent. Tab patterns to scan: the project's tab primitive (concrete tag/component vocabulary varies by stack — see the project's frontend pack rule § Tab patterns), the project's role-based ARIA tab markers (`role="tab"`, `role="tablist"`), in-page tab arrays (the project's iteration construct over a `tabs|items|sections` collection, `[{label, path|value}]` literals at template scope), nested-routing siblings inside the component, accordion title arrays. Per-stack packs add their own framework-specific patterns.
    - **Why both layers**: routes-only extraction misses in-component tab UIs (e.g., a marketing page that uses one route but renders many platform tabs via a radio-button + conditional-render pattern inside its template). The "Layer-A-Only Scan" failure mode produces high-confidence "PARITY" verdicts on tabs whose internal navigation was never compared.

    **Section 0 completion checklist (every box must be ticked before audit can advance past Section 0):**
    - [ ] V1 routes extracted from every router file
    - [ ] V2 routes extracted from every router file
    - [ ] For EACH V1 route leaf: component source opened and grep'd for tab patterns; matches enumerated as additional V1 leaves
    - [ ] For EACH V2 route leaf: same grep applied; matches enumerated
    - [ ] V1 leaf set ↔ V2 leaf set diffed
    - [ ] Every V1 leaf has a V2 equivalent OR is flagged DRIFT (with closure verb)
    - [ ] Every V2-extra leaf flagged for V1-parity decision (default: remove the extra)
    - [ ] No "consolidation" accepted without ADR — a V1 separate page becoming a V2 tab (or vice versa) is drift, not STRUCTURE_OK

    A Section 0 with only the route-tree diff is a Layer-A-Only Scan — incomplete, HALTS.


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
- **Phase 4.6 STUDY-DECIDE-ACT** anchors this rule to the project's actual V1/V2 paths, ledger location, and cutover mechanism. A rule that talks about generic feature flags while the project uses its own framework-native settings + routing primitive is a leak — the project-specific block is mandatory.
- **Validator script** `scripts/validate-migration-artifacts.sh` operationalizes the enforcement of the named anti-patterns below — each anti-pattern maps to a specific check function that halts the gate when its fingerprint matches:
    - "The Zombie Port" → `check_no_dead_v1_ported` (planned). Re-runs the 6-axis reachability check against the port PR's V1 entry point at the pinned commit; if all 6 axes return zero callers, the gate REFUSES the port. Override allowed via `--include-dead` flag on the originating scan + `caller_evidence: <path:line>` field in the ledger row.
    - "The Hand-waved Query Param" → `check_audit` hand-wave grep (rejects `etc.`, `...`, `&...`, `N+ items`, `and so on`, `deferred to port-phase`).
    - "The Permission-gate Drop" → `check_v2_structure § per-button-permission-gate` (per-stack fingerprint set).
    - "The Reinvented Wrapper" → `check_v2_mapping_doc` halts on missing/empty `ai/migration/mapping/<feature>.md` + `check_v2_structure` flags the most common reinvention fingerprints.
    - "The Wrong Lifecycle Hook on Nested Child" → `check_v2_structure § lifecycle-hooks` (stack-conditional via `PROJECT_KIND`; per-stack pack rules name the concrete hook pairs).
    - "The Misplaced i18n / Locale Key" → planned-validator `check_i18n_locale_parity` in the same script (catches keys that don't resolve in the project's locale tree).
    - "The Consumer Compensation" → audit-time review-checklist row "No frontend/consumer workaround for backend/provider gaps"; `parity-auditor` flags it during PR review.


## Halts 12-13 — full elaborations

12. **UI surface audit row missing v1_states / v2_states enumeration** — for any audit row whose `v1_path` is a UI file (any leaf-component / view-template extension declared in the project's stack — see `frontend/rules/migration-frontend.md § Leaf-component extensions` for the concrete list), the row MUST enumerate every interaction state V1 exposes: idle / loading / opened / single-result / empty / error / hover / disabled / each branch of conditional rendering / etc. A row described in one line ("navigate-to-X", "shows the list", "opens dialog") without explicit per-state enumeration HALTS. **Why**: a button labelled identically in V1 and V2 can hide a stateful affordance in V1 (dropdown, async fetch, branched click handler) and a one-shot navigation in V2 — the divergence is invisible without state enumeration, and the audit verdict misses the real V1 contract. Required field shape on UI rows: `v1_states: [list]`, `v2_states: [list]`, `gap: any v1_state not in v2_states`. A row with `v1_states: [single line description]` does NOT satisfy enumeration — each state is a separate list item.
13. **Module/page audit missing navigation inventory** — for any audit whose scope is a module, settings shell, page-with-tabs, page-with-subtabs, or any UI surface that exposes more than one user-clickable navigation target (top-level tab, in-page sub-tab, sidebar item, inner-route, accordion group, modal-shell tab), the audit MUST produce a Navigation Inventory section comparing V1's full navigation tree to V2's. Required shape: list every clickable label/route reachable from the module entry in V1; list the same for V2; produce a 1:1 mapping. Any V1 navigation leaf with no V2 equivalent navigation surface is **DRIFT, not STRUCTURE_OK** — even if the underlying form fields, components, or data exist somewhere in V2's source. **Burying a V1 tab as a section in another V2 tab is drift.** Splitting a V1 tab into separate V2 routes is drift unless an accepted ADR documents the navigation restructure. **Why**: the user-clickable path to reach a feature IS observable behaviour. "User can edit colors via this tab" and "user can edit colors by scrolling down inside another tab" are different observable outcomes; only the first matches V1. Source-only audits that confirm files exist without tracing the user click-path produce false STRUCTURE_OK verdicts. The Navigation Inventory section appears BEFORE per-axis enumeration in every module-scoped audit; if it surfaces drift, the audit halts and reports nav drift first — per-axis work happens only on tabs that exist on both sides.

    **The Navigation Inventory MUST be a TWO-LAYER scan** — Layer A (route tree from every router file) AND Layer B (per-leaf template grep for in-component tab patterns, MANDATORY). A Layer-A-only scan is incomplete and HALTS. Full two-layer spec + the Section 0 completion checklist: `references/migration-discipline-procedures.md § Navigation Inventory two-layer scan`.



## v1_status modes (full semantics)

When `v1_status: production-stable` (the most common case — V1 is in maintenance-only mode), audits SKIP all V1-side verification halts. The agent treats V1 source as the unambiguous oracle and produces gap findings against V2 only. The `check_api_response_sample` validator becomes a WARNING instead of a halt — V2 types are derived from V1 source reads.

When `v1_status: actively-developed` (rare — V1 is still being feature-developed in parallel with V2), the auditor pins `v1_reference_commit` and treats THAT specific commit as the oracle for the duration of the port. V1 changes after the pin are ignored until the next `/migration-scan`.

When `v1_status: frozen` (post-cutover-prep — V1 is read-only, no new commits), no halts fire from V1-side at all.


## Tier rationale (Phase 7 incident)

> **Why this is tiered (added 2026-04-30 from a Phase 7 incident lesson)**: prior single-floor discipline produced ~95% docs / ~5% code on small features (all 8 artifacts mandatory regardless of feature size). 1-line fixes generated 5-section contracts + 30-fixture parity tests + 12-candidate perf surveys + 7-stage runbooks. The tiered model preserves the F039 anti-Trusted-Summary protections on heavy features while letting trivial features ship in proportion.



## Should — full guidance

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


