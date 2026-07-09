---
name: image-optimization
description: Static scan for image delivery mistakes — legacy formats where AVIF/WebP would cut bytes, missing responsive srcset/sizes, absent width/height (CLS), missing lazy-loading below the fold, raw <img> where the framework offers an optimized component, and oversized sources served into small slots. Owns format / dimensions / responsiveness / loading; LCP priority-hints stay with lcp-audit.
---

# image-optimization

## Premise

**Images are usually the heaviest bytes on a page and the top source of layout shift.** The browser needs three things to deliver an image well: the right *format* (AVIF/WebP over JPEG/PNG), the right *size for the viewport* (`srcset`/`sizes`, not one 2000px file for a phone), and *reserved space* (`width`/`height` or `aspect-ratio`, or the page jumps as it loads → CLS). Every finding cites the element at `<file:line>` + the matched pattern + the fix in **this project's own image primitive**. "Optimize images" without the cited element is not a finding.

Division of labor: **this skill owns format, responsiveness, dimensions/CLS, and lazy-loading.** The *LCP image's priority hints* (`fetchpriority`, `preload`, no-lazy-on-hero) belong to `lcp-audit` — cross-link it, don't duplicate. Pair with `lighthouse-ci` (its "Properly size images" / "Serve images in next-gen formats" / CLS audits) to confirm bytes actually dropped.

## Adapt to the codebase first

Detect and **mirror the project's image primitive** — most frameworks ship one that solves format + srcset + dimensions + lazy automatically. Prefer adopting it over hand-rolling `<picture>`:

| Framework / setup | Optimized image primitive | What it auto-handles |
|---|---|---|
| **Next.js** | `next/image` `<Image>` | format negotiation (AVIF/WebP), `srcset`, lazy (below-fold), enforced `width`/`height` (no CLS) |
| **Nuxt** | `<NuxtImg>` / `<NuxtPicture>` (`@nuxt/image`) | format, responsive `sizes`, lazy, provider CDN |
| **Astro** | `<Image>` / `<Picture>` (`astro:assets`) | format, `srcset`, dimensions from source |
| **Angular** | `NgOptimizedImage` (`ngSrc`) | `srcset`, lazy, requires `width`/`height`, priority for LCP |
| **SvelteKit / Vite** | `@sveltejs/enhanced-img` / `vite-imagetools` | build-time format + `srcset` |
| **Plain HTML / React** | `<picture>` + `<source type>` + `<img srcset sizes width height loading>` | manual, but explicit |
| **CDN-fronted** (Cloudinary / imgix / Cloudflare Images) | URL transform params (`f_auto,q_auto,w_…`) | format + resize at the edge |

If the project already routes images through a component/CDN, every fix goes through it. Only hand-roll `<picture>` when there is no primitive.

## Scans for

### 1. Legacy format with no modern-format path

JPEG/PNG delivered without an AVIF/WebP alternative ships 25–50% more bytes.

```
BAD:  <img src="/hero.jpg">
GOOD: <picture>
        <source type="image/avif" srcset="/hero.avif">
        <source type="image/webp" srcset="/hero.webp">
        <img src="/hero.jpg" width="1200" height="630" alt="…">
      </picture>
GOOD (CDN): <img src="/cdn/hero.jpg?format=auto&quality=auto">
```

Flag `<img>` pointing at `.jpg/.jpeg/.png` with no `<picture>`/`type` negotiation and no `format=auto` CDN param — or a raw `<img>` where the framework component would negotiate format for free.

### 2. Missing responsive `srcset` / `sizes`

One fixed-resolution image for every device wastes bytes on phones and looks soft on retina.

```
GOOD: <img srcset="/p-400.avif 400w, /p-800.avif 800w, /p-1600.avif 1600w"
           sizes="(max-width: 600px) 100vw, 50vw" src="/p-800.avif" width="800" height="600">
```

Flag content `<img>` with a single `src` and no `srcset`/`sizes` (and no framework component that generates them). Icons/logos at fixed small size are exempt.

### 3. Missing `width`/`height` (or `aspect-ratio`) → CLS

Without intrinsic dimensions, the browser reserves no space; the image pops in and shoves content down.

