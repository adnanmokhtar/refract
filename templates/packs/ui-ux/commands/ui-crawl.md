---
description: Automated cross-route UI crawler. Logs in once, visits every route in the project's route manifest, takes screenshots at 3 breakpoints + dark mode + RTL, walks in-page tabs, opens dialogs and dropdowns, runs axe-core a11y scan per route, captures console/network errors, and writes a ranked findings report. Frontend stacks only. Detect-only — for auto-fix see /ui-crawl-fix. Complements /ui-sweep (which is the deeper specialist sweep) by providing fast, repeatable QA-style coverage of EVERY route with machine-readable output.
kind: command
pack: ui-ux
---

# /ui-crawl [<scope>] [--smoke] [--filter=<substr>] [--full-matrix]

## The Premise

**You can't QA 100+ pages by hand on every change.** This command spins up Playwright, logs in once, visits every route, and produces a ranked report of what's broken — JS errors, failed API calls, layout overflow, a11y violations, broken dialog triggers, untestable dropdowns.

It's **detect-only**. Fixing is a separate step (`/ui-crawl-fix` or manual). The report ranks routes by severity so you fix the worst first.

## When to use

- **Pre-release sweep** — before shipping, surface every regression across the app.
- **After a design-token / shared-wrapper change** — verify nothing visually broke downstream.
- **Recurring CI** — schedule weekly; diff findings against last run.
- **Before `/ui-sweep`** — use `/ui-crawl` to triage WHAT is broken, then `/ui-sweep` for the deep dive on a specific area.

## When NOT to use

- Visual polish on one component → `/enhance-ui`.
- Whole-app design quality measurement → `/ui-sweep` (deeper, slower, with HTML report).
- New-feature development → `/add-feature`.
- Non-frontend stacks — halts.

## Prerequisites

1. **Dev server running** at a known URL (default `http://localhost:3000` unless overridden).
2. **Test account** with broad permissions (so every route resolves; routes hidden behind permissions get skipped silently otherwise).
3. **Route manifest** at `ai/audits/ui-crawl-inventory.json` (auto-generated on first run if missing — calls the inventory subskill).
4. **Playwright + axe installed**: `@playwright/test`, `@axe-core/playwright`. Auto-installed if missing.

## What it produces

| Artifact | Path | Purpose |
|---|---|---|
| Inventory JSON | `ai/audits/ui-crawl-inventory.json` | Route manifest with dialog/DDL/tab counts |
| Findings JSON | `ai/audits/ui-crawl-findings.json` | Full machine-readable findings (per-route) |
| Findings MD | `ai/audits/ui-crawl-findings.md` | Human triage report, ranked by severity |
| Screenshots | `tests/crawl/.screenshots/` | 5+ per route: mobile/tablet/desktop LTR, desktop dark, desktop RTL, plus tabs/dialogs/DDLs |
| Playwright HTML report | `tests/crawl/.report/` | Interactive timeline with traces on failure |

## Phases

### Phase 0 — Pre-flight
- Verify dev server reachable.
- Verify auth credentials in `tests/crawl/.env` (or prompt user to create from `.env.example`).
- Install Playwright + axe if missing.

### Phase 1 — Inventory (skipped if `ui-crawl-inventory.json` exists and `--refresh-inventory` not set)
- Parse `src/<modules>/routes.ts` (or framework-equivalent) for every route + name + permission + lazy component.
- Parse sidebar config for menu hierarchy.
- For each page file: grep for `<BaseModal>`/`<Dialog>` (dialogs), `<BaseDropdown>`/`<Dropdown>`/`<MultiSelect>` (DDLs), `<TabView>`/`<v-tabs>`/`role="tab"` (tabs).
- Output JSON inventory.

### Phase 2 — Auth setup
- Log in once via the project's auth flow (uses selectors documented in `_extracted-idioms.md`).
- Save `storageState` to `tests/crawl/.auth/state.json`. Reused by all crawler workers.

### Phase 3 — Parallel crawl
For each crawlable route (filters out auth pages, dynamic-param routes like `:id/edit`, full-screen editors), in parallel workers (default 3):

1. Visit route, wait for `networkidle`.
2. Attach probes: console errors, page errors, network 4xx/5xx, request failures.
3. Take screenshots:
   - Mobile (375×812) LTR light
   - Tablet (768×1024) LTR light
   - Desktop (1440×900) LTR light
   - Desktop LTR dark (toggle `html.dark`)
   - Desktop LTR→RTL (set `dir="rtl"`)
   - (with `--full-matrix`: + desktop dark+RTL, + mobile dark)
4. Detect horizontal overflow at each viewport (`doc.scrollWidth > window.innerWidth`).
5. Run axe-core (`wcag2a`, `wcag2aa`, `wcag21aa`) — capture violations with impact, node count, help URL.
6. Walk in-page tabs (`main [role="tab"]`, `.p-tabview-nav li`, `.p-tabmenu-item`, `.nav-tabs .nav-link`, `.route-tabs a|button`): skip already-active tab, click each (cap 8), snapshot after each.
7. Try to open up to 3 dialogs by clicking Add/New/Create/Edit-labeled buttons; snapshot, close with Escape.
8. Try to open up to 3 dropdowns; snapshot panel, close with Escape.
9. Write per-route finding to `tests/crawl/.findings/<route-id>.json`.

### Phase 4 — Aggregate
- Read all per-route findings.
- Compute severity per route:
  - Critical: failed load OR uncaught JS error
  - High: page errors OR 5xx network OR multiple critical axe OR broken dialog trigger
  - Medium: overflow at a viewport, moderate axe density
  - Low: single contrast issue, light findings
