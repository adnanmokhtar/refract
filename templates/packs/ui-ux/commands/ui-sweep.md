---
description: Project-wide UI/UX specialist sweep. Goes BEYOND align's structural cleanup — runs UI/UX-specific deep detectors (visual hierarchy, component utilization, token coverage, cross-surface consistency, UI-state coverage, responsive matrix, design-language coherence), captures visual baseline screenshots per route, quantifies coverage metrics with targets, phases by USER FLOW (not by class), uses UI/UX-specific verbs (consolidate-tokens, unify-component, normalize-hierarchy, wire-empty-state), outputs an HTML visual report with screenshots + metrics + recommendations. Frontend stacks only.
kind: command
pack: ui-ux
---

# /ui-sweep [<phase>]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/ui-sweep <phase> --plan` runs the **read-only** phases (PRE-FLIGHT → SCAN → METRICS → PLAN — the 8 detectors + coverage metrics + the user-flow plan), writes the fix plan to `.claude/plans/`, and exits **before the FIX phase** — no code edits, no baseline overwrite. Execute it later with `/execute-plan <file>` (or hand it to any tool). The in-pack `ai/ui-sweep/ledger.md` is the deep report-based handoff; `--plan` is the tool-agnostic spelling of the same stop-before-FIX boundary.

## The Premise (read this first)

**Discipline pointer:** [`templates/governance/core-discipline.md`](../../../governance/core-discipline.md) — when routing to `/align-scan` for SOLID / structural work, use linked vocabulary (single source of truth).

**This is the UI/UX specialist command — not a thin align wrapper.** It has its own detectors, its own metrics, its own phasing strategy, its own verbs, and its own visual report. It overlaps with align on a few classes (a11y, design tokens) but goes substantially deeper on UX-specific concerns align doesn't measure.

Use it when you want **measurable UI/UX quality** across the project, not just "code structure is clean".

## What this does that `/align-scan` does NOT

| Capability | `/align-scan` | `/ui-sweep` |
|---|---|---|
| Hardcoded colors / spacing detection | YES (design-token-drift class) | YES (and quantifies coverage %) |
| Reinvented wrapper detection | YES | YES (and quantifies utilization %) |
| **Visual hierarchy analysis** | NO | YES (per-page hierarchy score; primary-action prominence) |
| **Component utilization quantification** | NO | YES ("project has 12 wrappers; 6 are used in <50% of eligible sites") |
| **Token coverage quantification** | NO | YES ("73% of color values use tokens; 27% hardcoded") |
| **Cross-surface consistency matrix** | NO | YES (all list pages compared structurally; outliers flagged) |
| **UI-state coverage** (loading / empty / error per data-fetch) | partial (missing-ui-state class) | YES (% per page; per-flow rollup) |
| **Responsive breakpoint matrix** | partial (responsive-drift) | YES (every key page screenshotted at 360 / 768 / 1280; visual diffs) |
| **Design-language coherence** (tone of voice, iconography, typography scale) | NO | YES |
| **Visual baseline + drift tracking** | NO | YES (screenshots per route, stored, compared next sweep) |
| **User-flow-based phasing** | NO (phases by class) | YES (auth flow / checkout flow / dashboard / etc.) |
| **HTML visual report** | NO (markdown only) | YES (interactive report with screenshots, metrics, before/after) |

## When to use

- Pre-launch UI/UX polish across all surfaces.
- Quarterly UI/UX cadence (after design system updates).
- Post-feature-merge consistency check ("the last 3 features added new pages — do they match existing surfaces?").
- "Make the design consistent everywhere" — quantified, not subjective.
- Establish UI/UX baseline metrics for the team to track over time.

## When NOT to use

- For code structure cleanup → `/align-scan`.
- For a single area → `/enhance-ui <description>`.
- For new features → `/add-feature`.
- Non-frontend stacks — halts.

## The 8 UI/UX-specific deep detectors

`/ui-sweep` runs these in addition to (and overlapping with) align's UI/UX classes. These are the SPECIALIST detectors:

### Detector 1 — Visual hierarchy

