---
name: dark-mode
kind: example
pack: ui-ux
---

# Pattern: Dark Mode

> **Hard rule** — Dark is a parallel THEME, not a filter and not a per-component prop. It rides on the theming mechanism (`theming.md` owns that: the `[data-theme]` attribute, the token layer, persistence, the SSR anti-flash script). This file owns only what is *different about dark* — the values, and the four places a straight luminance flip produces a worse product.

**The failure this prevents:** a team wires the theme switch correctly, inverts every token's lightness, and ships a dark mode that reads as a cheap negative of the light one — flat, because the shadows disappeared; glaring, because the brand colour was never re-tuned; and broken in three places (logos, illustrations, code blocks) where an asset carries a baked-in white background. All of that passes a contrast audit.

**Scope split:** `theming.md` owns the *mechanism* (token layer, `[data-theme]` on `<html>`, persistence + first-visit default, the `<head>` anti-flash script, per-tenant composition, migration path). Do not restate it here.

**Halt conditions / mandatory cites**
- Cite the design-token file as `<path:line>` before proposing dark values; "I'll grep for tokens" is a halt.
- Cite a component using `var(--token)` as `<path:line>` proving the indirection layer exists; if components use raw hex, halt and retrofit first.
- Cite the SSR entry point as `<path:line>` (the anti-flash script per `theming.md`) before claiming FOWT is fixed.
- Cite the visual-regression config as `<path:line>` proving **both** themes render in CI; if absent, halt and require the matrix added in the same PR.
- Refuse to ship dark values without a contrast audit **per theme** — a ratio that passes in light says nothing about dark.

## What actually changes in dark

### 1. Elevation inverts — and shadows stop working

In light, depth comes from something darker cast onto a lighter surface. **In dark there is nothing darker to cast**, so a reused `--shadow-md` is invisible and the theme reads flat. Depth in dark comes from the surface getting *lighter* as it rises, plus a light hairline:

```css
:root {                        /* light: surfaces ascend by DARKNESS */
  --color-bg-base:     #ffffff;
  --color-bg-elevated: #ffffff;
  --shadow-md:         0 1px 3px rgb(0 0 0 / 0.1);
}
[data-theme="dark"] {          /* dark: surfaces ascend by LIGHTNESS */
  --color-bg-base:     #0b0f17;
  --color-bg-elevated: #1f2937;                      /* modals, popovers — LIGHTER than base */
  --shadow-md:         0 0 0 1px rgb(255 255 255 / 0.06);  /* depth via a lit edge */
}
```

Components reference the semantic role (`--color-bg-elevated`), never a ramp step (`gray-200`) or a literal — otherwise the inversion cannot happen at all.

### 2. Brand colours need a second value

A saturated brand hue that reads confident on white glares on a dark surface. Lift luminance, drop saturation slightly, and check it **against the actual dark background** — judging on a light canvas is unreliable because the surround changes perception. Every brand-adjacent token (`brand`, `brand-hover`, `success`, `danger`, `focus-ring`) gets its own dark value.

### 3. Pure black and pure white are the amateur tell — but verify on a device

`#000` with `#fff` text is the maximum possible luminance ratio, and that is the problem: readers report glow/halation around white glyphs, and OLED panels are reported to smear during scroll at full black. **Both effects are panel- and person-dependent** — the determinant is a look on a real device in a dark room, not a hex value from a blog. Near-black / near-white (`#0b0f17` / `#f5f7fa`) cost nothing and remove the risk.

### 4. Assets do not theme themselves

- **Logos** — ship a dark variant:
  ```html
  <picture>
    <source srcset="/logo-dark.svg" media="(prefers-color-scheme: dark)">
    <img src="/logo-light.svg" alt="Brand">
  </picture>
  ```
  If the theme can be overridden independently of the OS preference (it should be), drive the swap from the same `[data-theme]` attribute instead of the media query alone.
- **SVG illustrations** — `currentColor` on strokes/fills so they inherit the theme's text colour. Highest-leverage asset decision.
- **Raster art with a baked-in white background** needs a dark variant or a transparent re-export; no CSS workaround looks right.
- **Code blocks** need a real dark syntax theme. `filter: invert()` on a light one produces wrong hues for keyword / string / comment classes.

## Trade-offs

Parallel themes beat a runtime filter on every axis except day-one effort. The price is recurring: **every new colour decision happens twice**, raster assets double, the QA matrix doubles.

Don't ship dark mode without committing to: a dark value for every new token, visual regression in both themes on every PR, and maintaining brand-colour dark variants through the next rebrand.

## Common mistakes

- **`filter: invert(1) hue-rotate(180deg)` on `<html>`** — destroys photos, brand colours, and stroke-dependent SVG. Loses by week three.
- **Reusing the light theme's shadow tokens** — invisible on dark; the UI flattens.
- **Elevation the wrong way** — a modal darker than the page behind it reads as a hole, not a layer.
- **One brand value for both themes.**
- **Dark mode added in week 12 of a 12-week project** — every prior decision assumed a white background. Budget the token retrofit, not just the palette.
- **Assuming the OS preference is the whole feature** — a persisted per-app override is required, with the OS value as first-load default only.

## Testing

- Visual regression capturing every story/route in **both** themes; a diff in either blocks the merge.
- Contrast audit **per theme**. Dark most often regresses on *disabled* text.
- One look on a real OLED device, in a dark room, scrolling.
- Per-tenant themes: verify the tenant brand colour against the dark surfaces too.

## References

- [Material Design 3 — colour roles](https://m3.material.io/styles/color/roles) — surface/elevation role vocabulary.
- [Apple Human Interface Guidelines — Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) — platform semantic-colour behaviour (client-rendered page).
- [Adam Argyle, "Building a theme switch component" (web.dev)](https://web.dev/articles/building/a-theme-switch-component) — the accessible switch + avoiding the colour flash.
- `theming.md` (this pack) — the mechanism this pattern rides on.
