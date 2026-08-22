---
name: lcp-audit
description: Static scan for LCP-resource priority mistakes — lazy hero images, missing fetchpriority, absent preload/preconnect for the LCP image. Turns "optimize LCP" prose into grep detectors.
---

# lcp-audit

The LCP element (usually the hero image) must be discovered + fetched first. Every finding cites the element at `<file:line>` + the matched pattern + the fix. Static scan — pair with `web-vitals-field` to confirm the real LCP element.

## Premise

The Largest Contentful Paint element — usually the hero image or a large heading — must be **discovered and fetched first**. The common failure is the opposite: the hero is lazy-loaded (so the browser delays it), or it has no priority hint (so it queues behind less important resources), or it's a late-discovered CSS background with no preload. `frontend-principles` § LCP & images states the MUST — the LCP image is eager + prioritized and never carries `loading="lazy"`, which is lawful **below the fold only**. This skill is the detector that proves it on a real tree: the rule says exactly one high-priority element per view, and only a scan can tell you whether the route has zero or three.

Every finding cites the element at `<file:line>` + the matched pattern + the fix. "LCP is slow" without the cited element is not a finding. This is a *static* scan — pair it with `web-vitals-field` (which attributes field LCP to the real element + sub-part) to confirm you fixed the element users actually see.

**Closure verbs** — exactly one per finding. This skill emits `report-with-fix` (priority hint missing on the confirmed LCP element), `dismiss` (the § False positives carve-outs: lawful lazy below the fold, a text LCP element, an already-prioritised hero), and `halt-handoff` (format / dimensions / `sizes` → `image-optimization`; font + critical CSS on a text LCP → `font-optimization`).

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
- The LCP element differs by viewport/route — confirm via `web-vitals-field` (`attribution.element`) *(performance pack, when co-installed)*. Absent that pack there is no field attribution, and § Identifying the LCP element below is how the element is named instead — a label is not a substitute for running it.
- A text LCP element has no image to preload — its cost is font + render-blocking CSS/JS.
- Preloading an unused image hurts LCP — preload only the confirmed resource.

## Identifying the LCP element without the performance pack

Every detector above targets *the* LCP element, so the scan is worthless until one element is named. On a frontend-only install — the default — there is no field attribution, and "pick it from the lab trace" is not a procedure. This is:

1. **Run `lighthouse-ci` (this pack) on the route** at the viewport in question, against the production build. It already runs for the LCP number; the same report carries the element.
2. **Read the `largest-contentful-paint-element` diagnostic from the JSON report**, not from the score. It is an informative audit — `lhci` cannot fail a build on it, which is why nobody reads it. Its item gives the element's node (selector / snippet).
3. **Map the node back to source.** Grep the selector, `alt` text, class, or image path against the source tree to land on `<file:line>`. That grep is the citation; a node with no source anchor is not a finding.
4. **Repeat per viewport** — mobile and desktop routinely resolve to different elements. Run the mobile form factor at minimum; that is what CWV scores.
5. **Label it honestly**: `LCP element: <file:line> (lab-inferred, lighthouse-ci <form-factor>)`. Never print a field figure this skill did not read.

If `lighthouse-ci` cannot run at all (no dev server, no build, no Chrome), report `LCP element: unidentified — scan not run` rather than falling back to "the first big image."

## Halt conditions

- No LCP finding without the cited element + matched pattern.
- No `fetchpriority="high"` on more than one element per view.
- No preload for an image not confirmed to be the LCP resource (§ Identifying the LCP element, or field attribution when the performance pack is present). The finding records `confirmed by: lighthouse-ci largest-contentful-paint-element (<form-factor>)` — never wording that implies field evidence.
- No detector fires before an element is identified. Five detectors that all target "the LCP element" produce five guesses when nothing named one.
- If the LCP element is text, don't target image priority — re-scope to font/CSS.
