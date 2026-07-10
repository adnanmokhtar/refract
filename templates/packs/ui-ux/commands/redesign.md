---
description: One command full UI/UX redesign of a page / screen / flow — rethinks layout + UX from scratch (NOT enhancement), then rebuilds it inside the app's existing design system (tokens, components, spacing/type scale, locale + text-direction). Approval gate before any code. Frontend / mobile stacks only. Distinct from /enhance-ui + /polish (refinement, structure preserved) and /align (drift enforcement).
kind: command
pack: ui-ux
---

# /redesign <description-or-path> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/redesign <scope> --plan` runs design-system extraction + the redesign proposal, writes it to `.claude/plans/`, and exits before any edit. Execute it later with `/execute-plan <file>` (or hand it to any tool).

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

## Pre-requisites

This command throws away the current layout and rebuilds it — the highest-blast-radius command in the pack. It refuses to start without a safe baseline:

- `PROJECT_KIND` is `frontend-*` / `mobile-*` (gated on `primary_frontend_framework_detected`). Backend/data-only → HALT.
- **Working tree clean** at HEAD — the whole rebuild lands as reviewable commits, and `git` is the rollback path if the proposal is approved but the build goes wrong.
- `_extracted-idioms.md` populated — the oracle for design tokens + shared-component / wrapper inventory + locale/RTL setup. If it's missing, halt → `/setup-project --refine`.
- Playwright MCP (or the project's screenshot harness) wired — Phase 6 renders the rebuilt surface to verify it; a redesign that is never rendered cannot claim `RTL ✓ / a11y ✓`.

## Args

- `<description-or-path>` — a route, page component, or feature area (e.g. `dashboard/orders/settings-list` or `src/modules/orders/pages/OrderListPage.vue`). Same semantic resolution as `/enhance-ui` (codebase-profile + idioms).
- `--direction="<text>"` — seed the proposal with a desired direction ("card-based", "single-column flow", "split-pane"). Default: the agent derives 1–2 directions from the page's purpose + personas.
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
10. **Motion, actually implemented** — motion is a BUILD OUTPUT, not a principle to nod at: every interactive element has a real hover / press / `:focus-visible` transition; state changes (open/close, add/remove, load→content) animate; lists stagger or fade in; loading uses skeletons, not spinners. All purposeful (clarifies causation/space), fast (≤200–300ms), interruptible, GPU-friendly (`transform`/`opacity`, never animating layout), and `prefers-reduced-motion`-safe. A redesign that ships zero transitions has NOT satisfied this lens — it feels static and dead.
11. **Modern / contemporary register** — the result reads as *current-era*, not merely "not dated": a real depth/elevation system (considered shadows or hairline borders, not flat framework defaults), a decisive accent used with restraint, generous and consistent spacing, coherent corner/geometry language, and a confident type scale. The squint test at a glance should say "this is a 2025-class product," not "default admin template." "Bland but inoffensive" FAILS this lens.
12. **Performance & efficiency** — the rebuilt surface is smooth and cheap: 60fps interactions with no jank or layout thrash; efficient rendering in the stack's idiom (computed/memo not per-render work, keyed lists, virtualize lists >~100, no needless re-renders); heavy/below-the-fold content lazy-loaded; animations on `transform`/`opacity` only; no new render-blocking weight (a multi-hundred-KB gradient/font as the "identity" fails). Cite the frontend/performance patterns where relevant.
13. **Content & micro-copy** — voice matches the personas; buttons are verbs (the action), not "OK / Submit"; empty / error copy is genuinely helpful; headings are scannable. Every new label/state string is added to **all** shipped locales — a raw i18n key (`STATUS.GROUP_X`) on screen is a hard failure, never "designed".

## Phases

All 7. The approval gate sits between Phase 4 (propose) and Phase 5 (build).

### Phase 1 — Understand
- **Intent gate:** "enhance / tidy / tighten / consistent" → `/enhance-ui`. "enforce token / fix drift" → `/align`. "new page that doesn't exist" → `/add-feature`. Proceed only when the intent is *rethink an existing page's design*.
- Parse `<scope>` — a route, page component, or feature area (e.g. `dashboard/orders/settings-list`).
- Locate the page's component(s), its data sources, and every interactive element + state (loading / empty / error / success).

### Phase 2 — Organize
- Sub-tasks: extract design system → inventory current page → draft proposal → (gate) → build → verify.
- The gate is a hard stop: no code is written before the user approves the proposal.

### Phase 3 — Retrieve (design-system extraction — the oracle)
ALWAYS read, in priority order:
- `ai/_extracted-idioms.md`, `ai/conventions.md` — declared UI conventions + component idioms.
- **Design tokens** — locate the token source (Tailwind config / CSS custom properties / theme file / design-tokens package) and enumerate color / spacing / radius / shadow / type scale / z-index.
- **Shared component library** — buttons, inputs, selects, checkboxes, tables, cards, modals, layout primitives. The redesign composes these; it does not re-implement them.
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

- **Feature parity:** every feature / state / data binding from the old page is present (or explicitly approved for removal) — diff the inventory from Phase 1 against the rebuilt surface.
- **System conformance** (`design-system-architect` re-check + `design-token-audit`): no off-token colors/spacing/fonts; no re-implemented components; new primitives (if any) live in the system.
- **Locale + direction:** screenshot in the page's locale — RTL/locale renders correctly (mirroring, alignment, font); strings go through i18n, not hardcoded.
- **a11y** (`a11y-quick-check`): focus order, labels, contrast, tap-targets on the new layout.
- **Responsive + theme-mode:** screenshot at each breakpoint and in light/dark (or each theme) — all hold.
- **Design-quality scorecard + the refine loop (this is how one pass becomes a good design).** Score the *rendered* result against every **Design principles** lens (✓ / Δ with a one-line note). This is NOT a one-pass verify-and-report: a real designer iterates while looking at the screen, and so does this command. **While any targeted lens is `Δ`/`✗`, or lens 10/11/12 (motion / modern register / performance) is not clearly `✓`, the build LOOPS** — improve the specific weak lens in code, re-render, re-score — up to **3 rounds** (`--max-refine=<n>`, default 3). Each round must move a named lens from `Δ`→`✓`, not just restate the score. Only when every targeted lens plus motion/modern/performance is `✓` (or a residual is honestly reported as `Δ` with why it can't clear this pass) does the redesign finish. The redesign must **measurably beat the Phase-4 diagnosis** on the lenses it targeted; a lens the diagnosis flagged that is still `Δ` after the loop is a REQUEST-level miss reported plainly, never hidden. The scorecard + the loop, not vibes, are the bar — a flat, motionless, or default-template result does not pass because it "type-checks", it gets iterated until it looks and moves like a modern product or the residual is named.

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
