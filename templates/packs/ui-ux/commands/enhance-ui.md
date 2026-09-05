---
description: Orchestrator for UI/UX enhancement. Takes a natural-language description ("the sidebar", "the dashboard header") OR explicit path. Runs scope-tier detection (DRY — token / wrapper / extract / leaf) so the same affordance is not styled twice on multiple pages; then cleanup → design-iterate → verify. Composes /align-recheck (including duplicated-surface-styles when frontend) + design-iterate (passes $SCOPE_TIER) + /align-recheck again.
kind: command
pack: ui-ux
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash]
---

# /enhance-ui <description-or-path> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/enhance-ui <scope> --plan` runs scope-tier detection + the cleanup/design diagnosis, writes the enhancement plan to `.claude/plans/`, and exits before any edit. Execute it later with `/execute-plan <file>` (or hand it to any tool).

> **Not this command? (ANTI-triggers)** — "the LAYOUT / IA / flow is wrong, rethink the page" → **`/redesign`** (this command preserves structure and rebuilds nothing). "our whole look is the problem, invent a language" → **`/art-direct`**. "just enforce the tokens / a11y rules, no creative work" → **`/align-recheck`**. "tell me what's wrong, change nothing" → **`/design-review`**. "every surface, with numbers and a report" → **`/ui-sweep`**. "a new screen that doesn't exist" → **`/add-feature`**. **"it looks generic / dated" is NOT this command's ask at all** — it is the `/redesign` ÷ `/art-direct` split, decided by [`redesign.md § Phase 1 — THE LANGUAGE-OR-COMPOSITION TEST`](redesign.md); `/enhance-ui` can only finish inside a language, so it cannot fix a language that is the problem. Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

## The Premise (read this first)

**You describe what you want enhanced; this command runs the cleanup → iterate → verify loop.** Cleanup ensures the surface uses the design system correctly BEFORE you iterate on visuals (no point polishing on top of hardcoded colors). **Before iterate, it decides a scope tier** so you do not paste the same scoped styles on two leaf pages for one shared button — that fragments the design system and violates DRY. Iterate generates 3 style variants at the **correct layer** (token, shared wrapper, or single leaf). Verify catches anything the iteration drifted.

This is the orchestrator for visual / UX enhancement work. It composes:
1. **`/align-recheck`** — fixes structural drift (`design-token-drift`, `a11y-violation`, `reinvented-wrapper`, `raw-library-component`, `missing-ui-state`, `motion-drift`, `responsive-drift`, and for `frontend-*` also **`duplicated-surface-styles`**).
2. **`design-iterate` skill** — generates 3 style variants (polished / bolder / minimal); receives **`$SCOPE_TIER`** and **`$CONSUMER_ROUTES`** (when tier is `token` or `wrapper-variant`); user picks; skill applies.
3. **`/align-recheck`** again — re-enforces conventions on the picked variant.

Examples:
- `/enhance-ui the sidebar`
- `/enhance-ui the dashboard header`
- `/enhance-ui the login page`
- `/enhance-ui src/modules/orders/pages/OrderListPage.vue`
- `/enhance-ui the customer tabs --direction="cleaner padding"`
- `/enhance-ui the primary CTA --scope=wrapper-variant`
- `/enhance-ui the checkout button --dry-detect` — print tier + duplicate map only

## When to use

- "Make the sidebar look better."
- "Polish the dashboard."
- "Tighten up the spacing on the order page."
- "The header feels off — try a few variants."
- After a feature merge that landed UI without much polish.
- Pre-launch cleanup of a specific surface.

## When NOT to use

- For new UI features (new menu, new screen) → `/add-feature`.
- For pure cleanup with no creative work → `/align-recheck` alone.
- For visual review without changes → `/design-review`.
- For non-frontend stacks (`PROJECT_KIND` not `frontend-*`) — this command halts.

## Pre-requisites

