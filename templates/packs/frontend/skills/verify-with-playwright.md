---
name: verify-with-playwright
description: Live-drive the running app via the Playwright MCP server — navigate, assert visible, fill forms, screenshot, capture console errors. Use after a UI feature change, before declaring "done." Distinct from @playwright/test (file-based suites, see visual-check).
---

# verify-with-playwright

## Premise

Real artifacts only. Every claim of "works" cites the screenshot file path produced + the URL navigated + the selectors waited on. "I checked it" is not verification. A 0-step run is a failure, not a pass. Console errors on load fail the run even if the screenshot looks fine. Selectors pin to roles + accessible names, not CSS classes — a verification that breaks on the next styling change is worthless.

Refuse to declare PASS without at least 1 navigate + 1 wait_for_selector + 1 screenshot citation.

Real-browser verification that the change you just made actually works in the running app. Uses the Playwright MCP server's tools (`navigate`, `click`, `type`, `wait_for_selector`, `screenshot`, `eval_js`, `console_messages`) — not pre-written `.spec.ts` files. Tighter feedback loop than e2e tests; complementary, not replacement.

## When to use

- After `/add-feature` / `/add-page` / `/add-component` — confirm the new UI renders + interacts as designed.
- After `/fix-bug` for a UI bug — reproduce the user's flow, confirm it now works.
- After a router change, layout shift, or design-token swap — visually inspect at least one representative page.
- During an `/a11y-audit` — drive the page through keyboard navigation; capture focus order.
- After an i18n string update that may shift layout (Arabic / German / Japanese) — screenshot at each locale.

## When NOT to use

- Pure logic / utility / store changes with no rendered surface.
- Pre-written e2e test work — use `npx playwright test` (file-based) for that; this skill is for live ad-hoc verification.
- Performance benchmarking — use `lighthouse-ci` skill instead.

## Prerequisites

- **Playwright MCP server configured** in `.mcp.json` (`detect-mcp.sh --apply` writes this; on tenant-portal-v2 it's the `playwright` key with `@playwright/mcp`).
- **Dev server running** — invoke `dev-server-start` first; consume its `url` output.
- **Authenticated state** if the route requires auth — either the test user credentials are in `.env.local`, or the verification flow includes login as Step 1.

## Procedure

### Step 1 — Acquire the URL

If no URL provided, invoke `dev-server-start`. Take its `url` + `pid` + `mode` output. If `mode == started-fresh`, take ownership of cleanup; if `already-running`, never kill on exit.

### Step 2 — Author the verification flow

Compose a short list of MCP tool calls. **Pin to user-visible behavior**, not implementation. Each step is one MCP call:

```
navigate(url + path)                       # open the page
wait_for_selector(<primary heading>)        # confirm render
screenshot("<feature>-loaded.png")          # baseline frame
... interact with the feature ...
wait_for_selector(<success indicator>)
screenshot("<feature>-success.png")
console_messages()                          # capture console errors
```

Pin selectors to roles + accessible names where possible (`role=button[name=Save]`, `role=heading[name=Brands]`) — survives styling changes. Avoid CSS-class selectors except where they're stable design-system tokens.

### Step 3 — Execute + collect

Each tool call returns a result; halt on the first failure. On `wait_for_selector` timeout (10s default), capture:
- The current screenshot (`<feature>-failure-<step>.png`).
- The console messages.
- The page's full HTML (`page.content()`).

### Step 4 — Multi-locale / multi-viewport pass

For frontend projects with `i18n` declared (codebase-profile.md § 10), repeat the flow at each locale via:
```
eval_js("location.assign('/?lang=ar')")
wait_for_selector(<primary heading translated>)
screenshot("<feature>-ar.png")
```

For projects with declared breakpoints (CSS theme detection), repeat at `375px` (mobile), `768px` (tablet), `1280px` (desktop) using `set_viewport_size`.

### Step 5 — Cleanup

If you started the dev server (Step 1 returned `started-fresh`), kill it:
```bash
kill "$(cat .claude/dev-server.pid)" 2>/dev/null && rm .claude/dev-server.pid
```

If `already-running`, leave it alone.

## Output format

```
verify-with-playwright — <feature/route>
  url:       http://localhost:5173/dashboard/brands
  flows:     3 (golden + edit + delete confirmation)
  steps:     22 navigate/click/wait/assert
  failures:  0
  screenshots:
    - .claude/playwright/<ts>/brands-list-loaded.png
    - .claude/playwright/<ts>/brands-edit-saved.png
    - .claude/playwright/<ts>/brands-delete-confirmed.png
  console:   0 errors, 1 warning ("Vue I18n missing key: Brands.exports.title")
  outcome:   PASS
```

## Failure modes

- **Selector not found within 10s** — common: framework still hydrating, or selector points at a name that changed. Capture screenshot + HTML snapshot; surface to the agent for a re-author of the selector. Don't loop forever.
- **Console error on load** — fail loudly. UI may render but throw — that's a regression even if the screenshot looks fine. Print the error stack to the report.
- **Auth required, no credentials** — surface the missing-credentials condition; halt. Never log a fake credential or commit one.
- **Network request failure** (XHR 4xx/5xx) — log under `network_errors` in the report. Don't auto-retry — that masks real backend issues.
- **Headless vs headed mismatch** — some flows behave differently headed. Default to headless; if a step fails, surface the suggestion to re-run with `--headed` for human inspection.

## Related

- `dev-server-start` — prerequisite for localhost targets.
- `visual-check` — file-based pre-written `.spec.ts`. Persistent regression suite. Slower; runs less often.
- `a11y-audit` — uses similar Playwright tools but layered on axe-core checks.

## Hard rules

- **Cite the URL + path in the output.** Anyone reading the report should be able to navigate to the same page in their own browser.
- **Screenshots are ephemeral by default** — write to `.claude/playwright/<timestamp>/` (gitignored). Promote to `test/visual/baseline/` only when the agent + user explicitly accept a new baseline.
- **Never commit** `.claude/dev-server.{pid,log}` or screenshot dumps. They're per-developer.
- **Pinned selectors prefer roles + names** over CSS classes. Surfacing the rule explicitly because it's the single thing that determines whether the verification survives a styling refactor.
- **Don't fake success.** A 0-step run is a fail, not a pass. Minimum 1 navigate + 1 wait_for_selector + 1 screenshot.

## Halt conditions

- Halt if no screenshot file path is produced — verification without an artifact is unverified.
- Halt if console errors appeared on load and the report claims PASS. UI rendering is not enough; runtime errors fail the run.
- Halt if selectors target CSS classes instead of roles + accessible names — the verification won't survive the next styling refactor.
- Halt if the Playwright MCP server is not configured in `.mcp.json` — do not silently fall back to a different tool.
