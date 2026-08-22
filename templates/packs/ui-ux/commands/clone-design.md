---
description: One command to CLONE an external design reference (a live URL or a screenshot) into a self-contained folder of framework-neutral HTML/CSS — every page and section, styled to design tokens extracted from the reference, then verified by rendering each built page and pixel-diffing it against the reference until it matches. Stage 1 (capture → build → verify) is the whole command; Stage 2 adoption (into your app's tokens, into per-page redesigns, or into a platform theme) is a delegated follow-through via `--adopt`. Reproduces a design LANGUAGE as a starting point — brand identity is placeholdered, never counterfeited. Works with NO existing project.
kind: command
pack: ui-ux
---

# /clone-design <url-or-image> [<out-dir>] [<flags>...]

> **Not this command? (ANTI-triggers)** — **you want the site to LOOK like the original** (its real logo, photos, fonts) → **`/grab-site`**; this command placeholders the brand on purpose, so its output reads as a clean wireframe and pointing it at a live storefront expecting a copy is its #1 misuse. Invent a language from your product's goals, no reference → **`/art-direct`**. Rethink an in-repo page → **`/redesign`**. Add finish to one → **`/enhance-ui`** · `/polish`. Add a theme slot to a multi-theme app → **`/add-theme-variant`**. Make a deceptive 1:1 counterfeit of a real brand's live site → not this command, by invariant. Full map: [`ui-sweep.md § The ui-ux command map`](ui-sweep.md).

> **`--plan`**: honours the universal handoff flag — see [`templates/snippets/plan-flag.md`](../../../snippets/plan-flag.md). `/clone-design <ref> --plan` runs ingest → distill (tokens + section inventory + page set) and writes the **capture plan** to `.claude/plans/`, exiting before any file is built. Execute it later with `/execute-plan <file>` (or hand it to any tool).

## The Premise (read this first, internalize, do not deviate)

**You point at an external design — a live URL (`https://…/`) or a screenshot — and this command reproduces it as a folder of self-contained HTML/CSS: every page, every section, styled to a design-token system extracted from the reference, then verified by rendering each built page and diffing it against the reference until they match.** Every other UI command works *inside a design language the project already owns*: `/redesign` rebuilds a page in it, `/add-theme-variant` adds a slot to it, `/art-direct` invents one from product goals, `/align` enforces it. `/clone-design` is the only one whose source of truth is **outside the repo** — an external artifact — and whose success metric is **fidelity to that reference**, measured from pixels, not taste.

**Two stages, and the command owns only the first.** This split is the whole design, not an implementation detail:

- **Stage 1 — capture → build → verify (this command, always).** Ingest the reference, extract real tokens + a section/component inventory, emit a **folder of framework-neutral, self-contained HTML/CSS** for every discovered page, then **render each built page and perceptually diff it against the reference, looping until it clears the fidelity bar.** Fidelity is *measurable* and *framework-independent* — this stage nails it once, in plain HTML, so no later port ever has to re-fight it.
- **Stage 2 — adopt (delegated, only under `--adopt`).** Take the verified static clone and land it in a target: merge the extracted tokens into your app's system (delegates to [`/add-theme-variant`](add-theme-variant.md)), rebuild real pages from the clone as the reference (delegates to [`/redesign`](redesign.md) per surface), or scaffold a new project seeded from the clone (delegates to `/scaffold-project`). **Stage 2 grows no new design machinery — it routes the clone into commands that already exist.** Default (no `--adopt`): the run stops at the folder, and you choose. (A platform-theme emitter — Shopify Liquid / WordPress from the section library — is a *planned* target, not yet built; it is deliberately absent from `--adopt` until a real emitter command exists.)

The one hard fidelity invariant: **the built pages must match the reference, verified from the render — not asserted.** A clone that only "looks about right" in code, was never screenshotted, or was graded from the HTML instead of the pixels, is an unverified clone and the run says so. The Fidelity gate is the teeth (below).

The one hard ethics invariant: **reproduce the design LANGUAGE, not the brand.** The output is a token system + layout + section structure — a legitimate design starting point. **Brand identity is placeholdered, never counterfeited:** the logo, product/company name, marketing copy, and photography are replaced with clearly-labelled placeholders (`[LOGO]`, `Acme`, generic copy, neutral placeholder imagery), and the fidelity report states it. The command builds a design *inspired by / structured like* the reference; it does not mint a pixel-identical counterfeit of someone's live storefront presented as your own. If the request is explicitly "make an exact deceptive copy of <real brand>'s site to pass as theirs," that is where this command stops.

> **⚠️ "I want the SAME design as this site" → use [`/grab-site`](grab-site.md), not this command.** Because the brand is placeholdered, `/clone-design`'s output looks like a **clean wireframe of the reference's *structure*, not a copy of the filled-in site** — so the Fidelity gate below measures **layout / colour / type / spacing** against the reference, with content deliberately generic. If you want the site's REAL assets so it *looks like the original* (real logo, photos, fonts), that is `/grab-site` (a faithful mirror). Reach for `/clone-design` only when you want a **reusable, brand-neutral design *system*** you can restyle and own. Pointing `/clone-design` at a live storefront expecting a copy is the #1 misuse — if the reference is a live site and you want its look, stop and run `/grab-site`.

### `/clone-design` vs `/redesign` vs `/art-direct` vs `/add-theme-variant`

| | `/clone-design` | `/redesign` | `/art-direct` | `/add-theme-variant` |
|---|---|---|---|---|
| **Source of the design** | **an EXTERNAL reference (URL / image)** | the app's existing language | invented from product goals | the default theme's structure |
| Success metric | **fidelity to the reference (pixel-diff)** | beats the old surface | beats the old, original concept | parity with the default theme |
| Needs an existing project? | **No — builds into an empty folder** | yes (rebuilds its page) | yes | yes (multi-theme slot system) |
| Primary output | **a folder of static HTML/CSS + tokens** | a rebuilt page in-repo | a built identity in-repo | a new theme slot |
| Invents a visual language? | ❌ **reproduces the reference's** | ❌ | ✅ | ❌ |
| Ships into the app directly? | only via `--adopt` (delegates) | yes | yes | yes |

> **Not in this table — the closest sibling, [`/grab-site`](grab-site.md):** it **mirrors the REAL site** (real assets → looks like the original); `/clone-design` extracts a **brand-neutral system** (placeholdered → looks like a wireframe). Same input (a URL), opposite output. Want the real site → `/grab-site`. Want a reusable system → `/clone-design`.

**Stack scope:** Stage 1 is **stack-agnostic and project-optional** — it writes plain HTML/CSS into a folder and needs no frontend framework, no `_extracted-idioms.md`, not even a repo. This is the ONE ui-ux command that does not HALT on a backend/empty repo. Only `--adopt` needs a real target project (and then inherits that target command's prerequisites).

## When to use
- You want a **reusable, brand-neutral design *system*** — tokens + a section library — extracted from a reference (a Dribbble shot, a Figma export PNG, a site whose *structure* you admire), which you will then **restyle with your own brand**. The output is placeholdered (logo → `[LOGO]`, photos → grey boxes) on purpose.
- You want the extracted **design-token system + section library** to seed a new project or a new theme (then `--adopt`).
- You're starting a project from a visual reference and want a verified, brand-neutral structural baseline before committing to a framework.

## When NOT to use
- **You want the site's REAL design — its actual images, logo, fonts, looking like the original → [`/grab-site`](grab-site.md)** (faithful mirror). `/clone-design` deliberately placeholders the brand and returns a wireframe-like system; a live storefront where you want the *look* is a `/grab-site` job, full stop.
- Rethink an existing in-repo page's UX → `/redesign`. Add finish to one → `/enhance-ui` / `/polish`.
- Invent an original visual language from goals (no external reference) → `/art-direct`.
- Add a new theme to a multi-theme app → `/add-theme-variant`.
- **Make a deceptive 1:1 counterfeit of a real brand's live site to pass as that brand** → not this command (brand-safety invariant).

## Args
- `<url-or-image>` — the reference. **`shop.example.com` throughout this file is a placeholder host** standing in for a real reference site; substitute the real URL. A URL (`https://…`) triggers **live capture** (Playwright: computed styles + DOM + screenshots — measured signal); an image path (or several, space-separated) triggers **vision extraction** (inferred signal, lower confidence, flagged as such). Mixed (a URL plus supporting screenshots) is allowed — measured signal wins where they disagree.
- `<out-dir>` — where to write the clone. Default `.clone/<slug>/` under cwd (`<slug>` derived from the reference host/name). The reference captures + raw extraction go to `.claude/artifacts/clone-design/<iso>/` regardless.
- `--pages=<a,b,c>` — which routes to clone (URL mode). Default: **auto-discover the primary set** — the home page plus one representative page per detected template family (e.g. collection, product, cart, article, contact). `--all-routes` clones every discoverable route (bounded, with a cap that is `log()`-reported if hit).
- `--sections-only` — extract the token system + the reusable section library + the design-system pane, and skip full-page assembly. For when you want the components, not the pages.
- `--fidelity=<0-100>` — the per-page match threshold the Fidelity gate must clear (default `90`). Below it after `--max-refine` rounds → `INCOMPLETE`, worst regions named, never faked green.
- `--max-refine=<n>` — fidelity refine rounds per page (default `3`).
- `--adopt=<tokens | pages | project>` — **Stage 2**, delegated (default: none — stop at the folder). `tokens` → merge extracted tokens via `/add-theme-variant`; `pages` → rebuild each surface via `/redesign` using the clone as the direction; `project` → scaffold a real project seeded from the clone via `/scaffold-project`. Each target is an **existing** command; adopt inherits its prerequisites and gates. (`theme:<platform>` emit is planned but not yet built — omitted until a real emitter exists.)
- `--plan` — universal handoff flag (see blockquote): write the capture plan (tokens + section inventory + page set) and exit before building.

```bash
/clone-design https://shop.example.com/            # capture → build → verify into .clone/shop-example-com/
/clone-design ./ref/home.png ./ref/product.png site/            # clone from screenshots into ./site/
/clone-design https://example.com --sections-only               # extract tokens + section library only
/clone-design https://example.com --all-routes --fidelity=95    # every route, tight match bar
/clone-design ./ref/shot.png --adopt=tokens                     # Stage 1, then merge tokens via /add-theme-variant
/clone-design https://example.com --plan                         # capture plan only; build nothing
```

## What "a good clone" means (the four pillars)

A clone is not done because HTML files exist. Three pillars have hard gates (Fidelity, Self-contained, Brand-safety); the fourth (Structure) is verified structurally.

### Pillar 1 — Fidelity (matches the reference's STRUCTURE) — HARD GATE, measured from pixels
Because content is placeholdered, "fidelity" here is **structural**: each built page, rendered at the reference's viewport, must match the reference on **layout** (section order, grid columns, container width), **color** (ΔE between built and reference palettes within tolerance), **type** (family / scale / weight hierarchy), **spacing** (rhythm on the same base grid), and **radii / elevation** — NOT on the filled-in imagery/copy (which is deliberately generic). Measured by a **perceptual diff** (structural similarity + per-region overlay), not a byte compare. Below bar → the run **loops** (fix the worst region in code, re-render, re-diff) up to `--max-refine` rounds; still below after that → `INCOMPLETE`, worst regions and their scores named, never a faked pass.

> **The score is a MEASUREMENT or it is not reported.** The diff requires a real render+compare harness (the project's `visual-check` / Playwright + an SSIM/ΔE comparison). **Without that harness there is no fidelity number** — the run prints `fidelity: SKIPPED (no harness) — NOT verified`, never a fabricated integer like "94". A confident-looking score the agent estimated by eye is a Pillar-1 failure, because it defeats the "measured from pixels, not taste" premise that is this command's whole reason to exist. If your environment can't run the harness, `/clone-design` cannot verify — and for a live site you want reproduced, `/grab-site` (no harness needed) is the better tool anyway.

### Pillar 2 — Structure (a real design system, not a flat dump) — verified structurally
The output is a **token system + reusable section library**, not one giant hand-copied HTML blob. Extraction produces: **color roles** (bg / surface / text / primary / accent / border / state) clustered from the reference's computed colors, a **type scale** (detected modular ratio + weights), a **spacing scale** (snapped to the reference's base unit — usually 4/8px), **radii**, **elevation** (shadows / hairlines), **breakpoints** (from the reference's own media behaviour). Repeated DOM structures become **named section partials** (`nav`, `hero`, `product-grid`, `feature-row`, `testimonial`, `footer`), each rendered once and reused — the pages compose sections, they don't duplicate markup. A flat clone with no tokens and no shared sections fails this pillar even if it pixel-matches.

### Pillar 3 — Self-contained (opens standalone) — HARD GATE
Every built page must render **offline, opened directly** — no broken external runtime dependency. Fonts are self-hosted or matched to a safe stack with the reference's family named; images are neutral placeholders (brand-safety) sized to the reference's boxes; all CSS is local (`tokens.css` + page/section CSS). A clone that only renders against the live origin's CDN is not a clone — it's a proxy. The gate opens each page in a clean context and confirms zero failed same-origin-less requests block layout.

### Pillar 4 — Brand-safety (a language, not a counterfeit) — HARD GATE
Logo → `[LOGO]` placeholder; brand/product names → a neutral placeholder (`Acme`); marketing copy → generic equivalents; photography → labelled placeholder imagery at the right aspect ratio. The design system (tokens, layout, sections) is reproduced faithfully; the **identity is deliberately not**. The gate scans the output for verbatim brand strings / hotlinked brand assets and flags any that leaked. The fidelity report states plainly: *design language cloned; brand identity placeholdered.*

## Flow (silent — no phase numbers reach the user)

1. **Frame** — parse `<ref>` (URL vs image vs mixed) + flags + `<out-dir>`. No project prerequisites for Stage 1. If `--adopt` is set, additionally check the adopt target's prerequisites now (fail early, not after the build).
2. **Ingest — capture the reference (the oracle).**
   - **URL:** drive Playwright — load, wait for network idle, dismiss cookie/consent/popup overlays, then harvest **computed styles** from a curated node set (`:root`, `body`, `h1`–`h6`, `p`, `a`, `button`, common component roots), the **DOM tree** (for section structure), and **full-page screenshots at 3 breakpoints** (1440 / 768 / 375). In `--all-routes` (or to build the page set), follow in-site links to discover the template families. **A blocked capture** (bot wall / login / Cloudflare interstitial / the real content never renders) → **HALT** (`CAPTURE BLOCKED — the reference did not render; provide screenshots instead, or an authenticated session`), never a clone built from an error page.
   - **Image:** vision-extract the same token targets and section structure from the screenshot(s); mark every value **inferred** (vs URL-mode **measured**) in the report.
3. **Distill** — cluster raw computed colors into semantic **color roles**; detect the **type scale** ratio + weights; snap spacing to the reference's **base unit**; capture **radii / elevation / breakpoints / container width**; write `tokens.json` + `tokens.css`. Enumerate repeated DOM structures into the **section inventory** (named, counted). Resolve the **page set** (default primary set, or `--pages` / `--all-routes`).
4. **Build (Stage 1 output)** — create `<out-dir>`: `tokens.css`, `sections/<name>.html` (each section once), one `<page>.html` per page composing sections, a `design-system.html` pane (every token + section as a card, `@dsCard`-annotated), and an `index.html` gallery. Framework-neutral, self-contained, brand-placeholdered.
5. **Fidelity gate + refine loop** — render each built page, perceptually diff vs the reference screenshot, score per region; while any page/region is below `--fidelity`, fix the worst region in code, re-render, re-diff — up to `--max-refine` rounds. Run the Self-contained + Brand-safety gates.
6. **Adopt (only under `--adopt`)** — delegate the verified clone to the target command: `tokens` → `/add-theme-variant` (extracted tokens as the new slot's direction); `pages` → `/redesign` per surface with the clone as the reference; `project` → `/scaffold-project` from the clone. Each runs its own gates. (No `theme:<platform>` — that emitter is not yet built.)
7. **Report** — emit the fidelity scorecard + folder tree + honesty footer.

## Gates (each is a real mechanism, not a claim)

- **Capture gate.** The reference must have actually rendered — real screenshots + a non-empty extraction. A blocked/empty capture HALTs (`CAPTURE BLOCKED`); a clone is never built from a login wall, a bot interstitial, or a blank SSR shell. No Playwright harness at all (and a URL ref, no screenshots) → HALT with the "provide screenshots" redirect — never guess a URL's design unseen.
- **Fidelity gate (HARD).** Per-page perceptual diff ≥ `--fidelity`, cross-checked on color ΔE / type / spacing / layout, verified **from the render**. Loops up to `--max-refine`; below bar after that → `INCOMPLETE — <page>: <score> (<worst region>)`, never a faked pass. A page graded from the HTML instead of the screenshot is invalid.
- **Self-contained gate (HARD).** Each page opens standalone with no layout-blocking external request. A page that only renders against the live origin fails.
- **Brand-safety gate (HARD).** No verbatim brand names / hotlinked brand logos / copied marketing copy in the output; identity is placeholdered. A leak is flagged and replaced before the run reports success.

All four must be green (Capture may be an honest `image-mode (inferred)` note) before the run reports done. Under `--plan`, the run ends at the capture plan — nothing is built.

## What you see

```
/clone-design https://shop.example.com/

Reference:  https://shop.example.com/  (URL — measured signal)
Captured:   3 breakpoints × {home, collection, product, cart}  → .claude/artifacts/clone-design/2026-07-13T.../

Design system extracted:
  colors: 7 roles (bg #fff · surface #f6f6f6 · text #222 · primary #c9a44c · accent · border · state)
  type:   Jost / system-fallback · scale 1.25 · weights 400/500/700
  spacing base 8px · radii {0, 4, 999} · elevation 2 shadows + hairline · breakpoints 375/768/1440
  sections: 9 (nav · hero · promo-grid · product-grid · feature-row · newsletter · testimonial · footer · cart-drawer)

Built (.clone/shop-example-com/):
  index.html · design-system.html · tokens.css · sections/*.html (9) · home/collection/product/cart .html
  self-contained: ✓ (all pages open standalone) · brand-safe: ✓ (logo/name/copy/photos placeholdered)

Fidelity (rendered + diffed vs reference — requires the visual-check/Playwright harness):
  home 94 · collection 91 · product 92 · cart 90   (bar 90)  → all ✓  (2 refine rounds on home hero)
  color ΔE within tol · type scale matched · spacing on 8px grid · layout order matched

Adopt:      none (Stage 1 only). Next: --adopt=tokens (into your app) · --adopt=pages (/redesign per page).
Note:       design LANGUAGE cloned; brand identity placeholdered (structural wireframe, NOT a copy of the look).
```

**Without the render harness the Fidelity block reads `Fidelity: SKIPPED (no harness) — NOT verified`** — the per-page integers are only printed when a real diff ran; they are never estimated by eye. Image-mode adds `Reference: <files> (image — inferred signal, lower confidence)` and marks measured-only fields `~approx`. If the fidelity bar isn't cleared after `--max-refine`, the page line reads `product 84 ✗ INCOMPLETE — hero image grid mismatch` rather than a faked ✓.

## What you DON'T see
- Phase numbers, the computed-style harvest mechanics, the color-clustering or diff internals.
- A prompt per page — the run is silent; the `<out-dir>` folder + the fidelity report are the review surface.
- The Stage-2 delegation machinery — `--adopt` hands off to the target command, which reports in its own format.

## Don't (hard rules)
- **DON'T print a fidelity checkmark you didn't render.** Every ✓ is from a screenshot diff. No harness / image-mode → say `inferred`, never assert a measured match.
- **DON'T ship a flat hand-copied blob.** The output is tokens + reusable sections; a clone with no design system fails Pillar 2 even if it pixel-matches.
- **DON'T leave the clone dependent on the live origin.** Self-host / placeholder every asset; the pages open standalone or the Self-contained gate fails.
- **DON'T counterfeit the brand.** Logo/name/copy/photography are placeholdered; reproduce the language, not the identity. A deceptive 1:1 copy of a real brand's site is out of scope.
- **DON'T build from a blocked capture.** A login wall / bot interstitial / blank shell HALTs — never clone an error page and call it the design.
- **DON'T let `--adopt` reinvent `/redesign` or `/add-theme-variant`.** Stage 2 delegates to them; it owns no new design machinery.
- **Rollback is a folder.** Stage 1 writes only under `<out-dir>` (+ artifacts) — delete the folder to undo. `--adopt` edits the repo and lands as the target command's commits; `git` is that rollback.

## Failure modes
- **Capture blocked** (bot wall / login / consent-gated / blank SSR) — HALT (`CAPTURE BLOCKED`); ask for screenshots (→ image-mode) or an authenticated session. Never clone the error page.
- **No Playwright harness + a URL ref (no screenshots)** — HALT; can't see the reference. Provide screenshots to run image-mode, or wire the harness.
- **Image-mode, thin reference** (one low-res screenshot) — build what's inferable, mark every measured-only field `~approx`, and state the confidence limit; don't assert a scale/spacing you couldn't measure.
- **Fidelity bar not cleared after `--max-refine`** — report `INCOMPLETE` per page with the score + worst region; don't fake green. Raising `--max-refine` or lowering `--fidelity` is the user's call.
- **`--adopt` with no valid target** (e.g. `--adopt=tokens` in a non-frontend / non-theming repo) — the delegated command's own prerequisite HALT fires; the Stage-1 folder still stands.
- **Brand asset leaked** (a hotlinked logo / verbatim name slipped through) — the Brand-safety gate flags and placeholders it before reporting success.

## Cross-references
- [`/grab-site`](grab-site.md) — **the sibling to reach for when you want the REAL site** (real assets, looks like the original) instead of a brand-neutral placeholdered system. Same input (a URL), opposite output; route live-storefront "same design" requests here.
- [`/redesign`](redesign.md) — `--adopt=pages` delegates here per surface, using the clone as the direction reference (it owns the per-page rebuild + parity gate).
- [`/add-theme-variant`](add-theme-variant.md) — `--adopt=tokens` delegates here to land the extracted tokens as a new theme slot (additive gate holds).
- [`/art-direct`](art-direct.md) — the sibling for when there is **no** external reference and the language must be invented from goals.
- skill `visual-check` — owns the Playwright capture + render harness (and the authenticated / blocked-render contract this command inherits for the Capture gate).
- agent `design-system-architect` — codifies the extracted tokens into a real primitive→semantic system when the clone is adopted into a project.
- pattern `design-systems`, `theming`, `motion`, `rtl` — the system context an adopted clone lands in. (Earlier versions listed `design-tokens` and `responsive`; neither is a pattern in this pack — the token contract lives in `design-systems`, and responsive/breakpoint drift is deliberately outside the 19-verb set and owned by `/enhance-ui`.)

## Stack scope
Stage 1 is **stack-agnostic and project-optional** — plain HTML/CSS into a folder, no framework or `_extracted-idioms.md` required; it does not HALT on a backend/empty repo (the one ui-ux command that doesn't). `--adopt` requires a valid target project and inherits that target command's prerequisites and gates.
