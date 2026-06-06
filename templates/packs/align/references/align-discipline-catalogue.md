# Align discipline — examples & anti-pattern catalogue

> Companion to `rules/align-discipline.md` (the always-loaded core). Loaded on demand during audits and reviews — NOT auto-loaded into every session.
> Rule-only tools: ships alongside the core rule in your adapter bundle.
> Content relocated verbatim from the core rule on 2026-06-07; wording unchanged.

## Examples per concern

### Behaviour preservation

```text
# ❌ Behavioural change masquerading as alignment
Finding: silent catch in fetchUser()
Closure: remove the catch (let it throw)

→ Caller code that did `try { fetchUser() } catch {}` UPSTREAM was the actual silent-catch.
→ Removing the inner catch surfaces the error to a stack-trace, breaking the upstream silent caller.
→ This is a BEHAVIOUR CHANGE — caller observes a thrown error where they previously got undefined.
→ Halt. Re-classify as a refactor; route to /refactor with caller-migration plan.

# ✅ Mechanical alignment
Finding: silent catch in parseDate()
Closure: route through the project's error handler `errors.handleParseFailure(e)` (named in _extracted-idioms.md)

→ The error handler logs at debug + returns the same `null` the silent catch was returning.
→ Caller observable: identical (still gets null on parse failure).
→ Behaviour preserved; alignment win = downstream observability.
```

### Scope discipline

```text
# ❌ Mission creep
Phase 1 PR title: "Phase 1: dead code + dedupes + silent catches + reinvented wrappers + drift"
→ 5 finding classes in 1 phase. Reviewer can't tell which class caused which delta. Rollback is all-or-nothing.

# ✅ Atomic phases
Phase 1: dead code only (12 findings, all `remove` verb).
Phase 2: silent catches only (8 findings, all `replace-with-shared` to error handler).
Phase 3: reinvented wrappers in the auth domain (10 findings, all `replace-with-shared`).
Phase 4: over-abstraction in the order domain (6 findings, all `inline`).
```

### Reuse-Before-Create

```text
# ❌ Reinvented Wrapper (alignment finding that itself reinvents)
Finding: 4 files have a copy of `formatCurrency(amount, locale)`
Closure: extract to `<utils-root>/format-currency.<ext>`, import in all 4

→ Wait — `_extracted-idioms.md` already names `<source-root>/lib/i18n.formatMoney(amount)` as the project's currency formatter.
→ The "extract" is a reinvention. Halt.

# ✅ Replace with shared
Finding: 4 files have a copy of `formatCurrency(amount, locale)`
Closure: replace 4 local copies with `i18n.formatMoney(amount)` (per _extracted-idioms.md)

→ Net-lines: -4 functions, +4 imports = -3 lines per file.
→ Mapping doc not required at trivial tier; the closure verb cites the shared equivalent inline.
```

### Tier escalation

```text
# Trivial → standard escalation
Finding A001: replace local `cn()` helper with shared `clsx` (per _extracted-idioms.md)
Initial tier: trivial (single shared swap, mechanical)

→ Scan re-checks: this swap touches 18 files.
→ Promoter triggers: "3–10 files" exceeded; "newly-introduced shared helper consumed by 3+ sites" matches.
→ Promote to standard. Add 1-paragraph rationale: "18 components import the local cn(); shared clsx is API-equivalent (drop-in)."

# Standard → heavy escalation
Finding A012: replace `useUserContext()` hook with `useAuth()` (per _extracted-idioms.md)
Initial tier: standard (cross-module symbol rename)

→ Scan re-checks: this hook is exported and used by 2 sibling packages in the monorepo.
→ Promoter trigger: "removes a symbol used outside the module being aligned" matches.
→ Promote to heavy. Add impact analysis listing every consumer + reviewer approval before merge.
```

### Security findings (always ≥ standard)

