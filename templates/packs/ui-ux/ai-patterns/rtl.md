---
name: rtl
description: "Pattern: RTL (Right-to-Left) Support"
kind: ai-pattern
pack: ui-ux
---

# Pattern: RTL (Right-to-Left) Support

> **Hard rule** — All new layout CSS uses logical properties (`*-inline-start/end`, `text-align: start`). Physical `margin-left` / `padding-right` / `text-align: left` in new code is forbidden. `dir` is driven by the active locale, never hardcoded. Every property logical values do NOT cover gets an explicit `[dir="rtl"]` override.

**The failure this prevents:** a team flips `dir="rtl"`, the boxes mirror, everyone declares RTL done — and ships a UI where every shadow falls the wrong way, every slide-in animation enters from the wrong edge, every gradient runs backwards, and every user-typed Latin string inside Arabic copy renders scrambled. Logical properties solve the easy 70%. This pattern is mostly about the other 30%.

**When to apply**
- Product targets Arabic / Hebrew / Persian / Urdu speakers (now or roadmapped within 12 months).
- A locale switcher exists or an i18n library is wired.
- Visual regression covers screens — RTL doubles the matrix and needs CI coverage.

**When NOT to apply**
- Internal admin tool with an English-only mandate codified in product docs.
- Single static landing page where retrofitting logical props costs more than translating the copy.
- App without an i18n library — fix that first; RTL without locale wiring is half-done.

**Halt conditions / mandatory cites**
- Cite the locale → `dir` resolver as `<path:line>` (e.g. `src/i18n/dir.ts:8`) before claiming RTL is wired; hardcoded `dir="ltr"` is a halt.
- Cite at least one component using `margin-inline-start` / `padding-inline-end` as `<path:line>` proving the convention is in place; if all hits are physical, halt and retrofit.
- Cite the icon-flip rule (CSS or component) as `<path:line>` for directional icons; arrows that don't flip in RTL are a halt.
- Cite an `[dir="rtl"]` override (or a proof of absence) for each of the four uncovered property families below before claiming a surface is RTL-clean; "logical properties handle it" is a halt for those four.
- Cite the visual-regression matrix config as `<path:line>` proving RTL renders in CI on every PR.
- Hand-wave grep ban — never declare "no physical CSS" without citing the stylelint rule or grep output path.

## Logical properties — and the four families they do NOT flip

```css
/* physical → logical */
margin-left       → margin-inline-start
padding-right     → padding-inline-end
border-left       → border-inline-start
left: 0           → inset-inline-start: 0
text-align: left  → text-align: start
width/height      → inline-size / block-size
border-*-radius   → border-start-start-radius (etc.)
```

The [CSS logical properties module](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_logical_properties_and_values) covers exactly: **sizing, margin, padding, border (incl. the four logical radius corners), inset, and the `start`/`end` keywords**. **Anything outside that list stays physical and will NOT mirror.** Four families bite in practice, and they are the largest real RTL defect class:

| Stays physical | What breaks in RTL | The fix |
|---|---|---|
| `box-shadow` / `text-shadow` offsets | Elevation lights the scene from the wrong side; a right-side drop shadow reads as a seam against the mirrored layout. | `[dir="rtl"] .card { box-shadow: -2px 4px 8px … }` — negate the x offset. Better: a shadow token with a `--shadow-x-sign` custom property the `[dir="rtl"]` block flips to `-1`. |
| `transform: translateX()` / `rotate()` | Drawers slide in from the wrong edge; chevrons rotate the wrong way; carousels advance backwards. Every entry animation is inverted. | Negate under `[dir="rtl"]`, or drive translation from a `--dir` custom property (`1` / `-1`) and multiply: `translateX(calc(var(--dir) * 100%))`. |
| `background-position` (and `background-position-x`) | Decorative art, sprite icons, and CSS-drawn select arrows sit on the wrong side. | `[dir="rtl"]` override, or switch to a logical layout (a pseudo-element positioned with `inset-inline-end`) instead of a background offset. |
| Gradient direction (`to right`, `90deg`, and conic/radial angles) | Brand gradients run backwards; a light-source-consistent surface set becomes incoherent. | `[dir="rtl"] { background-image: linear-gradient(to left, …) }`, or express the angle from `--dir`. |

**Browser support:** do not hand-set a year — check the compat table on the MDN page above for the *specific* property; the four uncovered families have no logical form at all and need the override regardless. Tailwind ships logical spacing utilities (`ms-*` / `me-*` / `ps-*` / `pe-*`) **and** an `rtl:` variant (`rtl:-translate-x-full`) that is the escape hatch for exactly these four families — greppable evidence the project handled them.