Per page: parses the rendered DOM (via Playwright) for primary action, secondary actions, headings, body text, supporting elements. Computes a hierarchy score:

- Primary action (e.g., "Save", "Submit", "Buy") visually dominant? (font weight, color contrast, position above-fold).
- Headings descend in size (h1 > h2 > h3) consistently.
- No visual collisions (two primary-styled buttons same view).
- Score: 0–100. Target: ≥ 80.

Output: per-page hierarchy heatmap (overlay PNG saved to `ai/ui-sweep/hierarchy/<page>.png`).

### Detector 2 — Component utilization

Reads the project's shared wrapper inventory from `_extracted-idioms.md` (e.g., `AppButton`, `BaseDataTable`, `BaseModal`, `BaseInputText`, `CrudActions`). Counts:

- How many sites COULD use each wrapper (raw fingerprint match).
- How many actually DO use it.
- Utilization % per wrapper.

Surfaces wrappers with < 80% utilization as targets for `unify-component` verb.

### Detector 3 — Token coverage

Reads design-token system from `_extracted-idioms.md` (colors, spacing, font-sizes, radii, shadows). Counts:

- How many distinct values are hardcoded across the codebase per category.
- How many tokens exist for that category.
- Coverage % = (sites using tokens) / (sites with values).

Per-category coverage:
- Color tokens: <%>%
- Spacing tokens: <%>%
- Font-size tokens: <%>%
- Radius / shadow tokens: <%>%

Target: ≥ 95%. Below 95% → `consolidate-tokens` phase.

### Detector 4 — Cross-surface consistency

For each surface type (list-page, detail-page, form-page, modal, dialog), reads the project's prototypical example (oldest stable instance) and compares all other instances structurally:

- Same wrapper components used?
- Same props passed?
- Same lifecycle hooks?
- Same a11y patterns?

Outliers flagged as `normalize-surface` candidates.

### Detector 5 — UI-state coverage

For each data-fetching component (uses `useCrud` / `useFetch` / equivalent), checks:

- Loading state wired? (skeleton / spinner / placeholder)
- Empty state wired? (specific empty-state UI, not just blank table)
- Error state wired? (user-facing error message, retry affordance)

Coverage % per page + per-flow rollup.

Target: 100%. Below → `wire-empty-state` / `wire-loading-state` / `wire-error-state` verbs.

### Detector 6 — Responsive matrix

For each route, runs Playwright at 3 breakpoints: 360px (mobile), 768px (tablet), 1280px (desktop). Captures:

- Screenshot at each breakpoint.
- Tap-target audit at 360px (every interactive element ≥ 44×44px).
- Layout collapse audit (no horizontal scroll, no clipped content).
- Critical-path visibility (primary action above fold at every breakpoint).

Surfaces breakpoint-failures as `add-mobile-affordance` / `fix-responsive` candidates.

### Detector 7 — Design-language coherence

Cross-page checks:

