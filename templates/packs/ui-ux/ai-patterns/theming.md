# Pattern: Theming

One codebase, N visual variants — light/dark, brand-per-tenant, accessibility contrast modes — without forking components or rebuilding bundles. The technique is a layer of indirection: components reference semantic tokens (CSS custom properties), and a single attribute on `<html>` swaps the values.

## Context

Reach for runtime theming when:
- You need light AND dark modes that switch instantly without page reload.
- You ship multi-tenant SaaS where each tenant has a brand color, logo, optional fonts.
- Accessibility requires high-contrast or reduced-motion variants.
- Marketing wants to A/B-test brand color changes without redeploying.

If you only need static dark mode and one brand, a build-time CSS-variable swap with two stylesheets is simpler. The runtime approach pays off when variants multiply or tenants self-serve.

## The token layer

Components NEVER reference colors, spacing, or shadows directly. They reference semantic CSS custom properties. The theme defines the values.

```css
/* base layer — always loaded */
:root {
  --color-bg-base:       #ffffff;
  --color-bg-surface:    #f8f9fa;
  --color-bg-elevated:   #ffffff;
  --color-text-primary:  #111827;
  --color-text-secondary:#4b5563;
  --color-brand:         #3366ff;
  --color-brand-hover:   #2952cc;
  --color-border:        #e5e7eb;
  --color-success:       #10b981;
  --color-danger:        #dc2626;
  --shadow-md:           0 1px 3px rgb(0 0 0 / 0.1);
  --radius-md:           8px;
  --space-4:             16px;
  --duration-fast:       150ms;
  --ease-out:            cubic-bezier(0.2, 0, 0, 1);
}

/* dark theme variant */
[data-theme="dark"] {
  --color-bg-base:       #0b0f17;
  --color-bg-surface:    #111827;
  --color-bg-elevated:   #1f2937;
  --color-text-primary:  #f5f7fa;
  --color-text-secondary:#9ca3af;
  --color-brand:         #5c85ff;
  --color-brand-hover:   #7ba0ff;
  --color-border:        #2d3748;
  --color-success:       #34d399;
  --color-danger:        #f87171;
  --shadow-md:           0 0 0 1px rgb(255 255 255 / 0.06);
}

/* tenant-specific brand (composes with light or dark) */
[data-tenant="acme"] {
  --color-brand:         #ff6b00;
  --color-brand-hover:   #cc5500;
}
[data-theme="dark"][data-tenant="acme"] {
  --color-brand:         #ff944d;  /* lifted for dark */
  --color-brand-hover:   #ffaa70;
}
```

Components are clean:

```css
.button-primary {
  background: var(--color-brand);
  color: var(--color-bg-base);
  border-radius: var(--radius-md);
  padding: var(--space-4);
  transition: background var(--duration-fast) var(--ease-out);
}
.button-primary:hover {
  background: var(--color-brand-hover);
}
```

## Applying the theme

Set the attribute on `<html>` (preferred) or `<body>`:

```html
<html data-theme="dark" data-tenant="acme" lang="en">
```

Switching is one DOM mutation that re-styles every descendant via cascade — no component needs to listen for "theme changed".

```ts
function setTheme(theme: 'light' | 'dark', tenant?: string) {
  const root = document.documentElement;
  root.dataset.theme = theme;
  if (tenant) root.dataset.tenant = tenant;
  localStorage.setItem('theme', theme);
}
```

Multi-dimensional themes compose: `[data-theme]`, `[data-tenant]`, `[data-density="compact"]`, `[data-contrast="high"]` can all coexist on `<html>`. CSS specificity handles the override order.

## Persistence + first-visit default

```ts
// On first visit: respect OS preference
const initial = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';

// On return: respect user override (stored in localStorage AND server)
const stored = localStorage.getItem('theme');
const theme = stored ?? initial;
```

For logged-in users, also persist server-side so theme follows them across devices. The localStorage value wins on conflict — the user just clicked the toggle, that's authoritative for this session.

## SSR: avoid flash of wrong theme

Server renders before knowing the user's theme; the client hydrates and switches → 200ms white flash before dark mode settles. Fix is a tiny inline script in `<head>` BEFORE the stylesheet:

```html
<head>
  <script>
    (function () {
      var stored = localStorage.getItem('theme');
      var os = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
      document.documentElement.dataset.theme = stored || os;
    })();
  </script>
  <link rel="stylesheet" href="/app.css">
</head>
```

For multi-tenant SSR, resolve the tenant from the request (subdomain → tenant lookup) and bake `data-tenant` into the served HTML — the client doesn't need a script for that part.

