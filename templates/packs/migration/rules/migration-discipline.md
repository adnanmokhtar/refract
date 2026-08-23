---
name: migration-discipline
description: "Migration Rule: V1→V2 port discipline"
kind: rule
pack: migration
severity: must
applies-to: migration-track, every-code-writing-task-in-migration
---

# Migration Rule: V1→V2 port discipline

## CORE PHILOSOPHY — read this first, internalize, do not deviate

**V1 is the production reference. V1 is sacred truth.** We are in MIGRATION mode, not refactor mode. V1's behaviour, API, permissions, response shapes and error contracts are the PRODUCTION CONTRACT. Real users use V1 every day. V2's job is to mirror that contract while using V2's structure.

**Implications**:

1. **Do NOT halt to verify V1.** The auditor reads V1 source DIRECTLY and treats what it reads as the contract. There is no "confirm V1 is correct" step — V1 source IS the verification. A halt asking the user to verify V1's API means the audit logic is wrong.
2. **V1 cannot be wrong.** A V1 bug is either a documented behaviour we preserve (`known_v1_bug` in the contract; port-as-is) or a user-decided break (ADR + caller migration).
3. **API samples are HELPFUL, not REQUIRED.** Captured responses under `ai/migration/api-samples/` give V2's types perfect field accuracy, but a readable V1 source (controllers / serializers / view templates) is sufficient — missing samples WARN, not halt, when V1 source is unambiguous.
4. **We are NOT refactoring.** If V1 has odd query params, V2 has the same odd query params. If V1 gates on `tenants.read`, V2 gates on `tenants.read` — not "the cleaner `read.tenants`". Refactor happens AFTER migration, on V2-only, with its own ADR. Mid-migration "while I'm here" improvements are FORBIDDEN.
5. **Halts that DO fire**: V2 deviates from V1 (most common — fix V2); cross-repo blocker; user-chosen contract break (ADR); dead V1 code in the queue; artifact missing for the row's tier. All are about V2 quality and PROCESS completeness — never about V1 verification.

**V1 stability modes** — `v1_status` in `ai/migration/_v2-anchors.md` (with `v1_api_frozen`, `v1_reference_commit`): `production-stable` (default — V1-side halts SKIPPED, api-samples WARN) · `actively-developed` (pin `v1_reference_commit` as the oracle; api-samples stay a hard halt because V1 may have shipped contract changes) · `frozen` (no V1-side halts at all). Full semantics — which halts each mode skips: `ai/patterns/migration-guardrails.md § v1_status modes`.

**TL;DR: in migration mode, V1 is gospel. Don't ask, port.**

> **Project-specific values** (V1/V2 roots, parity-test location, cutover mechanism, caching and DB primitives) are auto-injected into the `project-specific` block at the bottom of this file by `scripts/apply-anchors.sh`. Edit `ai/migration/_v2-anchors.md` and re-run `/setup-project --refresh` — never edit the injected values here.

This rule governs every per-feature port. It exists because migrations fail three ways, and audits cite these names: **subtle behavioural drift** (V2 *almost* matches, ships, and leaks customer issues for months) · **scope creep** (the port becomes a redesign + perf project + refactor in one unreviewable PR) · **trusted summary** (an executor delegates V1↔V2 comparison, the agent reports "looks identical", and the executor echoes that into the audit unverified — a real incident passed both a missing UI affordance and a divergent query-param surface this way).

**This rule is the universal contract** — enforceable by any AI tool. Full-capability tools compose it by dispatch (`/port-feature` → `parity-auditor` → `extract-v1-contract`); rule-only tools follow this file directly. Of the adapters this repo ships, **only Aider is rule-only** (`tool-adapters/_registry.md:23` — closed slash set, no user-extensible primitive at any layer); Codex (`.agents/skills/`), Gemini (`.gemini/commands/*.toml`), Cline (`.cline/skills/`) and Windsurf (`.windsurf/workflows/`) each have an executable command primitive and take the dispatch path — `_registry.md § Command translation` verifies all four against vendor docs and lists "Gemini has no executable primitive" among its doc-verified FALSE claims.

