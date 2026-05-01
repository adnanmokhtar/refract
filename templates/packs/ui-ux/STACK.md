# UI / UX pack — stack assumption

This pack's rules, agents, skills, and patterns assume:

- **A modern component framework** (Vue / React / Svelte / Angular / SwiftUI / Compose / Flutter)
- **A design-system layer** owned by the project (component library + design tokens — wrappers named in the project's `_extracted-idioms.md`)
- **A11y tooling** (`axe-core` / Lighthouse a11y / `eslint-plugin-jsx-a11y` / `vue-a11y` / `@storybook/addon-a11y`)
- **A design-token scheme** (CSS custom properties / Tailwind config / Style Dictionary / theme-extension class)
- **An icon system** with `aria-label` discipline (font icons / SVG sprites / `react-native-svg`)
- **Visual regression** for critical pages (Playwright / Chromatic / Percy / Loki)

## Stack scope

This pack's rules apply to **any** UI surface — web (responsive), native mobile (iOS / Android), desktop (Tauri / Electron / native). The accessibility, label, contrast, and focus principles are framework-agnostic and grounded in WCAG 2.2 AA.

Stack-specific substitution table:

| Vue 3 + PrimeVue + Tailwind (illustrated) | React + MUI / shadcn | Angular Material | SwiftUI | Compose | Flutter Material 3 | Substitution source |
|---|---|---|---|---|---|---|
| `<BaseModal>` (project shared) | `<AppModal>` | `<MatDialog>` | `.sheet { ... }` | `ModalBottomSheet` | `showModalBottomSheet` | shared modal |
| `<FormField>` wrapper | `<Field>` (formik / RHF) | `<MatFormField>` | `Form { TextField(...) }` | `OutlinedTextField` | `TextFormField` | form-field wrapper |
| `vue-a11y` lint plugin | `eslint-plugin-jsx-a11y` | `@angular-eslint/template/accessibility` | Accessibility Inspector | `Modifier.semantics` | `Semantics` widget | a11y lint / inspect |
| `:focus-visible` CSS | same | same | `.focusable()` modifier | `Modifier.focusable` | `Focus` widget | focus indicator |
| Tailwind / SCSS tokens | CSS Modules / styled-components | Material theme tokens | Asset Catalog colors | `MaterialTheme.colors` | `ThemeData` / `ThemeExtension` | design tokens |
| Playwright visual diff | same / Chromatic / Percy | same | XCUITest snapshots | Compose UI tests + Showkase | golden tests | visual regression |
| `@vueuse/i18n` | `react-i18next` / `formatjs` | `@ngx-translate/core` | `Localizable.strings` | string resources | `flutter_localizations` + ARB | i18n |

## Where stack-specific names live

- The project's `_extracted-idioms.md` — actual shared component names (e.g., `<BaseDialog>`, `<AppButton>`, `<Field>`), the canonical icon library, the form-validation pattern.
- The project's `_extracted-codebase.md § UI` — design-token directory, theme-toggle helper, i18n locale tree.
- The validator script `check_v2_structure` — stack-conditional fingerprint set keyed by `PROJECT_KIND` for frontend reinvented-wrapper detection.

Universal hard rules (keyboard reachable + visible focus, label every input, ≥ 4.5:1 contrast, status not by color alone, every empty/error state opinionated) are platform-agnostic — they hold for web, native mobile, desktop alike.
