---
name: lcp-audit
description: Static scan for LCP-resource priority mistakes — lazy hero images, missing fetchpriority, absent preload/preconnect for the LCP image. Turns "optimize LCP" prose into grep detectors.
---

# lcp-audit

The LCP element (usually the hero image) must be discovered + fetched first. Every finding cites the element at `<file:line>` + the matched pattern + the fix. Static scan — pair with `web-vitals-field` to confirm the real LCP element.

## Scans for

### 1. Lazy-loaded LCP candidate

```
BAD:  <img src="/hero.jpg" loading="lazy" class="hero">
GOOD: <img src="/hero.jpg" fetchpriority="high">
```

Grep `loading=["']lazy["']` on `<img>` near hero/banner/above-fold markers. Lazy is correct *below* the fold.

### 2. Hero image without `fetchpriority="high"`

Grep above-the-fold `<img>` lacking `fetchpriority="high"` (or the framework priority prop).

### 3. Late-discovered LCP image with no preload

```
GOOD: <link rel="preload" as="image" href="/hero.avif" imagesrcset="..." fetchpriority="high">
```

CSS `background-image` / JS-injected hero with no matching preload → flag.

### 4. Cross-origin LCP image with no preconnect

`<link rel="preconnect" href="https://images.cdn.example">` for the LCP image's CDN origin.

### 5. Framework priority primitive missing on the hero

| Framework | LCP-image priority |
|---|---|
| Next | `<Image priority>` (fetchpriority=high + eager) |
| Nuxt | `<NuxtImg preload :loading="'eager'">` |
| Astro | `<Image loading="eager">` |
| Angular | `NgOptimizedImage` `ngSrc` + `priority` |
| Plain React/Vue/Svelte | `fetchpriority="high"` + width/height |

## Output

```
LCP audit — <route set>

1. components/Hero.tsx:14      [report-with-fix]  <Image> on the LCP element — no `priority`. Fix: add `priority`.
2. pages/index.vue:8          [report-with-fix]  <img class="masthead" loading="lazy"> — drop lazy; <NuxtImg preload eager>.
3. styles/home.css:22         [report-with-fix]  .hero { background-image } — late-discovered. Fix: <link rel="preload" as="image">.
```

## False positives / gotchas

- Only the SINGLE LCP element gets `fetchpriority="high"` — flag if >1.
- The LCP element differs by viewport/route — confirm via `web-vitals-field` (`attribution.element`) *(performance pack, when co-installed)*. Absent that pack there is no field attribution: pick the element from the lab trace and label it `LCP element: lab-inferred (no field source)`.
- A text LCP element has no image to preload — its cost is font + render-blocking CSS/JS.
- Preloading an unused image hurts LCP — preload only the confirmed resource.

## Halt conditions

- No LCP finding without the cited element + matched pattern.
- No `fetchpriority="high"` on more than one element per view.
- No preload for an image not confirmed to be the LCP resource.
- If the LCP element is text, don't target image priority — re-scope to font/CSS.