**Enforcement floor = THIS file + the four patterns and four skills that install with the pack.** Every threshold, artifact floor, halt definition and anti-pattern name this rule delegates goes to `ai/patterns/migration-guardrails.md`, `ai/patterns/{feature-port,parity-testing,migration-ledger}.md`, or one of the four skills — all copied unconditionally (`templates/phases/phase-4.2-apply.md:207`). **`references/` is not a delivery path**: `phase-4.2-apply.md:210-213` copies `references/<name>.md` only when `<name>` equals a **detected framework name**, so no installed project has ever received `migration-discipline-catalogue.md`, and no tool adapter ships it (`phase-4.8-deep.md:35`). Nothing enforceable is stored there.

## Required artifacts per feature — tiered floor

Every feature port produces an artifact set scaled to its actual risk. Tier is set on the ledger row at audit time and propagates through the port.

> **Why tiered**: prior single-floor discipline produced ~95% docs / ~5% code on small features — 1-line fixes generating 5-section contracts, 30-fixture parity tests, 12-candidate perf surveys and 7-stage runbooks (Phase 7 incident, 2026-04-30). Tiering keeps the anti-Trusted-Summary protections on heavy features and lets trivial features ship in proportion.

### Tier classification (set by audit; trivial-by-default)

| Tier | Triggers (any one promotes) | Required artifacts |
|---|---|---|
| **trivial** (DEFAULT) | No promoter triggers | Audit + code edit + ledger note |
| **standard** | 1–3 P1 gaps OR single API contract divergence OR <300 LOC change | Audit + code edit + 3-section contract (Inputs/Outputs/Known V1 bugs) + short plan + 10-fixture parity test + ledger row |
| **heavy** | Any P0 OR cross-repo blocker OR contract break OR storefront blast radius OR write-path mutation OR security-sensitive | Full 8-artifact set per `ai/patterns/migration-guardrails.md § Tier artifact specs` |

**Rules**:
- **Default tier is trivial.** Every audit starts trivial unless a promoter above fires. Heavy-by-default was replaced — it overproduced docs.
- Tier is **set by audit**, written to the ledger row's `tier:` field; the audit MUST state the tier in 1–2 sentences citing trigger absence/presence.
- Heavy requires an audit-flagged trigger OR explicit user opt-in via `/port-feature <feature> --heavy`.
- User can **upgrade** tier anytime; **downgrade requires an ADR**.
- `/migration-gate <N>` validates the artifact set **for the row's tier**, not the heavy floor universally. Over-production is allowed but never rewarded.

## Anti-bloat rules

Merge gates (not suggestions), from the Phase 7 incident (~95% docs / ~5% code): **code edits are the deliverable** · ADRs justify USER-decided breaks only (agent-default closure = edit V2 to match V1) · per-axis enumeration required wherever a gap exists, at every tier (hand-wave grep HALTs on `etc.` / `...` / `N+ items`) · single agent dispatch + shared 5K context blob by default · default-true wrapper props set explicitly when removing UI affordances (F040) · audit verdict = V1-parity, NOT plan-execution · trivial tier produces no contracts/plans/perf-docs/runbooks. Full gate definitions + per-tier artifact specs: `ai/patterns/migration-guardrails.md § Anti-bloat merge gates` and `§ Tier artifact specs`.

## Contract — 9 required sections

The contract at `ai/migration/contracts/<feature>.md` MUST contain all 9 sections — 1. Inputs · 2. Outputs (per code path) · 3. Side effects · 4. Business rules · 5. Invariants · 6. Performance baseline · 7. Caller assumptions · 8. Edge cases · 9. Known V1 bugs — every claim cited `<path:line>`; a contract missing any section is incomplete and the audit halts. Full section-by-section template: skill `extract-v1-contract` § 9 (Synthesise the contract), which installs with the pack; per-tier scope (heavy = 9 sections, standard = 3) is in its § Tier-aware contract scope.

## Per-feature audit — 13 hard halts

