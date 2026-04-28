---
name: dark-mode
description: Pattern: Dark Mode
kind: ai-pattern
pack: ui-ux
---

# Pattern: Dark Mode

Dark mode is a parallel design system, not a CSS filter. Eyes perceive contrast, color, and elevation differently against a dark substrate — copying light-mode tokens with their luminance flipped produces glare, muddy hierarchy, and unreadable brand colors. Treat dark as a first-class theme that rides on the same component contracts.

## Context

You need explicit dark mode (not just `prefers-color-scheme` on a few pages) when:
- The product runs at night or in low-light contexts (chat, IDE, video, reading).
- You ship per-tenant theming and dark is one of the brand variants.
- Accessibility audits flag light-mode glare or low contrast in dim viewing.

Don't bother with dark mode on a marketing site that's read for 30 seconds — the cost (palette tuning, image variants, QA matrix doubling) outweighs the benefit.

## The token translation table

The mistake is "swap light hex for dark hex on a per-component basis". The discipline is "every semantic token has a light value AND a dark value, no component knows which is active".

```css
:root {
  /* Light — surfaces ascend by darkness  */
  --color-bg-base:        #ffffff;
  --color-bg-surface:     #f8f9fa;
  --color-bg-elevated:    #ffffff;
  --color-border:         #e5e7eb;
  --color-text-primary:   #111827;
  --color-text-secondary: #4b5563;
  --color-text-disabled:  #9ca3af;
  --color-brand:          #3366ff;
  --color-success:        #10b981;
  --color-danger:         #dc2626;
  --shadow-md:            0 1px 3px rgb(0 0 0 / 0.1);
}

[data-theme="dark"] {
  /* Dark — surfaces ascend by lightness  */
  --color-bg-base:        #0b0f17;   /* not pure #000 — OLED smearing */
  --color-bg-surface:     #111827;
  --color-bg-elevated:    #1f2937;   /* modals, popovers */
  --color-border:         #2d3748;
  --color-text-primary:   #f5f7fa;   /* not pure #fff — too sharp */
  --color-text-secondary: #9ca3af;
  --color-text-disabled:  #4b5563;
  --color-brand:          #5c85ff;   /* lifted + slightly desaturated */
  --color-success:        #34d399;
  --color-danger:         #f87171;
  --shadow-md:            0 0 0 1px rgb(255 255 255 / 0.06);  /* "shadow" via subtle stroke */
}
```

Note that `--shadow-md` swaps from drop-shadow (depth via darkness) to inset stroke (depth via light) — naive shadow tokens are invisible on dark backgrounds.

## The three rules people break

1. **Dark elevation goes UP in lightness, not down.** A modal on `--color-bg-base: #0b0f17` should sit on `--color-bg-elevated: #1f2937` (lighter). In light mode the relationship inverts. Components must reference the semantic token (`--color-bg-elevated`), never `gray-200` or `#fff`.

2. **Brand colors usually need a second value.** A vibrant brand orange `#ff6b00` glares painfully on dark. Lift luminance and drop saturation 5-10% for the dark token. Test against the actual dark background — eyeballing in Figma is unreliable because the surrounding canvas affects perception.

3. **Pure black + pure white is the amateur tell.** `#000` causes "OLED smearing" during scroll on phones (pixels gate fully off and lag re-lighting). `#fff` text on dark causes halation (perceived bloom around glyphs). The hex pairs `#0b0f17 / #f5f7fa` work for almost everything; tune from there.

## Asset variants

```html
<!-- Logo with light + dark variants -->
<picture>
  <source srcset="/logo-dark.svg" media="(prefers-color-scheme: dark)">
  <img src="/logo-light.svg" alt="Brand">
</picture>
```

For SVG illustrations: prefer `currentColor` on strokes/fills so they inherit the theme's text color. PNGs with baked-in white backgrounds need a dark variant or transparent re-export — there is no CSS workaround that doesn't look broken.

Code blocks need a dark syntax theme (e.g., `github-dark`, `one-dark`). Light themes inverted via `filter: invert()` produce wrong colors for keyword/string/comment classes.

## Flash of wrong theme (FOWT) on SSR

The page renders light, JS runs, theme switches to dark — user sees a 200ms white flash. Solution: write the theme attribute into `<html>` BEFORE any CSS resolves, via a blocking inline script.

```html
<head>
  <script>
    // Runs before any CSS — sets data-theme synchronously
    (function () {
      var stored = localStorage.getItem('theme');
      var theme = stored || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
      document.documentElement.dataset.theme = theme;
    })();
  </script>
  <link rel="stylesheet" href="/app.css">
</head>
```

The inline script is the only place a small amount of synchronous JS in `<head>` is justified. Bundlers will warn — suppress for this one snippet.

## Trade-offs

Pro: parallel themes are cheaper than a runtime CSS filter and respect designer intent for every color. Pro: tokens become a first-class API designers + engineers share. Con: every new color decision now happens twice (light value, dark value) — and forgetting one ships a broken component. Con: assets (logos, illustrations, screenshots) double — there is no way around variant assets for raster art.

Don't ship dark mode if you can't commit to:
- Adding a dark value for every new token.
- Running visual regression in both themes on every PR.
- Maintaining brand-color dark variants when marketing rebrands.

## Common mistakes

- **`filter: invert(1) hue-rotate(180deg)` on `<html>`** — destroys photos, brand colors, and any SVG that relies on stroke. The "30-line dark mode" trick that loses by week three.
- **Hex literals inside components.** `color: #111827` works in light, breaks in dark. The grep query `rg "#[0-9a-f]{3,6}" src/components` should be near zero hits.
- **Same shadow tokens in both themes.** `0 1px 3px rgb(0 0 0 / 0.1)` is invisible on dark. Either swap to a brighter inset stroke or drop shadows entirely on dark surfaces.
- **Dark mode added in week 12 of a 12-week project.** Every decision before then assumed white background. Audit tokens, retrofit semantic names, accept it'll take longer than building it from day one.
- **Toggles that use the OS preference but never persist user override.** A user who prefers dark in their app but light in their OS (or vice versa) needs a per-app preference, persisted, with OS as the first-load default only.

## Testing

- Visual regression (Chromatic, Percy, Playwright screenshots) configured to capture every story in both themes. Diffs in either theme block the merge.
- Contrast audit per theme via axe-core or pa11y. Dark mode often regresses on disabled-text contrast (the gray gets too dim against the now-darker surface).
- Toggle rapidly during a manual smoke test — nothing should flicker, jump, or briefly show wrong colors. Look for transition stutter on the body background especially.
- Test a tenant-branded dark variant if you ship per-tenant themes: `data-theme="dark" data-tenant="acme"` and verify Acme's brand orange still has AA contrast on the dark surfaces.

## References

- Material Design 3 dark theme guidelines (m3.material.io) — surface elevation reasoning.
- Apple HIG "Dark Mode" — system color semantics.
- Adam Argyle's "Building a custom dark theme switch" (web.dev) — FOWT prevention technique.