```text
# ❌ Trivial-tier security row (forbidden)
Finding A047: missing auth gate on GET /admin/export
Tier: trivial
Closure verb: add-gate

→ Halt #11: security finding without standard-tier rationale.
→ Promote to standard. Rationale required: "Endpoint exposed admin export to unauthenticated callers; gate uses requireAdmin() from _extracted-idioms.md."
→ Test added in same commit: assert 401 for unauth caller, 403 for non-admin, 200 for admin.

# ✅ Critical security → heavy
Finding A101: SQL injection in /reports/orders?status=<unsanitized>
Tier: heavy (auto-promoted; class=security, subclass=sql-injection)
Closure verb: parameterize
Severity: critical

→ Heavy tier: impact analysis required. Lists every consumer of the affected query.
→ Reviewer approval required before merge.
→ Test added: a known-injection payload returns 400 (validator rejects) AND the query log shows parameterised execution.
→ Notes: "Threat: arbitrary SQL execution as DB user; observed in red-team report 2026-04-15. Test fixture: tests/security/sql-injection.<test-ext>:42."
```

### Performance findings (idiom citation required for added lines)

```text
# ❌ Perf fix without idiom citation
Finding A082: N+1 in listOrders() — 1 query + N customer lookups
Closure verb: cache-with-explicit-ttl
Diff:
+ const cache = new Map();
+ function getCustomer(id) { if (!cache.has(id)) cache.set(id, query(...)); return cache.get(id); }

→ Halt #6: functional fix doesn't cite idiom.
→ The added cache is a NEW abstraction. The project has `<source-root>/cache/requestScopedCache.<ext>` named in _extracted-idioms.md.
→ Re-do using `replace-with-shared`: route through `requestScopedCache.get('customer:' + id, () => fetchCustomer(id), { ttl: 60_000 })`.

# ✅ Parity-preserving perf with idiom citation
Finding A082: N+1 in listOrders()
Closure verb: batch
Idiom cited: <source-root>/repos/customers.<ext>:88 (getByIds() batch primitive)
Diff (pseudocode):
- customers = parallel_each(orders, o => getCustomer(o.customerId))
+ customers = getByIds(unique(orders.map(o => o.customerId)))

→ Net: −1 line.
→ Perf assertion added: query log shows 2 queries instead of N+1 for a 50-order list.
→ Notes: "V1 cost: 51 queries / 200ms p95. V2: 2 queries / 35ms p95. Measured in tests/perf/list-orders.<test-ext>:18."
```

### Clean code / SOLID (extract to NAMED idioms only)

```text
# ❌ extract-to-shared inventing a new abstraction
Finding A055: long function (143 lines) in <source-root>/checkout/processOrder.<ext>:42
Closure verb: extract-to-shared
Diff (pseudocode):
+ // <source-root>/checkout/helpers/calculateTax.<ext> (NEW FILE)
+ export calculateTax(items, region) { ... }

→ Halt #9: new symbol introduced (not in _extracted-idioms.md).
→ Either route to /setup-project --refine (add calculateTax to idioms first), OR re-classify (the long function is a god function; the right verb may be split-extract into pre-named responsibilities, not a fresh extract).

# ✅ extract-to-shared using a pre-named idiom
Finding A055: long function (143 lines) in <source-root>/checkout/processOrder.<ext>:42
Closure verb: split-extract
Idiom cited: _extracted-idioms.md § Service responsibilities (TaxCalculator, ShippingCalculator already named)
Diff:
- // 60 lines of tax calculation
+ const tax = taxCalculator.calculate(items, region);
- // 50 lines of shipping calculation  
+ const shipping = shippingCalculator.calculate(items, region);

→ Net: −90 lines (consumers now call existing services).
→ TaxCalculator and ShippingCalculator already exist per _extracted-idioms.md; this finding moves the inline logic into them (not creates them).
```


## Anti-patterns (named)

