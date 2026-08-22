---
description: One command full UI/UX redesign of a page / screen / flow — rethinks layout + UX from scratch (NOT enhancement), then rebuilds it inside the app's existing design system (tokens, components, spacing/type scale, locale + text-direction). Approval gate before any code. Frontend / mobile stacks only. Distinct from /enhance-ui + /polish (refinement, structure preserved) and /align (drift enforcement).
kind: command
pack: ui-ux
---

# /redesign <description-or-path> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/redesign <scope> --plan` runs design-system extraction + the redesign proposal, writes it to `.claude/plans/`, and exits before any edit. Execute it later with `/execute-plan <file>` (or hand it to any tool).

> **Not this command? (ANTI-triggers)** — "make it look better / tighter / more finished" with the structure kept → **`/enhance-ui`**. "enforce our tokens / fix a11y drift" → **`/align`**. "a page that doesn't exist yet" → **`/add-feature`**. "tell me what's wrong, change nothing" → **`/design-review`**. **"it looks generic / dated / forgettable" is the one you cannot route by keyword — it belongs to this command OR to `/art-direct`, and Phase 1's LANGUAGE-OR-COMPOSITION TEST decides it mechanically. Do not ask the user; run the test.** Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

## The Premise (read this first, internalize, do not deviate)

**You point at a page; this command redesigns it from scratch — like handing it to a UX designer — then rebuilds it inside the app's existing design system.** This is NOT enhancement. `/enhance-ui` and `/polish` preserve the structure and tighten it; `/redesign` is allowed to throw away the current layout, rethink the information architecture and the user flow, and produce a genuinely new design.

The one hard constraint: **the new design must speak the app's existing visual language** — same design tokens, same component library, same spacing / type scale, same locale + text-direction (e.g. RTL / Arabic) conventions. A redesign that introduces a foreign look is a failed run. The current design is the starting point to leave behind; the design system is the starting point to keep.

### `/redesign` vs `/enhance-ui` + `/polish` vs `/align`

| | `/enhance-ui` · `/polish` | `/redesign` | `/align` |
|---|---|---|---|
| Layout / structure | preserved | **reworked from scratch** | preserved |
| UX flow / IA | untouched | **rethought** | untouched |
| Visual system | tightened / iterated | **new design, same tokens** | enforced |
| Mindset | senior eng tidying | **UX designer redesigning** | linter |
| Approval gate | no | **yes — proposal before build** | no |

**Stack scope:** frontend / mobile only (`primary_frontend_framework_detected`). If the repo has no UI surface (backend / data only), **HALT** and tell the user there is no frontend here to redesign — point them at the frontend repo.

## When to use
- A page/flow whose layout or UX is genuinely wrong and needs rethinking, not tidying.
- Consolidating a sprawling screen (e.g. a wall of checkboxes / a cramped settings page) into a coherent new design.
- Modernizing a legacy screen's UX while staying on-brand.

## When NOT to use
- Hardcoded value → existing token, or a11y drift from an existing rule → `/align`.
- Adding finish (states, rhythm, hierarchy, a few variants) without changing structure → `/enhance-ui` or `/polish`.
- A brand-new page that doesn't exist yet → `/add-feature` or your scaffold flow.
- A **new visual identity / colour world / bold new look** — not rebuilding inside the app's *existing* language → `/art-direct` (it is upstream: it DECIDES and invents the language; `/redesign` builds inside an already-decided one and is forbidden to invent one).
- **"Generic / dated / forgettable" with no other signal** — do NOT guess and do NOT ask the user. Run Phase 1's **LANGUAGE-OR-COMPOSITION TEST**: ≥2 of its three questions pointing at the language means this command cannot fix the complaint and the run halts to `/art-direct`. Routing costs nothing — `/art-direct` runs `/redesign` per surface once the language is decided.

## Pre-requisites

This command throws away the current layout and rebuilds it — the highest-blast-radius command in the pack. It refuses to start without a safe baseline:

- `PROJECT_KIND` is `frontend-*` / `mobile-*` (gated on `primary_frontend_framework_detected`). Backend/data-only → HALT.
- **Working tree clean** at HEAD — the whole rebuild lands as reviewable commits, and `git` is the rollback path if the proposal is approved but the build goes wrong.
- `_extracted-idioms.md` populated — the oracle for design tokens + shared-component / wrapper inventory + locale/RTL setup. If it's missing, halt → `/setup-project --refine`.
- Playwright MCP (or the project's screenshot harness) wired — Phase 6 renders the rebuilt surface to verify it; a redesign that is never rendered cannot claim `RTL ✓ / a11y ✓`. **If the target surface is auth-gated, an authenticated session is a prerequisite** (`storageState` / a login step — see `visual-check`): a headless/isolated browser with no session renders the login wall, and a redesign graded against a login screenshot is unverified. A blocked render HALTs (it is not the same as "no harness").

## Args

- `<description-or-path>` — a route, page component, or feature area (e.g. `dashboard/orders/settings-list` or `src/modules/orders/pages/OrderListPage.vue`). Same semantic resolution as `/enhance-ui` (codebase-profile + idioms).
- `--direction="<text>"` — seed the proposal with a desired direction ("card-based", "single-column flow", "split-pane"). Default: the agent derives 1–2 directions from the page's purpose + personas.
- `--yes` — **unattended variant selection.** The post-approval build's optional variant step runs `design-iterate` in **refine** mode (auto render → self-critique → improve loop) instead of pausing to show 3 pickable variants. It does **NOT** skip the proposal approval gate — that hard stop always stands (Phase 4). For a design-only run use `--plan`; to auto-approve the proposal, run under `/art-direct --yes` (which relaxes `/redesign`'s per-page gate for its build chain).
- `--max-refine=<n>` — cap the Phase-6 render → critique → improve loop (default 3 rounds).
- `--plan` — universal handoff flag (see blockquote above): produce the proposal as a plan artifact and exit before any edit.

