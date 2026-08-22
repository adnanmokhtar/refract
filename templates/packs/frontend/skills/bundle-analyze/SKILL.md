---
name: bundle-analyze
description: Analyze the production bundle — chunks, sizes, dependencies, duplicates — and flag bloat before users feel it. Run after adding a dependency, after a major version bump, or when `lighthouse-ci` flags a JS-size regression. Measures and names the heavy chunk; the `code-splitting` pattern decides where to cut it.
---

# bundle-analyze

## Premise

Find real bloat, not vibes. Every finding cites the chunk name + gzipped size + the import graph that pulled it in (`<file:line>` of the import that anchors a heavy dep). "Bundle is big" is not a finding. "Should split this" without naming the chunk is not a finding. If the analyzer wasn't actually run against the production build, the report is invalid.

A budget breach without a named cause is a failed analysis, not a passing one.

Build the prod bundle, visualize chunk composition, and check sizes against budgets.

## When to run

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

1. **Build + analyze**, per bundler. Source-maps must survive the build or the treemap attributes bytes to nothing.

   | Bundler | Build | Analyze |
   |---|---|---|
   | Vite | `npx vite build --mode production --sourcemap` | `npx vite-bundle-visualizer -t treemap -o dist/bundle-report.html` |
   | Webpack | `pnpm build --json > stats.json` | `npx webpack-bundle-analyzer stats.json dist` |
   | Nuxt | `pnpm nuxi analyze --gzip` | built in (see the `--gzip` gotcha below) |
   | Next | `ANALYZE=true pnpm build` | `@next/bundle-analyzer` opens the treemap |

2. **Read the treemap in gzipped bytes, and capture three lists**: top 5 chunks, top 5 third-party deps, every duplicate. Raw/parsed size is the number the tool shows by default and it is not the number users pay — it is roughly 3-4x the transferred size, so a report that mixes the two produces findings that evaporate on re-check.
3. **Resolve the budget before comparing anything** (§ Where the budget comes from).
4. **Duplicates**: `pnpm dedupe --check` / `npx yarn-deduplicate --check` / `npm dedupe --dry-run`.
5. **Unused**: `npx knip --reporter compact` — unused files, exports and deps.

## Where the budget comes from (this skill does not have authority it did not earn)

A verdict of OVER BUDGET is only meaningful against a budget somebody chose. Resolve in this order and **print which arm was used**:

1. **A project budget** — `ai/stack.md`, a `size-limit` / `bundlesize` config, a `resource-summary:script:size` assertion in the project's own `lighthouserc.json`, a CI budget file. `frontend-principles` § Should requires a budget gate but deliberately sets no number, because the right number is per-product. If the project has one, it wins outright and this skill never overrides it. **One axis caveat when the budget arrives from Lighthouse:** that assertion sums every script the audited *page* loads, while this skill measures one route's initial bundle. It is a ceiling above your number, not the same measurement — so print which of the two you measured, and treat a per-route figure sitting under a page-level ceiling as unproven rather than passing.
2. **This skill's own default**, when none exists: **150 KB gzipped on the initial critical path**. It is *this skill's* number — a working default for an interactive app on a mid-tier mobile connection, not an industry constant, and it is not written down in any rule in this pack. Say so in the report.

**Budget absent → the verdict is `report-flagged`, never OVER BUDGET.** Emit the measured sizes, the named heavy chunks and the anchoring imports — the useful half of this skill works fine without a threshold — and flag "no budget declared; measured against this skill's default of 150 KB initial" as its own finding, whose fix is *declare a budget*, not *delete a dependency*. Failing a build on a number the project never agreed to is how a bundle gate gets disabled permanently.

Each third-party over 10 KB gzipped is worth a line justifying its weight regardless of which arm supplied the budget; that one is a review prompt, not a threshold.

## Output

```
Bundle analysis  (vite build, gzipped)

Initial bundle:
  158 KB / 150 KB    OVER BUDGET by 8 KB   (budget: this skill's default — no project budget declared)

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
- Halt on an `OVER BUDGET` verdict that does not name which of the three budget arms supplied the threshold. A number with no authority behind it is this skill asserting a standard it does not hold.

## Related

- `code-splitting.md` (ai-pattern) — the fix sibling: this skill measures the heavy chunk + gzipped size and names the anchoring import; that pattern decides where to cut it (route/component split, `manualChunks`, deep imports). Its split proposals cite this output.
- `lighthouse-ci` — the reciprocal of its own `## Related` entry: that runner knows only the JS *total* against a budget, this skill names the chunk and the import that made it. A failed JS budget there is unfinished until it has a chunk name from here.
- `lcp-audit` / `streaming-ssr` — the two skills a heavy chunk usually shows up as. Bytes are this skill's finding; a lazy hero or a blocked first byte are theirs. Do not propose a split as a fix for either.
- Consumed cross-pack by `/enhance-ui` *(ui-ux pack, when co-installed)* for its optional bundle-size delta. That command already declares the absent branch (`SKIPPED (no bundle-analyze)`); this skill never has to synthesize a delta for a caller.
- Cross-pack (`performance`, when co-installed): `bundle-perf` owns the whole-app budget conversation and the page-load verdict; this skill answers the narrower question "which chunk, and which import anchored it?". Absent that pack, this skill is the only bundle instrument in the project — say so in the report rather than implying a budget authority it does not hold.