- Rank all routes by severity score.
- Output ranked markdown report + machine-readable JSON.

## Flags

- `<scope>` — Optional comma-separated module names (e.g., `inventory,orders`). Crawls only matching routes.
- `--smoke` — 1 representative route per module (fast triage, ~20 routes, ~5 min).
- `--filter=<substr>` — Crawl only routes whose path contains this substring.
- `--full-matrix` — Adds dark+RTL combo and mobile-dark snapshots. ~8 screenshots per route.
- `--skip-interactions` — Skip dialog/DDL/tab clicking. Faster, but no broken-trigger detection.
- `--refresh-inventory` — Re-build the inventory JSON before crawling.
- `--workers=N` — Parallel browser workers (default 3). Higher = faster but more dev-server load.
- `--no-dark` / `--no-rtl` — Skip those screenshot variants.

## Examples

```
/ui-crawl                          # full crawl, default options
/ui-crawl --smoke                  # one route per module, fast
/ui-crawl inventory,orders         # only those two modules
/ui-crawl --filter=settings        # any route with "settings" in path
/ui-crawl --full-matrix --no-dark  # full responsive matrix, no dark mode
/ui-crawl --workers=5              # 5 parallel browsers, faster
```

## Severity scoring (used in the markdown report)

```
score = 100 if !loadOk
      + 20 × pageErrors
      + 10 × network_5xx_or_failed
      + 8  × axe_critical
      + 6  × (dialogs_attempted > 0 AND dialogs_opened == 0)
      + 5  × console_errors
      + 4  × axe_serious
      + 4  × overflow_at_viewport
      + 3  × network_4xx (excluding /auth /login)
      + 2  × axe_moderate

severity = critical if score ≥ 80
         | high     if score ≥ 30
         | medium   if score ≥ 10
         | low      otherwise
```

## Hard rules

- **No dev-server-affecting changes during crawl.** Don't trigger HMR. The crawl is read-only against the running app.
- **No fixes.** This command produces findings; `/ui-crawl-fix` (or manual edits) apply fixes.
- **Credentials in `tests/crawl/.env` only.** Never log password to console. Never commit `.env` (gitignored).
- **Skip dynamic-param routes** (`:id/edit`, etc.) — no representative ID without seed data. Surfaced as "skipped" in the report.
- **Per-route timeout** at 90s. A page that doesn't load is logged as `loadOk: false` and the crawl continues.
- **One inventory rebuild per run max.** Inventory is mechanical; the command does not re-parse routes every run unless `--refresh-inventory` is set.

## Output (terminal summary)

```
[crawl] inventory: 165 routes | crawlable: 146 | workers: 3 | matrix: standard
[setup] storageState saved (admin@admin.com)
[crawl] 1/146 — dashboard :: dashboard (4.2s)
[crawl] 2/146 — inventory :: products (7.1s)
...
[crawl] 146/146 — webhooks :: webhooks (3.4s)
[crawl] complete in 47m23s
[aggregate] severity: critical=0 high=1 medium=49 low=96
[aggregate] top issues: color-contrast (778 nodes / 79 routes), button-name (347/22), label (338/38)
[aggregate] reports written:
  - ai/audits/ui-crawl-findings.md
  - ai/audits/ui-crawl-findings.json
```

## Cross-references

- `/ui-crawl-fix` — auto-fix the mechanical findings (contrast tokens, missing aria-label, label-for wiring, etc.).
- `/ui-sweep` — deeper UI/UX specialist sweep with HTML report and metrics; uses `/ui-crawl` findings as one input.
- `/enhance-ui <surface>` — targeted polish on one surface.
- `/design-review` — qualitative review without changes.
- `/align-scan` — structural-quality scan (overlaps on a11y / token classes; this command goes deeper on per-route browser-driven detection).
- `.claude/rules/align-discipline.md` — the closure-verb vocabulary `/ui-crawl-fix` operates on.

## Implementation notes

The command is backed by a Playwright test project at `tests/crawl/` (path follows the project's test root from `_extracted-codebase.md`) with:
- `auth.setup.ts` — Phase 2
- `ui-crawl.spec.ts` — Phase 3 (the heavy lifter; one Playwright `test()` per route)
- `aggregate.ts` — Phase 4
- `lib/inventory.ts` + `lib/probe.ts` — shared helpers

Wired via `<pkg-runner> crawl` / `crawl:report` / `crawl:smoke` / `crawl:clean` scripts in the project's `package.json` (package runner — `pnpm` / `npm` / `yarn` / `bun` — comes from `_extracted-codebase.md § Stack`). The slash command exists for discoverability + flag parsing; the underlying scripts are the canonical entrypoint.

**Stack scope.** Frontend stacks only (`PROJECT_KIND in {frontend-*, mobile-web}`). Halts on backend / data / library / CLI projects with a redirect to the appropriate `/optimize` or `/security-audit` flow.

**Project-specific paths** — the route-manifest source (`src/<modules>/routes.ts` or framework equivalent), shared wrapper inventory (`<CrudActions>` / `<TableActions>` / `<FormField>` etc.), design-token file, sidebar config, sanitize helper, and translation builder are **all read from `_extracted-idioms.md`**. Hardcoded examples in this file are the Vue 3 + Vite + Pinia shape; substitute for React / Next / Svelte / Solid / Angular per the project's idioms.