The audit step runs against an implementation + its artifacts. The audit HALTS (refuses to advance the feature) on any of these 13 conditions:

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
11. **Dead V1 code in port queue** — the V1 source has zero callers across **all six** reachability axes (app source · downstream tests · cron/scheduler · route/API registration · infra/deploy config · production telemetry, N/A if unwired). One live axis → port it. Halt the port; mark the row `status: deprecated` + `deprecation_reason: dead-v1-no-callers` (no ADR — dead code is a structural fact). Override: `--include-dead` + `caller_evidence: <path:line>`, logged in `_history.md`. Full axis definitions + edge cases (public APIs, library exports, in-development, flag-gated): `ai/patterns/migration-guardrails.md § What counts as dead V1 code (the 6-axis check)`.
12. **UI surface audit row missing v1_states / v2_states enumeration** — any audit row whose `v1_path` is a UI file MUST enumerate every interaction state V1 exposes (idle / loading / opened / single-result / empty / error / hover / disabled / each conditional-render branch) as `v1_states:` / `v2_states:` / `gap:`. One-line rows ("navigate-to-X", "shows the list") HALT — a stateful V1 affordance vs a one-shot V2 navigation is invisible without state enumeration.
13. **Module/page audit missing navigation inventory** — any module / settings-shell / page-with-tabs / multi-nav-target audit MUST produce a Navigation Inventory as **Section 0, before per-axis work**: every clickable label/route reachable from the module entry, V1 vs V2, mapped 1:1. A V1 nav leaf with no V2 navigation surface is **DRIFT, not STRUCTURE_OK** — burying a V1 tab as a scroll-section inside another V2 tab is drift; splitting or consolidating navigation requires an accepted ADR. The scan MUST be two-layer (A: route tree from every router file; B: per-leaf template grep for in-component tab patterns). A Layer-A-only scan is incomplete and HALTS.
Halts 12–13 full spec (two-layer scan, Section 0 completion checklist, tab-pattern vocabulary): `ai/patterns/migration-guardrails.md § Halts 12-13 — full elaborations`.

**Output of any halt**: a structured remediation list — specific finding + specific action — written to the audit file. NO advance until each halt is cleared.

## Per-stack extensions and tool-agnostic procedure

The 6 generic axes (Inputs / Outputs / Errors / Auth / Side effects / Performance) are necessary but NOT sufficient: frontend ports add form-field / UI-affordance / query-param / event-handler / per-button-permission / a11y / DOM / lifecycle axes (`frontend/rules/migration-frontend.md`); backend ports add DTO-shape / query-param-surface / envelope / validator-stack / tenant-isolation / transaction-boundary axes (`backend/rules/migration-backend.md`). If the project has no per-stack pack file, author one against the stack's primitives — `_extracted-idioms.md` is the source of truth; this universal rule stays stack-agnostic and concrete component / hook / library names belong in the per-stack packs. The three canonical procedures — extract V1 contract, generate parity tests, perf-uplift survey — are dispatched as skills `extract-v1-contract` / `parity-test-generate` / `perf-uplift-survey`; rule-only tools read those same three `SKILL.md` files verbatim, since skills install with the pack and every adapter translates them.

## Must