## Bidi isolation — the bug that survives a perfect layout flip

Mirroring the layout does not fix the *text*. When a string of unknown direction (a username, a product title, a search term) is interpolated into a sentence of the opposite direction, the Unicode bidirectional algorithm lets the surrounding neutrals — punctuation, digits, spaces — take the wrong direction and the line renders scrambled. It is the most common production RTL defect, and it appears only with real user data, never with lorem. **Wrap every interpolated value of unknown direction in `<bdi>`:**

```html
<!-- broken: the neutral "-" and "1" adopt the embedded string's direction -->
<p>{{ userName }} - 1st place</p>

<!-- correct: the embedded run is isolated in both directions -->
<p><bdi>{{ userName }}</bdi> - 1st place</p>
```

[`<bdi>`](https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/bdi) isolates its contents in both directions. MDN's note is worth honouring — the CSS equivalent (`unicode-bidi: isolate` on a `<span>`) looks the same but **"HTML authors should not use this approach because it is not semantic and browsers are allowed to ignore CSS styling."** Use `dir="ltr"` only when the value's direction is *known* and fixed (phone number, IBAN, code); use `<bdi>` when it is user-supplied and unknown — which is most of the time.

## Direction at the root

```html
<html lang="ar" dir="rtl">
```

Set `dir` from the active locale (never hardcoded); `[dir="rtl"] .x { … }` is the override hook for the four uncovered families above. Date and number formatting goes through `Intl` with the locale — never hand-formatted.

## Icons + directional content

Icons that imply direction (arrows, chevrons, back buttons, undo/redo, send) MUST flip:

```css
[dir="rtl"] .icon-chevron-end { transform: scaleX(-1); }
```

Progress bars, steppers, timelines and flowcharts also run start→end and must be re-read in RTL, not just mirrored blindly.

## What should NOT flip

Numbers and digits · phone numbers, postcodes, IBANs · code blocks and file paths · Latin-letter brand logos · media transport controls (play/pause are universal).

For a **known-LTR** run inside RTL copy use `<span dir="ltr">+20 123 456</span>`; for an **unknown-direction** run use `<bdi>` (above). Mirroring a value that should not mirror is as much a bug as failing to mirror one that should.

## Scroll and geometry in JavaScript

Layout mirrors; the DOM's physical coordinate system does not. In an RTL scroller `scrollLeft` is **`0` at the start of the content (scrollbar rightmost) and increasingly NEGATIVE toward the end** ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollLeft)) — so a carousel or scroll-progress indicator written as `scrollLeft / (scrollWidth - clientWidth)` silently inverts. MDN also records a live divergence: **Safari lets `scrollLeft` overshoot the maximum on overscroll bounce; Chrome and Firefox do not** — clamp rather than trusting the bound. Prefer `scrollIntoView()` / `scrollBy({ left: … })` with a direction-aware sign.

## Typography

Arabic / Hebrew usually need a taller line-height (≈1.7–1.8 vs ≈1.4–1.5 for Latin) because of ascenders, descenders and diacritics, and often read a step larger at the same nominal size. Pair a dedicated family with the Latin one and verify the fallback chain per locale.

## Testing

- Every screen in the RTL visual-regression matrix, with **real translated copy** — Arabic and German expansion break layouts lorem never will.
- Mixed-direction fixtures on purpose: a Latin username in Arabic copy, an Arabic name in an English list. That is where `<bdi>` proves itself.
- Keyboard: tab order in RTL starts from the right.
- Input direction: the caret, selection and `Home`/`End` behave in the field's direction.
- The four uncovered families explicitly: screenshot a card (shadow), open a drawer (transform), and inspect a gradient — in RTL.

## Forbidden

- Physical CSS properties in new code (`margin-left`, `padding-right`) where a logical value exists.
- Assuming logical properties cover shadows, transforms, background-position or gradients — they do not; those need `[dir="rtl"]` overrides.
- Interpolating user-supplied text into a bidi sentence without `<bdi>`.
- Reading or writing `scrollLeft` without accounting for the RTL sign.
- Icons that don't flip in RTL (a back button pointing left in Arabic).
- Hardcoded `dir="ltr"` / `dir="rtl"` on page-level elements (must be driven by the active locale).
- Testing "it works" in English and assuming RTL is fine.
- Mirroring content that shouldn't mirror (numbers, codes, logos).