- `PROJECT_KIND` is `frontend-*` (Vue / React / Angular / Svelte / etc.).
- `_extracted-idioms.md` populated (oracle for cleanup step + shared-component / token paths).
- Mechanical CI green at HEAD.
- Working tree clean.
- **Playwright MCP — recommended, NOT required. THE RENDER CONTRACT (stated once here; everything below cites it).** Two of the three steps (`/align-recheck` → iterate → `/align-recheck`) need no screenshots, so a missing harness must not block the run. Two values, never merged — the same contract `design-iterate` and `/redesign` use:
  - **No harness at all → `SKIPPED (no harness)`.** Cleanup and re-enforce still run; the variant step is skipped; every visual claim prints `SKIPPED`, never a checkmark.
  - **Harness present, render BLOCKED** (login wall / redirect / surface marker absent) → **HALT `RENDER BLOCKED`**. Authenticate (`storageState` / login step per `visual-check`) and re-run. Never grade a login screenshot; never downgrade a block to a skip.

## Args

- `<description-or-path>` — natural-language description OR explicit path. Same resolution as `/align-recheck` (semantic understanding via codebase-profile + idioms).
- `--direction="<text>"` — pass-through to design-iterate ("cleaner", "more minimal", "bolder", "card-based"). Default: agent picks based on the description.
- `--scope=<tier>` — **`token` | `wrapper-variant` | `wrapper-extract` | `leaf-local`**. Overrides automatic tier detection from Phase 1.5. Use when you know the correct layer (e.g. shared `AppButton` → `wrapper-variant`).
- `--auto-extract` — when tier would be `wrapper-extract`, run an inline extraction sub-flow (introduce shared wrapper + rewire callers) instead of halting with a recommendation to `/add-component`. Riskier; default is halt unless this flag is set.
- `--dry-detect` — run Phase 1 + **Phase 1.5 only**: print resolved paths, duplicate-surface map, chosen tier, and exit with no cleanup / iterate / re-enforce.
- `--skip-cleanup` — skip step 1; jump straight to design-iterate. Use only if you've JUST run align-recheck **at the same tier target** as this run.
- `--skip-iterate` — only run cleanup steps (1 + 3); no creative variants. Equivalent to `/align-recheck the X --class=...`.
- `--re-detect-only` — both align-recheck calls run in re-detect-only mode (no fixes). Useful for surface inspection.

## Phase 1 — Understand

### Intent gate (mandatory pre-step)

Parse the user's description for keywords that indicate a different command is the right choice:

| User description contains | Right command | Action |
|---|---|---|
| "add" / "new" / "create" / "build" / "implement" | `/add-feature` | Halt; suggest `/add-feature <description>` |
| "fix" + ("bug" / "broken" / "wrong" / "crash") | `/fix-bug` | Halt; suggest `/fix-bug <description>` |
| "audit" / "review" — read-only intent | `/design-review` | Halt; suggest read-only command |
| "redesign" / "rethink" / "from scratch" / "new layout" / "re-theme" / "new look" / "new visual language" | `/redesign` (rethink ONE page in the existing language) · `/art-direct` (invent a NEW language) | Halt; `/enhance-ui` **preserves structure + the current language** — it cannot rethink IA or introduce a new visual language. Route to `/redesign` (structural rework) or `/art-direct` (new direction). |
| "generic" / "dated" / "forgettable" / "looks like a template" | **not this command** — it is the `/redesign` ÷ `/art-direct` split | Halt. Do NOT accept it as a polish job: finishing inside a language cannot fix the language. Do NOT ask the user which one either — hand it to [`redesign.md § Phase 1 — THE LANGUAGE-OR-COMPOSITION TEST`](redesign.md), which decides it from the render + the token source. |
| Pure cleanup, no creative work ("just fix tokens", "just a11y") | `/align-recheck <description> --class=<targeted>` | Halt; suggest narrower class filter |
| "enhance" / "improve" / "polish" / "cleaner" / "better look" | `/enhance-ui` (this command) | Proceed |

If ambiguous: ASK "are you enhancing existing UI, or adding something new?" Route based on answer.

