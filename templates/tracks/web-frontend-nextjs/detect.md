---
track: web-frontend-nextjs
signals:
  - { kind: file, glob: "**/next.config.js",                  weight: 8 }
  - { kind: file, glob: "**/next.config.mjs",                 weight: 8 }
  - { kind: file, glob: "**/next.config.ts",                  weight: 8 }
  - { kind: dep,  ecosystem: npm, name: "next",               weight: 10 }
  - { kind: dep,  ecosystem: npm, name: "react",              weight: 3 }
  - { kind: dep,  ecosystem: npm, name: "react-dom",          weight: 2 }
  - { kind: file, glob: "**/app/page.tsx",                    weight: 4 }
  - { kind: file, glob: "**/app/page.jsx",                    weight: 4 }
  - { kind: file, glob: "**/app/layout.tsx",                  weight: 4 }
  - { kind: file, glob: "**/pages/index.tsx",                 weight: 3 }
  - { kind: file, glob: "**/pages/_app.tsx",                  weight: 3 }
  - { kind: negative, glob: "**/nuxt.config.ts",              weight: -10 }
  - { kind: negative, glob: "**/svelte.config.js",            weight: -10 }
threshold: 10
exclusive-with:
  - web-frontend-vue
  - web-frontend-svelte
  - web-frontend-angular
  - web-frontend-nuxt
---

# Detection — web-frontend-nextjs

Selects when the codebase is a Next.js project (App Router or Pages Router).

## Signal rationale

- `next` dep (weight 10): definitive — alone meets threshold.
- `next.config.{js,mjs,ts}` (weight 8): expected; Next-managed config file.
- `app/page.{tsx,jsx}` + `app/layout.tsx` (weight 4 each): App Router fingerprints.
- `pages/index.tsx` + `pages/_app.tsx` (weight 3 each): Pages Router fingerprints.
- `react` / `react-dom` deps add small weight; needed but not exclusive to Next.
- Negative signals on `nuxt.config.ts` (Nuxt) and `svelte.config.js` (Svelte): polyglot disambiguation.

## Threshold

`10` — meets on `next` dep alone, OR on `next.config.*` + 1 router-specific signal, OR on app/page + app/layout + react.

## Router variant

App Router and Pages Router are NOT separate tracks. The router shape is detected by Phase 2 deep extraction (`detected.app-router` vs `detected.pages-router`) and used by `pack.md` `emits-conditional` to ship different convention sets. Mixed projects (both routers present) emit both convention sets and a TODO ADR to pick one.