- **The Refactor in Disguise** — a finding whose fix introduces a new abstraction (not in `_extracted-idioms.md`), renames a public API, or changes observable behaviour where preservation was the contract. Looks like alignment in the ledger; ships as a redesign in PR review. Caught by: closure-verb vocabulary check + `check_no_new_symbols` (with idioms exemption) + `check_test_coverage_nondecreasing` (agent-side — not script-enforced).
- **The Trusted Summary** (inherited from migration) — agent says "looks duplicated" / "looks dead" / "looks reinvented" / "no security issues" without `<path:line>` evidence; executor echoes into ledger. Caught by: `check_evidence_resolves` + audit halt #1.
- **The Hand-waved Finding** (inherited) — `~8 dead exports`, `several silent catches`, `multiple reinvented wrappers`, `a few missing auth gates`. Caught by: `check_no_handwaves` + audit halt #2.
- **The Net-Positive Cleanup** (structural) — fix imports a shared helper but doesn't delete the local copy; OR introduces a wrapper "to make the swap easier"; OR adds a comment explaining the new shape. Net lines go up on a structural row. Caught by: `check_net_lines_structural` + audit halt #5.
- **The Bundled Phase** — phase PR mixes 5 finding classes; reviewer can't localise regressions. Caught by: review-checklist row "PR title = single-class-or-domain"; reviewer responsibility.
- **The Stale Ledger** — a phase merges without updating ledger rows to `fixed`. Code grep claims "no more silent catches" but ledger rows are still `in-progress`. Caught by: `/align-gate` halt #1; `/align-status` reports stalled rows.
- **The Oracle Drift** — alignment PR also modifies `_extracted-idioms.md` / `ai/conventions.md` to "explain" the fix. Caught by: review-checklist + `check_oracle_unmodified` (PR diff against `_extracted-idioms.md` must be empty).
- **The Eternal Phase** — phase opens, 30+ findings detected, phase never closes because new findings keep getting added. Caught by: phase-cap rule (≤ 12 findings); excess routes to phase N+1.
- **The Re-Detection Skip** — porter applies the fix and marks `status: fixed` without re-running the detector to confirm the fingerprint is gone. The fingerprint sometimes lingers (the fix targeted the wrong line). Caught by: VERIFY step's mandatory re-detect; `check_evidence_resolves` re-run at gate.
- **The Silent Coverage Drop** — fix removes a branch; tests pass; but the branch was the only path exercising a downstream code path. Coverage drops 0.3%; nobody notices in a 1500-test suite. Caught by: `check_test_coverage_nondecreasing` (agent-side — not script-enforced) (any drop is a halt).
- **The Reinvented Idiom in Functional Verb** — porter writes a new validator schema, cache helper, escape function, gate wrapper inside an `add-validator` / `cache-with-explicit-ttl` / `escape` / `add-gate` fix. The functional verbs are supposed to USE the project's existing idiom — inventing a new one is the same anti-pattern as Reinvented Wrapper, just on functional adds. Caught by: `check_added_lines_cite_idioms` + `check_no_new_symbols` (with idioms exemption).
- **The Bare Security Fix** — porter adds a gate / validator / escape but doesn't add a test asserting it works. Six months later, a refactor accidentally removes the gate and no test catches it. Caught by: `check_security_assertion_present`.
- **The Hopeful Perf Fix** — porter parallelises / batches / caches without measuring before or after. The fix may be a perf regression (e.g., `Promise.all` overwhelms a downstream service); nobody knows because there's no baseline. Caught by: `check_perf_baseline_present`.
- **The Lockfile-Only Bump** — `bump-dep` for a vulnerable dependency without running the test suite. The bump may have a breaking change; tests catch it but nobody ran them. Caught by: VERIFY step's mandatory test run.
- **The Tier Demotion** — porter sets a security row to trivial because "it's just one missing gate, easy fix". Caught by: audit halt #11 + `check_security_tier_minimum`.
- **The Behaviour Change Conflation** — security gate that changes behaviour (denies unauth) is bundled with an unrelated alignment fix in the same commit. The security change becomes invisible in the diff. Caught by: review-checklist + one-finding-per-commit rule.
- **The Cross-Class Phase** — phase PR contains a mix of structural + security + perf rows. Net-lines rule is ambiguous; reviewer attention is scattered. Caught by: phasing strategy in `/align-plan` (single-class or single-domain phases preferred).
- **The Frontend Regression Skip** — porter ignores a11y / visual / bundle-size regression "because it's mechanical". Caught by: `check_frontend_regressions` (agent-side — not script-enforced) at gate.
- **The Idiom Inventory Gap** — porter halts repeatedly because the idiom they need (a validator, a cache helper, a gate wrapper) doesn't exist in `_extracted-idioms.md`. The right move is to update idioms first via `/setup-project --refine`, then resume alignment — not to invent the idiom inline. Symptom: `halts/` directory full of "missing idiom: X" entries.


