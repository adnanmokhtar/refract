---
description: Install Storybook with the MCP addon and a story for every shared component; on a repo that already has it, write stories only for the components added since.
---

# /setup-storybook [app-dir]

Setup command. Mode is detected, never asked: **CREATE** (no `.storybook/` → install, wire providers, story per shared component, register the MCP) or **UPDATE** (`.storybook/` exists → say `Storybook already installed at <app-dir>/.storybook — updating, not installing`, then stories only for components that have none). In a monorepo `app-dir` is the frontend member.

## The Premise (read this first, internalize, do not deviate)

**A story is an example a coding agent will copy.** The MCP serves every story as "how to use this component" — import line, props, sample content — so a story meets the app-code bar: the project's conventions, its static gates, its language.

**The agent's job is exactly this:** detect mode, framework, package manager + release-age policy, and prior art; build the inventory and show it; CREATE: install then cut the installer's output back; write stories (parallel batches above ~12); prove them with typecheck, lint, the FULL unit suite and the full story run; wire and probe the MCP.

**The agent ONLY asks the user when:** the repo ships a different explorer (Histoire, Ladle, an in-app gallery) — migrate / coexist / stop; the inventory is ready (CREATE, or a gap over ~12); no Storybook release in the major is older than the release-age window. Never bypass that window.

## When to use / NOT to use
- USE: a frontend with a shared component layer and no Storybook, or a Storybook behind its components.
- NOT: one component, disposable (`component-playground` skill); a new component (`/add-component` writes its story); visual baselines (`visual-check`).

## Phase 1 — Understand
Mode from `ls <app-dir>/.storybook`. Framework package from the app's deps. Release-age policy from `.npmrc` / `pnpm-workspace.yaml` / `.yarnrc.yml` → pin every `@storybook/*` to the newest release older than the window. Prior art: `.storybook`, `histoire.config.*`, `.ladle`, any `*.stories.*`, or a route/page importing most of the shared component dir (or a test requiring a page per component) → HALT and ask, citing the file.

## Phase 2 — Organize
Inventory = `.tsx/.jsx/.vue/.svelte` exporting a PascalCase component, in the shared layer; excludes pages, routes, tests, stories, hooks, utils, providers, layouts, throw-only boundaries. Rank by importer count. UPDATE gap = inventory entries with no sibling story and no story naming them as `component:`; report orphan stories. Story sources in trust order: component source (sole authority on props) → existing gallery/doc page → call sites.

## Phase 3 — Retrieve
ALWAYS: [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md). Plus: root providers, i18n + direction, theme + font location, lint config location, test config, and every test that walks `src/**` (stories will be scanned).

## Phase 4 — Generate
**CREATE:** `npx storybook@<version> init --yes --no-dev --package-manager <pm>`, then clean up (measured on 10.6): revert the eslint rewrite and add the plugin by hand where the eslint config lives; keep the browser project in the default `vitest.config.*` but name the old one `unit` and scope `test` to it; drop `@chromatic-com/storybook` (`"latest"`) and coverage unless asked; delete `src/stories/`. Keep addon-docs, addon-a11y, addon-vitest, addon-mcp. `main`: source globs, `staticDirs: ['../public']` (self-hosted fonts). `preview`: app stylesheet + root providers minus server-bound ones + locale/theme toolbar (hooks in a component, not the decorator) + `a11y.test: 'todo'`. Storybook's test panel and MCP `test-run` only find the storybook project in the DEFAULT vitest config; give it `name: 'storybook'` for `test:stories`.

**Stories** beside each component: relative import, `Category/Name` title, autodocs, purpose sentence; args/argTypes from real props; `Playground` then one story per visible state with a when-to-use JSDoc; product-language sample copy from its locales; overlays open; inline fixtures, no network.

**Import tag (mandatory):** `docs-show` rewrites relative/alias imports to the package name. Add `@import import { X } from '<path>'` to the component's JSDoc, where `<path>` is the one app code uses most (often a barrel). JSDoc only, no code change.

**Story hygiene** — fix the story, never loosen the gate: gates walking the component dir skip `.stories.` like `.test.`; helper components get unique names; no helper copied from a migrated gallery; literal `aria-label` on icon-only JSX; required props passed explicitly; copy follows the digit/language rules; hook results named as app code names them (`askConfirm`).

## Phase 5 — Update
Scripts `storybook`, `build-storybook`, `test:stories`, `test` → `--project unit`; `.gitignore` `storybook-static`, `*storybook.log`; `~/.claude/scripts/detect-mcp.sh <repo> --apply` writes `{"type": "http", "url": "http://localhost:<port>/mcp"}`; changelog line.

## Phase 6 — Validate
1. Typecheck. 2. Lint. 3. FULL unit suite; failures also on the base branch are pre-existing — report, don't fix. 4. `test:stories`; a first-run `Failed to fetch dynamically imported module …/sb-vitest/deps/…` is Vite re-optimising — re-run once, a repeat is real. 5. Probe the MCP live: `initialize` → `tools/list` → `docs-list` count → `docs-show` import line → `test-run` on two stories (streamable HTTP, keep `mcp-session-id`).

### Mechanical halt (mandatory)

Halt if any of: a story passes a prop the source lacks; a story crosses the repo's layering rule; an inventory component has no story and no cited reason; `docs-show` prints the package name; a unit failure the base branch lacks; `@storybook/*` versions unpinned or mixed.

## Phase 7 — Improve
`/learn-from-task` — providers the preview needed, gates the stories tripped. A doc page disagreeing with source → report both; source decides.

## Output format
```
## /setup-storybook — <CREATE | UPDATE> · Storybook <version> · <app-dir>
Prior art · Inventory (N, K had stories, M written, S skipped) · Installed · Cleaned
Tests: unit <pass>/<total> (pre-existing: …) · stories <P>/<P>
MCP: http://localhost:<port>/mcp · docs-list <N> · import verified on <Component>
Status: COMPLETE | BLOCKED on <halt>
```
End with `## What to do next` (MUST / SHOULD / OPTIONAL, each with `<file:line>` + Fix + Verify) per [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- Keeping `init`'s eslint rewrite → an unreviewable diff hiding the one line that mattered.
- The browser project left in the default `test` script → every test run starts Chromium.
- A separate vitest config for stories → the test panel and MCP `test-run` cannot find the project.
- No `@import` tag → every MCP snippet imports from the package name and does not resolve.
- Validating only the story run → the repo's own gates fail on the next `test` run.
- Bypassing the release-age window → the supply-chain exposure the window exists to close.

## Related
**Boundary:** `component-playground` is the no-explorer probe and halts on a Storybook repo; `/add-component` writes a new component's story; `visual-check` owns baselines; `@design-system-guardian` *(ui-ux pack)* owns whether a primitive should exist. **Scripts:** `scripts/detect-mcp.sh` writes the `storybook` HTTP entry once `addon-mcp` is present. **Rules:** `.claude/rules/frontend-principles.md`.
