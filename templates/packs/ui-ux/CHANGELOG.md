# ui-ux pack — changelog

Release history for `templates/packs/ui-ux/`, newest first.

Hard rule **A27** requires every pack source to ship `_version.json` + `CHANGELOG.md`.
`_version.json` holds the machine-readable stamp (`version`, `released`, `min_setup_command`,
`deprecated`) plus a one-line `summary` of the current release; this file holds the prose record. It
was previously the `changelog` object inside `_version.json` — history buried in JSON string
literals, neither diffable nor greppable. Every entry below is reproduced verbatim; nothing was
condensed.

Some versions also carry a **Release narrative**. This pack kept a second, independent telling of
each release inside the `_version.json` `summary` string, and every release appended to it — by
v1.24.0 it had reached 22,498 characters nested nine `[prior <version>: …]` levels deep, all on one
JSON line. Each telling is preserved below under the version it describes, verbatim and unabridged.

## 1.24.0 — 2026-07-13

- BUILT-IN composite-surface table-stakes floor — origin: a coverage audit of the whole ui-ux pack
  against a block of pasted 'how to make Claude produce premium UI' best-practice advice
  (design-system foundations, always-include-states, art-direction/premium bar, design-critic,
  quantitative rubric, iterate-in-stages, multiple-directions, component-reuse,
  persistent-ai-context, complex-component-specs). Verdict: 9/10 clusters ALREADY covered, usually
  more rigorously than the source (16-axis catalog, 11-lens creative rubric with a mechanical
  divergence check, the render→critique→fix refine loop, cite-or-halt reviews). The deltas the pack
  lacks — named-brand benchmarks (Stripe/Linear), a subjective self-rated 9.5/10 rubric,
  eCommerce-specific guidance — are DELIBERATE principled exclusions (no-brand-clone /
  cited-not-vibes / generic-source), not gaps, so no change was made for them.
- The one genuine gap (complex-component-specs, PARTIAL): buttons + forms were fully specified, but
  there was no PROACTIVE completeness floor for two COMPOSITE surface types.
  skills/ui-design-sweep.md verb 19 `normalize-surface` compared a page against the project's
  `_extracted-idioms.md § Surfaces` prototype and — per its Inputs table — SKIPPED-with-warn when
  that (optional) section was unauthored, leaving data-table + dashboard with no generic fallback.
  Empirically confirmed by grep: `sticky-header` / `bulk-select` / `bulk-action` = 0 hits; `toolbar`
  appeared only as reactive region-coverage + a CTA-placement example; `export` only as PNG/Figma
  re-export; dashboard composition (metric tile / widget grid / quick-action / activity feed) = 0
  hits.
- Fix: verb 19 gains a `#### Built-in composite-surface table-stakes` subsection — a generic
  FALLBACK PROTOTYPE used when the project's § Surfaces section is absent (a project-authored
  prototype ALWAYS overrides; this is the floor, never a ceiling). DATA-TABLE floor =
  persistent/sticky header · toolbar (search/filter/sort) · row-selection + bulk actions · export ·
  pagination (or virtualized infinite scroll) · per-row hover/affordances · empty/loading/error
  (defer to verbs 9-11) · responsive stack-or-scroll-with-frozen-column. DASHBOARD floor —
  UNIVERSAL: labeled metric/stat tiles with trend/context (NOT bare numbers) · charts re-themed to
  the language (NOT library defaults) · widget/section grid with deliberate hierarchy · a
  period/time-range control when the data is time-bound; JOB-CONDITIONAL (count toward M only when
  the job includes it): recent-activity feed + quick-actions belong to an operational/home
  dashboard, an analytics/BI or monitoring dashboard legitimately has neither. And a few DATA-TABLE
  items (search/filter/sort/pagination) are cited as already floor-owned (ui-principles § Should ·
  ux-reviewer §9), not re-claimed as new content — the genuinely-new items are
  row-selection+bulk-actions, export, sticky header, per-row affordances, responsive frozen-column,
  and the composite N/M grade itself. (Both refinements applied after a read-only 3-lens adversarial
  review returned SHIP with these two minor precision nits.) FORM row cross-references ux-reviewer
  §5/§9 + design-system-architect (owned there, NOT re-specified here). The Inputs-table row for
  'Surface prototypes' was updated from 'skip if missing' to 'falls back to the built-in catalog' so
  the verb no longer self-contradicts.
- Discipline baked in to prevent enforcement-theater AND over-reach: (1) DETECT + REPORT — the verb
  emits a coverage finding `<surface> affordances: N/M present — missing: <list>`, it does NOT
  silently graft affordances; (2) SCALE-GATED candidacy — not every instance needs every affordance
  (a 5-row reference table needs no pagination/export/bulk), so absence is flagged as a candidate
  for the reviewer/user, triggered by the surface's scale (pagination/search/sort/filter are
  table-stakes only past ~50 items, per ui-principles § Should); (3) a genuinely-NEW affordance
  system (a bulk-actions system, export pipeline, new chart) is a FEATURE/RE-COMPOSITION out of verb
  19's re-paint/normalize boundary → HALT-and-surface, route to /redesign or /add-feature; (4) stays
  generic — export/bulk-select/sticky-header/metric-tile are generic data-management +
  status-surface affordances, no domain/product terms.
- Invariants held: this is verb 19's fallback prototype, NOT a 20th verb and NOT a 17th axis — the
  closed set stays 16 axes / 19 verbs (same status as the existing framework-control / chart
  carve-outs). The catalog is stated to never re-audit an axis the 16-axis catalog already owns.
- Wired into the review/grade path so the catalog is not an orphaned artifact: agents/ux-reviewer.md
  §9 (Flow and density) gains a composite-surface completeness bullet citing the catalog — and
  because /design-review AND /redesign Phase 6 both dispatch ux-reviewer, both paths inherit it;
  commands/redesign.md per-component audit notes it as a SURFACED /add-feature recommendation
  (explicitly NOT auto-added and NOT a below-bar blocker, because /redesign preserves feature parity
  and never grafts a new capability on its own); commands/design-review.md Phase 4 names it on the
  ux-reviewer dispatch line; rules/ui-principles.md § Axis catalog gains a 'companion floor' pointer
  stating surface-completeness is a per-SURFACE dimension owned by verb 19, NOT a 17th per-element
  axis (reinforcing, not threatening, the 16/19 invariant).
- Sync chain: skills/ui-design-sweep.md (catalog + Inputs fallback line) · agents/ux-reviewer.md ·
  commands/redesign.md · commands/design-review.md · rules/ui-principles.md · docs/COMMANDS.md
  (/design-review row) · _examples/ux-reviewer.md + _examples/design-review.md mirrors (the two
  abridged mirrors that carry the edited §9 + Phase-4 lines; _examples/ui-principles.md does NOT
  carry the axis-catalog block, so no mirror edit there) · _version.json. Unchanged (verified, not
  skipped): _essentials.md + _topics.md (no artifact role or section-list changed — the catalog
  lives under ui-design-sweep's existing `the_19_closure_verbs` section); docs/REFERENCE.md (carries
  no verb-19 or design-review-Phase-4 detail, and its /polish row's 15-axis list + verb count are
  unaffected); tool-adapters/_ui-ux-pack-coverage.md (the 19-verb / 16-axis roster at :161 is
  unchanged — verb 19 deepened, not added — generic class-based contract, no per-tool edit).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

BUILT-IN COMPOSITE-SURFACE TABLE-STAKES floor for ui-design-sweep's verb 19 `normalize-surface` —
closes the one genuine gap surfaced by a coverage audit of the pack against pasted 'premium UI'
best-practice advice (verdict: 9/10 already covered, usually MORE rigorously than the source; the
deltas the pack LACKS — named-brand benchmarks, a self-rated 9.5/10 rubric, eCommerce specifics —
are deliberate principled exclusions, not gaps). The hole: verb 19 graded a page against the
project's `_extracted-idioms.md § Surfaces` prototype but SKIPPED-with-warn when that section was
unauthored, so two COMPOSITE surfaces had no proactive completeness floor (grep-confirmed absent:
`sticky-header`/`bulk-select`/`bulk-action` = 0 hits; `toolbar`/`export`/`data-table` only as
reactive region-coverage or a primitive name; dashboard composition = 0 hits). Fix: verb 19 gains a
BUILT-IN generic fallback prototype used when the project hasn't authored its Surfaces section (a
project prototype ALWAYS overrides — floor, not ceiling): DATA-TABLE = sticky header · toolbar
(search/filter/sort) · row-selection + bulk actions · export · pagination · row states ·
empty/loading/error · responsive stack-or-scroll; DASHBOARD (universal) = labeled metric tiles (not
bare numbers) · charts re-themed to the language (not library defaults) · widget grid with hierarchy
· a period/time-range control when time-bound, with activity-feed + quick-actions JOB-CONDITIONAL
(count only for an operational/home dashboard, not analytics/BI or monitoring — an
adversarial-review precision fix so a fixed M doesn't false-positive); FORM = cross-referenced to
ux-reviewer §5/§9 + design-system-architect, NOT duplicated. A few data-table items
(search/filter/sort/pagination) are cited as already floor-owned (ui-principles § Should ·
ux-reviewer §9), not re-claimed as new. Emits `<surface> affordances: N/M present — missing: …`,
treats each miss as a SCALE-GATED candidate to surface (a 5-row reference table needs no
pagination/export/bulk), and routes a genuinely-new affordance system to /redesign or /add-feature —
never a silent graft. INVARIANTS HELD: it is verb 19's fallback prototype, NOT a 20th verb and NOT a
17th axis (16 axes / 19 verbs unchanged). Wired into the review/grade path (not orphaned):
ux-reviewer §9 (dispatched by /design-review AND /redesign Phase 6), redesign per-component audit
(SURFACED as a /add-feature recommendation, never a below-bar blocker — redesign preserves feature
parity), design-review Phase 4, and a companion-floor pointer in ui-principles.md § Axis catalog
(explicitly NOT a 17th axis). Sync: skills/ui-design-sweep.md (catalog + Inputs fallback line) +
agents/ux-reviewer.md + commands/{redesign,design-review}.md + rules/ui-principles.md +
docs/COMMANDS.md (/design-review row) + _examples/{ux-reviewer,design-review}.md mirrors.
_essentials.md / _topics.md unchanged (roles + section lists unchanged); no REFERENCE.md change (no
verb-19 / design-review-Phase-4 detail there); no adapter-roster change (generic class-based
contract; the 19-verb list at _ui-ux-pack-coverage.md:161 stays accurate).

## 1.23.0 — 2026-07-13

- commands/add-theme-variant.md — RE-SKIN-vs-NEW-DIRECTION fix, closing the '#1 my new theme barely
  changed' complaint: a built variant came back as the base theme RECOLORED (same layout, same
  sections, same order — only the token/SCSS block retuned), not a genuinely new look. Root cause:
  default + --skin are RE-SKINS by design (Flow steps 3+5 mirror the base's component set and retune
  tokens), and the Parity gate's 'counts must match' actively resisted re-composition — so even
  --reimagine only changed token DERIVATION (via /art-direct), never the layout.
