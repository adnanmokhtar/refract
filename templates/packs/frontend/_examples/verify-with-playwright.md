---
name: verify-with-playwright
description: Live-drive the running app via the Playwright MCP server — navigate, assert visible, fill forms, screenshot, capture console errors. Use after a UI feature change, before declaring "done." Distinct from @playwright/test (file-based suites, see visual-check).
kind: example
pack: frontend
---

# verify-with-playwright

Live-drives the running app through the Playwright **MCP** server — navigate, wait, interact, screenshot, read the console. Ad-hoc verification of the change you just made; not a file-based `.spec.ts` suite (that is `visual-check`).

## Premise

Real artifacts only. Every "works" cites the screenshot path + the URL + the selectors waited on. A 0-step run is a failure, not a pass. Console errors on load fail the run even when the screenshot looks fine. Selectors pin to roles + accessible names — a verification that breaks on the next styling change was never verification.

Minimum for PASS: 1 navigate + 1 wait_for_selector + 1 screenshot citation.

## Prerequisites

- Playwright MCP server in `.mcp.json`.
- Dev server running — invoke `dev-server-start` and consume its `url`.
- **The `visual-check` harness contract**: session state at `tests/.auth/user.json`, artifacts under the gitignored `.playwright-mcp/`, `RENDER BLOCKED` as a HALT (never a SKIP). Do not introduce a second convention.

## Procedure

1. **Acquire the URL** — if none was provided, invoke `dev-server-start` and take its `url` + `pid` + `mode`. If `mode == started-fresh`, take ownership of cleanup; if `already-running`, never kill on exit.
2. **Author the verification flow** — a short list of MCP calls pinned to user-visible behavior: navigate, `wait_for_selector` on the primary heading, screenshot the baseline frame, interact, `wait_for_selector` on the success indicator, screenshot, `console_messages()`. Pin selectors to roles + accessible names (`role=button[name=Save]`), not CSS classes.
3. **Execute + collect** — halt on the first failure. On a `wait_for_selector` timeout capture the current screenshot, the console messages, and the page's full HTML.
4. **Multi-locale / multi-viewport pass** — for projects with `i18n` declared, repeat the flow at each locale; for projects with declared breakpoints, repeat at mobile / tablet / desktop widths via `set_viewport_size`.
5. **Cleanup** — if Step 1 returned `started-fresh`, kill the dev server and remove `.claude/dev-server.pid`; if `already-running`, leave it alone.

## Output format

```
verify-with-playwright — <feature/route>
  url:      http://localhost:5173/dashboard/brands
  flows:    3   steps: 22   failures: 0
  screenshots: .playwright-mcp/<ts>/brands-list-loaded.png ...
  console:  0 errors, 1 warning
  outcome:  PASS
```

## Failure modes

- **Selector not found** — common: framework still hydrating, or the selector points at a name that changed. Capture screenshot + HTML snapshot and surface it for a re-author of the selector. Don't loop forever.
- **Console error on load** — fail loudly. UI may render but throw; that is a regression even if the screenshot looks fine. Print the error stack in the report.
- **Auth required, no credentials** — surface the missing-credentials condition; halt. Never log or commit a fake credential.
- **Network request failure** (XHR 4xx/5xx) — log under `network_errors`. Don't auto-retry; that masks real backend issues.
- **Headless vs headed mismatch** — default to headless; if a step fails, surface the suggestion to re-run headed for human inspection.

## Hard rules

- **Cite the URL + path in the output.** A reader must be able to navigate to the same page in their own browser.
- **Screenshots are ephemeral by default** — write to the gitignored `.playwright-mcp/<timestamp>/` per the `visual-check` contract. Promoting a frame to a baseline is a `visual-check` decision, not this skill's.
- **Never commit** `.claude/dev-server.{pid,log}` or screenshot dumps. They're per-developer.
- **Pinned selectors prefer roles + names** over CSS classes — the single thing that determines whether the verification survives a styling refactor.
- **Don't fake success.** A 0-step run is a fail, not a pass. Minimum 1 navigate + 1 wait_for_selector + 1 screenshot.

## Halt conditions

- No screenshot artifact → unverified.
- Console errors on load with a PASS verdict → contradiction; fail the run.
- Selectors targeting CSS classes instead of roles + names.
- Playwright MCP not configured → halt. If another instrumented browser MCP is configured, name it as the alternative the user may wire, then stop — choosing the harness is the user's call.
