---
name: design-iterate
description: Two modes. `pick` (attended) — generate 2–3 style variants at the correct design-system layer (leaf scoped styles, shared wrapper, or design tokens), screenshot via Playwright MCP, present side-by-side so the user picks. `refine` (unattended, for /redesign Phase 6 + /art-direct build) — render the approved design, self-critique the PIXELS against the caller's rubric, fix the weakest lens (depth/motion/modern/perf/i18n), re-render, loop up to $MAX_REFINE rounds until it clears the bar. Honors $SCOPE_TIER so the same affordance is not duplicated across pages. Invoke for "try a few variants" / "iterate on the design", or as the quality loop that turns a one-pass build into a good design.
---

# Design Iterate

For when the user isn't sure what they want and "just describe it" isn't working. You generate 2–3 variants, screenshot each, and let them point. **Layer depends on `$SCOPE_TIER`** — see Inputs.

## Inputs

- `$TARGET` — file path:
  - **`leaf-local`** — `.vue` / `.tsx` / `.svelte` page or leaf component.
  - **`wrapper-variant`** — shared wrapper component named in `_extracted-idioms.md`.
  - **`token`** — design tokens / theme file (SCSS variables, CSS custom properties module, `tailwind.config` extension — path from idioms).
  - **`wrapper-extract`** — **do not invoke this skill** until the orchestrator has finished extraction and re-targets `wrapper-variant`; if called prematurely, halt and return to `/enhance-ui`.
- `$SCOPE_TIER` — **`leaf-local`** | **`wrapper-variant`** | **`token`** | (never **`wrapper-extract`** at iterate time). Default **`leaf-local`** when omitted (backward compatible).
- `$CONSUMER_ROUTES` — optional list of routes / URLs / story paths to screenshot when `$SCOPE_TIER` is **`token`** or **`wrapper-variant`**. Provided by `/enhance-ui` Phase 1.5. When absent, fall back to `visual-check` resolution for `$TARGET` only (legacy behaviour).
- `$DIRECTION` — optional: "more minimal", "more colorful", "card-based", etc.

## Steps

### All tiers — variants A/B/C

Generate three variants (polished / bolder / minimal) unless user tune requests otherwise:

- **Variant A** — closer to current, polished (spacing tighter, cleaner borders).
- **Variant B** — bolder (more color, larger type, heavier shadows).
- **Variant C** — minimal (flat, less chrome, more whitespace).

Use **design tokens** (`$primary`, `$space-md`, CSS vars, Tailwind theme keys) — no arbitrary hex in variants unless the project's idiom allows it.

### Tier-specific — what to edit

| `$SCOPE_TIER` | Step 1 — Read | Step 3 — Apply variants to |
|---|---|---|
| **`leaf-local`** | Scoped `<style>` / CSS modules / styled blocks on `$TARGET` only. | Scoped style block only — **no template or script changes.** |
| **`wrapper-variant`** | Wrapper component's styles + existing props API from `_extracted-idioms.md`. | Wrapper scoped styles; **template / script / prop changes only after explicit user confirmation** in Step 5 (e.g. new `variant=` prop). |
| **`token`** | Token definitions in `$TARGET` (theme file). | Token values only — no component template edits in this skill (orchestrator may chain a separate token-sync doc edit). |

### Steps (numbered)

1. Read `$TARGET` and capture the editable style surface per tier (table above).
2. **Baseline screenshots** — If `$CONSUMER_ROUTES` is non-empty, run `visual-check` (or Playwright) on **each** consumer route and save baselines. If empty, run `visual-check` on the route that renders `$TARGET` (legacy).
3. Generate 3 variants (stash / branch / patch workflow per repo convention). Each variant modifies only the allowed layer for that tier.
4. For each variant: apply, screenshot via Playwright MCP — **when `$CONSUMER_ROUTES` is set, capture each route** so propagation is visible; save to `.claude/artifacts/design-iterate/<timestamp>/<variant>-<route-slug>.png`, then revert before the next variant.
5. Leave `$TARGET` in original state until pick. Present:
   - Screenshots side-by-side (group by variant or by route — whichever reads clearer).
   - One-line tradeoffs per variant.
   - For **`wrapper-variant`**: if a variant needs a new prop or slot, say so and **ask confirm** before applying template/script edits.
   - "Pick A/B/C or tune" as CTA.
6. Once they pick, apply that variant. Run **`visual-check` on every route in `$CONSUMER_ROUTES`** again for final verification; if empty, single-route check.

### Refine mode (`$MODE=refine` — unattended: render → critique → improve → re-render)

The steps above are **`pick` mode** (attended): make 3 variants, a human chooses. In an unattended / `--yes` flow (e.g. `/redesign` Phase 6, `/art-direct` build), there is no human to pick — so this skill runs the **refine loop** instead, which is how a one-pass build becomes a genuinely good design:

1. Apply the approved design, screenshot the rendered surface (`$SCOPE_TIER` allowed layer only; `$CONSUMER_ROUTES` if set) at the breakpoints × theme × locale.
2. **Look at the render and self-critique it against the caller's rubric** — the `/redesign` Design-principles lenses (hierarchy, rhythm, states, motion-actually-implemented, modern register, performance, a11y, RTL). Score each `✓ / Δ / ✗` from the *pixels*, not the code.
3. **Fix the weakest lens in code, then re-render.** Each round must move a named lens `Δ`→`✓` (e.g. "flat/no depth → add the elevation token + hover lift"; "static → add the list-entrance + hover transitions"; "raw i18n key visible → add the locale strings"). Do not restate the same score twice.
4. Loop steps 2–3 up to **`$MAX_REFINE`** rounds (default 3). Stop early when every targeted lens + motion/modern/performance is `✓`.
5. Leave the surface in the improved state; emit the per-round lens deltas so the caller's scorecard shows what each round bought. A residual `Δ` that couldn't clear in the budget is reported honestly, never hidden.

Refine mode never invents a NEW visual language (that is `creative-director` / `/art-direct`) and never changes the approved structure (that is fixed by `/redesign`'s gate) — it drives the approved design to the quality bar by iterating on the rendered result.

## Rules

- **Template / script:** **NEVER** change template or script when `$SCOPE_TIER == leaf-local`. For **`wrapper-variant`**, template / prop-API changes require **explicit user confirmation** before applying the picked variant.
- **NEVER** leave a variant applied without user confirmation (pick step).
- Use design tokens — no hardcoded raw values where the project supplies a token.
- **Stay scoped** — no global style bleed unless `$SCOPE_TIER == token` and the tokens file is the intentional global surface.
- **`wrapper-extract`** is not handled here — orchestrator runs extraction first.