If user insists on `/enhance-ui` for an add-feature task, halt; cannot proceed when the work requires new structure — route to `/add-feature`. Exception: **`wrapper-extract`** tier explicitly introduces a shared wrapper; that is extraction + enhancement, not an unrelated feature.

### Standard inputs

Resolves the description to file paths via the same semantic flow as `/align-recheck` (read codebase-profile + idioms + ledger). Confirms the resolved files are UI components (`.vue` / `.tsx` / `.svelte` / etc.) — refuses to enhance a service or composable unless tier is `token` (tokens module path).

## Phase 1.5 — Surface scope detection (DRY gate)

**Runs after resolve, before cleanup.** If `--scope=<tier>` is set, adopt that tier but **still print** the duplicate-surface map for transparency.

1. **Identify the target surface** inside the resolved file(s): a named component — the project's own wrapper (`<AppButton>`) or a library control (Vuetify `<v-btn>`, a React/MUI or shadcn `<Button>`, an Ant or PrimeVue equivalent) — or a stable affordance (`role="button"`, `data-testid`, repeated heading text per idioms). The names here are illustrative; the real ones come from `_extracted-idioms.md`.
2. **Find duplicate call sites** — grep / semantic search for other uses of the same component or same affordance pattern across the repo; stack-aware patterns from `_extracted-idioms.md`. Record each hit as `<path:line>`.
3. **Choose exactly one scope tier** (override with `--scope`):

| Tier | When | Where iterate applies styles | Iterate behaviour |
|---|---|---|---|
| **`token`** | Change is purely visual (color / spacing / radius / shadow / motion) and maps to existing tokens in `_extracted-idioms.md`. | Theme / tokens file (`_tokens.scss`, `tailwind.config`, CSS variables module — path from idioms). | `design-iterate` edits token values; screenshots **every consumer route** listed below. |
| **`wrapper-variant`** | A shared wrapper in idioms already owns the surface (`AppButton`, `BaseCard`, …). | That wrapper component file. | `design-iterate` edits wrapper (scoped styles + optional variant props **with user confirmation** for template/script). Screenshots every consumer route. |
| **`wrapper-extract`** | Same affordance appears on **≥ 2** leaf pages / routes, **no** shared wrapper in idioms yet. | N/A until extraction completes. | **Halt** iterate; emit duplicate map + recommend `/add-component <WrapperName>` (or run extraction inline if `--auto-extract`). After wrapper exists, re-enter this command at **`wrapper-variant`**. |
| **`leaf-local`** | Exactly **one** meaningful call site for this surface (true one-off page chrome). | Resolved leaf page / component only. | Same as legacy: scoped `<style>` variants only; `design-iterate` with `$SCOPE_TIER=leaf-local`. |

4. **Build `$CONSUMER_ROUTES`** — for `token` and `wrapper-variant`, list every route or storybook entry that renders the surface (from router config + grep). Pass to `design-iterate` for multi-screenshot variant comparison.

5. **Print one-line verdict**: `Scope tier: <tier> | duplicate surfaces: N | iterate target: <path>`

**If `--dry-detect`:** emit verdict, full duplicate map, and tier rationale; **halt** — do not run Phase 2 onward.

### Framework component-library controls need explicit overrides (the filter/control bar)

A design-token / theme file styles the project's own elements; it does **not** reach the internals of a component library — PrimeVue (`SelectButton`, `Calendar`, `InputText`, `Dropdown`), MUI, Ant, Vuetify, Radix/shadcn render with their DEFAULT theme unless the enhancement writes explicit `:deep()` / `::v-deep` / theme-token overrides for their inner classes (`.p-button`, `.p-inputtext`, `.p-highlight`, …). The **filter / control bar** (date pickers, segmented toggles, selects, action buttons) is usually built from these controls — so when the enhanced surface contains them, cleanup's `design-token-drift` fix must target the control's override layer, and the control counts as `below-bar` until it visibly matches the system in the render. "The tokens exist, the controls inherit them" is false; they stay default until overridden.

### Charts / data-viz + data tables are first-class surfaces (not skipped)