## References

These references are **convenience pointers for AI tools that support them**. The rule itself is self-sufficient — every procedure is inlined above. If your tool doesn't expose these as commands/agents/skills, follow the inlined procedures.

### For tools with command + agent + skill dispatch

- `.claude/skills/detect-drift.md` — drift-detection procedure (inlined above).
- `.claude/skills/find-and-align.md` — per-finding fix loop (inlined above).
- `.claude/commands/align-scan.md` — Phase 0 entry point (scan + report).
- `.claude/commands/align-plan.md` — phase grouper (consumes scan output).
- `.claude/commands/align-phase.md` — per-phase orchestrator (executes find-and-align per row).
- `.claude/commands/align-gate.md` — phase exit verifier (validates the artifact set above).
- `.claude/commands/align-fast.md` — one-shot orchestrator (scan + plan + all phases + gate).
- `.claude/commands/align-status.md` — read-only ledger reader.
- `.claude/commands/align-final.md` — final sweep across all phases.
- `.claude/commands/align-rollback.md` — undo a phase.
- `.claude/commands/align-park.md` — park a hairy finding.

### Cross-pack references

- `code-quality/commands/simplify.md` — structural closure-verb vocabulary inherited from this command.
- `code-quality/commands/check-health.md` — pre-flight mechanical check; run before `/align-scan`.
- `code-quality/agents/dead-code-finder.md` — dispatched by `detect-drift` for the dead-code class.
- `code-quality/agents/refactorer.md` — dispatched in detect-only mode for over-abstraction + SOLID classes.
- `code-quality/agents/code-reviewer.md` — dispatched for clean-code class.
- `code-quality/agents/performance-optimizer.md` (or per-pack equivalent) — dispatched for performance class.
- `code-quality/rules/quality-principles.md` — clean-code thresholds referenced by clean-code detector.
- `code-quality/rules/engineering-principles.md` — SOLID principles + engineering rules referenced by SOLID + clean-code detectors.
- `security/agents/security-auditor.md` — dispatched for security class.
- `security/commands/security-audit.md` — sibling command (security-only deep audit, used by /align-scan when security findings exceed scan threshold).
- `security/skills/deps-audit.md` — dispatched for vulnerable-dependency security findings.
- `migration/rules/migration-discipline.md` — sibling discipline; align is migration turned inward.
- `frontend/rules/migration-frontend.md` — frontend-specific anti-pattern catalogue (extends align).
- `frontend/agents/accessibility-auditor.md` — dispatched for `frontend-*` a11y class.
- `frontend/agents/i18n-auditor.md` — dispatched for `frontend-*` i18n class.
- `frontend/agents/data-flow-auditor.md` — dispatched for `frontend-*` UI-state class.
- `ui-ux/skills/design-token-audit.md` — dispatched for `frontend-*` token class.
- `ui-ux/skills/motion-audit.md` — dispatched for `frontend-*` motion class.
- `backend/rules/migration-backend.md` — backend-specific anti-pattern catalogue (extends align).
- `backend/rules/concurrency-discipline.md` — perf class's `parallelize` verb references this for safe parallelism.

### Patterns (read by all tools as ai/ knowledge)

- `ai/patterns/align-ledger.md` — ledger record format + state machine (authored when `/align-scan` first runs).

### Validator script

- `scripts/validate-align-artifacts.sh` — validates evidence resolution, hand-wave-token absence, net-line non-positivity, test-coverage non-decreasing, scope-boundary, no-new-symbols, oracle-unmodified. Runnable from CI / pre-commit / any tool's hook system. Tool-agnostic.