- Modes honestly labelled (Args + a new Pillar-1 'RE-SKIN vs NEW DIRECTION' block): default and
  --skin = RE-SKIN — they mirror the base's layout + components and retune only tokens, so they read
  modern but stay the SAME composition ('same store, different palette') and will NOT change the
  look-direction or layout. --reimagine = the ONLY mode that produces a genuinely new look.
- --reimagine is now LICENSED TO RE-COMPOSE: it routes the direction through /art-direct AND
  rebuilds each surface via /redesign — new layout, reordered/regrouped/ADDED sections, a distinct
  visual language — and INHERITS their hard gates: (a) beats-the-old (rendered beside the base
  theme, the new must WIN on hierarchy·modern register·distinctiveness·craft·appeal; a tie or
  old-win HALTs), (b) re-composition not re-paint (the IA/section-order/grouping/layout archetype
  must actually DIFFER from the base — a mirror-with-new-tokens FAILS no matter how bold the
  palette), (c) one named loud move. A reimagine that renders ~identical to the base is HALTED, not
  shipped. Flow step 4 restated: under --reimagine, 'mirror the base's component set' (step 5)
  becomes 're-compose from the base's CAPABILITIES' — the components are raw material, not a layout
  to copy.
- Pillar 4 (Parity) reconciled: parity is FEATURE parity (no base capability dropped — every
  component/state/icon kept or moved/demoted/re-grouped/re-shaped), NOT layout parity.
  default/--skin keep the base structure → counts match exactly; --reimagine RE-COMPOSES and MAY ADD
  new section types the base never had → its count floor is '≥ the base's items, none dropped', and
  re-arranging or adding never fails parity (only dropping without a keep/move/drop record does).
  This removes the structural constraint that was capping how transformative a new theme could be.
- Flow step 1 (Frame) gains a mode-ambition check: if the request wants a genuinely
  new/bold/distinct theme ('new look', 'different', 'redesign', 'not just a recolor', or a reference
  design the user admires) but neither --reimagine was passed, SURFACE it and recommend --reimagine
  before building — the command never silently ships a recolor when a new look was wanted. Plus a
  matching Don't ('DON'T ship a RE-SKIN as a new theme when the user wanted a new LOOK') and
  Failure-mode ('--reimagine came back ~identical → it failed the beats-the-old + re-composition
  gates → HALT, regenerate bolder or route to /art-direct').
- Sync: docs/COMMANDS.md (add-theme-variant row — mode clarity: RE-SKIN vs the NEW-LOOK --reimagine
  gates + feature-not-layout parity) + docs/REFERENCE.md (mode-ceiling note) + _version.json.
  _essentials.md / _topics.md unchanged (command role unchanged). No adapter-roster change (generic
  class-based contract).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

/add-theme-variant RE-SKIN-vs-NEW-DIRECTION fix — closes the '#1 my new theme barely changed'
complaint (a built variant came back as the base RECOLORED, not a new look/layout). Root cause:
default + --skin are RE-SKINS by design (mirror the base theme's layout + component set, retune only
the token/SCSS block → same composition, new palette), and the Parity gate's 'counts must match'
actively RESISTED re-composition, so even --reimagine only changed token derivation, not the layout.
Fix: (1) modes are honestly labelled — default/--skin = RE-SKIN (won't change the look-direction or
layout; 'same store, different palette'), --reimagine = the ONLY mode that produces a genuinely new
look; (2) --reimagine is now LICENSED TO RE-COMPOSE — it routes the direction through /art-direct
AND rebuilds each surface via /redesign (new layout, reordered/regrouped/ADDED sections, a distinct
visual language), inheriting their hard gates: beats-the-old (rendered beside the base theme, must
WIN on hierarchy·modern·distinctiveness·craft·appeal), re-composition (IA/section-order/archetype
must DIFFER — a mirror-with-new-tokens FAILS), one named loud move — a reimagine that renders
~identical to the base HALTs, never ships; (3) Parity reconciled to FEATURE parity (no base
capability dropped — every component kept/moved/demoted/re-grouped/re-shaped), NOT layout parity —
so --reimagine may re-compose + ADD new section types the base never had (its count floor is '≥
base, none dropped', not 'identical structure'); default/--skin keep the base structure so their
counts still match exactly; (4) a Frame-step mode-ambition check recommends --reimagine when the ask
is 'new/bold/different/redesign/not-just-a-recolor' but the flag wasn't passed — the command never
silently ships a recolor when a new look was wanted; (5) a Don't + a Failure-mode codify 'reimagine
came back ~identical → HALT, regenerate bolder or route to /art-direct'. Sync: docs/COMMANDS.md
(mode clarity) + docs/REFERENCE.md + _version.json.

## 1.22.0 — 2026-07-13

- DESIGN-CLUSTER REMEDIATION wave 3/3 (final): crawl-path auth-honesty (T4), operational safety,
  reference-file coherence (T9), cross-pack qualification (T7), --plan handoff (T11), and the last
  cross-ref/count fixes — closing all remaining themes of the adversarially-verified 66-finding gap
  analysis across the 19-artifact design cluster.
- T4 auth-render BLOCKED = HALT on /ui-crawl + /ui-sweep: both rendered and SCORED auth-gated routes
  with no assertion the login succeeded and no per-route redirect detection, so an expired/failed
  session silently screenshot + axe-scanned the login WALL for every route and reported it clean — a
  fabricated critical=0 and corrupted every drift %, hierarchy score, and coverage number. Now: an
  up-front auth-success gate (load a known-auth route, assert URL≠login + a post-auth element; fail
  → RENDER BLOCKED HALT), a per-route guard (redirect-to-login / 403 → BLOCKED, never a clean
  low/pass, never fed to a screenshot/axe/coverage summary), and a reason-coded SKIPPED/BLOCKED
  ledger (permission-blocked / redirected-to-login / dynamic-param-no-seed / full-screen-editor) + a
  rendered-vs-skipped count line in both the findings artifact and the terminal summary. Honest
  distinction stated: harness-present-but-blocked = HALT / per-route BLOCKED; no harness at all =
  SKIPPED. /ui-crawl additionally gets a 'What to do next' tier→handoff footer (mechanical →
  /ui-crawl-fix; behavioral → human triage; whole-surface below-bar →
  /ui-sweep·/redesign·/art-direct) and its phantom 'inventory subskill' credit corrected to the real
  Phase-1 inventory step (lib/inventory.ts).
- T3 + operational safety on /ui-crawl-fix (the file with the most findings): the 'visual diff
  verifies' safety story for the two pixel-changing fix classes (contrast-token swap,
  raw→shared-component swap) was enforcement-theater — no phase actually rendered/compared pixels,
  only an axe/DOM re-scan blind to visual regressions. Now Phase-0 snapshots the input findings JSON
  (ai/audits/ui-crawl-findings.pre-fix.json) AND the before screenshots
  (tests/crawl/.screenshots-pre-fix/) so the re-crawl can't clobber the diff basis; Phase-3 computes
  a REAL before/after visual diff per affected route × breakpoint and prints rendered: VERIFIED /
  SKIPPED (BLOCKED) — never asserted in a Risk cell — plus a raw-key scan of the re-crawl. New
  gates: a clean-tree precondition (discrete per-class commits + git-revert rollback are only safe
  from a clean baseline; relaxed under --dry-run/--plan), an i18n-completeness gate (an injected
  aria-label i18n key must resolve in EVERY shipped locale or the raw key renders as the accessible
  name — a NEW a11y defect dressed as a closed finding), and a --plan handoff flag.
  align-discipline.md / /align-recheck / /align-fast qualified as (align pack) with a Phase-0
  degrade-or-HALT (never a silent no-op). Corrected the 19-vs-21-verb conflation: /ui-crawl-fix
  patches with align-discipline.md's 21-verb closure vocabulary (replace-with-shared / add-validator
  / …); /polish's frontend branch dispatches ui-design-sweep's SEPARATE, disjoint 19-verb DESIGN
  vocabulary — they share no verbs.
- T1/T7/T6/T11 on /ui-sweep: render-harness reference normalized verify-with-playwright →
  visual-check (frontend pack — the harness the ui-ux design commands standardize on, carrying the
  authenticated + blocked-render contract, with a fallback-not-skip note); a11y ref rewired
  a11y-scan → a11y-quick-check (in-pack); the 'Six commands touch UI surfaces' map refreshed to the
  real roster (nine general-purpose commands + /add-theme-variant noted as the tenth/multi-theme
  specialist; /redesign·/art-direct·/grab-site·/clone-design added; /polish relabeled a global
  front-door, not a ui-ux specialist; a below-floor→re-composition handoff to /redesign·/art-direct
  added); and a --plan flag added (read-only phases → write plan → stop before FIX), with
  ai/ui-sweep/ledger.md as the deep report-based handoff.