- **Inventory V2 before reading V1.** Before extracting the V1 contract, scan V2's shared inventory — wrappers, shared utils / hooks / composables, design tokens, base classes — at the paths declared in `_extracted-codebase.md § Gold standards` and `_extracted-idioms.md`, and produce `ai/migration/mapping/<feature>.md`: a 2-column "V1 X → V2 Y" table. Skipping this is the #1 cause of the Transposition Trap. Required at every tier; `check_v2_mapping_doc` halts the gate without it.
- **Reuse-Before-Create.** Before authoring any component, hook, util, type, style or markup pattern, search that inventory. Exists → reuse. Partially exists → extend the shared one, don't fork. Authoring a duplicate is a migration failure, not a stylistic choice. `check_v2_structure` reads its fingerprint list from the PROJECT_KIND anchor; a PR introducing a new V1-pattern fingerprint must add a matching detector.
- **Read V1 before writing V2.** Produce `ai/migration/contracts/<feature>.md` with all 9 sections. The contract is the spec V2 must satisfy.
- **Prefer a captured API response for any port touching the service / data-access layer** — one per endpoint under `ai/migration/api-samples/<feature>/<endpoint>.json`, and derive V2's field names, nullability and nested shape from it. A Guessed Type ships an empty UI that reads as "API returned nothing" rather than "type mismatch". Under `v1_status: production-stable` the sample is a WARNING (`check_api_response_sample`) and V1 source may be read directly; under `actively-developed` it stays a hard halt.
- **Generate parity tests before V2 code.** Tests run V1 + V2 on identical inputs and assert equivalence per the tolerance taxonomy (exact / structural / numeric tolerance / order-insensitive / timestamp-insensitive / dom-equivalent). Red baseline before V2 is fine; green is required before cutover. Corpus ≥30 inputs OR record-replay; `tolerance.yaml` exists; every contract output field has a tolerance entry.
- **One feature per port PR.** Atomic unit = one ledger feature row. Multi-feature PRs hide regressions and make rollback ambiguous.
- **Update the ledger on every state transition.** `V1-only → In-progress → V2-shadow → V2-canary → V2-only → V1-deleted`. The ledger is the source of truth — code grep is not.
- **Cutover is gated.** V2-canary → V2-only only when: (1) parity tests green, (2) shadow / canary metrics show no regression on error rate / latency / business KPIs for the agreed observation window, (3) the relevant ADR (if any) is merged, (4) rollback path tested.
- **A cross-store data port uses a resumable checkpointed backfill + reconciliation, and read-cutover is gated on backfill-complete + reconciliation-green.** When V2 keeps the feature's data in a *different* store than V1 (different engine, schema, or owning service), the data itself must be ported — not just the code. The backfill MUST be resumable and checkpointed (key-range batches, durable cursor, idempotent upserts — never one unbounded `SELECT * → write` pass) and MUST apply the V1→V2 field mapping through the *same* shared mapper the dual-write path uses. A cross-store reconciliation (per-range counts + checksum/sample-diff) MUST prove the stores agree before any read flips: the read-cutover flag opens ONLY when the cursor is past the max key AND divergence is within the declared threshold. A flag that opens on "backfill exited 0" is the primary failure mode. Follow `data-cutover-orchestrate` — its readiness verdict (default `BLOCK`) is the evidence the cutover gate consults. **Boundary**: this owns the *cross-store* seam only — `parity-test-generate` COMPARES V1/V2 *outputs* (it never moves a row) and `database/`'s `migrations` owns *single-store* schema evolution in place (expand-contract, online DDL). If there is one store, this rule does not apply — hand off to `database/migrations`.
- **Delete V1 only when the last reference is gone.** `git grep` + dead-code analyser + telemetry "no traffic in N days". The `V2-only → V1-deleted` transition requires evidence attached.
- **Structure → V2 wins; observable behaviour → V1 wins.** This resolves the apparent conflict between "Use V2's primitives" and "Default to V1-parity": they apply on **different axes** — never substitute one for the other.

    **Decision checklist — ask in order, stop at first YES:**
    1. Would a *user* (or *caller / API consumer*) notice the difference if we changed it? → **BEHAVIOUR axis → V1 wins.**
    2. Is it about *where code lives*, *which shared primitive renders it*, *which layer owns it*, or *what file it sits in*? → **STRUCTURE axis → V2 wins.**
    3. Still ambiguous? Default to **BEHAVIOUR (V1 wins)** and surface to user — under-changing structure is recoverable; under-preserving behaviour ships a regression.

    18-row axis lookup table, worked examples, and the named failure modes on this axis (Transposition Trap / Silent Break / "I made it cleaner"): `ai/patterns/feature-port.md § Axis lookup — structure vs behaviour`.