## The agent's job (exactly this)

This command composes the pack's design specialists — it does not hand-roll their work: **`design-system-architect`** owns system extraction + conformance, **`ux-reviewer`** owns the IA/flow rethink + micro-copy in the proposal, the **`ui-design-sweep`** skill supplies the closure-verb vocabulary that finishes the rebuilt surface, and (optionally, post-approval) **`design-iterate`** generates screenshotted visual variants of the approved structure.

1. **Extract the design system** (`design-system-architect`) — tokens, component library, spacing/type scale, motion, locale + text-direction conventions. This is the non-negotiable vocabulary.
2. **Read the current page** — every feature, state, and data binding, so nothing is silently dropped in the redesign.
3. **Diagnose, then propose a new design** (`ux-reviewer` drives) — name the current page's failures against the Design-principles rubric, design the new layout + IA + flow + micro-copy to fix them, self-critique against the rubric, then present a structured proposal and **GATE on user approval before writing code**.
4. **Rebuild** — implement the approved design using only design-system primitives, finishing the surface with the `ui-design-sweep` closure verbs; preserve all behavior / data / feature parity unless the user approved removing something.
5. **Verify** (`design-system-architect` re-checks conformance) — feature parity, token / component conformance, locale + direction correctness, a11y, responsive + theme-mode — **rendered, not asserted** (Phase 6 screenshots the result).

