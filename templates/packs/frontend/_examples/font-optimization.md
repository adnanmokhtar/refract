---
name: font-optimization
description: Static scan for web-font delivery mistakes — missing font-display (invisible text / FOIT), critical font not preloaded, render-blocking remote font CSS (Google Fonts) not self-hosted, no fallback metric override (font-swap CLS), full unsubset charset, too many families/weights, and legacy formats before woff2. Owns font loading + swap-CLS; text-LCP timing cross-links lcp-audit.
---

# font-optimization

## Premise

A web font blocks text (FOIT) or shifts layout on swap (FOUT → CLS), and each family/weight is a byte payload + often a cross-origin round-trip. The fix set is small: `font-display`, preload the critical font, self-host, subset, metric-matched fallback. Every finding cites the `@font-face`/link at `<file:line>` + pattern + fix. Text-LCP timing cross-links `lcp-audit`.

## Adapt first

Mirror the mechanism: `next/font` (self-hosts + swap + size-adjust), `@nuxt/fonts`, `@fontsource/*` / Fontaine, plain `@font-face`, or a remote Google Fonts `<link>` (the thing to replace). If a self-hosting primitive is already used, most items are handled — verify.

## Scans for

1. Missing `font-display` → FOIT (up to 3s invisible text). Fix: `swap` (or `optional` for zero-CLS).
2. Critical above-the-fold font not `<link rel="preload" as="font" crossorigin>`.
3. Remote Google Fonts `<link>` (render-blocking + extra origin + consent surface) not self-hosted.
4. No metric-matched fallback (`size-adjust`/`ascent-override`) with `swap` → reflow CLS.
5. Full charset not subset (`unicode-range`) on single-script content.
6. Too many families/weights — prefer one variable font when ≥3 weights.
7. Legacy format (ttf/eot/otf/woff) before woff2, or `src` with no `format()`.

## Output

```
font-optimization — <scope>  (mechanism: <e.g. next/font | @font-face | Google <link>>)
1. layout.tsx:6 — Google Fonts <link> (blocking, consent). Fix: next/font/google (self-host + swap + fallback).
2. fonts.css:3 — @font-face no font-display → invisible text. Fix: font-display: swap.
3. fonts.css:3 — swap but no size-matched fallback → CLS. Fix: size-adjust/ascent-override fallback face.
4. fonts.css:10 — 6 static weights. Fix: one variable font (wght 100–900).
```

## Gotchas

- `font-display: optional` deliberately skips the swap for zero CLS — don't "fix" it.
- Preload only the 1–2 above-the-fold fonts; `crossorigin` is mandatory (else double-fetch).
- System-font stacks need none of this.
- `unicode-range` subsetting can drop needed glyphs — only for confirmed single-script content.

## Halt conditions

- No finding without the cited `@font-face`/link + pattern + fix.
- Don't flip a deliberate `optional` to `swap`; don't over-preload or omit `crossorigin`; don't subset a multilingual project blindly; don't reintroduce a remote `<link>` when self-hosting exists.
