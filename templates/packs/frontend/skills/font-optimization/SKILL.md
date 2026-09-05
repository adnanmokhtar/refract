---
name: font-optimization
description: Static scan for web-font delivery mistakes — missing font-display (invisible text / FOIT), critical font not preloaded, render-blocking remote font CSS (Google Fonts) not self-hosted, no fallback metric override (font-swap CLS), full unsubset charset, too many families/weights, and legacy formats before woff2. Owns font loading + swap-CLS; text-LCP timing cross-links lcp-audit.
allowed-tools: [Read, Grep, Glob, Bash]
---

# font-optimization

## Premise

**A web font is on the critical path for text: it either blocks the text from rendering (FOIT — invisible text) or, when it swaps in, shifts the layout (FOUT → CLS).** Every custom family/weight/style is also a byte payload and often an extra cross-origin round-trip. The fix set is small and mechanical: declare `font-display`, preload the one critical font, self-host, subset, and give the fallback matching metrics so the swap doesn't move anything. Every finding cites the declaration at `<file:line>` + the matched pattern + the fix. "Fonts are slow" without the cited `@font-face`/link is not a finding.

**Closure verbs** — exactly one per finding. This skill emits `report-with-fix`, `dismiss` (a deliberate `font-display: optional`, a system-font stack, a framework primitive that already self-hosts and metric-adjusts), and `halt-handoff` (a text LCP element's priority → `lcp-audit`; a locale set that forbids the proposed subset → `/i18n-audit`).

Division of labor: this skill owns **font loading strategy + swap-induced CLS**. When the LCP element is a *heading/text block*, its LCP timing depends on font+CSS — `lcp-audit` flags that the LCP element is text; this skill supplies the font fix. Pair with `lighthouse-ci` ("Ensure text remains visible during webfont load", CLS).

## Adapt to the codebase first

Detect and **mirror the font mechanism in use** — several frameworks self-host + metric-adjust automatically, which dissolves most findings:

| Framework / setup | Font primitive | What it auto-handles |
|---|---|---|
| **Next.js** | `next/font/google` / `next/font/local` | self-hosts (no external request), `font-display: swap`, auto `size-adjust` fallback (near-zero CLS), preload |
| **Nuxt** | `@nuxt/fonts` | self-host + download + `font-display` + fallback metrics |
| **SvelteKit / Astro / Vite** | `@fontsource/*` packages or Fontaine (`unplugin-fontaine`) | self-host; Fontaine injects `size-adjust` fallbacks |
| **Plain CSS** | `@font-face` + `<link rel="preload">` | manual: you set `font-display`, `format('woff2')`, preload, subset, `size-adjust` |
| **Remote (Google Fonts `<link>`)** | the CSS `<link>` | ← the thing to *replace*: render-blocking, extra origin, privacy/consent surface |

If the project already uses `next/font` / `@nuxt/fonts` / Fontsource, most items below are handled — verify, don't re-implement.

## Scans for

### 1. Missing `font-display` → FOIT (invisible text)

Without `font-display`, most browsers block text for up to 3s waiting for the font.

```
BAD:  @font-face { font-family: Inter; src: url(inter.woff2) format('woff2'); }
GOOD: @font-face { font-family: Inter; src: url(inter.woff2) format('woff2'); font-display: swap; }
```

Flag any `@font-face` with no `font-display`. `swap` for body/brand text; `optional` when zero CLS matters more than always getting the custom font.

### 2. Critical font not preloaded (self-hosted)

A self-hosted font referenced only from CSS is discovered late (after CSS parses).

```
GOOD: <link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin>
```

Flag the primary above-the-fold font with no `<link rel="preload" as="font" crossorigin>`. **Preload only the one or two fonts actually used above the fold** — preloading all weights hurts.

### 3. Render-blocking remote font CSS not self-hosted

A Google Fonts `<link>` costs an extra origin (DNS+TCP+TLS), is render-blocking, and is a privacy/consent surface (GDPR).

```
BAD:  <link href="https://fonts.googleapis.com/css2?family=Inter…" rel="stylesheet">
GOOD: self-host via next/font, @nuxt/fonts, or @fontsource/inter (no external request)
```

Flag remote font stylesheets; recommend self-hosting through the framework primitive. If it must stay remote, require `<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>`.

### 4. No fallback metric override → font-swap CLS

When the custom font swaps in, differing metrics reflow text unless the fallback is size-matched.

```
GOOD: @font-face { font-family: 'Inter-fallback'; src: local('Arial');
        size-adjust: 107%; ascent-override: 90%; descent-override: 22%; line-gap-override: 0%; }
      body { font-family: Inter, 'Inter-fallback', sans-serif; }
```

Flag a custom body font with `font-display: swap` and no adjusted fallback (`size-adjust`/`ascent-override`, or Fontaine/`next/font` which generate it). This is the font half of CLS.

### 5. Full charset shipped (not subset)

A full multi-language font can be 100–300KB; a Latin subset is a fraction.

```
GOOD (self-host): unicode-range: U+0000-00FF;   // Latin subset per @font-face
```

Flag large self-hosted fonts with no `unicode-range` subsetting for a project whose content is single-script. (Don't strip glyphs a multilingual site needs.)

### 6. Too many families / weights / styles

Each weight+style is a separate file. Loading 6 weights when the UI uses 2 is wasted bytes.

Flag more than ~2 families or a long weight list where the design system uses few. Prefer a **variable font** (one file, all weights) when ≥3 weights are loaded.

### 7. Legacy format before `woff2` / missing `format()`

```
GOOD: src: url(f.woff2) format('woff2');       // woff2 first; drop ttf/eot/woff for modern targets
```

Flag `@font-face` shipping `.ttf`/`.eot`/`.otf`/`.woff` (non-woff2) as the primary, or `src` with no `format()` hint (forces a wasted download attempt).

### 8. Framework primitive not adopted

Flag hand-rolled `@font-face` + `<link>` in a project that ships `next/font` / `@nuxt/fonts` / Fontsource — adopting it self-hosts, sets `font-display`, and generates metric fallbacks in one change.

## Output

```
font-optimization — <scope>   (mechanism: <e.g. next/font | @font-face | Google <link>>)

Findings: 4

1. app/layout.tsx:6                                    [report-with-fix]
   <link href="fonts.googleapis.com/css2?family=Inter"> — remote, render-blocking, consent surface.
   Fix: import { Inter } from 'next/font/google' (self-hosts + swap + size-adjust fallback).

2. styles/fonts.css:3                                  [report-with-fix]
   @font-face Inter — no font-display → up to 3s of invisible text.
   Fix: add font-display: swap;

3. styles/fonts.css:3                                  [report-with-fix]
   swap set but no size-matched fallback → text reflows on swap (CLS).
   Fix: add an 'Inter-fallback' @font-face with size-adjust/ascent-override; list it before sans-serif.

4. styles/fonts.css:10-20                              [report-with-fix]
   6 static weights of one family loaded.
   Fix: one variable font file (Inter var, wght 100–900) — smaller than 3 static weights.
```

## False positives / gotchas

- **`font-display: optional` intentionally skips the swap** to guarantee zero CLS (uses fallback if the font isn't cached in ~100ms). Don't "fix" a deliberate `optional` to `swap`.
- **Preloading every weight backfires** — it floods the critical path. Preload only the 1–2 above-the-fold fonts; let the rest lazy-load via CSS.
- **`crossorigin` is mandatory on font preload** even same-origin, or the browser fetches the font twice. Flag a font `preload` missing `crossorigin`.
- **System font stacks need none of this** — if the project uses `system-ui`/native stacks, there's nothing to optimize; don't invent a web-font problem.
- **Subsetting can drop needed glyphs** — only recommend `unicode-range` Latin subsets for confirmed single-script content (check the i18n locales).

## When to run

- When `lighthouse-ci` flags "Ensure text remains visible during webfont load", font CLS, or render-blocking font CSS.
- When `lcp-audit` reports the LCP element is a heading/text block (its cost is font + CSS, not image priority).
- After adding a font, a new weight, or a Google Fonts `<link>`.

## Halt conditions

- Halt on any finding without the cited `@font-face`/link at `<file:line>` + the matched pattern + the fix.
- Halt if a fix proposes changing a deliberate `font-display: optional` to `swap` without cause.
- Halt if a preload set exceeds the 1–2 above-the-fold fonts actually used, or omits `crossorigin`.
- Halt if `unicode-range` subsetting is proposed for a multilingual project without confirming the locale set.
- Halt if the project already self-hosts via a framework primitive and the fix reintroduces a remote `<link>`.

## Related

- `lcp-audit` — a text LCP element waits on the font; the preload this skill adds and the priority that skill sets are the same critical path seen from two ends.
- `image-optimization` — the other asset lane. Font swap-CLS and image dimension-CLS both land in the same CLS score; report them separately so the fix is attributable.
- `lighthouse-ci` — measures the CLS / render-blocking result of these fixes; it does not tell you which `@font-face` caused it.
- `.claude/rules/frontend-principles.md` — the `font-display` / self-host / preload-critical-font / size-adjusted-fallback MUSTs this skill enforces.
- `i18n.md` (ai-pattern) — subsetting is locale-dependent: a Latin-only subset silently breaks a declared non-Latin locale. Check the declared locale set before proposing `unicode-range`.