## Per-tenant theming (SaaS)

Tenants edit a brand color in settings; you persist `{ brandColor, logoUrl, faviconUrl }` per tenant. Two delivery options:

1. **Inline `<style>` block in HTML head** (small, dynamic): server renders `<style>:root[data-tenant="${id}"] { --color-brand: ${color} }</style>` once per tenant. Cached aggressively. Good for ≤ 10 customizable tokens.

2. **Per-tenant CSS endpoint** (larger customizations): `/themes/${tenantId}.css` served with long cache + invalidation on settings save. Good for fonts, multiple custom tokens, asset URLs.

Both keep the component code untouched.

## Accessibility variants

```css
@media (prefers-reduced-motion: reduce) {
  :root {
    --duration-fast: 0.01ms;
    --duration-base: 0.01ms;
  }
}

/* Optional: explicit high-contrast mode */
[data-contrast="high"] {
  --color-text-primary: #000;
  --color-bg-base:      #fff;
  --color-border:       #000;
}
[data-theme="dark"][data-contrast="high"] {
  --color-text-primary: #fff;
  --color-bg-base:      #000;
  --color-border:       #fff;
}
```

Contrast variants are NOT a substitute for proper light/dark contrast — they're additional, for users who need WCAG AAA-level contrast.

## Trade-offs

Pro: instant runtime switching, one bundle, components stay framework-agnostic. Pro: tenant brand customization without redeploys. Pro: A/B testing colors becomes a flag flip. Con: every new color decision must add tokens for every theme variant — forgetting one ships a broken component. Con: tooling that reads CSS values (e.g., chart libraries that need a hex string) needs a JS reflection of the tokens. Con: CSS specificity wars when nesting `[data-theme]` deeply — keep selectors flat.

Skip runtime theming if you have ONE theme and no realistic plan for variants. Static CSS is faster.

## Common mistakes

- **Hex literals inside components.** `color: #3366ff` in a component file is the entire pattern's failure mode. Grep for `#[0-9a-f]{3,6}` in the components dir; the count should be near zero.
- **Per-component dark mode props.** `<Button isDark />` is the anti-pattern — components shouldn't know which theme is active. CSS custom properties cascade, props don't.
- **Compiling separate CSS bundles per theme.** Doubles bundle size, can't switch at runtime, can't compose with tenant variant. Runtime variables are smaller and more flexible.
- **Hardcoded fallback for missing tokens.** `var(--color-brand, #3366ff)` looks safe but locks the brand to one default. If `--color-brand` is missing, that's a bug to surface, not silently paper over.
- **Persisting only to localStorage.** User signs in on a new device, gets light mode despite preferring dark. Persist server-side too.
- **Forgetting the inline script on SSR.** White flash on every dark-mode page load. The script in `<head>` is the only place inline JS in `<head>` is justified.
- **Mixing the JS theme name with the CSS attribute value.** Code says `theme = 'darkMode'`, CSS expects `data-theme="dark"`. Lock to one string set, ideally `'light' | 'dark'`.

## Testing

- Visual regression per theme (Chromatic/Percy/Playwright). The matrix is `themes × locales × critical pages` — keep "critical" small.
- A11y audit per theme. Some contrast issues only manifest in dark mode; some focus-ring issues only in high-contrast.
- Manual rapid-toggle smoke test: nothing should flicker, jump, or briefly show wrong colors. Body background transitions especially.
- Per-tenant: render a tenant with brand `#FFB000` against the dark theme and verify AA contrast on buttons and links.

## Migration path

Retrofitting theming on an app with hardcoded colors:
1. Inventory hex literals via `rg "#[0-9a-f]{3,6}"`. Group similar colors → semantic intentions ("this gray is text-secondary, this gray is border").
2. Define the token layer as `:root` custom properties with current light values.
3. Replace literals with `var(--token)` file by file. PR per feature, not all at once.
4. Add a `[data-theme="dark"]` block with dark values for each token. Most components need no further changes.
5. Wire the theme switcher + SSR script.
6. Audit visual regressions per theme; fix tokens that turned out to mean different things in different contexts.

## References

- web.dev: "A complete guide to CSS custom properties" — the cascade + fallback semantics.
- Adam Argyle's "Building a custom dark theme switch" — the SSR flash-of-wrong-theme fix.
- Tailwind CSS dark mode docs (tailwindcss.com/docs/dark-mode) — class strategy compatible with this pattern via `darkMode: ['class', '[data-theme="dark"]']`.
