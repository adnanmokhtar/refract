# Migration toolchain failure surface

> Catalog of every failure mode the V1→V2 migration toolchain can produce.
> Generated: 2026-04-29 · coverage refreshed 2026-10-18 (§ Coverage refresh below; the per-mode "Current coverage" lines that had gone stale are updated in place)
> Scope: `templates/packs/migration/` (Refract repo) + `validate-migration-artifacts.sh` + Phase-6/7/9 incident audits.
> Method: read every command, agent, skill, rule, the validator script, and the per-phase incident audits line by line. Anti-pattern catalog cross-referenced against `migration-discipline.md § Anti-patterns (named)`.
>
> ## ⚠️ READ THIS FIRST — file scope + portability
>
> This catalog is **illustrative**, not prescriptive. The 38 failure modes here are universal patterns; the parenthetical `Where it bit us` provenance lines cite real incidents from the catalog's seed project (the <your-org> family: `<frontend-v2>` frontend / `<backend-v2>` backend / `<backend-v1>` V1) for traceability — those are the audits the catalog was built from. They are NOT claims about YOUR project.
>
> **For your migration**:
> 1. Read each failure mode + its **Suggested mechanism** (stack-agnostic).
> 2. Substitute your project's stack identifiers in the suggestions.
> 3. Track YOUR project's incidents under `ai/migration/incidents/` (the failure catalog) — do not edit this template file with your incidents; pin your history in `ai/`.
> 4. The seed-project provenance can be deleted from your local copy if you prefer a fully-generic catalog: search `Where it bit us:` and remove or replace those lines.
>
> The validator's check IDs (F0xx) and the failure-mode taxonomy ARE meant to be portable — they're abstract patterns, not project-specific bugs.

---

## Summary

- **Failure modes catalogued: 56** (A1–A10, B1–B10, C1–C10, D1–D9, E1–E5, F1–F7, G1–G5; the "38" this line used to carry predates categories E–G).
- **HALT-able today (a validator or agent gate fails the row): 21.**
- **Partial today (`log_warn`, a heuristic, a count, or a check that runs only under an anchor): 17.**
- **Spec-only or reviewer-only: 8. No check at all: 10.** Each of these 18 names the detector § that now covers it or says "out of scope" in the table below.

The 2026-04 summary said the toolchain was weakest on **post-merge drift**, **service-layer parity** and **cross-stack contract sync**. The first is now checked (`check_audit_freshness`). The second is where it is still weakest: every runnable comparison of V1 against V2 code is a per-file regex COUNT, except the keyed lanes `check_inventory_primitives_match` reads when `pair-inventory.py` has extracted both sides. The six parity detectors below (shipped, run together by `/compare-v1`) are the paired, keyed answer.

## Coverage refresh — 2026-10-18

Detector § ids are the shipped migration-pack skills, each § a `### N.` heading in its `SKILL.md` unless marked routed; all six run by `/compare-v1` and closed by `/find-and-fix --from-audit`: **SP** `surface-parity-scan` §1–§9 · **SM** `semantics-parity-scan` §1, §2, §4–§8 (§3, §9, §10 are routed lines to backend, frontend and database) · **SE** `side-effect-parity-scan` §1–§5 · **DC** `data-cutover-orchestrate` §1–§12 · **CR** `cutover-routing-scan` §1–§4 · **PF** `parity-proof-scan` §1–§5. "Process gate" means the mode is about the audit artifact, not about code, and stays with the validator and `parity-auditor`. "Out of scope" names the owner when one exists.

