---
name: design-systems
description: Pattern: Design System
kind: ai-pattern
pack: ui-ux
---

# Pattern: Design System

A shared vocabulary of tokens + components so every screen feels like the same product. Without one, UI drifts with every PR.

## Layers (atomic design + variants)

```
Tokens        — raw values (color #3366FF, spacing 8px, font 16px)
    ↓
Primitives    — styled building blocks (Button, Input, Badge)
    ↓
Patterns      — composed UI (Card, Modal, Form, Table, DataGrid)
    ↓
Templates     — page layouts (Dashboard, Auth, List, Detail)
    ↓
Screens       — actual pages (ProductList, OrderDetail)
```

Rule: DON'T skip a layer. A "Card" built from raw HTML + magic spacing bypasses the system.

## Tokens

Live as CSS custom properties OR a typed TS/JSON source of truth:

```ts
export const tokens = {
  color: {
    brand: { 500: '#3366FF', 600: '#2952CC', 700: '#1F3E99' },
    neutral: { 50: '#F8F9FA', 100: '#E9ECEF', ..., 900: '#212529' },
    success: { 500: '#10B981' },
    warning: { 500: '#F59E0B' },
    danger:  { 500: '#EF4444' },
  },
  spacing: { 1: '4px', 2: '8px', 3: '12px', 4: '16px', 6: '24px', 8: '32px' },
  radius:  { sm: '4px', md: '8px', lg: '12px', full: '9999px' },
  font:    { sans: 'Inter, system-ui', mono: 'JetBrains Mono, monospace' },
  fontSize:{ xs: '12px', sm: '14px', md: '16px', lg: '18px', xl: '24px', '2xl': '32px' },
  shadow:  { sm: '0 1px 2px rgba(0,0,0,.05)', md: '...', lg: '...' },
  duration:{ fast: '150ms', base: '250ms', slow: '400ms' },
  ease:    { in: 'cubic-bezier(0.4, 0, 1, 1)', out: '...', inOut: '...' },
};
```

CSS consumes via vars: `color: var(--color-brand-500);` or Tailwind preset.

## Component contract

Every system component has:
- **Props** — typed.
- **Variants** — size (sm/md/lg), intent (primary/secondary/danger), state (default/hover/disabled/loading).
- **Slots** — where custom content plugs in (prefix icon, suffix action).
- **A11y** — keyboard, focus, ARIA built in.
- **Docs** — Storybook entry with all variants + interaction examples.

## Single source of truth

One package (or one folder) owns the system. ALL apps import from it.

- Monorepo: `packages/design-system/` consumed by `apps/*`.
- Workspace: `design-system` sibling repo (published to internal npm / monorepo).
- Small team: folder `src/ui/` with strict rules — never rebuild a token/component per feature.

## Governance

- New primitive → discussion before adoption.
- New token → ADR ("why do we need an orange?").
- One-off deviations → documented with reason.

## Documentation

- Storybook / Ladle / Histoire for interactive docs.
- Every component has a story covering: all variants, loading, error, empty, RTL.
- Token reference page shows every color / spacing / radius with live previews.

## Forbidden

- Magic pixel values in components (`margin-top: 13px`).
- Hex colors inline (`color: #3366ff`).
- Inline font families.
- Rebuilding a system component per feature ("quick one-off Button").
- Custom spacing that doesn't fit the scale.
- Component APIs that leak implementation (e.g., Tailwind classes as props).