When the target surface contains a **chart-library chart** (Chart.js / ECharts / Recharts / Nivo / D3) or a **data table** (shared `<DataTable>` or a per-page one), it is a surface to enhance like any other — do not enhance the surrounding cards and leave the chart/table on old styling. Two things make them easy to miss, so name them explicitly:

- **A chart's colours / grid / axis / font / tooltip live in its OWN config object, NOT in design tokens.** So `design-token-drift` cleanup and a token-tier iterate silently pass it over. Treat the chart config as part of the editable surface: pull the series/axis/grid colours from the config to the project's token *values*, and let iterate propose the chart's palette/legend/grid legibility alongside the card styling.
- **A shared chart wrapper or `<DataTable>` is a `wrapper-variant`, not `leaf-local`** — if the same chart/table affordance renders on ≥ 2 routes, Phase 1.5 must resolve it to `wrapper-variant` (or `wrapper-extract` if no wrapper exists yet), so the enhancement lands once and propagates. A one-off page chart with a single call site stays `leaf-local`, but its config is still in-scope for the leaf edit.

Enhancement here means **better within the existing system** (legend contrast ≥ AA, real no-data / loading / error states, consistent enter/update motion, token-aligned palette, table zebra/hover/empty) — NOT re-theming to a new visual language (that is `/redesign` + `/art-direct`).

## Phase 2 — Organize

```
0. TIER           — Phase 1.5 complete; $SCOPE_TIER + $CONSUMER_ROUTES frozen for this run
1. RESOLVE        — (already done) description → UI file(s)
2. CLEANUP        — /align-recheck <iterate-target> --class=<classes>
                    Always include for frontend-*: duplicated-surface-styles, design-token-drift,
                    a11y-violation, reinvented-wrapper, raw-library-component, missing-ui-state,
                    motion-drift, responsive-drift
                    If target has a chart/data-viz or data table: its config object + wrapper are
                    in-scope (see "Charts / data-viz + data tables" note) — chart series/axis/grid
                    colours count as design-token-drift even though they live in the chart config,
                    and a no-data/empty chart or table counts as missing-ui-state.
                    Tier-specific:
                    - token          → cleanup targets tokens file; replace-with-shared for drift on tokens
                    - wrapper-variant→ cleanup targets wrapper component path
                    - wrapper-extract→ cleanup runs on leaf files to surface duplicated-surface-styles;
                                       HALT iterate unless --auto-extract resolved extraction
                    - leaf-local     → cleanup on resolved leaf only
3. ITERATE        — design-iterate with $TARGET = tier iterate target, $SCOPE_TIER, $DIRECTION,
                    $CONSUMER_ROUTES (token / wrapper-variant only).
                    Render contract per Pre-requisites: no harness -> SKIPPED (steps 2/4/5
                    skipped, 1/3/6/7 run); render BLOCKED -> HALT. Mode:
                    - ATTENDED (default) → $MODE=pick (3 variants, the user pick IS the quality bar)
                    - UNATTENDED (--yes / no interactive pick) → $MODE=refine — the render→
                      self-critique-from-pixels→fix-weakest-lens→re-render loop with the ui-principles
                      lens scorecard, so an unattended run still has an OWN quality bar, not zero.
4. PICK           — attended: user picks A / B / C / "tune one further". Unattended: the refine
                    loop's cleared-scorecard result stands (its lens deltas are shown, no blind auto-pick)
5. APPLY          — design-iterate applies the picked / refined variant at the tier layer
6. RE-ENFORCE     — /align-recheck <iterate-target> (+ consumers if wrapper/token touched)
7. SUMMARY        — diff stats + screenshots + DRY proof line
```

## Phase 3 — Retrieve

- `_extracted-idioms.md` (design tokens, shared components, motion tokens, wrapper inventory).
- `ai/conventions.md` (UI conventions).
- The resolved component file(s) **and** tokens / wrapper path chosen by tier.
- **`$CONSUMER_ROUTES`** — for screenshot sweep when tier ≠ `leaf-local`.