- redesign HIGH gate-coherence fix: --yes and --max-refine (used in the body, absent from Args) are
  now documented, and --yes's effect on the mandatory approval gate is pinned to resolve the
  contradiction — --yes is UNATTENDED VARIANT SELECTION ONLY (post-approval, design-iterate refine
  mode instead of a pick pause); it does NOT skip the proposal approval gate (that hard stop always
  stands; --plan is design-only; auto-approval only happens when composed under /art-direct --yes).
  Added the reciprocal /art-direct routing (intent gate + When-NOT-to-use + Cross-references —
  art-direct→redesign was fully wired but redesign→art-direct dead-ended a user wanting a new visual
  identity), and fixed the phase-5 gate-location mislabel (the gate sits INSIDE Phase 4, between the
  proposal step and the build step; Phase 5 is 'Update').
- creative-director: the Direction-rubric intro said 'nine lenses' while the table + scorecard have
  11 — corrected to eleven, naming the two lenses that grew the count (Beats-the-current +
  Re-composition) as the decisive superiority EXIT GATES (a Δ/✗ on either is disqualifying) and
  clarifying the rollup relationship (Beats-the-current is the one-cell rollup of the per-dimension
  before→after row, not a second independent point) so an implementer doesn't double-score.
- ui-principles: the § Axis catalog header/intro reframed from 'cited by ui-design-sweep closure
  verbs' to its actual DUAL role — the closed axis map the 19 verbs close against AND the pack-wide
  canonical usability FLOOR that creative-director / art-direct delegate to (self-check, never
  re-audit, no 17th axis) and redesign / enhance-ui / ux-reviewer score against — so a future editor
  can't silently narrow the section and break 4+ consumers. States the '16 axes / 19 closure verbs
  (counts differ on purpose)' invariant at source (matching ui-design-sweep). Cross-pack routing
  targets qualified (architectural-diagnosis / refactoring-sweep = code-quality pack; align-recheck
  = align pack).
- T9 anchor hygiene: every brittle numeric cross-file anchor across art-direct.md +
  creative-director.md — redesign.md:NNN (keep/move/drop, shared-components, rollback),
  design-system-architect.md:156 (token cap), ui-principles.md:87 (no-17th-axis) — several ALREADY
  stale after waves 1-2 shifted those files' line numbers — converted to STABLE named-section
  anchors (e.g. 'redesign.md § Failure modes — keep/move/drop', 'ui-principles.md § Axis catalog',
  'design-system-architect.md § Token contract guidance') so the next edit can't silently
  re-invalidate them.
- Sync chain: docs/COMMANDS.md (redesign gains --yes/--max-refine + /art-direct routing;
  ui-crawl-fix gains --plan + snapshot/visual-diff/clean-tree/i18n notes; ui-sweep gains --plan +
  auth-BLOCKED note) + tool-adapters/_ui-ux-pack-coverage.md (the bogus '12 UI/UX verbs' — which
  listed FABRICATED names add-mobile-affordance / fix-responsive / normalize-typography that are not
  in the set — corrected to the canonical 19 verbs across 16 axes, cited to ui-design-sweep.md § The
  19 closure verbs) + _version.json. _essentials.md / _topics.md unchanged (roles/fallbacks
  unchanged). No adapter-roster change (generic class-based contract). Waves 1-3 executed via three
  per-artifact editor fan-outs with canonical-block briefs + hand-authored gate-semantics/anchor
  fixes, each diff reviewed against the house standard before commit.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

DESIGN-CLUSTER REMEDIATION (wave 3/3, final) — crawl-path auth-honesty + reference-file coherence +
cross-pack qualification, closing the remaining themes of the 66-finding gap analysis. Auth-render
BLOCKED = HALT (T4): /ui-crawl + /ui-sweep rendered/scored auth-gated routes with no login-succeeded
assertion, so an expired session silently screenshot + axe-scanned the LOGIN WALL for every route
and reported a fabricated critical=0 / corrupted drift% — both now assert an authenticated session
up-front (load a known-auth route; URL≠login + post-auth element present, else RENDER BLOCKED HALT),
mark a per-route redirect/403 BLOCKED (never a clean 'low', never fed to a screenshot/axe/coverage
number), and emit a reason-coded SKIPPED/BLOCKED ledger + a rendered-vs-skipped count line so a
dropped route never reads as 'covered'. /ui-crawl adds a 'What to do next' tier→handoff footer
(mechanical → /ui-crawl-fix · behavioral → human triage · whole-surface-below-bar →
/ui-sweep·/redesign·/art-direct) + fixes the phantom 'inventory subskill' reference → the real
Phase-1 lib/inventory.ts step. /ui-crawl-fix (T3 + operational safety): its 'visual diff verifies'
safety claim for the pixel-changing fixes (contrast-token + raw→shared swaps) was
enforcement-theater — no phase rendered pixels — now wired to a REAL before/after visual diff
(rendered: VERIFIED/SKIPPED, never asserted in a Risk cell) against a Phase-0 screenshot snapshot; +
a clean-tree precondition, an i18n-completeness gate (an injected aria-label i18n key must resolve
in EVERY shipped locale, and the re-crawl is grepped for raw keys — a raw key on screen is a
FAILURE, not a closed finding), a pre-fix findings-JSON snapshot so the re-crawl can't clobber the
diff basis, a --plan handoff flag, align refs qualified as (align pack) with a Phase-0
degrade-or-HALT, and the 19-vs-21-verb conflation corrected (ui-crawl-fix patches with align's
21-verb closure set; /polish dispatches ui-design-sweep's DISJOINT 19-verb DESIGN set). /ui-sweep
gains --plan + normalizes its render-harness reference (verify-with-playwright → visual-check,
frontend pack) + a11y-scan → a11y-quick-check (in-pack) + a refreshed command map (the real
ten-command roster; /redesign·/art-direct·/grab-site·/clone-design added; /polish relabeled
global-not-specialist; a re-composition handoff added). redesign (HIGH gate coherence): --yes +
--max-refine are now DOCUMENTED in Args with --yes's exact semantics pinned — unattended VARIANT
step only, it does NOT skip the mandatory proposal approval gate (resolving the 'unattended' vs
'never skip the gate' contradiction) — + an intent-gate / When-NOT / Cross-references branch to
/art-direct (the reciprocal of art-direct→redesign, previously one-way) + the phase-5 gate-location
mislabel fixed. creative-director: the Direction-rubric intro's '9 lenses' corrected to 11 (the two
superiority exit-gate lenses named + the rollup-vs-double-count relationship clarified).
ui-principles: the § Axis catalog reframed to state its DUAL role (the closed 19-verb map AND the
pack-wide delegated usability FLOOR creative-director/art-direct/redesign/enhance-ui/ux-reviewer
depend on) + the '16 axes / 19 verbs' invariant stated at source + cross-pack routing targets
qualified. Anchor hygiene (T9): every brittle numeric cross-file anchor across art-direct +
creative-director (redesign.md:NNN / design-system-architect.md:NNN / ui-principles.md:NNN — several
already stale from waves 1-2's line shifts) converted to STABLE named-section anchors. Sync:
docs/COMMANDS.md (redesign / ui-crawl-fix / ui-sweep flag lists + auth notes) +
tool-adapters/_ui-ux-pack-coverage.md (the bogus '12 UI/UX verbs' with fabricated names
add-mobile-affordance/fix-responsive/normalize-typography corrected to the canonical 19 verbs / 16
axes, source-cited) + _version.json. Completes the 3-wave remediation of all 66 verified findings
across the 19-artifact design cluster.

## 1.21.0 — 2026-07-13

- DESIGN-CLUSTER REMEDIATION wave 2/3 (T2 — the single highest below-floor gap): the
  framework-control + chart-config RE-THEME discipline, fully articulated upstream in redesign.md
  (Phase 3 charts + Phase 6 'framework component-library controls are the #1 miss'), is propagated
  DOWN to the specialists that actually build / theme / fix — add-theme-variant, theme-specialist,
  ui-design-sweep, design-iterate — which had never inherited it. Root cause: a design-token / theme
  layer does NOT reach a component library's internals (PrimeVue/MUI/Ant/Vuetify/Radix/shadcn — the
  filter/control bar) or a chart's config object (Chart.js/ECharts/Recharts/ApexCharts/D3), yet
  every parity gate marked a default-styled control/chart 'present ✓' by file existence and every
  fix verb blind-swapped a chart's config hex.
- add-theme-variant + theme-specialist (BUILDER + AUDITOR): the Parity gate and the audit now
  enumerate framework-library controls and charts as two first-class parity item classes graded FROM
  THE RENDER — a library control confirmed to pick up the new slot via explicit
  :deep()/::v-deep/CSS-var overrides of its inner classes (.p-button/.p-inputtext/.p-highlight), and
  every chart re-themed in its config (series/dataset colors, grid/axis, ticks/labels, legend,
  tooltip, no-data). A control or chart still in the default/base palette is a Parity FAILURE, not
  present ✓ (counts must match AND every control+chart reads themed-from-render). The Visual gate
  gains an adversarial per-component audit mirroring redesign.md Phase 6 (separate critic =
  ux-reviewer, never the builder self-grading; each component defaults below-bar, ✓ justified from
  the screenshot; bounded refine loop on the new slot's OWN styles; no-harness → SKIPPED,
  blocked-auth-render → HALT).
- add-theme-variant + theme-specialist additive-invariant fixes: the Additive gate's whitelist
  prefix is now the DETECTED slot root (${SLOT_ROOT}/<name>/ from the Phase-2 inventory), not a
  hardcoded ^themes/ — on a src/theme / resolver / whitelist layout the literal prefix false-HALTed
  the new slot's own files. A stack-scope HALT (primary_frontend_framework_detected;
  backend/data-only → point at the frontend repo) is added to BOTH the builder and the standalone
  auditor jobs, ordered before the multi-theme-slot check. The shared-layer escape hatch is honored
  end-to-end: a globally-themed component-library control or a hardcoded shared chart config cannot
  be re-themed additively, so it is surfaced as an architecture/parity LIMIT (report + route the
  shared restyle to /art-direct), never a shared-layer edit — the Additive gate HALTs that.
