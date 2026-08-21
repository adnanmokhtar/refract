---
name: verify-with-playwright
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

## Output

```
verify-with-playwright — <feature/route>
  url:      http://localhost:5173/dashboard/brands
  flows:    3   steps: 22   failures: 0
  screenshots: .playwright-mcp/<ts>/brands-list-loaded.png ...
  console:  0 errors, 1 warning
  outcome:  PASS
```

## Halt conditions

- No screenshot artifact → unverified.
- Console errors on load with a PASS verdict → contradiction; fail the run.
- Selectors targeting CSS classes instead of roles + names.
- Playwright MCP not configured → halt. If another instrumented browser MCP is configured, name it as the alternative the user may wire, then stop — choosing the harness is the user's call.