| Mode | Today | Detector § (shipped) |
|---|---|---|
| A1 Trusted Summary | ✅ `check_audit_provenance` | process gate (`parity-auditor` judges detector rows) |
| A2 Hand-waved enumeration | ✅ `check_audit` hand-wave bank | process gate |
| A3 Inline-executor verdict | ✅ `check_audit_provenance` placeholders | process gate |
| A4 Stale audit | ✅ `check_audit_freshness` (7-day SLA vs the v2_path commit) | — |
| A5 Porter = auditor | ⚠️ `check_porter_vs_auditor` (fails on a collision; silent when `porter_agent_id` is absent) | process gate |
| A6 Tolerance loosened | ✅ `check_tolerance_loosening_adr_evidence` — committed since the base and uncommitted; a loosening with no ADR fails | PF §5 (CO-4, V385) |
| A7 Parity-clean with no tests | ✅ `check_parity_corpus` + `check_parity_run_report` | PF §1, PF §4 (a skipped V1-gated suite is NOT-RUN) |
| A8 Citation spoofing | ⚠️ `check_contract_citations` (path and line exist; content unchecked) | paired-inventory rows carry `file:line` + excerpt for the contract prefill; content alignment otherwise out of scope |
| A9 Intentional break without ADR | ✅ `check_intentional_break_adr` | PF §3 (PP-3) |
| A10 PASS with caveats | ✅ `check_audit_body_consistency` | — |
| B1 Transposition Trap | ✅ `check_v2_structure` (frontend and TS-backend sets; N/A for other kinds) | out of scope (V2 structure, not parity) |
| B2 Composable reuse miss | ⚠️ `check_composable_reuse` (Vue heuristic, warn) | out of scope (V2 structure) |
| B3 Service shape miss | ⚠️ `check_service_shape` (heuristic, warn) | out of scope (V2 structure) |
| B4 Layering violation | ✅ layering fingerprints in `check_v2_structure` | out of scope → architecture / code-quality |
| B5 Cross-module import | ⚠️ `check_cross_module_import` (warn) | out of scope (V2 structure) |
| B6 i18n key missing | ⚠️ `check_i18n_locale_parity` (V2 locales only, warn) | SM §9 → frontend `i18n-scan` (MG-I18N-1) |
| B7 Hexagonal boundary | ⚠️ TS-backend fingerprints only | out of scope → architecture |
| B8 Transaction script | ❌ | out of scope → architecture; the transaction half is SM §10 → database |
| B9 Response-mapper drift | ⚠️ keyed I-RULES / I-ROUTES lanes when both sides were extracted | SP §6–§9; envelope correctness → backend |
| B10 Per-route auth mismatch | ⚠️ keyed I-AUTHZ lane in `check_inventory_primitives_match` (both sides extracted); `auth_guard` counts otherwise | SP §3, §4, §5 (security owns widening and tenant scope when installed) |
| C1 Missing UI affordance | ✅ `check_section_0_evidence`, `check_per_axis_enumeration` | MG-UI-1 (parity-auditor, unchanged) |
| C2 Permission-gate divergence | ✅ `check_permission_gate_divergence` (frontend axes table) | SP §3, §4 for server routes |
| C3 Templated query param drop | ✅ hand-wave regex; enumeration soft | SP §2 (MG-RT-2, V358) |
| C4 Side-effect drop | ⚠️ `event_emit` count — blind to observers and traits | SE §1 (MG-SE-1, V371); DB triggers SE §5 |
| C5 Empty-state drop | ⚠️ corpus + tolerance (`structural` never hides presence) | SM §7 (MG-NULL-1, V367) |
| C6 Lifecycle mismatch | ⚠️ `check_lifecycle_keepalive` (Vue KeepAlive, anchor-gated, warn) | MG-UI-2 (halt 12); frontend `ui-state-scan` single-codebase |
| C7 Loading / error state drop | ❌ | MG-UI-2 (halt 12 state enumeration) |
| C8 RTL break | ⚠️ spec-only | out of scope → frontend |
| C9 Visual divergence | ❌ | out of scope → frontend visual regression |
| C10 Locale semantic shift | ❌ | SM §8 (time zone, V368); SM §9 → frontend i18n (V369) |
| D1 Corpus all-happy-path | ⚠️ `check_corpus_distribution` (buckets, warn) | PF §2 (V387 — V1 branch floor, not a file count) |
| D2 Tolerance coverage | ⚠️ `check_tolerance_coverage` (warn) | PF §5 |
| D3 Loosened with a red test | as A6 | PF §5 |
| D4 Pin ≠ run commit | ✅ `check_parity_run_v1_commit` + `check_parity_run_report` | PF §1 |
| D5 Mocked V1 dependency | ❌ | PF §5 in part (journal against real fakes, V371); otherwise reviewer |
| D6 Generators off prod shape | ❌ | PF §2 (V387 lists unreached V1 branches) |
| D7 Snapshot drift | ⚠️ repo-baseline `test-integrity.py` `undeclared-baseline-rewrite` when installed | PF §1 (PP-1, V386) |
| D8 KeepAlive mount missing | ❌ | out of scope (frontend test config; `parity-test-generate` route-cache-aware mount) |
| D9 Auto-import mismatch | ❌ | out of scope (frontend test config; `parity-test-generate` auto-import requirement) |
| E1 a11y attribute dropped | ⚠️ spec-only | out of scope → frontend a11y |
| E2–E5 Token storage, manual auth header, `axios.create`, `console.log` | ✅ `check_v2_structure` fingerprints | out of scope (V2 structure) |
| F1 Ledger drift | ✅ `check_ledger_row` (tier-scoped fields) | process gate |
| F2 Scope creep | ⚠️ `check_port_diff_scope_warning` (warn) | process gate |
| F3 V1 modified in port PR | ⚠️ halt 6, reviewer | PF §1 for V1-pinned tests; V1 source edits stay with the reviewer |
| F4 Cutover without rollback | ✅ `check_runbook` (heavy tier) | DC §11 (reverse path, point of no return), CR §4 |
| F5 Eternal Shadow | ⚠️ `migration-status` age flag | out of scope (status report) |
| F6 V1 Deletion Sprint | ⚠️ spec-only | CR §4 (V1 cold before soak end), DC §11 |
| F7 Architecture in flux | ⚠️ spec-only | out of scope |
| G1 API contract change breaks frontends | ⚠️ spec-only | SP §1–§9 run per consumer; workspace sync out of scope |
| G2 Workspace orchestrator stale | ❌ | out of scope (workspace) |
| G3 Sibling drift | ⚠️ spec-only | out of scope (workspace) |
| G4 Shared component not in siblings | ❌ | out of scope (workspace) |
| G5 Cross-stack ledger desync | ⚠️ spec-only | out of scope (`migration-doctor.sh` dependency resolution) |

---

## Category A: Audit-time failures (the audit doc lies)

The audit is the gate. If the audit is wrong, every downstream check is wrong. These are the failures we hit hardest in F039 + Phase 6 and the area most reinforced after this session.

### A1. Trusted Summary
- **What**: Auditor reads prior audit doc / "Fully Migrated" label / search-agent summary, echoes "parity-clean" without reading V1 source line by line.
- **Stack**: Both frontend + backend.
- **Where it bit us**: F039 (missing Add-mapping button); Phase-6 first pass on F030/F032/F033 — all four declared parity-clean before the user pushed back.
- **Current coverage**: ✅ HALT — `validate-migration-artifacts.sh § check_audit_provenance` (refuses audits whose `auditor_agent_id` frontmatter is missing/empty/placeholder); `migration-phase.md § 4b` mandates `Agent({subagent_type:"parity-auditor"})` dispatch.
- **Severity**: P0.

### A2. Hand-waved enumeration
- **What**: Audit table cells read "20+ filters", "etc.", "and so on", "&...", "deferred to port-phase parity author", "by audit-by-inspection" instead of explicit per-row enumeration.
- **Stack**: Frontend (mostly); backend equivalents are "all CRUD endpoints similar".
- **Where it bit us**: F039 query-param surface; Phase-6 F030/F031/F032/F033 first pass (caught after promoting `log_warn` → `log_fail`).
- **Current coverage**: ✅ HALT — `validate-migration-artifacts.sh § check_audit` regex bank: `\&\.\.\.|"etc\.|, etc\.| etc\.\)|\.\.\.[[:space:]]*\||\b[0-9]+\+\s+(filters?|buttons?|fields?|params?|columns?)\b|\band so on\b|\bdeferred to (port-phase|future) parity\b|\bby audit-by-inspection\b`.
- **Severity**: P0.