- ui-design-sweep: the fix verbs (consolidate-tokens / apply-type-scale / lift-contrast /
  align-focus-ring / normalize-motion) gain a library-control + chart CARVE-OUT — when the target is
  a component-library control the fix is explicit :deep()/::v-deep/CSS-var overrides on the
  library's inner classes (graded first-class from the render); when it is a chart the fix re-themes
  the config object (never blind-replacing a config literal with a var() a canvas chart can't
  resolve — which the visual-baseline oracle reverts+halts). This is a carve-out on EXISTING verbs,
  NOT a 20th verb (the closed set stays 19 verbs / 16 axes; unify-component covers PROJECT wrappers
  only). Its out-of-scope rule + References now route re-composition findings
  (IA/grouping/order/rhythm reshaped) → /redesign·/art-direct and whole-surface rethink →
  /design-review (recompose-not-repaint, mirroring redesign lens 15). The visual-baseline
  required-vs-warn-only range is made deterministic: baseline REQUIRED for verbs 1-8 + 12-19
  (align-focus-ring's :focus-visible ring IS a rendered change, not an exception);
  render-but-not-equivalence for the state-wiring verbs 9-11; the ONLY warn-only case is Playwright
  unavailable (whole skill degrades, rows → pending-review). Render-harness reference normalized
  from verify-with-playwright to visual-check (the harness the ui-ux design commands standardize on,
  carrying the authenticated/blocked-render contract).
- design-iterate refine mode: step 3 gains a fix-LAYER note that a token edit reaches neither a
  chart nor a library control — a below-bar chart is fixed in the chart library's config/options
  object (re-theme series/axis/grid/legend/tooltip), and a below-bar framework library control is
  fixed by :deep()/::v-deep/CSS-var overrides on its inner classes, NOT by rewrapping (rewrapping is
  for a raw native <select>; you :deep() a PrimeVue Dropdown). When $SCOPE_TIER==token forbids that
  layer, it reports a residual Δ naming the fix that lives elsewhere, never a silent component edit
  and never a hidden ✓. Adds a Cross-references section (visual-check = the frontend-pack harness it
  inherits; creative-director; callers /redesign·/art-direct·/enhance-ui) + kind/pack frontmatter.
- design-system-architect (T3 honesty floor): the component-review table's A11y row is now COMPUTED
  (numeric contrast ratio vs AA for the actual fg/bg token pair, per interactive state, never an
  asserted 'pass') + a produced-artifact-or-SKIPPED floor line (a gate whose evidence wasn't
  produced prints SKIPPED, not ✓). Pre-flight reads ai/_extracted-idioms.md first in the
  audit-then-evolve path (CONDITIONAL, not a halt) — the synthesized oracle creative-director keys
  its direction off and the codified tokens must land back into — so both ends of the handoff read
  the same source. Related gains @creative-director (the upstream that hands codification here) + a
  Hands-off-to (/redesign, design-token-audit/@design-system-guardian, /art-direct).
- Executed as a fan-out of one editor per artifact with canonical Block-A (framework controls) +
  Block-B (charts) wording provided so the discipline reads identically across all 5 files,
  mirroring redesign.md/art-direct.md verbatim where load-bearing; each edit is additive (no
  existing content removed) and every added gate asserts a real render/computed artifact, not
  field-presence.
- Sync chain: docs/COMMANDS.md (add-theme-variant visual-gate row — now covers
  framework-control/chart re-theme + adversarial per-component audit) + _version.json.
  _essentials.md / _topics.md unchanged (artifact roles/fallbacks unchanged). No adapter-coverage
  roster change (generic class-based contract; the discipline travels inside the verbatim-shipped
  command prose). The bogus '12 UI/UX verbs' at _ui-ux-pack-coverage.md:161 vs the canonical 19/16
  is reconciled in wave 3 alongside ui-principles.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

DESIGN-CLUSTER REMEDIATION (wave 2/3) — propagates the framework-control + chart-config RE-THEME
discipline (redesign.md names framework-library controls 'the #1 miss') DOWN the whole build / theme
/ fix path, which had never inherited it. A design-token / theme layer does NOT reach a component
library's internals (PrimeVue / MUI / Ant / Vuetify / Radix / shadcn — the filter/control bar) or a
chart's config object (Chart.js / ECharts / Recharts / ApexCharts / D3), yet every parity gate
marked a default-styled control/chart 'present ✓' by file existence and every fix verb blind-swapped
a chart's config hex. /add-theme-variant + theme-specialist: the Parity gate + audit now grade
framework controls (:deep()/::v-deep/CSS-var overrides of inner classes) + charts (config re-theme:
series/axis/grid/legend/tooltip/no-data) as first-class parity items VERIFIED FROM THE RENDER — a
control/chart still in the default palette is a Parity FAILURE, not present ✓ — and the Visual gate
gains an adversarial per-component audit (separate critic = ux-reviewer, default below-bar, ✓
justified from the screenshot, bounded refine loop, no-harness = SKIPPED, blocked = HALT); the
Additive gate's whitelist prefix is now the DETECTED slot root (${SLOT_ROOT}/<name>/), not a
hardcoded ^themes/ (which false-HALTed on src/theme / resolver layouts); a stack-scope HALT is added
to BOTH builder + auditor jobs; the shared-layer escape hatch is honored throughout (a
globally-themed control or hardcoded shared chart config is an architecture/parity LIMIT to surface +
route to /art-direct, never a shared-layer edit the Additive gate would HALT). ui-design-sweep:
the fix verbs (consolidate-tokens / apply-type-scale / lift-contrast / align-focus-ring /
normalize-motion) gain a library-control + chart CARVE-OUT (fix via :deep() / config re-theme,
graded from the render) — a carve-out on EXISTING verbs, NOT a 20th verb (closed set stays 19 verbs
/ 16 axes); its out-of-scope escalation now routes re-composition findings → /redesign·/art-direct
(recompose-not-repaint) + whole-surface rethink → /design-review; and the visual-baseline
required-vs-warn-only range is made deterministic (align-focus-ring IS a rendered change, required;
only Playwright-absent is warn-only). design-iterate refine mode: a below-bar chart is fixed in its
config object + a library control by :deep() override (NOT rewrapping — the token tier reaches
neither), with a token-tier residual-Δ honesty path; +a Cross-references section (visual-check
frontend-pack harness, creative-director, callers) + kind/pack frontmatter. design-system-architect:
the review-table A11y row is COMPUTED (numeric ratio per interactive state, never an asserted
'pass') + a produced-artifact-or-SKIPPED floor line; pre-flight reads _extracted-idioms.md first in
the audit-then-evolve path (the oracle creative-director keyed the direction off);
+@creative-director sibling + a Hands-off-to. Also normalizes the render-harness reference to
visual-check in ui-design-sweep. Sync: docs/COMMANDS.md (add-theme-variant visual-gate note) +
_version.json; no adapter-roster change (generic class-based contract).

## 1.20.0 — 2026-07-13

- DESIGN-CLUSTER REMEDIATION wave 1/3 (the design REVIEW + ENHANCE path), from an
  adversarially-verified 66-finding gap analysis of all 19 design-cluster artifacts vs the quality
  floor set by redesign.md/art-direct.md (40 agents: 31-discipline floor → per-artifact audit →
  separate-critic verify → synthesis; 11 themes, 13-rank plan).
- T1 dangling-ref repoint (the pack's #1 defect class — enforcement-theater): /design-review
  dispatched `accessibility-auditor` (Phase 2 + Phase 4), an agent that ships ONLY in the frontend
  pack, as one of three parallel reviewers — so on a ui-ux-only install the entire a11y third of the
  review resolved to nothing while the pack's own a11y specialists sat unused. Now the a11y lane
  runs the in-pack `a11y-quick-check` skill + `ux-reviewer` (which already carries a WCAG 2.2 AA
  dimension); the frontend `accessibility-auditor` is kept only as an OPTIONAL deeper audit,
  explicitly gated on that pack being installed and never depended on. Same repoint applied to
  /enhance-ui (Related `a11y-scan` → `a11y-quick-check`; `bundle-analyze` qualified as frontend-pack +
  SKIPPED when absent), design-system-guardian + its _examples mirror (`/design-audit`, which
  never existed, → /design-review·/ui-sweep), a11y-quick-check + motion-audit
  (`@accessibility-auditor` escalations qualified as frontend-pack), and the design-review _examples
  mirror.
- T3 rendered-not-asserted honesty floor added to the review path: ux-reviewer gains a 'Rendered,
  not asserted' invariant (every a11y/contrast/state verdict verified from a real render; contrast
  COMPUTED per fg/bg pair per interactive state; un-rendered = SKIPPED; harness-present-but-blocked
  = RENDER BLOCKED HALT), and its pre-flight step 4 'describe what you'd want to see' (the
  imagination permission the pack floor forbids — the exact from-the-pixels grader role /redesign
  dispatches it into) is replaced with render-or-SKIPPED. /design-review computes contrast from the
  token pair at source level (no render) and prints `contrast: SKIPPED` when unresolvable.
  /enhance-ui gains the house Not-validated/Risks/Revert footer + per-consumer SKIPPED on unrendered
  routes. a11y-quick-check gains a coverage/honesty footer so a skipped screen-reader/keyboard lane
  never reads as clean.
- T5 self-contradicting copy-templates repaired: design-token-audit's '### Auto-fixable' output
  example printed the bare aggregate ('18 hardcoded colors → exact token match') that its own Halt
  condition bans — rewritten to per-row `<path:line> → token` form, and a new Halt requires a color
  swap's contrast be confirmed ≥ AA (delegated to a11y-quick-check) before it can be listed
  auto-fixable. motion-audit's exemplar asserted '30fps on mid-tier Android' with no profiling
  artifact + no path:line (violating two of its own Halts) — now carries `:64` + a Flipper-trace ref +
  a SKIPPED fallback; its reduced-motion rule self-contradicted (procedure >500ms vs exemplar >250ms)
  — reconciled to trigger-gated (interaction/scroll motion respects reduce-motion regardless
  of duration per WCAG 2.3.3; a single 250ms threshold applies only to incidental transitions).