## Phase 4 — Generate (the orchestration)

This command does NOT directly write code — it dispatches `/align-recheck` and `design-iterate`. Each downstream produces its own output; this command consolidates.

End-of-run summary:

```
/enhance-ui the sidebar — complete

Scope tier:                wrapper-variant
Duplicate surfaces:      3 (<path:line> × 3)
Iterate target:          src/shared/components/AppSidebar.vue
Surfaces updated by 1 change: 3 routes (DRY — single wrapper edit)

Resolved:                  src/shared/components/AppSidebar.vue

Step 1 — Cleanup:          5 findings fixed
  duplicated-surface-styles:   1 (sidebar padding duplicated on Dashboard + Settings — folded into wrapper)
  design-token-drift:        3 (hardcoded #3b82f6 → $primary; padding 12px → $space-md ×2)
  a11y-violation:            1 (focus state missing on collapse button)
  raw-library-component:     1 (a raw library button — PrimeVue / MUI / Vuetify, whichever
                                 this project ships — replaced with the shared AppButton)

Step 2 — Iterate:          3 variants generated (screenshots: Dashboard, Settings, Orders — consumer routes)
  Variant A (polished):      .claude/artifacts/design-iterate/2026-05-02T18-30/variant-a-dashboard.png …
  Variant B (bolder):        …
  Variant C (minimal):       …

User picked:               C (minimal)

Step 3 — Apply:            variant C applied to AppSidebar.vue (wrapper scoped styles + confirmed props)

Step 4 — Re-enforce:       0 new findings (clean)

Total impact:
  Diff:                    +18 / -34 = -16 lines
  a11y score:              92 → 96 (improved — rendered consumers only; un-rendered = SKIPPED)
  Visual regression:       1 diff accepted (intentional design change)
  Bundle-size delta:       -0.2% (smaller)   [SKIPPED if bundle-analyze absent]

Commits:                   5 cleanup commits + 1 design-iterate commit + 0 re-enforce commits

Not validated:             Orders consumer route not rendered → its a11y / visual claims SKIPPED
Risks:                     wrapper-variant edit touched 3 routes; 2 rendered this run
Revert:                    git reset --hard <pre-run HEAD>   (or git revert the range)
```

## Phase 5 — Update (persist changes)

- Per downstream commands: ledger updates from /align-recheck; screenshot artifacts from design-iterate.
- One log entry to `ai/_history.md`: `<iso> enhance-ui <resolved> | tier=<scope> | cleanup-fixes=<N> | variant=<A|B|C> | consumers=<N>`.

## Phase 6 — Validate

- Each step's downstream validation runs as normal (align-recheck's gate, design-iterate's snapshot review).
- Final state: working tree clean, tests pass, a11y score not below baseline, bundle-size within tolerance.
- **DRY check**: if tier was `leaf-local` but duplicate surfaces existed → classification bug; surface in summary.
- **Rendered, not asserted (honesty footer).** The a11y-score, visual-regression, and bundle-size lines are claimed ONLY for consumer routes actually rendered / measured this run; any consumer not rendered prints that line `SKIPPED (not rendered)`, never a fabricated delta. Every run ends with the house footer — `Not validated:` (what was SKIPPED + why) · `Risks:` · `Revert:` — mirroring `/redesign` + `/art-direct`.

## Phase 7 — Improve

- If the picked variant introduces new design-token drift, surface "iterate produced non-on-system styling; flag for design-token sync."
- If cleanup step found > 10 findings, surface "this surface had high drift; consider quarterly UI/UX cadence."
- If `wrapper-extract` halted, surface "extract shared wrapper before re-running enhance-ui for consistent visuals."

## Hard rules

