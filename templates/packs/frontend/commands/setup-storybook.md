---
description: Install Storybook with the MCP addon and a story for every shared component; on a repo that already has it, write stories only for the components added since.
allowed-tools: [Read, Write, Edit, Grep, Glob, Bash, Task]
---

# /setup-storybook [app-dir]

Setup command. Two modes, detected — never asked:

- **CREATE** — no `.storybook/` in the app → install Storybook + `@storybook/addon-mcp`, wire the app's providers, write a story for every shared component, register the MCP server.
- **UPDATE** — `.storybook/` exists → say so first (`Storybook already installed at <app-dir>/.storybook — updating, not installing`), then write stories ONLY for the shared components that have none, and repair the MCP wiring if it is missing. Never re-run the installer over an existing setup.

`app-dir` defaults to the repo root; in a monorepo it is the frontend member (`apps/web`, `packages/ui`, …) — resolve it from the workspace, and ask only when two members both render components.

## The Premise (read this first, internalize, do not deviate)

**A story is an example a coding agent will copy.** The MCP serves every story as "how to use this component" — its import line, its props, its sample content. So a story is held to the same bar as app code: the project's own conventions, its own static gates, its own language. A story that passes in Storybook but breaks a repo gate, or teaches a wrong import path, is worse than no story.

**The agent's job is exactly this:**
1. Detect the mode, the framework, the package manager and its release-age policy, and any component explorer the repo already has.
2. Build the component inventory (§ Inventory) and show it before writing anything.
3. CREATE: install, then cut the installer's output back to what the project needs (§ Installer cleanup). UPDATE: skip straight to the gap.
4. Write the stories — in parallel batches when there are more than ~12 — then prove them: the project's typecheck, lint, FULL unit suite, and the full story run.
5. Wire and probe the MCP (§ MCP).

**The agent ONLY asks the user when:**
- The repo already ships a **different** component explorer — Histoire, Ladle, or an in-app gallery (§ Prior art). Adding Storybook beside it means two places to keep in sync; the user decides migrate / coexist / stop.
- The inventory is ready (CREATE, or an UPDATE gap over ~12): print it and let the user strike or add before any story is written.
- The newest Storybook release is younger than the package manager's release-age window and no older release in the same major exists.

Everything else — which addons, which providers, which story per state, which import path — is read from the code. Never ask what the code already answers.

## When to use / NOT to use
- USE: a frontend with a shared component layer and no Storybook; or one whose Storybook has fallen behind the components.
- USE: to give coding agents the component catalogue through the Storybook MCP.
- NOT: to probe ONE component once, disposable — that is the `component-playground` skill (it halts on a repo that has Storybook and routes here or to a story).
- NOT: to add a new component — `/add-component` writes its story with it.
- NOT: visual regression baselines — the `visual-check` skill.

## Phase 1 — Understand

- **Mode:** `ls <app-dir>/.storybook` → UPDATE if present, else CREATE.
- **Framework + builder:** from the app's `package.json` — React/Vue/Svelte/Angular/Next, Vite/Webpack. Storybook's framework package follows (`@storybook/react-vite`, `@storybook/vue3-vite`, `@storybook/sveltekit`, `@storybook/nextjs-vite`, `@storybook/angular`).
- **Package manager + release-age policy:** read `.npmrc` / `pnpm-workspace.yaml` / `.yarnrc.yml` for `minimum-release-age` / `minimumReleaseAge` / `npmMinimalAgeGate`. If set, pick the newest Storybook release OLDER than the window (`npm view storybook time --json`) and pin every `@storybook/*` package to that exact version. **Never** add the package to an exclude list or pass a flag to bypass the window — the policy is the project's supply-chain decision, not an obstacle.

### Prior art (mandatory)

```bash
ls <app-dir>/.storybook histoire.config.* .ladle 2>/dev/null
rg -l "\.stories\.(t|j)sx?$|\.story\.vue$" --files
```

