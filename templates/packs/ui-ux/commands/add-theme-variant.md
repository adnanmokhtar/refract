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
- `--reimagine` — hand the **new theme's** creative direction to `/art-direct` (concept → direction → tokens), **scoped to the new slot only**. Use when the new theme should have a genuinely distinct point of view, not just a recolor. `/art-direct`'s output is confined to the new theme's own files — the Additive gate still holds.
- `--skin` — lighter mode: a modern **token refresh** for the new slot (palette / type / radii / elevation retune off the default theme's structure) without re-deriving a full design language. The fastest additive path; still gated on parity + perf + architecture.
- Default (neither flag) — build a **cohesive modern** token system for the new theme from scratch and style its components to it. Between `--skin` (retune) and `--reimagine` (new language) in ambition.
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

Build the **parity manifest** from the default theme, then diff the new theme against it item-by-item. **Counts must match** (N items in the default → N in the new theme). A single missing item is `INCOMPLETE` / HALT, never silent. An item the new theme intentionally leaves to the default needs an **explicit keep / move / drop record** (the same keep/move/drop discipline `/redesign` uses) — never an unrecorded gap.

## Flow (silent — no phase numbers reach the user)

The agent runs these internally; the user sees only the final report.

1. **Frame** — parse `<name>` + mode; gate: frontend present? multi-theme slot system present? `<name>` free (no collision)? working tree clean? Any no → HALT with the matching redirect. Capture pre-run HEAD for the Additive gate.
2. **Pick the parity base — the RICHEST/ACTIVE theme, NOT the folder named `default`.** The parity base is the theme the new variant must mirror. It is whichever theme the resolver actually **selects for this project** (e.g. the API/config `template` / active-theme value) OR, if that is unknown, the theme with the **largest component/section/SCSS-partial set** on disk. In many projects the canonical theme *is* the one folder-named `default` — but not always: a repo can carry a plain `default` fallback stub alongside a rich `new_theme` (or similar) that is the real active theme. Basing the variant on the plain stub produces a variant that renders as an empty page — every section silently absent. **Detect the base by richness + resolver-selection, never by the literal name `default`.** Count components/partials across all existing themes and cite which one you chose and why.
3. **Inventory (the parity contract)** — read the **parity-base theme** (from step 2) off disk: enumerate its component / icon / state / layout / per-section-style set into the **parity manifest** (counted), and record its slot structure, token source, and the project's theme-resolution mechanism (glob / whitelist / resolver) + SSR rule + RTL setup from `_extracted-idioms.md` + `ai/patterns/theming.md` + the cited architecture rule. This manifest is the non-negotiable reference for the Parity gate. **Model B:** copy the base theme's full component set + per-component style partials into the new slot, rewrite every internal `themes/<base>/…` path + `data-theme="<base>"` selector to the new slug, THEN retune tokens — a token-only swap on top of the base's real components is what makes every section change, not just the CSS variables.
4. **Design the new theme's tokens** — default: a cohesive modern token system; `--reimagine`: run `/art-direct` scoped to the new slot (concept → direction → tokens); `--skin`: a modern token refresh off the base's structure. Color roles · type scale · spacing rhythm · radii · elevation · reduced-motion-safe motion.
5. **Build the slot (additive only)** — create the new theme's directory parallel to the parity base: its tokens, its component styles (mirroring the base theme's component set, styled to the new tokens), its layouts / style-entrypoints / config. Apply the project's performance conventions to these components. **Only new paths under the new theme's dir are written.**
6. **Register (append-only)** — wire theme resolution the way the detected mechanism expects: glob auto-discovery → often nothing to edit; whitelist/enum → append the slug; resolver → extend additively. Never a rewrite.
7. **Run the four gates** — Additive, Architecture, Parity, Perf (below). Any HALT stops the run with done-vs-pending.
8. **Verify + report** — render the new theme across the project's key surfaces × every locale (incl. RTL) × mobile + desktop; confirm all four gates green; emit the brief report + honesty footer.

## Gates (each is a hard mechanism, not a claim)

