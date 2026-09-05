---
name: lcp-audit
description: Static scan for LCP-resource priority mistakes — lazy hero images, missing fetchpriority, absent preload/preconnect for the LCP image. Turns "optimize LCP" prose into grep detectors.
allowed-tools: [Read, Grep, Glob, Bash]
---

# lcp-audit

## Premise

The Largest Contentful Paint element — usually the hero image or a large heading — must be **discovered and fetched first**. The common failure is the opposite: the hero is lazy-loaded (so the browser delays it), or it has no priority hint (so it queues behind less important resources), or it's a late-discovered CSS background with no preload. `frontend-principles` § LCP & images states the MUST — the LCP image is eager + prioritized and never carries `loading="lazy"`, which is lawful **below the fold only**. This skill is the detector that proves it on a real tree: the rule says exactly one high-priority element per view, and only a scan can tell you whether the route has zero or three.

Every finding cites the element at `<file:line>` + the matched pattern + the fix. "LCP is slow" without the cited element is not a finding. This is a *static* scan — pair it with `web-vitals-field` (which attributes field LCP to the real element + sub-part) to confirm you fixed the element users actually see.

**Closure verbs** — exactly one per finding. This skill emits `report-with-fix` (priority hint missing on the confirmed LCP element), `dismiss` (the § False positives carve-outs: lawful lazy below the fold, a text LCP element, an already-prioritised hero), and `halt-handoff` (format / dimensions / `sizes` → `image-optimization`; font + critical CSS on a text LCP → `font-optimization`).

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
- The LCP element differs by viewport (mobile hero ≠ desktop hero) and by route — confirm the real element with `web-vitals-field` attribution (`attribution.element`) *(performance pack, when co-installed)* before "fixing" the wrong image. Absent that pack there is no field attribution, and the lab arm below is how the element is identified instead — a label is not a substitute for running it.
- A heading/text LCP element has no image to preload — its LCP cost is font + render-blocking CSS/JS, not image priority (→ `font-optimization` for font-display / preload / swap-CLS, and critical CSS).
- This skill owns only the LCP element's **priority** (fetchpriority / preload / eager). The LCP image's **format, dimensions, and responsive sizing** belong to `image-optimization` — run both on a hero image.
- Preloading an image the page doesn't actually use wastes bandwidth and can *hurt* LCP — preload only the confirmed LCP resource.

## Identifying the LCP element without the performance pack

Every detector on this page targets *the* LCP element, so the scan is worthless until one element is named. On a frontend-only install — the default — there is no field attribution, and "pick it from the lab trace" is not a procedure. This is:

1. **Run `lighthouse-ci` (this pack) on the route** at the viewport in question, against the production build. It already runs for the LCP *number*; the same report carries the element.
2. **Read the `largest-contentful-paint-element` diagnostic from the JSON report**, not from the score. It is an informative audit, not an assertable one — `lhci` cannot fail a build on it, which is exactly why nobody reads it and why it has to be named here. Its item gives the element's node (selector / snippet); that is the citation.
3. **Map the node back to source.** The report gives you rendered markup, not a file — grep the selector, the `alt` text, the class, or the image path against the source tree to land on `<file:line>`. That grep is the finding's citation; a node with no source anchor is not a finding (§ Halt conditions).
4. **Repeat per viewport.** Mobile and desktop routinely resolve to different elements, and a fix applied to the wrong one is a no-op that reads as a fix. Run at minimum the mobile form factor, since that is the one CWV is scored on.
5. **Label the result honestly**: `LCP element: <file:line> (lab-inferred, lighthouse-ci <form-factor>)`. Lab inference is a real measurement of one synthetic load — it is not a claim about what users saw. Never print a field figure this skill did not read.

**If `lighthouse-ci` cannot run at all** (no dev server, no build, no Chrome), the element is unknown, and this skill reports `LCP element: unidentified — scan not run` rather than falling back to "the first big image." Guessing the hero and prioritising it is how two elements end up marked high-priority, which § False positives already names as self-cancelling.

## When to run

- When `lighthouse-ci` (this pack) reports LCP > 2.5s. Also on `bundle-perf` / `web-vitals-field` *(performance pack, when co-installed)* attributing field LCP to an image with high `resourceLoadDelay`/`resourceLoadDuration`; absent that pack, `lighthouse-ci` is the only trigger and the run says so.
- After adding or restyling a hero / above-the-fold media region.
- Before launch on any public, SEO-relevant, image-led page.

## Halt conditions

- Halt on any LCP finding without the cited element at `<file:line>` + the matched pattern.
- Halt if `fetchpriority="high"` is proposed on more than one element per view.
- Halt if a preload is proposed for an image not confirmed to be the LCP resource (§ Identifying the LCP element, or field attribution when the performance pack is present). On a frontend-only install only the lab arm exists — the halt still stands, and the finding records `confirmed by: lighthouse-ci largest-contentful-paint-element (<form-factor>)` rather than implying field evidence it never had.
- Halt if any detector fired before an element was identified. Five detectors that all target "the LCP element" produce five guesses when nothing named one.
- Halt if the LCP element is text but the fix targets image priority — re-scope to font/CSS.

## Related

- `code-splitting.md` (ai-pattern) — the LCP-critical component must never be lazy-loaded (a chunk round-trip before paint); that pattern's detector 7 hands off here, and this skill rejects any lazy proposal in the LCP subtree.
- `image-optimization` / `font-optimization` — the two halves this skill deliberately does not own: format/dimensions/responsiveness for an image LCP, `font-display`/preload/swap-CLS for a text LCP. This skill only sets priority.
- `lighthouse-ci` — the lab measurement that triggers this scan; it reports the number, this skill names the element.
- Cross-pack (`performance`, when co-installed): `web-vitals-field` supplies `attribution.element` — the only source that proves which element users actually saw as LCP. Absent that pack, every finding here is lab-inferred and must be labelled as such; never print a field figure this skill did not read.
