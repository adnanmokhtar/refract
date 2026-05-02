---
name: design-iterate
description: Generate 2-3 style variants of a component or page (scoped SCSS diffs only), screenshot each via Playwright MCP, present side-by-side so the user can pick a direction. Invoke when the user says "try a few variants", "iterate on the design", "what if it looked like X", or isn't sure about visual direction.
---

# Design Iterate

For when the user isn't sure what they want and "just describe it" isn't working. You generate 2–3 variants, screenshot each, and let them point.

## Inputs

- `$TARGET` — file path to a `.vue` component or page
- `$DIRECTION` — optional: "more minimal", "more colorful", "card-based", etc.

## Steps

1. Read `$TARGET` and capture the current styles (scoped `<style lang="scss">` block only).
2. Run `visual-check` on the route that renders `$TARGET` to get the baseline screenshot.
3. Generate 3 style variants in separate branches via `git stash`:
   - **Variant A** — closer to current, polished (spacing tighter, cleaner borders).
   - **Variant B** — bolder (more color, larger type, heavier shadows).
   - **Variant C** — minimal (flat, less chrome, more whitespace).
   Each variant modifies ONLY the scoped `<style>` block — no template or script changes.
4. For each variant: apply, screenshot via Playwright MCP, save to `.claude/artifacts/design-iterate/<timestamp>/<variant>.png`, then revert before applying the next.
5. Leave the file in its original state. Present the user with:
   - 3 screenshots side-by-side in the response
   - A one-line summary of each variant's tradeoffs
   - "Pick A/B/C or say how to tune one" as the call to action
6. Once they pick, apply that variant and run `visual-check` one more time.

## Rules

- NEVER change template or script — variants are style-only.
- NEVER leave a variant applied without user confirmation.
- Use design tokens (`$primary`, `$space-md`, mixins) — no hardcoded values even in variants.
- Stay scoped — no global style bleed.