- **Additive gate (the top invariant — blocks everything).** `git diff --name-only` since the pre-run HEAD must show **only** new paths under the new theme's directory, plus at most an **append-only** registration edit (a slug appended to a whitelist / a config dropped for glob discovery). **Any** modification to an existing theme's files, or to ANY shared-layer file (shared pages / components / composables / stores / services / utils), is an immediate **HALT** — the run reports the offending path and does not proceed. (For a glob-discovery project, even the registration edit is often zero — the gate then expects a pure new-files diff.) This gate runs before the run can report success; a diff that touches shared or existing-theme code is never "a small necessary tweak".
- **Architecture gate.** The new slot's structure parallels the default theme (same component/layout/entrypoint/config set); theme resolution actually resolves the new slot (verified — switch to it and it loads); SSR-safe per the project's rule (no unguarded browser globals; the project's required conditional strategy); RTL-correct if bidi. A structural mismatch or an SSR violation → HALT.
- **Parity gate (HARD — no silent fallback).** Diff the new theme against the Phase-2 parity manifest item-by-item; print a parity table (`item | present ✓ / MISSING ✗ / default-only (recorded)`). **Every item is `✓` or an explicitly recorded keep/move/drop.** A single un-recorded `MISSING` is `INCOMPLETE — <item> falls back to default theme`, never a pass. Counts must match.
- **Perf gate.** Run the project's perf check (`/perf-check` or equivalent) on the new theme's key routes, on mobile. A breach of the project's budget → HALT. No perf check in the repo → `SKIPPED (no perf check)`, stated, never faked.
- **Visual gate.** Render the new theme across the project's key surfaces × every locale (incl. RTL) × mobile + desktop, IN the new theme (via `visual-check`). Contrast COMPUTED (AA per theme), never asserted. No harness → `SKIPPED (no harness) — visual claims NOT verified`; blocked render (auth wall) → HALT, not SKIPPED.

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
            RTL ✓ · a11y AA ✓ (contrast computed per theme)
Commits:    3 (tokens · component styles · registration) · diff +540/−0
Artifacts:  .claude/artifacts/add-theme-variant/2026-07-12T10-14/

Not validated: cross-browser (Playwright ran chromium-only)
Risks:         none — purely additive; existing themes untouched (Additive gate ✓)
Revert:        git revert <first>..<last>   (or git reset --hard <pre-run HEAD>)
```

If the screenshot harness was unavailable, `Visual:` reads `SKIPPED (no harness) — visual claims NOT verified`. If the repo has no perf check, `Perf:` reads `SKIPPED (no perf check)`. Under `--plan` the output ends at the slot + token + parity-manifest plan and its path — nothing is created.

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
- **DON'T print a verification checkmark the run did not render / measure.** No harness → `SKIPPED`; no perf check → `SKIPPED`; blocked auth render → HALT. Never a faked green.
- **DON'T run on a single-theme project** — HALT and redirect to `/art-direct` / `/redesign`. There is no slot to parallel.
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
- **Perf gate breach** — HALT; the new theme regresses the budget on mobile; fix the theme's images/splitting/bundle before shipping.
- **Screenshot harness unavailable / perf check absent** — do NOT fake; mark `SKIPPED` with what was not verified; build what can be built; note it under `Not validated:`.
- **Blocked render** (auth wall) — HALT (`RENDER BLOCKED`), authenticate (storageState / login step per `visual-check`), re-render — never SKIPPED, never graded against a login page.

## Cross-references
- agent [`theme-specialist`](../agents/theme-specialist.md) — **runs** this command: owns the four gates (Additive · Architecture · Parity · Perf) and the new-theme build; also the parity-audit mode for existing-theme drift.
- `/art-direct` — design the app's visual language (all themes), or (via `--reimagine`) the new slot's own direction; for a single-theme project, the redirect target.
- `/redesign` — rebuild ONE surface inside the existing theme; the Phase-6 parity gate this command inherits lives there.
- `/align` — enforce existing tokens/rules across themes (no new slot).
- skill `visual-check` — renders the new theme across surfaces × locales × viewports (the Visual gate); owns the authenticated-render + blocked-render contract.
- agent `design-system-architect` — codifies tokens when `--reimagine` routes through `/art-direct`.
- pattern `theming`, `dark-mode`, `rtl`, `design-systems`, `motion` — the system context the new slot lands in.

## Stack scope
Frontend / mobile only, AND a multi-theme slot system must exist. Gated on `primary_frontend_framework_detected` + a discoverable `themes/<name>/` (or equivalent) slot system. Backend/data-only → HALT. Single-theme frontend → HALT with the `/art-direct` · `/redesign` redirect.
