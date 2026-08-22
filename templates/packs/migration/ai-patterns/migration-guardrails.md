---
name: migration-guardrails
description: "Pattern: Migration guardrails (per-tier artifact floor, the dead-V1 reachability check, the anti-bloat merge gates, the named anti-pattern catalogue and the check that catches each)"
kind: ai-pattern
pack: migration
---

# Pattern: Migration guardrails (tier floor, merge gates, named anti-patterns)

> **Hard rule:** every threshold, artifact floor and named anti-pattern the migration rule enforces is defined HERE, and this file installs unconditionally. `rules/migration-discipline.md` states the halts; this file states what each one measures. A halt claimed without the definition below, or an anti-pattern name used that is not in the catalogue below, is a bug in the audit — not a finding.

**Why this file exists at all.** The depth below used to live in `references/migration-discipline-{procedures,catalogue}.md`. Those files are **not a delivery path**: `templates/phases/phase-4.2-apply.md:210-213` (and `:347-350`) copy `references/<name>.md` into a project only when `<name>` equals a **detected framework name** — `for fw in <detected-frameworks>; do cp -R .../references/${fw}.md .claude/references/ 2>/dev/null || true; done` — and `2>/dev/null || true` swallows every miss. No framework is called `migration-discipline-procedures`, so no installed project has ever received one. No tool adapter ships them either: `phase-4.8-deep.md:35` enumerates the translation surface as `.claude/{rules,commands,agents}/<x>.md` plus `.claude/skills/<x>/SKILL.md`. `ai-patterns/*.md` copies unconditionally into `ai/patterns/` (`phase-4.2-apply.md:207`), which is the destination `scripts/check-rule-budget.sh:105` names in its own failure message ("trim it or move depth to ai-patterns/").

**When to apply**
- Any `/port-feature`, `/find-and-fix`, `/migration-phase` or `/migration-gate` run — the tier floor decides which artifacts the gate demands, and the merge gates decide whether the PR is a port or a redesign.
- Any audit or `@parity-auditor` output that classifies a feature, names a failure, or refuses to advance a row.

**When NOT to apply**
- A one-line trivial-tier fix already past its gate: the tier floor is a floor, not a re-litigation. Over-production is allowed but never rewarded.

**Halt conditions / mandatory cites**
- An artifact missing at the row's tier → `/migration-gate <N>` REFUSES that row (§ Tier artifact specs).
- An anti-pattern name in a verdict that is not in § Named anti-patterns → say what actually happened instead, or add it here with a fingerprint and a catching check.
- A dead-V1 verdict without all six axes reported → the verdict is incomplete; halt 11 has not been evaluated (§ What counts as dead V1 code).

> **Project-specific block** — Phase 4.6 fills this from `ai/migration/_v2-anchors.md` + `.claude/_extracted-codebase.md`.
>
> - **V1 / V2 roots, parity-test root, cutover mechanism**: `<extracted>`.
> - **`v1_status`**: `<extracted>` (default `production-stable` — see § v1_status modes for which halts that skips).
> - **Ledger + artifact roots**: `ai/migration/` unless the anchors file says otherwise.

## Tier artifact specs

### Heavy-tier artifact spec (the historical floor)

| Artifact | Path | Purpose | Mandatory sections |
|---|---|---|---|
| Contract | `ai/migration/contracts/<feature>.md` | The spec V2 must satisfy. Re-derived from V1 source, not from a summary. | All 9 sections, with the per-section template: skill `extract-v1-contract` § 9 (Synthesise the contract). |
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



## Halts 12-13 — full elaborations

