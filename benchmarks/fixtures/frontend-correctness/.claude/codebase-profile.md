# Codebase profile — Harbor Market

PROJECT_KIND: frontend-web
Languages: TypeScript
Storefront: Next.js 16.1 App Router (React Server Components, server actions), React 19.2, TanStack Query 5, Tailwind CSS 4.1, next-intl 4, react-hook-form, msw 2 (local mocking)
Back office: Vue 3.5 + Vite 8, vue-router 4, Pinia 3, vue-i18n 11, @tanstack/vue-query 5, axios
Widgets: Angular 22 standalone components (zoneless), RxJS 7
Locales: storefront en (default) and ar (RTL); back office en and de
Browsers: evergreen only — the support matrix is the last two versions of Chrome, Edge, Firefox and Safari (RUM, 2026-09: 0.3 % older)
Rendering: storefront SSR + streaming on Node; back office static SPA behind SSO
Tests: Vitest + Testing Library (storefront), Playwright 1.63