- T6 cross-reference graph wired a generation forward: /enhance-ui gains a HALT intent-gate row +
  siblings routing 'redesign / rethink / re-theme / new visual language' → /redesign·/art-direct
  (the boundary was declared in prose but never gated, so a re-theme request was silently absorbed
  as a structure-preserving enhance); /design-review gains a finding-class→command map
  (/align·/enhance-ui·/redesign·/art-direct); ux-reviewer gains @creative-director as sibling + a
  'Dispatched by' subsection (/design-review, /redesign); design-system-guardian gains 'Hands off
  to' (/design-review·/enhance-ui·/ui-sweep); design-token-audit + motion-audit gain
  consumer/fix-command handoffs.
- T8 stack-scope HALT added to /design-review (CONDITIONAL — never blocks a screenshot-only review,
  since the command is read-only + screenshot-capable) and design-system-guardian (backend/data-only
  → halt before the primitive scan). design-system-guardian also gains an `_extracted-idioms.md`
  overlay cross-check in pre-flight (non-halting).
- T10 frontmatter uniformity: /design-review gains `kind: command` + `pack: ui-ux` (was the sole
  ui-ux command missing them); the skill batch a11y-quick-check / motion-audit / design-token-audit
  gains `kind: skill` + `pack: ui-ux` to match ui-design-sweep.
- Sync chain: docs/COMMANDS.md (/enhance-ui row — intent-gate + honesty footer note) +
  docs/REFERENCE.md (intent-gate table gains the /enhance-ui → /redesign·/art-direct row) + the
  design-review & design-system-guardian _examples mirrors (only the changed lines, mirrors stay
  abridged). _essentials.md / _topics.md unchanged (artifact roles + fallbacks unchanged). No
  adapter-coverage change (no command-roster change; generic class-based contract covers it).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

DESIGN-CLUSTER REMEDIATION (wave 1/3) — the design REVIEW + ENHANCE path lifted to the pack's own
quality floor after an adversarially-verified 66-finding gap analysis (40 agents, 31-discipline
floor, 11 themes, 13-rank plan). Kills the #1 defect class (enforcement-theater — a mechanism that
dispatches into empty space): /design-review dispatched `accessibility-auditor`, a
FRONTEND-pack-only agent, as one of three parallel reviewers, so on a ui-ux-only install the entire
a11y third of every review resolved to NOTHING — now routed to the in-pack `a11y-quick-check` skill +
`ux-reviewer` (which already owns a WCAG 2.2 AA dimension), with the frontend agent kept as an
OPTIONAL deeper escalation gated on that pack being installed. /enhance-ui's Related `a11y-scan` +
`bundle-analyze` (also absent from ui-ux) → `a11y-quick-check` + a pack-qualified frontend
`bundle-analyze`; design-system-guardian's periodic-audit command `/design-audit` (never existed) →
/design-review. Adds the rendered-not-asserted honesty floor to the review path: `ux-reviewer` gains
a 'Rendered, not asserted' invariant (contrast COMPUTED per fg/bg pair per state; un-rendered =
SKIPPED; harness-present-but-blocked = RENDER BLOCKED HALT), retiring its 'describe what you'd want
to see' imagination permission — the exact from-the-pixels grader contract /redesign dispatches it
into; /design-review now COMPUTES contrast from the token pair (source-level, SKIPPED when
unresolvable); /enhance-ui gains the house Not-validated/Risks/Revert footer + per-consumer SKIPPED
on unrendered routes; a11y-quick-check gains a coverage/honesty footer so a skipped lane never reads
as clean. Wires the review→fix cross-reference graph a generation forward: /enhance-ui gains a HALT
intent-gate row + siblings routing 'redesign / rethink / re-theme / new visual language' →
/redesign·/art-direct (previously declared only in prose, never gated); /design-review gains a
finding-class→command map; ux-reviewer / design-system-guardian / design-token-audit / motion-audit
gain Dispatched-by / Hands-off-to handoffs. Repairs self-contradicting copy-templates that
neutralized their own halt: design-token-audit's '### Auto-fixable' example printed the bare
aggregate its own Halt bans (now per-row + a ≥AA contrast gate before any colour swap is
'auto-fixable'); motion-audit's exemplar asserted a frame-rate with no profiling artifact + no
path:line and its reduced-motion rule self-contradicted (>500ms vs the exemplar's >250ms —
reconciled to trigger-gated per WCAG 2.3.3). Adds a stack-scope HALT to /design-review (CONDITIONAL
— never blocks a screenshot-only review) + design-system-guardian, and frontmatter kind/pack to
/design-review + the skill batch (a11y-quick-check / motion-audit / design-token-audit). Sync:
docs/COMMANDS.md (/enhance-ui row) + docs/REFERENCE.md (intent-gate table) + the design-review &
design-system-guardian _examples mirrors.

## 1.19.1 — 2026-07-13

- grab-site bundled script — three empirically-proven bugs fixed + re-verified by running the script
  against a fixture and the real Ella store: (1) lazy `<img>` with a placeholder `src` + `data-src`
  produced a DUPLICATE `src` attribute, so per HTML5 the browser kept the FIRST (blank placeholder)
  and the real photo never showed — now the placeholder `src` is dropped and `data-src` is promoted
  to the single `src`; (2) `data-srcset` images were left as inert JS hooks (no `src`/`srcset`) =
  blank offline — now every srcset candidate is localized, `data-srcset`→`srcset`, and a fallback
  `src` is emitted; (3) the 'Capture gate' was enforcement-theater — `--pages` skipped it and a 200
  bot-wall/consent/empty-shell was written as a mirror with exit 0 — now a hard first-page fetch
  runs even under `--pages` and `sys.exit`s non-zero with CAPTURE FAILED on 404/error or a short
  bot-wall/empty shell (heuristic gated on page size so a real page mentioning 'captcha' in a widget
  is NOT false-flagged; verified Ella still grabs).