- **Default to V1-parity, ADR is opt-in (BEHAVIOURAL axis).** When audit finds V2's *behaviour* deviates (extra button, missing field, flipped default), the **default action is to remove V2's deviation**. An ADR is required ONLY when the user explicitly chooses to keep V2's behaviour, or V1 is a security / privacy / legal regression. The agent MUST NOT silently draft an ADR to legitimize its own deviation — a real Phase 7 incident drafted ~6 such ADRs while leaving every user-visible gap unfixed. Surface the divergence, offer "match V1 / keep V2 + ADR / deprecate-V1-feature + ADR", wait for an explicit choice. **BEHAVIOUR ONLY, not structure.**
- **ADRs for V1↔V2 divergence require `user_decision_quote:`.** Every ADR at `ai/decisions/*-v2-break.md` (or any ADR closing a divergence finding) carries a non-empty `user_decision_quote:` — a verbatim user quote choosing keep-V2, specific to the divergence, e.g. `user_decision_quote: "I prefer the new dropdown" — user, 2026-04-01 chat`. Missing → the ADR is invalid, `check_adr_user_decision_quote` halts the gate, and the closure verb reverts to "edit V2 to match V1".
- **When an ADR IS warranted**, record: V1 behaviour, V2 behaviour, why the break is necessary, who's affected, caller migration path, deprecation timeline — in `ai/decisions/<NNN>-<feature>-v2-break.md`.
- **No frontend compensation for backend gaps.** A missing field, wrong shape or behaviour difference in V2's API is a backend ticket, not a UI workaround. Mapping `c.name` to `c.label` in the component, hardcoding a missing field, sending a fake parameter — each drifts the contract silently and re-surfaces as a bug in every other consumer. File the ticket; if blocked, mark the row `status: halted` with an explicit dependency.
- **No silent catches.** An empty `catch {}` makes failure indistinguishable from empty success — empty lists, missing widgets, no error indicator, and a user report of "looks empty" rather than "is erroring". Every catch in port code either calls the project's error handler (named in `_extracted-idioms.md`) or carries a one-line comment explaining why this failure mode is recoverable AND logs at debug level. `check_v2_structure` flags both.
- **Capture migration-time perf wins explicitly.** Per candidate (N+1 → batch, missing index, unbounded `SELECT *`, sequential await, no caching, in-app filter): decide applied / deferred / rejected with a reason and, for applied, a measured before/after, in `ai/migration/perf-decisions/<feature>.md`. A perf change is either parity-preserving or a documented break shipped separately.
- **Use V2's primitives, not V1's.** If V2's architecture says "service-layer + repository", do NOT carry over V1's fat controller. The port is the moment to align with V2 — that is the entire point.
- **Keep V1 untouched during port.** No "while I'm here" fixes in V1. V1 is the parity oracle; changing it changes the oracle.
- **Every deferred gap must have an explicit destination** — exactly one of: a target phase number in the row's `notes` (`deferred to phase 10`), an ADR ID (`intentional_break: ADR-NNN`), or `status: parked` + 1-line rationale via `/migration-park`. A gap marked "deferred" with no destination is a floating obligation: the row stays `halted` with `gaps_in != gaps_closed` and the phase gate REFUSES until the user decides (`check_gap_count_parity`; re-checked by the RE-DETECT step in `find-and-fix.md § 3.5`).

## Must not