12. **UI surface audit row missing v1_states / v2_states enumeration** — for any audit row whose `v1_path` is a UI file (any leaf-component / view-template extension declared in the project's stack — see `frontend/rules/migration-frontend.md § Frontend audit axes` for the concrete list), the row MUST enumerate every interaction state V1 exposes: idle / loading / opened / single-result / empty / error / hover / disabled / each branch of conditional rendering / etc. A row described in one line ("navigate-to-X", "shows the list", "opens dialog") without explicit per-state enumeration HALTS. **Why**: a button labelled identically in V1 and V2 can hide a stateful affordance in V1 (dropdown, async fetch, branched click handler) and a one-shot navigation in V2 — the divergence is invisible without state enumeration, and the audit verdict misses the real V1 contract. Required field shape on UI rows: `v1_states: [list]`, `v2_states: [list]`, `gap: any v1_state not in v2_states`. A row with `v1_states: [single line description]` does NOT satisfy enumeration — each state is a separate list item.
13. **Module/page audit missing navigation inventory** — for any audit whose scope is a module, settings shell, page-with-tabs, page-with-subtabs, or any UI surface that exposes more than one user-clickable navigation target (top-level tab, in-page sub-tab, sidebar item, inner-route, accordion group, modal-shell tab), the audit MUST produce a Navigation Inventory section comparing V1's full navigation tree to V2's. Required shape: list every clickable label/route reachable from the module entry in V1; list the same for V2; produce a 1:1 mapping. Any V1 navigation leaf with no V2 equivalent navigation surface is **DRIFT, not STRUCTURE_OK** — even if the underlying form fields, components, or data exist somewhere in V2's source. **Burying a V1 tab as a section in another V2 tab is drift.** Splitting a V1 tab into separate V2 routes is drift unless an accepted ADR documents the navigation restructure. **Why**: the user-clickable path to reach a feature IS observable behaviour. "User can edit colors via this tab" and "user can edit colors by scrolling down inside another tab" are different observable outcomes; only the first matches V1. Source-only audits that confirm files exist without tracing the user click-path produce false STRUCTURE_OK verdicts. The Navigation Inventory section appears BEFORE per-axis enumeration in every module-scoped audit; if it surfaces drift, the audit halts and reports nav drift first — per-axis work happens only on tabs that exist on both sides.

    **The Navigation Inventory MUST be a TWO-LAYER scan** — Layer A (route tree from every router file) AND Layer B (per-leaf template grep for in-component tab patterns, MANDATORY). A Layer-A-only scan is incomplete and HALTS. Full two-layer spec + the Section 0 completion checklist: `frontend/rules/migration-frontend.md § Frontend audit axes`.



## v1_status modes

When `v1_status: production-stable` (the most common case — V1 is in maintenance-only mode), audits SKIP all V1-side verification halts. The agent treats V1 source as the unambiguous oracle and produces gap findings against V2 only. The `check_api_response_sample` validator becomes a WARNING instead of a halt — V2 types are derived from V1 source reads.

When `v1_status: actively-developed` (rare — V1 is still being feature-developed in parallel with V2), the auditor pins `v1_reference_commit` and treats THAT specific commit as the oracle for the duration of the port. V1 changes after the pin are ignored until the next `/migration-scan`.

When `v1_status: frozen` (post-cutover-prep — V1 is read-only, no new commits), no halts fire from V1-side at all.



## Anti-bloat merge gates

A real-world Phase 7 incident (Apr 2026) burned ~95% of port-time tokens on documentation that did not enable any code change. These rules prevent recurrence — they are merge gates, not suggestions.

- **Code edits are the deliverable.** A doc that doesn't enable a code change is waste. Contracts/plans/runbooks/perf-decisions exist when they unblock a code decision; they are not deliverables themselves.
- **ADRs justify user-decided breaks, not agent-default closures.** When V2 deviates from V1, the agent's default closure verb is **edit V2 to match V1** — a code change. Drafting an ADR to legitimize V2's deviation is forbidden as a closure unless the user explicitly chose keep-V2 OR V1 is a security/privacy/legal regression. The Phase 7 anti-pattern (~6 ADRs drafted to preserve V2-over-V1) MUST NOT recur.
- **Per-axis enumeration is required wherever a gap exists, at every tier.** Heavy-tier audits enumerate every axis fully (F039 anti-Trusted-Summary protection). Standard- and trivial-tier audits MAY summarise axes with zero gaps in 1 line, but ANY axis with ≥1 detected gap (add / delete / change, frontend or API) MUST produce the full per-row enumeration table for that axis with `<v1-path:line>` and `<v2-path:line>` citations. Trivial-tier audits with summary-only text and ≥1 gap detected silently are forbidden — the validator's `check_audit` hand-wave grep (in `validate-migration-artifacts.sh`) HALTs on `etc.`, `...`, `N+ items`, `and so on`, `deferred to port-phase parity author`, and `by audit-by-inspection`.
- **Single agent dispatch with a shared 5K-token context blob is the default.** Parallel sub-agents are heavy-tier-only AND require a deduplicated context blob (each sub-agent reading 50K+ token files independently is forbidden — prior Phase 7 cost: 200-360K duplicate tokens per port).
- **Default-true wrapper props MUST be set explicitly when removing UI affordances.** Components like `<CrudActions>`, `<TableHeader>`, `<TableActions>` default `show-*` / `can-*` props to `true`. Removing a `@delete-selected` event handler does NOT hide the button. The fix is `:show-delete="false"` / `:can-delete="false"` set explicitly. Removing the handler alone is the F040-class default-true bug.
- **Audit verdict criterion is V1-parity, not plan-execution.** "PASS" means V2 matches V1, NOT "the agent shipped what the plan said." Phase 7 audits drifted into plan-execution checks; the discipline reverts.
- **Trivial-tier ports do not produce contracts, plans, perf-decisions, or runbooks.** The audit + ledger note carry the risk register. Heavy-tier opt-in is required for those artifacts.

> **Tier artifact specs (heavy / standard / trivial)** — the per-tier artifact tables are § Tier artifact specs at the top of this file. The gate validates per the row's tier, never the heavy floor universally.



## Supporting mechanisms (thresholds the commands cite)

These three are not halts — they decide who signs a heavy row off, how a row changes tier mid-port, and what happens when the idiom oracle moves under an in-flight row. Each carries its own threshold and is cited by name from a command or an agent.

### Reviewer-approval mechanism (heavy-tier rows)

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

### Mid-port tier promotion

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

### Idiom-drift propagation

When `_extracted-idioms.md` / `ai/architecture.md` / `ai/conventions.md` is modified between scan and execution, ledger rows that referenced the changed conventions may need re-evaluation:

**`/migration-scan` detection**: at end of scan, compares the oracle files' git hashes against hashes recorded in prior scan's `ai/migration/_session-digest.md`. If changed:
1. Scan-report includes "Oracle drift detected" section listing changed entries + affected rows (rows whose `notes` cite the changed convention OR whose plan references the changed module shape).
2. Recommended action: re-run `/migration-recheck <area>` for affected rows OR `/migration-replan --include-drifted`.

**`/migration-replan --include-drifted`**: re-phases rows whose plan references changed conventions. `done` rows flip to `unverified` ONLY if the change materially affects their port (architectural rename, primitive replaced); cosmetic changes leave `done` rows alone.

**Validator**: `check_oracle_drift` (planned) compares oracle hashes pre- and post-port; halts the gate if any row's audit cites a now-stale oracle reference.



## Review checklist (per port PR)

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



## Named anti-patterns

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
- **The Guessed Type** (added 2026-05-01; softened 2026-05-02 for production-stable V1) — the V2 DTO / interface / type is authored by reading V1 caller code (which destructures the response untyped) instead of from V1's authoritative source. When V1 silently returns one field name and V2 types another, the field mismatch produces empty consumer UIs / blank widgets / undefined-everywhere with no error thrown. Fix: derive V2 types from V1's serializer / view template / controller code (the actual contract source) OR from captured API samples. The validator's `check_api_response_sample` halts when `v1_status` is unset or `actively-developed`; warns (does not halt) when `v1_status: production-stable` AND V2 types cite the V1 source location they were derived from in the contract.
- **The Reinvented Wrapper** (added 2026-05-01) — porter authors custom markup / CSS / util / hook for a surface that already has a shared wrapper in the project's gold-standard inventory. Common shapes: a custom field group when a shared field-wrapper exists; a hand-rolled language toggle when a shared translation-input exists; a nested wrapper-inside-wrapper that the host already handles internally (causing double labels / double padding). Root cause: porter never inventoried the shared layer before writing. Fix: the `mapping/<feature>.md` artifact (required at every tier) names the project's shared equivalent for every V1 surface BEFORE code is written. The validator's `check_v2_mapping_doc` halts on missing/empty mapping; the stack-conditional fingerprints in `check_v2_structure` flag the most common reinventions.
- **The Silent Catch** (added 2026-05-01) — port code wraps API calls in `catch { /* fail silent */ }` or empty `catch {}`. Empty UI / blank widgets / missing data become indistinguishable from "operation succeeded with empty result". Bugs hide for weeks because users report "looks empty" not "is erroring". Fix: every catch in port code calls the project's error handler (named in `_extracted-idioms.md`) OR includes a comment + debug log explaining recovery. The validator's `check_v2_structure` flags both swallow patterns.
- **The Wrong Lifecycle Hook on Nested Child** (added 2026-05-01) — port copies a page-level / route-level lifecycle pattern onto a nested child component with different mount semantics. The chosen hook never fires (e.g., a hook that only fires when the framework's route-cache reactivates, chosen for a component that the route-cache never reaches); the child never fetches; the page renders "no data" forever. Fix: nested children that fetch data use the project's standard mount-AND-reactivate hook pair (named in `_extracted-idioms.md`), not just one. The validator's `check_v2_structure` flags the framework-specific shape via `PROJECT_KIND`; per-stack pack rules (e.g., `frontend/rules/migration-frontend.md`) name the concrete hook pairs.
- **The Misplaced i18n / Locale Key** (added 2026-05-01) — code references a translation / locale key path that doesn't resolve in the project's actual locale tree (key was added at the wrong namespace level, or reference predates a key move, or namespace casing differs). The literal key string renders to users instead of the translated text. Fix: i18n key paths must resolve against the actual locale file structure. A future validator addition will grep referenced keys against the resolved locale tree.
- **The Consumer Compensation** (added 2026-05-01) — provider returns wrong field name / missing field / different shape; the consumer "fixes" it locally by mapping fields in the component / job / handler instead of filing a provider ticket. The drift accumulates silently across consumers. Fix: when audit detects provider-shape divergence, mark the row `status: halted` with explicit dependency on the provider fix ticket; do NOT ship a consumer-side workaround.
- **The Auto-import Trip** (added 2026-08-21) — a parity test mounts a leaf component / view template from a project whose *production* build resolves helpers through an auto-import plugin (build-tool plugin, framework auto-import, IDE import-on-resolve), while the *test* config does not load that plugin. Auto-imported helpers (i18n hook, router hook, reactive primitives) resolve in production and not in tests, so the first mount fails with `<helper-name> is not defined`-type errors and the parity suite is red for a reason that has nothing to do with parity. It slips audit because audits read source and never run the tests. Fix: the test config mirrors the production plugin chain — `parity-test-generate` writes the test config alongside the test files rather than after the first red run. Detector: grep the production build config and the test config for the same auto-import plugin and flag a mismatch.



## Enforcement — where each halt is actually caught

- **Phase 5 audit** halts on: ledger drift (PR ports a feature without updating ledger), missing contract file, parity-test red, perf-decision file missing.
- **`/migration-status` command** reports per-feature state and flags rows older than the SLA (e.g., a feature in `In-progress` for >30d is flagged stalled).
- **`parity-auditor` agent** is invoked in PR review; its checklist hard-fails on missing parity tests, missing contract, scope-creep evidence (V1 modifications in a port PR).
- **Phase 4.6 STUDY-DECIDE-ACT** anchors the rule and this file to the project's actual V1/V2 paths, ledger location, and cutover mechanism. A rule that talks about generic feature flags while the project uses its own framework-native settings + routing primitive is a leak — the project-specific block is mandatory.
- **Validator script** `scripts/validate-migration-artifacts.sh` operationalizes the enforcement of the anti-patterns in § Named anti-patterns above — each anti-pattern maps to a specific check function that halts the gate when its fingerprint matches:
    - "The Zombie Port" → `check_no_dead_v1_ported` (planned). Re-runs the 6-axis reachability check against the port PR's V1 entry point at the pinned commit; if all 6 axes return zero callers, the gate REFUSES the port. Override allowed via `--include-dead` flag on the originating scan + `caller_evidence: <path:line>` field in the ledger row.
    - "The Hand-waved Query Param" → `check_audit` hand-wave grep (rejects `etc.`, `...`, `&...`, `N+ items`, `and so on`, `deferred to port-phase`).
    - "The Permission-gate Drop" → `check_v2_structure § per-button-permission-gate` (per-stack fingerprint set).
    - "The Reinvented Wrapper" → `check_v2_mapping_doc` halts on missing/empty `ai/migration/mapping/<feature>.md` + `check_v2_structure` flags the most common reinvention fingerprints.
    - "The Wrong Lifecycle Hook on Nested Child" → `check_v2_structure § lifecycle-hooks` (stack-conditional via `PROJECT_KIND`; per-stack pack rules name the concrete hook pairs).
    - "The Misplaced i18n / Locale Key" → planned-validator `check_i18n_locale_parity` in the same script (catches keys that don't resolve in the project's locale tree).
    - "The Consumer Compensation" → audit-time review-checklist row "No frontend/consumer workaround for backend/provider gaps"; `parity-auditor` flags it during PR review.



## Automation hooks

- `/migration-scan` sets each row's `tier:` and runs the 6-axis dead-V1 check; `--include-dead` requires `caller_evidence: <path:line>` and logs to `ai/migration/_history.md`.
- `/port-feature` and `/find-and-fix` produce the artifact set for the row's tier and re-run the RE-DETECT step so `gaps_in == gaps_closed`.
- `/migration-gate <N>` validates the artifact set **for the row's tier**, not the heavy floor universally, and runs `scripts/validate-migration-artifacts.sh`.
- `/migration-promote-tier` writes the tier change to the row and to `ai/migration/_history.md`; demotion requires an ADR.
- `@parity-auditor` cites anti-patterns by the names in § Named anti-patterns; `/migration-status` flags rows past the SLA.

## See also

- `migration-discipline.md` — the rule these floors and names serve; the 13 per-feature halts and the tier promoters live there.
- `feature-port.md` (sibling pattern) — the port loop and the 18-row structure-vs-behaviour axis lookup.
- `parity-testing.md` (sibling pattern) — the tolerance taxonomy the parity-test floor above assumes.
- `migration-ledger.md` (sibling pattern) — the row schema and state machine every gate above reads.
- Skills `extract-v1-contract` (the 9-section contract template), `parity-test-generate`, `perf-uplift-survey`, `data-cutover-orchestrate` — the executable procedures; all install with the pack.