### For rule-only tools (Aider, Codex, Gemini, partial: Cline, Windsurf)

This rule **is** the surface. The 11 universal finding categories (6 structural + 5 functional), the 14 phase-exit checks, the 11 per-finding halts, the closure-verb vocabulary (5 structural + 16 functional), and the three procedures (scan / find-and-align / gate) are all inlined above. No skill / agent / command dispatch is required — follow the rule as a checklist.

## Per-stack extensions

The 7 universal finding classes are necessary but NOT sufficient for stack-specific alignments. Stack-specific detector fingerprints, anti-pattern catalogues, and idiomatic shared-equivalents live in the per-stack packs:

### Frontend alignments — UI/UX is mandatory, not optional

For any `PROJECT_KIND in {frontend-*}`, the align scan MUST dispatch UI/UX detectors alongside the universal 7. UI/UX drift is the single largest source of user-visible regression in frontend codebases — inconsistent spacing, hardcoded colors, missing focus states, orphaned locale keys, a11y violations, raw library components used in pages where wrappers exist, broken empty/loading/error states, mobile breakpoints applied inconsistently. Treating these as "polish for later" is how design systems decay.

**UI/UX finding sub-classes (stack-specific, all use the universal closure verbs):**

| Sub-class | Detector signal | Default closure verb | Detector source |
|---|---|---|---|
| **a11y violation** | missing `alt`, `aria-label`, `aria-labelledby`, `for`/`id` pair, color contrast < AA, focus state missing on interactive element, heading hierarchy skip (`h1 → h3`), button-as-div, link-as-div | `replace-with-shared` (use the project's a11y-correct wrapper) OR `remove`-and-relocate (move attribute to correct element) | `frontend/agents/accessibility-auditor.md` + `frontend/commands/a11y-audit.md` |
| **design-token drift** | hardcoded color hex / rgb / hsl, hardcoded spacing / font-size / radius, raw Tailwind utility where the project's token alias exists, inline `style="color: #..."` | `replace-with-shared` (swap raw value for the design token named in `_extracted-idioms.md`) | `ui-ux/skills/design-token-audit.md` |
| **i18n key drift** | hardcoded user-visible string in markup (no `t('...')` / `$t('...')` / `useTranslation` call), orphan locale key (defined in JSON but no resolver), missing key (resolver call resolves to literal), namespace casing mismatch | `replace-with-shared` (swap hardcoded string for translation key) OR `remove` (orphan key in locale JSON) | `frontend/agents/i18n-auditor.md` + `frontend/commands/i18n-audit.md` |
| **raw library component used in app code** | a raw component from the project's UI library (e.g., button / modal / input / table) used directly in a page where the project's wrapper equivalent exists (per `_extracted-idioms.md` — concrete library and wrapper names vary by stack) | `replace-with-shared` (swap raw component for project wrapper) | universal `reinvented-wrapper` detector + frontend's gold-standard inventory |
| **missing UI state** | data-fetching component with no loading state OR no empty state OR no error state (hooks/composables that fetch data without surfacing the 3 states the project's standard fetch wrapper provides) | `replace-with-shared` (route through the project's standard fetch wrapper named in `_extracted-idioms.md`) | `frontend/agents/data-flow-auditor.md` |
| **motion / transition drift** | hardcoded `transition: all 0.3s` / inconsistent easing curves / missing `prefers-reduced-motion` guard / animation defined inline where the project has a token system | `replace-with-shared` (swap inline motion for project's motion token) | `ui-ux/skills/motion-audit.md` |
| **responsive breakpoint drift** | hardcoded `min-width: 768px` where the project has named breakpoints (`tablet`, `desktop`); responsive-only-at-page-level where the component should adapt; `display: none` for mobile-hide where the project's responsive utility exists | `replace-with-shared` (swap raw media query for project breakpoint utility) | `ui-ux` pack detector OR custom grep |
| **duplicated surface styles** | same affordance (button / card / badge / input / list-row) carries similar inline or scoped styling across **≥ 2** leaf pages or routes with no shared wrapper extracting it; detected by shape / component usage + style-rule similarity per `_extracted-idioms.md` | `extract-to-shared` (introduce or reuse the wrapper named in idioms; rewire callers) OR fold styles into the shared token / wrapper variant — see `ui-ux/commands/enhance-ui.md` Phase 1.5 | `/enhance-ui` orchestration + `frontend/agents/ui-architect.md` |
| **lifecycle / data-fetch hook on wrong element** | (inherited from migration-frontend.md): hook that fires only on full mount used on a route-cached child; hook that fires on every render used on data fetch | `replace-with-shared` (swap to the mount-AND-reactivate hook pair named in `_extracted-idioms.md`) | `frontend/rules/migration-frontend.md` § lifecycle-hooks |
| **default-true wrapper prop** | (inherited): `<CrudActions>` / `<TableHeader>` rendered without `:show-delete="false"` / `:can-edit="false"` where the page should hide that affordance | `remove`-the-element OR add the explicit `false` prop | `frontend/rules/migration-frontend.md` § default-true-wrapper-props |
| **permission-gate drop** | (inherited): action button rendered without the project's permission-gate wrapper / `v-if="hasPermission"` / `{user.can() && ...}` | `replace-with-shared` (wrap in the project's permission gate) | `frontend/rules/migration-frontend.md` § permission-gate |

**Frontend scan dispatch (mandatory for `PROJECT_KIND in frontend-*`):**

In addition to the universal 7 detectors, `/align-scan` runs:
1. `accessibility-auditor` agent — full repo a11y scan
2. `i18n-auditor` agent — locale-tree drift + orphan keys
3. `data-flow-auditor` agent — UI-state coverage
4. `design-token-audit` skill — token drift
5. `motion-audit` skill — animation drift
6. Per-stack pack's `migration-frontend.md` fingerprint set (if the frontend pack is loaded) — Transposition Trap, default-true props, permission-gate drop, reinvented wrappers

Scan output for frontend-* projects has UI/UX findings co-mingled with universal findings, classified by sub-class. Phasing typically groups UI/UX findings by **page or domain** (e.g., "Phase 1: auth pages a11y + design-token alignment") rather than by sub-class — a single page's a11y, token, and i18n fixes are reviewed together because they touch the same files.

**Visual / behaviour preservation for UI/UX fixes:**

UI/UX fixes have stricter behaviour-preservation requirements because the test suite often doesn't cover visual output. Required:
- **Visual regression** — for any phase that touches UI rendering, run the project's visual regression suite (Chromatic / Percy / Playwright snapshots — named in `_extracted-idioms.md`) against pre-fix and post-fix; diffs must be reviewed and accepted before the gate passes.
- **a11y regression** — for any phase that touches a11y, run the project's a11y test suite (`axe-core`, `pa11y`, `Playwright accessibility`) at HEAD; score must NOT drop.
- **Bundle size** — for any phase that swaps raw library components for wrappers, run the project's bundle-size check (`size-limit`, `bundlesize`); size must NOT increase by > 1% per phase.

If any of these regress, halt the gate; the closure verb was applied wrong.

### Backend alignments

See `backend/rules/migration-backend.md` (if your backend pack defines one). Adds: query-without-tenant-gate (in multi-tenant projects), N+1 detector, sequential-await loops where parallelism is safe, missing transaction boundary on multi-statement writes, raw SQL where the repository pattern is the convention.

### Data / pipeline alignments

See `data/rules/` (if defined). Adds: column-projection-greater-than-consumed (`SELECT *` where 4 columns are read), sync external-HTTP in batch jobs, idempotency-key-missing on write paths.

### Mobile alignments

For `PROJECT_KIND in {mobile-*}`, dispatch `mobile/skills/native-bridge-audit.md` alongside the universal 7.

### Fallback

If your project has no per-stack pack file, the universal 7-class taxonomy above is the floor. Author per-stack fingerprints into a per-stack pack as drift accumulates.

The universal rule below stays stack-agnostic. All concrete component / hook / library / ORM / migration-tool / a11y-tool / token-system names belong in the per-stack packs.