Then look for an **in-app gallery**: a route or page that imports most of the shared component directory (count its imports against the directory's module count), or a test that asserts "every shared component has a page". Any hit → HALT and ask: migrate the gallery into stories (its per-component demos and prose are the best story source there is), coexist, or stop. Cite the file you found.

## Phase 2 — Organize

### Inventory — what counts as a component

A module is in the inventory when ALL hold:
- extension `.tsx` / `.jsx` / `.vue` / `.svelte` (Angular: `*.component.ts`);
- it exports a PascalCase component that renders markup;
- it lives in the shared layer — `components/`, `ui/`, `shared/`, `lib/components/`, or whatever the repo's own sibling convention names.

Excluded: `pages/`, `routes/`, `app/` route files, `*.test.*`, `*.stories.*`, hooks, utils, constants, context providers, layouts, error boundaries that only render on a throw. Rank by importer count (`rg -l "from '.*<module>'"`) — the most-imported primitives first.

**UPDATE gap:** an inventory entry is covered when a `*.stories.*` beside it exists OR any story file names it as `component:`. The gap is the uncovered rest. Also report stories whose component file no longer exists (orphans) — they fail typecheck; list them, never silently delete.

### Story sources, in order of trust
1. The component's source — the ONLY authority on props. A prop in a doc table that the source lacks does not exist.
2. An existing gallery / doc page for the component (its demo states, its purpose sentence, its do / don't).
3. The component's call sites — the realistic prop combinations.

## Phase 3 — Retrieve

ALWAYS (universal pre-flight): see [`templates/snippets/phase-3-always-reads.md`](../../../snippets/phase-3-always-reads.md).

Storybook-specific:
- The app entry and its root providers (`main.tsx` / `App.tsx` / `app/providers.*`) — the preview must wrap stories in the same ones.
- The i18n setup and its locales; the direction mechanism (RTL).
- The theme mechanism (class / `data-theme` / provider) and where the self-hosted fonts live (`public/fonts/`).
- The lint config location (in a monorepo usually the ROOT) and the test runner config.
- The repo's static gates over source — tests that walk `src/**` or the component directory (grep test files for `readdirSync`, `globSync`, `import.meta.glob`, `walk(`). Stories will be scanned by them.

## Phase 4 — Generate

### CREATE — install

```bash
cd <app-dir> && npx storybook@<version> init --yes --no-dev --package-manager <pm>
```

#### Installer cleanup (mandatory — measured on Storybook 10.6)

`init` optimises for a demo, not for an existing codebase. After it runs, diff and cut back:

| `init` did | Do instead |
|---|---|
| Rewrote the whole eslint config (re-quoted and re-indented every line) | Revert it; add the plugin import + `...storybook.configs['flat/recommended']` by hand, and put `eslint-plugin-storybook` in the package.json that owns the eslint config (the root, in a monorepo). |
| Folded a browser test project into `vitest.config.*`, so the existing `test` script now starts Chromium | Keep both projects in that file (see § Tests), name the old one `unit`, and point `test` / `test:watch` at `--project unit`. |
| Added `@chromatic-com/storybook` at `"latest"` and `@vitest/coverage-v8` | Remove both unless the user asked for Chromatic or coverage. A `"latest"` range is never committed. |
| Wrote example stories + assets under `src/stories/` | Delete the directory. |
| Registered addons through a `getAbsolutePath()` helper | Plain package names work when `.storybook/` sits in the package that depends on them; keep the helper only for Yarn PnP. |

Addons to keep: `@storybook/addon-docs`, `@storybook/addon-a11y`, `@storybook/addon-vitest`, `@storybook/addon-mcp` (the MCP addon requires `addon-vitest` as a peer).

#### `.storybook/main.*`
- `stories`: the source globs only (`../src/**/*.stories.@(ts|tsx)`, plus `.mdx` when docs pages exist).
- `staticDirs: ['../public']` — without it self-hosted fonts 404 and every story renders in the fallback face.
- The framework reuses the app's own Vite config (aliases, CSS plugin) — do not duplicate it.

#### `.storybook/preview.*`
- Import the app's global stylesheet.
- One decorator that mounts the app's root providers **minus anything that needs a server** (settings queries, realtime sockets, telemetry): theme, query client (fresh, `retry: false`), direction, router (`MemoryRouter` / equivalent), tooltip, confirm and toast hosts.
- Toolbar globals for **locale** (switch i18n + `<html dir>`) and **theme mode**, defaulting to the app's own defaults. Put hooks in a component, not in the decorator function — `rules-of-hooks` rejects the latter.
- `parameters.a11y.test: 'todo'` to start; a component whose stories are clean is raised to `'error'` in its own file.

#### Tests
`addon-vitest` runs stories as tests, and **both** Storybook's test panel and the MCP `test-run` tool look for the storybook project in the DEFAULT `vitest.config.*` — a separate config file makes `test-run` fail with "No projects matched the filter". So:
- `test.projects: [ { name: 'unit', …existing config }, { plugins: [storybookTest(...)], test: { name: 'storybook', browser: {…chromium} } } ]`.
- The explicit `name: 'storybook'` is what `test:stories` (`vitest run --project storybook`) filters on; the plugin renames it to `storybook:<configDir>` only when Storybook itself starts the run.

### Stories (CREATE: the inventory; UPDATE: the gap)

**Parallelise above ~12 components:** split into batches of ~11, one agent per batch, disjoint files; each agent runs prettier + eslint + `vitest run --project storybook <its files>`. The orchestrator runs typecheck, the full unit suite and the full story run ONCE at the end — N agents type-checking the whole project in parallel is N times the cost for one answer.

**Each story file**, beside the component (`button.tsx` → `button.stories.tsx`):
- `component` + a relative import; `title: '<Category>/<Name>'`; `tags: ['autodocs']`; `parameters.docs.description.component` = the component's purpose in one sentence.
- `args` / `argTypes` from the REAL props: select for unions, boolean for flags, `control: false` for functions, nodes and `asChild`; callbacks through `fn()`.
- `Playground` first, then one named story per state that changes what the user sees (variants, sizes, disabled, pending, empty, error, long text, RTL-sensitive layout). Each named story carries a one-line JSDoc saying WHEN to use it.
- Sample text in the product's primary language, taken from its own locale files — never lorem ipsum.
- Overlays render open in at least one story (`defaultOpen`, or a `play` that clicks the trigger when there is no such prop).
- Data components take inline fixtures through props; no network. A provider the preview lacks goes in that story's `decorators`.

**The import tag (mandatory).** The MCP's `docs-show` prints each story's import line — and rewrites any relative or path-alias import to the app's `package.json` name (`import { Button } from '@acme/web'`), which does not resolve. The documented override is a JSDoc tag on the component itself:

```tsx
/**
 * @import import { Button } from '@/shared/ui/button';
 */
const Button = …
```

The path is **the one the app's own code uses most** for that name — count it (`rg -o "import \{[^}]*\bButton\b[^}]*\} from '[^']+'" -g '!*.stories.*' | sort | uniq -c`). That is often a barrel (`@/shared/query`, `@/entities/money`), not the defining file. Append the tag to an existing JSDoc block; never change code.

### Story hygiene — the project's gates apply to stories

A repo that tests its own source will scan the new `*.stories.*` files. Each class below failed on a real repo; fix the STORY, never loosen the gate:

| Gate shape | What the story must do |
|---|---|
| Walks the component dir to require a doc/test per module | The gate must skip `.stories.` the way it skips `.test.` — the one gate edit that IS right, because a story is not a module. |
| One component name per UI idea | Helper components get story-unique names (`ControlledCheckbox`, not `Controlled` in fourteen files). |
| No function body written twice | Don't copy a helper from the gallery page being migrated; write it in the story's own shape. |
| Static a11y scan (icon-only button needs a name) | Put `aria-label="…"` literally on the JSX; a label passed through `args` is invisible to a static scan. |
| Required-prop scan (e.g. money without a currency) | Pass the prop explicitly even when `{...args}` already carries it. |
| Digit-system / copy scans | Sample copy follows the same rule as app copy. Test-only inputs (typing Arabic digits) belong in the unit test that already covers them, not in a `play`. |
| Banned API names (`confirm(`, `alert(`) | Name the hook result the way app code does (`askConfirm`). |

## Phase 5 — Update
- `package.json` scripts: `storybook`, `build-storybook`, `test:stories`; `test` scoped to `--project unit`.
- `.gitignore`: `storybook-static`, `*storybook.log`.
- `.mcp.json`: run `~/.claude/scripts/detect-mcp.sh <repo> --apply` — it detects `.storybook/` in any workspace member, reads the dev port, and writes `{"type": "http", "url": "http://localhost:<port>/mcp"}` (plus the Cursor / VS Code siblings when those tools are selected).
- `ai/dynamic/changelog.md` — `Storybook <version>: <N> components, <M> stories (<mode>)`.

## Phase 6 — Validate

All of these, in this order, and the run is not done until each is green:
1. Typecheck the app (a monorepo member may need its workspace deps built first — a missing `@scope/pkg` type error is that, not a story bug).
2. Lint — zero errors.
3. **The FULL unit suite**, not the stories' neighbours: the gates that catch stories live in unrelated directories. Compare failures against the base branch — a failure also present there is pre-existing; report it, don't fix it here.
4. `test:stories` — every story renders in Chromium. **The first full run after adding many stories can fail with `Failed to fetch dynamically imported module …/sb-vitest/deps/…`**: Vite re-optimises dependencies mid-run (it also happens when several agents run vitest at once). Re-run once; a failure that repeats is real.
5. **Probe the MCP** with the dev server up — do not trust the config alone:
   ```
   initialize → tools/list            (expect docs-list, docs-show, test-run, stories-preview …)
   docs-list                          (count == components with stories)
   docs-show <one component>          (its import line is the app's path, not the package name)
   test-run <two story ids>           (passes — proves the storybook vitest project is found)
   ```
   The endpoint speaks streamable HTTP: POST JSON-RPC with `Accept: application/json, text/event-stream`, keep the `mcp-session-id` header from `initialize`.

### Mechanical halt (mandatory)

**Halt if any of:**
- A story passes a prop the component's source does not declare.
- A story file imports from a feature/slice the component's layer may not reach (the repo's layering lint is the judge).
- A component in the inventory got no story and the report does not say why at `<file:line>`.
- `docs-show` still prints the package name as the import source for any component.
- The unit suite has a failure that the base branch does not have.
- Any `@storybook/*` version is not pinned to one exact version, or differs across packages.

## Phase 7 — Improve
- `/learn-from-task` — record the providers the preview needed and any gate the stories tripped, so the next UPDATE starts from them.
- A doc page and a story disagreeing about a prop → report both locations; the source decides which one is wrong.

## Output format
```
## /setup-storybook — <CREATE | UPDATE> · Storybook <version> · <app-dir>

Prior art:   none | <explorer> at <file:line> → <user's decision>
Inventory:   <N> components (<K> already had stories) → <M> written, <S> skipped (reasons below)
Installed:   storybook, @storybook/<framework>, addon-docs, addon-a11y, addon-vitest, addon-mcp @ <version>
Cleaned:     eslint config restored + plugin added · example stories removed · <chromatic/coverage removed>
Tests:       unit <pass>/<total> (pre-existing failures: <list or none) · stories <P>/<P> in Chromium
MCP:         http://localhost:<port>/mcp · docs-list <N> · import line verified on <Component>
Skipped:     <component> — <reason> (<file:line>)

Status: COMPLETE | BLOCKED on <halt>
```

## What to do next — required closing section

End with a `## What to do next` block: MUST FIX (any halt above) → SHOULD FIX (doc pages that disagree with source, components skipped for a real bug) → OPTIONAL (raise `a11y.test` to `'error'` per clean component, MDX pages for foundations). Each step names `<file:line>` + **Fix** + **Verify**, then the closing steps: start `pnpm storybook` before an agent session so the MCP is live, and re-run `/setup-storybook` (UPDATE) after adding components. Canonical contract: [`templates/snippets/review-action-plan.md`](../../../snippets/review-action-plan.md).

## Failure modes
- Keeping `init`'s eslint rewrite → a thousand-line diff nobody can review, hiding the one line that mattered.
- Leaving the browser project in the default `test` script → every `test` run starts Chromium; CI slows or fails with no story change.
- A separate vitest config for stories → Storybook's test panel and the MCP `test-run` both fail to find the project.
- No `@import` tag → every snippet the MCP serves imports from the package name; the agent copies an import that does not resolve.
- Validating only the story run → the repo's own gates fail on the next `test` run, after the change looks done.
- Bypassing the release-age window to get the newest Storybook → the exact supply-chain exposure the window exists to close.

## Related

### Sibling commands and skills — where the boundary falls
- `component-playground` (skill, this pack) — the disposable, dependency-free probe for one component in a repo with NO explorer. It halts on a repo with Storybook; this command is where that repo goes instead.
- `/add-component` — writes a new component and, when Storybook is present, its story with the `@import` tag. This command is the sweep over components that already shipped.
- `visual-check` (skill, this pack) — owns rendered-frame baselines; a story gives it a stable URL to point at, nothing more.
- `@design-system-guardian` *(ui-ux pack, when co-installed)* — owns whether a primitive should exist; this command documents what does exist and makes no system-level claim.

### Scripts
- `scripts/detect-mcp.sh` — writes the `storybook` HTTP entry once `.storybook/` carries `addon-mcp`; reports it as unwired (nothing written) when the addon is missing.

### Rules
- `.claude/rules/frontend-principles.md`