- **Copy-paste V1 into V2.** Even when V2's architecture looks the same shape — the port is re-derived from the contract, not transposed line-by-line. Copy-paste smuggles V1's hidden invariants (which V2's structure may not satisfy) and reproduces V1's bugs.
- **Skip the contract step.** "V1 is small / I read it once / it's obvious" — every post-cutover regression is preceded by that sentence. The contract takes hours; the regression takes weeks.
- **Skip parity tests because "the unit tests cover it".** V1's unit tests pin what V1's authors *thought* it did. Parity tests pin what V1 *actually* does — production has called V1 with inputs no unit test covers. Use record-replay against anonymised production traffic.
- **Bundle features in one port PR.** "Port the user module" is not one feature — it is `getUser`, `listUsers`, `searchUsers`, `updateUser`. Each gets its own port and its own ledger row.
- **Bundle parity-breaking perf changes into the port PR.** Either it preserves parity (ship in the port PR) or it changes the contract (separate PR + ADR + caller migration plan + deprecation window).
- **Cutover without a rollback path.** A flag that can't be flipped back, a schema change without a reversible migration, a deleted V1 path — each turns a 2-minute incident into a 2-hour one.
- **Leave the ledger stale.** A merged PR that ports a feature without updating `ai/migration/ledger.md` is incomplete. Phase 5 verification halts on ledger drift.
- **Use V2's "future" architecture as a moving target.** Pin V2's architecture before the migration starts. If it must evolve, finish or pause the migration first.
- **Ignore non-functional behaviour.** Latency p95, memory footprint, error rate and log volume are part of the contract. A V2 returning the same JSON 5× slower has not preserved parity.
- **Mix migration with feature work.** "We're porting search and adding fuzzy matching" guarantees both regressions and missed scope. Port to parity, ship cutover, then add the feature on V2.
- **Treat "no test exists for this in V1" as "no behaviour exists".** Read git log, PR descriptions, related issues; run V1 against fuzz inputs. V1's untested behaviour is still observable and still load-bearing for some caller.
- **Port dead V1 code.** Zero callers on all 6 axes (halt 11) means dead. Porting it migrates rot into V2 and inflates V2's surface with code that has no consumer. Dead V1 code is marked `deprecation_reason: dead-v1-no-callers` and excluded from V2 entirely — it gets deleted from V1 at the retirement phase, NOT ported then deleted.

## Should

Slice vertically (not horizontally) · first port = lowest-risk feature · shadow ≥1 week before canary · anchor every perf-uplift to a measurement · index proactively when V2's query shape differs · project columns minimally · replace sequential await loops with bounded parallelism · cap contracts in writing (50-page contract = split the feature) · run parity against the frozen pinned V1 commit. Each of these is a default, not a halt; deviate with a one-line reason in the row's `notes`.

## Anti-patterns (named)

**Zombie Port · Transposition Trap · Bundled Cutover · Stale Oracle · Silent Break · Test-by-Test Port · Eternal Shadow · Buried Perf "Improvement" · V1 Deletion Sprint · Trusted Summary · Hand-waved Query Param · Optimistic Form Field Match · Permission-gate Drop · Guessed Type · Reinvented Wrapper · Silent Catch · Wrong Lifecycle Hook on Nested Child · Misplaced i18n Key · Consumer Compensation · Auto-import Trip.** These names are load-bearing vocabulary — audits cite them. Fingerprints, real-world costs, fixes, and the `validate-migration-artifacts.sh` check that catches each: `ai/patterns/migration-guardrails.md § Named anti-patterns`.

## Load on demand

**Installed with the pack, always reachable** — `ai/patterns/migration-guardrails.md` (tier artifact specs · dead-V1 6-axis check · halts 12-13 full spec · v1_status modes · anti-bloat merge gates · reviewer-approval, mid-port tier promotion and idiom-drift propagation · the 19-box review checklist · the 20 named anti-patterns · the anti-pattern → check-function matrix) · `ai/patterns/{feature-port,parity-testing,migration-ledger}.md` · skills `extract-v1-contract` / `parity-test-generate` / `perf-uplift-survey` / `data-cutover-orchestrate` · agents `migration-architect` / `parity-auditor` · commands `find-and-fix` (default loop) / `port-feature --heavy` / `migration-phase` / `migration-gate`. Validator: `scripts/validate-migration-artifacts.sh`.

**Companion reference file — pack-side only, NOT installed.** `references/migration-discipline-catalogue.md` holds worked examples per concern (parity preservation, scope discipline, the 8-row perf-uplift table, the progressive-cutover timeline), the structure-vs-behaviour worked examples, per-tool dispatch tables, the tier rationale and the long-form Should guidance. Phase 4.2 copies `references/<name>.md` only for a **detected framework name** (`phase-4.2-apply.md:210-213`), so a project does not receive it and nothing above depends on it.