- **Iconography**: same icon set everywhere? (Heroicons vs Material vs FontAwesome mixed = drift).
- **Typography scale**: every font-size matches one of the project's defined scale steps? (custom font-size: 17.5px in one place = drift).
- **Tone of voice**: empty-state / error-message phrasing checked against `_extracted-idioms.md § Voice` (if defined).
- **Spacing rhythm**: vertical rhythm check (every section's margin matches a token multiple).

### Detector 8 — Visual baseline + drift

Captures route-level screenshots (Playwright) at every key route. Stores:

```
ai/ui-sweep/baseline/<iso-timestamp>/
├── login.png
├── signup.png
├── dashboard.png
├── orders-list.png
├── orders-detail.png
... (one per route)
```

Compares against the prior baseline (if exists). Surfaces:

- New routes added since last sweep.
- Removed routes.
- Visual drift > threshold (default: 10% pixel diff).

## UI/UX-specific verb taxonomy

`/ui-sweep` dispatches the closed 19-verb vocabulary defined in **`templates/packs/ui-ux/skills/ui-design-sweep/SKILL.md`** — the same skill `/polish` (frontend), `/enhance-ui`, and `/align-recheck` use. Per-verb fingerprint / procedure / verify / WCAG-iOS-HIG-Material citation live in the skill; this command does not redefine them.

Detector → verb mapping (this command's 8 detectors → ui-design-sweep's verbs):

| `/ui-sweep` detector | `ui-design-sweep` verbs dispatched |
|---|---|
| 1. Visual hierarchy | `normalize-hierarchy` |
| 2. Component utilization | `unify-component`, `extract-pattern` |
| 3. Token coverage | `consolidate-tokens`, `extract-token` |
| 4. Cross-surface consistency | `normalize-surface` |
| 5. UI-state coverage | `wire-empty-state`, `wire-loading-state`, `wire-error-state` |
| 6. Responsive matrix | `expand-tap-target`, `unify-cta-placement` |
| 7. Design-language coherence | `apply-type-scale`, `tighten-rhythm`, `simplify-density`, `unify-iconography`, `normalize-motion` |
| 8. Visual baseline + drift | (no fix verbs — diff-only; surfaces drift, the fix verb is decided per finding) |
| (a11y axis cross-cutting) | `lift-contrast`, `align-focus-ring`, `clarify-affordance` |

These verbs operate at scale — `consolidate-tokens` typically touches 20–50 sites in one fix, vs align's per-site `replace-with-shared`. `validate-polish-artifacts.sh § check_frontend_verb_vocabulary` rejects any `closure_verb:` outside the 19-verb set.

## Phasing strategy — by USER FLOW

Unlike align's class-based phasing ("phase 1: dead code, phase 2: silent catches"), `/ui-sweep` phases by **user flow**:

```
Phase 1 — Foundation (project-wide)
  Token consolidation (all categories)
  Component utilization (all wrappers)
  → Touches every page; do first because subsequent phases reuse the cleaned tokens/wrappers.

Phase 2 — Auth flow
  Login + Signup + Password Reset + MFA
  → All UI/UX work (hierarchy, ui-states, responsive, language) for these pages together.

Phase 3 — Onboarding flow
  First-run wizard + tenant setup + verification

Phase 4 — Core flows (per project; e.g., orders / checkout / etc.)
  Cart → Address → Payment → Confirmation
  → All visual work for the critical revenue path together.

Phase 5 — Dashboard + Navigation
  Sidebar, header, dashboard widgets, settings entry-points

Phase 6 — Long tail
  Settings, profile, integrations, admin

Phase K — Visual polish (--with-iterate)
  design-iterate per page-domain to refine the cleanup
```

This grouping is meaningful because a user flow is reviewed END-TO-END (the user EXPERIENCES a flow, not a class). Doing all UI/UX work for one flow at once produces cohesive results.

## HTML visual report

End-of-sweep output: `ai/ui-sweep/report-<YYYY-MM-DD>.html`. Includes:

- **Per-page section**: screenshot at 3 breakpoints, hierarchy score, ui-state coverage, drift vs baseline.
- **Coverage dashboard**: token / component / ui-state coverage % with target lines, plus the `rendered / skipped / blocked` route count (BLOCKED auth-gated routes are excluded from every coverage %, never scored as `pass`).
- **Cross-surface matrix**: visual table of pages × surface-type-conformance.
- **Phase-by-phase progress**: pages × phases with status.
- **Top 10 worst surfaces**: ranked by combined score.
- **Recommendations**: per-phase next steps, with estimated effort.

Browse-able. Shareable with PMs / designers.

## Pre-requisites

- `PROJECT_KIND` is `frontend-*`.
- `_extracted-idioms.md` populated with: design tokens (per category), shared wrappers list, surface-type prototypes, voice guide (optional), responsive breakpoints.
- Playwright MCP wired (the `visual-check` skill (frontend pack) works) — for screenshots + DOM analysis. `visual-check` carries the authenticated + blocked-render contract the ui-ux design commands standardize on.
- **Authenticated session for auth-gated routes.** Capturing / scoring dashboard · orders · settings (anything behind login) requires a real session (`storageState` / a login step — see `visual-check`); a headless browser with no session renders the login wall, and a page scored against a login-wall screenshot is unverified. A blocked render HALTs — it is NOT "no harness". See the auth Hard rule below.
- Mechanical CI green at HEAD.
- Working tree clean.

## Optional flags

- `<phase>` — run a specific phase. Default: walks workflow (no scan → scan; scan done → plan; plan done → next phase).
- `--first-run` — caps at 5 pages per detector for first sweep (manageable scope).
- `--scope=<path>` — restrict to a sub-tree (e.g., `--scope=src/modules/orders/`).
- `--with-iterate` — after each flow phase, dispatch design-iterate per page in the flow.
- `--detector=<list>` — narrow detectors (e.g., `--detector=hierarchy,token-coverage`).
- `--breakpoints=<list>` — override the responsive matrix (default: 360,768,1280).
- `--baseline-only` — capture baseline screenshots; no detection. Use to set the first baseline.
- `--report-only` — re-generate the HTML report from existing ledger; no scan.
- `--allow-dirty` — proceed with uncommitted changes.
- `--plan` — run the read-only phases through PLAN, write the tool-agnostic fix plan to `.claude/plans/`, stop before FIX (universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md)).