```
BAD:  <img src="/card.jpg">                              // reserves 0 height → CLS
GOOD: <img src="/card.jpg" width="400" height="300">     // or CSS aspect-ratio: 4/3
```

Flag any `<img>` lacking both explicit `width`+`height` and a CSS `aspect-ratio` on its box. This is the single biggest CLS lever.

### 4. Missing `loading="lazy"` below the fold (and wrongly present above it)

```
GOOD (below fold): <img loading="lazy" decoding="async" …>
```

Flag below-the-fold content images with no `loading="lazy"`. **Inverse:** a hero/above-fold/LCP image with `loading="lazy"` is an LCP bug — flag it but route the fix to `lcp-audit` (it owns hero priority).

### 5. Raw `<img>` where the framework offers an optimized component

Flag a hand-written `<img>` in a project that ships `next/image` / `<NuxtImg>` / `NgOptimizedImage` / `astro:assets` — adopting the component fixes format + srcset + dimensions + lazy in one change.

### 6. Oversized source served into a small slot

A 2400px original rendered into a 300px avatar ships ~8× the pixels.

```bash
# heuristic: large intrinsic dimensions / file size feeding a small CSS box or thumbnail/avatar class
```

Flag images whose natural size vastly exceeds their display size (thumbnails, avatars, list rows) with no resize/CDN transform.

### 7. Missing placeholder for large images (perceived perf)

Large content images benefit from an LQIP/blur/dominant-color placeholder so the layout looks intentional while bytes arrive. Flag large hero/card images with no placeholder where the framework offers one (`next/image` `placeholder="blur"`, `<NuxtImg placeholder>`).

## Output

```
image-optimization — <route set>   (primitive: <e.g. next/image | <picture> | Cloudinary>)

Findings: 4

1. components/ProductCard.tsx:18                       [report-with-fix]
   <img src={p.image}> — no width/height, no srcset, raw <img> in a next/image project.
   Fix: <Image src={p.image} width={400} height={300} sizes="(max-width:600px) 50vw, 25vw" alt={p.name} />

2. app/gallery/page.tsx:44                             [report-with-fix]
   30 gallery <img> below the fold with no loading="lazy".
   Fix: loading="lazy" decoding="async" (or the framework component, lazy by default).

3. components/Avatar.vue:6                             [report-with-fix]
   Serves the 1600px original into a 48px avatar.
   Fix: <NuxtImg :src="url" width="48" height="48" sizes="48px" /> (or CDN w_48).

4. public/photos/*.png (12 files)                      [report-with-fix]
   PNG photos with no AVIF/WebP path.
   Fix: convert to AVIF/WebP + <picture>, or route through the image component/CDN (format=auto).
```

## False positives / gotchas

- **Don't lazy-load the LCP image.** If a scan would add `loading="lazy"` to the hero, stop — that's `lcp-audit`'s territory and lazy there *hurts* LCP.
- **SVGs and tiny icons** don't need srcset/format negotiation — exempt vector + fixed small raster.
- **`width`/`height` are the intrinsic ratio, not the display size** — CSS can still scale; the attributes just reserve the aspect box. Don't "fix" a correctly-ratioed image.
- **AVIF encode cost**: AVIF is smaller but slower to encode — for build-time it's fine; for on-the-fly CDN, `format=auto` picks per-browser. Don't force AVIF where the CDN already negotiates.
- **One `srcset` doesn't fit all layouts** — `sizes` must reflect the *actual* rendered width at each breakpoint, or the browser picks wrong. A wrong `sizes` is worse than none; verify against the layout.

## When to run

- Before launching any image-led page (product, gallery, marketing, blog).
- When `lighthouse-ci` flags "Properly size images", "Serve images in next-gen formats", "Efficiently encode images", or CLS from images.
- After adding a card/list/grid that renders user or CMS images.

## Halt conditions

- Halt on any finding without the cited element at `<file:line>` + the matched pattern + the fix in the project's own image primitive.
- Halt if a fix would add `loading="lazy"` to the LCP/hero image — hand to `lcp-audit`.
- Halt if a `sizes` value is proposed without checking the element's real rendered width per breakpoint.
- Halt if the project has an image component/CDN and the fix hand-rolls `<picture>` instead of using it.
