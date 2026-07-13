---
description: One command to ADD a new theme variant to a multi-theme app — creates a NEW theme slot only (never edits an existing theme or the shared layer), builds it modern + technically-correct + fast + feature-complete-vs-the-default-theme, each gated. Additive is the top invariant. For multi-theme architectures (a `themes/<name>/` slot system) only.
kind: command
pack: ui-ux
---

# /add-theme-variant <name> [<more>...]

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/add-theme-variant <name> --plan` runs the frame → inventory → design-brief pass (slot structure, token direction, the parity manifest inherited from the default theme) and writes it to `.claude/plans/`, exiting before any file is created. Execute it later with `/execute-plan <file>` (or hand it to any tool).

## The Premise (read this first, internalize, do not deviate)

**You name a new theme; this command adds it as a NEW slot beside the existing themes — and never touches anything that already exists.** A multi-theme app renders N visual variants (per tenant / per brand / light-dark-high-contrast / per market) over ONE shared LOGIC layer. This command creates the `(N+1)`th theme. It is not a redesign of the app and not a refactor of the theme system: it is **purely additive**.

**First, detect the project's theming model — the whole run depends on it:**
- **Model A — token-only:** ONE shared component tree; a theme is a set of **token / style files** (`tokens.scss` + overrides). Adding a theme = adding its token files; parity is measured **token-by-token** (every theme must define every token). Here a per-theme *component* fork IS an anti-pattern.
- **Model B — per-theme components:** each theme owns its **own component set** (`themes/<name>/components/…`); pages import the active theme's component via a resolver. Adding a theme = mirroring the default theme's component set into the new slot, styled to new tokens; parity is measured **component-by-component**. Here per-theme components are the ARCHITECTURE, not a fork.
Detect which from disk (do theme dirs hold *style files* or *components*?) via `_extracted-idioms.md` + `ai/patterns/theming.md`; do not assume. The gates below adapt: Parity checks *tokens* in Model A, *components* in Model B.

The single hard invariant, above design, above everything: **ADDITIVE, NEVER REPLACE.** The run creates a new theme's own files (its tokens/styles, and — in Model B — its own component set, plus layouts/entrypoints/config parallel to the existing theme) and, at most, an **append-only** registration so the app can resolve the new slot. It **never** edits an existing theme, and it **never** forks or edits the **shared LOGIC layer** — the pages, composables, stores, services, and utilities (and, in Model A only, the shared components) that all themes reuse are the one truth and stay byte-identical. If honouring a request would require changing an existing theme or the shared logic layer, the run **HALTS** and says so — it does not "just tweak" a shared page/store to make the new theme look right (that would change every theme). This is enforced mechanically by the **Additive gate** (below), not by good intentions.

Within that invariant the new theme must be **good on four axes** — three with hard pass/fail gates (Architecture, Performance, Feature-parity), plus Design (verified structurally + by the render, not a binary gate). A theme that is additive but architecturally wrong, or additive but slow, or additive but missing half the default theme's items, is a failed run; a theme that is additive but merely bland is a weak run the render surfaces for judgement:

1. **Design (modern).** A real, cohesive, current-era token system for the new theme, then its components styled to it.
2. **Architecture (technically correct).** The slot fits the project's actual theme architecture — correct structure, theme resolution wired, SSR-safe, RTL-correct if the app is bidi.
3. **Performance (fast).** The new theme's surfaces meet the project's own performance budget on mobile.
4. **Feature-complete (parity).** The new theme provides every component, icon, rendered state, and layout the **default theme** provides — a missing item is an invisible bug (it silently falls back to the default theme's component, off-language and off-brand), never a "clean simplification".

The build is driven by the **[`theme-specialist`](../agents/theme-specialist.md)** agent, which owns all four gates. This command frames the work and reports; the agent decides the tokens, mirrors the slot, wires resolution, and runs the gates.

**This command is for multi-theme architectures ONLY** — a project that already has a `themes/<name>/` (or equivalent) slot system with a default theme to mirror and a resolution mechanism to register into. A single-theme project has no slot to parallel and no resolver to extend: on such a repo this command **HALTS** and points the user at `/art-direct` (to design an identity) or `/redesign` (to rebuild a surface) instead. Detect the project's real theme layout from `_extracted-idioms.md` + `ai/patterns/theming.md`; do not assume a folder name.

### `/add-theme-variant` vs `/art-direct` vs `/redesign` vs the `theme-specialist` audit

| | `/add-theme-variant` | `/art-direct` | `/redesign` | `theme-specialist` (audit mode) |
|---|---|---|---|---|
| **What it touches** | a NEW theme slot only (additive) | the app's visual language (all themes) | ONE surface, in the existing language | nothing — read-only findings |
| Existing themes / shared layer | **never** (Additive gate) | may re-codify system-wide | shared components may be restyled system-wide | never |
| Creates | the `(N+1)`th theme, parallel to default | a built identity + tokens | a rebuilt page | a parity report |
| Parity target | **every item the DEFAULT theme has** | n/a | the Phase-1 feature manifest | default vs each variant, token-by-token |
| Design scope | the new theme's OWN components only | product-wide direction | the one surface | none |
| When | "add a `<brand>` / `dark` / `<market>` theme" | "what should this look like?" | "this page's layout is wrong" | "did we update the X theme too?" |

**Stack scope:** frontend / mobile only (`primary_frontend_framework_detected`) AND a multi-theme slot system must exist. Backend/data-only → HALT. Single-theme frontend → HALT with the `/art-direct` · `/redesign` redirect.

## When to use
- The app ships multiple themes and you need to add another — a new tenant/brand variant, a `dark` / `high-contrast` mode, a per-market skin.
- A new white-label customer needs their own theme slot without disturbing the existing customers' themes.

## When NOT to use
- The project has only ONE theme (no slot system) → `/art-direct` (design an identity) or `/redesign` (rebuild a surface). This command HALTS.
- You want to change how ALL themes look / re-codify the shared design language → `/art-direct`.
- An existing theme drifted from the default and you want to find/fix the gaps → run `theme-specialist` in its **parity-audit** mode (or `/align`), not this command.
- Rebuild one surface's layout inside the current theme → `/redesign`.

## Pre-requisites
- `PROJECT_KIND` is `frontend-*` / `mobile-*` (gated on `primary_frontend_framework_detected`). Backend/data-only → HALT.
- **A multi-theme slot system exists** — a default theme to mirror + a resolution mechanism to register into, discovered from `_extracted-idioms.md` + `ai/patterns/theming.md`. Absent → HALT with the single-theme redirect.
- **Working tree clean** at HEAD — the Additive gate diffs `git diff --name-only` against the pre-run HEAD to prove nothing outside the new slot changed; a dirty tree makes that diff meaningless. Commit or stash first.
- `_extracted-idioms.md` populated — the oracle for the token source, the theme mechanism, the default theme's component/surface inventory, breakpoints, locales, and the RTL/SSR conventions. Missing/thin → HALT → `/setup-project --refine`.
- The project's **architecture rule / theme pattern** readable (`ai/patterns/theming.md`, `.claude/rules/<the project's SSR/theming/architecture rule>`) — the slot structure, resolution mechanism, and SSR rule are CITED from the project, never invented.
- The project's **performance check** identified (`/perf-check` or the repo's equivalent) — the Perf gate runs it; if the repo has no perf check, the gate is `SKIPPED (no perf check)`, stated plainly, never faked green.
- Playwright MCP (or the project screenshot harness) wired — Verify renders the new theme across surfaces × locales × viewports; without it the visual claims are `SKIPPED (no harness)`, never asserted. (If a surface is auth-gated, an authenticated session is required — see `visual-check`'s authenticated-rendering contract; a blocked render HALTs, it is not SKIPPED.)

## Args
- `<name>` — the new theme's slug (e.g. `brand-acme`, `dark`, `market-eu`). Becomes the new slot's directory/key. Validated: must NOT collide with an existing theme (a collision would mean editing, not adding → HALT).
- `--name="<display name>"` — optional human-facing label for the theme (registry / switcher). Default: derived from `<name>`.
- `--reimagine` — **the ONLY mode that produces a genuinely NEW look.** Hands the new theme's creative direction to `/art-direct` (concept → direction → tokens) AND licenses it to **RE-COMPOSE** — rebuild each surface via `/redesign` (new layout, reordered / regrouped / *added* sections, a distinct visual language), not just retune tokens on the mirrored components. Scoped to the new slot only (the Additive gate still holds). It inherits `/art-direct`'s **hard gates** — the new theme must **BEAT the base** (rendered side-by-side) and **re-compose** (not re-paint) and carry one **named loud move**, or it HALTS (see Pillar 1). Use this whenever the new theme should look and feel *different*, not just recoloured.
- `--skin` — lighter mode: a modern **token refresh** for the new slot (palette / type / radii / elevation retune off the base theme's structure) without re-deriving a design language. A **RE-SKIN**: same layout, same sections, same components — new tokens only. Fastest additive path; still gated on parity + perf + architecture. **It will NOT change the look-direction or the layout.**
- Default (neither flag) — build a **cohesive modern** token system for the new theme and style the mirrored components to it. Also a **RE-SKIN** (same layout + sections + component set as the base, retuned tokens) — a bit bolder than `--skin`, but it does **NOT** invent a new visual language or re-compose the layout, so the new theme reads "same store, different palette." **For a genuinely new look, use `--reimagine`.**
- `--plan` — universal handoff flag (see blockquote): write the slot structure + token direction + inherited parity manifest as a plan artifact and exit before any file is created.

```bash
/add-theme-variant dark                              # add a modern dark theme, parallel to default
/add-theme-variant brand-acme --name="Acme"          # add a tenant theme
/add-theme-variant market-eu --skin                  # light token refresh into a new slot
/add-theme-variant brand-neo --reimagine             # /art-direct designs the new slot's identity
/add-theme-variant dark --plan                        # slot + token plan only; create nothing
```

## The four pillars (what "good" means)

The new theme is not done because files exist. Three of the four pillars have **hard pass/fail gates** — Architecture, Performance, and Feature-complete (parity) — plus the top **Additive** invariant and the **Visual** render. Design is the one pillar with no binary gate: "modern / cohesive" is not mechanically checkable, so it is verified **structurally** (the token system must define every role category below) and **visually** (the rendered Visual gate), not as a green/red check — an honest limit, stated rather than faked. The `theme-specialist` agent owns all of them.

### Pillar 1 — Design (modern) — scoped to the new theme's OWN components
Build a real token system for the new slot: **color roles** (surface / on-surface / brand / accent / border / state), a **type scale** (a modular ratio, weights that encode hierarchy), **spacing rhythm** (snap to the project's grid), **radii**, an **elevation** system (considered shadows or hairline borders, not framework defaults), and **motion** tokens (duration/easing) that respect `prefers-reduced-motion`. Then style the new theme's components to those tokens so the result reads current-era, not "default template". `--reimagine` derives this via `/art-direct` (concept-first); `--skin` refreshes the palette/type/radii/elevation off the default's structure. **All design work touches ONLY the new theme's own component styles** — never the shared components, never another theme.

**RE-SKIN vs NEW DIRECTION — the mode sets the ceiling (this is the #1 "it barely changed" failure).** Default and `--skin` are RE-SKINS: they mirror the base theme's layout + component set and retune only the tokens/styles, so the result reads *modern* but stays the **same composition** — same sections, same order, same layout archetype. That is by design (fast, parity-safe) but it is **not a new look**: side-by-side, a stakeholder sees "same store, different palette." `--reimagine` is the ONLY mode that lifts that ceiling — it routes the direction through `/art-direct` and RE-COMPOSES each surface via `/redesign`, inheriting their **hard gates**: (a) **beats-the-old** — rendered beside the base theme, the new must WIN on hierarchy · modern register · distinctiveness · craft · appeal; a tie or an old-win HALTs (a recolor that doesn't out-class the base is a failed reimagine); (b) **re-composition, not re-paint** — the IA / section order / grouping / layout archetype must actually DIFFER from the base; a mirror-with-new-tokens FAILS this no matter how bold the palette; (c) **one named loud move** — a deliberate signature the direction is built around. **A reimagine that renders ~identical to the base is HALTED, not shipped.** And because a new theme is *additive*, `--reimagine` is free to **ADD new section types + richer density the base never had** (a promo / collection rail, a category grid, an editorial band, brand / trust signals) — it is NOT bound to mirror the base's N components; parity (Pillar 4) only forbids *dropping* a base capability, never adding to or re-arranging them.

**The token layer does NOT reach a component library's internals — the filter/control bar is the #1 miss.** A design-token / theme layer styles the project's OWN elements; it does NOT reach the internals of a component library — PrimeVue (`SelectButton` / `Calendar` / `InputText` / `Dropdown`), MUI, Ant, Vuetify, Radix/shadcn primitives render with their DEFAULT theme unless explicit `:deep()` / `::v-deep` / theme-token / CSS-var overrides are written for their inner classes (`.p-button`, `.p-inputtext`, `.p-highlight`, …). The filter / control bar (date pickers, segmented toggles, selects, action buttons) is almost always built from these controls, so it stays default-styled while the new theme's authored elements look new — "styled the tokens, the controls follow" is FALSE, they do not follow. The new slot must therefore ship its OWN theme-scoped overrides — `[data-theme="<slug>"] :deep(.p-inputtext)` / a per-theme CSS-var map — for every library control it renders, each graded as a first-class component from the RENDER (the Visual gate below), `below-bar` until it visibly matches the new theme's language. **This stays additive:** the overrides live in the new theme's OWN style files, scoped to its selector, so they never touch the shared layer. But when a library is themed at a level the new slot cannot reach additively — a GLOBAL component-library theme config, a shared wrapper that hardcodes the control's look — re-theming it would edit the shared layer; that is an **architecture / parity LIMIT to surface** (report it; route the shared restyle to `/art-direct`), NEVER a shared-layer edit (the Additive gate HALTs it).

**Charts carry their palette in their own config, not tokens — re-theme the config for the new slot.** A chart-library chart (Chart.js / ECharts / Recharts / ApexCharts / D3) holds its colors, axis/grid lines, fonts, legend, and tooltip in its OWN config object — NOT design tokens — so the new theme's token system alone leaves every chart in the OLD theme's palette. Re-theme the chart's config explicitly for the new slot: series/dataset colors → the new palette, grid/axis → the new hairline/neutral, ticks/labels → the new type, legend + tooltip → the new surface, no-data → the new empty language — verified from the chart's ACTUAL rendered colors (the screenshot), not "a chart is present". **This stays additive when** the chart config is theme-resolvable (read from the active theme's tokens, or fed a per-theme palette the new slot supplies). **A hardcoded or SHARED chart config** — one options object baked into a shared chart wrapper, not theme-aware — cannot be re-themed without editing the shared layer: surface it as an **architecture / parity LIMIT** (`chart theming is shared, not per-theme — the new slot renders it in the base palette; a per-theme fix needs /art-direct on the wrapper`), NEVER a shared-config edit.

### Pillar 2 — Architecture (technically correct) — CITE the project, don't invent
The slot must fit the project's real theme architecture:
- **Slot structure** parallel to the existing default theme — the same components / layouts / style-entrypoints / config the default theme has, in the new theme's own directory. Mirror the default's shape exactly; do not invent a structure.
- **Theme resolution wired** — detect the project's mechanism and register the new slot the way that mechanism expects: **glob auto-discovery** (registration is often just dropping the new theme's config folder — no code edit at all), a **whitelist / enum** (append the new slug — append-only), or a **resolver / factory** (extend it additively). Detect which; do not assume.
- **SSR-safety** — obey whatever the project's SSR rule says: no unguarded browser globals (`window` / `document` / `localStorage`) at module scope; the project's required conditional strategy (e.g. static conditionals over dynamic component resolution where its SSR demands it); hydration-safe theme selection. Cite the project's SSR rule.
- **RTL / logical CSS** — if the app is bidi, the new theme's styles use logical properties (`margin-inline-start`, not `margin-left`) and mirror correctly; verified in Verify.
- **Shared layer untouched** — the new theme composes the shared components; it never forks or edits them.

### Pillar 3 — Performance (fast) — GATED on the project's own budget
Apply the project's own performance conventions to the new theme's components — cite the project's performance rule, do not hardcode a stack: the project's **LCP / above-the-fold image strategy**, **code-splitting** for heavy libraries the theme pulls in, the **bundle budget**, and **hydration / SSR discipline**. A new theme must not regress the app's performance. The **Perf gate** runs the project's perf check on the new theme's key routes on mobile; a breach HALTS.

### Pillar 4 — Feature-complete (parity vs the PARITY-BASE theme) — HARD GATE
The new theme must provide **everything the parity-base theme provides** — the parity base being the richest/active theme picked in Flow step 2, which may or may not be the folder literally named `default`. Measured against the project's model:
- **Model B (per-theme components):** every **component**, every **per-component style partial**, every **icon** (card / action / section-header, empty-state illustrations), every **rendered state** (loading / empty / error / success / zero), and every **layout** the base theme ships. A missing component does not error — it **silently falls back to the resolver's fallback theme's component**, which renders off-language and off-brand (an invisible bug, not a missing feature). Basing the variant on a plain fallback stub instead of the rich active theme is the failure mode where every section renders empty.
- **Model A (token-only):** every **token** the shared components consume must be defined in the new theme (or explicitly inherited) — a token the shared `Button` reads but the new theme doesn't define renders undefined/inherited (the same invisible bug, at the token level).

**Charts and framework library controls are PARITY-INVISIBLE — present ≠ re-themed.** A chart component can be `✓` in the parity manifest (the file exists, the tokens are defined) while its config still renders the BASE theme's palette, and a library control (the filter/control bar) can be `✓` while it still renders the LIBRARY's default theme — because neither reads the new theme's tokens (Pillar 1). Parity presence is therefore necessary but not sufficient: the manifest enumerates the chart / the control as items (so they cannot be silently dropped), and the **Visual gate re-grades them from the render** (below) — a chart still in the base palette, or a control still in the default look, is `below-bar` / `INCOMPLETE` even though the file exists. Where clearing that would require the shared layer (a hardcoded shared chart config, a globally-themed control), surface it as an **architecture / parity LIMIT** — never a silent pass, never a shared-layer edit.

Build the **parity manifest** from the default theme, then diff the new theme against it item-by-item. A single missing item is `INCOMPLETE` / HALT, never silent. An item the new theme intentionally leaves to the default needs an **explicit keep / move / drop record** (the same keep/move/drop discipline `/redesign` uses) — never an unrecorded gap.

**Parity is FEATURE parity, NOT LAYOUT parity.** It guarantees no base *capability* is dropped — every component / state / icon the base ships still renders somewhere in the new theme (kept, or moved / demoted / re-grouped / re-shaped). It does **not** require the same layout or section order. So: **default / `--skin` keep the base structure → counts match exactly**; **`--reimagine` RE-COMPOSES** (re-ranks, regroups, changes the archetype) and MAY **ADD** new section types → its count floor is "**≥ the base's items, none dropped**," and a re-composed or richer new theme passes parity as long as every base capability is present somewhere in the render. Never fail a reimagine for *re-arranging* or *adding* — only for *dropping* a base capability without a keep/move/drop record.

## Flow (silent — no phase numbers reach the user)

The agent runs these internally; the user sees only the final report.

1. **Frame** — parse `<name>` + mode; gate: frontend present? multi-theme slot system present? `<name>` free (no collision)? working tree clean? Any no → HALT with the matching redirect. Capture pre-run HEAD for the Additive gate. **Mode-ambition check (do this before building):** if the request wants a *genuinely new / bold / distinct* theme — words like "new look", "different", "redesign", "not just a recolor", or a reference design the user admires — but neither `--reimagine` was passed, SURFACE it: `default`/`--skin` only re-skin the base's layout and will come back looking ~identical (the recolor complaint). Recommend `--reimagine` (the only mode that invents a new language + re-composes + can add new sections). Do NOT silently ship a recolor when the user asked for a new look.
2. **Pick the parity base — the RICHEST/ACTIVE theme, NOT the folder named `default`.** The parity base is the theme the new variant must mirror. It is whichever theme the resolver actually **selects for this project** (e.g. the API/config `template` / active-theme value) OR, if that is unknown, the theme with the **largest component/section/SCSS-partial set** on disk. In many projects the canonical theme *is* the one folder-named `default` — but not always: a repo can carry a plain `default` fallback stub alongside a rich `new_theme` (or similar) that is the real active theme. Basing the variant on the plain stub produces a variant that renders as an empty page — every section silently absent. **Detect the base by richness + resolver-selection, never by the literal name `default`.** Count components/partials across all existing themes and cite which one you chose and why.
3. **Inventory (the parity contract)** — read the **parity-base theme** (from step 2) off disk: enumerate its component / icon / state / layout / per-section-style set into the **parity manifest** (counted), and record its slot structure, token source, and the project's theme-resolution mechanism (glob / whitelist / resolver) + SSR rule + RTL setup from `_extracted-idioms.md` + `ai/patterns/theming.md` + the cited architecture rule. This manifest is the non-negotiable reference for the Parity gate. **Model B:** copy the base theme's full component set + per-component style partials into the new slot, rewrite every internal `themes/<base>/…` path + `data-theme="<base>"` selector to the new slug, THEN retune tokens — a token-only swap on top of the base's real components is what makes every section change, not just the CSS variables.
4. **Design the new theme** — default: a cohesive modern token system styled onto the mirrored components (a re-skin); `--skin`: a modern token refresh off the base's structure (a lighter re-skin); **`--reimagine`: run `/art-direct` scoped to the new slot to invent the direction (concept → tokens), THEN re-compose each surface via `/redesign` — new layout / section order / grouping, ADDING new section types where the direction calls for it, styled to the new language.** Color roles · type scale · spacing rhythm · radii · elevation · reduced-motion-safe motion. **Under `--reimagine`, step 5's "mirror the base's component set" becomes "re-compose from the base's *capabilities*"** — the components are the raw material, not a layout to copy.
5. **Build the slot (additive only)** — create the new theme's directory parallel to the parity base: its tokens, its component styles (mirroring the base theme's component set, styled to the new tokens), its layouts / style-entrypoints / config. Include the new slot's OWN theme-scoped `:deep()`/CSS-var overrides for every framework component-library control it renders (the filter/control bar's date pickers / selects / segmented toggles) and re-theme every chart's config to the new palette — neither inherits the token layer (Pillar 1); a control or chart themed only at the shared layer is surfaced as an **architecture / parity LIMIT**, never edited here. Apply the project's performance conventions to these components. **Only new paths under the new theme's dir are written.**
6. **Register (append-only)** — wire theme resolution the way the detected mechanism expects: glob auto-discovery → often nothing to edit; whitelist/enum → append the slug; resolver → extend additively. Never a rewrite.
7. **Run the four gates** — Additive, Architecture, Parity, Perf (below). Any HALT stops the run with done-vs-pending.
8. **Verify + report** — render the new theme across the project's key surfaces × every locale (incl. RTL) × mobile + desktop; confirm all four gates green; emit the brief report + honesty footer.

## Gates (each is a hard mechanism, not a claim)

- **Additive gate (the top invariant — blocks everything).** `git diff --name-only` since the pre-run HEAD must show **only** new paths under the new theme's directory, plus at most an **append-only** registration edit (a slug appended to a whitelist / a config dropped for glob discovery). **Any** modification to an existing theme's files, or to ANY shared-layer file (shared pages / components / composables / stores / services / utils), is an immediate **HALT** — the run reports the offending path and does not proceed. (For a glob-discovery project, even the registration edit is often zero — the gate then expects a pure new-files diff.) This gate runs before the run can report success; a diff that touches shared or existing-theme code is never "a small necessary tweak".
- **Architecture gate.** The new slot's structure parallels the default theme (same component/layout/entrypoint/config set); theme resolution actually resolves the new slot (verified — switch to it and it loads); SSR-safe per the project's rule (no unguarded browser globals; the project's required conditional strategy); RTL-correct if bidi. A structural mismatch or an SSR violation → HALT.
- **Parity gate (HARD — no silent fallback).** Diff the new theme against the Phase-2 parity manifest item-by-item; print a parity table (`item | present ✓ / MISSING ✗ / default-only (recorded)`). **Every item is `✓` or an explicitly recorded keep/move/drop.** A single un-recorded `MISSING` is `INCOMPLETE — <item> falls back to default theme`, never a pass. Counts must match.
- **Perf gate.** Run the project's perf check (`/perf-check` or equivalent) on the new theme's key routes, on mobile. A breach of the project's budget → HALT. No perf check in the repo → `SKIPPED (no perf check)`, stated, never faked.
- **Visual gate.** Render the new theme across the project's key surfaces × every locale (incl. RTL) × mobile + desktop, IN the new theme (via `visual-check`). Contrast COMPUTED (AA per theme), never asserted. Then run an **adversarial per-component audit from the pixels** (mirrors `redesign.md` Phase 6 — computing contrast is NOT enough; a framework-default control, an un-re-themed chart, or a bland component passes a contrast check while rendering off-theme): after each render, **enumerate EVERY distinct component visible in the new theme** — button (each variant), input / select / combobox, the **filter / control bar**, tab, card / tile, table (header · row · zebra · hover), badge / chip, **chart** (series · axis · legend · tooltip · no-data), pagination, icon-button, toast, modal, and each empty / loading / error state — and grade each ONE against concrete modern tells (intentional elevation/hairline not the framework default; type on the scale; spacing on the rhythm; purposeful color at AA; real hover/focus-visible/active states; not a raw library default). **The grader is ADVERSARIAL and SEPARATE from the builder** — dispatch `ux-reviewer` / a fresh critic, never the `theme-specialist` self-grading its own tokens (self-grading inflates). Each component **defaults to `below-bar`; a `✓` must be justified from the screenshot**, not from the token file. Two tells are the new theme's specific traps: (1) a **framework component-library control does NOT inherit the token layer** — a PrimeVue/MUI/Ant/Vuetify `SelectButton`/`Calendar`/`Dropdown`/input renders in the LIBRARY's default theme unless the new slot wrote explicit `:deep()`/CSS-var overrides for its inner classes (`.p-button`, `.p-inputtext`, `.p-highlight`), so the filter/control bar survives in the default look while authored elements look new — grade it `below-bar` until it visibly matches the new theme; (2) a **chart still in the base palette** (its config was not re-themed) is `below-bar` even though it is parity-present. Print a per-component table (`component | ✓ / below-bar | what's wrong`); the run **LOOPS** (bounded — default 3 rounds, the same refine bound `/redesign` Phase 6 uses) on the new theme's OWN styles while any component is `below-bar`, re-rendering and re-grading. A `below-bar` that can only be cleared by editing the shared layer (a globally-themed control, a hardcoded shared chart config) is the **architecture / parity LIMIT** — surfaced, not fixed here (the Additive gate HALTs the edit). No harness → `SKIPPED (no harness) — visual claims + component quality NOT verified`; blocked render (auth wall) → HALT (`RENDER BLOCKED`), authenticate and re-render, never grade a login page, never SKIPPED.

All five must be green (or an honest `SKIPPED` for the harness/perf-absent cases) before the run reports success.

## What you see

```
/add-theme-variant dark

New theme: dark   (display: "Dark")   mode: default (cohesive modern)

Additive:   ✓ git diff since pre-run HEAD = 9 new files under themes/dark/ + 1 append
            (dark slug appended to the theme whitelist) · 0 shared/existing-theme edits
Architecture: ✓ slot mirrors default (components · layouts · entry · config) ·
              resolution: whitelist enum (append-only) · SSR-safe (no window at
              module scope; static theme conditional per the project's SSR rule) ·
              RTL: logical properties ✓
Design:     token system built — 6 color roles · type scale (1.25) · spacing rhythm ·
            radii · elevation (hairline + 2 shadows) · motion (reduced-motion-safe)
Parity:     18/18 items vs default (12 components · 4 icon sets · loading/empty/error/
            zero states · 2 layouts) — 0 MISSING · 0 default-only
Perf:       /perf-check on 3 key routes @ mobile — within budget (LCP 1.9s · bundle +6KB)
Visual:     3 surfaces × {en LTR, ar RTL} × {mobile, desktop} rendered in `dark` →
            RTL ✓ · a11y AA ✓ (contrast computed per theme) · per-component audit
            (adversarial, ux-reviewer) 14/14 ✓ — filter bar's PrimeVue Dropdown +
            Calendar re-themed via :deep() · Chart.js series re-themed to dark palette
Commits:    3 (tokens · component styles · registration) · diff +540/−0
Artifacts:  .claude/artifacts/add-theme-variant/2026-07-12T10-14/

Not validated: cross-browser (Playwright ran chromium-only)
Risks:         none — purely additive; existing themes untouched (Additive gate ✓)
Revert:        git revert <first>..<last>   (or git reset --hard <pre-run HEAD>)
```

If the screenshot harness was unavailable, `Visual:` reads `SKIPPED (no harness) — visual claims + component quality NOT verified` (no per-component audit). If the repo has no perf check, `Perf:` reads `SKIPPED (no perf check)`. Under `--plan` the output ends at the slot + token + parity-manifest plan and its path — nothing is created.

## What you DON'T see
- Phase numbers, the manifest diff mechanics, or the token-derivation internals.
- The `theme-specialist` dispatch or the per-gate machinery.
- A prompt per file — the run is silent; `git` (per-commit) is the review surface. The one interaction it keeps is a **keep / move / drop** call when the new theme has no home for a default-theme item — never dropped silently.

## Don't (hard rules)
- **DON'T edit any existing theme or any shared-layer file — ever.** The Additive gate HALTs on it. If the new theme "needs" a shared-component change, that is a different task (`/art-direct` / `/redesign`), not this command.
- **DON'T fork the shared LOGIC layer per theme** — pages, composables, stores, services, and utils are one truth for all themes; never copy them per theme. (In a **Model A** token-only project this extends to shared *components* too — themes differ via tokens, not `Button.dark` + `Button.default` forks. In a **Model B** project each theme legitimately owns its own component set — that is the architecture, not a fork; the rule there is parity across those sets, never a forked *logic* layer.)
- **DON'T invent the slot structure, the resolution mechanism, or the SSR rule** — CITE the project's (`_extracted-idioms.md`, `ai/patterns/theming.md`, the architecture/SSR rule). Detect glob vs whitelist vs resolver; do not assume.
- **DON'T leave a parity gap silent.** A missing theme component falls back to the default theme's off-brand component — every default item is present in the new theme or an explicit recorded keep/move/drop.
- **DON'T introduce unguarded browser globals** or the wrong conditional strategy for the project's SSR — obey the cited SSR rule.
- **DON'T break RTL** — logical properties, mirrored, verified in the render for every shipped RTL locale.
- **DON'T assume the token layer reaches a component library's controls or a chart's config.** PrimeVue/MUI/Ant/Vuetify controls (the filter/control bar) and Chart.js/ECharts/Recharts charts render in the LIBRARY default / OLD palette until the new slot writes explicit `:deep()`/CSS-var overrides (controls) and re-themes the chart config — grade each from the render, not the token file. When a control is globally-themed or a chart config is shared/hardcoded, surface it as an architecture/parity LIMIT; never edit the shared layer to fix it (the Additive gate HALTs).
- **DON'T pass a component on contrast alone.** AA-computed contrast does not prove a component is on-theme; a framework-default control or an un-re-themed chart clears contrast while looking off-brand. The per-component audit (adversarial, separate critic, `below-bar`-by-default) is what verifies each rendered component — never the builder self-grading its own tokens.
- **DON'T print a verification checkmark the run did not render / measure.** No harness → `SKIPPED`; no perf check → `SKIPPED`; blocked auth render → HALT. Never a faked green.
- **DON'T run on a single-theme project** — HALT and redirect to `/art-direct` / `/redesign`. There is no slot to parallel.
- **DON'T ship a RE-SKIN as a "new theme" when the user wanted a new LOOK.** `default`/`--skin` recolor the base's *same layout* — they cannot produce a new direction. If the request is for something *different / bold / redesigned*, recommend `--reimagine` (the only mode that invents a language + re-composes + adds sections). Under `--reimagine`, a variant that renders ~identical to the base failed the beats-the-old + re-composition gates → HALT and regenerate bolder, never ship it.
- **DON'T design outside the new theme's own components** — the new theme's tokens style the new theme's components; nothing else.
- **Rollback is `git`.** The run starts from a clean tree and lands as discrete commits; because it is purely additive, `git reset --hard <pre-run HEAD>` removes the theme with zero collateral.

## Failure modes
- **Single-theme project (no slot system)** — HALT; redirect to `/art-direct` (design an identity) or `/redesign` (rebuild a surface). Nothing to parallel here.
- **No frontend in the repo** (backend/data-only) — HALT; point at the frontend repo.
- **`<name>` collides with an existing theme** — HALT; adding a colliding slug would mean editing that theme, which violates the invariant. Ask for a distinct name (or route to the parity audit if the intent was "fix the existing X theme").
- **Working tree dirty** — HALT; the Additive gate needs a clean pre-run HEAD to prove nothing outside the slot changed.
- **`_extracted-idioms.md` missing / thin** — the theme-mechanism oracle is unavailable; HALT → `/setup-project --refine`.
- **Additive gate trips** (a shared or existing-theme file changed) — HALT immediately; report the offending path; the fix is to move that change out of this command (it is not additive).
- **Parity gate INCOMPLETE** (a default item has no home in the new theme) — surface it as keep / move / drop; never drop silently. Record the decision; re-run the gate.
- **Library control / chart re-themeable only in the shared layer** — a globally-configured component-library theme, or a chart's options baked into a shared wrapper, means the new slot cannot re-theme it additively (its filter/control bar stays default-styled, its chart stays in the base palette — the per-component audit grades them `below-bar`). This is an **architecture / parity LIMIT**, surfaced in the report (`<control/chart> is themed at the shared layer — the new slot renders it in the base look; a per-theme fix needs /art-direct on the shared component`), never a shared-layer edit — the Additive gate HALTs that.
- **Perf gate breach** — HALT; the new theme regresses the budget on mobile; fix the theme's images/splitting/bundle before shipping.
- **`--reimagine` came back looking ~identical to the base (re-painted, not re-composed)** — it failed the inherited beats-the-old + re-composition gates → HALT; regenerate a bolder direction (name a louder move, re-rank the IA, add new section types) or route to `/art-direct` directly. A "new theme" that's a recolor of the same layout is the exact miss this mode exists to prevent. (Default / `--skin` are re-skins by design — this failure mode is specific to `--reimagine`, which promises a new look.)
- **Screenshot harness unavailable / perf check absent** — do NOT fake; mark `SKIPPED` with what was not verified; build what can be built; note it under `Not validated:`.
- **Blocked render** (auth wall) — HALT (`RENDER BLOCKED`), authenticate (storageState / login step per `visual-check`), re-render — never SKIPPED, never graded against a login page.

## Cross-references
- agent [`theme-specialist`](../agents/theme-specialist.md) — **runs** this command: owns the four gates (Additive · Architecture · Parity · Perf) and the new-theme build; also the parity-audit mode for existing-theme drift.
- `/art-direct` — design the app's visual language (all themes), or (via `--reimagine`) the new slot's own direction; for a single-theme project, the redirect target.
- `/redesign` — rebuild ONE surface inside the existing theme; the Phase-6 parity gate this command inherits lives there, as does the canonical per-component visual audit + the framework-control / chart re-theme disciplines the Visual gate mirrors.
- `/align` — enforce existing tokens/rules across themes (no new slot).
- skill `visual-check` — renders the new theme across surfaces × locales × viewports (the Visual gate); owns the authenticated-render + blocked-render contract.
- agent [`ux-reviewer`](../agents/ux-reviewer.md) — the adversarial, separate critic that runs the Visual gate's per-component audit (grades each rendered component `below-bar`-by-default), so the builder never self-grades its own tokens.
- agent `design-system-architect` — codifies tokens when `--reimagine` routes through `/art-direct`.
- pattern `theming`, `dark-mode`, `rtl`, `design-systems`, `motion` — the system context the new slot lands in.

## Stack scope
Frontend / mobile only, AND a multi-theme slot system must exist. Gated on `primary_frontend_framework_detected` + a discoverable `themes/<name>/` (or equivalent) slot system. Backend/data-only → HALT. Single-theme frontend → HALT with the `/art-direct` · `/redesign` redirect.
