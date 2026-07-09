---
name: image-optimization
description: Static scan for image delivery mistakes — legacy formats where AVIF/WebP would cut bytes, missing responsive srcset/sizes, absent width/height (CLS), missing lazy-loading below the fold, raw <img> where the framework offers an optimized component, and oversized sources served into small slots. Owns format / dimensions / responsiveness / loading; LCP priority-hints stay with lcp-audit.
---

# image-optimization

## Premise

Images are the heaviest bytes and the top CLS source. The browser needs the right format (AVIF/WebP), the right size per viewport (`srcset`/`sizes`), and reserved space (`width`/`height`). Every finding cites the element at `<file:line>` + pattern + fix in **the project's own image primitive**. This skill owns format / responsiveness / dimensions / lazy; the LCP image's priority hints belong to `lcp-audit`.

## Adapt first

Mirror the image primitive: Next `next/image`, Nuxt `<NuxtImg>`, Astro `astro:assets`, Angular `NgOptimizedImage`, SvelteKit `enhanced-img`, plain `<picture>`, or a CDN (`f_auto,q_auto,w_…`). Route fixes through it; only hand-roll `<picture>` if none exists.

## Scans for

1. Legacy format (jpg/png) with no AVIF/WebP `<picture>`/`type` path or `format=auto` CDN param.
2. Missing responsive `srcset`/`sizes` (one fixed image for all viewports).
3. Missing `width`+`height` (or CSS `aspect-ratio`) → CLS. **Biggest CLS lever.**
4. Missing `loading="lazy"` below the fold — and *wrongly present* on the hero (→ lcp-audit).
5. Raw `<img>` where the framework's optimized component exists.
6. Oversized source into a small slot (1600px original → 48px avatar).
7. Missing blur/LQIP placeholder on large images (perceived perf).

## Output

```
image-optimization — <routes>  (primitive: <e.g. next/image>)
1. ProductCard.tsx:18 — raw <img>, no width/height/srcset. Fix: <Image width height sizes … />
2. gallery/page.tsx:44 — 30 below-fold <img> no lazy. Fix: loading="lazy" decoding="async".
3. Avatar.vue:6 — 1600px into 48px. Fix: <NuxtImg width=48 height=48 sizes="48px"> (or CDN w_48).
```

## Gotchas

- Never lazy-load the LCP/hero image (→ lcp-audit).
- SVG + tiny icons are exempt from srcset/format.
- `width`/`height` set the aspect ratio, not display size — don't "fix" a correct one.
- A wrong `sizes` is worse than none — verify against the real rendered width per breakpoint.

## Halt conditions

- No finding without `<file:line>` + pattern + fix in the project's own primitive.
- Don't lazy the LCP image; don't hand-roll `<picture>` when a component/CDN exists; don't propose `sizes` without checking rendered width.
