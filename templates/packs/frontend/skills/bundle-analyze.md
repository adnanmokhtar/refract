---
name: bundle-analyze
description: Analyze the production bundle — chunks, sizes, dependencies, duplicates. Flag bloat before users feel it.
---

# bundle-analyze

## Premise

Find real bloat, not vibes. Every finding cites the chunk name + gzipped size + the import graph that pulled it in (`<file:line>` of the import that anchors a heavy dep). "Bundle is big" is not a finding. "Should split this" without naming the chunk is not a finding. If the analyzer wasn't actually run against the production build, the report is invalid.

A budget breach without a named cause is a failed analysis, not a passing one.

Build the prod bundle, visualize chunk composition, and check sizes against budgets.

## When to use

- After adding a new dependency.
- After a `package.json` upgrade (especially major version bumps).
- When `lighthouse-ci` flags a JS-size regression.
- Quarterly to catch slow-creep bloat.

## Prerequisites

- `node`, the project's package manager (`pnpm` / `npm` / `bun`), and a clean `node_modules`.
- One of these analyzers (install on first use):
  - Vite: `vite-bundle-visualizer` or `rollup-plugin-visualizer`
  - Webpack: `webpack-bundle-analyzer`
  - Nuxt: built-in `nuxi analyze`
  - Next.js: `@next/bundle-analyzer`

## Procedure

1. Build for production with source-maps preserved (analyzer needs them):
   ```bash
   # Vite
   npx vite build --mode production --sourcemap
   # Nuxt
   pnpm nuxi analyze
   # Next
   ANALYZE=true pnpm build
   # Webpack
   pnpm build --json > stats.json
   ```
2. Run analyzer:
   ```bash
   # Vite
   npx vite-bundle-visualizer -t treemap -o dist/bundle-report.html
   # Webpack
   npx webpack-bundle-analyzer stats.json dist
   ```
3. Inspect generated `dist/bundle-report.html` (treemap) — capture: top 5 chunks by gzipped size, top 5 third-party deps, any duplicates.
4. Compare against budgets (from `ai/stack.md` or `.claude/rules/frontend-principles.md`):
   - Initial JS critical path: ≤ 150 KB gzipped
   - Per-route total JS: ≤ 300 KB gzipped
   - Each third-party > 10 KB gzipped: justify its weight
5. Detect duplicates:
   ```bash
   pnpm dedupe --check          # pnpm
   npx yarn-deduplicate --check # yarn
   npm dedupe --dry-run          # npm
   ```
6. Detect unused exports:
   ```bash
   npx knip --reporter compact   # finds unused files + exports + deps
   ```

## Output

```
Bundle analysis  (vite build, gzipped)

Initial bundle:
  158 KB / 150 KB    OVER BUDGET by 8 KB

Top chunks:
  vendor-abc.js     82 KB    Vue + Pinia + router + primevue core
  app-def.js        41 KB    shared composables + components
  home-xyz.js       28 KB    HomePage (lazy-loaded — good)

Top third-party (gzipped):
  primevue@4.0.5             32 KB    consider per-component imports (a la carte)
  moment@2.29.4              24 KB    replace with date-fns (6 KB) or Intl.DateTimeFormat (0 KB)
  lodash@4.17.21             14 KB    use lodash-es subpath imports + tree-shake

Duplicates:
  WARN  @vue/runtime-core    3.4.0 AND 3.4.5 — run `pnpm dedupe`

Unused (knip):
  src/utils/legacy-formatters.ts (export `formatPriceLegacy` never imported)
```

## False positives / gotchas

- `nuxi analyze` reports raw size by default; pass `--gzip` for the metric that matches the network.
- Dynamic imports (`import('./x')`) show as separate chunks — that's correct, not duplication.
- `knip` flags re-exports as unused if no consumer imports through the barrel — verify by hand.
- A "duplicate" can be intentional (different versions for backwards-compat) — don't `dedupe` blindly.
- Replacement of a heavy lib (moment → date-fns) is a refactor — open a separate PR after this analysis.

## Halt conditions

- Halt on hand-waves: every flagged dep must cite gzipped size + the importing `<file:line>`. "Looks heavy" is not a finding.
- Halt if the report was generated against `pnpm dev` output instead of the production build — dev bundles include HMR + uncompressed source and lie about size.
- Halt if a duplicate is dismissed as "intentional" without naming the two consumers + their version constraints.
- Halt if budgets fail but no named chunk / dep is identified as the cause. A budget breach without a named cause is unfinished work.

## Related

- `code-splitting.md` — the fix sibling: this skill measures the heavy chunk + gzipped size and names the anchoring import; that pattern decides where to cut it (route/component split, `manualChunks`, deep imports). Its split proposals cite this output.
