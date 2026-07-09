---
name: migration-discipline
description: Migration Rule: V1→V2 port discipline
kind: rule
pack: migration
severity: must
applies-to: migration-track, every-code-writing-task-in-migration
---

# Migration Rule: V1→V2 port discipline

## CORE PHILOSOPHY — read this first, internalize, do not deviate

**V1 is the production reference. V1 is sacred truth.** We are in MIGRATION mode, not refactor mode. The whole point of migration is: V1's behaviour, V1's API, V1's permissions, V1's response shapes, V1's error contracts — all of these are the PRODUCTION CONTRACT. Real users use V1 every day. V2's job is to mirror that contract while using V2's structure.

**Implications**:

1. **Do NOT halt to verify V1.** The auditor reads V1 source DIRECTLY and treats whatever it reads as the contract. There is no "verify with the user that V1 actually does this" step — V1 source IS the verification. If V1 source returns `{ id, name, status }`, V2 must return `{ id, name, status }`. No questions. No halts asking "is V1 correct?"
2. **API verification is not a halt condition.** Halts fire for V2-deviation-from-V1 OR artifact-completeness — never for "V1 might be wrong, please confirm." V1 cannot be wrong; V1 is the oracle. If V1 has a bug, it's a documented V1 behaviour we preserve (mark `known_v1_bug` in contract; port-as-is) or a user-decided break (ADR + caller migration).
3. **API samples are HELPFUL, not REQUIRED.** Capturing real V1 responses to `ai/migration/api-samples/` is the ideal — gives V2's types perfect field-name accuracy. But if V1 source is readable and the agent can derive the response shape from V1 code (controllers / serializers / view templates), that is sufficient. Missing api-samples WARN (do not halt) when V1 source is unambiguous.
4. **We are NOT refactoring.** Improvement is out of scope. If V1 has odd query params, V2 has the same odd query params. If V1's permission gate uses `tenants.read`, V2 uses `tenants.read` (not "the cleaner `read.tenants`"). Refactor happens AFTER migration completes, on V2-only, with its own ADR. Mid-migration "while I'm here" improvements are FORBIDDEN.
5. **Halts that DO fire**: V2 deviates from V1 (most common — fix V2 to match V1); cross-repo blocker (V1 backend route shape changed for unrelated reason); contract break user wants to make (ADR required); dead V1 code being ported (skip per dead-V1 rule); artifact missing (contract / parity tests / plan / runbook for the row's tier). These halts are about V2 quality and PROCESS completeness, not V1 verification.

**The "API verification" halt is a misuse.** If audits surface halts asking the user to verify V1's API contract, the audit logic is wrong. V1 source IS the API contract. The auditor reads V1 source line-by-line and produces gap findings against V2 — that's the workflow. There is no V1-side verification phase.

**Project-level anchor for V1 stability** (in `_v2-anchors.md`):
```yaml
v1_status: production-stable      # production-stable | actively-developed | frozen
v1_api_frozen: true               # if true, no API contract changes expected during this migration
v1_reference_commit: <sha>        # the V1 commit pinned as oracle
```

**v1_status modes**: `production-stable` (most common — V1 source is the unambiguous oracle; V1-side verification halts SKIPPED; api-samples WARN not halt) · `actively-developed` (pin `v1_reference_commit`; that commit is the oracle; api-samples remain a hard halt) · `frozen` (no V1-side halts at all). Full mode semantics: `.claude/references/migration-discipline-procedures.md § v1_status modes`.

**TL;DR: in migration mode, V1 is gospel. Don't ask, port.**

> **Project-specific values** — V1 root, V2 root, parity-test location, cutover mechanism, caching primitive, DB query primitive — are auto-injected by `scripts/apply-anchors.sh` during `/setup-project --refresh` into the `<!-- project-specific:start --> ... <!-- project-specific:end -->` block at the bottom of this file. Migration-pack-specific anchors (V1↔V2 paths, parity test root, cutover mechanism) live in `ai/migration/_v2-anchors.md`. Do **not** edit those values here; edit `_v2-anchors.md` and re-run `apply-anchors.sh` (or `/setup-project --refresh`) to propagate.

This rule governs every per-feature port. It exists because the most common migration failure is **subtle behavioural drift** — V2 *almost* matches V1, ships, and a long-tail of customer issues surface over months. The second most common is **scope creep** — the port becomes a redesign, a perf project, and a refactor in one PR, none of which can be safely reviewed. The third most common is **trusted summary** — an executor delegates V1↔V2 comparison to a search/exploration agent, the agent reports "looks identical" in confident summary language, and the executor echoes that into the audit without verifying the claim against source. The canonical real-world incident: a missing UI affordance + a divergent query-param surface both passed audit because the summary said "identical".

**This rule is the universal contract** — it must be enforceable by any AI tool. Tools with full capability (commands + agents + skills + hooks) compose the discipline by dispatching `/port-feature` → `parity-auditor` → `extract-v1-contract` etc. Tools with rules only (Aider, Codex, Gemini) enforce the discipline by reading and following this file directly. Therefore: the complete discipline = THIS file + its two companion reference files (`.claude/references/migration-discipline-procedures.md` + `.claude/references/migration-discipline-catalogue.md`), which hold the verbatim procedural detail (split 2026-06-07 to respect the 40k-char always-on context limit). Every adapter bundle ships all three together; rule-only tools read all three as one discipline. Do not delete the reference files or break the bundle — rule-only tool users have no other surface.

## Required artifacts per feature — tiered floor

Every feature port produces an artifact set scaled to its actual risk. The discipline is **tiered**, not one-size-fits-all: a 1-line bulk-delete URL fix and a 25-file payment-flow rewrite have different audit needs. Tier is set on the ledger row at audit time and propagates through the port.

> **Why tiered**: prior single-floor discipline produced ~95% docs / ~5% code on small features (Phase 7 incident, 2026-04-30). Full rationale: `.claude/references/migration-discipline-procedures.md § Tier rationale`.

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

Merge gates (not suggestions), from the Phase 7 incident (~95% docs / ~5% code): **code edits are the deliverable** · ADRs justify USER-decided breaks only (agent-default closure = edit V2 to match V1) · per-axis enumeration required wherever a gap exists, at every tier (hand-wave grep HALTs on `etc.` / `...` / `N+ items`) · single agent dispatch + shared 5K context blob by default · default-true wrapper props set explicitly when removing UI affordances (F040) · audit verdict = V1-parity, NOT plan-execution · trivial tier produces no contracts/plans/perf-docs/runbooks. Full gate definitions + tier artifact specs: `.claude/references/migration-discipline-procedures.md § Anti-bloat rules`.

## Contract — 9 required sections

The contract at `ai/migration/contracts/<feature>.md` MUST contain all 9 sections — 1. Inputs · 2. Outputs (per code path) · 3. Side effects · 4. Business rules · 5. Invariants · 6. Performance baseline · 7. Caller assumptions · 8. Edge cases · 9. Known V1 bugs — every claim cited `<path:line>`; a contract missing any section is incomplete and the audit halts. Full section-by-section template: `.claude/references/migration-discipline-procedures.md § Contract template`.

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
11. **Dead V1 code in port queue** — the V1 source of this feature has zero callers across all 6 reachability axes (see § "What counts as dead V1 code" below). Halt the port; do NOT migrate dead code into V2. Mark the ledger row `status: deprecated` with `deprecation_reason: dead-v1-no-callers` (no ADR required for this case — dead code is a structural fact, not a user-facing decision). If the user disputes the dead-code finding (e.g., "it's called from a cron job our scanner missed"), they pass `--include-dead` to override AND attach a 1-line `caller_evidence: <path:line>` to the ledger row proving the missed caller.
12. **UI surface audit row missing v1_states / v2_states enumeration** — any audit row whose `v1_path` is a UI file MUST enumerate every interaction state V1 exposes (idle / loading / opened / single-result / empty / error / hover / disabled / each conditional-render branch) as `v1_states: [list]` / `v2_states: [list]` / `gap: any v1_state not in v2_states`. One-line rows ("navigate-to-X", "shows the list") HALT — a stateful V1 affordance vs a one-shot V2 navigation is invisible without state enumeration. Full spec: `.claude/references/migration-discipline-procedures.md § Halts 12-13 — full elaborations`.

13. **Module/page audit missing navigation inventory** — any module / settings-shell / page-with-tabs / multi-nav-target audit MUST produce a Navigation Inventory (Section 0, BEFORE per-axis work): every clickable label/route reachable from the module entry in V1 vs V2, 1:1 mapped. Any V1 nav leaf with no V2 navigation surface is **DRIFT, not STRUCTURE_OK** — burying a V1 tab as a scroll-section inside another V2 tab is drift; splitting/consolidating navigation requires an accepted ADR. The inventory MUST be a TWO-LAYER scan: Layer A (route tree from every router file) + Layer B (per-leaf template grep for in-component tab patterns — MANDATORY); a Layer-A-only scan is incomplete and HALTS. Full two-layer spec + Section 0 completion checklist + tab-pattern vocabulary: `.claude/references/migration-discipline-procedures.md § Halts 12-13 — full elaborations`.

**Output of any halt**: a structured remediation list — specific finding + specific action — written to the audit file. NO advance until each halt is cleared.

## What counts as dead V1 code (the 6-axis check)

A V1 feature is dead — and must NOT be ported — only when **all six** reachability axes return zero callers: 1. app-source callers · 2. test references (downstream, not the feature's own) · 3. cron/scheduler config · 4. route/API registration · 5. infra/deploy config · 6. production telemetry (N/A if unwired). One live axis → port it. Override: `--include-dead` + `caller_evidence: <path:line>`, logged in `_history.md`. Full axis definitions + edge cases (public APIs, library exports, in-development, flag-gated): `.claude/references/migration-discipline-procedures.md § Dead V1 code — 6-axis check`.

## Per-stack extensions (frontend / backend specifics)

The 6 generic axes (Inputs / Outputs / Errors / Auth / Side effects / Performance) are necessary but NOT sufficient — frontend ports add form-field / UI-affordance / query-param / event-handler / per-button-permission / a11y / DOM / lifecycle axes per `frontend/rules/migration-frontend.md`; backend ports add DTO-shape / query-param-surface / envelope / validator-stack / tenant-isolation / transaction-boundary axes per `backend/rules/migration-backend.md`. Detail: `.claude/references/migration-discipline-procedures.md § Per-stack extensions`.

## Tool-agnostic procedure (for tools without skill dispatch)

The canonical procedures — **extract V1 contract** (10 steps), **generate parity tests** (10 steps), **perf-uplift survey** (8 steps per candidate) — are inlined verbatim in `.claude/references/migration-discipline-procedures.md § Procedures`. Tools with skill dispatch use `extract-v1-contract` / `parity-test-generate` / `perf-uplift-survey`; rule-only tools follow the reference file (shipped alongside this rule in every adapter bundle).

## Must

- **Inventory navigation before per-axis** (added 2026-05-02). For any audit whose scope is a module, settings shell, page-with-tabs, or any UI surface exposing more than one user-clickable navigation target, build a Navigation Inventory FIRST — list every clickable label/route reachable from the V1 module entry, list the same for V2, produce a 1:1 mapping. The inventory is the audit's Section 0 and appears before form-field / UI-affordance / event-handler enumeration. **Why**: per-axis enumeration on the wrong tab set produces high-confidence "STRUCTURE_OK" verdicts that miss whole tabs V2 dropped. The user-clickable click-path to reach a feature IS observable behaviour — not structure — and source-only audits cannot detect it without explicit nav-tree comparison. Burying a V1 sub-tab as a section in another V2 tab is drift, not consolidation. Per-stack packs MUST add stack-specific tab-discovery patterns (e.g., framework-specific tab components, sidebar config files, in-page tab arrays) so the inventory is mechanically reproducible.
- **Inventory V2 before reading V1** (added 2026-05-01). Before extracting the V1 contract, scan V2's shared inventory — every wrapper, every shared util / hook / composable, every design token, every base class — at the paths declared in the project's `_extracted-codebase.md § Gold standards` and `_extracted-idioms.md`. Produce `ai/migration/mapping/<feature>.md`: a 2-column "V1 X → V2 Y" table naming the V2 equivalent for each V1 surface. Skipping this is the #1 cause of the Transposition Trap. Required at every tier; `check_v2_mapping_doc` halts the gate without it.
- **Reuse-Before-Create** (added 2026-05-01). Before authoring any component, hook / composable, util, type, style, or markup pattern, search the project's shared inventory. If it exists → reuse. If it partially exists → extend the shared one (don't fork). Authoring a duplicate is a migration failure, not a stylistic choice. The specific shared entries to check are project-specific (see `_extracted-idioms.md`); the validator's `check_v2_structure` is stack-conditional and reads its fingerprint list from the project's PROJECT_KIND anchor. PRs that introduce a new V1-pattern fingerprint must add a corresponding detector to the script.
- **Read V1 before writing V2.** Produce `ai/migration/contracts/<feature>.md` with all 9 sections per the procedure above. The contract is the spec V2 must satisfy.
- **Capture real API responses to derive types from** (added 2026-05-01; softened 2026-05-02). For any port that touches the project's service / data-access layer, prefer storing at least one captured response per endpoint under `ai/migration/api-samples/<feature>/<endpoint>.json`. The V2 type's field names + nullability + nested shape are best derived from this sample. The Guessed Type anti-pattern (a typed DTO that doesn't match the actual response field names) ships empty UIs that look like "API returned nothing" rather than "type mismatch". **However**: when `v1_status: production-stable` is set in `_v2-anchors.md` (V1 in maintenance-only mode), the V2 type can be derived from V1 source directly (controllers, serializers, view templates) — the api-sample is no longer required to halt the gate. The validator's `check_api_response_sample` becomes a WARNING instead of a halt in this mode. For projects with `v1_status: actively-developed`, the api-sample remains a hard halt because V1 may have shipped contract changes since the agent last read source.
- **Generate parity tests before V2 code.** Follow the parity-test procedure above. Tests run V1 + V2 against identical inputs and assert equivalence per the tolerance taxonomy (exact / structural / numeric tolerance / order-insensitive / timestamp-insensitive / dom-equivalent). Red baseline before V2 is fine — green is required before cutover. Corpus has ≥30 inputs OR a record-replay setup; tolerance.yaml exists; every contract output field has a tolerance entry.
- **One feature per port PR.** Atomic unit = one feature in the migration ledger. Multi-feature PRs hide regressions and make rollback ambiguous.
- **Update the ledger on every state transition.** `V1-only → In-progress → V2-shadow → V2-canary → V2-only → V1-deleted`. The ledger is the source of truth — code grep is not.
- **Cutover is gated.** Move from V2-canary → V2-only only when: (1) parity tests green, (2) shadow / canary metrics show no regression on error rate / latency / business KPIs for the agreed observation window, (3) the relevant ADR (if any) is merged, (4) rollback path tested.
- **A cross-store data port uses a resumable checkpointed backfill + reconciliation, and read-cutover is gated on backfill-complete + reconciliation-green** (added 2026-07-09). When V2 keeps the feature's data in a *different* store than V1 (different engine, schema, or owning service), the data itself must be ported — not just the code. The backfill MUST be resumable and checkpointed (key-range batches, a durable cursor, idempotent upserts — never one unbounded `SELECT * → write` pass), it MUST apply the V1→V2 field mapping (`ai/migration/mapping/<feature>.md`) through the *same* shared mapper the dual-write path uses, and a cross-store reconciliation (per-range counts + checksum/sample-diff) MUST prove the stores agree before any read flips. The read-cutover flag opens ONLY when the checkpoint is complete (cursor past the max key) AND reconciliation is green (divergence ≤ the declared threshold); a flag that opens on "backfill exited 0" is the primary failure mode. Follow `data-cutover-orchestrate.md` — its readiness verdict (default `BLOCK`) is the evidence the cutover gate consults. **Boundary**: this owns the *cross-store* seam only — `parity-test-generate` COMPARES V1/V2 *outputs* (it never moves a row) and `database/`'s `migrations` owns *single-store* schema evolution in place (expand-contract, online DDL). If there is one store, this rule does not apply — hand off to `database/migrations`.
- **Delete V1 only when last reference is gone.** Use `git grep` + dead-code analyser + telemetry "no traffic in N days" before deletion. The ledger transition `V2-only → V1-deleted` requires evidence attached.
- **Structure → V2 wins; observable behaviour → V1 wins** (added 2026-05-01; clarified 2026-05-05). This resolves the apparent conflict between "Use V2's primitives" and "Default to V1-parity". They apply on **different axes** — never substitute one for the other.

    **Decision checklist — ask in order, stop at first YES:**
    1. Would a *user* (or *caller / API consumer*) notice the difference if we changed it? → **BEHAVIOUR axis → V1 wins.**
    2. Is it about *where code lives*, *which shared primitive renders it*, *which layer owns it*, or *what file it sits in*? → **STRUCTURE axis → V2 wins.**
    3. Still ambiguous? Default to **BEHAVIOUR (V1 wins)** and surface to user — under-changing structure is recoverable; under-preserving behaviour ships a regression.

    **Axis lookup table:**

    | Axis | Belongs to | V1 wins (behaviour) | V2 wins (structure) |
    |---|---|---|---|
    | Inputs accepted (form fields, query params, headers, body shape) | behaviour | ✓ port every V1 input | — |
    | Outputs returned (response shape, field names, nullability, status codes) | behaviour | ✓ match V1 exactly | — |
    | Error contracts (error shape, error codes, when each fires) | behaviour | ✓ match V1 | — |
    | Side effects (DB writes, queue publishes, external HTTP, log fields) | behaviour | ✓ preserve | — |
    | Events fired / emitted | behaviour | ✓ preserve names + payloads | — |
    | Permission gates (which user roles see / can do what) | behaviour | ✓ match V1 gate set | — |
    | Navigation paths (clickable routes, tab labels reachable) | behaviour | ✓ user-clickable surface = V1 | — |
    | UI affordances (buttons present, default-true wrapper props) | behaviour | ✓ same affordances visible | — |
    | Copy / labels / i18n keys (visible text users read) | behaviour | ✓ V1 copy unless ADR | — |
    | Performance characteristics (latency p95, error rate ceiling) | behaviour | ✓ V1 baseline or better | — |
    | File layout / directory structure | structure | — | ✓ V2's convention |
    | Layering (controller / service / repo split) | structure | — | ✓ V2's layers |
    | Shared wrappers / utils / hooks chosen | structure | — | ✓ V2's gold-standard inventory |
    | Routing / state-management / DI primitive | structure | — | ✓ V2's primitive |
    | Naming conventions (file names, symbol names, casing) | structure | — | ✓ V2's conventions |
    | Type / DTO authoring style (where types live, how they're shaped) | structure | — | ✓ V2's pattern (field NAMES still come from V1's response — that's behaviour) |
    | Lifecycle hooks / mount semantics | structure | — | ✓ V2's framework idioms |
    | Error-handling primitive (which error handler is called) | structure | — | ✓ V2's project handler (the FACT that errors surface = behaviour; HOW = structure) |

    **Worked examples + named failure modes** (Transposition Trap / Silent Break / "I made it cleaner") for this rule: `.claude/references/migration-discipline-catalogue.md § Structure-vs-behaviour worked examples`.
- **Default to V1-parity, ADR is opt-in (BEHAVIOURAL axis).** When audit finds V2's *behaviour* deviates (extra button, missing field, flipped default), the **default action is to remove V2's deviation** to match V1. An ADR is required ONLY when the user explicitly chooses to keep V2's behaviour (or V1 is a security / privacy / legal regression). The architect/port agent MUST NOT silently draft an ADR to legitimize V2 deviations — that pattern (observed in a real-world Phase 7 incident: ~6 ADRs drafted to preserve V2 over V1) inflates documentation while leaving the user-visible parity gap unfixed. Surface the divergence to the user, offer "match V1 / keep V2 + ADR / deprecate-V1-feature + ADR", wait for explicit choice. **This rule applies to BEHAVIOUR ONLY, not structure** — see the rule above.
- **No frontend compensation for backend gaps.** If V2's API is missing a field, returning a wrong shape, or behaving differently than V1's API, the fix is a backend ticket — not a UI workaround. Workarounds (mapping `c.name` to `c.label` in the component, hardcoding a missing field, sending a fake parameter) drift the contract silently and re-surface as bugs in every other consumer. File the API ticket; if the port is blocked waiting, mark the feature `status: halted` with an explicit dependency, do not ship a UI patch.
- **No silent catches** (added 2026-05-01). A `catch { /* fail silent */ }` or empty `catch {}` swallow makes failures indistinguishable from empty success states — empty lists, missing widgets, no error indicator. Every catch in port code must either (a) call the project's error handler (named in `_extracted-idioms.md`) or (b) include a one-line comment explaining why this specific failure mode is recoverable AND log at debug level. The validator's `check_v2_structure` flags both patterns. The user reports "looks empty" rather than "is erroring", and the bug hides for weeks.
- **When an ADR IS warranted**, document the intentional behaviour break in `ai/decisions/<NNN>-<feature>-v2-break.md` with: V1 behaviour, V2 behaviour, why the break is necessary (user decision rationale), who's affected, migration path for callers, deprecation timeline.
- **ADRs for V1↔V2 divergence require `user_decision_quote:`.** Every ADR file at `ai/decisions/*-v2-break.md` (or any ADR closing a divergence finding) MUST contain a `user_decision_quote:` field with a verbatim quote from the user explicitly choosing keep-V2. If no such quote exists, the ADR is invalid and the default closure verb reverts to "edit V2 to match V1" — a code change. **Why**: this blocks the agent-default-closure anti-pattern where an agent ratifies its own V2 deviation by drafting an ADR without ever asking the user. The "Default to V1-parity, ADR is opt-in" rule above states the principle; this rule operationalises it. Validator: `check_adr_user_decision_quote` greps each `*-v2-break.md` file for a non-empty `user_decision_quote:` line; missing → halt the gate. Acceptable shape: `user_decision_quote: "I prefer the new dropdown" — user, 2026-04-01 chat`. The quote must be specific to the divergence, not a general "keep V2 looking good".
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

Slice vertically (not horizontally) · first port = lowest-risk feature · shadow ≥1 week before canary · anchor every perf-uplift to a measurement · index proactively when V2's query shape differs · project columns minimally · replace sequential await loops with bounded parallelism · cap contracts in writing (50-page contract = split the feature) · run parity against the frozen pinned V1 commit. Full guidance with rationale: `.claude/references/migration-discipline-procedures.md § Should — full guidance`.

## Examples per concern

Worked examples — parity preservation (null-return vs throw; column projection), scope discipline (atomic PRs), the migration-time perf-uplift table (8 V1 anti-pattern → V2 uplift rows), progressive-cutover timeline — live in `.claude/references/migration-discipline-catalogue.md § Examples per concern`.

## Review checklist · Reviewer approval · Tier promotion · Idiom drift

The four operational protocols — per-PR review checklist (19 boxes), heavy-tier reviewer-approval mechanism (`reviewer_approval:` field + halt behaviour + timeout), mid-port tier promotion (`/migration-promote-tier`), idiom-drift propagation (oracle-hash comparison + `--include-drifted`) — are in `.claude/references/migration-discipline-procedures.md § Operational protocols`. Load when reviewing a port PR, approving a heavy row, re-tiering mid-port, or after oracle edits.

## Enforcement

Phase 5 audit, `/migration-status` SLA flags, `parity-auditor` PR hard-fails, Phase 4.6 anchoring, and the validator-script mapping (each named anti-pattern → its `validate-migration-artifacts.sh` check function) are specified in `.claude/references/migration-discipline-procedures.md § Enforcement matrix`.

## Anti-patterns (named)

The full named catalogue — **Zombie Port · Transposition Trap · Bundled Cutover · Stale Oracle · Silent Break · Test-by-Test Port · Eternal Shadow · Buried Perf "Improvement" · V1 Deletion Sprint · Trusted Summary · Hand-waved Query Param · Optimistic Form Field Match · Permission-gate Drop · Guessed Type · Reinvented Wrapper · Silent Catch · Wrong Lifecycle Hook on Nested Child · Misplaced i18n Key · Consumer Compensation** — with fingerprints, real-world costs, and fixes is in `.claude/references/migration-discipline-catalogue.md § Anti-patterns`. The names above are load-bearing vocabulary; audits cite them; the catalogue holds the definitions.

## References

These references are **convenience pointers for AI tools that support them**. The rule itself is self-sufficient — every procedure is inlined above. If your tool doesn't expose these as commands/agents/skills, follow the inlined procedures.

**Companion reference files (ship with this rule in every adapter bundle):**
- `.claude/references/migration-discipline-procedures.md` — tier artifact specs, contract template, halts 12-13 full spec, dead-V1 6-axis check, the 3 inlined procedures, operational protocols, enforcement matrix.
- `.claude/references/migration-discipline-catalogue.md` — worked examples, anti-pattern catalogue, per-tool dispatch tables, pattern/cross-pack pointers.

**Key dispatch surfaces**: skills `extract-v1-contract` / `parity-test-generate` / `perf-uplift-survey`; agents `migration-architect` / `parity-auditor`; commands `find-and-fix` (default loop) / `port-feature --heavy` / `migration-phase` / `migration-gate`. Patterns: `ai/patterns/{feature-port,parity-testing,migration-ledger}.md`. Validator: `scripts/validate-migration-artifacts.sh`. Rule-only tools: this rule + the two reference files together are the complete discipline.