**The agent does NOT:** keep the old layout "to be safe" (that's `/enhance-ui`); invent a new visual language / off-system colors / fonts; drop a feature or state without surfacing it; skip the approval gate; ship without verifying RTL / locale parity.

**The agent ONLY asks the user when:** presenting the redesign proposal (mandatory gate), or when feature parity forces a UX decision ("the old page had X; the new layout has no obvious home for it — keep, move, or drop?").

## Design principles (the rubric — design against it, then score against it)

A redesign is not a matter of taste; it is judged against established UX/UI best practice. The agent **diagnoses the current page against this rubric** (Phase 4), **designs the proposal to satisfy it**, and **scores the result against it** (Phase 6). Cite the specific lens when a decision turns on it.

1. **Information architecture** — every screen has *one* primary job; rank actions primary / secondary / tertiary and make that ranking visible; progressive disclosure (advanced / rare options behind expandos, steps, or a secondary view); group by user task, not by data model; minimize on-screen decisions (Hick's law).
2. **Visual hierarchy** — the squint test: the most important element is seen first; size / weight / color / spacing encode importance; one clear focal point + primary CTA per view; respect F- / Z- reading patterns.
3. **Layout & rhythm** — snap to the design system's spacing grid (e.g. 8pt) and type scale (a modular ratio); align to a grid; generous, *consistent* whitespace; readable measure (~50–75ch) for text blocks.
4. **Cognitive load & flow** — shortest path to the user's goal; sensible defaults; recognition over recall; chunk related fields; Fitts's law (large, near targets for frequent actions); forgiving (undo / confirm destructive).
5. **States as first-class** — design *every* state, not just the happy path: loading (skeletons, not spinners where possible), empty (with a helpful next action), error (specific + recoverable), success, zero-results, partial / offline. Immediate feedback on every action.
6. **Consistency** — match the design system and the gold-standard screen; same pattern for the same problem; honor platform conventions.
7. **Accessibility by design** (not bolted on) — contrast ≥ WCAG AA; never signal by color alone; logical focus order + visible focus ring; labels + roles; target size ≥ 44px; honor `prefers-reduced-motion`.
8. **Responsive, mobile-first** — design the smallest breakpoint first, then enhance up; reflow, don't shrink; content priority survives at every width.
9. **Locale & direction** — design *in the actual locale*: RTL mirrors the whole layout (not just text); logical properties; lay out with real translated copy (Arabic / German expansion), never lorem.
10. **Motion, actually implemented** — motion is a BUILD OUTPUT, not a principle to nod at: every interactive element has a real hover / press / `:focus-visible` transition; state changes (open/close, add/remove, load→content) animate; lists stagger or fade in; loading uses skeletons, not spinners. All purposeful (clarifies causation/space), in the `base` band (200–300 ms) for UI transitions — **the durations come from `motion.md § The duration scale`, which owns them; this lens cites, it does not set them** — interruptible, GPU-friendly (`transform`/`opacity`, never animating layout, and `filter` is not in the cheap set), and `prefers-reduced-motion`-safe (gated by trigger, not duration). A redesign that ships zero transitions has NOT satisfied this lens — it feels static and dead.
11. **Modern / contemporary register** — the result reads as *current-era*, not merely "not dated": a real depth/elevation system (considered shadows or hairline borders, not flat framework defaults), a decisive accent used with restraint, generous and consistent spacing, coherent corner/geometry language, and a confident type scale. The squint test at a glance should say "this is a 2025-class product," not "default admin template." "Bland but inoffensive" FAILS this lens.
12. **Performance & efficiency** — the rebuilt surface is smooth and cheap: 60fps interactions with no jank or layout thrash; efficient rendering in the stack's idiom (computed/memo not per-render work, keyed lists, virtualize lists >~100, no needless re-renders); heavy/below-the-fold content lazy-loaded; animations on `transform`/`opacity` only; no new render-blocking weight (a multi-hundred-KB gradient/font as the "identity" fails). Cite the frontend/performance patterns where relevant.
13. **Content & micro-copy** — voice matches the personas; buttons are verbs (the action), not "OK / Submit"; empty / error copy is genuinely helpful; headings are scannable. Every new label/state string is added to **all** shipped locales — a raw i18n key (`STATUS.GROUP_X`) on screen is a hard failure, never "designed".
14. **Beats the previous version (before→after superiority — the one that decides "is this actually a redesign")** — this lens is NOT scored against best-practice in the abstract; it is scored against a **rendered screenshot of the CURRENT (pre-run) surface** captured before any code changed. Put the two renders side by side. The new must **win on every dimension it claims**: visual hierarchy, modern/contemporary register, distinctiveness/point-of-view, craft & polish, and emotional appeal at a glance. **If the OLD surface looks better on ANY of those dimensions, this lens is `✗` — not "different", worse — and the redesign is NOT done.** "It changed" is not the bar; "a stranger shown both, told nothing, picks the new one on every axis" is the bar. A redesign that is merely *not identical* to the old but doesn't clearly out-class it is a failed redesign, reported as such.
15. **Re-composition, not re-paint (a redesign moves things, not just recolors them)** — a true redesign changes the **composition**: the information architecture, the grouping and order of sections, action ranking, spatial rhythm, and where the eye lands — not only the tokens/colors/type on top of the identical skeleton. Reorganizing and repositioning components to build a stronger hierarchy is *expected and encouraged*, not a risk to avoid. **A rebuild that keeps every element in the same place and only restyles it fails this lens even if the restyle is bold** — that is `/enhance-ui`/`/polish` territory, not a redesign. The Phase-1 inventory vs the rebuilt layout must show a real structural delta (sections merged/split/reordered, hierarchy re-ranked, a different IA archetype), stated in the proposal.

## Phases

All 7. The approval gate sits **inside Phase 4** — between the proposal (step 4) and the build (step 6); no code is written before it. (Phase 5 is "Update"; the build is Phase 4 step 6, not a separate phase.)

### Phase 1 — Understand
- **Intent gate:** "enhance / tidy / tighten / consistent" → `/enhance-ui`. "enforce token / fix drift" → `/align`. "new page that doesn't exist" → `/add-feature`. "new visual identity / invent a language" → `/art-direct` (upstream — it decides the language `/redesign` builds inside). Proceed only when the intent is *rethink an existing page's design within the existing language*.

- **THE LANGUAGE-OR-COMPOSITION TEST (mandatory; run it, do NOT ask the user).** The keyword gate above resolves every intent except the one this command is invoked for most: *"it looks generic / dated / fine but forgettable."* That phrase is claimed by BOTH `/redesign` and `/art-direct`, and the user genuinely cannot say which — whether the fault is the **composition** (this page's IA, grouping, ranking, rhythm) or the **visual language** (the tokens, type, colour, shape, depth the whole app is built from) is the *output* of a diagnosis, not an input a user can supply. Asking them is passing the question back to the one person who cannot answer it. So decide it mechanically, in under a minute, from two artifacts this phase needs anyway — the baseline render and the token source. **This block is the pack's single source for that decision; `/art-direct`, `/enhance-ui` and `/design-review` cite it rather than restating it.**

  **Q1 — Does the complaint reproduce on OTHER surfaces?** Spot-render (or read) two unrelated surfaces in the app. If the same "generic / dated" reading holds on all three, the fault is not in this page's arrangement.
  **Q2 — Does the TOKEN SOURCE itself carry the tell?** Score five, from the token file, not from taste:
  (a) the palette is the UI framework's default ramp, unmodified; (b) the type stack is the system default with no type decision recorded; (c) one radius value, or none; (d) no elevation set at all (no considered shadow scale, no hairline system); (e) no accent role — nothing in the token file is designated the thing used sparingly for emphasis. **≥ 3 of 5 = the language is generic**, and a perfectly-composed page built inside it is a well-organised generic page.
  **Q3 — Would a perfect rebuild in the CURRENT language fix the complaint?** Answer it as a written sentence, not a feeling. If the honest answer is *"it would be better organised but it would still look like this"*, the language is the constraint.

  **≥ 2 of Q1/Q2/Q3 pointing at the language → HALT and route to `/art-direct`.** Nothing is lost by routing: `/art-direct` runs `/redesign` per surface after it decides the language, so the composition work still happens — it just happens against a language worth building in. **Otherwise proceed**: the composition is the problem and this command owns it.

  Record the verdict verbatim in the Phase-4 proposal — `language-or-composition: composition (Q1 no · Q2 1/5 · Q3 yes)` — so the routing decision is auditable, reviewable, and not re-litigated halfway through the build.
- Parse `<scope>` — a route, page component, or feature area (e.g. `dashboard/orders/settings-list`).
- Locate the page's component(s), its data sources, and every interactive element + state (loading / empty / error / success).
- **Build the COMPONENT/FEATURE MANIFEST (the parity contract) — a complete, COUNTED enumeration of every component and feature currently on the surface**: every KPI/stat card (by name — e.g. `conversion-rate`, `total-visits`, `total-orders`, `total-sales`), every chart/series, every table/list, every filter/control (date pickers, period toggles, action buttons), every action/CTA, every panel, every state, **and every ICON** (each card's leading icon, action/button icons, section-header icons, nav icons, empty-state illustrations). **Icons are affordances, not decoration** — record them in the manifest so a redesign cannot silently strip them. Record the count (`N cards, M charts, K tables, …`). This manifest is the non-negotiable reference for the Phase-6 parity gate: **a redesign redraws these, it does not remove them.** Redesign changes the LOOK and MAY re-rank/move/demote/group them (re-composition), but the manifest count and membership must survive the rebuild.
- **Capture the BEFORE baseline** — render the current surface (Playwright MCP, at the primary breakpoint + theme + locale) to `.claude/artifacts/redesign/<iso>/before-*.png` **before any code changes**. This is the reference for lens 14 (before→after superiority); without it the "beats the old" claim is unverifiable and Phase 6 marks lens 14 `SKIPPED (no baseline)`. Also snapshot the layout inventory (sections, their order, action ranking) as the reference for lens 15 (re-composition). **If the surface is auth-gated, authenticate first** (`visual-check`'s authenticated-rendering contract); **if the baseline render is BLOCKED** (login wall / redirect / surface marker absent), the whole redesign is unverifiable from pixels → **HALT** with `RENDER BLOCKED — cannot see the surface; establish an authenticated Playwright session (storageState / login step) and re-run`. A blocked baseline is NOT the same as "no harness" — do not proceed to build a redesign you will be unable to render, grade, or compare.

### Phase 2 — Organize
- Sub-tasks: extract design system → inventory current page → draft proposal → (gate) → build → verify.
- The gate is a hard stop: no code is written before the user approves the proposal.

### Phase 3 — Retrieve (design-system extraction — the oracle)
ALWAYS read, in priority order:
- `ai/_extracted-idioms.md`, `ai/conventions.md` — declared UI conventions + component idioms.
- **Design tokens** — locate the token source (Tailwind config / CSS custom properties / theme file / design-tokens package) and enumerate color / spacing / radius / shadow / type scale / z-index.
- **Whole-app color palette + the PERSISTENT CHROME (this is a fixed constraint, not a suggestion).** A page redesign lives inside an app that keeps rendering its **persistent chrome** — the sidebar, the top header, the nav, the global buttons — in the app's existing colors (e.g. a navy `#04273A` sidebar + a teal `#1F9DBB` brand accent). Extract that real palette from the token source AND from the persistent chrome visible in the baseline render (sidebar colour, header, brand accent, existing control/button colours). **When the scope is ONE page inside a shell that stays, the palette is FIXED by the rest of the app: every colour the redesign uses MUST come from this palette or provably harmonize with the chrome.** Introducing an off-palette colour that fights the unchanged chrome — a **black button in a teal/navy app**, a new accent hue the brand never uses — is a **failure, not a creative choice**: the redesigned page would clash with the sidebar/header the user still sees. A new colour *world* is only legitimate when it is applied **app-wide** (chrome included) — never as one repainted page floating in the old shell. Buttons/controls take the brand accent and the system's neutrals; they are never an arbitrary colour.
- **Shared component library** — buttons, inputs, selects, checkboxes, tables, cards, modals, layout primitives. The redesign composes these; it does not re-implement them. **Caveat (or the page ends up half-redesigned):** composing a shared component is only valid when that component already reflects the target language. When the redesign introduces a NEW language (or `/art-direct` drives it), a shared table/card/chart-wrapper reused **in its old style** leaves the page looking half-done. Such a shared component must be **restyled at the design-system level** (its own file / tokens, so the new language propagates to it and every page that uses it) — the redesign states the blast radius ("`DataTable` restyle hits N pages"). Never silently reuse an old-style shared component and call the page redesigned.
- **Data-visualization / charts** — a chart-library chart (Chart.js / ECharts / Recharts / ApexCharts / D3) holds its colors, axis/grid, fonts, legend, and tooltip in its **own config object, NOT design tokens**, so a token-level redesign leaves it in the old palette. Locate the chart's options/config and **re-theme it explicitly** to the new language: series colors → new palette, grid/axis → new hairline, ticks/labels → new type, legend + tooltip → new surface, no-data → new empty state. A dashboard redesign that restyles the cards but leaves the chart in its old colors has not finished.
- **Locale + direction** — i18n setup, RTL handling, font stack for the locale. If the page is RTL, the redesign MUST preserve correct text-direction + mirroring.
- An existing "gold standard" screen the team is proud of — match its caliber.

### Phase 4 — Generate (diagnose → design → self-critique → propose → gate → build)

1. **Diagnose first (no design yet).** Name *why* the current page is wrong — its specific failures against the **Design principles** rubric, each cited to a real element (e.g. "no hierarchy: 14 fields at equal weight; primary action buried at the bottom; 3 states unhandled; 11 decisions on one screen — Hick's law"). A redesign with no diagnosis is a guess. State the **one job** this screen exists to do, and rank its actions.
2. **Design against the rubric** (`ux-reviewer` drives) — produce the new IA + layout + flow so that each rubric lens is satisfied *by construction*, tied to the personas and the screen's one job.
3. **Self-critique before showing the user (red-team your own proposal).** Score the draft against every rubric lens and against feature parity; find where it still fails; fix it. Only a proposal that passes its own critique reaches the gate. Surface residual tradeoffs honestly rather than hiding them.
4. **Proposal (structured — no code yet).** Present, in this order:
   - **Diagnosis** — what's wrong today (cited).
   - **The screen's job** — the one primary task + secondary tasks.
   - **Direction & rationale** — why this design, tied to personas + the rubric lenses it improves.
   - **New layout & IA** — sections, grouping, order, action ranking (primary / secondary / tertiary).
   - **Component mapping** — which design-system components compose each part.
   - **State inventory** — every state designed (loading / empty / error / success / zero / partial).
   - **Responsive plan** — mobile-first → up; what reflows at each breakpoint.
   - **a11y + locale/RTL plan** — focus order, contrast, target size; mirroring + real translated copy.
   - **Parity map** — old feature → new home (keep / move / drop), nothing silently lost.
   - **Risks & tradeoffs** — and **one** genuine alternative direction only if the design space truly forks (seed with `--direction`). Lead with a recommendation.
5. **GATE:** ask the user to approve / adjust / pick a direction. Do not proceed without it. (Under `--plan`, this structured proposal IS the plan artifact — write it to `.claude/plans/` and exit here; approval happens later via `/execute-plan`.)
6. **Build (after approval):** implement using only design-system primitives, then finish the surface with the `ui-design-sweep` closure verbs (hierarchy / rhythm / states / contrast / focus / motion / …). The build is not "layout only" — **motion (lens 10), the modern register (lens 11), and performance (lens 12) are built in this step, not left for later**: every interactive element gets its hover/press/focus transition, state changes and list entrances animate (GPU-friendly + reduced-motion-safe), loading uses skeletons, depth/elevation + spacing + accent are applied so it reads current-era, and the render path stays efficient (computed/memo, keyed/virtualized lists, lazy below-fold). Add a new token/component ONLY if the system lacks it — and add it to the system, not inline. Preserve all behavior + data bindings + feature parity, and add every new label/state string to all shipped locales. Then the Phase-6 refine loop renders it, scores it, and iterates until motion/modern/performance and the targeted lenses are `✓`. **Optional (attended runs):** dispatch `design-iterate` in `pick` mode to show the user 3 screenshotted variants; in an unattended (`--yes`) run it uses `refine` mode instead — auto-render → self-critique → improve → re-render toward the rubric bar.

### Phase 5 — Update
- `ai/status.md` — Recent Changes entry (page redesigned, what changed structurally).
- `ai/decisions/` — ADR if the redesign sets a new layout/UX pattern others should follow, or adds a new shared component/token.
- `ai/patterns/` — append if the new layout becomes a reusable screen pattern.

### Phase 6 — Validate

**Rendered, not asserted.** Every visual claim below is verified by actually rendering the rebuilt surface (Playwright MCP / project screenshot harness) — at each breakpoint, in each theme mode, and in the page's locale + direction. A redesign that only type-checks has not been validated. If the screenshot harness is unavailable, say so in the output and downgrade the claims — never print `RTL ✓ / a11y ✓` without having looked.

- **Feature parity (HARD GATE — no component is ever dropped): diff the Phase-1 COMPONENT/FEATURE MANIFEST against the rebuilt surface, item by item, and print a parity table** (`component | present ✓ / MISSING ✗ | where it moved to`). **Every item must be `✓`.** A single `MISSING` component (the classic reimagine failure: dropping the `conversion-rate` card to "simplify", deleting a table, removing a filter control) is a **hard FAILURE → `INCOMPLETE — dropped <component>`**, never a silent omission and never a pass. The counts must match (`4 cards in → 4 cards out`). **The default is KEEP; the agent NEVER drops a component on its own initiative** — not to simplify, not because "it didn't fit the new layout", not because the data is empty. A drop is legitimate ONLY when the USER explicitly approved it via the keep/move/drop question (recorded); absent that, re-composition may MOVE or DEMOTE a component (smaller, lower, in a group, behind a tab) but MUST render it. "New design" means new *look*, identical *feature set*. This gate is verified from the render (the rebuilt screenshot must show every manifest item), not asserted from the code.
- **Region coverage (from the render, not the code):** enumerate every region of the page — toolbar, filter/control bar, cards, **charts / data-viz**, **data tables / lists**, panels, empty/loading — and confirm each shows the NEW language in the screenshot. A chart still in its old series colors/grid, or a table still in its old header/row style, is a **coverage failure** (INCOMPLETE), even if the cards look great. Print `coverage: N/N regions` and name any left old. Shared components left old-style are restyled at the system level (with blast radius stated), never silently reused.
- **System conformance** (`design-system-architect` re-check + `design-token-audit`): no off-token colors/spacing/fonts; no re-implemented components; new primitives (if any) live in the system.
- **Colour harmony with the persistent chrome (verified from the render — the "it changed the colours" gate).** Screenshot the redesigned surface **with the app shell visible** (sidebar + header in frame), and confirm every colour the redesign introduced belongs to the app palette or provably harmonizes with the chrome. **Any off-palette colour that clashes with the unchanged sidebar/header — a black button in a teal/navy app, an accent the brand never uses — is a FAILURE (`INCOMPLETE — off-palette <element>`), not a style.** Buttons/controls must use the brand accent + system neutrals, never an arbitrary colour. If the concept genuinely needs a new colour world, it must be applied app-wide (chrome included) or the scope was mis-set — a single page repainted in colours that fight the shell it lives in is never done. (For a single-page scope inside a persistent shell, the safe default is: keep the app's palette, modernize everything else.)
- **Locale + direction:** screenshot in the page's locale — RTL/locale renders correctly (mirroring, alignment, font); strings go through i18n, not hardcoded.
- **a11y** (`a11y-quick-check`): focus order, labels, **computed** contrast, and tap targets on the new layout — reported against both thresholds, never merged into one: **2.5.8 (Level AA, 24×24)** is the conformance floor and **44×44 (2.5.5, Level AAA / iOS HIG / under Material's 48dp)** is the house target. The skill's **Lane B** (screen reader, keyboard walk, OS reduced-motion) cannot run unattended — it prints `NOT RUN (human lane)` and the scorecard says so rather than printing `a11y ✓`.
- **Responsive + theme-mode:** screenshot at each breakpoint and in light/dark (or each theme) — all hold.
- **Design-quality scorecard + the refine loop (this is how one pass becomes a good design).** Score the *rendered* result against every **Design principles** lens (✓ / Δ with a one-line note). This is NOT a one-pass verify-and-report: a real designer iterates while looking at the screen, and so does this command. **While any targeted lens is `Δ`/`✗`, or lens 10/11/12 (motion / modern register / performance) is not clearly `✓`, or lens 14/15 (beats-the-old / re-composition) is not clearly `✓`, or ANY component is `below-bar` in the per-component visual audit (below), the build LOOPS** — improve the specific weak lens or component in code, re-render, re-score — up to **3 rounds** (`--max-refine=<n>`, default 3). Each round must move a named lens from `Δ`→`✓`, not just restate the score. Only when every targeted lens plus motion/modern/performance AND before→after superiority is `✓` (or a residual is honestly reported as `Δ` with why it can't clear this pass) does the redesign finish. The redesign must **measurably beat the Phase-4 diagnosis** on the lenses it targeted; a lens the diagnosis flagged that is still `Δ` after the loop is a REQUEST-level miss reported plainly, never hidden. The scorecard + the loop, not vibes, are the bar — a flat, motionless, or default-template result does not pass because it "type-checks", it gets iterated until it looks and moves like a modern product or the residual is named.
- **The before→after comparison is a rendered, per-dimension judgement (lens 14) — the decisive exit gate.** Put the Phase-1 `before-*.png` next to the rebuilt render and score five dimensions explicitly: hierarchy · modern register · distinctiveness · craft/polish · appeal-at-a-glance. Print the verdict per dimension (`new wins` / `tie` / `OLD wins`). **Any dimension where the OLD wins keeps the loop running** (fix that dimension, re-render) — the run does not finish, and NEVER reports success, while the previous version still looks better on any axis. If after `--max-refine` rounds a dimension is still a tie or an old-win, that is reported bluntly (`before→after: old still wins on <dimension> — redesign INCOMPLETE`), never smoothed over. This is the exact "the old version still looks better in some areas" failure, caught mechanically from the two screenshots rather than assumed away.
- **Per-component visual audit (adversarial, from the render, EVERY component) — the "all components actually modern" gate.** The lens scorecard above judges the page as a whole; it is why a page can score `modern ✓` while a filter dropdown, a table row, or a badge is still ugly. This gate closes that: after each render, **enumerate every distinct component visible in the screenshot** — button (each variant), input/select/combobox, filter/control bar, tab, card/tile, table (header · row · cell · zebra · hover), badge/chip, chart (series · axis · legend · tooltip · no-data), pagination, icon-button, toast, modal, empty/loading/error state — and **grade each ONE, from the pixels**, against concrete modern tells: (1) intentional depth — a real elevation/hairline system, NOT the framework default border/shadow; (2) type on the scale with a weight hierarchy, no default 14px-everything; (3) spacing on the rhythm, not cramped or arbitrary; (4) purposeful color at AA, not a raw accent; (5) real interactive states actually implemented (hover/focus-visible/active/disabled), verified by hovering in the render; (6) consistent corner/geometry with the rest; (7) **not a raw library default** (unstyled native `<select>`, default table zebra, stock spinner, framework toast) — the #1 "one component looks off" tell; (8) **purposeful iconography** — icons that existed for recognition (each KPI card's leading icon, action/button icons, section-header icons, empty-state illustrations) are KEPT and restyled to the new language, not stripped for a "cleaner" look. Icons carry fast recognition and scannability; an icon-barren redesign of a surface that had icons is a **usability regression** (and a parity miss). A component that lost its icon, or a metric/action that reads as a bare number/word where the app elsewhere pairs it with an icon, is `below-bar`. **The grader is ADVERSARIAL and SEPARATE from the builder** (dispatch `ux-reviewer` / a fresh critic pass, never the agent that wrote the component grading itself — self-grading inflates): each component **defaults to `below-bar` and a `✓` must be justified from the screenshot**, not from the code. Print a per-component table (`component | ✓ / below-bar | what's wrong`). **The loop CANNOT exit while ANY component is `below-bar`** — fix that specific component in code, re-render, re-grade. A component graded from the code instead of the screenshot is invalid; a component that was never enumerated is a gate failure (the audit must cover the whole surface, not the prominent parts). This is what "ensure every component is right, even after the visual check" actually requires: the visual check is per-component and adversarial, not a holistic glance.
  - **Framework component-library controls are the #1 miss — they do NOT inherit the token layer.** A design-token/theme file styles YOUR elements; it does **not** reach the internals of a component library (PrimeVue `SelectButton`/`Calendar`/`InputText`/`Dropdown`, MUI, Ant, Vuetify, Radix, shadcn primitives). Those render with the library's DEFAULT theme unless you write explicit **`:deep()` / `::v-deep` / theme-token / CSS-var** overrides for their inner classes (`.p-button`, `.p-inputtext`, `.p-highlight`, …). The **filter / control bar** (date pickers, segmented toggles, selects, action buttons) is almost always built from these controls, which is exactly why it survives a redesign looking default while your authored cards look new. The per-component audit MUST treat every library control as a component to grade, and "styled the tokens, assumed the controls follow" is the specific failure — they don't; override them explicitly or the control is `below-bar`.
  - **Composite-surface completeness (surfaced, never silently added).** When the surface is a **data-table** or a **dashboard**, also note it against the built-in table-stakes catalog (`ui-design-sweep.md § normalize-surface — Built-in composite-surface table-stakes`): a table missing a toolbar (search/filter/sort), row-selection + bulk actions, export, or a sticky header — or a dashboard rendering bare numbers instead of labeled metric tiles with a widget hierarchy — is **SURFACED as a recommendation** (route to `/add-feature`), scale-gated (a tiny reference table needs none of these). It is **NOT** auto-added here (redesign preserves feature parity and never grafts a new capability on its own initiative) and **NOT** a `below-bar` visual blocker — the per-component visual grade stays about how the EXISTING components look, not what affordances the surface lacks.
  - **Render dependency (honest status):** the per-component audit needs a real render. **No harness at all** → `SKIPPED (no harness) — component quality NOT verified` (stated, not hidden). **Harness present but the render is BLOCKED** (login wall / redirect / surface marker absent — `visual-check`'s blocked-render halt) → **HALT, not SKIPPED**: authenticate (storageState / login step) and re-render; never grade a login screenshot or ship an unaudited surface as done.

### Phase 7 — Improve
- If the new layout is reusable, promote it to `ai/patterns/`.
- If the redesign revealed a missing token/component, ensure it lands in the design system so the next screen reuses it.

## Output
```
Redesign: dashboard/orders/settings-list  (column-visibility settings)

Design system extracted:
  tokens: <source>  ·  components: <library>  ·  direction: RTL (ar)

Diagnosis: <the 2–3 worst UX failures of the current page, cited>
Proposal (approved): <one-line summary of the new layout/IA + the direction chosen>

Built:
  <files changed>
  parity: 14/14 features preserved · 0 off-system values
  rendered: 3 breakpoints × {light,dark} × RTL → RTL ✓ · a11y ✓ (axe clean)
  scorecard: hierarchy ✓ · IA ✓ (11→4 decisions) · states 6/6 ✓ · rhythm ✓ · a11y AA ✓ · motion ✓
  screenshots: .claude/artifacts/redesign/<iso>/*.png
```

If the screenshot harness was unavailable, the `rendered:` line reads `rendered: SKIPPED (no Playwright MCP) — RTL / a11y NOT verified` instead of printing unearned checkmarks.

## Hard rules
- **Diagnose before designing.** No proposal without a cited critique of the current page against the Design-principles rubric. A redesign that can't say what was wrong is a guess dressed as a redesign.
- **Design against the rubric, then beat the diagnosis.** The Phase 6 scorecard must show measurable improvement on every lens the diagnosis flagged. "Looks nicer" is not a passing bar.
- **Beat the OLD render, not just the rubric (lens 14).** Success requires the rebuilt surface to win the before→after comparison on hierarchy · modern register · distinctiveness · craft · appeal. If the pre-run screenshot wins on any dimension, the redesign is INCOMPLETE — loop or report it; never ship a redesign the old version out-looks.
- **Re-compose, don't re-paint (lens 15).** A redesign changes the composition — IA, grouping, order, action ranking, spatial rhythm — not just the paint. Reorganizing/repositioning components for a stronger hierarchy is the job, not a risk. A same-skeleton restyle is `/enhance-ui`, not a redesign.
- **Self-critique before the gate.** Red-team the proposal against the rubric + parity and fix the gaps *before* showing the user — don't outsource quality control to them.
- If structure didn't change, it wasn't a redesign — that's `/enhance-ui`. Do not ship a restyle as a redesign.
- No off-system colors / fonts / spacing because they "look better" — extract or add a token instead.
- No feature or state dropped silently — every old capability survives or is explicitly approved for removal.
- Never skip the approval gate and build a guess.
- Never break RTL / locale (left-aligned Arabic, un-mirrored icons, hardcoded English).
- Never print a verification checkmark (`RTL ✓ / a11y ✓`) the run did not render. No harness → say SKIPPED.
- **Rollback is `git`.** The run starts from a clean tree and lands as discrete commits; if the build diverges from the approved proposal, `git reset` to the pre-redesign HEAD — never leave a half-rebuilt page committed.

## Failure modes
- **No frontend in the repo** (backend / data-only PROJECT_KIND) — HALT; point the user at the frontend repo. Nothing to redesign here.
- **Intent mismatch** ("just tidy / enforce tokens / add a new page") — HALT at the Phase 1 intent gate; route to `/enhance-ui` · `/polish` · `/align` · `/add-feature`.
- **Working tree dirty** — HALT; ask the user to commit or stash first (rollback safety depends on a clean baseline).
- **`_extracted-idioms.md` missing / thin** — the design-system oracle is unavailable; HALT → `/setup-project --refine` before redesigning blind.
- **Feature has no home in the new layout** — surface the specific feature/state and ASK keep / move / drop (the one non-gate question allowed). Never drop silently.
- **User does not approve the proposal** — stop at the gate with no code written; legitimate end state (re-run with an adjusted direction).
- **Screenshot harness unavailable** — build still completes, but Phase 6 visual claims are marked `SKIPPED`; the run reports RTL / a11y as NOT verified rather than asserting them.
- **The rebuild needs a token/component the system lacks** — add it to the design system (not inline), record it in Phase 7; if it implies a broad new pattern, write the ADR before shipping.

## Cross-references
- `/art-direct` — **upstream**: decides + invents the visual language (concept, tokens, signature moments) from product goals; `/redesign` rebuilds a page *inside* an already-decided language and is forbidden to invent one. Route here when the ask is a new identity, not a page rework. (`/art-direct`'s build chain runs `/redesign` per surface.) **The split is decided by Phase 1's LANGUAGE-OR-COMPOSITION TEST, which lives here and is cited — not restated — by `/art-direct`, `/enhance-ui` and `/design-review`.**
- pattern `motion` — **owns the duration scale + easing classes** lens 10 grades against.
- `/enhance-ui`, `/polish` — refinement, not redesign (structure preserved).
- `/align` — enforce existing tokens/rules (no creative work).
- `/unify-surfaces` — make this screen's tables/forms consistent with the rest of the app.
- `/add-feature` — a brand-new page that doesn't exist yet.
- agent `ux-reviewer` — drives the Phase 4 IA/flow/micro-copy rethink in the proposal.
- agent `design-system-architect` — owns Phase 3 system extraction + Phase 6 conformance re-check.
- skill `ui-design-sweep` — the closure-verb vocabulary used to finish the rebuilt surface (Phase 4 build).
- skill `design-iterate` — optional post-approval visual variants of the approved structure.
- skills `design-token-audit` · `a11y-quick-check` — Phase 6 conformance + a11y detectors.
- pattern `rtl` — logical-property + mirroring requirements for RTL locales.

## Stack scope
Frontend / mobile only. Gated on `primary_frontend_framework_detected`. On a backend/data-only repo the command halts with a redirect to the frontend repo.
