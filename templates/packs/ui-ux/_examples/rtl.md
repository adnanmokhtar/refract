---
name: rtl
kind: example
pack: ui-ux
---

# Pattern: RTL (Right-to-Left) Support

For Arabic, Hebrew, Persian, Urdu. First-class, not an afterthought.

## Logical properties (the key technique)

Use CSS logical properties so layouts FLIP automatically:

```css
/* BAD — physical */
.card {
  margin-left: 16px;
  padding-right: 24px;
  border-left: 2px solid;
  text-align: left;
}

/* GOOD — logical (flips under dir="rtl") */
.card {
  margin-inline-start: 16px;
  padding-inline-end: 24px;
  border-inline-start: 2px solid;
  text-align: start;
}
```

- `margin-inline-start` / `margin-inline-end` (replaces left / right)
- `padding-inline-*`, `border-inline-*`
- `inset-inline-start` / `inset-inline-end` (replaces left/right position)
- `text-align: start` / `end` (replaces left/right)

Browser support: excellent (all modern browsers, 2022+). Tailwind has `ms-4` / `me-4` / `ps-4` / `pe-4`.

## Direction at the root

```html
<html lang="ar" dir="rtl">
```

- Set `dir` based on the active locale.
- CSS selectors can target: `[dir="rtl"] .something { ... }` for special cases.

## Icons + directional content

Icons that imply direction (arrows, chevrons, back buttons) MUST flip in RTL:

```css
[dir="rtl"] .icon-chevron-right {
  transform: scaleX(-1);
}
```

Flowcharts, progress bars, stepper indicators — all must reconsider direction.

## What should NOT flip

- Numbers and digits: `123` stays LTR even in Arabic text.
- Phone numbers, postcodes, IBANs.
- Code blocks.
- Brand logos with Latin letters.
- Video player controls (play, pause — universal).

```html
<span dir="ltr">+20 123 456</span>
```

## Typography

- Arabic / Hebrew text often needs a taller line-height (1.7-1.8) vs Latin (1.4-1.5).
- Font pairing: use a dedicated Arabic/Hebrew font that pairs with your Latin font (many "multilingual" fonts exist).
- Font size: may need to be 1px or 2px larger for Arabic equivalent legibility.

## Testing

- Every screen tested in RTL (visual regression).
- Form input direction: user can write RTL text in inputs; ensure cursor behavior correct.
- Mixed content (Arabic label + English value): browser Bidi handles most, verify edge cases.
- Keyboard: Tab order in RTL starts from the right.

## i18n library integration

- `vue-i18n`, `react-i18next`, `next-intl`: all support switching `dir` alongside locale.
- Date/number formatting: use `Intl` API with the locale — don't hand-format.

## Forbidden

- Physical CSS properties in new code (`margin-left`, `padding-right`).
- Icons that don't flip in RTL (back button pointing left in Arabic).
- Hardcoded `dir="ltr"` / `dir="rtl"` on page-level elements (must be driven by the active locale).
- Testing "it works" in English and assuming RTL is fine.
- Mirroring content that shouldn't mirror (numbers, codes, logos).