### A3. Inline-executor verdict
- **What**: Executor opens the audit file in their own context (no Agent dispatch), reads V1 + V2 themselves, writes "parity-clean". The sustained-attention failure mode of A1 reflowed: it isn't echoing a summary, but the executor's confidence outruns their reading.
- **Stack**: Both.
- **Where it bit us**: Phase-6 first pass — all 4 audits produced inline; user pushback triggered the `parity-auditor` re-dispatch.
- **Current coverage**: ✅ HALT — `check_audit_provenance` rejects placeholder values (`TODO`, `pending`, `inline`, `executor`, `unknown`, `<...>`). `migration-phase.md § 4b` makes Agent dispatch the only acceptable mechanism.
- **Severity**: P0.

### A4. Stale audit (oracle drift since gate)
- **What**: Audit was written N days ago against V2 commit X. Since then V2 evolved; tolerance.yaml or implementation diverged; the gate still consumes the stale audit verdict. The Eternal Shadow's audit-side cousin.
- **Stack**: Both.
- **Where it bit us**: Projected — not yet observed. F033's "ai/status.md is stale" is a sibling drift; same shape.
- **Current coverage**: ✅ HALT — `check_audit_freshness`: `audit_date` older than the last commit on the row's `v2_path` by more than 7 days fails the row.
- **Severity if uncovered**: P1.
- **Suggested mechanism**: `validate-migration-artifacts.sh § check_audit_freshness` — if `audit_date` is older than `git log -1 <v2_path>`, log_fail "audit predates V2 changes; re-audit required". 7-day SLA.

### A5. Audit author = port author (no second-eyes)
- **What**: Same agent run / same person produces both the port and the audit. The auditor's bias matches the porter's blind spots — same omissions in both.
- **Stack**: Both.
- **Where it bit us**: Projected — `parity-auditor.md § Pitfalls "Auditor + author conflict of interest"` warns but isn't enforced.
- **Current coverage**: ⚠️ Partial — `check_porter_vs_auditor` fails when the ledger's `porter_agent_id` equals the audit's `auditor_agent_id`; silent while `porter_agent_id` is unset.
- **Severity**: P1.
- **Suggested mechanism**: Audit frontmatter requires `auditor_agent_id` ≠ `porter_agent_id` (add `porter_agent_id` to ledger row). Validator halts on equality.

### A6. Tolerance loosened to make red green
- **What**: Parity test fails, executor edits `tolerance.yaml` to make it pass (adds field to `ignore`, raises `numeric_tolerance`).
- **Stack**: Both.
- **Where it bit us**: Projected — `parity-auditor.md § Pitfalls "Loosening tolerance during audit"` and `parity-test-generate.md § Failure modes "Tolerance creep"` warn but no mechanical check.
- **Current coverage**: ✅ HALT — `check_tolerance_loosening_adr_evidence` reads tolerance.* changes in `<base>..HEAD` and the working tree; a loosening-shaped change (an added `ignore` / `structural` / numeric tolerance) with no ADR in the audit fails. (It read only uncommitted edits, and only warned, until 2026-10.)
- **Severity**: P0.
- **Suggested mechanism**: `validate-migration-artifacts.sh § check_tolerance_diff` — if PR diff includes `tolerance.yaml` changes, refuse unless ADR cited in PR body. Pre-commit hook flag.

### A7. Audit declares "parity-clean" with zero parity tests
- **What**: Audit's classification = `parity-clean` but `tests/parity/<feature>/` doesn't exist or has 0 corpus inputs. The verdict is unsupported.
- **Stack**: Both.
- **Where it bit us**: Phase-6 audits ALL had this shape — "Parity tests: 0 exist per repo state" appears in F030/F032/F033 relook artifacts. Initial verdicts were "parity-clean" without supporting tests.
- **Current coverage**: ✅ HALT — `check_parity_corpus` enforces ≥30 corpus OR record-replay; `check_audit` requires "Decision recommended" section.
- **Severity**: P0.
- **Note**: Coverage exists but separately — the validator does NOT cross-check that classification ≠ "parity-clean" when corpus = 0. Tighten by linking the two checks.

### A8. Citation spoofing
- **What**: Audit cites `<path:line>` that resolves but its content does NOT match the claim. (E.g., audit says "V1 line 1403 has warehouse filter"; line 1403 actually has unrelated code.)
- **Stack**: Both.
- **Where it bit us**: Projected — F030 relook caught this implicitly by re-reading; no automated detection.
- **Current coverage**: ⚠️ Partial — `check_contract_citations` verifies path + line range (file exists, line ≤ wc -l). It does NOT verify content alignment.
- **Severity**: P1.
- **Suggested mechanism**: Audit-author agent must include a 1-line excerpt next to each citation: `<path:line>: "<first 60 chars of that line>"`. Validator regex-matches the excerpt against the actual file content. Citation spoof fails.

