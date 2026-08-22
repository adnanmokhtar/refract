---
name: dark-mode
description: Pattern: Dark Mode
kind: ai-pattern
pack: ui-ux
---

# Pattern: Dark Mode

> **Hard rule** — Dark is a parallel THEME, not a filter and not a per-component prop. It rides on the theming mechanism (`theming.md` owns that: the `[data-theme]` attribute, the token layer, persistence, the SSR anti-flash script). This file owns only what is *different about dark* — the values, and the four places a straight luminance flip produces a worse product.

**The failure this prevents:** a team wires the theme switch correctly, inverts every token's lightness, and ships a dark mode that reads as a cheap negative of the light one — flat, because the shadows disappeared; glaring, because the brand colour was never re-tuned; and broken in three places (logos, illustrations, code blocks) where an asset carries a baked-in white background. All of that passes a contrast audit.

**Scope split — read this before duplicating work:** `theming.md` owns the *mechanism* (token layer, `[data-theme]` on `<html>`, persistence + first-visit default, the `<head>` inline script that prevents flash-of-wrong-theme, per-tenant composition, the migration path). Do not restate it here and do not re-derive it. This file is the *dark-specific* half.

**When to apply**
- Product is used in low-light contexts (chat, IDE, video, reading apps).
- The design system already has semantic tokens you can extend with a dark set.
- Visual-regression infra exists, or lands in the same PR, for both themes.

**When NOT to apply**
- Marketing site read for < 60s — the QA + asset doubling cost outweighs the benefit.
- App with hex literals in components — retrofit tokens FIRST (`theming.md § Migration path`), then add dark. Dark mode on hardcoded colours is a rewrite disguised as a feature.
- No SSR strategy yet — flash-of-wrong-theme will be the user's first impression.

**Halt conditions / mandatory cites**
- Cite the design-token file as `<path:line>` before proposing dark values; "I'll grep for tokens" is a halt.
- Cite a component using `var(--token)` as `<path:line>` proving the indirection layer exists; if components use raw hex, halt and retrofit first.
- Cite the SSR entry point as `<path:line>` (the anti-flash script per `theming.md`) before claiming FOWT is fixed.
- Cite the visual-regression config as `<path:line>` proving **both** themes render in CI; if absent, halt and require the matrix added in the same PR.
- Refuse to ship dark values without a contrast audit **per theme** — cite the audit config or runbook by path. A ratio that passes in light says nothing about dark.

## What actually changes in dark (the whole point of this file)

### 1. Elevation inverts — and shadows stop working

In light, depth comes from something darker being cast onto a lighter surface. **In dark there is nothing darker to cast**, so a reused `--shadow-md` is invisible and the theme reads flat. Depth in dark comes from the surface getting *lighter* as it rises, plus a light hairline:

```css
:root {                        /* light: surfaces ascend by DARKNESS */
  --color-bg-base:     #ffffff;
  --color-bg-elevated: #ffffff;
  --shadow-md:         0 1px 3px rgb(0 0 0 / 0.1);
}
[data-theme="dark"] {          /* dark: surfaces ascend by LIGHTNESS */
  --color-bg-base:     #0b0f17;
  --color-bg-elevated: #1f2937;                      /* modals, popovers — LIGHTER than base */
  --shadow-md:         0 0 0 1px rgb(255 255 255 / 0.06);  /* depth via a lit edge, not a cast */
}
```

Components must reference the semantic role (`--color-bg-elevated`), never a ramp step (`gray-200`) or a literal — otherwise the inversion cannot happen at all.

### 2. Brand colours need a second value, not the same one

A saturated brand hue that reads confident on white glares on a dark surface. Lift its luminance and drop saturation slightly for the dark token, then check it **against the actual dark background** — judging it on a light canvas in a design tool is unreliable because the surround changes the perception. Every brand-adjacent token (`brand`, `brand-hover`, `success`, `danger`, `focus-ring`) gets its own dark value or it will be either invisible or shouting.