## Phase 1 — Understand

### Intent gate

Halt with redirect if:
- Description contains "fix bug" / "broken" → `/fix-bug`.
- "add new" / "create" → `/add-feature`.
- "structural cleanup" / "dead code" / "SOLID" → `/align-scan`.
- "single area" / "just the sidebar" → `/enhance-ui`.

Proceed for project-wide UI/UX work.

### Inputs

- Phase arg (optional).
- Flags above.
- `_extracted-idioms.md` — read for token system + wrapper inventory + surface-type prototypes.
- Playwright MCP — required for visual detection.

## Phase 2 — Organize

```
1. PRE-FLIGHT       — frontend stack, Playwright, idioms, clean tree
2. SCAN             — run 8 specialist detectors in parallel + capture visual baseline
3. METRICS          — compute coverage % per category; surface gaps
4. PLAN             — phase by user flow (foundation → auth → core → dashboard → tail)
5. FIX              — per phase, dispatch UI/UX-specific verbs (consolidate-tokens, unify-component, etc.)
6. VERIFY           — Playwright re-screenshot; compare against pre-fix; coverage re-measured
7. (--with-iterate) — design-iterate per page in the phase's user flow
8. REPORT           — generate / update ai/ui-sweep/report-<date>.html
```

## Phase 3 — Retrieve

- `_extracted-idioms.md` § Tokens / Wrappers / Surfaces / Voice / Breakpoints.
- Project's design-token file (`tokens.json` / `theme.ts` / Tailwind config).
- Locale tree (for voice / i18n cross-checks).
- Prior `ai/ui-sweep/baseline/` (for drift comparison).
- Prior `ai/ui-sweep/ledger.md` (if exists; tracks UI/UX-specific findings separately from align ledger).

## Phase 4 — Generate

The 8 detectors produce findings into `ai/ui-sweep/ledger.md` — UI/UX-specific schema:

```yaml
- id: U001
  detector: token-coverage
  category: color
  affected_sites: [src/.../*.vue:line × 47 sites]
  current_coverage: 73%
  target_coverage: 95%
  closure_verb: consolidate-tokens
  consolidation: "5 distinct hex values (#3b82f6, #3a83f7, #4090ff, #3b82f5, #4083f6) → $primary"
  estimated_impact: "+22% coverage"
  flow: foundation
  status: detected

- id: U042
  detector: hierarchy
  page: src/modules/orders/pages/OrderListPage.vue
  hierarchy_score: 62/100
  issues:
    - "Primary action 'Add Order' competes with secondary 'Filter' (same color/weight)"
    - "h1 missing; h2 used as page title"
  closure_verb: normalize-hierarchy
  flow: orders
  status: detected
```

## Phase 5 — Update