### A9. Audit silently classifies as "intentional-break" without ADR
- **What**: Audit decides V2's divergence is "intentional", lists no ADR, no caller-migration plan, no deprecation timeline. It's a contract break dressed as a port.
- **Stack**: Both.
- **Where it bit us**: F033 G2 (V2 added `orders.print` permission gate V1 didn't have) — flagged P2 in re-look but the original Phase-6 audit didn't flag it as a contract break at all.
- **Current coverage**: ✅ HALT — `check_intentional_break_adr`: an "intentional-break" classification needs an `ADR-NNN` that resolves.
- **Severity**: P0.
- **Suggested mechanism**: Validator parses the "Classification" line; if it contains "intentional-break", require a populated ADR-NNNN reference that resolves under `ai/decisions/`.

### A10. The "PASS with caveats" verdict
- **What**: Audit produces "Result: PASS" but the body lists open P0/P1 gaps. Reviewer reads only the header.
- **Stack**: Both.
- **Where it bit us**: F033 relook (`Result: PASS (with P2 gap on summary card fields, P3 gaps on delete affordance and filterWithSeller param)`) — the header says PASS but the body declares G1 P1 (delete affordance missing).
- **Current coverage**: ✅ HALT — `check_audit_body_consistency`: a PASS / parity-clean verdict over a body that lists open P0 / P1 / HALT / missing gaps fails.
- **Severity**: P1.
- **Suggested mechanism**: Validator parses the audit body for any line matching `^(- |\| ).*\b(P0|P1|HALT|missing|regression)\b` after the "Result:" header. If found AND header says PASS, log_fail "audit header contradicts body". Force the auditor to either downgrade the header or close the gap.

---

## Category B: Port-implementation failures (V2 code wrong shape)

The port is "done" but V2's code violates V2's own conventions. The audit may pass at the contract level while the implementation rots.

### B1. Transposition Trap — frontend grid + components
- **What**: V2 file copy-pastes V1's `<div class="col-md-6"><FormField>` wrappers, `<Dialog>`, `<Paginator>`, hand-rolled phone field, etc. — instead of using V2's shared component wrappers.
- **Stack**: Frontend.
- **Where it bit us**: F032 OrderEditDialog port — copy-pasted V1 `MissingOrderVerification.vue`'s grid + hand-rolled phone-row, fixed in second pass.
- **Current coverage**: ✅ HALT — `check_v2_structure` fingerprint bank: raw `<Dialog>`, `<Paginator>`, `<Calendar>`, `<form @submit>`, `col-md-* > FormField`, `phone-row`, `localStorage *token*`, `axios.create(`, inline `style="..."`, `console.log/debug`, manual `Authorization: Bearer`, `:label="$t(...)"` on `<FormField>` / `<TranslatedInput>`.
- **Severity**: P1 (visible UI breakage; not a silent data break).

### B2. Composable reuse miss (page reinvents `useCrud` / `useForm` / `useGeoCascade`)
- **What**: V2 page hand-rolls list/pagination/filter state instead of using shared composables. Becomes untestable, drifts from sibling pages.
- **Stack**: Frontend.
- **Where it bit us**: Projected — not directly observed in Phase 6. F032 OrderEditDialog initial port had ad-hoc form state instead of `useForm`; second pass aligned.
- **Current coverage**: ⚠️ Warn — `check_composable_reuse` (Vue `*Page.vue` list-state heuristic).
- **Severity**: P1.
- **Suggested mechanism**: `check_v2_structure` extension — for any V2 page in `src/modules/<m>/pages/*.vue`, grep for `reactive\(\{[\s\S]{0,500}items:\s*\[\]` (open-coded list state) WITHOUT a corresponding `useCrud(` import. log_warn ("did you mean useCrud?").

### B3. Service shape miss (custom HTTP instead of `BaseCrudService`)
- **What**: V2 `services/index.ts` defines hand-written `apiClient.get/.post/.put/.delete` instead of `new BaseCrudService<T, CreateDto, UpdateDto>(urls)`. Loses the auto-detect-FormData, getMinimal, deleteMany, toggleStatus, export methods.
- **Stack**: Frontend.
- **Where it bit us**: Projected — not in Phase 6, but is a known anti-pattern in `.claude/rules/services.md`.
- **Current coverage**: ⚠️ Warn — `check_service_shape` (hand-rolled CRUD service heuristic).
- **Severity**: P2 (works, but misses convention).
- **Suggested mechanism**: validator scans `src/modules/<m>/services/index.ts`; if file declares any HTTP method directly without an accompanying `BaseCrudService` instance for the same URL group, log_warn.

### B4. Layering violation (component imports service / composable imports component)
- **What**: V2 `.vue` page imports `apiClient` directly, or composable imports a component, breaking the 4-layer dependency direction.
- **Stack**: Frontend.
- **Where it bit us**: Projected — `.claude/rules/clean-architecture.md` warns; F032 dialog port had this risk during refactor.
- **Current coverage**: ⚠️ Soft — ESLint rules + `code-quality` agent catch some; `check_v2_structure` flags `axios.create(` but not generic `apiClient.get` in `.vue`.
- **Severity**: P1.
- **Suggested mechanism**: `check_v2_structure` add `apiClient\.(get|post|put|delete|patch)\(` in `.vue` files → log_fail.

### B5. Cross-module import (V2 module A imports from V2 module B)
- **What**: `src/modules/orders/pages/X.vue` imports from `src/modules/inventory/...`. Violates `.claude/rules/clean-architecture.md § Cross-Module Rules`.
- **Stack**: Frontend.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Warn — `check_cross_module_import`.
- **Severity**: P2.
- **Suggested mechanism**: `check_v2_structure` add `from '@/modules/(?!\$THIS_MODULE)` regex (project-anchored).

### B6. i18n key collision / missing in one locale
- **What**: V2 adds key to `en.ts` but not `ar.ts`, or two modules define the same key path.
- **Stack**: Frontend.
- **Where it bit us**: F032 OrderEditDialog — initial port added en keys before ar keys; caught in same commit. The i18n key `Orders.editOrder` already existed in `ar.ts:74` un-referenced (pre-existing dead key, F032 audit noted).
- **Current coverage**: ⚠️ Warn — `check_i18n_locale_parity` compares V2's own locale files; V1 `lang/` keys are not read (→ SM §9, frontend `i18n-scan`).
- **Severity**: P1 (Arabic users see bare `Orders.editOrder` keys in UI).
- **Suggested mechanism**: validator runs i18n-audit module; if any new key in `en.ts` lacks the same path in `ar.ts`, log_fail.

### B7. Backend hexagonal-boundary violation
- **What**: V2 service in the application layer imports from the infrastructure layer; controller calls repository directly bypassing the command/service layer; the project's DI/framework service-registration decorator/marker appears in domain or pure-application layers. *Concrete syntax varies by stack — see `backend/rules/migration-backend.md § DI markers` for the project's stack.*
- **Stack**: Backend (<backend-v2> hexagonal).
- **Where it bit us**: Projected — `<backend-v2>/CLAUDE.md` warns; the `/hex-purity` skill exists.
- **Current coverage**: ⚠️ Project-side only — `/hex-purity` static scan exists in <backend-v2>; NOT wired into the migration validator.
- **Severity**: P0 (architectural rot).
- **Suggested mechanism**: For backend ports, `check_v2_structure` invokes `pnpm hex-purity --feature=<feature>` and consumes its exit code.

### B8. Backend transaction-script in service (no aggregate)
- **What**: V2 `CommandService.create()` is procedural — fetches, mutates, saves — instead of `aggregate.applyChange(); repo.save(aggregate);`. Skips the aggregate-root pattern <backend-v2> mandates.
- **Stack**: Backend.
- **Where it bit us**: Projected.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P1.
- **Suggested mechanism**: agent-side — `migration-architect`'s "Read V2's primitives" step (Phase 3 of `port-feature`) must surface "uses aggregate?" check; flag in plan.

### B9. Backend response-mapper drift (DTO shape ≠ V1)
- **What**: V2 `ResponseMapper.toResponse()` returns shape `{ id, name }`; V1 returned `{ id, name, name_translations }`. Frontend silently breaks.
- **Stack**: Backend → Frontend (cross-stack).
- **Where it bit us**: Projected. F033 G3 (V2 added 3 new KPI summary fields) is the inverse of this — V2 over-returns; the audit flagged "if API doesn't return these fields, V2 will show 0 silently" — same shape, different direction.
- **Current coverage**: ❌ UNCOVERED. The contract's "Outputs (per code path)" section names the shape, but no automated check that the V2 implementation's actual response matches.
- **Severity**: P0.
- **Suggested mechanism**: parity-test-generate produces a "shape assert" test that hits V2 with a fixed input and asserts response keys = contract.Outputs.shape.keys. CI gate.

### B10. Per-route auth/permission mismatch
- **What**: V2 controller's `@Permissions('orders.update')` doesn't match V1's middleware permission check. Sub-roles whose RBAC differs are silently granted/denied.
- **Stack**: Backend (and surfaces in frontend's permission gates).
- **Where it bit us**: F033 G2 (V2 added `orders.print` + `orders.track` gates V1 lacked) — frontend side. Same risk on the API.
- **Current coverage**: ⚠️ Partial — keyed I-AUTHZ set diff in `check_inventory_primitives_match` when `pair-inventory.py` extracted both sides (a guard moved from route A to route B now fails); otherwise the substitution-blind `auth_guard` count.
- **Severity**: P0.
- **Suggested mechanism**: contract's "Auth + permissions" axis (already in spec) must enumerate every route's `@Permissions()` decorator on V1 vs V2; halt on mismatch unless ADR-cited.

---

## Category C: Contract failures (V2 doesn't match V1 observable)

The contract was written; the implementation matches the contract; but the contract itself missed something V1 actually does.

### C1. Missing UI affordance (button / link / dropdown)
- **What**: V1 has a button, V2 doesn't. Audit declared parity-clean.
- **Stack**: Frontend.
- **Where it bit us**: F039 ("Add new mapping"), F032 ("Edit Order" button + dialog), F033 G1 ("Delete selected").
- **Current coverage**: ✅ HALT *if* `parity-auditor` agent is dispatched (per `migration-phase.md § 4b`) AND it enumerates the "UI affordances" axis per `frontend/rules/migration-frontend.md § Frontend audit axes`. ✅ HALT on hand-wave (`check_audit`).
- **Severity**: P0.
- **Note**: Coverage is mechanism (mandatory dispatch) + content (no hand-waves). Both paths must hold.

### C2. Permission-gate divergence (V1 ungated → V2 gated, or vice versa)
- **What**: V1 shows a button to all users; V2 hides it behind a permission. Sub-roles regress; or V1 gated and V2 ungated → privilege escalation.
- **Stack**: Frontend + Backend.
- **Where it bit us**: F033 G2 (V2 added Track + Print gates), F030 G6 (assign-orders gated in V2 ungated in V1).
- **Current coverage**: ✅ HALT (frontend table) — `check_permission_gate_divergence` fails a "match" verdict whose cells show V1 ungated and V2 gated, or the reverse. Server routes → SP §3, §4.
- **Severity**: P0 (security regression in either direction).
- **Suggested mechanism**: `check_audit` parses Frontend-axes table; if "Per-button permission gates" row says "match" but V1 cell = "none" and V2 cell ≠ "none" (or vice versa), log_fail "verdict contradicts cells".

### C3. Templated query param drop
- **What**: V1's URL filter sends `?warehouse_id=X&google_sheet=Y`; V2 sends fewer params. List endpoint silently filters less.
- **Stack**: Frontend.
- **Where it bit us**: F039 (4 query params hidden under `&...`); F030 missing-tab `created_at` vs `from_date`/`to_date`; F030 `is_missing_request=1`.
- **Current coverage**: ✅ HALT on hand-wave (`check_audit` regex catches `&...` literal). Soft on enumeration completeness — relies on auditor reading V1's URL construction.
- **Severity**: P0.

### C4. Side-effect drop (V1 wrote audit log; V2 doesn't)
- **What**: V1 emits a metric / log line / audit record / queue message that downstream systems depend on; V2 omits it. Billing dashboards, audit trails, downstream consumers break.
- **Stack**: Backend.
- **Where it bit us**: Projected. `extract-v1-contract.md § 3 Side effects` lists the surface; relies on contract author finding it.
- **Current coverage**: ⚠️ Spec-only — contract section 3 + parity-test "Side effects" recipe. No mechanical assertion.
- **Severity**: P0.
- **Suggested mechanism**: parity test for side-effect features = a snapshot of all side effects (audit_log rows / metric counters / queue messages) per input, asserted against V1 capture.

### C5. Empty-state observable drop
- **What**: V1 returns `{}` for empty result; V2 returns `null`. Or V1 returns `[]`, V2 returns `{ items: [] }`. Caller crashes.
- **Stack**: Backend.
- **Where it bit us**: Projected. Classic example in the pack-side `references/migration-discipline-catalogue.md § Examples per concern (parity / scope / perf-uplift / cutover) § Parity preservation`; the enforceable form is `ai/patterns/migration-guardrails.md § Named anti-patterns → The Silent Break`.
- **Current coverage**: ⚠️ Tolerance taxonomy + corpus must include empty-state inputs (per `parity-test-generate.md § 2`). Soft enforcement.
- **Severity**: P0.

### C6. Reactive lifecycle mismatch (mount-only hook on cached/reactivating page)
- **What**: V1 uses a mount-only lifecycle hook on a non-cached page; V2 page is cached / kept-alive but uses only the mount-only hook — data goes stale on tab return / tenant switch. *(Concrete hook pair varies by stack — see the project's frontend pack rule § Lifecycle for the project's mount-only hook vs its mount-AND-reactivate hook pair.)*
- **Stack**: Frontend.
- **Where it bit us**: Documented in `<frontend-v2>/CLAUDE.md` (KeepAlive section); F032 audit verified V2 uses `onActivated` correctly. Risk recurs every port.
- **Current coverage**: ⚠️ Warn — `check_lifecycle_keepalive` (Vue KeepAlive; runs only with `keepalive_layout` anchored).
- **Severity**: P0 (tenant-leak risk on tab return after account switch).
- **Suggested mechanism**: `check_v2_structure` — for any `.vue` file under `src/modules/*/pages/` that's NOT in the `noCache` exclude list, grep for `onMounted\(` without a paired `onActivated\(` → log_fail.

### C7. Loading / error state drop
- **What**: V1 shows a spinner during fetch + an error toast on 5xx; V2 silently shows empty page on error. Already in `<frontend-v2>/CLAUDE.md § NEVER skip loading/error states`.
- **Stack**: Frontend.
- **Where it bit us**: Projected.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P1.

### C8. RTL break
- **What**: V2 uses physical CSS properties (`margin-left`); RTL layouts break. Already in `.claude/rules/a11y.md § RTL safety`.
- **Stack**: Frontend.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Spec-only — a11y agent reviews; no validator check.
- **Severity**: P1.
- **Suggested mechanism**: `check_v2_structure` regex for `margin-(left|right):|padding-(left|right):|left:\s*[0-9]|right:\s*[0-9]` in scoped `<style>` blocks.

### C9. Visual-only divergence (pixel diff outside tolerance)
- **What**: V2 renders the same fields but layout differs visually beyond the `dom-equivalent` tolerance class.
- **Stack**: Frontend.
- **Where it bit us**: Projected. `parity-test-generate.md § Visual regression` covers but isn't always wired.
- **Current coverage**: ❌ UNCOVERED at validator level. Frontend `/visual-check` skill exists.
- **Severity**: P2.

### C10. Locale-specific semantic shift
- **What**: V1 formats currency as `1,000 SAR`; V2 formats as `SAR 1,000`. Caller's regex on the rendered string breaks; user perception differs.
- **Stack**: Frontend.
- **Where it bit us**: Projected. F033 KPI summary cards (different label keys) gestures at this.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P2.

---

## Category D: Test failures (parity test is thin)

The corpus exists but doesn't cover what V1 actually does in production.

### D1. Corpus all-happy-path (no error / edge / business-rule inputs)
- **What**: 30 inputs all hit the success branch; no 4xx/5xx/empty/oversize/Unicode inputs.
- **Stack**: Both.
- **Where it bit us**: Projected. Phase-6 corpus = 38 inputs but distribution unknown; relook found gaps the corpus didn't cover.
- **Current coverage**: ⚠️ Warn (fail under `--strict`) — `check_corpus_distribution` classifies inputs into happy / error / edge / rule buckets. The 30-input floor still counts files, not V1 branches (→ PF §2, V387).
- **Severity**: P0.
- **Suggested mechanism**: corpus filenames follow convention (`001-happy-*.json`, `010-error-*.json`, `020-edge-*.json`, `030-rule-*.json`) — validator counts each prefix; halt if any prefix < 1.

### D2. Tolerance.yaml doesn't cover every contract output field
- **What**: Contract Outputs section lists 14 fields; tolerance.yaml lists 11. The 3 unspecified fields default to "exact" or, worse, are silently ignored.
- **Stack**: Both.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Warn — `check_tolerance_coverage` cross-parses the contract Outputs against tolerance.yaml keys.
- **Severity**: P1.
- **Suggested mechanism**: `check_tolerance_coverage` — parse contract `## 2. Outputs`, extract field names, intersect with tolerance.yaml keys; halt on missing.

### D3. Tolerance loosened in same PR as a red test (re-listed from A6)
- See A6.

### D4. V1 commit pinned ≠ commit parity tests ran against
- **What**: Ledger says `v1_commit_pinned: abc`; CI ran tests against V1 HEAD = `def`. Oracle drifted; test passed on a different V1.
- **Stack**: Both.
- **Where it bit us**: Projected. `migration-discipline.md § halt #7` requires equality.
- **Current coverage**: ✅ HALT — `check_parity_run_v1_commit` (heavy tier) and `check_parity_run_report` compare the recorded run's `v1_commit` with `v1_commit_pinned`.
- **Severity**: P0.
- **Suggested mechanism**: parity test runner emits `parity-runs/<feature>-<runid>.md` with the V1 commit it cloned; validator cross-checks against ledger.

### D5. Mocked V1 dependency hides bug
- **What**: V1 calls `getUser`, V2 calls `getUser`, both mocked → parity passes but production diverges.
- **Stack**: Both.
- **Where it bit us**: Projected. `parity-test-generate.md § Failure modes` warns.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P1.

### D6. Property generators don't reflect prod input shapes
- **What**: Generators produce small inputs; prod sends 10MB inputs; V2 OOMs in prod despite green CI.
- **Stack**: Backend.
- **Where it bit us**: Projected.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P1.

### D7. Snapshot drift via `--update-snapshots`
- **What**: Engineer "fixes CI" by updating golden snapshots; oracle is now wrong.
- **Stack**: Both.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Partial — when the repo-baseline gate scripts are installed, `test-integrity.py` fails an undeclared golden rewrite (`undeclared-baseline-rewrite`); nothing in this pack checks it (→ PF §1, V386).
- **Severity**: P0.
- **Suggested mechanism**: pre-commit hook / CI check — if `__golden__/` files change in a PR, require ADR cite or auditor signoff.

### D8. KeepAlive-aware mount missing in test config
- **What**: Vue test mounts page bare; `onActivated` never fires; `expect(mockApi).toHaveBeenCalled()` fails. Test config missing `<KeepAlive>` wrap.
- **Stack**: Frontend.
- **Where it bit us**: Projected. `parity-test-generate.md § KeepAlive-aware mount` documents.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P2.

### D9. Auto-import test config mismatch
- **What**: `unplugin-auto-import` works in prod, not in test config; first mount fails with "useI18n is not defined".
- **Stack**: Frontend.
- **Where it bit us**: Projected. `parity-test-generate.md § Auto-import test-config requirement` — cites "The Auto-import Trip" in `ai/patterns/migration-guardrails.md § Named anti-patterns` (named 2026-08-21; moved to the installed pattern 2026-08-23).
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P2.

---

## Category E: Cross-cutting failures

### E1. a11y attribute dropped
- **What**: V1 had `aria-label` on icon-only button; V2 omits.
- **Stack**: Frontend.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Spec-only — `frontend/rules/migration-frontend.md § Frontend audit axes "Accessibility"`; `/a11y-audit` skill exists.
- **Severity**: P1.

### E2. Tenant-isolation leak (token in localStorage outside secureStorage)
- **What**: V2 introduces `localStorage.setItem('product_cache', ...)` that survives logout; or `localStorage.getItem('selectedLanguage')` outside store.
- **Stack**: Frontend.
- **Where it bit us**: Projected. `<frontend-v2>/.claude/rules/multi-tenancy.md` warns; F030/F032/F033 audits all confirmed clean.
- **Current coverage**: ✅ HALT — `check_v2_structure` fingerprint `localStorage\.(get|set)Item.*[Tt]oken`. ⚠️ Doesn't catch non-token localStorage that survives logout.
- **Severity**: P0.
- **Suggested mechanism**: extend fingerprint to flag any `localStorage\.setItem` that's not in `secureStorage.ts` or a documented allow-list.

### E3. Manual `Authorization: Bearer` header in service code
- **What**: V2 service hand-builds the auth header instead of letting the interceptor inject — bypasses refresh queue.
- **Stack**: Frontend.
- **Where it bit us**: Projected.
- **Current coverage**: ✅ HALT — `check_v2_structure` fingerprint `"Authorization.*Bearer"`.
- **Severity**: P0.

### E4. `axios.create` outside canonical client
- **What**: Per-feature axios instance with its own interceptors → double-source-of-truth on token.
- **Stack**: Frontend.
- **Where it bit us**: Projected.
- **Current coverage**: ✅ HALT — `check_v2_structure` fingerprint `axios\.create\(`.
- **Severity**: P0.

### E5. console.log left in production code
- **Where it bit us**: Projected.
- **Current coverage**: ✅ HALT — `check_v2_structure` fingerprint `console\.(log|debug)\(`. Also ESLint.
- **Severity**: P2.

---

## Category F: Process failures

### F1. Ledger drift (PR ports without updating ledger)
- **What**: V2 ships, ledger row stays `unverified`. Source of truth diverges from code.
- **Stack**: Both.
- **Where it bit us**: F033 reconciliation — `ai/status.md` "Reports: advanced filters not implemented" was stale (V2 had implemented them).
- **Current coverage**: ✅ HALT — `migration-gate.md` checks 1-3 enforce; `check_ledger_row` enforces required fields per state.
- **Severity**: P0.

### F2. Scope creep (one PR ports + refactors + adds feature)
- **What**: Reviewer can't localize regression; rollback all-or-nothing.
- **Stack**: Both.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Soft — `parity-auditor.md § Stage A halt #9` ("Scope creep"); manual reviewer check.
- **Severity**: P1.
- **Suggested mechanism**: PR-side check — if `git diff --name-only` includes files outside `<v2_path>` + ledger + audit + parity-tests, halt.

### F3. V1 modified in port PR
- **Stack**: Both.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Soft — `parity-auditor.md § Stage A halt #6`; relies on reviewer.
- **Severity**: P0.
- **Suggested mechanism**: PR-side check — `git diff --name-only` matched against V1 root; halt unless `--cutover-additive` flag with rationale.

### F4. Cutover without rollback path
- **What**: Feature flag that can't flip back; deleted V1 with no archive.
- **Where it bit us**: Projected.
- **Current coverage**: ✅ HALT — `check_runbook` requires runbook present.
- **Severity**: P0.

### F5. The Eternal Shadow (V2 lives in shadow indefinitely)
- **What**: V2 stays at `V2-shadow` for months; V1 keeps shipping; divergence widens; the cutover never happens.
- **Stack**: Both.
- **Where it bit us**: Projected. Phase 6 just landed `V2-shadow` for 4 features; cutover deadline not yet set.
- **Current coverage**: ⚠️ Soft — `migration-status.md` flags rows >30d in same state. No hard SLA.
- **Severity**: P1.
- **Suggested mechanism**: ledger row's `shadow_started_at` field; validator halts on `now() - shadow_started_at > shadow_max_days`.

### F6. The V1 Deletion Sprint (delete V1 before zero-traffic confirmed)
- **What**: Delete V1 module to "clean up"; a stale cron import silently fails next fire.
- **Stack**: Both.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Spec-only — `parity-auditor.md § Stage D` requires zero-traffic ≥14d evidence.
- **Severity**: P0.

### F7. Architecture-in-flux during port
- **What**: V2's own architecture changes mid-migration; ports written against the old shape rot.
- **Where it bit us**: Projected. `port-feature.md § Pre-flight check 5` halts.
- **Current coverage**: ⚠️ Spec-only.
- **Severity**: P1.

---

## Category G: Cross-repo / workspace failures

These are unique to multi-repo migrations where the V1 API + V1 frontends + V2 ports live in a shared workspace.

### G1. API contract changes; frontends silently break
- **What**: <backend-v1> (V1) endpoint changes shape; <frontend-v2> still consumes old shape; runtime breaks.
- **Stack**: Backend → Frontend.
- **Where it bit us**: Projected. F033 G3 (V2 expected 3 KPI fields V1 may not return) is a cousin.
- **Current coverage**: ⚠️ Spec-only — `/sync-contract` workspace command exists (`<workspace-root>/.claude/commands/`).
- **Severity**: P0.
- **Suggested mechanism**: contract test that runs against the live API in CI; halt if shape diff detected.

### G2. Workspace orchestrator out of date
- **What**: `/cross-repo-task` references `<frontend-v2>/CLAUDE.md` but that file moved / changed conventions.
- **Stack**: Workspace.
- **Where it bit us**: Projected.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P2.

### G3. Sibling drift (fix shipped to one repo, not synced to siblings)
- **What**: A bug fix lands in `<frontend-v1>/` (v1); the same bug exists in `<frontend-v2>/` and `<admin-v2>/`. Only v1 fixed.
- **Stack**: Frontend.
- **Where it bit us**: Projected. `<frontend-v2>/CLAUDE.md § Sibling repos` warns.
- **Current coverage**: ⚠️ Spec-only — a workspace-level multi-repo auditor agent (per `canonical-shape.md`) can run SIBLING_DRIFT detection; not migration-specific.
- **Severity**: P1.

### G4. Shared component added in one repo, not in siblings
- **What**: `<frontend-v2>/src/shared/components/form/PhoneInput.vue` lands; `<admin-v2>/` lacks it; future ports of phone fields in <admin-v2> reinvent.
- **Stack**: Frontend (workspace).
- **Where it bit us**: Projected.
- **Current coverage**: ❌ UNCOVERED.
- **Severity**: P2.

### G5. Cross-stack ledger desync
- **What**: API ports its ledger row to `done`; frontend depends on the API but its ledger row is still `V1-only`; downstream phase advances thinking the dep is live.
- **Stack**: Both.
- **Where it bit us**: Projected.
- **Current coverage**: ⚠️ Spec-only — `migration-architect.md § 2 Map dependencies` covers manually.
- **Severity**: P1.
- **Suggested mechanism**: cross-repo ledger format with `dependency: <repo>:<feature-id>` resolution at gate time.

---

## Recommended priority order for Steps 2-4 (2026-04 — items 1–4 have shipped; see § Coverage refresh)

The five highest-leverage uncovered failure modes — measured by (incident frequency × silent-break severity × cheapness-to-fix):

1. **A4 — Stale audit / oracle drift** (P1). Cheap to mechanize: `audit_date` vs `git log -1 <v2_path>` comparison + 7-day SLA. Catches the next "Phase 6 first pass" failure where audits and code drift between gate and cutover.
2. **A10 — "PASS with caveats" verdict** (P1). Cheap regex over audit body for P0/P1/HALT/missing tokens after a PASS header. F033 relook is a textbook case.
3. **C2 — Permission-gate divergence detection** (P0). Validator parses Frontend-axes table; if "match" verdict is incompatible with cell contents (V1=none, V2=permission), halt. Catches F033 G2 mechanically.
4. **D1 — Corpus distribution check** (P0). Filename-prefix convention (`happy-`, `error-`, `edge-`, `rule-`); validator counts each. The 38-input corpus that bit us in Phase 6 likely had thin error-path coverage.
5. **B7 — Backend hex-purity wired into validator** (P0 architectural). For backend ports, dispatch `/hex-purity` and consume exit code in `check_v2_structure`. <backend-v2> has the scan; the migration validator doesn't use it.

Honourable mentions: **A8 (citation spoofing)** + **A9 (intentional-break without ADR)** are both P0 + cheap; **C6 (lifecycle mismatch)** has a one-regex fix.

## Top surprise (2026-04 — since fixed)

> Fixed: `check_audit_body_consistency` (A10) now fails this shape. The 2026-10 equivalent is service-layer parity — see § Coverage refresh.

**The validator's `check_audit` provenance + hand-wave checks are HALT-able, but `check_audit` does NOT cross-check the audit's CLASSIFICATION against its body content.** An audit can declare "Result: PASS / Classification: parity-clean" while the body lists a P1 missing affordance (F033's actual shape) — and the validator passes because:
- frontmatter has provenance ✓
- no hand-wave tokens ✓
- per-axis section exists ✓
- but the `Decision recommended` section never has to agree with the gaps surfaced.

This is failure mode A10. The next "Phase 6 first pass" recurrence will land here. The fix is one regex over audit-body lines after the "Result:" header, but it's currently absent — the strongest single-line addition the validator could receive next.

## Path

`templates/packs/migration/_failure-surface.md` (relative to the Refract repo root)