### 3. Pure black and pure white are the amateur tell — but verify on a device

`#000` base with `#fff` text is the maximum possible luminance ratio, and that is the problem, not the achievement: readers report glow/halation around white glyphs, and OLED panels are reported to smear during scroll at full-black. **Both effects are panel- and person-dependent**, so the determinant is a look on a real device in a dark room — not a hex value copied from a blog. What is safe to say: near-black and near-white (e.g. `#0b0f17` / `#f5f7fa`) cost you nothing and remove the risk, so start there and tune up only if you have a reason.

### 4. Assets do not theme themselves

- **Logos** — ship a dark variant and pick it declaratively:
  ```html
  <picture>
    <source srcset="/logo-dark.svg" media="(prefers-color-scheme: dark)">
    <img src="/logo-light.svg" alt="Brand">
  </picture>
  ```
  (If the theme can be overridden independently of the OS preference — and per `theming.md` it should be — the `<picture>` query is not enough on its own; drive the swap from the same `[data-theme]` attribute the rest of the theme uses.)
- **SVG illustrations** — use `currentColor` on strokes and fills so they inherit the theme's text colour. This is the single highest-leverage asset decision.
- **Raster art with a baked-in white background** needs a dark variant or a transparent re-export. There is no CSS workaround that does not look broken.
- **Code blocks** need a real dark syntax theme. Inverting a light one with `filter: invert()` produces wrong hues for keyword / string / comment classes — the one place the inversion trick is most tempting and most visibly wrong.

## Trade-offs

Parallel themes beat a runtime filter on every axis except day-one effort: designer intent is preserved per colour, tokens become a shared API, and switching costs one DOM mutation. The price is real and recurring: **every new colour decision now happens twice**, and forgetting one ships a broken component; **raster assets double**; the QA matrix doubles.

Don't ship dark mode if you can't commit to: a dark value for every new token, visual regression in both themes on every PR, and maintaining brand-colour dark variants through the next rebrand.

## Common mistakes

- **`filter: invert(1) hue-rotate(180deg)` on `<html>`** — the "30-line dark mode" that destroys photos, brand colours, and any SVG relying on stroke colour. It loses by week three.
- **Reusing the light theme's shadow tokens** — invisible on dark, so the whole UI flattens. Swap to a lit edge (rule 1).
- **Elevation that goes the wrong way** — a modal *darker* than the page behind it reads as a hole, not a layer.
- **One brand value for both themes** — see rule 2.
- **Dark mode added in week 12 of a 12-week project** — every decision before then assumed a white background. Budget the token retrofit, not just the palette.
- **Assuming the OS preference is the whole feature** — a user who wants dark in your app and light in their OS needs a persisted per-app override, with the OS value as the first-load default only (`theming.md § Persistence`).

## Testing

- Visual regression capturing every story/route in **both** themes; a diff in either blocks the merge.
- Contrast audit **per theme**. Dark most often regresses on *disabled* text — the grey that read as muted on white reads as absent on a dark surface.
- One look on a real OLED device, in a dark room, scrolling — the only way to settle rule 3.
- If you ship per-tenant themes, verify a tenant's brand colour against the dark surfaces too (`[data-theme="dark"][data-tenant="…"]`), not just against light.

## References

- [Material Design 3 — colour roles](https://m3.material.io/styles/color/roles) — the system's own surface/elevation role vocabulary.
- [Apple Human Interface Guidelines — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) — platform semantic-colour behaviour. (Client-rendered page; open it in a browser rather than expecting a plain fetch to return the text.)
- [Adam Argyle, "Building a theme switch component" (web.dev)](https://web.dev/articles/building/a-theme-switch-component) — the accessible switch + getting the preference to the browser early enough to avoid a colour flash.
- `theming.md` (this pack) — the mechanism this pattern rides on.