- `ai/ui-sweep/ledger.md` — UI/UX-specific findings (separate from align's ledger to avoid mixing structural + visual concerns).
- `ai/ui-sweep/ledger.md § render-coverage` — the reason-coded SKIPPED/BLOCKED rows + the `rendered N / skipped M / blocked K` count line (a login-wall render is recorded BLOCKED here, never as a scored baseline; BLOCKED routes are excluded from every coverage %).
- `ai/ui-sweep/baseline/<iso>/` — screenshots.
- `ai/ui-sweep/hierarchy/` — hierarchy heatmaps.
- `ai/ui-sweep/report-<date>.html` — generated report.
- `ai/_history.md` — `<iso> ui-sweep <phase> | findings=<N> | coverage-delta=<...>`.

## Phase 6 — Validate

- Per detector: re-run after fix; metric must improve.
- Visual regression: post-fix screenshots compared against pre-fix; ALL drift either expected (the fix) or zero.
- a11y / bundle / coverage from underlying align gate.
- Coverage targets met or progress documented.

## Phase 7 — Improve

- Coverage targets become trends over time — surface "Q1 token coverage 73% → Q2 89% → Q3 96% (target met)".
- Pages chronically below hierarchy score 80 → flag for design review, and when the fix is structural (not token-level) hand the surface to re-composition: `/redesign` (rebuild inside the existing visual language) or `/art-direct` (when it needs a new language).
- Drift above 30% from baseline without explanation → halt, surface "unexpected visual change since last sweep — was this intentional?"

## Hard rules

- **Frontend only.** Halts on non-frontend.
- **Playwright required.** No screenshots = no visual detection. Halts if MCP missing.
- **Authenticated session before capturing / scoring auth-gated routes.** After login, load a KNOWN-authenticated route and assert the URL ≠ the login path AND a known post-auth element is present. If that assertion fails → **HALT** with `RENDER BLOCKED — establish an authenticated session (storageState / login step) and re-run`. Then PER ROUTE, detect a runtime redirect to the login wall or a 403 → mark that route **BLOCKED**, never a clean `low` / `pass` — a login-wall screenshot must never feed a hierarchy score, drift %, coverage number, or the coverage-dashboard summary. Distinguish the two honestly: harness present but blocked = HALT (or per-route BLOCKED); NO harness at all = SKIPPED (the Playwright-missing halt above). Emit a reason-coded SKIPPED/BLOCKED ledger (`permission-blocked` / `redirected-to-login` / `dynamic-param-no-seed` / `full-screen-editor`) into `ai/ui-sweep/ledger.md` + a `rendered N / skipped M / blocked K` count line in both the ledger and the terminal summary — a silently-dropped route reads as "covered" when it wasn't.
- **UI/UX ledger separate from align ledger.** Different concerns; mixing them blurs phase progress.
- **Coverage metrics quantified, not subjective.** Every finding includes a measured coverage % and target.
- **Phasing by user flow, not by class.** A flow ships UI-cohesive together.
- **Visual baseline mandatory for first sweep.** `--baseline-only` if you want to set baseline before scanning.

## Failure modes

- **Playwright not wired** (NO harness) → halt; route to install MCP + the `visual-check` skill (frontend pack). This is SKIPPED-class, distinct from the BLOCKED render below.
- **Auth-gated route renders the login wall** (redirect / 403 / post-auth marker absent) → mark that route **BLOCKED**, never scored `low` / `pass`; if the up-front session assertion fails, the whole run HALTs with `RENDER BLOCKED — establish an authenticated session and re-run`. A login-wall screenshot must never become a page baseline or feed drift %. See the auth Hard rule.
- **No tokens in idioms** → halt; route to `/setup-project --refine` to populate token inventory.
- **No surface prototypes in idioms** → cross-surface consistency detector skipped (warned).
- **Too many findings on first sweep** (> 500) → recommend `--first-run`.
- **Coverage targets not defined** → use defaults (95% tokens, 90% utilization, 100% ui-states); flag for project to override in idioms.

## Examples

```bash
# First sweep on a project (sane defaults)
/ui-sweep --first-run

# Set visual baseline only (no detection; first time)
/ui-sweep --baseline-only

# Walk the workflow (next pending phase)
/ui-sweep

# Specific phase
/ui-sweep 3

# Add visual polish per page after cleanup
/ui-sweep --with-iterate

# Run only the hierarchy + token-coverage detectors
/ui-sweep --detector=hierarchy,token-coverage

# Restrict to one module
/ui-sweep --scope=src/modules/orders/

# Re-generate report from existing ledger (no scan)
/ui-sweep --report-only
```

## Related

### UI-UX command map (which one to reach for)

The ui-ux pack has ten commands; the nine general-purpose ones are below (the tenth, `/add-theme-variant`, is the multi-theme-only specialist — adds a new theme slot; see its own docs). They differ by intent, scope, and whether they write. (The global `/polish` also routes `frontend-*` into the same 19-verb vocabulary, but it is the simple-surface front door, not a ui-ux specialist — see the note under the table.) Pick by the verb you actually want:

| Command | Intent | Scope | Writes code? |
|---|---|---|---|
| `/ui-crawl` | **detect** — Playwright crawl, axe a11y, console/network probes, ranked findings | project-wide (read-only) | NO (report only) |
| `/ui-crawl-fix` | **fix** — consume a `/ui-crawl` report, patch findings at the wrapper level | the crawled findings | YES |
| `/ui-sweep` (this) | **deep** — specialist sweep with quantified metrics + HTML visual report + baselines | project-wide | YES (FIX phase) |
| `/enhance-ui` | **iterate** — visual polish + variant exploration on ONE area | single surface | YES |
| `/design-review` | **audit** — cite-or-halt review of changed UI (UX + design-system + a11y) | changed files / screenshot | NO (audit only) |
| `/redesign` | **re-compose** — rebuild a page/flow's structure INSIDE the already-decided visual language | one surface / flow | YES |
| `/art-direct` | **direct** — invent + score a NEW visual language from product goals, then build it | scope arg | YES (designs then builds) |
| `/grab-site` | **grab** — faithfully mirror a live site into real static HTML/CSS (real assets, opens offline) | an external URL | YES (new folder) |
| `/clone-design` | **clone** — extract a reference's design SYSTEM into brand-neutral HTML/CSS, verified by pixel-diff | an external URL / screenshot | YES (new folder) |

`/polish` (global, not a ui-ux specialist): the simple-surface front door that routes `frontend-*` into the same 19-verb vocabulary — scope arg or whole project, writes code.

Rule of thumb: detect with `/ui-crawl`, fix routine findings with `/ui-crawl-fix`, go deep + measurable with `/ui-sweep`, polish/explore one area with `/enhance-ui`, gate a change with `/design-review`. When a surface scores **below floor** (hierarchy < 80, systemic cross-surface drift) and the fix is structural rather than token-level, hand it off to re-composition — `/redesign` to rebuild it in the existing visual language, `/art-direct` when it needs a new language rather than a rework. For a full external site, `/grab-site` (faithful real-asset mirror) or `/clone-design` (brand-neutral design system). The global `/polish` is the simple-surface entry into the same 19-verb vocabulary.

### Sibling commands
- `/enhance-ui <description>` — single-area version.
- `/design-review` — read-only audit (different focus: cite-or-halt findings).
- `/align-scan` — structural quality (orthogonal to this command).

### Skills
- `ui-design-sweep` — closed 19-verb closure vocabulary (the spec this command's 8 detectors dispatch into).
- `design-iterate` — visual variant generator (dispatched with --with-iterate).
- `visual-check` (frontend pack) — screenshots + DOM analysis (the required render harness); carries the authenticated + blocked-render contract this command's auth Hard rule enforces. If it is absent, fall back to the Playwright MCP directly under the same auth contract — never silently skip the render.
- `a11y-quick-check` (in-pack) — the a11y detector `/redesign` uses (focus order, labels, contrast, tap-targets); this command's a11y axis goes deeper but dispatches its primitives.

### Rules
- `.claude/rules/align-discipline.md` — closure-verb discipline (this command extends with UI/UX-specific verbs).

### Required project anchors
- `_extracted-idioms.md § Tokens` — design token system per category.
- `_extracted-idioms.md § Wrappers` — shared component inventory.
- `_extracted-idioms.md § Surfaces` — prototypical examples per surface type (list-page, detail-page, etc.).
- `_extracted-idioms.md § Breakpoints` — responsive breakpoints.
- `_extracted-idioms.md § Voice` (optional) — tone of voice guide.