- grab-site further script hardening: page-relative asset URLs now resolve against the current PAGE,
  not the site root (deep template pages with relative refs localize correctly); non-Shopify sites
  fall back to harvesting the homepage's own nav links instead of emitting index + two /cart,/search
  404s; CSS/fonts are fetched BEFORE images so a tight `--max-assets` drops images (not the layout)
  and WARNs; default cap 600→800; the script now prints a real localization report (`localized:
  css=N img-refs=N img-assets=N · residual-remote-refs=N`) + `WARN` lines for no-CSS / no-images /
  cap-hit — so the Asset-localization / Offline-open / Template-coverage 'gates' are actually
  reported, not just asserted. Embedded ```python block in the command re-synced BYTE-IDENTICAL to
  the deployed .claude/scripts/grab-site.py.
- grab-site.md prose reconciled to the fixed script: mechanism (CSS-first, real capture HALT,
  data-src/data-srcset promotion, page-relative resolution, printed report), the Gates section
  (Capture = script-enforced HALT; the other three = script-reported, agent reads them), the 'What
  you see' example (real output lines), and the softened offline claim (primary CSS/fonts/images
  localized; residual secondary refs reported).
- clone-design routing + honesty (it was re-trapping the exact user grab-site was built for — a
  live-storefront 'same design' request got a placeholdered wireframe with zero pointer to
  grab-site): added a premise ⚠️ routing warning, a When-NOT-to-use entry, a comparison-table
  sibling note, and a Cross-references bullet all routing 'want the REAL site' → /grab-site;
  reconciled the wireframe-vs-pixel-match contradiction (Fidelity is STRUCTURAL —
  layout/colour/type/spacing — with content deliberately placeholdered); made the Fidelity score
  MEASURED-or-SKIPPED (no fabricated integer without the visual-check/Playwright harness); dropped
  the documented-but-unbuilt `--adopt=theme:shopify/wordpress` from args/flow/examples/output; named
  `--adopt=project`→/scaffold-project. When-to-use reworded to lead with 'brand-neutral design
  system' + a non-storefront example.
- art-direct: added an external-reference exit (When-NOT-to-use + Cross-references → /grab-site ·
  /clone-design; art-direct INVENTS from goals and ignores a handed-in reference site); the
  before→after superiority gate no longer silently passes under a SKIPPED render — it prints
  `before→after: NOT verified (no harness)` and treats superiority as unproven, keeping only the
  harness-independent Conviction + re-composition checks hard.
- Adapter-coverage: the six per-tool command brace-lists now include add-theme-variant +
  clone-design + grab-site (were frozen at 7 commands, implying those were unsupported on every
  non-Claude adapter while the deployed .opencode files show they ARE shipped). Source: adversarial
  multi-agent review (6 dimensions, 26 findings, 24 survived verification, 23 CONFIRMED).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

grab-site + clone-design + art-direct HARDENING (adversarial multi-agent review, 24 verified
findings fixed). grab-site's bundled script had real bugs proven by running it: lazy `data-src`
images wrote a DUPLICATE `src` so the browser kept the blank placeholder (real photo never showed);
`data-srcset` images were left as dead JS hooks (blank offline); the 'Capture gate' was theater
(`--pages` bypassed it and a 200 bot-wall/empty-shell was written as a mirror). All fixed +
re-proven on a fixture + real Ella: `data-src`/`data-srcset` now promote to ONE working
`src`/`srcset` (placeholder dropped), a real Capture HALT runs on the first page even under
`--pages` (short-page bot-wall heuristic that does NOT false-positive on a real page mentioning
'captcha'), page-relative assets resolve against the page (not site root), non-Shopify sites fall
back to nav-link discovery, CSS/fonts fetch before images so a tight cap never yields an unstyled
page, and the script prints a real localization report (css/img counts · residual-remote-refs ·
WARNs). Embedded block re-synced byte-identical to the deployed script. clone-design: now ROUTES
live-storefront 'same design' users to /grab-site (premise warning + When-NOT-to-use +
comparison-table note + Cross-references — it was one-directional, re-trapping the exact user
grab-site was built for); reconciles the wireframe-vs-pixel-match contradiction (fidelity is
STRUCTURAL, content placeholdered); the Fidelity score is now MEASURED-or-SKIPPED (no fabricated
'94' without a harness); the documented-but-unbuilt `--adopt=theme:shopify/wordpress` dropped,
`--adopt=project` names /scaffold-project. art-direct: adds an external-reference exit to
/grab-site·/clone-design (When-NOT-to-use + Cross-references) and stops the before→after superiority
gate from silently passing with no render harness. Adapter-coverage per-tool command lists now
include add-theme-variant/clone-design/grab-site (were stuck at 7).

## 1.19.0 — 2026-07-13

- NEW /grab-site <url> [out-dir] command — FAITHFULLY MIRROR a live website into a folder of static
  HTML/CSS that looks like the ORIGINAL: real HTML + real CSS + real images + real fonts, one page
  per TEMPLATE FAMILY, every remote reference rewritten to a local path so the folder opens offline.
  Distinct from /clone-design and born from a real miss: /clone-design's brand-safety placeholdering
  (logo→[LOGO], photos→grey boxes) produced a grey wireframe when a user pointed it at a real
  Shopify storefront and asked for 'the same design' — they wanted a GRAB (reproduce the real design
  as-is), not a design-system extraction. /grab-site is that grab; /clone-design remains the
  placeholdered-design-system tool.
- Executes a BUNDLED stdlib-Python mirror script (embedded in the command; materialized to
  .claude/scripts/grab-site.py and run — no pip / wget / httrack, only python3). It fetches with a
  real browser User-Agent; auto-discovers one page per template family (/collections/… · /products/…
  · /pages/… · /blogs/…/… · /cart · /search) from the homepage's links, or takes an explicit --pages
  list; for each page downloads the HTML, every <link> CSS (recursing into @import + url() for
  fonts/background images), every <img> src/data-src/srcset image, and background-image:url();
  rewrites every remote ref to a local assets/… path and copies lazy data-src into src so images
  render without JS; writes <template>.html per page + _gallery.html. Flags: --pages, --max-assets
  (runaway/size guard, default 600), --plan.
- 'All pages' = one page per TEMPLATE FAMILY, not every URL — a storefront's thousands of
  product/collection URLs share a handful of templates; the command grabs one representative of
  each. Four gates: Capture (non-200 / bot wall / blank shell = CAPTURE FAILED HALT, never mirror an
  error page), Asset-localization (the primary page's real CSS AND its <img src> images must resolve
  to local assets/, else it is not a mirror), Offline-open (pages render standalone; residual remote
  background/srcset variants reported, not hidden), Template-coverage (one per discovered family,
  missing families named). Verified working on new-ella-demo-07.myshopify.com: 6 template pages,
  ~247 real assets (400KB base.css, real logo + product photos, 3 woff fonts) localized.
- Honest limits stated up front (the nature of a static grab, not failures): JS interactions
  (sliders / add-to-cart / live search / mega-menu) are NOT live — it is a faithful VISUAL copy; and
  the mirror carries the source site's real content/images, legitimate as a starting scaffold or
  reference but the user must swap in their own brand/products before shipping — /grab-site does not
  exist to pass a site off as its original owner (out of scope). Stack-agnostic + project-optional:
  writes plain HTML/CSS into a folder, needs only python3, does not HALT on a backend/empty repo.
- Sync chain: _essentials.md (grab-site rationale — the faithful-grab sibling to clone-design's
  placeholdered system), _topics.md (grab-site command topic, fallback → commands/grab-site.md),
  docs/COMMANDS.md (UI-UX track row), docs/REFERENCE.md (TOC + /grab-site section),
  tool-adapters/_ui-ux-pack-coverage.md (now ten commands; command bullet + Claude Code file mapping +
  a translation responsibility: the bundled script must ship verbatim + execute, and the
  grab-vs-clone-design distinction must not be flattened).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

NEW /grab-site command — FAITHFULLY MIRROR a live website into a folder of static HTML/CSS that
looks like the ORIGINAL: real HTML + real CSS + real images + real fonts, one page per TEMPLATE
FAMILY (home/collection/product/cart/search/page/article, auto-discovered from the homepage's links
or an explicit --pages list), every remote reference rewritten to a local path so the folder opens
offline. This is a GRAB (reproduce the real design as-is), the deliberate opposite of /clone-design
(which extracts a brand-neutral design SYSTEM and PLACEHOLDERS the brand — that placeholdering is
why a clone-design run against a real storefront produced a grey wireframe, not the site). Executes
a BUNDLED stdlib-Python mirror script (no pip / wget / httrack — only python3): fetch with a real UA
→ auto-discover template pages → download each page's CSS (recursing @import + url() for fonts/bg) +
img src/data-src/srcset + background-image → rewrite all refs local + copy lazy data-src into src so
images show without JS → write <template>.html per page + _gallery.html. Four gates: Capture
(non-200/bot-wall/blank-shell HALTs — never mirror an error page), Asset-localization (the primary
page's real CSS AND its <img src> images must resolve to local assets/, else it is not a mirror),
Offline-open (pages render standalone; residual remote background/srcset variants are reported, not
hidden), Template-coverage (one page per discovered family, missing families named). Stack-agnostic +
project-optional (writes into a folder, needs only python3). Honest limits stated up front: JS
interactions (sliders/cart/live-search) are NOT live — it is a faithful VISUAL copy; and it carries
the source's real content, so swap your own brand/products in before shipping — not for passing a
site off as its original owner. Sibling to /clone-design: grab = the real site, clone-design = a
placeholdered design system.

## 1.18.0 — 2026-07-13

- NEW /clone-design <url-or-image> [out-dir] command — reproduce an EXTERNAL design reference as a
  folder of self-contained, framework-neutral HTML/CSS: every discovered page template + a named
  reusable section library, styled to a design-token system EXTRACTED from the reference. Ingest is
  two-mode: a URL → Playwright capture (computed styles + DOM + screenshots at 3 breakpoints =
  MEASURED signal); an image → vision extraction (INFERRED signal, flagged as lower-confidence).
  Distill clusters raw computed colors into semantic roles, detects the type-scale ratio + weights,
  snaps spacing to the reference's base unit, captures radii/elevation/breakpoints/container width,
  and enumerates repeated DOM structures into counted section partials. The only ui-ux command whose
  source of truth is OUTSIDE the repo (an external artifact) and whose success metric is FIDELITY to
  that reference measured from pixels — and the only one that is project-optional + stack-agnostic
  (Stage 1 needs no framework, no _extracted-idioms.md, not even a repo; it does NOT HALT on a
  backend/empty repo).
- Two-stage architecture (the command owns only Stage 1). Stage 1 = capture → build → verify: build
  the folder (tokens.css, sections/*.html each once, one <page>.html per template composing
  sections, a design-system.html pane with @dsCard cards, an index.html gallery), then render each
  built page and perceptually diff it vs the reference, looping (fix worst region → re-render →
  re-diff) up to --max-refine (default 3) until it clears --fidelity (default 90). Stage 2 = adopt,
  DELEGATED under --adopt and growing no new design machinery: =tokens → /add-theme-variant
  (extracted tokens as the new slot's direction); =pages → /redesign per surface with the clone as
  the reference; =theme:shopify/theme:wordpress → emit platform templates from the section library;
  =project → scaffold from the clone. Default (no --adopt) stops at the folder.
- Four gates. Capture (a blocked bot-wall / login / consent-gate / blank SSR shell HALTs — CAPTURE
  BLOCKED, never build a clone from an error page; no harness + URL ref + no screenshots also HALTs,
  never guess a URL's design unseen). Fidelity (HARD — per-page perceptual diff ≥ --fidelity
  cross-checked on color ΔE / type / spacing / layout, verified FROM THE RENDER; below bar after
  --max-refine = INCOMPLETE with the worst region named, never a faked ✓; a page graded from HTML
  instead of the screenshot is invalid). Self-contained (HARD — each page opens offline with no
  layout-blocking external request; a clone that only renders against the live origin's CDN fails).
  Brand-safety (HARD — reproduce the design LANGUAGE, placeholder the IDENTITY: logo → [LOGO],
  brand/product names → a neutral placeholder, marketing copy → generic, photography → labelled
  placeholders; a leaked verbatim brand string / hotlinked logo is flagged + replaced; a deceptive
  1:1 counterfeit of a real brand's live site is explicitly out of scope).
- Flags: --pages=<list> / --all-routes (page-set scope; default is the primary set — home + one
  representative per detected template family), --sections-only (tokens + section library, skip page
  assembly), --fidelity=<0-100>, --max-refine=<n>, --adopt=<tokens|pages|theme:<platform>|project>,
  --plan (write the capture plan + exit before building). Cross-refs /redesign + /add-theme-variant
  (the --adopt delegates) and /art-direct (the sibling for when there is NO external reference).
  Reuses visual-check's Playwright capture/render harness (inherits its authenticated /
  blocked-render contract for the Capture gate) and design-system-architect for adopted-into-project
  token codification.
- Sync chain: _essentials.md (clone-design rationale — project-optional specialist, kept out of
  --minimal), _topics.md (clone-design command topic, fallback → commands/clone-design.md),
  docs/COMMANDS.md (UI-UX track row), docs/REFERENCE.md (TOC + /clone-design section),
  tool-adapters/_ui-ux-pack-coverage.md (now nine commands; per-tool command lists + a
  Capture-gate/Fidelity-gate/Brand-safety translation responsibility + adopt-delegation note).

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

NEW /clone-design command — clone an EXTERNAL design reference (a live URL or a screenshot) into a
self-contained folder of framework-neutral HTML/CSS: every page template + a reusable section
library, styled to a design-token system EXTRACTED from the reference (color roles clustered from
computed colors, detected type scale, spacing base unit, radii/elevation/breakpoints), then VERIFIED
by rendering each built page and perceptually diffing it against the reference until it clears a
fidelity bar. The only ui-ux command whose source of truth is OUTSIDE the repo and whose success
metric is fidelity-to-reference (measured from pixels, not taste) — and the only one that runs with
NO existing project (Stage 1 writes plain HTML/CSS into a folder, no framework/idioms required). Two
stages: Stage 1 (capture → build → verify) is the whole command; Stage 2 adoption is a delegated
`--adopt` follow-through (=tokens → /add-theme-variant · =pages → /redesign · =theme:<platform> →
emit platform templates · =project → scaffold) that grows NO new design machinery. Four gates:
Capture (a blocked bot-wall/login/blank-shell HALTs — never clone an error page), Fidelity (HARD —
per-page perceptual diff + color ΔE/type/spacing/layout, loops up to --max-refine, below-bar =
INCOMPLETE not faked), Self-contained (pages open offline, no live-origin dependency), Brand-safety
(HARD — reproduce the design LANGUAGE, placeholder the brand IDENTITY: logo/name/copy/photography →
placeholders; never a deceptive counterfeit of someone's live storefront).

## 1.17.1 — 2026-07-12

- /add-theme-variant parity-base fix: the new variant now mirrors the RICHEST/ACTIVE theme
  (whichever the resolver selects for the project, else the theme with the largest
  component/section/partial count) — NOT the folder literally named `default`. A project can carry a
  plain `default` fallback stub alongside the real rich active theme; basing the variant on the stub
  yields a theme whose sections all render empty (tokens swap but no section components exist). Flow
  adds an explicit 'pick parity base' step (count components across all themes, cite the choice) and
  a Model-B build note: copy the base theme's full component set + per-component style partials into
  the new slot, rewrite every internal `themes/<base>/…` path + `data-theme="<base>"` selector to
  the new slug, THEN retune tokens — so every section changes, not just CSS variables. Pillar 4 +
  the Parity gate now diff against the parity-base theme, not `default`.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

/add-theme-variant parity base fix — a new variant now mirrors the RICHEST/ACTIVE theme (by
resolver-selection or largest component/partial count), NOT whatever folder is named `default`. Root
cause of a real miss: a store carried a plain `default` fallback stub beside a rich `new_theme` (the
actual active theme); building the variant off `default` produced a theme where every section
rendered empty (only tokens changed, no section components). Flow gains an explicit 'pick parity
base' step + Model-B build note (copy the base's full component + per-component-style set into the
new slot, rewrite internal theme paths/selectors, THEN retune tokens). Pillar 4 + parity gate now
measure against the parity-base theme, not `default`.

## 1.17.0 — 2026-07-12

- NEW /add-theme-variant command — ADDS a new theme slot to a multi-theme app (a themes/<name>/
  system). Additive is the top invariant: creates a NEW slot only, never edits an existing theme or
  the shared cross-theme layer (a git-diff Additive gate enforces it). Builds along four gated
  aspects — Architecture (slot parallels default, resolution wired, SSR-safe, RTL-correct), Parity
  (item-by-item manifest diff vs the default theme: components/icons/states/layouts, counts must
  match, a miss falls back to default = invisible bug), Performance (project perf conventions +
  perf-check gate) — plus a visual gate. Design modes: default modern token system / --reimagine
  (routes the slot direction to /art-direct) / --skin. Multi-theme architectures only; single-theme
  projects redirect to /art-direct or /redesign.
- theme-specialist agent upgraded from parity-auditor to builder+auditor: gains the new-theme
  builder job (owns the four gates) alongside the retained existing-theme parity audit; tools gain
  Write.

**Release narrative** — migrated verbatim from the `_version.json` `summary` field:

NEW /add-theme-variant command + theme-specialist upgraded to builder+auditor — ADDS a new theme
slot to a multi-theme app (additive, never edits an existing theme or the shared layer), built
modern + technically-correct + fast + feature-complete-vs-default, each aspect a hard gate
(additive/architecture/parity/perf/visual). Multi-theme only. Icons are affordances, not decoration
— a redesign keeps them (the bug: the redesign stripped the KPI cards' recognition icons, hurting
scannability). Two enforcement points: (1) the Phase-1 component manifest now records every ICON
(each card's leading icon, action/button icons, section-header icons, nav icons, empty-state
illustrations), so the parity gate catches a silently-dropped icon; (2) the per-component visual
audit adds an 8th modern tell — purposeful iconography: existing recognition icons are KEPT and
restyled to the new language, an icon-barren redesign of a surface that had icons is a usability
regression + parity miss, and a component that lost its icon is below-bar.

## 1.16.1 — 2026-07-10

- art-direct.md: its build's inherited parity gate now names icons explicitly (art-direct builds by
  running /redesign, so all of redesign's gates — icons, parity, colour-fidelity, per-component
  audit — apply to art-direct too).

## 1.16.0 — 2026-07-10

- redesign.md Phase 1 manifest: every ICON is a manifest item (card icons, action/button icons,
  section-header icons, nav icons, empty-state illustrations) — icons are affordances, recorded so a
  redesign cannot silently strip them.
- redesign.md Phase 6 per-component audit: 8th modern tell — purposeful iconography (recognition
  icons kept + restyled, not stripped for a 'clean' look; an icon-barren redesign of an icon-having
  surface is a usability regression; a component that lost its icon is below-bar).

## 1.15.0 — 2026-07-10

- redesign.md Phase 3: extract the whole-app colour palette + the PERSISTENT CHROME
  (sidebar/header/nav/brand accent, from tokens + the baseline render) as a fixed constraint — for a
  single-page-in-a-shell scope every colour must come from the app palette or harmonize with the
  chrome; an off-palette colour (black button in a teal/navy app) is a failure.
- redesign.md Phase 6: colour-harmony gate verified from the render WITH the shell in frame — any
  off-palette colour clashing with the unchanged sidebar/header = INCOMPLETE (off-palette
  <element>); buttons/controls use brand accent + system neutrals; a new colour world must be
  app-wide or the scope was mis-set.
- creative-director.md: reimagine's colour world is app-wide or nothing — a page repainted in a
  different palette clashes with the persistent chrome; either apply app-wide or keep the app
  palette and reimagine everything else.

## 1.14.0 — 2026-07-10

- redesign.md Phase 1: build a COUNTED component/feature manifest (parity contract) — every KPI card
  by name, chart, table, filter/control, action, panel, state, with counts.
- redesign.md Phase 6: feature parity is now a HARD GATE verified from the render — diff the
  manifest item-by-item, print a parity table (present/MISSING/moved-to), a single MISSING component
  = INCOMPLETE (dropped <component>), counts must match, default KEEP, agent never drops on its own;
  re-composition may move/demote but must render every item.
- creative-director.md: reimagine may throw away the LOOK, never the JOBS AND never the COMPONENTS —
  deleting a card/table/filter to 'simplify' is a parity failure, not a design decision; freedom is
  over form, not the feature set.
- art-direct.md: new feature-parity gate in the build (inherits redesign Phase-6) — no dropped
  component, counts must match, drop only on explicit user approval; called out for reimagine
  specifically.

## 1.13.0 — 2026-07-10

- design-iterate refine mode: authenticate before rendering gated surfaces; a BLOCKED render (login
  wall/redirect/marker absent) HALTs the refine loop (cannot self-critique an unrendered page) — not
  a fall-through to SKIPPED.
- redesign.md: Phase-1 BEFORE baseline + Phase-6 render require an authenticated session for gated
  surfaces and HALT on a blocked render (distinct from no-harness SKIPPED); Playwright prerequisite
  updated. Per-component audit adds the framework-control-override rule (library controls don't
  inherit tokens; the filter bar is the #1 miss) + a two-valued honest render status
  (no-harness=SKIPPED, blocked=HALT).
- art-direct.md: authenticated-render + blocked=HALT hard build precondition (a saved
  login-blocked.png is a stop signal, not a pass); build-step-3 grades framework controls as
  first-class + two-valued render status; coverage gate adds framework component-library controls
  (the filter/control bar) as a must-cover region alongside charts + shared components.
- enhance-ui.md + /polish (orchestration): framework-control-override note — component-library
  controls need explicit :deep()/theme overrides; the token/theme layer does not reach them, so the
  filter/control bar counts as below-bar until overridden.

## 1.12.0 — 2026-07-10

- redesign.md Phase 6: new 'Per-component visual audit (adversarial, from the render, EVERY
  component)' gate — enumerate every distinct component in the screenshot and grade each from the
  pixels against 7 concrete modern tells; grader is a SEPARATE critic (ux-reviewer/fresh pass, never
  the builder self-grading); each component defaults to below-bar and earns ✓ only from the render;
  per-component table printed; loop CANNOT exit while any component is below-bar; a component graded
  from code (not the screenshot) is invalid; harness-absent = SKIPPED-not-verified. Wired into the
  refine-loop exit condition.
- design-iterate.md refine mode: step 2 gains the per-component pass (enumerate + grade each,
  defaults to below-bar, not a holistic 'looks modern'); step 3 fixes the worst below-bar component
  OR weakest lens; step 4 stop-condition now also requires no component below-bar.
- art-direct.md: build step 3 states it inherits the per-component audit via /redesign — cannot
  finish while any component is below-bar; without a harness, component quality is reported NOT
  verified rather than claimed.

## 1.11.0 — 2026-07-10

- redesign.md: Design-principles rubric +2 lenses — 14 'beats the previous version (before->after
  superiority)' scored against a rendered screenshot of the pre-run surface (win per-dimension or
  the redesign is not done; old winning any axis = INCOMPLETE), and 15 're-composition, not
  re-paint' (IA/grouping/order/hierarchy must change; same-skeleton restyle fails). Phase 1 captures
  a BEFORE baseline render + layout inventory. Phase 6 refine loop now loops while lens 14/15 aren't
  clearly green and prints a per-dimension new-wins/tie/OLD-wins verdict as the decisive exit gate.
  Hard rules add 'beat the OLD render, not just the rubric' + 're-compose, don't re-paint'.
- creative-director.md: +2 invariants (beats-the-baseline: win per-dimension vs the current surface,
  'different' is necessary not sufficient; re-compose-don't-re-theme: the IA archetype must differ
  from the current composition). Direction rubric +2 lenses (before->after superiority,
  re-composition). Converge renders each direction beside the current surface and refuses to
  recommend one the old design out-looks. evolve REDEFINED — a real redesign that re-composes +
  beats the old keeping only brand DNA, not a token retune; its before->after gate upgraded from a
  difference gate to a superiority gate. New duty: recommend reimagine-level ambition when redlines
  cluster on generic/dated/forgettable. Brief output gains a before->after row + the
  reimagine-escalation recommendation.
- art-direct.md: Premise now has FOUR hard anchors (added re-compose-not-re-paint +
  beat-the-old-not-merely-differ). The 'anti-timidity gate' became the 'before->after superiority +
  re-composition gate' — blocks the build unless the new WINS the per-dimension comparison vs the
  current render AND the layout actually re-composed. The mode gate now RECOMMENDS reimagine (not
  just offers it) when the diagnosis says the design is generic/dated/forgettable. New
  superiority+re-composition coverage gate; example output gains recompose:/vs-before: lines; hard
  rules add better-not-different / re-compose-not-re-paint / diagnosis-drives-ambition.

## 1.10.0 — 2026-07-10

- enhance-ui.md: new Phase-1.5 note 'Charts / data-viz + data tables are first-class surfaces' — a
  chart-library config's colours/grid/axis/font/tooltip live in its OWN config object (not tokens)
  so token-tier cleanup/iterate skip it; now the chart config is editable surface (series/axis/grid
  colours -> token values, legend/grid legibility iterated with the cards). A shared chart wrapper
  or <DataTable> on >=2 routes resolves to wrapper-variant (or wrapper-extract), not repeated
  leaf-local. Phase-2 CLEANUP step references it: chart config colours count as design-token-drift,
  a no-data chart/table counts as missing-ui-state.
- polish.md (top-level orchestration command): item-2 'Audits every relevant surface' now names
  charts + data tables as surfaces; new frontend-branch note routes the existing 19 closure verbs
  onto the chart config + table wrapper (consolidate-tokens for series/axis/grid colours set inside
  the chart config, wire-empty/loading/error-state for no-data/skeleton/load-fail, lift-contrast for
  legend+axis+table text, normalize-motion, normalize-surface/tighten-rhythm) — finish within the
  system, NO new verb (closed set stays at 19).
- Both frame the work as finish/improve WITHIN the existing language, explicitly NOT a re-theme
  (that remains /redesign + /art-direct). Closes the 'cards got finished, the chart/table stayed
  old' defect on the two commands that operate inside a design system.

## 1.9.0 — 2026-07-10

- art-direct.md coverage gate + redesign.md build/Phase-6: data-visualization (charts) is a
  MUST-cover region with the technique — locate the chart library's config and re-theme series
  colors/grid/axis/font/legend/tooltip/no-data to the new language; coverage verifies the chart's
  ACTUAL rendered colors changed, not just 'a chart exists'.
- shared components (tables/cards/chart-wrappers): the 'compose, don't re-implement' rule now
  carries a caveat — a shared component reused in the OLD language is a coverage failure; fix is a
  design-system-level restyle so the new language propagates (blast radius 'restyle hits N pages'
  stated), never a silent old-style reuse. This is why the dashboard's charts + tables kept coming
  back unchanged.

## 1.8.1 — 2026-07-10

- enhance-ui: unattended runs (--yes / no interactive pick) now use design-iterate's refine mode
  (the render->critique->improve loop + ui-principles lens scorecard) instead of a blind auto-pick —
  so enhance-ui always has an own quality bar, attended (user pick) or not.

## 1.8.0 — 2026-07-10

- redesign.md: Design-principles rubric +3 positive lenses — 10 motion-actually-implemented
  (transitions/entrances/skeletons are BUILD outputs, a zero-transition redesign fails), 11
  modern/contemporary register (depth/accent/spacing read current-era, 'bland but inoffensive'
  fails), 12 performance/efficiency (60fps, computed/keyed/virtualized, lazy, transform/opacity
  only).
- redesign.md Phase 6: scorecard is now a render->critique->improve LOOP (default 3 rounds,
  --max-refine) — while any targeted lens or motion/modern/perf is Δ/✗, improve it in code +
  re-render + re-score until ✓ or the residual is named. One pass -> iterated-to-quality. Build step
  (Phase 4.6) makes motion/modern/perf explicit build outputs, not optional finish.
- skills/design-iterate.md: +`refine` mode — the unattended
  render->self-critique-from-pixels->fix-weakest-lens->re-render loop (up to $MAX_REFINE), beside
  the existing `pick` mode. Description updated.
- commands/art-direct.md: build explicitly inherits /redesign's refine loop — surfaces are iterated
  to the motion/modern/performance bar; no success on a flat/motionless/default-template result.

## 1.7.1 — 2026-07-10

- art-direct + creative-director: i18n-completeness / no-raw-key gate — a redesign that introduces
  new labels/section-headers/empty-states MUST add real translations to every shipped locale; a
  surface rendering a raw i18n key (STATUS.GROUP_X, Status.no_products, any user-visible
  dotted/SCREAMING key) is a build/floor FAILURE, not a nit. Catches the 'nice grouping, forgot the
  copy' defect.

## 1.7.0 — 2026-07-10

- commands/art-direct.md: mode surfaced + escalatable at the approval gate (no-flag run states MODE:
  evolve and offers reimagine — no silent timid default); anti-timidity build-readiness gate (named
  loud move + before->after glance delta or HALT the build to /enhance-ui·/polish); full-scope
  coverage gate (every in-scope region incl. filter/control bar rebuilt in the new language, else
  reported INCOMPLETE, not success) + a coverage: output line.
- agents/creative-director.md: evolve mode gains the before->after glance gate — the recommended
  surface must be distinguishable from the CURRENT surface at 1/8 thumbnail (not only vs
  competitors); 'same layout, new paint / sparkline added / cards collapsed' explicitly named as the
  restyle failure the gate catches; noted as operationally enforced by /art-direct before the build.

## 1.6.0 — 2026-06-26

- /art-direct now BUILDS, not just proposes: after the single direction-approval gate it AUTO-RUNS
  design-system-architect (codify tokens, landed in the same oracle /redesign re-extracts) →
  /redesign (rebuild each key surface in scope with its per-page proposal gate RELAXED — the one
  direction approval + a reviewable commit per surface stand in for it, rather than a prompt per
  page) → /polish (finish), producing real commits (one per surface). git is the rollback. The build
  keeps /redesign's one mandatory non-gate question — a feature with no home is surfaced
  keep/move/drop, never dropped silently (--yes defaults it to keep).
- New flag --yes: skip the single approval gate (design → build in one shot). Still HALTs on hard
  pre-flight failures (dirty tree, missing oracles in reimagine, no frontend).
- New flag --surfaces=<n>: cap how many surfaces the build rebuilds per run; the rest are listed as
  remaining (keeps a broad scope like 'the whole product' from running unbounded).
- --plan is now explicitly the design-only mode (writes the brief to .claude/plans/, builds
  nothing).
- Now requires a clean working tree (relaxed under --plan). Pre-requisites + output reframed around
  the build (built surfaces, commits, diff, revert range). Phases 5–7 changed from 'handoff' to
  'run'.
- Docs + adapter contract resynced: COMMANDS.md, REFERENCE.md (flow + prereqs + new-project
  walkthrough), FEATURE-LIFECYCLE.md (Scenario A scaffold→art-direct→build),
  tool-adapters/_ui-ux-pack-coverage.md (responsibility #8 now DESIGN→GATE→BUILD; the gate is the
  load-bearing translation concern, --yes skips it). creative-director agent: 'Driven by' note
  updated (command auto-runs the build chain).

## 1.5.0 — 2026-06-25

- NEW agent creative-director (model: opus) — sets and INVENTS the visual direction from product
  goals; owns the Direction rubric (9 creative lenses), a 15-label redline diagnosis vocabulary, and
  a 14-element invention vocabulary (concept, shape/grid language, type personality, colour concept,
  motion personality, signature moments, refusals, Encodability Table). The creative high-ground
  above design-system-architect (codifies a decided direction) and ux-reviewer (audits the usability
  floor). Premise-first, cite-or-halt via templates/snippets/hand-wave-grep.md,
  rendered-not-asserted, mechanical ownability + divergence gates. Standard mode only (not in
  --minimal).
- NEW command /art-direct <scope> (kind: command, pack: ui-ux) — one command to set + invent the
  visual direction, driven by creative-director. Modes: --evolve (default, push the existing
  language further) / --reimagine (greenfield from goals). Diagnoses → diverges three distinct
  directions → renders (design-iterate) + scores → mandatory approval gate → hands off to
  design-system-architect → /redesign → /polish. Proposes + directs; writes no production code.
  Flags: --evolve, --reimagine, --direction, --render/--no-render, --plan. Frontend / mobile only.
  Standard mode only.
- Sync chain: _topics.md (creative-director agent + art-direct command, fallbacks point at live
  sources — no _examples stubs), _essentials.md rationale (both standard-mode), docs/COMMANDS.md
  (UI-UX track table) + docs/REFERENCE.md (TOC + /art-direct section),
  tool-adapters/_ui-ux-pack-coverage.md (now seven commands; per-tool translation + gate-intact
  responsibility for /art-direct).

## 1.4.0 — 2026-06-22

- Sync-chain repair: _topics.md now declares enhance-ui and ui-sweep as commands (kind:command,
  primary_frontend_framework_detected trigger). Both shipped under commands/ and are listed in
  _essentials.md commands, but were absent from the topic list, so /setup-project AUTHOR-mode
  generation silently dropped them. No _examples/ stubs exist, so the fallbacks point at the live
  sources (commands/enhance-ui.md, commands/ui-sweep.md).
- Version record now reflects the audit action-plan rollout already landed in the pack's review /
  feedback commands.
