---
name: lcp-audit
description: Static scan for LCP-resource priority mistakes — lazy hero images, missing fetchpriority, absent preload/preconnect for the LCP image. Turns "optimize LCP" prose into grep detectors.
---

# lcp-audit

## Premise

The Largest Contentful Paint element — usually the hero image or a large heading — must be **discovered and fetched first**. The common failure is the opposite: the hero is lazy-loaded (so the browser delays it), or it has no priority hint (so it queues behind less important resources), or it's a late-discovered CSS background with no preload. `frontend-principles` § LCP & images states the MUST — the LCP image is eager + prioritized and never carries `loading="lazy"`, which is lawful **below the fold only**. This skill is the detector that proves it on a real tree: the rule says exactly one high-priority element per view, and only a scan can tell you whether the route has zero or three.

Every finding cites the element at `<file:line>` + the matched pattern + the fix. "LCP is slow" without the cited element is not a finding. This is a *static* scan — pair it with `web-vitals-field` (which attributes field LCP to the real element + sub-part) to confirm you fixed the element users actually see.

## Scans for

### 1. Lazy-loaded LCP candidate

```
BAD:  <img src="/hero.jpg" loading="lazy" class="hero">     // defers the LCP element
GOOD: <img src="/hero.jpg" fetchpriority="high">             // eager + prioritized
```

Grep: `loading=["']lazy["']` on `<img>` near hero/banner/above-fold markers (class/id containing `hero`, `banner`, `cover`, `masthead`, or the first image in a page/layout). Lazy is correct *below* the fold — flag only above-the-fold candidates.

### 2. Hero image without `fetchpriority="high"`

The LCP image should declare high priority so it jumps the queue. Grep above-the-fold `<img>` lacking `fetchpriority="high"` (raw HTML) or the framework's priority prop (§ per-framework).

### 3. Late-discovered LCP image with no preload

A CSS `background-image` or a JS-injected hero isn't in the initial HTML, so the browser discovers it late.

```
GOOD: <link rel="preload" as="image" href="/hero.avif"
            imagesrcset="/hero-800.avif 800w, /hero-1600.avif 1600w" fetchpriority="high">
```

Flag a CSS-background or dynamically-set LCP image with no matching `<link rel="preload" as="image">`.

### 4. Cross-origin LCP image with no preconnect

If the LCP image is served from a CDN/image host on another origin, the connection setup (DNS + TCP + TLS) is on the critical path.

```
GOOD: <link rel="preconnect" href="https://images.cdn.example">
```

Flag an LCP image from a cross-origin host with no `<link rel="preconnect">` (or `dns-prefetch`).

### 5. Framework priority primitive missing on the hero

| Framework | LCP-image priority | Below-fold default |
|---|---|---|
| **Next** | `<Image priority>` (sets `fetchpriority="high"` + `loading="eager"`) | `loading="lazy"` |
| **Nuxt** | `<NuxtImg preload :loading="'eager'">` | lazy |
| **Astro** | `<Image loading="eager">` (+ `fetchpriority`) | lazy |
| **Angular** | `NgOptimizedImage` `ngSrc` + `priority` (emits preload + `fetchpriority=high`) | non-priority |
| **Plain React/Vue/Svelte** | `fetchpriority="high"` + `width`/`height` on the `<img>` | `loading="lazy"` |

Flag a hero using the framework image component without its priority flag, or a raw `<img>` where the framework offers an optimized component.

## Output

```
LCP audit — <route set>

Findings: 3

1. components/Hero.tsx:14                              [report-with-fix]
   <Image src="/hero.jpg" /> on the LCP element — no `priority`.
   Fix: <Image src="/hero.jpg" priority />  (emits fetchpriority=high + eager).

2. pages/index.vue:8                                   [report-with-fix]
   <img class="masthead" loading="lazy"> — lazy on the LCP candidate delays LCP.
   Fix: drop loading="lazy"; <NuxtImg preload :loading="'eager'" .../>.

3. styles/home.css:22                                  [report-with-fix]
   .hero { background-image: url(/cover.avif) } — late-discovered, no preload.
   Fix: <link rel="preload" as="image" href="/cover.avif" fetchpriority="high"> in <head>.
```

## False positives / gotchas

- Only the **single** LCP element gets `fetchpriority="high"`. If a scan would mark two heroes high-priority, flag it — competing high-priority fetches cancel the benefit.
- The LCP element differs by viewport (mobile hero ≠ desktop hero) and by route — confirm the real element with `web-vitals-field` attribution (`attribution.element`) *(performance pack, when co-installed)* before "fixing" the wrong image. Absent that pack there is no field attribution: pick the element from the lab trace, and label it `LCP element: lab-inferred (no field source)` so nobody reads a guess as a measurement.
- A heading/text LCP element has no image to preload — its LCP cost is font + render-blocking CSS/JS, not image priority (→ `font-optimization` for font-display / preload / swap-CLS, and critical CSS).
- This skill owns only the LCP element's **priority** (fetchpriority / preload / eager). The LCP image's **format, dimensions, and responsive sizing** belong to `image-optimization` — run both on a hero image.
- Preloading an image the page doesn't actually use wastes bandwidth and can *hurt* LCP — preload only the confirmed LCP resource.

## When to run

- When `lighthouse-ci` (this pack) reports LCP > 2.5s. Also on `bundle-perf` / `web-vitals-field` *(performance pack, when co-installed)* attributing field LCP to an image with high `resourceLoadDelay`/`resourceLoadDuration`; absent that pack, `lighthouse-ci` is the only trigger and the run says so.
- After adding or restyling a hero / above-the-fold media region.
- Before launch on any public, SEO-relevant, image-led page.

## Halt conditions

- Halt on any LCP finding without the cited element at `<file:line>` + the matched pattern.
- Halt if `fetchpriority="high"` is proposed on more than one element per view.
- Halt if a preload is proposed for an image not confirmed to be the LCP resource (lab heuristic OR field attribution). On a frontend-only install only the lab arm exists — the halt still stands, and the finding records `confirmed by: lab trace` rather than implying field evidence it never had.
- Halt if the LCP element is text but the fix targets image priority — re-scope to font/CSS.

## Related

- `code-splitting.md` (ai-pattern) — the LCP-critical component must never be lazy-loaded (a chunk round-trip before paint); that pattern's detector 7 hands off here, and this skill rejects any lazy proposal in the LCP subtree.
- `image-optimization` / `font-optimization` — the two halves this skill deliberately does not own: format/dimensions/responsiveness for an image LCP, `font-display`/preload/swap-CLS for a text LCP. This skill only sets priority.
- `lighthouse-ci` — the lab measurement that triggers this scan; it reports the number, this skill names the element.
- Cross-pack (`performance`, when co-installed): `web-vitals-field` supplies `attribution.element` — the only source that proves which element users actually saw as LCP. Absent that pack, every finding here is lab-inferred and must be labelled as such; never print a field figure this skill did not read.