- **Frontend stacks only.** Halts on non-frontend PROJECT_KIND.
- **Cleanup before iterate.** Don't polish on top of drift. The order is fixed (tier lock → cleanup → iterate → re-enforce).
- **Never apply the same style change to ≥ 2 leaf pages** when those pages share one affordance. If duplicate surfaces are detected, route to `token`, `wrapper-variant`, or `wrapper-extract` — not repeated `leaf-local` iterate on each page.
- **Iterate runs at exactly one tier.** The tier is decided in Phase 1.5 (or `--scope`) and survives the whole run.
- **`leaf-local` template/script lock.** When `$SCOPE_TIER == leaf-local`, `design-iterate` must not change template or script — style-only. For `wrapper-variant`, template/prop changes require explicit user confirmation (see `design-iterate` skill).
- **`wrapper-extract` default is halt** — user runs `/add-component` or passes `--auto-extract`.
- **User picks the variant.** This command does NOT auto-pick. The skill pauses for user input.
- **Re-enforce always runs.** Even if iterate produced no diff, and even when iterate was `SKIPPED (no harness)`.
- **The harness is optional; honesty about it is not.** Missing → skip and say so; blocked → halt. The summary must say which.

## Failure modes

- **Resolution returns 0 matches** — halt; route to `/align-status` for known surfaces or paths.
- **Resolved file is not a UI component** (it's a service / composable) — halt; ask user for the right file (unless tier `token` and target is a tokens module).
- **Cleanup step halts** (idiom missing, etc.) — halt the whole flow; route to `/setup-project --refine`.
- **No render harness** — **do NOT halt** (see the render contract in Pre-requisites). Cleanup + re-enforce run, iterate is `SKIPPED (no harness)`, visual claims print `SKIPPED`, and the missing infra is named under `Not validated:`. Halting the pack's most-dispatched command over an optional dependency is a worse failure than skipping one step honestly.
- **Render BLOCKED** (auth wall / redirect) — **HALT** per the same contract; the variants would otherwise be graded against a login page.
- **design-iterate fails otherwise** (crash, timeout) — halt the iterate step only, keep the cleanup commits, report the failure with its output.
- **User skips the pick** — leaves the file in cleanup-only state (no creative change); legitimate flow.
- **Re-enforce surfaces drift** that iterate introduced — auto-fixes via the standard align loop; surfaces in the summary.
- **Duplicate surface, no wrapper (`wrapper-extract`)** — halt with duplicate map + recommend `/add-component <SharedX>` for extraction. With `--auto-extract`, run extraction sub-flow then continue at `wrapper-variant`.
- **Tier override conflicts with detection** — warn; proceed under user's `--scope` and log the conflict in the summary (user accepts responsibility).
- **Token-tier change affects many routes** — ensure every consumer appears in variant screenshots before pick; if user aborts, roll back via git.

## Related

### Sibling commands
- `/align-recheck` — the cleanup primitive this command dispatches (include `--class=duplicated-surface-styles` for frontend).
- `/design-review` — read-only audit (use BEFORE enhance-ui to see what needs cleaning).
- `/redesign` — when the surface needs its **layout / IA / flow rethought** (not preserved). `/enhance-ui` preserves structure and rebuilds nothing; `/redesign` throws the layout away and rebuilds it inside the same design system. The intent gate above routes here for that ask.
- `/art-direct` — when the ask is a **new visual language / direction** (not finishing within the current one). It is upstream of `/enhance-ui` — it decides the language, then `/redesign` + `/polish` (and `/enhance-ui`) work within it.
- `/add-feature` — for net-new surfaces; use `/add-component` or equivalent when `wrapper-extract` applies.

### Skills
- `design-iterate` — generates the 3 visual variants (`$SCOPE_TIER`, `$CONSUMER_ROUTES`).
- `a11y-quick-check` — the **in-pack** a11y pass run as part of cleanup verification (focus order, contrast, labels, reduced-motion).
- `bundle-analyze` *(frontend pack)* — optional bundle-size delta on re-enforce; only when the `frontend` pack is installed. Absent → the bundle-size line prints `SKIPPED (no bundle-analyze)`, never a fabricated delta.

### Rules
- `.claude/rules/align-discipline.md` — the discipline the cleanup steps enforce (`duplicated-surface-styles` subclass).
